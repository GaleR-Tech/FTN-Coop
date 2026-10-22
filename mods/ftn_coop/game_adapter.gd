extends RefCounted

const MODULE_DIR := "res://mods/ftn_coop"

const SCRIPT_PATHS := {
	"cfg": "res://autoload/cfg.gd",
	"saves": "res://autoload/save_manager.gd",
	"state": "res://autoload/game_state.gd",
	"tech": "res://autoload/tech.gd",
	"world": "res://scripts/world/world.gd",
}

var nodes: Dictionary = {}
var verified: Dictionary = {}
var guest_mode := false
var actors: Dictionary = {}
var _previous_frame: Dictionary = {}
var _save_origin: Dictionary = {}
var _guest_directory := ""
var _world_mode := Node.PROCESS_MODE_INHERIT
var _loose: RefCounted
var last_sync_error := ""
var _actor_factory: RefCounted
var _actor_epochs: Dictionary = {}
var _actor_serial := 0
var _collision_tree: SceneTree
var _guest_colliders: Dictionary = {}
var _restore_epoch := 0
var _closing_guest := false
var _guest_save_block := false
var _guest_world_block := false
var _settings_scope: RefCounted
var _quest_world_id := 0
var _quest_index := -1
var _guest_quest: Dictionary = {}
var _shared_tools_scope: RefCounted
var _props_replica: RefCounted
var _local_peer := 0
var _guest_countdown: Dictionary = {}
var _countdown_world_id := 0
var _guest_field: RefCounted
var _tool_load_state: RefCounted
var _build_capture: RefCounted
var _guest_belts: Dictionary = {}
var _guest_belts_ready := false
var _guest_belts_world := 0
var _belts_pending := false
var _belts_world_id := 0
var _belts_epoch := 0
var _belt_paths: Array[Node] = []
var _belt_paths_world := 0

func _clear_belt_records() -> void:
	if not nodes.has("world"): return
	var world: Node = nodes.world
	if _belt_paths_world!=world.get_instance_id():
		_belt_paths.clear()
		_collect_belt_paths(world)
		_belt_paths_world = world.get_instance_id()
	for path in _belt_paths:
		if not is_instance_valid(path): continue
		var run: Variant = path.get("run")
		if run is Object and run.has_method("clear"): run.call("clear")
	if nodes.has("builds"):
		for category in ["hay_lifts","hay_stairs"]:
			var machines: Variant = nodes.builds.get(category)
			if not machines is Array: continue
			for machine in machines:
				if not is_instance_valid(machine): continue
				var carried: Variant = machine.get("_carried")
				if not carried is Array: continue
				for row in carried:
					if row is Dictionary and row.get("draw") is Node and is_instance_valid(row.draw): row.draw.free()
				carried.clear()

func _collect_belt_paths(node: Node) -> void:
	if node.has_method("records_to_save"):
		var run: Variant = node.get("run")
		if run is Object and run.has_method("clear"): _belt_paths.append(node)
	for child in node.get_children(): _collect_belt_paths(child)

func _read_belts() -> Dictionary:
	if guest_mode and _guest_belts_ready and nodes.has("world") and _guest_belts_world==nodes.world.get_instance_id(): return _guest_belts.duplicate(true)
	return nodes.world.call("_belts_to_dict").duplicate(true)

func _queue_belt_render() -> void:
	var world_id: int = nodes.world.get_instance_id()
	if not _guest_belts_ready or _guest_belts_world!=world_id: return
	if _belts_pending and _belts_world_id==world_id: return
	_belts_epoch += 1
	_belts_pending = true
	_belts_world_id = world_id
	_render_belts.call_deferred(world_id,_belts_epoch)

func _render_belts(world_id: int, epoch: int) -> void:
	if epoch!=_belts_epoch: return
	_belts_pending = false
	if not guest_mode or not _guest_belts_ready or _guest_belts_world!=world_id or not nodes.has("world") or not is_instance_valid(nodes.world) or nodes.world.get_instance_id()!=world_id or not nodes.has("saves"): return
	# Native load import adds cargo and spills blocked records into props.
	# Clear only the guest run storage; clear_path() would destroy the belt
	# geometry and spill its load. The host's simulation is never touched.
	_clear_belt_records()
	nodes.saves.set("_pending_belts",_guest_belts.duplicate(true))
	nodes.world.call("_restore_belts")

func _tool_loads() -> RefCounted:
	if _tool_load_state==null: _tool_load_state = load(MODULE_DIR+"/tool_load_state.gd").new()
	return _tool_load_state

func read_local_tool_load() -> Dictionary:
	if not guest_mode or not nodes.has("player"): return {}
	return _tool_loads().selected(_local_peer,int(nodes.player.get("current_tool")))

func probe(root: Node) -> Dictionary:
	if root == null or not is_instance_valid(root):
		return {"ok": false, "code": "ROOT_MISSING", "value": null}
	bind(root)
	var bindings: RefCounted = load(MODULE_DIR + "/game_bindings.gd").new()
	for available in candidate_report().values():
		if available != true:
			return {"ok": false, "code": "CAPABILITY_MISSING", "value": null}
	if nodes.world.get("_built")!=true: return _error("WORLD_NOT_READY")
	if not Engine.has_singleton("Steam") or not ClassDB.class_exists("SteamMultiplayerPeer"):
		return {"ok": false, "code": "CAPABILITY_MISSING", "value": null}
	verified = bindings.verified_evidence(game_build())
	return bindings.check_evidence(verified)

func game_build() -> String:
	var steamapps := OS.get_executable_path().get_base_dir().get_base_dir().get_base_dir()
	var manifest := FileAccess.open(steamapps.path_join("appmanifest_5165210.acf"), FileAccess.READ)
	if manifest == null or manifest.get_length() > 65536:
		return ""
	var content := manifest.get_as_text()
	manifest.close()
	return _manifest_build(OS.get_executable_path(),content)

func _manifest_build(executable: String, content: String) -> String:
	var pattern := RegEx.new()
	pattern.compile('"appid"\\s+"([0-9]+)"')
	var app := pattern.search(content)
	if app==null or app.get_string(1)!="5165210": return ""
	pattern.compile('"installdir"\\s+"([^"/\\\\]+)"')
	var directory := pattern.search(content)
	if directory==null or directory.get_string(1).to_lower()!=executable.replace("\\","/").get_base_dir().get_file().to_lower(): return ""
	pattern.compile('"buildid"\\s+"([0-9]+)"')
	var matched := pattern.search(content)
	return matched.get_string(1) if matched != null else ""

func bind(root: Node) -> Dictionary:
	nodes.clear()
	# Autoloads and the world are direct children in the measured demo.
	var candidates: Array[Node] = [root]
	candidates.append_array(root.get_children())
	for candidate in candidates:
		var script: Script = candidate.get_script() as Script
		if script == null:
			continue
		for role in SCRIPT_PATHS:
			if script.resource_path == SCRIPT_PATHS[role]:
				nodes[role] = candidate
	if nodes.has("world"):
		for role in ["field", "player", "builds", "props", "live"]:
			var member: Variant = nodes.world.get(role)
			if member is Node:
				nodes[role] = member
	return candidate_report()

func candidate_report() -> Dictionary:
	var report := {}
	for role in SCRIPT_PATHS:
		report[role] = nodes.has(role)
	for role in ["field", "player", "builds", "props", "live"]:
		report[role] = nodes.has(role)
	var checks := {
		"saves": ["build_payload", "use_scratch_dir", "use_player_saves", "write_file", "begin_load"],
		"state": ["to_dict", "from_dict"],
		"tech": ["to_dict", "from_dict"],
		"world": ["save_now", "_belts_to_dict"],
		"builds": ["to_array", "from_array"],
		"props": ["to_array", "from_array"],
		"player": ["set_look", "_active_tool_primary", "_accepts_input"],
	}
	for role in checks:
		for method in checks[role]:
			report[role + "." + method] = nodes.has(role) and nodes[role].has_method(method)
	return report

