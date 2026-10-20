extends Node

signal problem(code: String)
signal pose_received(peer_id: int, pose: Dictionary)
signal stopped
signal action_result(sequence: int, ok: bool, code: String)
signal load_progress(stage: String, received_bytes: int, total_bytes: int)
signal markers_changed(rows: Array)
signal player_status_changed(rows: Dictionary)

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
var version_mismatch: Dictionary = {}
var recovery_reason := ""
var _mod_version := ""
var _sync_wait := 0.0
var _markers: RefCounted
var _status: RefCounted
var _player_status: Dictionary = {}
var _peer_positions: Dictionary = {}
var _peer_stages: Dictionary = {}
var _status_due := 3.0
var _sent_stage := ""
var _status_announced_at: Dictionary = {}
var _last_equipment_sequence := 0
var _last_build_sequence := 0
var _equipment_epochs: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(transport: Node, adapter: RefCounted, build: String, version: String) -> void:
	_transport = transport
	_adapter = adapter
	_mod_version = version
	var base: String = get_script().resource_path.get_base_dir()
	_protocol = load(base+"/protocol.gd").new()
	_markers = load(base+"/marker_state.gd").new()
	_status = load(base+"/connection_status.gd").new()
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
	_receiver.failed.connect(func(code: String): _request_resync(code))
	_receiver.progress_changed.connect(_on_transfer_progress)
	transport.message_received.connect(_on_message)
	transport.disconnected.connect(_on_disconnected)
	transport.failed.connect(_on_transport_failed)
	load_progress.connect(_send_load_status)

func host() -> Dictionary:
	leave()
	recovery_reason = ""
	if save_session.closing or save_session.guest_open: return _error("GUEST_SESSION_BUSY")
	return session.host()

func join(lobby_id: int) -> Dictionary:
	leave()
	recovery_reason = ""
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
	if _adapter!=null and _adapter.has_method("stop_shared_tools"): _adapter.stop_shared_tools()
	_connections.clear()
	_peer_epochs.clear()
	_world_retries.clear()
	_markers.clear()
	_status.clear()
	_player_status.clear()
	_peer_positions.clear()
	_peer_stages.clear()
	_status_announced_at.clear()
	_status_due = 3.0
	_sent_stage = ""
	markers_changed.emit([])
	player_status_changed.emit({})
	version_mismatch.clear()
	connection_id = ""
	_loading = false
	_baseline_received = false
	_resync_pending = false
	_resync_attempts = 0
	_sequence = 0
	_last_equipment_sequence = 0
	_last_build_sequence = 0
	_equipment_epochs.clear()
	_sync_wait = 0.0
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
		body.pose = _local_equipment_pose(pose.value)
	var queued: Dictionary = _queue(1,"ACTION",body)
	return {"ok":true,"code":"OK","value":{"sequence":_sequence}} if queued.ok else queued

