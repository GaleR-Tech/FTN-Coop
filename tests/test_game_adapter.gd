extends RefCounted

const RenderFieldBase = preload("res://tests/fixtures/render_field.gd")

class VisualField extends Node:
	var eye := Vector3.INF
	func tick_lod(value: Vector3) -> void: eye = value

class HayDetail extends Node:
	var eye := Vector3.INF
	func tick(value: Vector3) -> void: eye = value

class VisualWorld extends Node:
	var detail := HayDetail.new()
	func _init() -> void: add_child(detail)

class VisualPlayer extends Node3D:
	var camera := Camera3D.new()
	func _init() -> void: add_child(camera)

class Countdown extends Node3D:
	var _shown := -1
	var seconds := 3600
	var _lit := MeshInstance3D.new()
	func _init() -> void: add_child(_lit)
	func remaining() -> int: return seconds
	func format_clock(value: int) -> String: return str(value)
	func _on_for(text: String) -> Array[String]: return [text]
	func _mesh(on: Array[String]) -> ArrayMesh:
		var mesh := ArrayMesh.new()
		mesh.resource_name = on[0]
		return mesh

class BayDoor extends Node:
	var countdown := Countdown.new()
	func _init() -> void: add_child(countdown)

class ClockWorld extends Node:
	var bay_door := BayDoor.new()
	func _init() -> void: add_child(bay_door)

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/game_bindings.gd") or not FileAccess.file_exists("res://mods/ftn_coop/game_adapter.gd"):
		return ["Game adapter and capability verification are not implemented yet."]
	var bindings: RefCounted = load("res://mods/ftn_coop/game_bindings.gd").new()
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	var errors: Array[String] = []
	if not adapter.has_method("_manifest_build"):
		errors.append("Demo build detection must verify the manifest belongs to the running installation.")
	else:
		var manifest := '"AppState" { "appid" "5165210" "installdir" "Find The Needle Demo" "buildid" "25963876" }'
		if adapter._manifest_build("M:/SteamLibrary/steamapps/common/Find The Needle Demo/FindTheNeedle.exe",manifest)!="25963876": errors.append("The measured demo installation must be recognized.")
		if adapter._manifest_build("M:/SteamLibrary/steamapps/common/Find The Needle/FindTheNeedle.exe",manifest)!="": errors.append("A nearby demo manifest must not authorize the main game.")
		if adapter._manifest_build("M:/SteamLibrary/steamapps/common/Find The Needle Demo/FindTheNeedle.exe",manifest.replace("5165210","5160800"))!="": errors.append("Another Steam app must not inherit demo compatibility.")
	if not bindings.has_method("verified_evidence"):
		return ["Measured demo-build compatibility is not registered yet."]
	if not bindings.verified_evidence("unknown-build").is_empty():
		errors.append("An untested build must not inherit verified bindings.")
	if not bindings.check_evidence(bindings.verified_evidence("25963876")).get("ok", false):
		errors.append("The successfully integration-tested demo build is not registered.")
	if not bindings.check_evidence(bindings.verified_evidence("26260645")).get("ok", false):
		errors.append("V71 must satisfy the verified game capability gate.")
	for unknown_build in ["26240210", "26243427", "26260646", ""]:
		if bindings.check_evidence(bindings.verified_evidence(unknown_build)).get("ok", false):
			errors.append("Only explicitly supported builds may satisfy the capability gate: "+unknown_build)
	var evidence := {
		"snapshot_capture": true, "snapshot_restore": true, "action_capture": true,
		"host_apply": true, "guest_mutation_guard": true, "machine_host_only": true,
		"player_pose": true, "isolated_guest_session": true, "host_save": true,
	}
	if not bindings.check_evidence(evidence).get("ok", false):
		errors.append("Complete measured evidence must satisfy the capability gate.")
	for capability in evidence:
		var missing: Dictionary = evidence.duplicate()
		missing.erase(capability)
		if bindings.check_evidence(missing).get("code") != "CAPABILITY_MISSING":
			errors.append("Missing capability was accepted: " + capability)
	if adapter.probe(null).get("code") != "ROOT_MISSING":
		errors.append("Missing runtime root must fail safely.")
	var empty := Node.new()
	if adapter.probe(empty).get("code") != "CAPABILITY_MISSING":
		errors.append("A generic Godot scene must not be mistaken for the demo.")
	empty.free()
	if not adapter.has_method("capture_world"):
		errors.append("World capture is not implemented yet.")
		return errors
	var fixture: Script = load("res://tests/fixtures/snapshot_boundary.gd")
	var world: Node = fixture.World.new()
	var saves: Node = fixture.Saves.new()
	saves.world = world
	adapter.nodes = {"world": world, "saves": saves}
	var captured: Dictionary = adapter.capture_world()
	if not captured.get("ok", false) or captured.get("value") != {"hay": 123.0, "loose_strands": 7.0, "version": 66}:
		errors.append("Capture must use the complete native payload after a synchronous host save.")
	world.save_ok = false
	if adapter.capture_world().get("code") != "SAVE_FAILED":
		errors.append("Failed native save must not return an old snapshot.")
	world.save_ok = true
	saves.block_save = true
	world.saved_synchronously = false
	if adapter.capture_world().get("code") != "HOST_ONLY" or world.saved_synchronously:
		errors.append("Guest mode must not invoke a host save.")
	world.free()
	saves.free()
	var fresh: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	for method in ["apply_host_action","apply_confirmed_event","poll_host_events","restore_guest_world","set_guest_mode"]:
		if not fresh.has_method(method): errors.append("Missing actual game boundary: " + method)
	if fresh.has_method("apply_host_action"):
		if fresh.apply_host_action(2,"EXECUTE",{}).code != "ACTION_INVALID": errors.append("Unknown game actions must fail before touching native nodes.")
		if fresh.apply_host_action(2,"dig",{"pressed":true}).code != "ACTOR_NOT_READY": errors.append("A guest must own a prepared host controller before it can act.")
	if fresh.has_method("apply_confirmed_event"):
		var replica: Script = load("res://tests/fixtures/replica_boundary.gd")
		var field: Node = replica.Field.new()
		var state: Node = replica.State.new()
		fresh.nodes = {"field":field,"state":state}
		fresh.guest_mode = true
		var patch := {"state":{"money":7.0},"field":{"indices":PackedInt32Array([1]),"values":PackedFloat32Array([0.25])}}
		if not fresh.apply_confirmed_event({"patch":patch}).ok or field.heights != PackedFloat32Array([1.0,0.25,1.0,1.0]) or state.data.money != 7.0:
			errors.append("Confirmed incremental state and field changes must apply without a scene reload.")
		patch = {"state":{"money":-999.0},"field":{"indices":PackedInt32Array([99]),"values":PackedFloat32Array([0.5])}}
		if fresh.apply_confirmed_event({"patch":patch}).code != "SNAPSHOT_INVALID" or state.data.money != 7.0:
			errors.append("Invalid field indices must reject the entire update before changing money.")
		field.dirtied = PackedInt32Array()
		fresh.apply_confirmed_event({"patch":{"heights":field.heights.duplicate()}})
		if not field.dirtied.is_empty(): errors.append("An unchanged baseline height grid must not requeue every native straw cell after loading.")
		var replacement: PackedFloat32Array = field.heights.duplicate()
		replacement[2] = 0.5
		fresh.apply_confirmed_event({"patch":{"heights":replacement}})
		if field.dirtied!=PackedInt32Array([2]): errors.append("A full baseline must dirty only height vertices that actually changed during native restoration.")
		field.free()
		state.free()
		var normalizing: Node = replica.NormalizingState.new()
		fresh.nodes = {"state":normalizing}
		var host_state := {"money":25.0,"money_peak":0.0,"jetpack_fuel":10.0}
		if not fresh.apply_confirmed_event({"patch":{"state":host_state}}).ok or normalizing.to_dict()!=host_state:
			errors.append("A guest must preserve host fuel and peak money even when the native save loader normalizes them.")
		normalizing.free()
	live_state_checks(errors)
	sparse_state_checks(errors)
	live_build_capture_checks(errors)
	await belt_replica_checks(tree,errors)
	await guest_visual_checks(tree,errors)
	guest_field_checks(errors)
	guest_clock_checks(errors)
	var schema: Script = load("res://tests/fixtures/replica_boundary.gd")
	var state_schema: Node = schema.State.new()
	var tech_schema: Node = schema.Tech.new()
	fresh.nodes={"state":state_schema,"tech":tech_schema}
	var snapshot := {"version":1,"state":state_schema.to_dict(),"heights":PackedFloat32Array([0.0,0.0,0.0,0.0]),"player":Transform3D.IDENTITY,"buildings":[],"props":[],"belts":{},"tech":tech_schema.to_dict(),"cell":2.0,"extent":1.0}
	if not fresh._snapshot_valid(snapshot): errors.append("A correctly sized native grid must remain valid.")
	unsafe_snapshot_grid_checks(fresh,snapshot,errors)
	var unsafe_snapshot := snapshot.duplicate(true)
	unsafe_snapshot.props = [{"id":"res://untrusted.gd"}]
	if fresh._snapshot_valid(unsafe_snapshot): errors.append("Network save data must never supply resource or file paths to native loaders.")
	unsafe_snapshot = snapshot.duplicate(true)
	unsafe_snapshot.cell = 0.0
	if fresh._snapshot_valid(unsafe_snapshot): errors.append("Invalid native world dimensions must fail before native world allocation.")
	for field in ["state","tech","props","buildings"]:
		unsafe_snapshot=snapshot.duplicate(true)
		unsafe_snapshot[field]={} if field in ["state","tech"] else [null]
		if fresh._snapshot_valid(unsafe_snapshot): errors.append("Malformed native snapshot records must be rejected before loading: "+field)
	state_schema.free();tech_schema.free()
	return errors

