extends Node

# Explicit CLI-only integration test, never a normal multiplayer entry point.
var _adapter: RefCounted
var _network: Node
var _role := ""
var _index := 0
var _count := 2
var _directory := ""
var _stage := "starting"
var _fatal := ""
var _done := false
var _history: Dictionary = {}
var _field_history: Dictionary = {}
var _state_history: Dictionary = {}
var _sample_history: Dictionary = {}
var _building_history: Dictionary = {}
var _state_roundtrip: Dictionary = {}
var _load_history: Dictionary = {}
var _results: Dictionary = {}
var _last_revision := -1
var _revision_frames := 0
var _write_due := 0.0
var _purchase_successes := 0
var _extra_running := false
var _checks: Dictionary = {}
var _began := 0
var _finished := false
var _scenario_revision := -1
var _runtime: Node
var _presence_check := false
var _ui_captured := false
var _host_shop_before: Dictionary = {}
var _save_check := false
var _offline_path := ""
var _offline_hash := ""
var _offline_directory := ""
var _settings_original: Dictionary = {}
var _expected_disconnect := false
var _collaboration_running := false
const TEST_SETTINGS := {"prop_cap":300,"prop_decay":true,"belt_cap":600,"belt_decay":true,"auto_clean":false,"auto_clean_seconds":90.0,"grid_lock":false,"autosave":false,"autosave_seconds":180.0}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func run(base: String, args: PackedStringArray) -> Dictionary:
	_began = Time.get_ticks_msec()
	_role = _argument(args,"--ftn-role=","host")
	_index = _argument(args,"--ftn-index=","0").to_int()
	_count = _argument(args,"--ftn-count=","2").to_int()
	_presence_check = args.has("--ftn-coop-presence-check")
	_save_check = args.has("--ftn-coop-save-check")
	var run_id := _argument(args,"--ftn-run=","")
	var protocol: RefCounted = load(base+"/protocol.gd").new()
	if _role not in ["host","guest"] or _count not in [2,4] or not protocol.valid_id(run_id): return _finish("TEST_ARGUMENTS")
	_directory = OS.get_environment("FTN_COOP_TEST_OUTPUT").replace("\\","/")
	if _directory.is_empty(): _directory = "user://ftn_coop/tests/"+run_id
	DirAccess.make_dir_recursive_absolute(_directory)
	get_tree().root.title = "FTN Koop Test · "+_role+" "+str(_index)
	_adapter = load(base+"/game_adapter.gd").new()
	_adapter.bind(get_tree().root)
	if not _adapter.nodes.has("world") or not _adapter.nodes.has("saves"): return _finish("WORLD_NOT_READY")
	var saves: Node = _adapter.nodes.saves
	if _role=="host":
		for key in TEST_SETTINGS:
			var setting: Dictionary = _adapter.update_shared_setting(key,TEST_SETTINGS[key])
			if not setting.ok: return _finish(setting.code)
	else:
		_adapter.nodes.cfg.call("set_prop_cap",70+_index)
		_adapter.nodes.cfg.call("set_grid_lock",true)
		_settings_original = _adapter.read_shared_settings().value
	saves.call("use_scratch_dir","user://ftn_coop/tests/"+run_id+"/world-"+str(_index))
	saves.set("current_slot",1)
	if _save_check and _role=="guest":
		_adapter.nodes.world.set("block_save",false)
		saves.set("block_save",false)
		var seeded: Dictionary = _adapter.capture_world()
		if not seeded.ok: return _finish("OFFLINE_SEED_FAILED")
		_offline_path = saves.call("slot_path",1)
		_offline_hash = FileAccess.get_sha256(_offline_path)
		_offline_directory = saves.call("save_dir")
	_adapter.nodes.world.set("block_save",_role!="host")
	saves.set("block_save",_role!="host")
	if _role=="host":
		var price := float(_adapter.nodes.world.get("shop").call("live_price","bucket"))
		_adapter.nodes.state.set("money",price)
	else:
		_adapter.set_guest_mode(true)
		var before: Dictionary = _adapter.nodes.state.call("to_dict").duplicate(true)
		_adapter.nodes.state.call("from_dict",before)
		var after: Dictionary = _adapter.nodes.state.call("to_dict")
		for field in before:
			if _digest(before[field])!=_digest(after.get(field)):
				var entry := {"before_type":type_string(typeof(before[field])),"after_type":type_string(typeof(after.get(field))),"has_property":false}
				for property in _adapter.nodes.state.get_script().get_script_property_list():
					if property.name==field:
						entry.has_property = true
						_adapter.nodes.state.set(field,before[field])
				entry.direct_restore = _digest(_adapter.nodes.state.call("to_dict").get(field))==_digest(before[field])
				_state_roundtrip[str(field)] = entry
	var transport: Node = load(base+"/local_transport.gd").new()
	transport.port = _argument(args,"--ftn-port=","27641").to_int()
	add_child(transport)
	if _presence_check:
		_runtime = load(base+"/coop_runtime.gd").new()
		add_child(_runtime)
		_runtime.configure(_adapter,transport,"25963876","0.4.1")
		_network = _runtime.network
	else:
		_network = load(base+"/network_controller.gd").new()
		add_child(_network)
		_network.configure(transport,_adapter,"25963876","0.4.1")
	_network.session.player_name = "Netztest "+str(_index)
	_network.problem.connect(func(code: String):
		if not _directory.is_empty() and FileAccess.file_exists(_directory+"/stop.request"): return
		if _expected_disconnect and code in ["HOST_LEFT","HOST_DISCONNECTED","NOT_CONNECTED","SEND_FAILED"]: return
		if code not in ["INSUFFICIENT_FUNDS","PURCHASE_REFUSED"]: _fatal = code
	)
	_network.action_result.connect(func(sequence: int, ok: bool, code: String): _results[sequence]={"ok":ok,"code":code})
	_network.world_sync.confirmed.connect(func(event: Dictionary):
		if event.get("kind")=="purchase":
			_purchase_successes += 1
			if _presence_check and not _host_shop_before.is_empty():
				var menu: Node = _adapter.nodes.world.get("shop_menu")
				_checks.host_shop_preserved = menu.get("_open")==_host_shop_before.open and menu.get("visible")==_host_shop_before.visible and Input.mouse_mode==_host_shop_before.mouse
	)
	var begun: Dictionary = {"ok":true,"code":"OK","value":null}
	if _role=="host": begun = _network.host()
	elif _presence_check: _runtime.join_invitation(1)
	else: begun = _network.join(1)
	if not begun.ok: return _finish(begun.code)
	if _role=="guest": _guest_actions()
	_stage = "waiting"
	var deadline := Time.get_ticks_msec()+((480000 if _count==4 else 220000) if _presence_check else (360000 if _count==4 else 110000))
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if not _fatal.is_empty(): break
		if FileAccess.file_exists(_directory+"/stop.request"): break
	if _fatal.is_empty() and not _done: _fatal = "TEST_TIMEOUT"
	_finished = true
	set_process(false)
	_network.leave()
	if _network.save_session.closing: await _network.save_session.closed
	if _role=="guest" and _fatal.is_empty():
		_checks.settings_restored = _adapter.read_shared_settings().value==_settings_original and not _adapter.nodes.cfg.get("settings_readonly")
		_adapter.nodes.cfg.call("load_settings")
		_checks.settings_disk_restored = _adapter.read_shared_settings().value==_settings_original and is_equal_approx(float(_adapter.nodes.cfg.get("mouse_sensitivity")),0.42)
		if not _checks.settings_restored or not _checks.settings_disk_restored or not _checks.get("settings_live",false): _fatal = "SETTINGS_RESTORE_FAILED"
		if _presence_check:
			for key in ["native_f3","marker_common","marker_colors","connection_status","preset_live"]:
				if not _checks.get(key,false): _fatal = "CHECK_"+key.to_upper()
			if _index==1 and not _checks.get("rejoin_button",false): _fatal = "REJOIN_BUTTON_FAILED"
	if _save_check and _fatal.is_empty():
		if _role=="guest":
			_checks.offline_unchanged = not _offline_hash.is_empty() and FileAccess.get_sha256(_offline_path)==_offline_hash
			_checks.close_details = {"guest_mode":_adapter.guest_mode,"origin_empty":_adapter._save_origin.is_empty(),"directory":_adapter.nodes.saves.call("save_dir"),"expected_directory":_offline_directory,"scene":get_tree().current_scene.scene_file_path if get_tree().current_scene!=null else ""}
			_checks.guest_closed = not _adapter.guest_mode and _adapter._save_origin.is_empty() and _adapter.nodes.saves.call("save_dir")==_offline_directory and get_tree().current_scene!=null and get_tree().current_scene.scene_file_path=="res://scenes/main_menu.tscn"
			if not _checks.offline_unchanged or not _checks.guest_closed: _fatal = "GUEST_PERSISTENCE_FAILED"
		else:
			await get_tree().process_frame
			await _check_host_reload()
	_adapter.nodes.saves.set("block_save",true)
	if _adapter.nodes.has("world") and is_instance_valid(_adapter.nodes.world): _adapter.nodes.world.set("block_save",true)
	_write("PASS" if _fatal.is_empty() else "FAIL")
	return {"ok":_fatal.is_empty(),"code":"OK" if _fatal.is_empty() else _fatal,"value":null}

