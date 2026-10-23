extends Node

signal hosted(lobby_id: int)
signal connected(peer_id: int)
signal disconnected(peer_id: int)
signal failed(code: String)
signal message_received(peer_id: int, channel: int, bytes: PackedByteArray)
signal invite_received(lobby_id: int)
var peer_id := 1
var other: Node
var linked := false
var drop_lossy := false
var invite_calls := 0
var invite_listening := false
var join_calls := 0
var joined_lobbies: Array[int] = []
var corrupt_baselines := 0
var corrupted_baselines := 0

func prepare() -> Dictionary:
	invite_listening = true
	return _ok()

func simulate_invitation(lobby: int) -> void:
	if invite_listening: invite_received.emit(lobby)

func host(_limit: int) -> Dictionary:
	hosted.emit.call_deferred(42)
	return _ok()

func join(_lobby: int) -> Dictionary:
	join_calls += 1
	joined_lobbies.append(_lobby)
	_link.call_deferred()
	return _ok()

func _link() -> void:
	if other==null: return
	linked = true
	other.linked = true
	other.connected.emit(peer_id)
	connected.emit(1)

func send(target: int, channel: int, bytes: PackedByteArray, _reliable: bool) -> Dictionary:
	if not linked or target != other.peer_id: return {"ok":false,"code":"NOT_CONNECTED","value":null}
	if channel==1 and drop_lossy: return _ok()
	if corrupt_baselines>0:
		var protocol: RefCounted = load("res://mods/ftn_coop/protocol.gd").new()
		var packet: Dictionary = protocol.decode(bytes)
		if packet.ok and (packet.value.type=="SNAPSHOT_CHUNK" or (packet.value.type=="SNAPSHOT_BEGIN" and packet.value.body.has("data"))):
			packet.value.body.data[0] = packet.value.body.data[0] ^ 1
			bytes = protocol.encode(packet.value).value
			corrupt_baselines -= 1
			corrupted_baselines += 1
	other.message_received.emit.call_deferred(peer_id,channel,bytes.duplicate())
	return _ok()

func local_peer_id() -> int: return peer_id
func invite() -> Dictionary:
	invite_calls += 1
	return _ok()
func reject_peer(_peer: int) -> void: close()
func close() -> void:
	if not linked: return
	linked = false
	other.linked = false
	other.disconnected.emit(peer_id)
	disconnected.emit(other.peer_id)
func _ok() -> Dictionary: return {"ok":true,"code":"OK","value":null}
