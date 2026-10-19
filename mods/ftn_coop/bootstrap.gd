extends Node

const VERSION := "0.2.0"
const REQUIRED_CAPABILITIES := [
	"snapshot_capture", "snapshot_restore", "action_capture", "host_apply",
	"guest_mutation_guard", "machine_host_only", "player_pose", "isolated_guest_session", "host_save",
]

var _status: Label
var _last_scene := 0
var _probe_pending := false
var _scene_has_built_flag := false
var _last_built := false
var _integration_started := false
var _network_test := false
var _coop_runtime: Node
var _locale: RefCounted

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_locale = load(get_script().resource_path.get_base_dir()+"/locale.gd").new()
	_locale.load_preferences()
	print("[FTN-Coop] own bootstrap loaded; version=" + VERSION)
	_network_test = OS.get_cmdline_user_args().has("--ftn-coop-native-network-test")
	if _network_test:
		Engine.max_fps = 30
		var guard: RefCounted = load(get_script().resource_path.get_base_dir()+"/game_adapter.gd").new()
		guard.bind(get_tree().root)
		if guard.nodes.has("saves"):
			guard.nodes.saves.set("block_save",true)
			guard.nodes.saves.call("use_scratch_dir","user://ftn_coop/tests/startup-"+str(OS.get_process_id()))
	if DisplayServer.get_name() != "headless" and not _network_test:
		if OS.get_cmdline_user_args().has("--ftn-coop-integration-check"): _create_diagnostic_panel()
		else: _create_coop_runtime.call_deferred()
	_refresh_report.call_deferred()
	var session_request := "user://ftn_coop/session-check.request"
	if OS.get_cmdline_user_args().has("--ftn-coop-session-check") or FileAccess.file_exists(session_request):
		if FileAccess.file_exists(session_request):
			DirAccess.remove_absolute(session_request)
		_run_session_check.call_deferred()

func ready_for_coop(report: Dictionary) -> bool:
	if not report.get("ok", false):
		return false
	var value: Variant = report.get("value")
	if not value is Dictionary or value.get("bindings_verified") != true:
		return false
	var steam: Variant = value.get("steam")
	if not steam is Dictionary or steam.get("singleton") != true or steam.get("multiplayer_peer") != true:
		return false
	var capabilities: Variant = value.get("capabilities")
	if not capabilities is Dictionary:
		return false
	for capability in REQUIRED_CAPABILITIES:
		if capabilities.get(capability) != true:
			return false
	return true

func _process(_delta: float) -> void:
	if _network_test and Engine.max_fps!=30: Engine.max_fps = 30
	if OS.get_cmdline_user_args().has("--ftn-coop-autoquit") and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var scene := get_tree().current_scene
	var scene_id := scene.get_instance_id() if scene != null else 0
	if scene_id != _last_scene and not _probe_pending:
		_last_scene = scene_id
		_last_built = false
		_scene_has_built_flag = false
		if scene != null:
			for property in scene.get_property_list():
				if property.name == "_built":
					_scene_has_built_flag = true
					break
		_probe_pending = true
		_refresh_report.call_deferred()
	if _scene_has_built_flag and scene != null:
		var built := bool(scene.get("_built"))
		if built and not _last_built:
			_refresh_report.call_deferred()
			if not _integration_started and OS.get_cmdline_user_args().has("--ftn-coop-integration-check"):
				_integration_started = true
				_run_integration_check.call_deferred()
			elif not _integration_started and _network_test:
				_integration_started = true
				_run_native_network_check.call_deferred()
		_last_built = built

func _run_integration_check() -> void:
	var base_dir: String = get_script().resource_path.get_base_dir()
	var checker_script: Script = load(base_dir + "/integration_probe.gd")
	if checker_script == null or not checker_script.can_instantiate():
		if OS.get_cmdline_user_args().has("--ftn-coop-autoquit"): get_tree().quit(1)
		return
	var checker: RefCounted = checker_script.new()
	await checker.run(get_tree(), base_dir)
	if OS.get_cmdline_user_args().has("--ftn-coop-autoquit"):
		get_tree().quit()