func read_local_pose() -> Dictionary:
	if not nodes.has("player") or not is_instance_valid(nodes.player):
		return {"ok": false, "code": "PLAYER_MISSING", "value": null}
	var player: Node3D = nodes.player
	var rotation := player.global_rotation
	var head: Variant = player.get("head")
	if head is Node3D: rotation.x = head.rotation.x
	var pose := {"position":player.global_position,"rotation":rotation}
	var tool: Variant = player.get("current_tool")
	if typeof(tool)==TYPE_INT: pose.tool = tool
	return {"ok":true,"code":"OK","value":pose}

func set_local_spawn(transform: Transform3D) -> Dictionary:
	if not nodes.has("player") or not _safe_native_data(transform,0) or transform.origin.length()>2048.0: return _error("POSE_INVALID")
	nodes.player.global_transform = transform
	return _ok()

func local_player_body() -> CharacterBody3D:
	return nodes.get("player") as CharacterBody3D

func read_marker_target() -> Dictionary:
	var player := local_player_body()
	if player==null or not player.is_inside_tree(): return _error("WORLD_NOT_READY")
	var camera: Variant = player.get("camera")
	if not camera is Camera3D or not camera.is_inside_tree(): return _error("MARKER_NO_SURFACE")
	var origin: Vector3 = camera.global_position
	var target: Vector3 = origin-camera.global_basis.z*50.0
	var query := PhysicsRayQueryParameters3D.create(origin,target,0xffffffff,[player.get_rid()])
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.get("position") is Vector3 or not hit.position.is_finite() or player.global_position.distance_to(hit.position)>50.0: return _error("MARKER_NO_SURFACE")
	return _ok(hit.position)

func marker_input_allowed() -> bool:
	return Input.mouse_mode==Input.MOUSE_MODE_CAPTURED

func set_local_look(yaw: float, pitch: float) -> void:
	if not guest_mode or not is_finite(yaw) or not is_finite(pitch): return
	var player := local_player_body()
	if player==null: return
	if player.has_method("set_look"): player.call("set_look",yaw,clampf(pitch,-1.5,1.5))
	else: player.rotation.y = yaw

func select_local_tool(index: int) -> Dictionary:
	if not guest_mode: return _error("HOST_ONLY")
	if not nodes.has("player") or index<0 or index>8: return _error("ACTION_INVALID")
	if not bool(nodes.player.call("is_tool_unlocked",index)): return _error("TOOL_LOCKED")
	nodes.player.call("_set_tool",index,true)
	if nodes.player.has_method("_sync_hands"): nodes.player.call("_sync_hands")
	return _ok()

func select_hotbar_slot(index: int) -> void:
	if guest_mode and nodes.has("player") and index>=0 and index<10:
		# Number keys address the compact visible bar, not hidden tool indices.
		nodes.player.call("select_hotbar_key",index)
		if nodes.player.has_method("_sync_hands"): nodes.player.call("_sync_hands")

func read_actor_equipment(peer: int) -> Dictionary:
	return {"tool":int(actors[peer].get("current_tool"))} if actors.has(peer) and is_instance_valid(actors[peer]) else {}

func read_actor_build_state(peer: int) -> Dictionary:
	if not actors.has(peer) or not is_instance_valid(actors[peer]) or actors[peer].get("current_tool")!=8: return {}
	var actor: Node = actors[peer]
	var tool: Node = actor.get("build")
	return {"id":actor.get("build_id"),"state":tool.get("_state"),"anchor":tool.get("_anchor")}

func apply_local_build_state(value: Dictionary) -> Dictionary:
	if value.size()!=3 or not value.get("id") is String or value.id.length()>100 or not _safe_native_data(value,0): return _error("ACTION_INVALID")
	if typeof(value.get("state"))!=TYPE_INT or value.state<0 or value.state>16 or not value.get("anchor") is Vector3 or value.anchor.length()>2048.0: return _error("ACTION_INVALID")
	if not guest_mode or not nodes.has("player"): return _error("WORLD_NOT_READY")
	var player: Node = nodes.player
	if player.get("current_tool")!=8 or player.get("build_id")!=value.id: return _ok()
	var tool: Node = player.get("build")
	tool.set("_state",value.state)
	tool.set("_anchor",value.anchor)
	# Only restore the confirmed construction stage. Calling primary() here
	# would spend money and create an unauthorized local building.
	return _ok()

func apply_local_equipment(value: Dictionary) -> Dictionary:
	if value.size()!=1 or typeof(value.get("tool"))!=TYPE_INT or value.tool<0 or value.tool>8: return _error("ACTION_INVALID")
	if not guest_mode or not nodes.has("player"): return _error("WORLD_NOT_READY")
	if nodes.player.get("current_tool")==value.tool: return _ok()
	return select_local_tool(value.tool)

func start_shared_tools() -> void:
	stop_shared_tools()
	if not nodes.has("state") or not nodes.has("player") or not nodes.player.has_method("tool_unlock"): return
	var ids := []
	for index in range(8): ids.append(nodes.player.call("tool_unlock",index))
	_shared_tools_scope = load(MODULE_DIR+"/shared_tools.gd").new()
	_shared_tools_scope.configure(nodes.state,ids)

func stop_shared_tools() -> void:
	if _shared_tools_scope!=null: _shared_tools_scope.close()
	_shared_tools_scope = null
	if _build_capture!=null: _build_capture.close()

func try_shared_tool_pickup(actor: Node) -> bool:
	if _shared_tools_scope==null or not nodes.has("props") or actor==null: return false
	var carry: Node = actor.get("carry")
	if carry==null or not carry.has_method("_probe"): return false
	var item: Variant = carry.call("_probe",false)
	if not item is Node3D or not nodes.props.get("items").has(item): return false
	var id: Variant = item.get("tool_id")
	if not id is String or not _shared_tools_scope.contains(id): return false
	actor.call("equip_tool_id",id)
	var index := int(actor.get("current_tool"))
	if actor.call("tool_unlock",index)!=id: return false
	nodes.props.call("remove",item)
	return true

func select_local_build(id: String) -> Dictionary:
	if not guest_mode: return _error("HOST_ONLY")
	if not nodes.has("world") or not nodes.has("player"): return _error("WORLD_NOT_READY")
	var catalogue: Node = nodes.world.get("catalog_panel")
	if catalogue==null or not catalogue.get("_tiles") is Dictionary or not catalogue.get("_tiles").has(id): return _error("ACTION_INVALID")
	nodes.player.call("equip_build",id)
	return _ok() if nodes.player.get("build_id")==id else _error("BUILD_LOCKED")

func selected_build_id() -> String:
	if not guest_mode or not nodes.has("player"): return ""
	var id: Variant = nodes.player.get("build_id")
	return id if id is String else ""

func set_local_peer(peer: int) -> void:
	_local_peer = peer

func _prop_module() -> RefCounted:
	if _props_replica==null: _props_replica = load(MODULE_DIR+"/prop_replica.gd").new()
	return _props_replica

func pump_local_preview(delta: float) -> void:
	if not guest_mode or not nodes.has("player") or nodes.player.get("current_tool")!=8: return
	var build: Node = nodes.player.get("build")
	if build!=null: build.call("_frame",delta)

