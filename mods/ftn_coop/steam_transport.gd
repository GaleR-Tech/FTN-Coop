extends Node

signal hosted(lobby_id: int)
signal connected(peer_id: int)
signal disconnected(peer_id: int)
signal failed(code: String)
signal message_received(peer_id: int, channel: int, bytes: PackedByteArray)
signal invite_received(lobby_id: int)

var build := "26260645"
var mod_version := "0.7.2"
var lobby_id := 0
var _steam: Object
var _peer: MultiplayerPeer
var _generation := 0
var _pending_host := -1
var _pending_join := 0
var _join_generation := -1
var _waiting := 0.0
var _hosting := false
var _wired := false
var _connecting_time := 0.0
var _version_mismatch: Dictionary = {}
var _polling := false
var _connection_handles: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func prepare() -> Dictionary:
	return _setup()

func local_name() -> String:
	if _steam==null or not _steam.has_method("getPersonaName"): return "Spieler"
	return String(_steam.call("getPersonaName")).replace("\n"," ").replace("\r"," ").left(32)

func host(limit: int) -> Dictionary:
	_version_mismatch.clear()
	var setup := _setup()
	if not setup.ok:
		return setup
	if limit != 4:
		return _error("LIMIT_INVALID")
	if _pending_host >= 0 or _pending_join != 0:
		return _error("STEAM_BUSY")
	close()
	_pending_host = _generation
	_waiting = 0.0
	_steam.call("createLobby", 0, limit) # Steam private, invitation-only lobby.
	return _ok(null)

func join(target_lobby: int) -> Dictionary:
	_version_mismatch.clear()
	var setup := _setup()
	if not setup.ok:
		return setup
	if target_lobby <= 0:
		return _error("LOBBY_INVALID")
	if _pending_host >= 0 or _pending_join != 0:
		return _error("STEAM_BUSY")
	close()
	_pending_join = target_lobby
	_join_generation = _generation
	_waiting = 0.0
	_steam.call("joinLobby", target_lobby)
	return _ok(null)

func invite() -> Dictionary:
	if _steam == null or lobby_id == 0:
		return _error("LOBBY_MISSING")
	_steam.call("activateGameOverlayInviteDialog", lobby_id)
	return _ok(null)

func local_peer_id() -> int:
	return _peer.get_unique_id() if _peer != null else 0

func send(peer_id: int, channel: int, bytes: PackedByteArray, reliable: bool) -> Dictionary:
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return _error("NOT_CONNECTED")
	if peer_id <= 0 or channel < 0 or channel > 1 or bytes.is_empty() or bytes.size() > 65536:
		return _error("PACKET_INVALID")
	if reliable:
		# SteamPacketPeer::send discards SendMessages' per-message error. Use
		# the same connection/lane with an API that reports a full send buffer.
		var identity: int = _peer.call("get_steam_id_for_peer_id",peer_id)
		for handle in _connection_handles:
			if _connection_handles[handle]!=identity: continue
			var info: Dictionary = _steam.call("getConnectionInfo",handle)
			if info.get("connection_state")!=3 or info.get("identity")!=identity or info.get("user_data")!=peer_id: continue
			var result: Dictionary = _steam.call("sendMessageToConnection",handle,bytes,9) # ReliableNoNagle, lane 0.
			if result.get("result")==25: return _error("WOULD_BLOCK")
			return _ok(null) if result.get("result")==1 else _error("SEND_FAILED")
		return _error("WOULD_BLOCK") # Connection callback can follow peer_connected.
	_peer.set_target_peer(peer_id)
	_peer.transfer_channel = channel
	# GodotSteam maps UNRELIABLE_ORDERED to RELIABLE, which queues old poses.
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	return _ok(null) if _peer.put_packet(bytes) == OK else _error("SEND_FAILED")

func reject_peer(peer_id: int) -> void:
	if _peer != null and peer_id > 1:
		_peer.disconnect_peer(peer_id, true)
		disconnected.emit(peer_id)

