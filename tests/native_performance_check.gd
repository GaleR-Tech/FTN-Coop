# Real demo + normal playable-host runtime, using a copied save and loopback transport.
extends Node

class MeteredTransport extends "res://mods/ftn_coop/local_transport.gd":
	var sent_bytes := 0
	var sent_packets := 0
	var packet_sizes := []
	func send(target: int, channel: int, bytes: PackedByteArray, reliable: bool) -> Dictionary:
		var result := super.send(target,channel,bytes,reliable)
		if result.ok:
			sent_bytes += bytes.size()
			sent_packets += 1
			if packet_sizes.size()<20000: packet_sizes.append(bytes.size())
		return result

var _adapter: RefCounted
var _network: Node
var _runtime: Node
var _transport: MeteredTransport
var _directory := ""
var _role := ""
var _index := 0
var _count := 4
var _stage := "starting"
var _fatal := ""
var _done := false
var _history := {}
var _checks := {}
var _results := {}
var _frames := []
var _actions := []
var _latencies := []
var _last_probe := {}
var _frame_at := 0
var _report_at := 0
var _began := 0
var _measure_at := 0
var _duration := 60
var _snapshot_loads := 0
var _join_ms := 0

func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS

func run(base: String, args: PackedStringArray) -> Dictionary:
	_began = Time.get_ticks_msec()
	_role = _argument(args,"--ftn-role=","host")
	_index = _argument(args,"--ftn-index=","0").to_int()
	_count = _argument(args,"--ftn-count=","4").to_int()
	var game_build := _argument(args,"--ftn-build=","")
	if not load(base+"/game_bindings.gd").supports_build(game_build): return _finish("BUILD_UNVERIFIED")
	_checks.game_build = game_build
	_checks.render_backend = DisplayServer.get_name()
	_duration = _argument(args,"--ftn-performance-seconds=","60").to_int()
	_directory = OS.get_environment("FTN_COOP_TEST_OUTPUT").replace("\\","/")
	_adapter = load(base+"/performance_adapter.gd").new()
	_adapter.bind(get_tree().root)
	var saves: Node = _adapter.nodes.saves
	saves.call("use_scratch_dir","user://ftn_coop/tests/performance/world")
	saves.set("current_slot",1)
	if _role=="host":
		var source := "res://performance-slot.dat"
		_checks.source_sha256 = FileAccess.get_sha256(source)
		var path: String = saves.call("slot_path",1)
		if DirAccess.copy_absolute(source,path)!=OK: return _finish("COPY_SAVE_FAILED")
		saves.call("begin_load",1)
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		var deadline := Time.get_ticks_msec()+120000
		while Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
			var scene := get_tree().current_scene
			if scene!=null and scene.scene_file_path=="res://scenes/main.tscn" and bool(scene.get("_built")): break
		_adapter.bind(get_tree().root)
		_adapter.nodes.world.set("block_save",false)
		saves.set("block_save",false)
		_adapter.update_shared_setting("autosave",false)
		_checks.loaded_state = _adapter.nodes.state.call("to_dict")
		_checks.loaded_buildings = _adapter._live_frame().buildings.size()
		_checks.loaded_props = _adapter.nodes.props.call("to_array").size()
		_stage = "offline_baseline"
		_write("RUNNING")
		var baseline := []
		var previous := Time.get_ticks_usec()
		while Time.get_ticks_usec()-previous<1: await get_tree().process_frame
		var baseline_until := Time.get_ticks_msec()+10000
		while Time.get_ticks_msec()<baseline_until:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			baseline.append((now-previous)/1000.0)
			previous = now
		_checks.offline_frame = _stats(baseline)
	_transport = MeteredTransport.new()
	_transport.port = _argument(args,"--ftn-port=","27641").to_int()
	_runtime = load(base+"/coop_runtime.gd").new()
	add_child(_runtime)
	_runtime.configure(_adapter,_transport,game_build,str(load(base+"/bootstrap.gd").get_script_constant_map().get("VERSION","")))
	_network = _runtime.network
	_network.problem.connect(func(code: String):
		if not FileAccess.file_exists(_directory+"/stop.request"): _fatal = code
	)
	_network.load_progress.connect(func(stage: String, _received: int, _total: int):
		if stage=="loading": _snapshot_loads += 1
	)
	_network.action_result.connect(func(sequence: int, ok: bool, code: String): _results[sequence]={"ok":ok,"code":code})
	_network.world_sync.confirmed.connect(_observe)
	_adapter.applied.connect(_observe)
	var joined: Dictionary = _network.host() if _role=="host" else _network.join(1)
	if not joined.ok: return _finish(joined.code)
	_stage = "waiting"
	_write("RUNNING")
	if _role=="guest": _guest_actions()
	var until := Time.get_ticks_msec()+(_duration+900)*1000
	while Time.get_ticks_msec()<until and _fatal.is_empty():
		await get_tree().process_frame
		if FileAccess.file_exists(_directory+"/stop.request"): break
	if not _done and _fatal.is_empty(): _fatal = "TEST_TIMEOUT"
	if _role=="host":
		_checks.event_profile = _network.profile_event_fields()
		var peak: Dictionary = load(base+"/value_codec.gd").new().encode(_network._peak_patch,64*1024*1024)
		if peak.ok:
			var peak_file := FileAccess.open(_directory+"/peak-event.json",FileAccess.WRITE)
			if peak_file!=null:
				peak_file.store_buffer(peak.value)
				peak_file.close()
	_stage = "closed"
	_checks.transport_stats = {}
	for peer in _transport._peers:
		var packet_peer: ENetPacketPeer = _transport._peer.get_peer(peer)
		_checks.transport_stats[str(peer)] = {"rtt_ms":packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),"loss_scaled":packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)}
	_network.leave()
	if _network.save_session.closing: await _network.save_session.closed
	_write("PASS" if _fatal.is_empty() else "FAIL")
	return {"ok":_fatal.is_empty(),"code":_fatal}

