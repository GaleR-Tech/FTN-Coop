extends RefCounted

var _adapter: RefCounted
var _primary_checks: Array[Dictionary] = []
var _primary_site := 0

func run(tree: SceneTree, base_dir: String) -> Dictionary:
	_adapter = load(base_dir + "/game_adapter.gd").new()
	_adapter.bind(tree.root)
	var nodes: Dictionary = _adapter.nodes
	var result := {"candidates": _adapter.candidate_report(), "verified": {}, "status": "RUNNING"}
	for role in ["world", "saves", "state", "tech", "player", "field", "builds", "props"]:
		if not nodes.has(role):
			result.status = "MISSING_" + role.to_upper()
			_write(result)
			return result
	var captured: Dictionary = _adapter.capture_world()
	if not captured.ok:
		result.status = captured.code
		_write(result)
		return result
	var payload: Dictionary = captured.value
	result.payload_keys = payload.keys()
	var codec: RefCounted = load(base_dir + "/value_codec.gd").new()
	var encoded: Dictionary = codec.encode(payload, 256 * 1024 * 1024)
	var decoded: Dictionary = codec.decode(encoded.value, 256 * 1024 * 1024) if encoded.ok else encoded
	result.codec_roundtrip = decoded.ok and decoded.value == payload
	if not result.codec_roundtrip:
		result.status = "CODEC_ROUNDTRIP_FAILED"
		_write(result)
		return result
	payload = decoded.value
	result.action_interfaces = _action_interfaces(nodes)
	result.verified.snapshot_capture = true
	result.verified.host_save = true
	result.verified.player_pose = _adapter.read_local_pose().ok
	var world: Node = nodes.world
	var saves: Node = nodes.saves
	var player: Node = nodes.player
	var field: Node = nodes.field
	var heights_before := _heights_hash(field)
	var original_dir: String = saves.call("save_dir")
	var original_slot: int = saves.get("current_slot")
	var original_world_block: bool = world.get("block_save")
	var original_save_block: bool = saves.get("block_save")
	var original_mode: int = world.process_mode
	# Keep every experimental native action out of the original test slot,
	# including when a diagnostic callback fails before the final reload.
	world.set("block_save",true)
	saves.set("block_save",true)
	result.test_saves_guarded = bool(world.get("block_save")) and bool(saves.get("block_save"))
	var live_before: Dictionary = _adapter._live_frame()
	result.remote_controller = await _check_remote_controller(tree, nodes)
	result.adapter_actions = await _check_adapter_actions(tree,nodes)
	result.verified.host_apply = await _check_host_primary(tree, nodes)
	result.primary_checks = _primary_checks
	result.snapshot_player_type = typeof(payload.player)
	result.snapshot_bounds = {"cell":payload.cell,"extent":payload.extent,"heights":payload.heights.size(),"version":payload.version}
	result.snapshot_validated = _adapter._snapshot_valid(payload)
	result.native_frame_shapes = _shape(_adapter._live_frame(),0)
	_adapter.set_guest_mode(true)
	result.rejected_frame_keys = []
	result.frame_field_codes = {}
	for key in live_before:
		if not _adapter._patch_valid({key:live_before[key]}): result.rejected_frame_keys.append(key)
		result.frame_field_codes[key] = codec.encode(live_before[key],64*1024*1024).code
	var restored_live: Dictionary = _adapter.apply_confirmed_event({"revision":1,"patch":live_before})
	result.incremental_restore = {"ok":restored_live.ok,"code":restored_live.code}
	if restored_live.ok:
		for frame in range(30):
			_adapter.pump_guest_visuals()
			await tree.process_frame
		var after_live: Dictionary = _adapter._live_frame()
		result.incremental_restore.differing_keys = []
		for key in live_before:
			if live_before[key] != after_live.get(key): result.incremental_restore.differing_keys.append(key)
		result.incremental_restore.exact = result.incremental_restore.differing_keys.is_empty()
	_adapter.set_guest_mode(false)
	world.set("block_save",true)
	saves.set("block_save",true)
	world.process_mode = original_mode
	var hay_before_capture := float(nodes.state.get("hay_dug"))
	# Pause the whole world, leaving our autoload outside it enabled.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	result.verified.guest_mutation_guard = not player.can_process()
	result.verified.machine_host_only = not nodes.builds.can_process() and not nodes.props.can_process()
	var bridge: Node = load(base_dir + "/input_bridge.gd").new()
	var requests: Array = []
	bridge.action_requested.connect(func(kind: String, body: Dictionary): requests.append({"kind": kind, "payload": body}))
	tree.root.add_child(bridge)
	bridge.enabled = true
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await tree.process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	await tree.process_frame
	bridge.enabled = false
	bridge.queue_free()
	result.verified.action_capture = requests.size() == 2 and float(nodes.state.get("hay_dug")) == hay_before_capture
	world.process_mode = original_mode
	result.input_callbacks_available = player.has_method("_unhandled_input")
	result.primary_dispatch_available = player.has_method("_active_tool_primary")
	var session_dir := "user://ftn_coop/sessions/integration-" + str(Time.get_ticks_usec())
	world.set("block_save", true)
	saves.set("block_save", true)
	saves.call("use_scratch_dir", session_dir)
	var scratch_dir: String = saves.call("save_dir")
	var scratch_path: String = saves.call("slot_path", 1)
	result.verified.isolated_guest_session = scratch_dir.begins_with(session_dir) and scratch_path.begins_with(session_dir + "/")
	if not result.verified.isolated_guest_session or saves.call("write_file", scratch_path, payload) != true:
		result.status = "SCRATCH_WRITE_FAILED"
		saves.call("use_scratch_dir", original_dir)
		saves.set("block_save", original_save_block)
		world.set("block_save", original_world_block)
		_write(result)
		return result
	# The native loader consumes the validated locally captured payload.
	saves.call("begin_load", 1)
	var world_scene: String = world.scene_file_path
	if tree.change_scene_to_file(world_scene) != OK:
		result.status = "NATIVE_RELOAD_FAILED"
		saves.call("use_scratch_dir", original_dir)
		saves.set("block_save", original_save_block)
		_write(result)
		return result
	for frame in range(1800):
		await tree.process_frame
		var current: Node = tree.current_scene
		if current != null and current.scene_file_path == world_scene:
			if bool(current.get("_built")):
				_adapter.bind(tree.root)
				result.verified.snapshot_restore = _heights_hash(_adapter.nodes.field) == heights_before
				current.set("block_save", true)
				result.status = "COMPLETE" if result.verified.action_capture and result.verified.host_apply else "COMPLETE_WITH_UNVERIFIED_ACTIONS"
				break
	if result.status == "RUNNING":
		result.status = "NATIVE_RELOAD_TIMEOUT"
	# Keep the reloaded test world unable to save over the original slot.
	saves.call("use_scratch_dir", original_dir)
	saves.set("current_slot", original_slot)
	saves.set("block_save", true)
	_write(result)
	return result