class BeltRun extends RefCounted:
	var rows: Array = []
	func clear() -> void: rows.clear()

class BeltPath extends Node:
	var run := BeltRun.new()
	func records_to_save() -> Array: return run.rows.duplicate(true)

class BeltCargo extends Node:
	var _carried: Array = []

class CargoBuilds extends Node:
	var hay_stairs: Array = []
	var hay_lifts: Array = []

class BeltView extends Node:
	var restores := 0
	var duplicated_props := 0
	var saves: Node
	var path := BeltPath.new()
	var builds := CargoBuilds.new()
	func _init() -> void:
		add_child(path)
		add_child(builds)
		for category in ["hay_stairs","hay_lifts"]:
			var machine := BeltCargo.new()
			builds.add_child(machine)
			builds.get(category).append(machine)
	func _belts_to_dict() -> Dictionary: return {"paths":[{"records":path.run.rows.duplicate(true)}]}
	func _restore_belts() -> void:
		restores += 1
		for entry in saves._pending_belts.get("paths",[]):
			if not path.run.rows.is_empty(): duplicated_props += entry.records.size()
			else: path.run.rows = entry.records.duplicate(true)
		for category in ["stairs","lifts"]:
			var machine: Node = builds.get("hay_"+category)[0]
			for entry in saves._pending_belts.get(category,[]):
				for record in entry.rows:
					var draw := Node3D.new()
					machine.add_child(draw)
					machine._carried.append({"rec":record.duplicate(true),"draw":draw})