func shared_summary() -> Dictionary:
	if not nodes.has("state") or not is_instance_valid(nodes.state): return {}
	return {"money":nodes.state.get("money"),"needles":nodes.state.get("needles_found")}

func _settings() -> RefCounted:
	if _settings_scope==null: _settings_scope = load(MODULE_DIR+"/shared_settings.gd").new()
	if nodes.has("cfg") and is_instance_valid(nodes.cfg): _settings_scope.configure(nodes.cfg)
	return _settings_scope

func read_shared_settings() -> Dictionary:
	return _settings().capture()

func apply_shared_settings(values: Variant) -> Dictionary:
	return _settings().accept(values)

func maintain_shared_settings() -> Dictionary:
	return _settings().enforce()

func restore_shared_settings() -> void:
	if _settings_scope!=null: _settings_scope.release()

func update_shared_setting(key: String, value: Variant) -> Dictionary:
	if guest_mode: return _error("HOST_ONLY")
	return _settings().update_host(key,value)

func update_shared_settings(values: Variant) -> Dictionary:
	if guest_mode: return _error("HOST_ONLY")
	return _settings().update_host_values(values)

func guest_options() -> Dictionary:
	var result := {"tools":[],"shop":[],"buildings":[],"upgrades":[]}
	if not guest_mode or not nodes.has("world") or not nodes.has("player"): return result
	var tool_names := ["Hand","Schaufel","Heugabel","Besen","Spielzeug","Metalldetektor","Hofsauger","Feuerzeug"]
	for index in range(tool_names.size()):
		if bool(nodes.player.call("is_tool_unlocked",index)): result.tools.append({"id":index,"label":tool_names[index],"label_key":tool_names[index]})
	var shop_names := {"wheelbarrow":"Schubkarre","spade":"Spaten","pitchfork":"Heugabel","bucket":"Eimer","sand_shovel":"Sandschaufel"}
	var shop: Node = nodes.world.get("shop")
	if shop!=null:
		for id in shop.call("display_ids"):
			if shop_names.has(id):
				var price := float(shop.call("live_price",id))
				result.shop.append({"id":id,"label":shop_names[id]+" · %.0f $" % price,"label_key":shop_names[id],"price":price})
	var catalogue: Node = nodes.world.get("catalog_panel")
	if catalogue!=null and catalogue.get("_tiles") is Dictionary:
		for id in catalogue.get("_tiles"):
			var title := _native_control_title(catalogue.get("_tiles")[id])
			if not title.is_empty(): result.buildings.append({"id":id,"label":title.get_slice("\n",0).left(100)})
	var research: Node = nodes.world.get("tech_panel")
	if research!=null and research.get("_cards") is Dictionary:
		for id in research.get("_cards"):
			var title := _native_control_title(research.get("_cards")[id])
			if not title.is_empty(): result.upgrades.append({"id":id,"label":title})
	return result

func _native_control_title(value: Variant) -> String:
	var queue: Array = [value]
	var count := 0
	while not queue.is_empty() and count<96:
		var item: Variant = queue.pop_front()
		count += 1
		if item is Label and not item.text.strip_edges().is_empty(): return item.text.strip_edges().left(100)
		if item is RichTextLabel and not item.get_parsed_text().strip_edges().is_empty(): return item.get_parsed_text().strip_edges().left(100)
		if item is Node: queue.append_array(item.get_children())
		elif item is Dictionary: queue.append_array(item.values())
	return ""

func capture_world() -> Dictionary:
	if not nodes.has("world") or not nodes.has("saves"):
		return {"ok": false, "code": "CAPABILITY_MISSING", "value": null}
	var world: Node = nodes.world
	var saves: Node = nodes.saves
	if not is_instance_valid(world) or not is_instance_valid(saves): return _error("WORLD_NOT_READY")
	if not world.has_method("save_now") or not saves.has_method("_read"):
		return {"ok": false, "code": "CAPABILITY_MISSING", "value": null}
	if bool(world.get("block_save")) or bool(saves.get("block_save")):
		return {"ok": false, "code": "HOST_ONLY", "value": null}
	if not bool(world.get("_built")):
		return {"ok": false, "code": "WORLD_NOT_READY", "value": null}
	# Let the game account for tools, machines and loose hay in its own format.
	var slot := int(saves.get("current_slot"))
	var path: String = saves.call("slot_path",slot)
	var directory: String = saves.call("save_dir")
	if slot<0 or slot>999 or not path.begins_with(directory.trim_suffix("/")+"/"): return _error("SAVE_PATH_INVALID")
	if saves.has_method("finish_write"): saves.call("finish_write")
	var backup := ""
	if FileAccess.file_exists(path):
		var prepared := _backup_host_slot(path)
		if not prepared.ok: return prepared
		backup = prepared.value
	var saved: bool = world.call("save_now", false)==true
	if saves.has_method("finish_write"):
		saves.call("finish_write")
	if not saved:
		return _failed_host_save(backup,path,"SAVE_FAILED")
	var payload: Variant = saves.call("_read",slot)
	if not payload is Dictionary or payload.is_empty():
		return _failed_host_save(backup,path,"SNAPSHOT_INVALID")
	return {"ok": true, "code": "OK", "value": payload}

func save_host_world() -> Dictionary:
	if guest_mode or not _save_origin.is_empty(): return _error("HOST_ONLY")
	var saved := capture_world()
	return _ok() if saved.ok else saved

func _backup_host_slot(path: String) -> Dictionary:
	var source := FileAccess.open(path,FileAccess.READ)
	if source==null or source.get_length()>256*1024*1024: return _error("SAVE_BACKUP_FAILED")
	var bytes := source.get_buffer(source.get_length())
	source.close()
	if bytes.is_empty(): return _error("SAVE_BACKUP_FAILED")
	var backup := path+".ftn-coop-last-good"
	var temporary := backup+".tmp-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return _error("SAVE_BACKUP_FAILED")
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK or FileAccess.get_file_as_bytes(temporary)!=bytes: return _error("SAVE_BACKUP_FAILED")
	if DirAccess.rename_absolute(temporary,backup)!=OK: return _error("SAVE_BACKUP_FAILED")
	return _ok(backup)

func _failed_host_save(backup: String, path: String, code: String) -> Dictionary:
	if not backup.is_empty() and DirAccess.rename_absolute(backup,path)!=OK: return _error("SAVE_RECOVERY_FAILED")
	return _error(code)

func prepare_actor(peer_id: int) -> Dictionary:
	if guest_mode or peer_id <= 1 or not nodes.has("player") or not nodes.has("world"): return _error("ACTOR_NOT_READY")
	if actors.has(peer_id): return _ok(actors[peer_id])
	_actor_serial += 1
	var epoch := _actor_serial
	_actor_epochs[peer_id] = epoch
	if _actor_factory==null: _actor_factory = load(MODULE_DIR+"/native_actor.gd").new()
	var factory := _actor_factory
	var created: Dictionary = factory.create(nodes.player,nodes.world,peer_id)
	if not created.ok: return created
	var actor: Node = created.value
	await nodes.world.get_tree().process_frame
	if epoch!=_actor_epochs.get(peer_id,-1) or guest_mode or not is_instance_valid(actor):
		if is_instance_valid(actor): actor.queue_free()
		return _error("ACTOR_CANCELED")
	var bound: Dictionary = factory.bind_tools(actor,nodes.player)
	if not bound.ok:
		actor.queue_free()
		return bound
	actor.global_transform = nodes.player.global_transform
	actors[peer_id] = actor
	return _ok(actor)