func _guest_actions() -> void:
	if _save_check:
		while not _network._loading:
			await get_tree().process_frame
			if not _fatal.is_empty(): return
		_network.leave()
		if _network.save_session.closing: await _network.save_session.closed
		_checks.cancel_clean = not _adapter.guest_mode and _adapter._save_origin.is_empty() and FileAccess.get_sha256(_offline_path)==_offline_hash and _adapter.read_shared_settings().value==_settings_original
		if not _checks.cancel_clean:
			_fatal = "CANCEL_PERSISTENCE_FAILED"
			return
		var rejoined: Dictionary = _network.join(1)
		if not rejoined.ok:
			_fatal = rejoined.code
			return
	while _network.session.state!=_network.session.State.PLAYING:
		await get_tree().process_frame
		if not _fatal.is_empty(): return
	if _save_check: _checks.rejoined = true
	_checks.settings_join = _adapter.read_shared_settings().value==TEST_SETTINGS
	var settings_hash := FileAccess.get_sha256("user://settings.cfg")
	_adapter.nodes.cfg.call("set_prop_cap",42)
	_adapter.nodes.cfg.call("set_mouse_sensitivity",0.42)
	for frame in range(3): await get_tree().process_frame
	_checks.settings_enforced = _adapter.read_shared_settings().value==TEST_SETTINGS
	_checks.settings_file_untouched = FileAccess.get_sha256("user://settings.cfg")==settings_hash
	if not _checks.settings_join or not _checks.settings_enforced or not _checks.settings_file_untouched:
		_fatal = "SETTINGS_JOIN_FAILED"
		return
	if _presence_check:
		await _guest_collaboration()
		if not _fatal.is_empty(): return
	var player: Node3D = _adapter.nodes.player
	if _presence_check:
		var bound: Dictionary = _runtime.movement.configure(_adapter)
		if not bound.ok:
			_fatal = "GUEST_BODY_UNSUPPORTED"
			return
		player.global_position = Vector3(-10,1,-10)
		player.call("set_look",0.0,0.0)
		var start := player.global_position
		_runtime.movement.enabled = true
		for frame in range(45):
			await get_tree().physics_frame
			_runtime.movement.step(1.0/60.0,Vector2(0,-1),false)
		_checks.guest_movement = Vector2(player.global_position.x-start.x,player.global_position.z-start.z).length()>1.0 and player.global_position.y>-0.5
		var options: Dictionary = _adapter.guest_options()
		_checks.main_scene = ProjectSettings.get_setting("application/run/main_scene","")
		_checks.guest_controls = not options.tools.is_empty() and not options.shop.is_empty() and not options.buildings.is_empty()
		_checks.option_counts = {"tools":options.tools.size(),"shop":options.shop.size(),"buildings":options.buildings.size(),"upgrades":options.upgrades.size()}
		if not _checks.guest_movement or not _checks.guest_controls:
			_fatal = "GUEST_CONTROLS_FAILED"
			return
	var x := float((_index-2)*4)
	player.global_position = Vector3(x,float(_adapter.nodes.field.call("top_at",x,3.0))+0.2,3.0)
	player.call("set_look",0.0,-1.35)
	for action in [["dig",{"pressed":true}],["dig",{"pressed":false}],["item_interact",{"operation":"drop"}]]:
		var result: Dictionary = await _action(action[0],action[1])
		if not result.ok:
			_fatal = result.code
			return
	_stage = "dig_done"
	while _read("host").get("stage")!="buy_ready":
		await get_tree().process_frame
		if not _fatal.is_empty(): return
	player.global_position = _adapter.nodes.world.get("shop").call("interact_point")
	player.call("set_look",0.0,0.0)
	var bought: Dictionary = await _action("purchase",{"id":"bucket"})
	if not bought.ok and bought.code not in ["INSUFFICIENT_FUNDS","PURCHASE_REFUSED"]:
		_fatal = bought.code
		return
	if _presence_check:
		player.global_position = Vector3(8,0,10)
		player.call("set_look",0.0,0.0)
	await _action("item_interact",{"operation":"drop"})
	if _presence_check:
		for frame in range(4): await get_tree().process_frame
	# The remaining private scenario controls this test pawn from the host.
	# Stop the scripted guest's idle poses overwriting that diagnostic movement.
	_network.pose_stream_enabled = false
	_stage = "actions_done"
	_done = true
	if _presence_check:
		_checks.avatars = _runtime.presence.avatars.size()==_count-1
		_runtime.ui.set_panel_open(true)