func _run_native_network_check() -> void:
	var base: String = get_script().resource_path.get_base_dir()
	var script: Script = load(base+"/native_network_check.gd")
	if script==null or not script.can_instantiate():
		get_tree().quit(1)
		return
	var checker: Node = script.new()
	add_child(checker)
	var result: Dictionary = await checker.run(base,OS.get_cmdline_user_args())
	get_tree().quit(0 if result.ok else 1)

func _run_session_check() -> void:
	var base_dir: String = get_script().resource_path.get_base_dir()
	var adapter: RefCounted = load(base_dir + "/game_adapter.gd").new()
	var detected_build: String = adapter.game_build()
	var result := {"build": detected_build, "status": "RUNNING", "cleanup": false}
	if detected_build != "25963876":
		result.status = "BUILD_UNVERIFIED"
	else:
		var transport: Node = load(base_dir + "/steam_transport.gd").new()
		transport.build = detected_build
		add_child(transport)
		var session: Node = load(base_dir + "/session.gd").new()
		add_child(session)
		session.configure(transport, detected_build, VERSION)
		var started: Dictionary = session.host()
		var ready_deadline := Time.get_ticks_msec() + 3000
		while not started.ok and started.code == "STEAM_NOT_READY" and Time.get_ticks_msec() < ready_deadline:
			await get_tree().create_timer(0.2).timeout
			started = session.host()
		if not started.ok:
			result.status = started.code
		else:
			var deadline := Time.get_ticks_msec() + 16000
			while session.state == session.State.CREATING and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			if session.state == session.State.LOBBY and transport.local_peer_id() == 1:
				result.status = "HOST_LOBBY_READY"
			else:
				result.status = session.last_error if session.last_error != "" else "HOST_TIMEOUT"
		session.leave()
		result.cleanup = transport.lobby_id == 0 and transport.local_peer_id() == 0 and session.roster.is_empty()
		session.queue_free()
		transport.queue_free()
	var file := FileAccess.open("user://ftn_coop/session-check.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result))
		file.close()
	print("[FTN-Coop] Steam session check: " + str(result.status))

func _refresh_report() -> void:
	_probe_pending = false
	if _network_test: return
	var script_path: String = get_script().resource_path.get_base_dir() + "/runtime_probe.gd"
	var probe_script: Script = load(script_path)
	if probe_script == null or not probe_script.can_instantiate():
		push_error("[FTN-Coop] runtime probe unavailable")
		return
	var probe: RefCounted = probe_script.new()
	var report: Dictionary = probe.inspect(get_tree().root)
	var report_json := JSON.stringify(report)
	if report_json.to_utf8_buffer().size() > 1048576:
		push_error("[FTN-Coop] diagnosis exceeds 1 MiB limit")
		return
	var directory_error := DirAccess.make_dir_recursive_absolute("user://ftn_coop")
	if directory_error != OK:
		push_error("[FTN-Coop] diagnosis directory unavailable")
		return
	var report_file := FileAccess.open("user://ftn_coop/runtime-report.json", FileAccess.WRITE)
	if report_file == null:
		push_error("[FTN-Coop] cannot write runtime report")
		return
	report_file.store_string(report_json)
	report_file.close()
	print("[FTN-Coop] runtime report written; nodes=" + str(report.get("value", {}).get("nodes", []).size()))
	if is_instance_valid(_status):
		_status.text = _locale.text("FTN Koop · eigener Entwicklungsstand %s\nStartkomponente geladen.\nTechnische Anbindung wird geprüft.\nKoop ist noch nicht freigeschaltet.") % VERSION
	if is_instance_valid(_coop_runtime): _coop_runtime.refresh_world()

func _create_coop_runtime() -> void:
	var base: String = get_script().resource_path.get_base_dir()
	var adapter: RefCounted = load(base+"/game_adapter.gd").new()
	var transport: Node = load(base+"/steam_transport.gd").new()
	var build: String = adapter.game_build()
	transport.build = build
	transport.mod_version = VERSION
	_coop_runtime = load(base+"/coop_runtime.gd").new()
	add_child(_coop_runtime)
	_coop_runtime.configure(adapter,transport,build,VERSION)

func _create_diagnostic_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FtnCoopDiagnosis"
	layer.layer = 100
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(440, 130)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	_status = Label.new()
	_status.text = _locale.text("FTN Koop · Startkomponente geladen\nDiagnose läuft …")
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_constant_override("outline_size", 1)
	panel.add_child(_status)