func _guest_actions() -> void:
	while _network.session.state!=_network.session.State.PLAYING and _fatal.is_empty(): await get_tree().process_frame
	_join_ms = Time.get_ticks_msec()-_began
	_stage = "collab_ready"
	_write("RUNNING")
	var player: Node3D = _adapter.nodes.player
	for tool in [2,1,0]:
		if _adapter.select_local_tool(tool).ok:
			_checks.tool = tool
			break
	while _read("host").get("stage")!="measuring" and _fatal.is_empty():
		await get_tree().create_timer(0.1).timeout
	_measure_at = Time.get_ticks_msec()
	_stage = "measuring"
	_adapter.perf.clear()
	_network.perf.clear()
	_network.maximum_queue_bytes = 0
	_network.maximum_queue_packets = 0
	_network.trace.clear()
	_transport.packet_sizes.clear()
	var cycle := 0
	while Time.get_ticks_msec()-_measure_at<_duration*1000 and _fatal.is_empty():
		var x := float((_index-2)*6)+sin(float(cycle)*0.4)*0.5
		var z := 3.0+cos(float(cycle)*0.4)*0.5
		player.global_position = Vector3(x,float(_adapter.nodes.field.call("top_at",x,z))+0.2,z)
		player.call("set_look",0.0,-1.35)
		await get_tree().create_timer(0.2).timeout
		for action in [["dig",{"pressed":true}],["dig",{"pressed":false}],["item_interact",{"operation":"secondary"}]]:
			var started := Time.get_ticks_msec()
			var result := await _action(action[0],action[1])
			_actions.append(Time.get_ticks_msec()-started)
			if not result.ok:
				_fatal = "ACTION_"+str(result.code)
				return
			await get_tree().create_timer(0.25).timeout
		cycle += 1
		await get_tree().create_timer(0.8).timeout
	_checks.action_cycles = cycle
	_done = true
	var helper: Node = load(get_script().resource_path.get_base_dir()+"/native_integrity_check.gd").new()
	helper._adapter = _adapter
	var deadline := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		await get_tree().process_frame
		var revision: int = _network.world_sync.revision
		helper._checks.clear()
		var proof: Dictionary = helper._native_building_values(_adapter._guest_buildings)
		helper._check_guest_belt_view()
		var belts_ok: bool = (helper._checks.get("belt_view_rendered",false) and not helper._checks.get("belt_view_misses",0)) or _fallback_belt_view()
		if revision==_network.world_sync.revision and proof.ok and belts_ok:
			_checks.native_integrity = {"buildings":_adapter._guest_buildings.size(),"machine_fields":proof.fields,"belts":true,"fallback_bodies":_adapter.spill_visuals.size(),"props":_adapter.nodes.props.get("items").size()}
			break
		_checks.integrity_detail = {"machines":proof,"belts":helper._checks.duplicate(true)}
		await get_tree().create_timer(0.05).timeout
	helper.free()
	if not _checks.has("native_integrity"): _fatal = "NATIVE_INTEGRITY_FAILED"
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_directory+"/guest-"+str(_index)+".png")
		await _capture_hay_views()
	else:
		await _capture_hay_views(false)
	_stage = "actions_done"
	_write("RUNNING")

