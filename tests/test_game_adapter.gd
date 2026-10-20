extends RefCounted

func run(_tree: SceneTree) -> Array[String]:
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
		field.free()
		state.free()
		var normalizing: Node = replica.NormalizingState.new()
		fresh.nodes = {"state":normalizing}
		var host_state := {"money":25.0,"money_peak":0.0,"jetpack_fuel":10.0}
		if not fresh.apply_confirmed_event({"patch":{"state":host_state}}).ok or normalizing.to_dict()!=host_state:
			errors.append("A guest must preserve host fuel and peak money even when the native save loader normalizes them.")
		normalizing.free()
	live_state_checks(errors)
	var snapshot := {"version":1,"state":{},"heights":PackedFloat32Array([0.0,0.0,0.0,0.0]),"player":Transform3D.IDENTITY,"buildings":[],"props":[],"belts":{},"tech":{},"cell":2.0,"extent":1.0}
	if not fresh._snapshot_valid(snapshot): errors.append("A correctly sized native grid must remain valid.")
	unsafe_snapshot_grid_checks(fresh,snapshot,errors)
	var unsafe_snapshot := snapshot.duplicate(true)
	unsafe_snapshot.props = [{"id":"res://untrusted.gd"}]
	if fresh._snapshot_valid(unsafe_snapshot): errors.append("Network save data must never supply resource or file paths to native loaders.")
	unsafe_snapshot = snapshot.duplicate(true)
	unsafe_snapshot.cell = 0.0
	if fresh._snapshot_valid(unsafe_snapshot): errors.append("Invalid native world dimensions must fail before native world allocation.")
	return errors

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
	if not adapter.apply_confirmed_event({"patch":{"state":changed}}).ok or world.quests.title.text!="Fill bucket" or world.mission_cue.shown!=14 or world.quests.progress.text!="50% full":
		errors.append("A host quest advance must refresh both native guest quest displays and their progress.")
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
