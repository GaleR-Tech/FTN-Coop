extends Node

signal problem(code: String)
signal pose_received(peer_id: int, pose: Dictionary)
signal stopped
signal action_result(sequence: int, ok: bool, code: String)
signal load_progress(stage: String, received_bytes: int, total_bytes: int)

var session: Node
var world_sync: Node
var connection_id := ""
var pose_stream_enabled := true
var save_session: Node
var _transport: Node
var _adapter: RefCounted
var _protocol: RefCounted
var _receiver: Node
var _pending: Dictionary = {}
var _preparing: Dictionary = {}
var _connections: Dictionary = {}
var _peer_epochs: Dictionary = {}
var _tx: Array[Dictionary] = []
var _epoch := 0
var _sequence := 0
var _poll_due := 0.0
var _pose_due := 0.0
var _loading := false
var _baseline_received := false
var _leaving := false
var _resync_pending := false
var _resync_attempts := 0
var _world_retries: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(transport: Node, adapter: RefCounted, build: String, version: String) -> void:
	_transport = transport
	_adapter = adapter
	var base: String = get_script().resource_path.get_base_dir()
	_protocol = load(base+"/protocol.gd").new()
	session = load(base+"/session.gd").new()
	world_sync = load(base+"/world_sync.gd").new()
	_receiver = load(base+"/snapshot_transfer.gd").new()
	save_session = load(base+"/save_session.gd").new()
	for node in [session,world_sync,_receiver,save_session]: add_child(node)
	save_session.configure(adapter)
	session.configure(transport,build,version)
	session.outgoing.connect(_on_session_outgoing)
	session.state_changed.connect(_on_state_changed)
	session.roster_changed.connect(_on_roster_changed)
	world_sync.configure(adapter,false)
	world_sync.confirmed.connect(_on_confirmed)
	world_sync.resync_required.connect(_request_resync)
	_receiver.completed.connect(_on_snapshot_completed)
	_receiver.failed.connect(func(_code: String): _request_resync())
	_receiver.progress_changed.connect(_on_transfer_progress)
	transport.message_received.connect(_on_message)
	transport.disconnected.connect(_on_disconnected)
	transport.failed.connect(func(code: String): _fail(code))

func host() -> Dictionary:
	leave()
	if save_session.closing or save_session.guest_open: return _error("GUEST_SESSION_BUSY")
	return session.host()

func join(lobby_id: int) -> Dictionary:
	leave()
	if save_session.closing or save_session.guest_open: return _error("GUEST_SESSION_BUSY")
	return session.join(lobby_id)

func leave() -> void:
	if _leaving or session==null: return
	_leaving = true
	_epoch += 1
	save_session.close()
	_tx.clear()
	_preparing.clear()
	for record in _pending.values(): record.transfer.queue_free()
	_pending.clear()
	for peer in _connections: _adapter.remove_actor(peer)
	_connections.clear()
	_peer_epochs.clear()
	_world_retries.clear()
	connection_id = ""
	_loading = false
	_baseline_received = false
	_resync_pending = false
	_resync_attempts = 0
	_sequence = 0
	_receiver.cancel()
	load_progress.emit("idle",0,0)
	session.leave()
	world_sync.configure(_adapter,false)
	_leaving = false
	stopped.emit()

func request_action(kind: String, payload: Dictionary) -> Dictionary:
	if session.is_host or session.state!=session.State.PLAYING: return _error("PEER_NOT_READY")
	_sequence += 1
	var body := {"sequence":_sequence,"kind":kind,"payload":payload}
	if _adapter.has_method("read_local_pose"):
		var pose: Dictionary = _adapter.read_local_pose()
		if not pose.ok: return pose
		body.pose = pose.value
	var queued: Dictionary = _queue(1,"ACTION",body)
	return {"ok":true,"code":"OK","value":{"sequence":_sequence}} if queued.ok else queued

func _on_state_changed() -> void:
	if _leaving: return
	if not session.is_host:
		if session.state==session.State.SYNCING: load_progress.emit("waiting",0,0)
		elif session.state==session.State.PLAYING: load_progress.emit("ready",0,0)
	if session.is_host and session.state==session.State.LOBBY:
		world_sync.configure(_adapter,true)
		world_sync.set_ready(1,true)
		session.mark_world_ready(1)

func _on_session_outgoing(peer: int, kind: String, body: Dictionary) -> void:
	if kind=="WELCOME" and not _connections.has(peer):
		_connections[peer] = Crypto.new().generate_random_bytes(16).hex_encode()
	_queue(peer,kind,body)

