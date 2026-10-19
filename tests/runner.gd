extends SceneTree

const SUITES := {
	"mod_versions": "res://tests/test_mod_versions.gd",
	"localization": "res://tests/test_localization.gd",
	"script_load": "res://tests/test_script_load.gd",
	"runtime_probe": "res://tests/test_runtime_probe.gd",
	"game_adapter": "res://tests/test_game_adapter.gd",
	"input_bridge": "res://tests/test_input_bridge.gd",
	"session": "res://tests/test_session.gd",
	"protocol": "res://tests/test_protocol.gd",
	"snapshot_transfer": "res://tests/test_snapshot_transfer.gd",
	"world_sync": "res://tests/test_world_sync.gd",
	"loose_sync": "res://tests/test_loose_sync.gd",
	"network_controller": "res://tests/test_network_controller.gd",
	"network_recovery": "res://tests/test_network_recovery.gd",
	"actor_lifecycle": "res://tests/test_actor_lifecycle.gd",
	"local_transport": "res://tests/test_local_transport.gd",
	"native_diagnostics": "res://tests/test_native_diagnostics.gd",
	"presence_ui": "res://tests/test_presence_ui.gd",
	"guest_movement": "res://tests/test_guest_movement.gd",
	"guest_controls": "res://tests/test_guest_controls.gd",
	"save_session": "res://tests/test_save_session.gd",
	"save_adapter": "res://tests/test_save_adapter.gd",
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var requested := "all"
	var args := OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if args[index] == "--suite":
			requested = args[index + 1]
	if requested != "all" and not SUITES.has(requested):
		printerr("FAIL unknown suite: " + requested)
		quit(1)
		return
	var failures := 0
	for suite in SUITES:
		if requested != "all" and requested != suite:
			continue
		var test_script: Script = load(SUITES[suite])
		if test_script == null or not test_script.can_instantiate():
			printerr("FAIL cannot load suite: " + suite)
			failures += 1
			continue
		var test: RefCounted = test_script.new()
		var errors: Array = await test.run(self)
		for error in errors:
			printerr("FAIL " + suite + ": " + str(error))
		failures += errors.size()
		if errors.is_empty():
			print("PASS " + suite)
	print("RESULT failures=" + str(failures))
	quit(0 if failures == 0 else 1)