func _check_host_primary(tree: SceneTree, nodes: Dictionary) -> bool:
	var player: Node3D = nodes.player
	var field: Node = nodes.field
	var state: Node = nodes.state
	if not field.has_method("top_at") or not player.has_method("set_look"):
		return false
	var original_transform := player.global_transform
	var original_tool := int(player.get("current_tool"))
	player.call("_set_tool",0,true) # Native Tool.HAND, measured in the action probe.
	var hand: Node = player.get("hand")
	if hand == null or not hand.has_method("count") or int(hand.call("count")) != 0:
		_primary_checks.append({"ok":false,"reason":"HAND_NOT_EMPTY"})
		player.call("_set_tool",original_tool,true)
		return false
	var before := float(state.get("hay_dug"))
	var x := -4.0 if _primary_site == 0 else 4.0
	_primary_site += 1
	player.global_position = Vector3(x, float(field.call("top_at", x, 3.0)) + 0.2, 3.0)
	player.call("set_look", 0.0, -1.35)
	await tree.physics_frame
	await tree.physics_frame
	player.call("_active_tool_primary", true)
	await tree.physics_frame
	var changed := float(state.get("hay_dug")) > before and int(hand.call("count")) > 0
	_primary_checks.append({"ok":changed,"dug_increased":float(state.get("hay_dug"))>before,"holding_hay":int(hand.call("count"))>0})
	player.call("_active_tool_primary", false)
	if hand.has_method("drop_held"):
		hand.call("drop_held")
	player.global_transform = original_transform
	player.call("_set_tool",original_tool,true)
	return changed