func _action(kind: String, payload: Dictionary) -> Dictionary:
	var queued: Dictionary = _network.request_action(kind,payload)
	if not queued.ok: return queued
	var sequence: int = queued.value.sequence
	var deadline := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline and not _results.has(sequence): await get_tree().process_frame
	return _results[sequence] if _results.has(sequence) else {"ok":false,"code":"ACTION_TIMEOUT"}

func _process(delta: float) -> void:
	if _finished or _network==null or _adapter==null or _directory.is_empty(): return
	if _role=="guest" and _network.session.state==_network.session.State.PLAYING and _adapter.nodes.cfg.get("prop_cap")==330:
		_checks.settings_live = true
		var expected := TEST_SETTINGS.duplicate(true)
		expected.prop_cap = 330
		_checks.preset_live = _adapter.read_shared_settings().value==expected
	if _network.session.state==_network.session.State.PLAYING:
		var revision: int = _network.world_sync.revision
		if revision!=_last_revision:
			_last_revision = revision
			_revision_frames = 0
		else: _revision_frames += 1
		if (_role=="host" and not _history.has(str(revision))) or (_role!="host" and _revision_frames==2):
			var frame: Dictionary = _adapter._previous_frame if _role=="host" else _adapter._live_frame()
			if not frame.is_empty():
				var key := str(revision)
				_history[key] = _digest(frame)
				var fields := {}
				for field in frame: fields[str(field)] = _digest(frame[field])
				_field_history[key] = fields
				var state_fields := {}
				for field in frame.get("state",{}): state_fields[str(field)] = _digest(frame.state[field])
				_state_history[key] = state_fields
				var samples := {}
				for field in ["hay_initial","hay_total","jetpack_fuel","money_peak","run_secs"]:
					var scalar: Variant = frame.get("state",{}).get(field)
					samples[field] = {"type":type_string(typeof(scalar)),"value":scalar,"bits":PackedFloat64Array([float(scalar)]).to_byte_array().hex_encode()}
				_sample_history[key] = samples
				var buildings := []
				var loads := []
				for building in frame.get("buildings",[]):
					var members := {}
					if building is Dictionary:
						for member in building: members[str(member)] = _digest(building[member])
					buildings.append(members)
					if building is Dictionary and building.has("loads"):
						var codec: RefCounted = load(get_script().resource_path.get_base_dir()+"/value_codec.gd").new()
						var encoded_load: Dictionary = codec.encode(building.loads,8192)
						loads.append(encoded_load.value.get_string_from_utf8() if encoded_load.ok else encoded_load.code)
				_building_history[key] = buildings
				_load_history[key] = loads
				while _field_history.size()>16:
					var oldest: Variant = _field_history.keys()[0]
					_field_history.erase(oldest)
					_state_history.erase(oldest)
					_sample_history.erase(oldest)
					_building_history.erase(oldest)
					_load_history.erase(oldest)
		if _role=="host" and not _extra_running:
			if _presence_check and _stage=="waiting" and not _collaboration_running and _all_stage("collab_ready"):
				_collaboration_running = true
				_host_collaboration()
			if _stage=="waiting" and _all_stage("dig_done"):
				_adapter.nodes.state.set("money",float(_adapter.nodes.world.get("shop").call("live_price","bucket")))
				_network.world_sync.poll()
				if _presence_check:
					var menu: Node = _adapter.nodes.world.get("shop_menu")
					_adapter.nodes.player.global_position = _adapter.nodes.world.get("shop").call("interact_point")
					menu.set("_open",true)
					menu.set("visible",true)
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					_host_shop_before = {"open":true,"visible":true,"mouse":Input.MOUSE_MODE_VISIBLE}
				_stage = "buy_ready"
			elif _stage=="buy_ready" and _all_stage("actions_done"):
				_extra_running = true
				_extra_actions()
		if _presence_check and _done and not _ui_captured and (_role=="host" or _read("host").get("stage")=="actions_done"):
			_ui_captured = true
			_capture_ui()
	_write_due += delta
	if _write_due>=0.1:
		_write_due = 0.0
		_write("RUNNING")