func close() -> void:
	_generation += 1
	_connection_handles.clear()
	var closing_peer := _peer
	_peer = null
	if closing_peer != null:
		# The SDK may emit disconnect while polling; close after its call returns.
		if _polling: closing_peer.close.call_deferred()
		else: closing_peer.close()
	if _steam != null and is_instance_valid(_steam) and lobby_id != 0:
		_steam.call("leaveLobby", lobby_id)
	lobby_id = 0
	_hosting = false
	_connecting_time = 0.0
	# Retain outstanding SDK requests until their callback arrives. This
	# prevents a late callback from being mistaken for a new request.

func _setup() -> Dictionary:
	if not Engine.has_singleton("Steam") or not ClassDB.class_exists("SteamMultiplayerPeer"):
		return _error("STEAM_UNSUPPORTED")
	_steam = Engine.get_singleton("Steam")
	for method in ["createLobby", "joinLobby", "leaveLobby", "setLobbyData", "getLobbyData", "getLobbyOwner", "activateGameOverlayInviteDialog", "getNumLobbyMembers", "getLobbyMemberByIndex", "setGlobalConfigValueInt32", "sendMessageToConnection", "getConnectionInfo"]:
		if not _steam.has_method(method):
			return _error("STEAM_UNSUPPORTED")
	if not is_inside_tree():
		return _error("STEAM_NOT_READY")
	var running := false
	for child in get_tree().root.get_children():
		var script: Script = child.get_script() as Script
		if script != null and script.resource_path == "res://autoload/steam_link.gd":
			running = child.get("running") == true
	if not running:
		return _error("STEAM_NOT_READY")
	var relay_key := "NETWORKING_CONFIG_P2P_TRANSPORT_ICE_ENABLE"
	if not ClassDB.class_has_integer_constant("Steam", relay_key):
		return _error("RELAY_UNSUPPORTED")
	var key := ClassDB.class_get_integer_constant("Steam", relay_key)
	if _steam.call("setGlobalConfigValueInt32", key, 0) != true:
		return _error("RELAY_UNSUPPORTED")
	if not _wired:
		for signal_name in ["lobby_created", "lobby_joined", "join_requested", "network_connection_status_changed"]:
			if not _steam.has_signal(signal_name):
				return _error("STEAM_UNSUPPORTED")
		_steam.connect("lobby_created", _on_lobby_created)
		_steam.connect("lobby_joined", _on_lobby_joined)
		_steam.connect("join_requested", _on_invite)
		_steam.connect("network_connection_status_changed",_on_network_connection_status_changed)
		_wired = true
	return _ok(null)

func _on_lobby_created(result: int, created_lobby: int) -> void:
	if _pending_host < 0:
		return
	var request_generation := _pending_host
	_pending_host = -1
	if request_generation != _generation:
		if result == 1:
			_steam.call("leaveLobby", created_lobby)
		return
	if result != 1:
		_fail("LOBBY_CREATE_FAILED")
		return
	lobby_id = created_lobby
	_hosting = true
	_peer = ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	if _peer == null or _peer.call("create_host", 0) != OK:
		_fail("HOST_CREATE_FAILED")
		return
	_steam.call("setLobbyData", lobby_id, "ftn_coop_protocol", "1")
	_steam.call("setLobbyData", lobby_id, "ftn_coop_build", build)
	_steam.call("setLobbyData", lobby_id, "ftn_coop_mod", mod_version)
	_wire_peer()
	_connecting_time = 0.0
	hosted.emit(lobby_id)