func remove_actor(peer_id: int) -> void:
	_actor_serial += 1
	_actor_epochs[peer_id] = _actor_serial
	if not actors.has(peer_id): return
	var actor: Node = actors[peer_id]
	if is_instance_valid(actor):
		# Return held resources through the game's own release paths.
		actor.call("drop_active_tool")
		if actor.get("hand") is Node: actor.get("hand").call("drop_held")
		if actor.get("carry") is Node: actor.get("carry").call("drop_all")
		actor.queue_free()
	actors.erase(peer_id)

func update_actor_pose(peer_id: int, pose: Dictionary) -> Dictionary:
	if guest_mode or not actors.has(peer_id): return _error("ACTOR_NOT_READY")
	if not pose.get("position") is Vector3 or not pose.get("rotation") is Vector3: return _error("POSE_INVALID")
	var position: Vector3 = pose.position
	var rotation: Vector3 = pose.rotation
	if not position.is_finite() or not rotation.is_finite() or position.length() > 2048.0: return _error("POSE_INVALID")
	if pose.has("tool"):
		if typeof(pose.tool)!=TYPE_INT or pose.tool<0 or pose.tool>8: return _error("POSE_INVALID")
		if actors[peer_id].get("current_tool")!=pose.tool:
			if not bool(actors[peer_id].call("is_tool_unlocked",pose.tool)): return _error("TOOL_LOCKED")
	actors[peer_id].global_position = position
	actors[peer_id].call("set_look",rotation.y,clampf(rotation.x,-1.5,1.5))
	if pose.has("tool"):
		if actors[peer_id].get("current_tool")!=pose.tool:
			actors[peer_id].call("_set_tool",pose.tool,true)
	if actors[peer_id].has_method("_sync_hands"): actors[peer_id].call("_sync_hands")
	return _ok()

func apply_host_action(actor_id: int, kind: String, payload: Dictionary) -> Dictionary:
	if kind not in ["dig","place","demolish","purchase","upgrade","needle_collect","item_interact","machine_config"]: return _error("ACTION_INVALID")
	if guest_mode: return _error("HOST_ONLY")
	if not actors.has(actor_id) or not is_instance_valid(actors[actor_id]): return _error("ACTOR_NOT_READY")
	var actor: Node = actors[actor_id]
	if _previous_frame.is_empty(): _previous_frame = _live_frame()
	var result := _perform_action(actor,kind,payload)
	if not result.ok: return result
	var frame := _live_frame()
	var patch := _difference(_previous_frame,frame)
	_previous_frame = frame
	return _ok({"kind":kind,"actor":actor_id,"patch":patch})

func _perform_action(actor: Node, kind: String, payload: Dictionary) -> Dictionary:
	match kind:
		"dig":
			if not payload.get("pressed") is bool: return _error("ACTION_INVALID")
			actor.call("_active_tool_primary",payload.pressed)
		"needle_collect":
			var hand: Node = actor.get("hand")
			if payload.get("operation","")=="deposit":
				var cabinet: Variant = hand.call("deposit_target")
				if not cabinet is Node3D: cabinet = actor.call("_cabinet_under")
				if not cabinet is Node3D: cabinet = actor.get("build").call("dismantle_target")
				if not cabinet is Node3D or cabinet not in nodes.builds.get("cabinets") or actor.global_position.distance_to(cabinet.global_position)>3.0: return _error("OUT_OF_REACH")
				if not bool(hand.call("deposit_into",cabinet)): return _error("ACTION_REFUSED")
			else: hand.call("primary")
		"place":
			var id: Variant = payload.get("id")
			var catalog: Node = nodes.world.get("catalog_panel")
			if not id is String or catalog == null or not catalog.get("_tiles") is Dictionary or not catalog.get("_tiles").has(id): return _error("ACTION_INVALID")
			if actor.get("build_id")!=id or actor.get("current_tool")!=8: actor.call("equip_build",id)
			if actor.get("build_id") != id: return _error("BUILD_LOCKED")
			actor.get("build").call("_frame",0.016)
			var status: Dictionary = actor.get("build").call("status")
			if status.get("ok") != true: return _error("PLACEMENT_REFUSED")
			actor.get("build").call("primary")
		"demolish":
			var tool: Node = actor.get("build")
			var target: Variant = tool.call("dismantle_target")
			if not target is Node3D or actor.global_position.distance_to(target.global_position) > 8.0: return _error("OUT_OF_REACH")
			tool.call("dismantle",target,false)
		"purchase":
			var shop: Node = nodes.world.get("shop")
			var id: Variant = payload.get("id")
			if shop == null or not id is String or id not in shop.call("display_ids"): return _error("ACTION_INVALID")
			if not bool(shop.call("is_near",actor.global_position)): return _error("OUT_OF_REACH")
			var price := float(shop.call("live_price",id))
			if not bool(nodes.state.call("can_afford",price)): return _error("INSUFFICIENT_FUNDS")
			var menu: Node = nodes.world.get("shop_menu")
			var previous_player: Node = menu.get("player")
			var previous_open := bool(menu.get("_open"))
			var money_before := float(nodes.state.get("money"))
			menu.set("player",actor)
			menu.set("_open",true)
			menu.call("_on_buy",id)
			menu.set("player",previous_player)
			menu.set("_open",previous_open)
			if float(nodes.state.get("money")) >= money_before: return _error("PURCHASE_REFUSED")
		"upgrade":
			var id: Variant = payload.get("id")
			var panel: Node = nodes.world.get("tech_panel")
			if not id is String or panel == null or not panel.get("_cards") is Dictionary or not panel.get("_cards").has(id): return _error("ACTION_INVALID")
			if not bool(nodes.tech.call("buy",id)): return _error("PURCHASE_REFUSED")
		"item_interact":
			match payload.get("operation"):
				"secondary":
					var event := InputEventAction.new()
					event.action = "secondary"
					event.pressed = true
					actor.call("_unhandled_input",event)
				"pick":
					if not try_shared_tool_pickup(actor): actor.get("carry").call("try_pick",false)
				"drop":
					actor.call("drop_active_tool")
					actor.get("hand").call("drop_held")
					actor.get("carry").call("drop_all")
				"throw": actor.call("throw_active_tool")
				_: return _error("ACTION_INVALID")
		"machine_config":
			if not payload.get("switched_off") is bool: return _error("ACTION_INVALID")
			var machine: Variant = actor.call("_console_under")
			if not machine is Node3D: machine = actor.call("_scanner_under")
			if not machine is Node3D: machine = actor.get("build").call("dismantle_target")
			if not machine is Node3D or actor.global_position.distance_to(machine.global_position) > 8.0: return _error("OUT_OF_REACH")
			var available := false
			for property in machine.get_script().get_script_property_list():
				if property.name == "switched_off" and property.type == TYPE_BOOL: available = true
			if not available: return _error("ACTION_UNSUPPORTED")
			machine.set("switched_off",payload.switched_off)
	return _ok()