func _extra_actions() -> void:
	_stage = "extra_actions"
	if _presence_check:
		_adapter.nodes.world.get("shop_menu").set("_open",false)
		_adapter.nodes.world.get("shop_menu").set("visible",false)
	var builds: Node = _adapter.nodes.builds
	var scanner: Node = builds.call("add_scanner",Vector3(-10,0,-8),0.0,1)
	_checks.build = scanner!=null
	if scanner!=null:
		scanner.call("_take_in","pool",10)
		_checks.machine_feed = int(scanner.get("stored"))>0
	var cabinet: Node3D = builds.call("add_cabinet",Vector3(12,0,10),0.0,false)
	var peer := 0
	for candidate in _adapter.actors:
		peer = candidate
		break
	if peer>1 and cabinet!=null:
		var actor: Node3D = _adapter.actors[peer]
		if _presence_check:
			_checks.tool_ticks = {}
			for role in ["hand","carry","shovel","pitchfork","broom","yard_vac","lighter","build"]:
				var methods := []
				for method in actor.get(role).get_script().get_script_method_list():
					if methods.size()<192:
						var args := []
						for arg in method.args: args.append(arg.name)
						methods.append({"name":method.name,"args":args})
				_checks.tool_ticks[role] = methods
		actor.call("_set_tool",0,true)
		var taken: PackedByteArray = _adapter.nodes.state.get("needle_taken")
		var index := -1
		for candidate in range(taken.size()):
			if taken[candidate]==0:
				index=candidate
				break
		if index>=0:
			var body: Node3D = _adapter.nodes.world.get("live").call("reveal_needle",index,Vector3(12,1.4,12))
			if body!=null:
				actor.global_position = Vector3(body.global_position.x,0,body.global_position.z+0.5)
				var aim: Vector3 = body.global_position-actor.get("camera").global_position
				actor.call("set_look",atan2(-aim.x,-aim.z),atan2(aim.y,Vector2(aim.x,aim.z).length()))
				await get_tree().physics_frame
				await get_tree().physics_frame
				_network.world_sync.submit_action(peer,1001,"needle_collect",{})
				if _presence_check:
					var held: Array = actor.get("hand").call("held_bodies")
					if not held.is_empty() and held[0] is Node3D:
						var hand: Node = actor.get("hand")
						_checks.held_state = {"can_process":hand.can_process(),"physics":hand.is_physics_processing(),"mode":hand.process_mode}
						# Finish native pickup flight before measuring steady carrying.
						await get_tree().create_timer(0.6).timeout
						var before: Vector3 = held[0].global_position
						actor.global_position += Vector3(1.0,0,0)
						for frame in range(10): await get_tree().physics_frame
						_checks.held_follow = held[0].global_position.distance_to(before)>0.2
						_checks.held_distance = held[0].global_position.distance_to(before)
				actor.global_position = cabinet.global_position+Vector3(0,0,0.75)
				var deposit_aim: Vector3 = cabinet.global_position+Vector3(0,0.8,0)-actor.get("camera").global_position
				actor.call("set_look",atan2(-deposit_aim.x,-deposit_aim.z),atan2(deposit_aim.y,Vector2(deposit_aim.x,deposit_aim.z).length()))
				await get_tree().physics_frame
				await get_tree().physics_frame
				_checks.needle_deposit = _network.world_sync.submit_action(peer,1002,"needle_collect",{"operation":"deposit"}).ok
				_checks.needle_once = not _network.world_sync.submit_action(peer,1003,"needle_collect",{"operation":"deposit"}).ok
		if _presence_check:
			await _check_power_tool(actor,peer)
			await _check_build_steps(actor)
			await _check_loaded_departure(actor,peer)
	if _presence_check:
		_runtime.ui.set_shared_settings(_adapter.read_shared_settings().value)
		_runtime.ui._settings_controls.prop_cap.value = 330
		_runtime.ui._preset_name.text = "Native check"
		_runtime.ui._preset_save.pressed.emit()
		_adapter.update_shared_setting("prop_cap",310)
		_runtime.ui._preset_apply.pressed.emit()
		var preset: Dictionary = _runtime._presets.load_preset("Native check")
		_checks.preset_roundtrip = preset.ok and preset.value.prop_cap==330 and _adapter.nodes.cfg.get("prop_cap")==330
	else: _adapter.update_shared_setting("prop_cap",330)
	_checks.settings_host_edit = _adapter.nodes.cfg.get("prop_cap")==330
	_network.world_sync.poll()
	_scenario_revision = _network.world_sync.revision
	_checks.purchase_once = _purchase_successes==1
	_checks.dig = float(_adapter.nodes.state.get("hay_dug"))>0
	_stage = "settling"
	if _presence_check: await get_tree().create_timer(8.0).timeout
	await get_tree().create_timer(1.0).timeout
	_done = true
	for key in ["build","machine_feed","needle_deposit","needle_once","purchase_once","dig","settings_host_edit"]:
		if _checks.get(key)!=true:
			_fatal = "CHECK_"+String(key).to_upper()
			_done = false
	if _presence_check and not _checks.get("held_follow",false):
		_fatal = "HELD_FOLLOW_FAILED"
		_done = false
	if _presence_check and not _checks.get("power_dig",false):
		_fatal = "POWER_DIG_FAILED"
		_done = false
	if _presence_check and not _checks.get("power_carry",false):
		_fatal = "POWER_CARRY_FAILED"
		_done = false
	if _presence_check and not _checks.get("power_drop",false):
		_fatal = "POWER_DROP_FAILED"
		_done = false
	if _presence_check and not _checks.get("build_steps",false):
		_fatal = "BUILD_STEPS_FAILED"
		_done = false
	if _presence_check and not _checks.get("loaded_departure",false):
		_fatal = "LOADED_DEPARTURE_FAILED"
		_done = false
	if _presence_check:
		for key in ["native_f3","marker_common","marker_colors","connection_status","marker_departure_cleanup","preset_roundtrip"]:
			if not _checks.get(key,false):
				_fatal = "CHECK_"+key.to_upper()
				_done = false
	_stage = "actions_done"
	if _presence_check:
		_checks.avatars = _runtime.presence.avatars.size()==_count-1
		_runtime.ui.set_panel_open(true)