func _queue(peer: int, kind: String, body: Dictionary, reliable: bool=true) -> Dictionary:
	if _tx.size()>=8192: return _error("SEND_LIMIT")
	var data := body.duplicate(true)
	data._connection = _connections.get(peer,"") if session.is_host else connection_id
	var cookie: String = "" if kind=="HELLO" else session.session_id
	var encoded: Dictionary = _protocol.encode({"protocol":1,"type":kind,"session":cookie,"body":data})
	if not encoded.ok: return encoded
	_tx.append({"peer":peer,"channel":0 if reliable else 1,"bytes":encoded.value,"reliable":reliable})
	return _ok()

func _process(delta: float) -> void:
	if session==null or _leaving: return
	_poll_due += delta
	_pose_due += delta
	if session.state==session.State.PLAYING:
		if session.is_host and _poll_due>=0.2:
			_poll_due = 0.0
			world_sync.poll()
			if not _adapter.last_sync_error.is_empty():
				_fail(_adapter.last_sync_error)
				return
		elif not session.is_host: _adapter.pump_guest_visuals()
		if _pose_due>=1.0/15.0 and pose_stream_enabled and _adapter.has_method("read_local_pose"):
			_pose_due = 0.0
			var pose: Dictionary = _adapter.read_local_pose()
			if pose.ok:
				if session.is_host: _broadcast_pose(1,pose.value)
				else: _queue(1,"POSE",{"pose":pose.value},false)
	for peer in _pending.keys():
		_pending[peer].age += delta
		if _pending[peer].age>120.0: _fail("TRANSFER_TIMEOUT",peer)
	for index in range(12):
		if _tx.is_empty(): break
		var packet: Dictionary = _tx.pop_front()
		var sent: Dictionary = _transport.send(packet.peer,packet.channel,packet.bytes,packet.reliable)
		if not sent.ok: _fail(sent.code,packet.peer if session.is_host else 0)

func _on_message(peer: int, channel: int, bytes: PackedByteArray) -> void:
	if _leaving or session.state==session.State.OFFLINE: return
	var decoded: Dictionary = _protocol.decode(bytes)
	if not decoded.ok:
		if session.is_host: _fail("INVALID_PAYLOAD",peer)
		return
	var message: Dictionary = decoded.value
	if channel!=(1 if message.type=="POSE" else 0): return
	var body: Dictionary = message.body
	if session.is_host:
		if message.type=="HELLO":
			var accepted: Dictionary = session.accept_hello(peer,body)
			if not accepted.ok:
				_queue(peer,"REJECT",{"code":accepted.code})
				# Deliver rejection before disconnecting on the next frame.
				return
			if not _pending.has(peer) and not _preparing.has(peer) and session.roster[peer].state!="playing": _start_world(peer)
			return
		if message.session!=session.session_id or not _connections.has(peer) or body.get("_connection")!=_connections[peer]: return
		if not session.roster.has(peer) or not session.roster[peer].accepted: return
		match message.type:
			"WORLD_READY": _finish_world(peer,body)
			"WORLD_REQUEST":
				if not _preparing.has(peer):
					_world_retries[peer] = int(_world_retries.get(peer,0))+1
					if _world_retries[peer]>3:
						_fail("RESYNC_FAILED",peer)
						return
					if _pending.has(peer):
						_pending[peer].transfer.queue_free()
						_pending.erase(peer)
					# No pieces of the replaced baseline may remain in our queue.
					_tx = _tx.filter(func(packet: Dictionary): return packet.peer!=peer)
					session.roster[peer].state = "syncing"
					world_sync.set_ready(peer,false)
					_start_world(peer)
			"ACTION":
				if typeof(body.get("sequence"))!=TYPE_INT or not body.get("kind") is String or not body.get("payload") is Dictionary: return
				if session.roster[peer].state!="playing":
					_queue(peer,"ACTION_RESULT",{"sequence":body.sequence,"ok":false,"code":"PEER_NOT_READY"})
					return
				if body.has("pose") and _adapter.has_method("update_actor_pose"):
					var updated: Dictionary = _adapter.update_actor_pose(peer,body.pose) if body.pose is Dictionary else _error("POSE_INVALID")
					if not updated.ok:
						_queue(peer,"ACTION_RESULT",{"sequence":body.sequence,"ok":false,"code":updated.code})
						return
				var applied: Dictionary = world_sync.submit_action(peer,body.sequence,body.kind,body.payload)
				_queue(peer,"ACTION_RESULT",{"sequence":body.sequence,"ok":applied.ok,"code":applied.code})
			"POSE":
				if session.roster[peer].state!="playing" or not body.get("pose") is Dictionary: return
				if _adapter.has_method("update_actor_pose"):
					if not _adapter.update_actor_pose(peer,body.pose).ok: return
				pose_received.emit(peer,body.pose)
				_broadcast_pose(peer,body.pose)
		return
	if peer!=1: return
	if message.type=="REJECT":
		if not session.session_id.is_empty() and message.session!=session.session_id: return
		_fail(body.get("code","JOIN_REFUSED"))
		return
	if message.type=="WELCOME":
		if message.session!=body.get("session_id") or not _protocol.valid_id(body.get("_connection")): return
		var welcomed: Dictionary = session.accept_welcome(peer,body)
		if not welcomed.ok: return
		connection_id = body._connection
		_receiver.configure(session.session_id)
		return
	if message.session!=session.session_id or body.get("_connection")!=connection_id or connection_id.is_empty(): return
	match message.type:
		"SNAPSHOT_BEGIN", "SNAPSHOT_CHUNK":
			if message.type=="SNAPSHOT_BEGIN": _resync_pending = false
			var received: Dictionary = _receiver.receive(1,body)
			if not received.ok and received.code not in ["STALE_REVISION","TRANSFER_MISMATCH"]: _request_resync()
		"EVENT": world_sync.accept_event(1,body)
		"WORLD_READY":
			if body.get("stage")=="caught_up" and body.get("revision")==world_sync.revision:
				_resync_attempts = 0
				session.mark_world_ready(_transport.local_peer_id())
		"ROSTER": session.accept_welcome(1,{"session_id":session.session_id,"player_id":_transport.local_peer_id(),"roster":body.get("roster")})
		"POSE":
			if typeof(body.get("peer"))==TYPE_INT and body.get("pose") is Dictionary and session.roster.has(body.peer): pose_received.emit(body.peer,body.pose)
		"ACTION_RESULT":
			if typeof(body.get("sequence"))==TYPE_INT and body.get("ok") is bool and body.get("code") is String: action_result.emit(body.sequence,body.ok,body.code)
			if body.get("ok")==false and body.get("code") is String: problem.emit(body.code)