func _live_frame() -> Dictionary:
	for role in ["world","field","state","tech","builds","props"]:
		if not nodes.has(role) or not is_instance_valid(nodes[role]):
			last_sync_error = "WORLD_NOT_READY"
			return {}
	last_sync_error = ""
	if _build_capture==null: _build_capture = load(MODULE_DIR+"/live_build_capture.gd").new()
	var buildings: Dictionary = _build_capture.capture(nodes.builds)
	if not buildings.ok:
		last_sync_error = buildings.code
		return {}
	var frame := {"state":nodes.state.call("to_dict").duplicate(true),"tech":nodes.tech.call("to_dict").duplicate(true),"heights":nodes.field.get("heights").duplicate(),"buildings":buildings.value,"props":nodes.props.call("to_array").duplicate(true),"belts":_read_belts()}
	if guest_mode:
		frame.held_props = _prop_module().held.duplicate(true)
		if _prop_module().initialized:
			var view: Array = _prop_module().authoritative_view(nodes.props)
			if view.size()!=frame.props.size():
				last_sync_error = "WORLD_NOT_READY"
				return {}
			frame.props = view
	else:
		var players := actors.duplicate()
		if nodes.has("player"): players[1] = nodes.player
		frame.held_props = _prop_module().capture_held(nodes.props,players)
	var settings := read_shared_settings()
	if not settings.ok:
		last_sync_error = settings.code
		return {}
	frame.settings = settings.value
	if guest_mode:
		if not _guest_countdown.is_empty(): frame.countdown = _guest_countdown.duplicate()
	else:
		var countdown: Variant = _countdown_node()
		if countdown is Node and countdown.has_method("remaining"):
			frame.countdown = {"seconds":clampi(int(countdown.call("remaining")),0,86400)}
	var missions: Node = nodes.world.get("missions")
	if guest_mode:
		if not _guest_quest.is_empty(): frame.quest = _guest_quest.duplicate(true)
	elif missions!=null and missions.has_method("progress_of"):
		var id: String = frame.state.get("mission_id","")
		frame.quest = {"index":int(frame.state.get("mission_index",0)),"progress":missions.call("progress_of",id) if not id.is_empty() else {}}
	if nodes.has("live"):
		if guest_mode:
			frame.loose = _loose_module().current.duplicate(true)
		else:
			var captured: Dictionary = _loose_module().capture_sources(nodes.live.get("_active"),nodes.live.get("needles"))
			if not captured.ok:
				last_sync_error = captured.code
				return {}
			frame.loose = captured.value
		if guest_mode:
			frame.held_loose = _loose_module().held.duplicate(true)
			frame.tool_loads = _tool_loads().current.duplicate(true)
		else:
			var players := actors.duplicate()
			if nodes.has("player"): players[1] = nodes.player
			frame.held_loose = _loose_module().capture_holds(players)
			frame.tool_loads = _tool_loads().capture(players)
	return frame

func _loose_module() -> RefCounted:
	if _loose == null: _loose = load(MODULE_DIR+"/loose_sync.gd").new()
	if nodes.has("live") and is_instance_valid(nodes.live): _loose.use_native_visuals(nodes.live)
	return _loose

func _difference(before: Dictionary, after: Dictionary) -> Dictionary:
	var patch := {}
	for key in after:
		if before.get(key) == after[key]: continue
		if key=="state" and before.get(key) is Dictionary and before[key].size()==after[key].size():
			var changes := {}
			for field in after[key]:
				if before[key].get(field)!=after[key][field]: changes[field] = after[key][field]
			patch.state_delta = changes
			continue
		if key=="loose" and before.get(key) is Dictionary:
			patch.loose_delta = _loose_module().difference(before[key],after[key])
			continue
		if key != "heights" or not before.get(key) is PackedFloat32Array or before[key].size() != after[key].size():
			patch[key] = after[key]
			continue
		var indices := PackedInt32Array()
		var values := PackedFloat32Array()
		for index in range(after[key].size()):
			if before[key][index] != after[key][index]:
				indices.append(index)
				values.append(after[key][index])
		patch.field = {"indices":indices,"values":values}
	return patch

func poll_host_events() -> Array[Dictionary]:
	if guest_mode: return []
	var frame := _live_frame()
	if frame.is_empty(): return []
	if _previous_frame.is_empty():
		_previous_frame = frame
		return []
	var patch := _difference(_previous_frame,frame)
	_previous_frame = frame
	return [] if patch.is_empty() else [{"kind":"native","patch":patch}]

func set_guest_mode(enabled: bool) -> Dictionary:
	if not nodes.has("saves"): return _error("CAPABILITY_MISSING")
	var has_world: bool = nodes.has("world") and is_instance_valid(nodes.world)
	if enabled:
		if not guest_mode:
			_guest_save_block = nodes.saves.get("block_save")==true
			if has_world:
				_world_mode = nodes.world.process_mode
				_guest_world_block = nodes.world.get("block_save")==true
		nodes.saves.set("block_save",true)
		guest_mode = true
		if has_world:
			nodes.world.set("block_save",true)
			nodes.world.process_mode = Node.PROCESS_MODE_DISABLED
			_hide_native_loose(true)
		if has_world and nodes.world.is_inside_tree():
			if _collision_tree==null:
				_collision_tree = nodes.world.get_tree()
				_collision_tree.node_added.connect(_guard_collision_node)
				_collision_tree.node_removed.connect(_forget_guest_collider)
			_guard_collision_branch(nodes.world)
		var prepared := _prepare_guest_field()
		if prepared.ok: load(MODULE_DIR+"/guest_field.gd").set_initial_guest_mode(true)
		return prepared
	# Restoring persistence requires the lifecycle's explicit origin restoration.
	if not _save_origin.is_empty(): return _error("GUEST_SESSION_ACTIVE")
	load(MODULE_DIR+"/guest_field.gd").set_initial_guest_mode(false)
	restore_shared_settings()
	if _guest_field!=null:
		_guest_field.restore()
		_guest_field = null
	_restore_guest_collisions()
	if has_world:
		nodes.world.process_mode = _world_mode
		nodes.world.set("block_save",_guest_world_block)
		_hide_native_loose(false)
	nodes.saves.set("block_save",_guest_save_block)
	if _loose != null: _loose.close()
	_guest_quest.clear()
	_guest_countdown.clear()
	_guest_belts.clear()
	_guest_belts_ready = false
	_guest_belts_world = 0
	_belts_pending = false
	_belts_epoch += 1
	_belt_paths.clear()
	_belt_paths_world = 0
	_tool_loads().current.clear()
	_countdown_world_id = 0
	_props_replica = null
	_local_peer = 0
	_quest_world_id = 0
	_quest_index = -1
	guest_mode = false
	return _ok()

func _prepare_guest_field() -> Dictionary:
	if not nodes.has("field"): return _ok()
	if _guest_field==null:
		# A render-only boundary needs no simulation guard. A native field must
		# carry the startup hook even if a cached original changed resource path.
		if not nodes.field.has_method("_settle"): return _ok()
		if not nodes.field.has_method("ftn_set_guest_field"): return _error("CAPABILITY_MISSING")
		_guest_field = load(MODULE_DIR+"/guest_field.gd").new()
	return _guest_field.configure(nodes.field)

func _guard_collision_branch(node: Node) -> void:
	_guard_collision_node(node)
	for child in node.get_children(): _guard_collision_branch(child)

func _guard_collision_node(node: Node) -> void:
	if not guest_mode or not nodes.has("world") or not is_instance_valid(nodes.world): return
	if not (node is StaticBody3D or node==nodes.get("player")): return
	if not nodes.world.is_ancestor_of(node): return
	var body: CollisionObject3D = node
	var key := body.get_instance_id()
	if not _guest_colliders.has(key): _guest_colliders[key] = {"body":weakref(body),"mode":body.disable_mode}
	body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE

func _forget_guest_collider(node: Node) -> void:
	var key := node.get_instance_id()
	if not _guest_colliders.has(key): return
	node.set("disable_mode",_guest_colliders[key].mode)
	_guest_colliders.erase(key)

func _restore_guest_collisions() -> void:
	if is_instance_valid(_collision_tree):
		if _collision_tree.node_added.is_connected(_guard_collision_node): _collision_tree.node_added.disconnect(_guard_collision_node)
		if _collision_tree.node_removed.is_connected(_forget_guest_collider): _collision_tree.node_removed.disconnect(_forget_guest_collider)
	_collision_tree = null
	for record in _guest_colliders.values():
		var body: Variant = record.body.get_ref()
		if is_instance_valid(body): body.set("disable_mode",record.mode)
	_guest_colliders.clear()