func _place_native_marker() -> bool:
	var player: Node3D = _adapter.nodes.player
	var x := float(_index*2)
	player.global_position = Vector3(x,float(_adapter.nodes.field.call("top_at",x,3.0))+1.0,3.0)
	player.call("set_look",0.0,-1.35)
	_runtime.ui.set_panel_open(false)
	_runtime.ui._marker_selector.select(1 if _role=="host" else 3)
	get_tree().root.grab_focus()
	for frame in range(4): await get_tree().physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F3
	key.pressed = true
	_checks.marker_input = {"allowed":_runtime._marker_input_allowed(),"mouse":Input.mouse_mode,"state":_network.session.state,"position":str(player.global_position),"camera":str(player.get("camera").global_basis.z)}
	_runtime._unhandled_input(key)
	_checks.marker_input.queued = _runtime._marker_requested
	for frame in range(8): await get_tree().process_frame
	_checks.marker_input.cooldown = _runtime._marker_cooldown
	_checks.marker_input.count = _network.collaboration_snapshot().markers.size()
	var local: int = _network._transport.local_peer_id()
	for row in _network.collaboration_snapshot().markers:
		if row.peer==local: return _runtime._world_markers._nodes.has(local)
	return false

func _collaboration_checks() -> bool:
	var snapshot: Dictionary = _network.collaboration_snapshot()
	_checks.marker_common = snapshot.markers.size()==_count and _runtime._world_markers._nodes.size()==_count
	_checks.connection_status = snapshot.players.size()==_count
	for peer in snapshot.players:
		if peer!=1 and snapshot.players[peer].latency_ms<0: _checks.connection_status = false
	var colors: Script = load(get_script().resource_path.get_base_dir()+"/player_colors.gd")
	_checks.marker_colors = true
	for peer in _network.session.roster:
		var expected: Color = colors.for_peer(peer,_network.session.roster)
		if not _runtime.ui._roster_labels.has(peer) or _runtime.ui._roster_labels[peer].get_theme_color("font_color")!=expected: _checks.marker_colors = false
		if _runtime.presence.avatars.has(peer) and _runtime.presence.avatars[peer]._material.albedo_color!=expected: _checks.marker_colors = false
		if not _runtime._world_markers._nodes.has(peer) or _runtime._world_markers._nodes[peer].get_node("Pin").material_override.albedo_color!=expected: _checks.marker_colors = false
	return _checks.marker_common and _checks.marker_colors and _checks.connection_status