func _on_state_changed() -> void:
	if _leaving: return
	if not session.is_host:
		if session.state==session.State.SYNCING:
			_sync_wait = 0.0
			load_progress.emit("waiting",0,0)
		elif session.state==session.State.PLAYING: load_progress.emit("ready",0,0)
	if session.is_host and session.state==session.State.LOBBY:
		if _adapter.has_method("start_shared_tools"): _adapter.start_shared_tools()
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
	_markers.advance(delta)
	_status_due += delta
	if session.is_host and session.state!=session.State.OFFLINE and _status_due>=3.0:
		_status_due = 0.0
		for peer in session.roster:
			if peer==1 or not session.roster[peer].accepted or not _connections.has(peer): continue
			var probe: Dictionary = _status.begin(peer,Time.get_ticks_msec())
			if probe.ok: _queue(peer,"STATUS_PROBE",{"token":probe.value})
		_publish_collaboration()
	if _adapter.has_method("maintain_shared_settings"):
		var maintained: Dictionary = _adapter.maintain_shared_settings()
		if not maintained.ok:
			_fail(maintained.code)
			return
	if not session.is_host and session.state==session.State.SYNCING and not _loading:
		_sync_wait += delta
		if _sync_wait >= (15.0 if connection_id.is_empty() else 120.0):
			_fail("CONNECT_TIMEOUT" if connection_id.is_empty() else "TRANSFER_TIMEOUT")
			return
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
				else: _queue(1,"POSE",{"pose":_local_equipment_pose(pose.value)},false)
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
				var rejection := {"code":accepted.code}
				if accepted.code=="MOD_MISMATCH": rejection.required_mod_version = _mod_version
				_queue(peer,"REJECT",rejection)
				# Deliver rejection before disconnecting on the next frame.
				return
			_status_due = 3.0
			if not _pending.has(peer) and not _preparing.has(peer) and session.roster[peer].state!="playing": _start_world(peer)
			return
		if message.session!=session.session_id or not _connections.has(peer) or body.get("_connection")!=_connections[peer]: return
		if not session.roster.has(peer) or not session.roster[peer].accepted: return
		match message.type:
			"MARKER_REQUEST":
				if session.roster[peer].state=="playing" and body.get("position") is Vector3 and body.get("kind") is String and _peer_positions.has(peer):
					var placed: Dictionary = _markers.place(peer,body.position,body.kind,_peer_positions[peer])
					if placed.ok: _publish_collaboration()
			"STATUS_REPLY":
				if typeof(body.get("token"))==TYPE_INT and _status.accept_reply(peer,body.token,Time.get_ticks_msec()).ok: _publish_collaboration()
			"LOAD_STATUS":
				var now := Time.get_ticks_msec()
				if session.roster[peer].state!="playing" and now-int(_status_announced_at.get(peer,-1000))>=200 and body.get("stage") in ["waiting","receiving","loading","catching_up"] and _peer_stages.get(peer,"")!=body.stage:
					_status_announced_at[peer] = now
					_peer_stages[peer] = body.stage
					_publish_collaboration()
			"WORLD_READY": _finish_world(peer,body)
			"WORLD_REQUEST":
				if not _preparing.has(peer):
					print("[FTN-Coop] Guest requested a replacement world snapshot")
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
					var updated: Dictionary = _update_actor_pose(peer,body.pose) if body.pose is Dictionary else _error("POSE_INVALID")
					if not updated.ok:
						_queue(peer,"ACTION_RESULT",{"sequence":body.sequence,"ok":false,"code":updated.code})
						return
					if body.pose.get("position") is Vector3 and body.pose.position.is_finite(): _peer_positions[peer] = body.pose.position
				var applied: Dictionary = world_sync.submit_action(peer,body.sequence,body.kind,body.payload)
				var result := {"sequence":body.sequence,"ok":applied.ok,"code":applied.code}
				if applied.ok and body.kind in ["purchase","item_interact"] and _adapter.has_method("read_actor_equipment"):
					result.equipment = _adapter.read_actor_equipment(peer)
					_equipment_epochs[peer] = maxi(int(_equipment_epochs.get(peer,0)),body.sequence)
				if applied.ok and body.kind=="place" and _adapter.has_method("read_actor_build_state"):
					result.build = _adapter.read_actor_build_state(peer)
				_queue(peer,"ACTION_RESULT",result)
			"POSE":
				if session.roster[peer].state!="playing" or not body.get("pose") is Dictionary: return
				if _adapter.has_method("update_actor_pose"):
					if not _update_actor_pose(peer,body.pose).ok: return
				if body.pose.get("position") is Vector3 and body.pose.position.is_finite(): _peer_positions[peer] = body.pose.position
				pose_received.emit(peer,body.pose)
				_broadcast_pose(peer,body.pose)
		return
	if peer!=1: return
	if message.type=="REJECT":
		if not session.session_id.is_empty() and message.session!=session.session_id: return
		if body.get("code")=="MOD_MISMATCH": _set_version_mismatch(body.get("required_mod_version"))
		_fail(body.get("code","JOIN_REFUSED"))
		return
	if message.type=="WELCOME":
		if message.session!=body.get("session_id") or not _protocol.valid_id(body.get("_connection")): return
		var welcomed: Dictionary = session.accept_welcome(peer,body)
		if not welcomed.ok:
			if welcomed.code=="MOD_MISMATCH":
				_set_version_mismatch(body.get("mod_version"))
				_fail(welcomed.code)
			return
		connection_id = body._connection
		_sync_wait = 0.0
		_receiver.configure(session.session_id)
		return
	if message.session!=session.session_id or body.get("_connection")!=connection_id or connection_id.is_empty(): return
	match message.type:
		"MARKERS":
			if _markers.accept_snapshot(body.get("rows")).ok: markers_changed.emit(_markers.snapshot())
		"STATUS_PROBE":
			if typeof(body.get("token"))==TYPE_INT and body.token>0: _queue(1,"STATUS_REPLY",{"token":body.token})
		"PLAYER_STATUS": _accept_player_status(body.get("rows"))
		"SNAPSHOT_BEGIN", "SNAPSHOT_CHUNK":
			if message.type=="SNAPSHOT_BEGIN": _resync_pending = false
			var received: Dictionary = _receiver.receive(1,body)
			if not received.ok and received.code not in ["STALE_REVISION","TRANSFER_MISMATCH"]: _request_resync(received.code)
		"EVENT":
			# Reliable packets already in flight can belong to the replaced world.
			# The host buffers new events until this baseline has finished loading.
			if not _baseline_received or _loading: return
			var applied: Dictionary = world_sync.accept_event(1,body)
			if applied.ok: _sync_wait = 0.0
		"WORLD_READY":
			if body.get("stage")=="caught_up" and body.get("revision")==world_sync.revision:
				_resync_attempts = 0
				session.mark_world_ready(_transport.local_peer_id())
		"ROSTER": session.accept_welcome(1,{"session_id":session.session_id,"player_id":_transport.local_peer_id(),"roster":body.get("roster"),"mod_version":_mod_version})
		"POSE":
			if typeof(body.get("peer"))==TYPE_INT and body.get("pose") is Dictionary and session.roster.has(body.peer): pose_received.emit(body.peer,body.pose)
		"ACTION_RESULT":
			if typeof(body.get("sequence"))!=TYPE_INT or body.sequence<=0 or not body.get("ok") is bool or not body.get("code") is String: return
			if body.ok and body.sequence>_last_equipment_sequence and body.get("equipment") is Dictionary and _adapter.has_method("apply_local_equipment"):
				if _adapter.apply_local_equipment(body.equipment).ok: _last_equipment_sequence = body.sequence
			if body.ok and body.sequence>_last_build_sequence and body.get("build") is Dictionary and _adapter.has_method("apply_local_build_state"):
				_last_build_sequence = body.sequence
				_adapter.apply_local_build_state(body.build)
			if typeof(body.get("sequence"))==TYPE_INT and body.get("ok") is bool and body.get("code") is String: action_result.emit(body.sequence,body.ok,body.code)
			if body.get("ok")==false and body.get("code") is String: problem.emit(body.code)