func restore_guest_world(state: Dictionary, session_id: String) -> Dictionary:
	var protocol: RefCounted = load(MODULE_DIR+"/protocol.gd").new()
	if not protocol.valid_id(session_id) or not _snapshot_valid(state): return _error("SNAPSHOT_INVALID")
	if _closing_guest: return _error("GUEST_SESSION_BUSY")
	if not nodes.has("saves"): return _error("CAPABILITY_MISSING")
	var saves: Node = nodes.saves
	var tree: SceneTree = saves.get_tree()
	_restore_epoch += 1
	var epoch := _restore_epoch
	if _save_origin.is_empty():
		if saves.has_method("finish_write"): saves.call("finish_write")
		_save_origin = {"directory":saves.call("save_dir"),"slot":saves.get("current_slot"),"block":saves.get("block_save")}
	var guarded := set_guest_mode(true)
	if not guarded.ok: return guarded
	var directory := "user://ftn_coop/sessions/" + session_id
	if not _guest_directory.is_empty() and _guest_directory!=directory: return _error("GUEST_SESSION_BUSY")
	_guest_directory = directory
	saves.call("use_scratch_dir",directory)
	var path: String = saves.call("slot_path",1)
	if not path.begins_with(directory+"/"): return _error("GUEST_ISOLATION_FAILED")
	if saves.call("write_file",path,state) != true: return _error("SAVE_FAILED")
	saves.call("begin_load",1)
	tree.paused = false
	var scene_path := _main_scene_path()
	if tree.change_scene_to_file(scene_path) != OK: return _error("NATIVE_RELOAD_FAILED")
	var deadline := Time.get_ticks_msec()+120000
	while Time.get_ticks_msec() < deadline:
		await tree.process_frame
		if epoch!=_restore_epoch: return _error("GUEST_LOAD_CANCELED")
		var current: Node = tree.current_scene
		if current != null and current.scene_file_path == scene_path and bool(current.get("_built")):
			bind(tree.root)
			return set_guest_mode(true)
	return _error("NATIVE_RELOAD_TIMEOUT")

func cancel_guest_restore() -> void:
	_restore_epoch += 1

func _main_scene_path() -> String: return "res://scenes/main.tscn"
func _menu_scene_path() -> String: return "res://scenes/main_menu.tscn"

func close_guest_world() -> Dictionary:
	cancel_guest_restore()
	if _closing_guest: return _error("GUEST_SESSION_BUSY")
	if _save_origin.is_empty():
		restore_shared_settings()
		if guest_mode: set_guest_mode(false)
		return _clear_guest_directory()
	_closing_guest = true
	var saves: Node = nodes.saves
	var tree: SceneTree = saves.get_tree()
	saves.set("block_save",true)
	# Keep native construction intact while its data remains isolated. Its
	# canceled completion cannot make the network session playable again.
	var deadline := Time.get_ticks_msec()+120000
	while Time.get_ticks_msec()<deadline:
		await tree.process_frame
		var current: Node = tree.current_scene
		if current==null: continue
		if current.scene_file_path!=_main_scene_path() or current.get("_built")==true: break
	if tree.current_scene==null or (tree.current_scene.scene_file_path==_main_scene_path() and tree.current_scene.get("_built")!=true):
		_closing_guest = false
		return _error("GUEST_CLOSE_FAILED")
	if tree.current_scene.scene_file_path==_main_scene_path(): tree.current_scene.set("block_save",true)
	var departure := PackedScene.new()
	var empty := Node.new()
	empty.name = "FtnCoopDeparture"
	departure.pack(empty)
	empty.free()
	if tree.change_scene_to_packed(departure)!=OK:
		_closing_guest = false
		return _error("GUEST_CLOSE_FAILED")
	await tree.scene_changed
	# The old world is gone before the original files become writable. The
	# native menu must then be built against the original directory.
	if saves.has_method("finish_write"): saves.call("finish_write")
	saves.call("_clear_pending")
	saves.call("use_scratch_dir",_save_origin.directory)
	saves.set("current_slot",_save_origin.slot)
	var original_block: bool = _save_origin.block
	_save_origin.clear()
	set_guest_mode(false)
	saves.set("block_save",original_block)
	tree.paused = false
	if tree.change_scene_to_file(_menu_scene_path())!=OK:
		_closing_guest = false
		return _error("GUEST_CLOSE_FAILED")
	await tree.scene_changed
	bind(tree.root)
	_previous_frame.clear()
	_closing_guest = false
	return _clear_guest_directory()

func _clear_guest_directory() -> Dictionary:
	if _guest_directory.is_empty(): return _ok()
	var root := "user://ftn_coop/sessions/"
	var id := _guest_directory.trim_prefix(root)
	var protocol: RefCounted = load(MODULE_DIR+"/protocol.gd").new()
	if _guest_directory!=root+id or not protocol.valid_id(id): return _error("GUEST_CLEANUP_FAILED")
	# This native storage is flat. Never traverse unexpected directories or links.
	for pair in [["user://","ftn_coop"],["user://ftn_coop","sessions"],[root,id]]:
		var parent := DirAccess.open(pair[0])
		if parent!=null and parent.is_link(pair[1]): return _error("GUEST_CLEANUP_FAILED")
	var absolute := ProjectSettings.globalize_path(_guest_directory).simplify_path()
	if absolute.get_base_dir()!=ProjectSettings.globalize_path(root).simplify_path().trim_suffix("/"): return _error("GUEST_CLEANUP_FAILED")
	if DirAccess.dir_exists_absolute(absolute):
		var directory := DirAccess.open(absolute)
		if directory==null: return _error("GUEST_CLEANUP_FAILED")
		directory.include_hidden = true
		if not directory.get_directories().is_empty(): return _error("GUEST_CLEANUP_FAILED")
		var files := directory.get_files()
		if files.size()>128: return _error("GUEST_CLEANUP_FAILED")
		for file in files:
			if directory.is_link(file): return _error("GUEST_CLEANUP_FAILED")
		for file in files:
			if DirAccess.remove_absolute(absolute.path_join(file))!=OK: return _error("GUEST_CLEANUP_FAILED")
		directory = null
		if DirAccess.remove_absolute(absolute)!=OK: return _error("GUEST_CLEANUP_FAILED")
	_guest_directory = ""
	return _ok()

func _snapshot_valid(state: Dictionary) -> bool:
	for key in ["version","state","heights","player","buildings","props","belts","tech","cell","extent"]:
		if not state.has(key): return false
	if not state.heights is PackedFloat32Array or state.heights.is_empty() or state.heights.size() > 2097152: return false
	if not state.state is Dictionary or not state.tech is Dictionary or not state.belts is Dictionary or not state.player is Transform3D: return false
	if not state.buildings is Array or state.buildings.size() > 32768 or not state.props is Array or state.props.size() > 65536: return false
	if typeof(state.version) != TYPE_INT or state.version < 1 or state.version > 100: return false
	for key in ["cell","extent"]:
		if typeof(state[key]) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(state[key])): return false
	if state.cell < 0.025 or state.cell > 8.0 or state.extent < 0.5 or state.extent > 512.0: return false
	var diameter := ceili(2.0*float(state.extent)/float(state.cell))+1
	if diameter*diameter > 2097152 or state.heights.size()!=diameter*diameter: return false
	for height in state.heights:
		if not is_finite(height) or absf(height)>8192.0: return false
	return _safe_native_data(state,0)