func _connection_ready() -> bool:
	var players: Dictionary = _network.collaboration_snapshot().players
	if players.size()!=_count: return false
	for peer in players:
		if peer!=1 and players[peer].latency_ms<0: return false
	return true

func _guest_collaboration() -> void:
	_runtime.ui.set_language("en" if _index%2==1 else "de")
	_stage = "collab_ready"
	var deadline := Time.get_ticks_msec()+(240000 if _count==4 else 90000)
	while _read("host").get("stage")!="collab_place_"+str(_index) and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	_checks.native_f3 = await _place_native_marker()
	_stage = "collab_marked"
	while _read("host").get("stage")!="collab_verify" and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	for frame in range(4): await get_tree().process_frame
	_collaboration_checks()
	_stage = "collab_verified"
	if _index==1:
		while _read("host").get("stage")!="collab_drop" and Time.get_ticks_msec()<deadline: await get_tree().process_frame
		_expected_disconnect = true
		var cookie: String = _network.connection_id
		_stage = "collab_drop_ready"
		while _network.session.state!=_network.session.State.OFFLINE and Time.get_ticks_msec()<deadline: await get_tree().process_frame
		while _network.save_session.closing and Time.get_ticks_msec()<deadline: await get_tree().process_frame
		_runtime._process(0.2)
		_checks.rejoin_button = _runtime.ui._rejoin_button.visible and not _runtime.ui._rejoin_button.disabled
		_runtime.ui._rejoin_button.pressed.emit()
		while _network.session.state!=_network.session.State.PLAYING and Time.get_ticks_msec()<deadline: await get_tree().process_frame
		_checks.rejoin_button = _checks.rejoin_button and _network.session.state==_network.session.State.PLAYING and _network.connection_id!=cookie
		_expected_disconnect = false
		_stage = "collab_rejoined"
	while _read("host").get("stage")!="collab_finish" and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	for key in ["native_f3","marker_common","marker_colors","connection_status"]:
		if not _checks.get(key,false): _fatal = "CHECK_"+key.to_upper()
	if _index==1 and not _checks.get("rejoin_button",false): _fatal = "REJOIN_BUTTON_FAILED"
	if Time.get_ticks_msec()>=deadline: _fatal = "COLLABORATION_TIMEOUT"

func _host_collaboration() -> void:
	_stage = "collab_place"
	_checks.native_f3 = await _place_native_marker()
	var deadline := Time.get_ticks_msec()+90000
	# Only one native window can own captured mouse input on this test PC.
	for index in range(1,_count):
		_stage = "collab_place_"+str(index)
		while _read("guest-"+str(index)).get("stage")!="collab_marked" and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	while not _all_stage("collab_marked") and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	while not _connection_ready() and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	for frame in range(6): await get_tree().process_frame
	_collaboration_checks()
	_stage = "collab_verify"
	while not _all_stage("collab_verified") and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	_stage = "collab_drop"
	while _read("guest-1").get("stage")!="collab_drop_ready" and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	var departing := 0
	for peer in _network.session.roster:
		if _network.session.roster[peer].name=="Netztest 1": departing = peer
	if departing>1: _network._transport.reject_peer(departing)
	_checks.marker_departure_cleanup = departing>1
	for row in _network.collaboration_snapshot().markers:
		if row.peer==departing: _checks.marker_departure_cleanup = false
	while (_read("guest-1").get("stage")!="collab_rejoined" or _network.session.roster.size()!=_count) and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	_stage = "collab_finish"
	while not _all_stage("dig_done") and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	if Time.get_ticks_msec()>=deadline: _fatal = "COLLABORATION_TIMEOUT"
	_stage = "waiting"