func _start_world(peer: int) -> void:
	var epoch := _epoch
	var peer_epoch: int = _peer_epochs.get(peer,0)
	_preparing[peer] = peer_epoch
	var actor: Dictionary = await _adapter.prepare_actor(peer)
	if _preparing.get(peer,-1)==peer_epoch: _preparing.erase(peer)
	if epoch!=_epoch or peer_epoch!=_peer_epochs.get(peer,0) or not session.roster.has(peer):
		return
	if not actor.ok:
		_fail(actor.code,peer)
		return
	var captured: Dictionary = _adapter.capture_world()
	if not captured.ok:
		_fail(captured.code,peer)
		return
	world_sync.poll()
	world_sync.checkpoint()
	var frame: Dictionary = _adapter._live_frame()
	if frame.is_empty():
		_fail(_adapter.last_sync_error if not _adapter.last_sync_error.is_empty() else "WORLD_NOT_READY",peer)
		return
	var spawn: Transform3D = actor.value.global_transform if actor.value is Node3D else Transform3D.IDENTITY
	var transfer: Node = load(get_script().resource_path.get_base_dir()+"/snapshot_transfer.gd").new()
	add_child(transfer)
	var begun: Dictionary = transfer.begin({"mode":"world","native":captured.value,"frame":frame,"spawn":spawn},session.session_id,world_sync.revision)
	if not begun.ok:
		transfer.queue_free()
		_fail(begun.code,peer)
		return
	_pending[peer] = {"transfer":transfer,"revision":world_sync.revision,"age":0.0}
	for packet in begun.value.frames:
		var queued: Dictionary = _queue(peer,packet.kind,packet)
		if not queued.ok:
			_fail(queued.code,peer)
			break

func _on_transfer_progress(received: int, total: int) -> void:
	if not session.is_host and session.state==session.State.SYNCING and not _baseline_received:
		load_progress.emit("receiving",received,total)