class BeltSave extends Node:
	var _pending_belts: Dictionary = {}

class BeltProps extends Node:
	var items: Array = []

func belt_replica_checks(tree: SceneTree, errors: Array[String]) -> void:
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	if not adapter.has_method("_read_belts"):
		errors.append("Guest belt state must retain the host's exact records despite normalization by the native visual importer.")
		return
	var view := BeltView.new()
	var props := BeltProps.new();view.add_child(props)
	var saves := BeltSave.new()
	view.saves = saves
	tree.root.add_child(view)
	adapter.nodes = {"world":view,"saves":saves,"builds":view.builds,"props":props}
	adapter.guest_mode = true
	var first := {"paths":[{"records":[{"strands":97,"s":0.125}]}],"stairs":[{"rows":[{"strands":17,"s":0.25}]}],"lifts":[{"rows":[{"strands":22,"s":0.5}]}]}
	var latest := first.duplicate(true)
	latest.paths[0].records[0].s = 0.5
	if not adapter.apply_confirmed_event({"patch":{"belts":first}}).ok or not adapter.apply_confirmed_event({"patch":{"belts":latest}}).ok:
		errors.append("Valid host belt records must be accepted.")
	if adapter._read_belts()!=latest or view.restores!=0:
		errors.append("Belt state must commit immediately, with native rendering deferred until newly restored paths are ready.")
	await tree.process_frame
	if view.restores!=1 or saves._pending_belts!=latest:
		errors.append("Several belt updates in one frame must restore only the latest state once.")
	for wanted in [latest,first,{"paths":[]}]:
		adapter.apply_confirmed_event({"patch":{"belts":wanted}})
		await tree.process_frame
		var records: Array = wanted.paths[0].records if not wanted.paths.is_empty() else []
		if view.path.run.rows!=records or view.duplicated_props!=0:
			errors.append("Repeated, moving and empty guest belt updates must replace native cargo without spilling or duplicating props.")
		for category in ["stairs","lifts"]:
			var machine: Node = view.builds.get("hay_"+category)[0]
			var count: int = wanted.get(category,[]).size()
			if machine._carried.size()!=count or machine.get_child_count()!=count:
				errors.append("Guest lift and stair cargo must replace both rows and their old render nodes without leaking visual duplicates.")
	var replacement := BeltView.new()
	replacement.saves = saves
	replacement.path.run.rows = [{"strands":22}]
	tree.root.add_child(replacement)
	adapter.nodes.world = replacement
	if adapter._read_belts()!=replacement._belts_to_dict(): errors.append("A replaced guest world must never reuse cargo cached for the old world.")
	adapter._queue_belt_render()
	await tree.process_frame
	if replacement.restores!=0 or replacement.path.run.rows!=[{"strands":22}]: errors.append("An update to new buildings must not import cargo from a previous guest world.")
	adapter.nodes.world = view
	replacement.free()
	var completed := view.restores
	adapter.apply_confirmed_event({"patch":{"belts":first}})
	adapter.guest_mode = false
	await tree.process_frame
	if view.restores!=completed: errors.append("Leaving must cancel queued guest belt rendering.")
	view.free()
	saves.free()