func _action_interfaces(nodes: Dictionary) -> Dictionary:
	var targets := nodes.duplicate()
	for member in ["shop", "shop_menu", "catalog_panel"]:
		var target: Variant = nodes.world.get(member)
		if target is Node: targets[member] = target
	for member in ["build", "hand", "carry"]:
		var target: Variant = nodes.player.get(member)
		if target is Node: targets[member] = target
	var report := {}
	for role in targets:
		var script: Script = targets[role].get_script()
		if script == null: continue
		var methods := []
		for method in script.get_script_method_list():
			var args := []
			for arg in method.args: args.append(arg.name)
			methods.append({"name":method.name,"args":args})
		report[role] = {"methods":methods}
	return report

func _check_remote_controller(tree: SceneTree, nodes: Dictionary) -> Dictionary:
	var source: Node = nodes.player
	var created: Dictionary = await _adapter.prepare_actor(2)
	if not created.ok: return {"status":created.code}
	var actor: Node = created.value
	var report := {"hand_isolated":actor.get("hand") is Node and actor.get("hand") != source.get("hand"),"camera_created":actor.get("camera") is Camera3D}
	if actor.get("camera") is Camera3D: actor.get("camera").current = false
	if source.get("camera") is Camera3D: source.get("camera").current = true
	if report.hand_isolated:
		var test_nodes := nodes.duplicate()
		test_nodes.player = actor
		report.primary = await _check_host_primary(tree,test_nodes)
	else: report.primary = false
	var shop: Node = nodes.world.get("shop")
	var menu: Node = nodes.world.get("shop_menu")
	var catalog: Node = nodes.world.get("catalog_panel")
	if catalog != null and catalog.get("_tiles") is Dictionary:
		report.catalog_ids = catalog.get("_tiles").keys()
	if shop != null and shop.has_method("display_ids") and menu != null:
		report.shop_ids = shop.call("display_ids")
		report.purchase_attempts = []
		actor.global_position = shop.call("interact_point")
		var starting_money := float(nodes.state.get("money"))
		if menu.has_method("_licence_ids"):
			report.licence_ids = menu.call("_licence_ids")
			for licence in report.licence_ids:
				nodes.state.set("money",1000000.0)
				menu.call("_on_licence",licence)
		for id in report.shop_ids:
			var price := float(shop.call("live_price",id))
			if price <= 0.0: continue
			var original_player: Node = menu.get("player")
			var original_open := bool(menu.get("_open"))
			var original_money := float(nodes.state.get("money"))
			nodes.state.set("money", price)
			menu.set("player", actor)
			menu.set("_open",true)
			report.counter_ready = menu.call("is_at_counter")
			menu.call("_on_buy",id)
			report.purchase = float(nodes.state.get("money")) < price
			var label: Variant = menu.get("_status_label")
			report.purchase_attempts.append({"id":id,"success":report.purchase,"reason":label.text if label is Label else ""})
			menu.set("player", original_player)
			menu.set("_open",original_open)
			nodes.state.set("money", original_money)
			if report.purchase: break
		nodes.state.set("money",starting_money)
	var scanner: Variant = nodes.builds.call("add_scanner",Vector3(8.0,0.0,8.0),0.0,1)
	if scanner is Node:
		report.scanner_created = true
		scanner.process_mode = Node.PROCESS_MODE_DISABLED
		var stored_before := int(scanner.get("stored"))
		scanner.call("_take_in","hay",10)
		report.machine_feed = int(scanner.get("stored")) > stored_before
		report.scanner_methods = []
		for method in scanner.get_script().get_script_method_list():
			var args := []
			for arg in method.args: args.append({"name":arg.name,"type":arg.type})
			report.scanner_methods.append({"name":method.name,"args":args})
		report.scanner_properties = []
		for property in scanner.get_script().get_script_property_list():
			report.scanner_properties.append({"name":property.name,"type":property.type})
	else: report.scanner_created = false
	report.tech_constants = {}
	for key in nodes.tech.get_script().get_script_constant_map():
		report.tech_constants[key] = typeof(nodes.tech.get_script().get_script_constant_map()[key])
	_adapter.remove_actor(2)
	await tree.process_frame
	return report

func _heights_hash(field: Node) -> String:
	var bytes := var_to_bytes(field.get("heights"))
	return bytes.hex_encode().sha256_text()