func _fallback_belt_view() -> bool:
	if _adapter.spill_visuals.is_empty() or _adapter._belts_pending: return false
	var expected: Dictionary = _adapter._read_belts()
	var actual: Dictionary = _adapter.nodes.world.call("_belts_to_dict")
	var records := []
	var wanted := []
	for category in ["paths","lifts","stairs"]:
		var key := "records" if category=="paths" else "rows"
		for path in expected.get(category,[]): wanted.append_array(path.get(key,[]))
		for path in actual.get(category,[]): records.append_array(path.get(key,[]))
	if wanted.size()!=records.size()+_adapter.spill_visuals.size(): return false
	var used := {}
	for item in wanted:
		var found := false
		for index in range(records.size()):
			var record: Dictionary = records[index]
			if not used.has(index) and record.get("kind")==item.get("kind") and record.get("strands")==item.get("strands") and record.xform.origin.distance_to(item.xform.origin)<0.05:
				used[index] = true
				found = true
				break
		if found: continue
		for index in range(_adapter.spill_visuals.size()):
			var visual: Dictionary = _adapter.spill_visuals[index]
			if used.has(records.size()+index) or visual.xform.origin.distance_to(item.xform.origin)>=0.05 or visual.meshes.is_empty(): continue
			var visible := true
			for mesh in visual.meshes:
				if not is_instance_valid(mesh) or mesh.mesh==null or not mesh.is_visible_in_tree(): visible = false
			if not visible: continue
			used[records.size()+index] = true
			found = true
			break
		if not found: return false
	return _adapter.nodes.props.get("items").size()==_adapter._prop_module()._records.size()

func _action(kind: String, payload: Dictionary) -> Dictionary:
	var result: Dictionary = _network.request_action(kind,payload)
	if not result.ok: return result
	var sequence: int = result.value.sequence
	var deadline := Time.get_ticks_msec()+15000
	while not _results.has(sequence) and Time.get_ticks_msec()<deadline and _fatal.is_empty(): await get_tree().process_frame
	return _results.get(sequence,{"ok":false,"code":"TIMEOUT"})

func _process(_delta: float) -> void:
	if _network==null or _done: return
	var now := Time.get_ticks_usec()
	if _measure_at>0 and _frame_at>0: _frames.append((now-_frame_at)/1000.0)
	if _role=="guest" and _stage=="measuring":
		var tool_load: Dictionary = _adapter.read_local_tool_load()
		_checks.max_tool_load = maxi(int(_checks.get("max_tool_load",0)),int(tool_load.get("count",0)))
	_frame_at = now
	# File polling is diagnostic coordination, not part of the game loop.
	# Keep it at one Hz so report I/O cannot dominate native frame timings.
	if Time.get_ticks_msec()-_report_at<1000: return
	if _role=="host" and _stage=="waiting" and _network.session.roster.size()==_count:
		var ready := true
		for index in range(1,_count):
			if _read("guest-"+str(index)).get("stage")!="collab_ready": ready = false
		if ready:
			_measure_at = Time.get_ticks_msec()
			_stage = "measuring"
			_adapter.perf.clear()
			_network.perf.clear()
			_network.maximum_queue_bytes = 0
			_network.maximum_queue_packets = 0
			_network.trace.clear()
			_network.event_shape_active = true
			_transport.packet_sizes.clear()
	if _role=="host" and _stage=="measuring":
		var complete := true
		for index in range(1,_count):
			if _read("guest-"+str(index)).get("stage")!="actions_done": complete = false
		if complete:
			_done = true
			_stage = "actions_done"
			_write("RUNNING")
	if _role=="host":
		for peer in _network._status._samples:
			var sample: Dictionary = _network._status._samples[peer]
			if _last_probe.get(peer)!=sample.received:
				_latencies.append(sample.latency_ms)
				_last_probe[peer] = sample.received
	_report_at = Time.get_ticks_msec()
	_write("RUNNING")

func _observe(event: Dictionary) -> void:
	# Independent native field and quest state, checked at the same revision.
	var state: Node = _adapter.nodes.state
	_history[str(event.revision)] = str(hash(_adapter.nodes.field.get("heights")))+":"+str(state.get("mission_index"))