func live_build_capture_checks(errors: Array[String]) -> void:
	if not ResourceLoader.exists("res://mods/ftn_coop/live_build_capture.gd"):
		errors.append("Live building snapshots must retain an arm's in-flight hay instead of using destructive save accounting.")
		return
	var module: Script = load("res://mods/ftn_coop/live_build_capture.gd")
	var native: Script = load("res://tests/fixtures/save_arm.gd")
	var driver: RefCounted = module.new()
	var arm: Node = native.new()
	var manager: Node = load("res://tests/fixtures/save_builds.gd").new()
	manager.robotic_arms.append(arm)
	var captured: Dictionary = driver.capture(manager)
	if not captured.ok or captured.value!=[{"type":"robotic_arm","position":Vector3.ZERO,"tier":1}] or arm.get("payload")!=97:
		errors.append("A live snapshot must retain the native building schema and the complete loaded arm payload.")
	arm.set("payload",54)
	if not driver.capture(manager).ok or arm.get("payload")!=54: errors.append("Repeated snapshots must capture fresh data without consuming a cached arm's load.")
	arm.call("to_dict")
	if arm.get("payload")!=0: errors.append("Native save accounting must still run outside live network capture.")
	manager.robotic_arms.clear()
	if not driver.capture(manager).ok or is_instance_valid(driver._root): errors.append("Removing the last arm must release the capture copies while the session continues.")
	var unsupported := Node.new()
	manager.robotic_arms = [unsupported]
	if driver.capture(manager).ok: errors.append("Unsupported arms must reject before native save accounting is called.")
	driver.close()
	unsupported.free()
	arm.free()
	manager.free()

func sparse_state_checks(errors: Array[String]) -> void:
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	var needles := PackedVector3Array()
	needles.resize(10000)
	var before := {"state":{"money":10.0,"needle_positions":needles,"run_secs":1.0}}
	var after: Dictionary = before.duplicate(true)
	after.state.money = 25.0
	var patch: Dictionary = adapter._difference(before,after)
	if patch!={"state_delta":{"money":25.0}}:
		errors.append("A money change must send only that state value, without retransmitting the unchanged needle collection.")
	var replica: Script = load("res://tests/fixtures/replica_boundary.gd")
	var state: Node = replica.LiveState.new()
	adapter.nodes = {"state":state}
	adapter.guest_mode = true
	if not adapter.apply_confirmed_event({"patch":{"state_delta":{"money":25.0}}}).ok or state.data.money!=25.0 or state.data.needle_stock!=[0]:
		errors.append("A sparse state update must change money while retaining every omitted authoritative value.")
	for invalid in [{"money":"25"},{"unknown":true},{"money":30.0,"needle_stock":["res://bad.gd"]}]:
		if adapter.apply_confirmed_event({"patch":{"state_delta":invalid}}).ok or state.data.money!=25.0:
			errors.append("Malformed sparse state must reject the whole event before changing money.")
	if adapter.apply_confirmed_event({"patch":{"state":state.data.duplicate(true),"state_delta":{"money":99.0}}}).ok:
		errors.append("An event cannot ambiguously contain both full and sparse game state.")
	state.free()