func _check_adapter_actions(tree: SceneTree, nodes: Dictionary) -> Dictionary:
	var created: Dictionary = await _adapter.prepare_actor(3)
	if not created.ok: return {"status":created.code}
	var actor: Node3D = created.value
	var sync: Node = load(get_script().resource_path.get_base_dir()+"/world_sync.gd").new()
	tree.root.add_child(sync)
	sync.configure(_adapter,true)
	sync.set_ready(3,true)
	var report := {}
	report.tool_enums = {}
	for key in actor.get_script().get_script_constant_map():
		var constant: Variant = actor.get_script().get_script_constant_map()[key]
		if constant is Dictionary and not constant.is_empty():
			var only_ints := true
			for value in constant.values():
				if typeof(value) != TYPE_INT: only_ints = false
			if only_ints: report.tool_enums[key] = constant
	actor.global_position = Vector3(0,float(nodes.field.call("top_at",0.0,0.0))+0.2,0)
	actor.call("set_look",0.0,-1.35)
	await tree.physics_frame
	await tree.physics_frame
	var before := float(nodes.state.get("hay_dug"))
	var dig: Dictionary = sync.submit_action(3,1,"dig",{"pressed":true})
	report.dig = dig.ok and float(nodes.state.get("hay_dug")) > before
	var after := float(nodes.state.get("hay_dug"))
	sync.submit_action(3,1,"dig",{"pressed":true})
	report.deduplicated = float(nodes.state.get("hay_dug")) == after
	sync.submit_action(3,2,"dig",{"pressed":false})
	var dropped: Dictionary = sync.submit_action(3,3,"item_interact",{"operation":"drop"})
	report.item_drop = dropped.ok and int(actor.get("hand").call("count")) == 0
	var shop: Node = nodes.world.get("shop")
	actor.global_position = shop.call("interact_point")
	report.shop_near = shop.call("is_near",actor.global_position)
	var price := float(shop.call("live_price","bucket"))
	nodes.state.set("money",price)
	var bought: Dictionary = sync.submit_action(3,4,"purchase",{"id":"bucket"})
	report.purchase = {"ok":bought.ok,"code":bought.code,"charged":float(nodes.state.get("money")) < price}
	nodes.state.set("money",1000000.0)
	var sequence := 5
	var panel: Node = nodes.world.get("tech_panel")
	report.scanner_cards = []
	if panel != null and panel.get("_cards") is Dictionary:
		for id in panel.get("_cards"):
			if String(id).contains("scan"): report.scanner_cards.append(id)
		for id in panel.get("_cards"):
			var upgraded: Dictionary = sync.submit_action(3,sequence,"upgrade",{"id":id})
			sequence += 1
			if upgraded.ok:
				report.upgrade = true
				break
	if not report.has("upgrade"): report.upgrade = false
	# Diagnostic-only unlock from the actual registered research card.
	# Normal remote actions always use the native purchase/research checks.
	if "scanner_mk1" in report.scanner_cards: nodes.tech.call("grant","scanner_mk1",1)
	actor.global_position = Vector3(10,0,14)
	actor.call("set_look",0.0,-0.85)
	await tree.physics_frame
	await tree.physics_frame
	var count_before: int = nodes.builds.call("to_array").size()
	var placed: Dictionary = sync.submit_action(3,sequence,"place",{"id":"scanner"})
	sequence += 1
	report.place = {"ok":placed.ok,"changed":nodes.builds.call("to_array").size()>count_before,"code":placed.code}
	report.place_status = actor.get("build").call("status")
	if not report.place.changed:
		# Find a native-approved flat test site, rather than placing on the pile.
		for x in [-12.0,-8.0,8.0,12.0]:
			for z in [-12.0,-8.0,8.0,12.0]:
				actor.global_position = Vector3(x,float(nodes.field.call("top_at",x,z))+0.1,z)
				actor.call("set_look",0.0,-0.7)
				await tree.physics_frame
				await tree.physics_frame
				var attempted: Dictionary = sync.submit_action(3,sequence,"place",{"id":"scanner"})
				sequence += 1
				if nodes.builds.call("to_array").size() > count_before:
					report.place = {"ok":attempted.ok,"changed":true,"code":attempted.code}
					break
			if report.place.changed: break
	if report.place.changed:
		var machines: Array = nodes.builds.get("scanners")
		var machine: Node3D = machines[-1]
		actor.call("put_away_build")
		actor.global_position = machine.global_position+Vector3(2.5,0,0)
		var aim: Vector3 = machine.global_position+Vector3(0,1.0,0)-actor.get("camera").global_position
		actor.call("set_look",atan2(-aim.x,-aim.z),atan2(aim.y,Vector2(aim.x,aim.z).length()))
		await tree.physics_frame
		await tree.physics_frame
		var configured: Dictionary = sync.submit_action(3,sequence,"machine_config",{"switched_off":true})
		sequence += 1
		report.machine_config = {"ok":configured.ok,"code":configured.code,"changed":machine.get("switched_off")==true}
		var before_demolish: int = nodes.builds.call("to_array").size()
		var removed: Dictionary = sync.submit_action(3,sequence,"demolish",{})
		sequence += 1
		report.demolish = {"ok":removed.ok,"code":removed.code,"changed":nodes.builds.call("to_array").size()<before_demolish}
	var index := -1
	var taken: PackedByteArray = nodes.state.get("needle_taken")
	for candidate in range(taken.size()):
		if taken[candidate] == 0:
			index = candidate
			break
	if index >= 0:
		var body: Node3D = nodes.world.get("live").call("reveal_needle",index,Vector3(12,1.4,12))
		actor.call("put_away_build")
		sync.submit_action(3,sequence,"item_interact",{"operation":"drop"})
		sequence += 1
		report.needle_hand_active = actor.get("hand").get("_active")
		report.needle_current_tool = actor.get("current_tool")
		report.needle_hand_count = actor.get("hand").call("count")
		report.needle_carrying = actor.get("carry").call("is_carrying")
		report.needle_taken_before = nodes.state.get("needle_taken")[index]
		report.needle_meta = body.get_meta_list() if body != null else []
		if body != null:
			actor.global_position = Vector3(body.global_position.x,0.0,body.global_position.z+0.5)
			var direction: Vector3 = body.global_position - actor.get("camera").global_position
			actor.call("set_look",atan2(-direction.x,-direction.z),atan2(direction.y,Vector2(direction.x,direction.z).length()))
		await tree.physics_frame
		await tree.physics_frame
		report.needle_hit = not actor.get("hand").call("needle_hit").is_empty()
		var collected: Dictionary = sync.submit_action(3,sequence,"needle_collect",{})
		sequence += 1
		report.needle_collect = collected.ok and bool(actor.get("hand").call("is_holding_needle"))
		report.needle_visible = body != null
		if not report.needle_collect:
			report.native_needle_take = actor.get("hand").call("take_needle",index,body.global_position) if body != null else false
		var cabinet: Node3D = nodes.builds.call("add_cabinet",Vector3(12,0,10),0.0,false)
		if cabinet != null:
			actor.global_position = cabinet.global_position + Vector3(0,0,0.75)
			await tree.physics_frame
			await tree.physics_frame
			report.native_needle_deposit = actor.get("hand").call("deposit_into",cabinet)
			report.native_needle_deposit_twice_refused = not bool(actor.get("hand").call("deposit_into",cabinet))
	var live: Node = nodes.world.get("live")
	var active: Variant = live.get("_active")
	report.loose_active_type = typeof(active)
	if active is Array and not active.is_empty(): report.loose_element_type = typeof(active[0])
	var bucket: Variant = nodes.props.call("spawn_at_feet","bucket",actor)
	report.prop_spawned = bucket is Node
	var frame: Dictionary = _adapter._live_frame()
	var codec: RefCounted = load(get_script().resource_path.get_base_dir()+"/value_codec.gd").new()
	var encoded_frame: Dictionary = codec.encode(frame,256*1024*1024)
	report.frame_encodes = encoded_frame.ok
	report.frame_encode_code = encoded_frame.code
	_adapter.remove_actor(3)
	sync.queue_free()
	await tree.process_frame
	return report

func _shape(value: Variant, depth: int) -> Variant:
	if depth > 4: return typeof(value)
	if value is Dictionary:
		var fields := {}
		for key in value: fields[str(key)] = _shape(value[key],depth+1)
		return fields
	if value is Array:
		return {"type":TYPE_ARRAY,"count":value.size(),"first":_shape(value[0],depth+1) if not value.is_empty() else null}
	return typeof(value)

func _write(result: Dictionary) -> void:
	var file := FileAccess.open("user://ftn_coop/integration-result.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result))
		file.close()
	print("[FTN-Coop] integration check: " + str(result.status))
