extends RefCounted

const HOST := {"prop_cap":300,"prop_decay":false,"belt_cap":1000,"belt_decay":false,"auto_clean":true,"auto_clean_seconds":90.0,"grid_lock":true,"autosave":false,"autosave_seconds":300.0}

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/shared_settings.gd"):
		return ["Host-owned gameplay settings with temporary guest overrides are not implemented."]
	var errors: Array[String] = []
	var cfg: Node = load("res://tests/fixtures/game_config.gd").new()
	cfg.path = "user://ftn-settings-test-"+str(Time.get_ticks_usec())+".cfg"
	cfg.save_settings()
	var original_file := FileAccess.get_sha256(cfg.path)
	var module: RefCounted = load("res://mods/ftn_coop/shared_settings.gd").new()
	module.configure(cfg)
	var captured: Dictionary = module.capture()
	if not captured.ok or captured.value.size()!=9 or captured.value.get("prop_cap")!=150 or captured.value.has("quality"):
		errors.append("The host snapshot must include all nine gameplay settings and exclude personal preferences.")
	var original: Dictionary = captured.value.duplicate(true)
	var accepted: Dictionary = module.accept(HOST)
	if not accepted.ok or not cfg.settings_readonly or cfg.prop_cap!=300 or not cfg.grid_lock or cfg.quality!=2 or cfg.mouse_sensitivity!=0.7:
		errors.append("Accepting host settings must lock only gameplay values while preserving personal controls and graphics.")
	cfg.quality = 1
	cfg.mouse_sensitivity = 0.5
	cfg.save_settings()
	if FileAccess.get_sha256(cfg.path)!=original_file:
		errors.append("Temporary host settings must never be written into a guest's settings file.")
	var changed := HOST.duplicate(true)
	changed.prop_cap = 500
	if not module.accept(changed).ok or cfg.prop_cap!=500:
		errors.append("A running guest must accept subsequent host changes.")
	cfg.prop_cap = 42
	cfg.settings_readonly = false
	module.enforce()
	if cfg.prop_cap!=500 or not cfg.settings_readonly or cfg.quality!=1:
		errors.append("Local gameplay changes must be reset to the host values without resetting personal changes.")
	if module.update_host("prop_cap",250).code!="HOST_ONLY" or cfg.prop_cap!=500:
		errors.append("A guest must not use the host editing path.")
	module.release()
	var restored: Dictionary = module.capture()
	var file := ConfigFile.new()
	file.load(cfg.path)
	if restored.value!=original or cfg.settings_readonly or file.get_value("gameplay","prop_cap")!=150 or file.get_value("personal","quality")!=1 or file.get_value("personal","mouse_sensitivity")!=0.5:
		errors.append("Leaving must restore the original gameplay values and save the guest's personal changes.")
	module.release()
	if not module.update_host("prop_cap",250).ok or cfg.prop_cap!=250:
		errors.append("An unlocked host must be able to edit a supported gameplay setting through the native setter.")
	for bad in ["250",250.5,19,1501]:
		if module.update_host("prop_cap",bad).ok or cfg.prop_cap!=250:
			errors.append("Host edits must reject invalid values before changing native configuration.")
	for key in ["quality","locale","override_file","unknown"]:
		if module.update_host(key,1).ok:
			errors.append("The shared editing path must reject personal and unknown keys.")
	for entry in [["prop_cap",19],["prop_cap",1501],["prop_cap",25.5],["belt_cap",5001],["auto_clean",1],["auto_clean_seconds",NAN],["autosave_seconds",1801.0]]:
		var invalid := HOST.duplicate(true)
		invalid[entry[0]] = entry[1]
		if module.accept(invalid).ok or cfg.settings_readonly or cfg.prop_cap!=250:
			errors.append("Invalid shared settings must be rejected atomically: "+str(entry[0]))
	var unknown := HOST.duplicate(true)
	unknown.override_file = "res://unexpected"
	if module.accept(unknown).ok: errors.append("Unknown network setting keys must fail closed.")
	var missing := HOST.duplicate(true)
	missing.erase("grid_lock")
	if module.accept(missing).ok: errors.append("Incomplete shared settings must fail before changing a guest.")
	# Existing native read-only modes must survive the session unchanged.
	cfg.settings_readonly = true
	module.accept(HOST)
	module.release()
	if not cfg.settings_readonly: errors.append("Leaving must preserve a pre-existing native settings write guard.")
	DirAccess.remove_absolute(cfg.path)
	cfg.free()
	errors.append_array(_adapter_boundary())
	errors.append_array(await _settings_ui(tree))
	errors.append_array(await _settings_wire(tree))
	await tree.process_frame
	return errors