func guest_field_checks(errors: Array[String]) -> void:
	if not FileAccess.file_exists("res://mods/ftn_coop/guest_field.gd"):
		errors.append("Guest hay must run the complete native render frame while blocking settling and end-of-pile simulation.")
		return
	var driver: RefCounted = load("res://mods/ftn_coop/guest_field.gd").new()
	# Supply a native boundary with the same method signatures, independent of
	# the protected game's implementation and assets.
	var fixture: Script = RenderFieldBase
	var installed: Dictionary = driver.install(fixture)
	if not installed.ok:
		errors.append("The field subclass must be registered before native worker ownership begins.")
		return
	if load("res://tests/fixtures/render_field.gd")!=installed.value or installed.value.get_base_script()!=fixture:
		errors.append("Resource takeover must return the registered subclass while retaining the original native base.")
	if not driver.has_method("set_initial_guest_mode"):
		errors.append("A replacement guest field must be guarded from its first callback, before native loading can reshape the host's pile.")
	else:
		driver.set_initial_guest_mode(true)
		var loading_field: Node = installed.value.new()
		loading_field.call("_process",0.016)
		if loading_field.get("heights")!=PackedFloat32Array([1.0,2.0]): errors.append("Native guest loading must not reshape a saved pile before baseline application.")
		driver.set_initial_guest_mode(false)
		loading_field.free()
	var field: RenderFieldBase = installed.value.new()
	field.call("_process",0.016)
	if field.get("heights")[0]<=1.0: errors.append("Registering the field subclass must preserve ordinary host simulation by default.")
	field.set("heights",PackedFloat32Array([1.0,2.0]))
	field.set("rendered",0)
	var guard: Dictionary = driver.configure(field)
	if not guard.ok:
		errors.append("The native render guard must install without losing field data: "+guard.code)
	else:
		driver.configure(field)
		if field.get("joined")!=1: errors.append("Repeated guest configuration must not restart field ownership or settling joins.")
		driver.pump(0.016)
		if field.get("rendered")!=1 or field.get("heights")!=PackedFloat32Array([1.0,2.0]):
			errors.append("Guest rendering must advance without any native settling, worker result or last-of-pile mutation.")
		driver.restore()
		if field.get_script()!=installed.value or field.get("_ftn_guest_field")!=false: errors.append("Leaving guest mode must restore simulation without replacing a live field script instance.")
		var replacement: Node = installed.value.new()
		driver.configure(field)
		driver.configure(replacement)
		if field.get("_ftn_guest_field")!=false or replacement.get("_ftn_guest_field")!=true: errors.append("A resync must move the guest guard to the replacement field without replacing either script instance.")
		var unrelated := Node.new()
		if driver.configure(unrelated).ok or replacement.get("_ftn_guest_field")!=true: errors.append("A failed field configuration must leave the current valid guard intact.")
		unrelated.free()
		replacement.free()
		driver.pump(0.016)
		driver.restore()
	field.free()

func guest_visual_checks(tree: SceneTree, errors: Array[String]) -> void:
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	var world := VisualWorld.new()
	var field := VisualField.new()
	var player := VisualPlayer.new()
	world.add_child(field)
	world.add_child(player)
	tree.root.add_child(world)
	await tree.process_frame
	player.position = Vector3(-8,2,14)
	player.camera.position = Vector3(0,1.5,0)
	adapter.nodes = {"world":world,"field":field,"player":player}
	adapter.guest_mode = true
	adapter.pump_guest_visuals()
	if field.eye!=Vector3(-8,3.5,14) or world.detail.eye!=Vector3(-8,3.5,14):
		errors.append("Guest hay shells and nearby straw must follow the current local camera, including the first frame after joining.")
	player.position = Vector3(5,2,3)
	adapter.pump_guest_visuals()
	if field.eye!=Vector3(5,3.5,3) or world.detail.eye!=Vector3(5,3.5,3):
		errors.append("Moving the guest must refresh both native hay detail layers without advancing world simulation.")
	world.free()