func _local_equipment_pose(pose: Dictionary) -> Dictionary:
	var tagged := pose.duplicate()
	tagged.equipment_epoch = _last_equipment_sequence
	return tagged

func _update_actor_pose(peer: int, pose: Dictionary) -> Dictionary:
	var epoch: Variant = pose.get("equipment_epoch",0)
	if typeof(epoch)!=TYPE_INT or epoch<0 or epoch>9007199254740991: return _error("POSE_INVALID")
	var confirmed := pose.duplicate()
	confirmed.erase("equipment_epoch")
	# Movement uses a separate unreliable channel. A late packet must not undo
	# a host-confirmed purchase/drop while its result is reaching the guest.
	if epoch<int(_equipment_epochs.get(peer,0)): confirmed.erase("tool")
	return _adapter.update_actor_pose(peer,confirmed)

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
	_peer_positions[peer] = spawn.origin
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
	_sync_wait = 0.0
	if not session.is_host and session.state==session.State.SYNCING and not _baseline_received:
		load_progress.emit("receiving",received,total)

func _on_snapshot_completed(state: Dictionary, revision: int) -> void:
	if session.is_host: return
	if state.get("mode")=="event" and state.get("event") is Dictionary:
		if not _baseline_received or _loading: return
		world_sync.accept_event(1,state.event)
		return
	if _loading or state.get("mode")!="world" or not state.get("native") is Dictionary or not state.get("frame") is Dictionary: return
	if _adapter.has_method("apply_shared_settings"):
		var settings: Dictionary = _adapter.apply_shared_settings(state.frame.get("settings"))
		if not settings.ok:
			_fail(settings.code)
			return
	_baseline_received = true
	_loading = true
	load_progress.emit("loading",0,0)
	print("[FTN-Coop] Loading a guest world snapshot")
	var epoch := _epoch
	var restored: Dictionary = await save_session.open_guest(state.native,session.session_id)
	if epoch!=_epoch: return
	_loading = false
	_sync_wait = 0.0
	if not restored.ok:
		_fail(restored.code)
		return
	if _adapter.has_method("set_local_peer"): _adapter.set_local_peer(_transport.local_peer_id())
	var applied: Dictionary = _adapter.apply_confirmed_event({"patch":state.frame})
	if not applied.ok:
		_request_resync(applied.code)
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
	_publish_collaboration()

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

