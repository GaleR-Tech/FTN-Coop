extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var bootstrap_path := "res://mods/ftn_coop/bootstrap.gd"
	var probe_path := "res://mods/ftn_coop/runtime_probe.gd"
	if not FileAccess.file_exists(bootstrap_path) or not FileAccess.file_exists(probe_path):
		return ["Own bootstrap and runtime diagnosis are not implemented yet."]
	var bootstrap_script: Script = load(bootstrap_path)
	var probe_script: Script = load(probe_path)
	if bootstrap_script == null or probe_script == null or not bootstrap_script.can_instantiate() or not probe_script.can_instantiate():
		return ["Own components do not load."]
	var bootstrap: Node = bootstrap_script.new()
	if bootstrap.ready_for_coop({}):
		errors.append("An empty capability report must not enable co-op.")
	if bootstrap.ready_for_coop({"ok": true, "code": "OK", "value": {"engine": "4.7.2"}}):
		errors.append("Engine identity alone must not enable co-op.")
	var complete := {"ok": true, "code": "OK", "value": {
		"bindings_verified": true,
		"steam": {"singleton": true, "multiplayer_peer": true},
		"capabilities": {
			"snapshot_capture": true, "snapshot_restore": true, "action_capture": true,
			"host_apply": true, "guest_mutation_guard": true, "machine_host_only": true,
			"player_pose": true, "isolated_guest_session": true, "host_save": true,
		},
	}}
	if not bootstrap.ready_for_coop(complete):
		errors.append("Fully verified capabilities should allow the next co-op stage.")
	complete.value.capabilities.guest_mutation_guard = false
	if bootstrap.ready_for_coop(complete):
		errors.append("Missing guest mutation isolation must keep co-op disabled.")
	var fixture: Node = load("res://tests/fixtures/fake_game.gd").new()
	fixture.name = "FixtureGame"
	tree.root.add_child(fixture)
	var probe: RefCounted = probe_script.new()
	var report: Dictionary = probe.inspect(fixture)
	if not report.get("ok", false):
		errors.append("Valid runtime tree must produce a successful diagnosis.")
	var serialized := JSON.stringify(report)
	if serialized.contains("fixture-secret-value"):
		errors.append("Diagnosis leaked a property value.")
	if fixture.fixture_counter != 0:
		errors.append("Diagnosis invoked a game action.")
	if not serialized.contains("fixture_action"):
		errors.append("Diagnosis did not expose method capabilities.")
	var steam: Dictionary = report.get("value", {}).get("steam", {})
	if steam.get("singleton", true) or steam.get("multiplayer_peer", true):
		errors.append("Standalone engine must report absent Steam capabilities.")
	if probe.inspect(null).get("code") != "ROOT_MISSING":
		errors.append("Missing scene tree must give a defined failure.")
	var dense_script := GDScript.new()
	var source := "extends Node\n"
	for index in range(128):
		source += "func capability_%d(a: int, b: int, c: int, d: int) -> void:\n\tpass\n" % index
	dense_script.source_code = source
	if dense_script.reload() != OK:
		errors.append("Dense scene fixture could not load.")
	else:
		var dense_root := Node.new()
		for index in range(80):
			dense_root.add_child(dense_script.new())
		var dense_report: Dictionary = probe.inspect(dense_root)
		if JSON.stringify(dense_report, "\t").to_utf8_buffer().size() > 1048576:
			errors.append("Repeated scripted nodes must not overflow the diagnosis size limit.")
		dense_root.free()
	var crowded_root := Node.new()
	var pool := Node.new()
	var world := Node.new()
	crowded_root.add_child(pool)
	crowded_root.add_child(world)
	for index in range(400):
		pool.add_child(Node.new())
	world.add_child(load("res://tests/fixtures/fake_game.gd").new())
	if not JSON.stringify(probe.inspect(crowded_root)).contains("fixture_action"):
		errors.append("An unscripted pool must not hide the gameplay controller.")
	crowded_root.free()
	fixture.free()
	bootstrap.free()
	return errors
