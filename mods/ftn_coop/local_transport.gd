extends Node

# Diagnostic transport only. It cannot bind or connect outside this computer.
signal hosted(lobby_id: int)
signal connected(peer_id: int)
signal disconnected(peer_id: int)
signal failed(code: String)
signal message_received(peer_id: int, channel: int, bytes: PackedByteArray)
signal invite_received(lobby_id: int)

var port := 27641
var _peer: ENetMultiplayerPeer
var _host := false
var _epoch := 0
var _waiting := 0.0
var _peers: Dictionary = {}
var _polling := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func host(limit: int) -> Dictionary:
	if limit!=4 or port<1024 or port>65535: return _error("LIMIT_INVALID")
	close()
	_host = true
	_peer = ENetMultiplayerPeer.new()
	_peer.set_bind_ip("127.0.0.1")
	if _peer.create_server(port,3,2)!=OK:
		close()
		return _error("PORT_UNAVAILABLE")
	_wire()
	_emit_hosted.call_deferred(_epoch)
	return _ok()

func join(lobby_id: int) -> Dictionary:
	if lobby_id!=1 or port<1024 or port>65535: return _error("LOBBY_INVALID")
	close()
	_peer = ENetMultiplayerPeer.new()
	if _peer.create_client("127.0.0.1",port,2)!=OK:
		close()
		return _error("CONNECTION_FAILED")
	_wire()
	return _ok()

func _wire() -> void:
	_peer.peer_connected.connect(_on_connected.bind(_epoch))
	_peer.peer_disconnected.connect(_on_disconnected.bind(_epoch))

func _emit_hosted(epoch: int) -> void:
	if epoch==_epoch and _peer!=null and _host: hosted.emit(1)

func _on_connected(peer: int, epoch: int) -> void:
	if epoch!=_epoch or _peers.has(peer): return
	_peers[peer] = true
	connected.emit(peer)

func _on_disconnected(peer: int, epoch: int) -> void:
	if epoch!=_epoch or not _peers.has(peer): return
	_peers.erase(peer)
	disconnected.emit(peer)

func local_peer_id() -> int:
	return _peer.get_unique_id() if _peer!=null else 0

func send(target: int, channel: int, bytes: PackedByteArray, reliable: bool) -> Dictionary:
	if _peer==null or _peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED or not _peers.has(target): return _error("NOT_CONNECTED")
	if target<=0 or channel not in [0,1] or bytes.is_empty() or bytes.size()>65536: return _error("PACKET_INVALID")
	_peer.set_target_peer(target)
	_peer.transfer_channel = channel
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	return _ok() if _peer.put_packet(bytes)==OK else _error("SEND_FAILED")

func invite() -> Dictionary:
	return _error("LOCAL_TEST_ONLY")

func reject_peer(peer: int) -> void:
	if _peer==null or not _peers.has(peer): return
	_peer.disconnect_peer(peer,true)
	_on_disconnected(peer,_epoch)

func close() -> void:
	_epoch += 1
	var closing_peer := _peer
	_peer = null
	if closing_peer!=null:
		# Disconnect callbacks can run inside ENet poll; release its native host later.
		if _polling: closing_peer.close.call_deferred()
		else: closing_peer.close()
	_host = false
	_peers.clear()
	_waiting = 0.0

func _process(delta: float) -> void:
	if _peer==null: return
	var polled_peer := _peer
	_polling = true
	polled_peer.poll()
	_polling = false
	if _peer!=polled_peer: return # A callback can close or replace the session.
	var status := _peer.get_connection_status()
	if not _host and status!=MultiplayerPeer.CONNECTION_CONNECTED:
		_waiting += delta
		if status==MultiplayerPeer.CONNECTION_DISCONNECTED or _waiting>15.0:
			close()
			failed.emit("HOST_LEFT")
		return
	for index in range(64):
		if _peer==null or _peer.get_available_packet_count()==0: break
		var source := _peer.get_packet_peer()
		var channel := _peer.get_packet_channel()
		var bytes := _peer.get_packet()
		if source<=0 or channel not in [0,1] or bytes.is_empty() or bytes.size()>65536: continue
		message_received.emit(source,channel,bytes)

func _ok() -> Dictionary: return {"ok":true,"code":"OK","value":null}
func _error(code: String) -> Dictionary: return {"ok":false,"code":code,"value":null}