func _request_resync(reason: String="") -> void:
	if _leaving or session.is_host or _resync_pending or connection_id.is_empty(): return
	if reason.is_empty(): reason = world_sync.last_resync_reason
	recovery_reason = reason if not reason.is_empty() else "UNKNOWN"
	print("[FTN-Coop] World resynchronization requested: "+(reason if not reason.is_empty() else "UNKNOWN"))
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
	for departed in _peer_stages.keys():
		if not session.roster.has(departed):
			_peer_stages.erase(departed)
			_status.remove_peer(departed)
			_markers.remove_peer(departed)
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
	_markers.remove_peer(peer)
	_status.remove_peer(peer)
	_peer_positions.erase(peer)
	_peer_stages.erase(peer)
	_status_announced_at.erase(peer)
	_preparing.erase(peer)
	_connections.erase(peer)
	if _pending.has(peer):
		_pending[peer].transfer.queue_free()
		_pending.erase(peer)
	_tx = _tx.filter(func(packet: Dictionary): return packet.peer!=peer)
	world_sync.remove_peer(peer)
	_equipment_epochs.erase(peer)
	_adapter.remove_actor(peer)
	if session.is_host: _publish_collaboration()

func request_marker(position: Vector3, kind: String) -> Dictionary:
	if session.state!=session.State.PLAYING: return _error("PEER_NOT_READY")
	if not position.is_finite() or kind not in ["point","build","needle","help"]: return _error("MARKER_INVALID")
	if not session.is_host: return _queue(1,"MARKER_REQUEST",{"position":position,"kind":kind})
	var pose: Dictionary = _adapter.read_local_pose()
	if not pose.ok or not pose.value.get("position") is Vector3: return _error("WORLD_NOT_READY")
	var result: Dictionary = _markers.place(1,position,kind,pose.value.position)
	if result.ok: _publish_collaboration()
	return result

func collaboration_snapshot() -> Dictionary:
	return {"markers":_markers.snapshot() if _markers!=null else [],"players":_player_status.duplicate(true)}

func _publish_collaboration() -> void:
	if not session.is_host or _leaving: return
	var rows: Array = []
	_player_status.clear()
	for peer in session.roster:
		var member: Dictionary = session.roster[peer]
		var stage: String = "playing" if member.state=="playing" else ("connecting" if not member.accepted else _peer_stages.get(peer,"waiting"))
		var row := {"peer":peer,"state":stage,"latency_ms":-1 if peer==1 else _status.snapshot(peer,Time.get_ticks_msec()).latency_ms}
		_player_status[peer] = row
		rows.append(row)
	var markers: Array = _markers.snapshot()
	markers_changed.emit(markers)
	player_status_changed.emit(_player_status.duplicate(true))
	for peer in session.roster:
		if peer!=1 and session.roster[peer].accepted and _connections.has(peer):
			_queue(peer,"MARKERS",{"rows":markers})
			_queue(peer,"PLAYER_STATUS",{"rows":rows})

func _accept_player_status(rows: Variant) -> void:
	if not rows is Array or rows.size()>4: return
	var checked := {}
	for row in rows:
		if not row is Dictionary or row.size()!=3 or typeof(row.get("peer"))!=TYPE_INT or not session.roster.has(row.peer) or checked.has(row.peer): return
		if row.get("state") not in ["connecting","waiting","receiving","loading","catching_up","playing"] or typeof(row.get("latency_ms"))!=TYPE_INT or row.latency_ms < -1 or row.latency_ms>9000: return
		checked[row.peer] = row.duplicate()
	_player_status = checked
	player_status_changed.emit(checked.duplicate(true))

func _send_load_status(stage: String, _received: int, _total: int) -> void:
	if _leaving or session==null or session.is_host or connection_id.is_empty() or stage==_sent_stage: return
	if stage in ["waiting","receiving","loading","catching_up"]:
		_sent_stage = stage
		_queue(1,"LOAD_STATUS",{"stage":stage})

func _fail(code: String, peer: int=0) -> void:
	if _leaving: return
	problem.emit(code)
	if session.is_host and peer>1: _transport.reject_peer(peer)
	else: leave()

func _set_version_mismatch(required: Variant) -> void:
	var version: Script = load(get_script().resource_path.get_base_dir()+"/mod_version.gd")
	version_mismatch = {"required":version.safe_version(required)}

func _on_transport_failed(code: String) -> void:
	if code=="MOD_MISMATCH" and _transport.has_method("version_mismatch_details"):
		var details: Dictionary = _transport.version_mismatch_details()
		_set_version_mismatch(details.get("required"))
	_fail(code)

func _exit_tree() -> void:
	if _adapter!=null and _adapter.has_method("restore_shared_settings"):
		_adapter.restore_shared_settings()

func _ok() -> Dictionary: return {"ok":true,"code":"OK","value":null}
func _error(code: String) -> Dictionary: return {"ok":false,"code":code,"value":null}