func _check_loaded_departure(actor: Node3D, peer: int) -> void:
	print("[FTN-Coop-Test] loaded departure: scoop")
	actor.call("_set_tool",1,true)
	actor.global_position = Vector3(-4,float(_adapter.nodes.field.call("top_at",-4.0,4.0))+0.2,4)
	actor.call("set_look",0.0,-1.35)
	_adapter._perform_action(actor,"dig",{"pressed":true})
	await get_tree().create_timer(0.6).timeout
	_adapter._perform_action(actor,"dig",{"pressed":false})
	var positions := {}
	print("[FTN-Coop-Test] loaded departure: read active positions")
	for body in _adapter.nodes.live.get("_active"):
		if body is Node3D and is_instance_valid(body) and body.is_inside_tree(): positions[body] = body.global_position
	actor.global_position += Vector3(1,0,0)
	print("[FTN-Coop-Test] loaded departure: move and identify")
	for frame in range(10): await get_tree().physics_frame
	var carried: Array = []
	for body in positions:
		if is_instance_valid(body) and body.is_inside_tree() and (body.global_position-positions[body]).distance_to(Vector3(1,0,0))<0.1: carried.append(body)
	print("[FTN-Coop-Test] loaded departure: remove actor")
	_adapter.remove_actor(peer)
	for frame in range(4): await get_tree().physics_frame
	print("[FTN-Coop-Test] loaded departure: check retained")
	var retained := 0
	for body in carried:
		if is_instance_valid(body) and body in _adapter.nodes.live.get("_active"): retained += 1
	_checks.loaded_departure = carried.size()>0 and retained==carried.size()
	_checks.loaded_departure_counts = {"carried":carried.size(),"retained":retained}