func _settings_wire(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var controllers: Array[Node] = []
	var wires: Array[Node] = []
	var configs: Array[Node] = []
	var games: Array = []
	for index in [0,1]:
		var cfg: Node = load("res://tests/fixtures/game_config.gd").new()
		cfg.prop_cap = 150 if index==0 else 77
		var game: RefCounted = load("res://tests/fixtures/settings_game_boundary.gd").new()
		game.tree = tree
		game.configure_settings(cfg)
		var wire: Node = load("res://tests/fixtures/pipe_transport.gd").new()
		wire.peer_id = index+1
		var controller: Node = load("res://mods/ftn_coop/network_controller.gd").new()
		tree.root.add_child(wire)
		tree.root.add_child(controller)
		controller.configure(wire,game,"25963876","0.3.0")
		configs.append(cfg)
		games.append(game)
		wires.append(wire)
		controllers.append(controller)
	wires[0].other = wires[1]
	wires[1].other = wires[0]
	controllers[0].host()
	await tree.process_frame
	controllers[1].join(42)
	for frame in range(40): await tree.process_frame
	if controllers[1].session.state!=controllers[1].session.State.PLAYING or games[1].settings_at_load.get("prop_cap")!=150:
		errors.append("Host gameplay settings must reach the native boundary before the guest world starts loading.")
	configs[1].prop_cap = 42
	for frame in range(3): await tree.process_frame
	if configs[1].prop_cap!=150:
		errors.append("The controller must enforce host gameplay values while the guest remains connected.")
	configs[0].set_prop_cap(330)
	controllers[0].world_sync._confirm({"kind":"native","patch":{"settings":games[0].settings.capture().value}})
	for frame in range(8): await tree.process_frame
	if configs[1].prop_cap!=330:
		errors.append("Confirmed settings changes must use the normal authenticated world-event route.")
	controllers[0].leave()
	await tree.process_frame
	if configs[1].prop_cap!=77 or configs[1].settings_readonly or controllers[1].session.state!=controllers[1].session.State.OFFLINE:
		errors.append("Host loss must restore the guest's own native configuration.")
	for controller in controllers: controller.leave()
	for node in controllers+wires: node.queue_free()
	for cfg in configs: cfg.free()
	await tree.process_frame
	return errors

func _settings_ui(tree: SceneTree) -> Array[String]:
	var ui: Node = load("res://mods/ftn_coop/coop_ui.gd").new()
	if not ui.has_method("set_shared_settings"):
		ui.free()
		return ["The F2 menu must show host-owned gameplay settings and lock guest controls."]
	var errors: Array[String] = []
	var session: Node = load("res://mods/ftn_coop/session.gd").new()
	tree.root.add_child(session)
	tree.root.add_child(ui)
	ui.bind_session(session)
	session.state = session.State.PLAYING
	session.is_host = true
	ui.set_shared_settings(HOST)
	var edits: Array = []
	ui.shared_setting_requested.connect(func(key: String, value: Variant): edits.append({"key":key,"value":value}))
	var cap: SpinBox = ui._settings_controls.prop_cap
	if not cap.editable or cap.value!=300:
		errors.append("A playing host must see editable current gameplay values.")
	cap.value = 350
	if edits!=[{"key":"prop_cap","value":350}] or typeof(edits[0].value)!=TYPE_INT:
		errors.append("The host's numeric edit must emit a typed allowlisted setting request.")
	session.is_host = false
	ui.set_language("en")
	ui.set_shared_settings(HOST)
	if cap.editable or not ui._settings_controls.auto_clean.disabled or not ui._settings_hint.text.contains("host"):
		errors.append("Guests must see host ownership and disabled shared controls.")
	ui.set_language("de")
	if not ui._settings_hint.text.contains("Host") or cap.value!=300:
		errors.append("Changing language must preserve shared values and translate their ownership notice.")
	session.state = session.State.OFFLINE
	ui._refresh()
	if ui._settings_toggle.visible or ui._settings_box.visible:
		errors.append("Leaving a session must hide its shared settings.")
	ui.queue_free()
	session.queue_free()
	await tree.process_frame
	return errors

func _adapter_boundary() -> Array[String]:
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	if not adapter.has_method("apply_shared_settings"):
		return ["The real game adapter must apply shared settings before loading and in confirmed patches."]
	var errors: Array[String] = []
	var cfg: Node = load("res://tests/fixtures/game_config.gd").new()
	var state: Node = load("res://tests/fixtures/replica_boundary.gd").State.new()
	adapter.nodes = {"cfg":cfg,"state":state}
	adapter.guest_mode = true
	if not adapter.apply_shared_settings(HOST).ok or cfg.prop_cap!=300:
		errors.append("The native adapter must accept host settings before guest world construction.")
	var changed := HOST.duplicate(true)
	changed.prop_cap = 500
	if not adapter.apply_confirmed_event({"patch":{"settings":changed,"state":{"money":7.0}}}).ok or cfg.prop_cap!=500 or state.data.money!=7.0:
		errors.append("Confirmed host changes must update native gameplay settings alongside shared progress.")
	changed.auto_clean_seconds = -1
	if adapter.apply_confirmed_event({"patch":{"settings":changed,"state":{"money":99.0}}}).ok or state.data.money!=7.0 or cfg.prop_cap!=500:
		errors.append("Malformed settings must reject the entire world patch before any partial mutation.")
	adapter.restore_shared_settings()
	if cfg.prop_cap!=150 or cfg.settings_readonly:
		errors.append("The real adapter cleanup must restore its guest's native settings.")
	cfg.free()
	state.free()
	return errors