func _stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"count":0}
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in ordered: total += float(value)
	return {"count":ordered.size(),"mean_ms":total/ordered.size(),"p50_ms":ordered[int((ordered.size()-1)*0.5)],"p95_ms":ordered[int((ordered.size()-1)*0.95)],"p99_ms":ordered[int((ordered.size()-1)*0.99)],"max_ms":ordered[-1]}

func _write(status: String) -> void:
	if _directory.is_empty(): return
	var timings := {}
	if _adapter!=null:
		for key in _adapter.perf: timings[key] = _stats(_adapter.perf[key])
	if _network!=null:
		for key in _network.perf: timings[key] = _stats(_network.perf[key])
	var file := FileAccess.open(_directory+"/"+("host" if _role=="host" else "guest-"+str(_index))+".json",FileAccess.WRITE)
	if file==null: return
	file.store_string(JSON.stringify({"status":status,"code":_fatal,"stage":_stage,"revision":_network.world_sync.revision if _network!=null else -1,"scenario_complete":_done,"scenario_revision":0,"history":_history,"checks":_checks,"join_ms":_join_ms,"measurement_ms":Time.get_ticks_msec()-_measure_at if _measure_at>0 else 0,"frame":_stats(_frames),"actions":_stats(_actions),"rtt":_stats(_latencies),"timings":timings,"queue_bytes":_network._tx_bytes if _network!=null else 0,"max_queue_bytes":_network.maximum_queue_bytes if _network!=null else 0,"max_queue_packets":_network.maximum_queue_packets if _network!=null else 0,"sent_bytes":_transport.sent_bytes if _transport!=null else 0,"snapshot_loads":_snapshot_loads}))
	file.close()
	if _done and _network!=null:
		var diagnostic := FileAccess.open(_directory+"/"+("host" if _role=="host" else "guest-"+str(_index))+"-transport.json",FileAccess.WRITE)
		if diagnostic!=null:
			diagnostic.store_string(JSON.stringify({"trace":_network.trace,"packet_sizes":_transport.packet_sizes}))
			diagnostic.close()

func _capture_hay_views(gpu: bool=true) -> void:
	var player: Node3D = _adapter.nodes.player
	var witness: RefCounted = load(get_script().resource_path.get_base_dir()+"/native_render_witness.gd").new()
	var views := []
	var number := 0
	for position in [Vector3(0,6.0,14),Vector3(-10,6.0,10),Vector3(10,6.0,0)]:
		player.global_position = position
		var direction: Vector3 = (Vector3(0,3.5,0)-position).normalized()
		player.call("set_look",atan2(-direction.x,-direction.z),asin(direction.y))
		await get_tree().create_timer(1.5).timeout
		if gpu: await RenderingServer.frame_post_draw
		var view: Dictionary = witness.inspect(_adapter)
		if not view.lod_follows_camera or not view.machine_lod_static or view.invalid_transforms>0 or view.slot_errors>0: _fatal = "NATIVE_HAY_VIEW_INVALID"
		if gpu:
			for path in ["res://scripts/build/belt_batch.gd","res://scripts/build/structure_cull.gd","res://scripts/world/shadow_lod.gd"]:
				if not view.presentation.has(path): _fatal = "GUEST_PRESENTATION_MISSING"
		for entry in view.presentation.values():
			if entry.nodes!=entry.processing: _fatal = "GUEST_PRESENTATION_STOPPED"
		view.position = position
		view.gpu_rendered = gpu
		views.append(view)
		if gpu: get_viewport().get_texture().get_image().save_png(_directory+"/guest-"+str(_index)+"-hay-"+str(number)+".png")
		number += 1
	# CPU visibility checks are separate evidence; they never certify pixels.
	_checks["native_hay_views" if gpu else "native_visibility_cpu"] = views

func _read(name: String) -> Dictionary:
	var file := FileAccess.open(_directory+"/"+name+".json",FileAccess.READ)
	if file==null: return {}
	var parser := JSON.new()
	if parser.parse(file.get_buffer(file.get_length()).get_string_from_utf8())!=OK: return {}
	return parser.data if parser.data is Dictionary else {}

func _argument(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for argument in args:
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return fallback

func _finish(code: String) -> Dictionary:
	_fatal = code
	_write("FAIL")
	return {"ok":false,"code":code}