func _check_build_steps(actor: Node3D) -> void:
	_adapter.nodes.state.set("money",100000.0)
	var catalogue: Dictionary = _adapter.nodes.world.get("catalog_panel").get("_tiles")
	_checks.build_catalogue_ids = catalogue.keys()
	var id := ""
	for key in catalogue:
		if "conveyor" in str(key) or "belt" in str(key):
			id = str(key)
			break
	if id.is_empty(): return
	_checks.build_tech_ids = []
	for key in _adapter.nodes.world.get("tech_panel").get("_cards"):
		if "belt" in str(key) or "conveyor" in str(key):
			_checks.build_tech_ids.append(str(key))
			_adapter.nodes.tech.call("grant",str(key),1)
	actor.call("equip_build",id)
	_checks.build_selected = {"id":actor.get("build_id"),"tool":actor.get("current_tool")}
	var before: int = _adapter.nodes.builds.call("to_array").size()
	_checks.build_step_details = []
	for x in [-10.0,-7.0]:
		actor.global_position = Vector3(x,float(_adapter.nodes.field.call("top_at",x,-12.0))+0.2,-12)
		actor.call("set_look",0.0,-1.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var result: Dictionary = _adapter._perform_action(actor,"place",{"id":id})
		var status: Dictionary = actor.get("build").call("status")
		_checks.build_step_details.append({"id":id,"result":result,"placing":status.get("placing"),"ok":status.get("ok"),"done":status.get("done"),"length":status.get("length"),"reason":status.get("reason")})
	var after: int = _adapter.nodes.builds.call("to_array").size()
	_checks.build_step_counts = {"before":before,"after":after}
	_checks.build_steps = after>before
	actor.call("put_away_build")

func _check_power_tool(actor: Node3D, peer: int) -> void:
	# Native purchase is controlled setup; the earlier shared-budget race is
	# counted only through its network-confirmed purchase events.
	actor.global_position = _adapter.nodes.world.get("shop").call("interact_point")
	_adapter.nodes.state.set("money",float(_adapter.nodes.world.get("shop").call("live_price","spade")))
	var bought: Dictionary = _adapter._perform_action(actor,"purchase",{"id":"spade"})
	_checks.power_purchase = bought.ok
	_checks.power_tool = actor.get("current_tool")
	actor.global_position = Vector3(6,float(_adapter.nodes.field.call("top_at",6.0,4.0))+0.2,4)
	actor.call("set_look",0.0,-1.35)
	var before := float(_adapter.nodes.state.get("hay_dug"))
	var pressed: Dictionary = _network.world_sync.submit_action(peer,2001,"dig",{"pressed":true})
	await get_tree().create_timer(0.6).timeout
	_checks.power_dig = bought.ok and pressed.ok and int(actor.get("current_tool"))==1 and float(_adapter.nodes.state.get("hay_dug"))>before
	var shovel: Node = actor.get("shovel")
	_checks.power_processing = {"can_process":shovel.can_process(),"physics":shovel.is_physics_processing(),"mode":shovel.process_mode,"strands":shovel.call("carried_strands")}
	var positions := {}
	for body in _adapter.nodes.live.get("_active"):
		if body is Node3D and is_instance_valid(body) and body.is_inside_tree(): positions[body] = body.global_position
	actor.global_position += Vector3(1,0,0)
	for frame in range(10): await get_tree().physics_frame
	var following: Array = []
	for body in positions:
		if is_instance_valid(body) and body.is_inside_tree() and (body.global_position-positions[body]).distance_to(Vector3(1,0,0))<0.1: following.append(body)
	actor.global_position -= Vector3(1,0,0)
	for frame in range(10): await get_tree().physics_frame
	var followed := 0
	for body in following:
		if is_instance_valid(body) and body.is_inside_tree() and body.global_position.distance_to(positions[body])<0.1: followed += 1
	_checks.power_carry = followed>0
	_checks.power_carry_count = followed
	_network.world_sync.submit_action(peer,2002,"dig",{"pressed":false})
	var load_before := float(shovel.call("carried_strands"))
	_network.world_sync.submit_action(peer,2003,"item_interact",{"operation":"drop"})
	_checks.power_drop = load_before<=0.0 or int(actor.get("current_tool"))!=1 or float(shovel.call("carried_strands"))<load_before

func _capture_ui() -> void:
	if _role=="guest": await get_tree().create_timer(0.4).timeout
	if not _runtime.presence.avatars.is_empty():
		var avatar: Node3D = _runtime.presence.avatars.values()[0]
		if _role=="host": _adapter.nodes.player.global_position = avatar.global_position+Vector3(0,0,4)
		var aim: Vector3 = avatar.global_position+Vector3(0,1,0)-_adapter.nodes.player.get("camera").global_position
		_adapter.nodes.player.call("set_look",atan2(-aim.x,-aim.z),atan2(aim.y,Vector2(aim.x,aim.z).length()))
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	if picture==null: return
	picture.convert(Image.FORMAT_RGBA8)
	var name := "host" if _role=="host" else "guest-"+str(_index)
	_checks.ui_capture = picture.save_png(_directory+"/"+name+"-ui.png")==OK

func _check_host_reload() -> void:
	_adapter.nodes.state.set("money",137.0)
	var saved: Dictionary = _adapter.capture_world()
	_checks.host_saved = saved.ok
	if not saved.ok:
		_fatal = "HOST_SAVE_FAILED"
		return
	var expected: Dictionary = saved.value.state
	var buildings: int = saved.value.buildings.size()
	var props: int = saved.value.props.size()
	var saves: Node = _adapter.nodes.saves
	saves.set("block_save",true)
	_adapter.nodes.world.set("block_save",true)
	saves.call("begin_load",int(saves.get("current_slot")))
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	var deadline := Time.get_ticks_msec()+120000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		var scene: Node = get_tree().current_scene
		if scene!=null and scene.scene_file_path=="res://scenes/main.tscn" and scene.get("_built")==true:
			_adapter.bind(get_tree().root)
			var state: Dictionary = _adapter.nodes.state.call("to_dict")
			_checks.host_reload = state.get("money")==expected.get("money") and state.get("hay_dug")==expected.get("hay_dug") and state.get("needles_found")==expected.get("needles_found") and _adapter.nodes.builds.call("to_array").size()==buildings and _adapter.nodes.props.call("to_array").size()==props
			if not _checks.host_reload: _fatal = "HOST_RELOAD_MISMATCH"
			return
	_fatal = "HOST_RELOAD_TIMEOUT"

func _all_stage(stage: String) -> bool:
	if _network.session.roster.size()!=_count: return false
	for index in range(1,_count):
		if _read("guest-"+str(index)).get("stage")!=stage: return false
	return true

func _write(status: String) -> void:
	if _directory.is_empty(): return
	var name := "host" if _role=="host" else "guest-"+str(_index)
	var file := FileAccess.open(_directory+"/"+name+".json",FileAccess.WRITE)
	if file==null: return
	file.store_string(JSON.stringify({"role":_role,"index":_index,"status":status,"code":_fatal,"stage":_stage,"scenario_complete":_done,"scenario_revision":_scenario_revision,"revision":_last_revision,"history":_history,"field_history":_field_history,"state_history":_state_history,"sample_history":_sample_history,"building_history":_building_history,"state_roundtrip":_state_roundtrip,"load_history":_load_history,"checks":_checks,"elapsed_msec":Time.get_ticks_msec()-_began,"fps":Engine.get_frames_per_second(),"roster_count":_network.session.roster.size() if _network!=null else 0}))
	file.close()

func _read(name: String) -> Dictionary:
	var file := FileAccess.open(_directory+"/"+name+".json",FileAccess.READ)
	if file==null or file.get_length()>1048576: return {}
	# Another process may replace its diagnostic report during this read.
	# get_as_text emits an engine error on that harmless short read.
	var length := file.get_length()
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.size()!=length or bytes.is_empty(): return {}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8())!=OK or not json.data is Dictionary: return {}
	return json.data

func _digest(frame: Variant) -> String:
	var codec: RefCounted = load(get_script().resource_path.get_base_dir()+"/value_codec.gd").new()
	var encoded: Dictionary = codec.encode(_ordered(frame),256*1024*1024)
	return encoded.value.get_string_from_utf8().sha256_text() if encoded.ok else "INVALID_"+String(encoded.code)

func _ordered(value: Variant) -> Variant:
	if value is Dictionary:
		var ordered := {}
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant,b: Variant): return _key(a)<_key(b))
		for key in keys: ordered[String(key) if key is StringName else key] = _ordered(value[key])
		return ordered
	if value is Array:
		var ordered := []
		for item in value: ordered.append(_ordered(item))
		return ordered
	return String(value) if value is StringName else value

func _key(value: Variant) -> String:
	return ("s:" if value is String or value is StringName else "i:")+str(value)

func _argument(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for argument in args:
		if argument.begins_with(prefix): return argument.substr(prefix.length())
	return fallback

func _finish(code: String) -> Dictionary:
	_fatal = code
	_write("FAIL")
	return {"ok":false,"code":code,"value":null}