func apply_confirmed_event(event: Dictionary) -> Dictionary:
	if not guest_mode: return _error("HOST_ONLY")
	if not event.get("patch") is Dictionary or not _patch_valid(event.patch): return _error("SNAPSHOT_INVALID")
	var patch: Dictionary = event.patch
	# Validate the whole update first; the guest world cannot simulate meanwhile.
	if patch.has("settings"):
		var settings := apply_shared_settings(patch.settings)
		if not settings.ok: return settings
	if patch.has("state"):
		_apply_guest_state(patch.state)
	elif patch.has("state_delta"):
		var state: Dictionary = nodes.state.call("to_dict").duplicate(true)
		state.merge(patch.state_delta,true)
		_apply_guest_state(state)
	if patch.has("quest"):
		_guest_quest = patch.quest.duplicate(true)
		_refresh_guest_quests(nodes.state.call("to_dict"))
	if patch.has("countdown"): _apply_countdown(patch.countdown)
	if patch.has("tech"): nodes.tech.call("from_dict",patch.tech,false)
	var moved := PackedInt32Array()
	if patch.has("heights"):
		var previous: PackedFloat32Array = nodes.field.get("heights")
		for index in range(patch.heights.size()):
			if previous[index]!=patch.heights[index]: moved.append(index)
		nodes.field.set("heights",patch.heights.duplicate())
	elif patch.has("field"):
		var heights: PackedFloat32Array = nodes.field.get("heights")
		for index in range(patch.field.indices.size()): heights[patch.field.indices[index]] = patch.field.values[index]
		nodes.field.set("heights",heights)
		moved = patch.field.indices
	if not moved.is_empty():
		nodes.field.call("_dirty_moved",moved)
		nodes.field.call("_flush_dirty")
	if patch.has("buildings"):
		_clear_belt_records()
		_belt_paths.clear()
		_belt_paths_world = 0
		nodes.builds.call("clear")
		var slice := int(nodes.builds.get("restore_slice_usec"))
		nodes.builds.set("restore_slice_usec",0)
		nodes.builds.call("from_array",patch.buildings)
		nodes.builds.set("restore_slice_usec",slice)
	if patch.has("props"):
		_prop_module().apply_records(nodes.props,patch.props)
	if patch.has("held_props"): _prop_module().held = patch.held_props.duplicate(true)
	if patch.has("belts"):
		_guest_belts = patch.belts.duplicate(true)
		_guest_belts_ready = true
		_guest_belts_world = nodes.world.get_instance_id()
	if _guest_belts_ready and (patch.has("belts") or patch.has("buildings")): _queue_belt_render()
	if patch.has("loose"):
		_hide_native_loose(true)
		var loose_result: Dictionary = _loose_module().apply(patch.loose,nodes.world.get_tree().root)
		if not loose_result.ok: return loose_result
	elif patch.has("loose_delta"):
		_hide_native_loose(true)
		var loose_result: Dictionary = _loose_module().apply_delta(patch.loose_delta,nodes.world.get_tree().root)
		if not loose_result.ok: return loose_result
	if patch.has("held_loose"): _loose_module().accept_holds(patch.held_loose)
	if patch.has("tool_loads"): _tool_loads().accept(patch.tool_loads)
	return _ok()

func _countdown_node() -> Variant:
	if not nodes.has("world") or not is_instance_valid(nodes.world): return null
	var door: Variant = nodes.world.get("bay_door")
	return door.get("countdown") if door is Node and is_instance_valid(door) else null

func _apply_countdown(value: Dictionary) -> void:
	var countdown: Variant = _countdown_node()
	if not countdown is Node or not countdown.get("_lit") is MeshInstance3D: return
	if _guest_countdown==value and _countdown_world_id==countdown.get_instance_id(): return
	# Draw with the game's own digits. Its refresh/tick also reads and advances
	# the personal Profile countdown, which must remain independent on guests.
	var text: String = countdown.call("format_clock",value.seconds)
	countdown.get("_lit").mesh = countdown.call("_mesh",countdown.call("_on_for",text))
	countdown.set("_shown",value.seconds)
	_guest_countdown = value.duplicate()
	_countdown_world_id = countdown.get_instance_id()

func _apply_guest_state(authoritative: Dictionary) -> void:
	var state: Node = nodes.state
	var before: Dictionary = state.call("to_dict").duplicate(true)
	var blocked := state.is_blocking_signals()
	# The offline loader broadcasts a full collection/UI reset. Doing that on
	# every clock or money update stalls the frame and rebuilds unrelated UI.
	state.set_block_signals(true)
	state.call("from_dict",authoritative)
	for field in ["jetpack_fuel","money_peak"]:
		if authoritative.has(field): state.set(field,authoritative[field])
	state.set_block_signals(blocked)
	if not blocked:
		var updates := [
			["money_changed",["money"],[authoritative.get("money",0.0)]],
			["debt_changed",["debt"],[authoritative.get("debt",0.0)]],
			["hay_changed",["hay_total","hay_dug","hay_returned"],[authoritative.get("hay_total",0.0),authoritative.get("hay_dug",0.0)]],
			["hay_sold_changed",["hay_sold"],[authoritative.get("hay_sold",0.0)]],
			["best_combo_changed",["best_combo"],[authoritative.get("best_combo",0)]],
			["collection_loaded",["needle_positions","needle_taken","needle_type","discovered","needle_stock","needles_by_type","needle_out","needle_loose","needle_loose_at","needles_found"],[]],
			["hotbar_changed",["hotbar","recent_builds","fresh_builds","fresh_since"],[]],
			["tools_changed",["owned_tools"],[]],
			["gifts_changed",["gifts","gifts_given","gift_card_due","missions_paid"],[]],
			["contract_pin_changed",["contract_pinned"],[authoritative.get("contract_pinned",false)]],
			["contracts_changed",["contract_index","contract_delivered","contracts_done"],[]],
		]
		for update in updates:
			if not state.has_signal(update[0]): continue
			for key in update[1]:
				if before.get(key)!=authoritative.get(key):
					state.callv("emit_signal",[update[0]]+update[2])
					break
	_refresh_guest_quests(authoritative)

func _refresh_guest_quests(authoritative: Dictionary) -> void:
	if not nodes.has("world") or not authoritative.has("mission_index"): return
	var world: Node = nodes.world
	var panels := [world.get("quests"),world.get("mission_cue")]
	var index: int = authoritative.mission_index
	if world.get_instance_id()!=_quest_world_id or index!=_quest_index:
		_quest_world_id = world.get_instance_id()
		_quest_index = index
		for panel in panels:
			if panel is Node and panel.has_method("show_step"): panel.call("show_step",index)
	var director: Node = world.get("missions")
	var id: String = authoritative.get("mission_id","")
	if director==null or not director.has_method("progress_of") or id.is_empty(): return
	var progress: Dictionary = _guest_quest.progress if _guest_quest.get("index")==index else director.call("progress_of",id)
	for panel in panels:
		if panel is Node and panel.has_method("show_progress"): panel.call("show_progress",progress)

func _hide_native_loose(hidden: bool) -> void:
	if not nodes.has("live"): return
	if nodes.live is Node3D: nodes.live.visible = not hidden
	var mmi: Variant = nodes.live.get("_mmi")
	if mmi is Node3D: mmi.visible = not hidden
	for body in nodes.live.get("needles"):
		if is_instance_valid(body) and body is Node3D: body.visible = not hidden