func _on_snapshot_completed(state: Dictionary, revision: int) -> void:
	if session.is_host: return
	if state.get("mode")=="event" and state.get("event") is Dictionary:
		world_sync.accept_event(1,state.event)
		return
	if _loading or state.get("mode")!="world" or not state.get("native") is Dictionary or not state.get("frame") is Dictionary: return
	_baseline_received = true
	_loading = true
	load_progress.emit("loading",0,0)
	var epoch := _epoch
	var restored: Dictionary = await save_session.open_guest(state.native,session.session_id)
	if epoch!=_epoch: return
	_loading = false
	if not restored.ok:
		_fail(restored.code)
		return
	var applied: Dictionary = _adapter.apply_confirmed_event({"patch":state.frame})
	if not applied.ok:
		_request_resync()
		return
	if state.get("spawn") is Transform3D and _adapter.has_method("set_local_spawn"): _adapter.set_local_spawn(state.spawn)
	world_sync.accept_baseline(revision)
	load_progress.emit("catching_up",0,0)
	_queue(1,"WORLD_READY",{"stage":"baseline","revision":revision})

func _finish_world(peer: int, body: Dictionary) -> void:
	if not _pending.has(peer) or body.get("stage")!="baseline" or body.get("revision")!=_pending[peer].revision: return
	var record: Dictionary = _pending[peer]
	_pending.erase(peer)
	for event in record.transfer.buffered_events(): _queue_event(peer,event)
	record.transfer.queue_free()
	world_sync.set_ready(peer,true)
	_world_retries.erase(peer)
	session.mark_world_ready(peer)
	_queue(peer,"WORLD_READY",{"stage":"caught_up","revision":world_sync.revision})

func _on_confirmed(event: Dictionary) -> void:
	for peer in session.roster:
		if peer==1 or not session.roster[peer].accepted: continue
		if _pending.has(peer):
			var buffered: Dictionary = _pending[peer].transfer.buffer_event(event)
			if not buffered.ok: _fail(buffered.code,peer)
		elif session.roster[peer].state=="playing": _queue_event(peer,event)

func _queue_event(peer: int, event: Dictionary) -> void:
	var queued := _queue(peer,"EVENT",event)
	if queued.ok: return
	if queued.code!="PAYLOAD_TOO_LARGE":
		_fail(queued.code,peer)
		return
	var transfer: Node = load(get_script().resource_path.get_base_dir()+"/snapshot_transfer.gd").new()
	var begun: Dictionary = transfer.begin({"mode":"event","event":event},session.session_id,event.revision)
	transfer.free()
	if not begun.ok:
		_fail(begun.code,peer)
		return
	for packet in begun.value.frames:
		var queued_packet: Dictionary = _queue(peer,packet.kind,packet)
		if not queued_packet.ok:
			_fail(queued_packet.code,peer)
			break

func _request_resync() -> void:
	if _leaving or session.is_host or _resync_pending or connection_id.is_empty(): return
	_resync_attempts += 1
	if _resync_attempts>3:
		_fail("RESYNC_FAILED")
		return
	_resync_pending = true
	_baseline_received = false
	_receiver.cancel()
	load_progress.emit("waiting",0,0)
	session._set_state(session.State.SYNCING)
	_queue(1,"WORLD_REQUEST",{})

func _on_roster_changed() -> void:
	if not session.is_host or _leaving: return
	for peer in session.roster:
		if peer!=1 and session.roster[peer].accepted and _connections.has(peer): _queue(peer,"ROSTER",{"roster":session.roster.values()})

func _broadcast_pose(peer: int, pose: Dictionary) -> void:
	for target in session.roster:
		if target!=1 and target!=peer and session.roster[target].state=="playing": _queue(target,"POSE",{"peer":peer,"pose":pose},false)

func _on_disconnected(peer: int) -> void:
	if _leaving: return
	if not session.is_host and peer==1:
		_fail("HOST_LEFT")
		return
	_peer_epochs[peer] = int(_peer_epochs.get(peer,0))+1
	_world_retries.erase(peer)
	_preparing.erase(peer)
	_connections.erase(peer)
	if _pending.has(peer):
		_pending[peer].transfer.queue_free()
		_pending.erase(peer)
	_tx = _tx.filter(func(packet: Dictionary): return packet.peer!=peer)
	world_sync.remove_peer(peer)
	_adapter.remove_actor(peer)

func _fail(code: String, peer: int=0) -> void:
	if _leaving: return
	problem.emit(code)
	if session.is_host and peer>1: _transport.reject_peer(peer)
	else: leave()

func _ok() -> Dictionary: return {"ok":true,"code":"OK","value":null}
func _error(code: String) -> Dictionary: return {"ok":false,"code":code,"value":null}
