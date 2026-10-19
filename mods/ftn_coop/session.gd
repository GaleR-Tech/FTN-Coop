extends Node

signal roster_changed
signal state_changed
signal outgoing(peer_id: int, kind: String, body: Dictionary)

enum State { OFFLINE, CREATING, JOINING, LOBBY, SYNCING, PLAYING }
const LIMIT := 4
const PROTOCOL := 1

var state: int = State.OFFLINE
var roster: Dictionary = {}
var is_host := false
var session_id := ""
var last_error := ""
var player_name := "Spieler"
var _transport: Node
var _build := ""
var _mod_version := ""
var _generation := 0
var _links: Array = []
var _pending: Dictionary = {}

func configure(transport: Node, build: String, mod_version: String) -> void:
	_transport = transport
	_build = build
	_mod_version = mod_version

func host() -> Dictionary:
	if _transport == null:
		return _error("TRANSPORT_MISSING")
	leave()
	last_error = ""
	is_host = true
	_set_state(State.CREATING)
	_attach()
	var result: Dictionary = _transport.host(LIMIT)
	if not result.ok:
		leave()
		last_error = result.code
	return result

func join(lobby_id: int) -> Dictionary:
	if _transport == null or lobby_id <= 0:
		return _error("LOBBY_INVALID")
	leave()
	last_error = ""
	_set_state(State.JOINING)
	_attach()
	var result: Dictionary = _transport.join(lobby_id)
	if not result.ok:
		leave()
		last_error = result.code
	return result

func leave() -> void:
	_generation += 1
	if _transport != null:
		for link in _links:
			if _transport.is_connected(link[0], link[1]):
				_transport.disconnect(link[0], link[1])
		_links.clear()
		_transport.close()
	roster.clear()
	_pending.clear()
	is_host = false
	session_id = ""
	_set_state(State.OFFLINE)
	roster_changed.emit()

func accept_hello(peer_id: int, hello: Dictionary) -> Dictionary:
	if not is_host or state == State.OFFLINE:
		return _error("HOST_ONLY")
	if peer_id <= 1:
		return _error("PEER_INVALID")
	if not roster.has(peer_id) and roster.size() >= LIMIT:
		return _error("SESSION_FULL")
	if typeof(hello.get("protocol")) != TYPE_INT or hello.protocol != PROTOCOL:
		return _error("PROTOCOL_MISMATCH")
	if hello.get("build") != _build:
		return _error("BUILD_MISMATCH")
	if hello.get("mod_version") != _mod_version:
		return _error("MOD_MISMATCH")
	if not roster.has(peer_id):
		return _error("PEER_UNKNOWN")
	if roster[peer_id].get("accepted", false):
		return _ok(roster[peer_id].duplicate())
	var name_value: Variant = hello.get("name", "Spieler")
	if not name_value is String or name_value.length() > 64 or name_value.contains("\n") or name_value.contains("\r"):
		return _error("NAME_INVALID")
	roster[peer_id] = {"id": peer_id, "name": name_value.strip_edges(), "state": "syncing", "accepted": true}
	_pending.erase(peer_id)
	roster_changed.emit()
	outgoing.emit(peer_id, "WELCOME", {"session_id": session_id, "player_id": peer_id, "roster": roster.values(), "mod_version":_mod_version})
	return _ok(roster[peer_id].duplicate())

func mark_world_ready(peer_id: int) -> Dictionary:
	if not roster.has(peer_id) or not roster[peer_id].get("accepted", false):
		return _error("PEER_NOT_READY")
	roster[peer_id].state = "playing"
	if (is_host and peer_id == 1) or (not is_host and peer_id == _transport.local_peer_id()):
		_set_state(State.PLAYING)
	roster_changed.emit()
	return _ok(null)

func accept_welcome(sender: int, body: Dictionary) -> Dictionary:
	if is_host or sender != 1 or (state != State.SYNCING and state != State.PLAYING):
		return _error("WELCOME_INVALID")
	if body.get("mod_version")!=_mod_version:
		return _error("MOD_MISMATCH")
	var identity: Variant = body.get("session_id")
	if not identity is String or identity.length() != 32 or not identity.is_valid_hex_number():
		return _error("SESSION_INVALID")
	if not session_id.is_empty() and session_id != identity:
		return _error("SESSION_MISMATCH")
	var assigned: Variant = body.get("player_id")
	var rows: Variant = body.get("roster")
	if typeof(assigned) != TYPE_INT or assigned != _transport.local_peer_id() or not rows is Array or rows.size() > LIMIT:
		return _error("ROSTER_INVALID")
	var updated := {}
	for row in rows:
		if not row is Dictionary or typeof(row.get("id")) != TYPE_INT or int(row.id) <= 0 or updated.has(row.id):
			return _error("ROSTER_INVALID")
		if not row.get("name") is String or row.name.length() > 64 or not row.get("state") is String or typeof(row.get("accepted")) != TYPE_BOOL:
			return _error("ROSTER_INVALID")
		updated[row.id] = row.duplicate()
	if not updated.has(1) or not updated.has(assigned) or not updated[assigned].accepted:
		return _error("ROSTER_INVALID")
	session_id = identity
	roster = updated
	if state != State.PLAYING:
		_set_state(State.SYNCING)
	roster_changed.emit()
	return _ok(null)

func _attach() -> void:
	_links = [
		["hosted", _on_hosted.bind(_generation)],
		["connected", _on_connected.bind(_generation)],
		["disconnected", _on_disconnected.bind(_generation)],
		["failed", _on_failed.bind(_generation)],
	]
	for link in _links:
		_transport.connect(link[0], link[1])

func _on_hosted(_lobby_id: int, generation: int) -> void:
	if generation != _generation or state != State.CREATING:
		return
	session_id = Crypto.new().generate_random_bytes(16).hex_encode()
	roster[1] = {"id": 1, "name": player_name, "state": "lobby", "accepted": true}
	_set_state(State.LOBBY)
	roster_changed.emit()

func _on_connected(peer_id: int, generation: int) -> void:
	if generation != _generation or state == State.OFFLINE:
		return
	if is_host:
		if roster.has(peer_id):
			return
		if roster.size() >= LIMIT:
			_transport.reject_peer(peer_id)
			return
		roster[peer_id] = {"id": peer_id, "name": "Verbinden …", "state": "connecting", "accepted": false}
		_pending[peer_id] = 0.0
		roster_changed.emit()
	elif peer_id == 1 and state == State.JOINING:
		_set_state(State.SYNCING)
		outgoing.emit(1, "HELLO", {"protocol": PROTOCOL, "build": _build, "mod_version": _mod_version, "name": player_name})

func _on_disconnected(peer_id: int, generation: int) -> void:
	if generation != _generation:
		return
	if not is_host and peer_id == 1:
		leave()
		last_error = "HOST_LEFT"
		return
	roster.erase(peer_id)
	_pending.erase(peer_id)
	roster_changed.emit()

func _on_failed(code: String, generation: int) -> void:
	if generation != _generation:
		return
	leave()
	last_error = code
	state_changed.emit()

func _process(delta: float) -> void:
	for peer_id in _pending.keys():
		_pending[peer_id] += delta
		if _pending[peer_id] > 15.0:
			_pending.erase(peer_id)
			roster.erase(peer_id)
			_transport.reject_peer(peer_id)
			roster_changed.emit()

func _set_state(value: int) -> void:
	if state != value:
		state = value
		state_changed.emit()

func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "code": "OK", "value": value}

func _error(code: String) -> Dictionary:
	return {"ok": false, "code": code, "value": null}