func guest_clock_checks(errors: Array[String]) -> void:
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	var world := ClockWorld.new()
	var clock: Node = world.bay_door.countdown
	adapter.nodes = {"world":world}
	adapter.guest_mode = true
	var result: Dictionary = adapter.apply_confirmed_event({"patch":{"countdown":{"seconds":120}}})
	if not result.ok or clock._shown!=120 or clock._lit.mesh==null or clock._lit.mesh.resource_name!="120":
		errors.append("The guest gate must display the host countdown instead of its own profile's remaining time.")
	else:
		var mesh: Mesh = clock._lit.mesh
		adapter.apply_confirmed_event({"patch":{"countdown":{"seconds":120}}})
		if clock._lit.mesh!=mesh: errors.append("An unchanged countdown must reuse its digit mesh.")
	if clock.seconds!=3600: errors.append("Shared gate time must not rewrite the guest's personal profile countdown.")
	for invalid in [{"seconds":-1},{"seconds":86401},{"seconds":1.5},{"seconds":5,"extra":true}]:
		if adapter.apply_confirmed_event({"patch":{"countdown":invalid}}).ok:
			errors.append("Malformed shared countdowns must be rejected before native drawing.")
	world.free()

func live_state_checks(errors: Array[String]) -> void:
	var replica: Script = load("res://tests/fixtures/replica_boundary.gd")
	var state: Node = replica.LiveState.new()
	var world: Node = replica.QuestWorld.new()
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	adapter.nodes = {"state":state,"world":world}
	adapter.guest_mode = true
	var collection := VBoxContainer.new()
	var original := Label.new()
	collection.add_child(original)
	state.collection_loaded.connect(func():
		for child in collection.get_children(): child.free()
		collection.add_child(Label.new())
	)
	var wallet := Label.new()
	state.money_changed.connect(func(amount: float): wallet.text = str(amount))
	var changed: Dictionary = state.to_dict().duplicate(true)
	changed.money = 25.0
	if not adapter.apply_confirmed_event({"patch":{"state":changed}}).ok or wallet.text!="25.0":
		errors.append("A live money update must refresh the native wallet.")
	if not is_instance_valid(original) or collection.get_child(0)!=original:
		errors.append("A money-only update must preserve the collection UI instead of rebuilding it.")
	changed.mission_index = 14
	changed.mission_id = "fill_bucket"
	world.quests._hold = 0.75
	world.quests._farewell_left = 1.0
	if not adapter.apply_confirmed_event({"patch":{"state":changed}}).ok or world.quests.title.text!="Fill bucket" or world.mission_cue._shown!=14 or world.quests.progress.text!="50% full":
		errors.append("A host quest advance must refresh both native guest quest displays and their progress.")
	world.quests._shown = 1
	world.quests._hold = 0.75
	adapter.apply_confirmed_event({"patch":{"state":changed}})
	if world.quests._shown!=14 or world.quests._hold>0.0:
		errors.append("A frozen completion hold must not keep an obsolete guest quest after repeated host updates.")
	if not adapter.apply_confirmed_event({"patch":{"quest":{"index":14,"progress":{"have":3.0,"need":5.0,"text":"3 / 5"}}}}).ok or world.quests.progress.text!="3 / 5" or world.mission_cue.progress.text!="3 / 5":
		errors.append("Quest progress must come from the host, including a progress-only update.")
	var invalid := {"state":changed.duplicate(true),"quest":{"index":14,"progress":{"have":3.0,"need":5.0,"text":["bad"]}}}
	invalid.state.money = 99.0
	if adapter.apply_confirmed_event({"patch":invalid}).ok or state.data.money!=25.0:
		errors.append("Invalid quest data must reject the entire update before money changes.")
	adapter.nodes.props = state
	for malformed in [{"quest":{"index":14,"progress":{}},"state":1},{"state":1,"quest":{"index":14,"progress":{}}},{"held_props":[],"props":1},{"props":1,"held_props":[]}]:
		if adapter.apply_confirmed_event({"patch":malformed}).code!="SNAPSHOT_INVALID":
			errors.append("Malformed siblings must be rejected independently of field order.")
	adapter.nodes.erase("props")
	changed.needle_stock = [1]
	adapter.apply_confirmed_event({"patch":{"state":changed}})
	if is_instance_valid(original): errors.append("A changed collection must still refresh its native UI.")
	wallet.free()
	collection.free()
	world.free()
	state.free()

func unsafe_snapshot_grid_checks(adapter: RefCounted, snapshot: Dictionary, errors: Array[String]) -> void:
	for heights in [PackedFloat32Array([0]),PackedFloat32Array([0,0,0,9000])]:
		var invalid := snapshot.duplicate(true)
		invalid.heights = heights
		if adapter._snapshot_valid(invalid): errors.append("A malformed grid or out-of-bounds height must fail before native allocation.")
	var path := snapshot.duplicate(true)
	path.props = [{"id":"nested/../../another_mod"}]
	if adapter._snapshot_valid(path): errors.append("Internal path traversal must never reach a native loader.")