func _on_lobby_joined(joined_lobby: int, _permissions: int, _locked: bool, response: int) -> void:
	if joined_lobby != _pending_join:
		return
	var request_generation := _join_generation
	_pending_join = 0
	if request_generation != _generation:
		if response == 1:
			_steam.call("leaveLobby", joined_lobby)
		return
	if response != 1:
		# Steamworks EChatRoomEnterResponse; keep a useful reason for the UI.
		var reasons := {2:"LOBBY_NOT_FOUND",3:"LOBBY_NOT_ALLOWED",4:"SESSION_FULL",6:"LOBBY_NOT_ALLOWED",7:"LOBBY_ACCOUNT_LIMITED",9:"LOBBY_NOT_ALLOWED",10:"LOBBY_BLOCKED",11:"LOBBY_BLOCKED",15:"LOBBY_RATE_LIMITED"}
		_fail(reasons.get(response,"LOBBY_JOIN_FAILED"))
		return
	lobby_id = joined_lobby
	if str(_steam.call("getLobbyData", lobby_id, "ftn_coop_protocol")) != "1":
		_fail("PROTOCOL_MISMATCH")
		return
	if str(_steam.call("getLobbyData", lobby_id, "ftn_coop_build")) != build:
		_fail("BUILD_MISMATCH")
		return
	var lobby_mod: Variant = _steam.call("getLobbyData", lobby_id, "ftn_coop_mod")
	if lobby_mod != mod_version:
		var version: Script = load(get_script().resource_path.get_base_dir()+"/mod_version.gd")
		_version_mismatch = {"required":version.safe_version(lobby_mod)}
		_fail("MOD_MISMATCH")
		return
	var owner := int(_steam.call("getLobbyOwner", lobby_id))
	_peer = ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	if _peer == null or _peer.call("create_client", owner, 0) != OK:
		_fail("CLIENT_CREATE_FAILED")
		return
	_wire_peer()

func version_mismatch_details() -> Dictionary:
	return _version_mismatch.duplicate()

func _wire_peer() -> void:
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(func(peer_id: int): disconnected.emit(peer_id))

func _on_peer_connected(peer_id: int) -> void:
	if _hosting:
		var steam_id := int(_peer.call("get_steam_id_for_peer_id", peer_id))
		var member := false
		for index in range(mini(int(_steam.call("getNumLobbyMembers", lobby_id)), 4)):
			if int(_steam.call("getLobbyMemberByIndex", lobby_id, index)) == steam_id:
				member = true
				break
		if not member:
			reject_peer(peer_id)
			return
	connected.emit(peer_id)

func _on_invite(target_lobby: int, _friend_id: int) -> void:
	invite_received.emit(target_lobby)

func _on_network_connection_status_changed(handle: int, info: Dictionary, _old_state: int) -> void:
	if _peer==null: return
	if info.get("connection_state")==3 and typeof(info.get("identity"))==TYPE_INT:
		_connection_handles[handle] = info.identity
	elif int(info.get("connection_state",0))>3:
		_connection_handles.erase(handle)

func _process(delta: float) -> void:
	if _pending_host == _generation or (_pending_join != 0 and _join_generation == _generation):
		_waiting += delta
		if _waiting > 15.0:
			_fail("STEAM_TIMEOUT")
	if _peer == null:
		return
	var polled_peer := _peer
	_polling = true
	polled_peer.poll()
	_polling = false
	if _peer!=polled_peer: return # A disconnect callback can close or replace it.
	if not _hosting:
		if _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
			_connecting_time += delta
			if _connecting_time > 15.0:
				_fail("CONNECTION_TIMEOUT")
				return
		elif _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			_fail("HOST_LEFT")
			return
	var budget := 64
	while _peer != null and _peer.get_available_packet_count() > 0 and budget > 0:
		budget -= 1
		var sender := _peer.get_packet_peer()
		var channel := _peer.get_packet_channel()
		var bytes := _peer.get_packet()
		if bytes.size() <= 65536 and channel >= 0 and channel <= 1:
			message_received.emit(sender, channel, bytes)

func _exit_tree() -> void:
	close()
	if _wired and is_instance_valid(_steam):
		for pair in [["lobby_created", _on_lobby_created], ["lobby_joined", _on_lobby_joined], ["join_requested", _on_invite], ["network_connection_status_changed",_on_network_connection_status_changed]]:
			if _steam.is_connected(pair[0], pair[1]):
				_steam.disconnect(pair[0], pair[1])

func _fail(code: String) -> void:
	close()
	failed.emit(code)

func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "code": "OK", "value": value}

func _error(code: String) -> Dictionary:
	return {"ok": false, "code": code, "value": null}