func pump_guest_visuals() -> void:
	if not guest_mode or not nodes.has("field"): return
	if nodes.has("player"):
		if nodes.player.has_method("_sync_hands"): nodes.player.call("_sync_hands")
		var tool_index: Variant = nodes.player.get("current_tool")
		if tool_index in [1,2]:
			var tool: Variant = nodes.player.get("shovel" if tool_index==1 else "pitchfork")
			if tool is Node and tool.has_method("_update_visual_pose"): tool.call("_update_visual_pose")
		if nodes.has("world"):
			var hud: Variant = nodes.world.get("hud")
			var bar: Variant = hud.get("_hotkey_bar") if hud is Node else null
			if bar is Node and bar.has_method("_process"): bar.call("_process",0.0)
		var camera: Variant = nodes.player.get("camera")
		if nodes.has("props") and camera is Camera3D and _props_replica!=null:
			_props_replica.follow_local(nodes.props,_local_peer,camera.global_transform)
		if camera is Camera3D and camera.is_inside_tree():
			var eye: Vector3 = camera.global_position
			if nodes.field.has_method("tick_lod"): nodes.field.call("tick_lod",eye)
			if nodes.has("world"):
				var detail: Variant = nodes.world.get("detail")
				if detail is Node and detail.has_method("tick"): detail.call("tick",eye)
		if _loose!=null: _loose.follow_local(_local_peer,nodes.player)
	if _guest_field!=null: _guest_field.pump(nodes.field.get_process_delta_time())

func _patch_valid(patch: Dictionary) -> bool:
	# Cross-field checks below must never depend on wire dictionary order.
	if patch.has("state") and not patch.state is Dictionary: return false
	if patch.has("state_delta") and (not patch.state_delta is Dictionary or patch.has("state")): return false
	if patch.has("loose_delta") and (not patch.loose_delta is Dictionary or patch.has("loose")): return false
	if patch.has("props") and not patch.props is Array: return false
	# Quest text is display-only, so separators such as "3 / 5" are safe.
	# It never enters a native resource or save loader.
	var native := patch.duplicate()
	native.erase("quest")
	if not _safe_native_data(native,0): return false
	for key in patch:
		if key not in ["state","state_delta","tech","heights","field","buildings","props","held_props","belts","loose","loose_delta","held_loose","tool_loads","settings","quest","countdown"]: return false
		var role: String = {"state":"state","state_delta":"state","tech":"tech","heights":"field","field":"field","buildings":"builds","props":"props","held_props":"props","belts":"world","loose":"world","loose_delta":"world","held_loose":"world","tool_loads":"state","settings":"cfg","quest":"world","countdown":"world"}[key]
		if not nodes.has(role): return false
		if key=="countdown":
			if not patch[key] is Dictionary or patch[key].size()!=1 or typeof(patch[key].get("seconds"))!=TYPE_INT or patch[key].seconds<0 or patch[key].seconds>86400: return false
		if key=="quest":
			var quest: Variant = patch[key]
			if not quest is Dictionary or quest.size()!=2 or typeof(quest.get("index"))!=TYPE_INT or quest.index<0 or quest.index>100000 or not quest.get("progress") is Dictionary: return false
			var progress: Dictionary = quest.progress
			if not progress.is_empty():
				if progress.size()!=3 or not progress.get("text") is String or progress.text.length()>256: return false
				for name in ["have","need"]:
					if typeof(progress.get(name)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(progress[name])) or absf(float(progress[name]))>1.0e15: return false
			if patch.has("state") and quest.index!=patch.state.get("mission_index"): return false
			if patch.has("state_delta") and quest.index!=patch.state_delta.get("mission_index",nodes.state.call("to_dict").get("mission_index")): return false
		if key=="settings" and not _settings().validate(patch[key]).ok: return false
		if key in ["state","state_delta","tech"]:
			if not patch[key] is Dictionary: return false
			var template: Dictionary = nodes[role].call("to_dict")
			if key!="state_delta" and patch[key].size() != template.size(): return false
			for name in patch[key]:
				if not template.has(name) or typeof(patch[key][name]) != typeof(template[name]): return false
		if key in ["heights","field"]:
			var heights: PackedFloat32Array = nodes.field.get("heights")
			if key == "heights":
				if not patch[key] is PackedFloat32Array or patch[key].size() != heights.size(): return false
				for value in patch[key]:
					if not is_finite(value) or absf(value) > 8192.0: return false
			else:
				if not patch.field is Dictionary or not patch.field.get("indices") is PackedInt32Array or not patch.field.get("values") is PackedFloat32Array: return false
				if patch.field.indices.size() != patch.field.values.size() or patch.field.indices.size() > heights.size(): return false
				var previous := -1
				for index in range(patch.field.indices.size()):
					var vertex: int = patch.field.indices[index]
					if vertex <= previous or vertex >= heights.size() or not is_finite(patch.field.values[index]) or absf(patch.field.values[index]) > 8192.0: return false
					previous = vertex
		if key in ["buildings","props"]:
			if not patch[key] is Array or patch[key].size() > 32768: return false
			for record in patch[key]:
				if not record is Dictionary: return false
				if key=="props" and (not record.get("id") is String or not record.get("state") is Dictionary or not record.get("xform") is Transform3D): return false
		if key=="held_props":
			var records: Array = patch.props if patch.has("props") else nodes.props.call("to_array")
			if not _prop_module().validate_held(patch[key],records.size()): return false
		if key == "belts" and (not patch.belts is Dictionary or not nodes.has("saves")): return false
		if key == "loose" and (not patch.loose is Dictionary or not _loose_module().validate(patch.loose)): return false
		if key == "loose_delta" and not _loose_module().validate_delta(patch.loose_delta): return false
		if key == "tool_loads" and not _tool_loads().validate(patch.tool_loads): return false
		if key == "held_loose":
			var loose: Variant = patch.get("loose",_loose_module().current)
			if patch.has("loose_delta"):
				if not patch.loose_delta is Dictionary: return false
				if not _loose_module().validate_delta(patch.loose_delta): return false
				loose = {"ids":_loose_module().next_ids(patch.loose_delta)}
			if not loose is Dictionary or not loose.get("ids") is PackedInt32Array or not _loose_module().validate_holds(patch.held_loose,loose.ids): return false
	# Local calls and tests receive the same object-free data restrictions as wire data.
	var codec: RefCounted = load(MODULE_DIR+"/value_codec.gd").new()
	return codec.encode(patch,64*1024*1024).ok

func _safe_native_data(value: Variant, depth: int) -> bool:
	if depth > 32: return false
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			var text := String(value).to_lower()
			if text.contains("/") or text.contains("\\") or text.begins_with("..") or (text.length()>1 and text[1]==":"): return false
			for suffix in [".gd",".tscn",".tres",".res",".pck"]:
				if text.ends_with(suffix): return false
		TYPE_FLOAT: return is_finite(value)
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4: return value.is_finite()
		TYPE_TRANSFORM3D: return value.origin.is_finite() and value.basis.x.is_finite() and value.basis.y.is_finite() and value.basis.z.is_finite()
		TYPE_BASIS: return value.x.is_finite() and value.y.is_finite() and value.z.is_finite()
		TYPE_COLOR: return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
		TYPE_DICTIONARY:
			if value.size()>131072: return false
			for key in value:
				if not _safe_native_data(key,depth+1) or not _safe_native_data(value[key],depth+1): return false
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			if value.size()>2097152: return false
			for item in value:
				if not _safe_native_data(item,depth+1): return false
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY: pass
		_: return false
	return true

func _error(code: String) -> Dictionary:
	return {"ok":false,"code":code,"value":null}

func _ok(value: Variant = null) -> Dictionary:
	return {"ok":true,"code":"OK","value":value}
