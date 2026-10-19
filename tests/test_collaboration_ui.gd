extends RefCounted

class NativePlayer extends CharacterBody3D:
	var camera: Camera3D

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/world_markers.gd"): return ["World marker display and collaboration UI are missing."]
	var errors: Array[String] = []
	var ui: Node = load("res://mods/ftn_coop/coop_ui.gd").new()
	var session: Node = load("res://mods/ftn_coop/session.gd").new()
	tree.root.add_child(session)
	tree.root.add_child(ui)
	ui.bind_session(session)
	if not ui.has_method("set_presets") or not ui.has_method("set_player_status") or not ui.has_method("set_rejoin_available"):
		errors.append("The F2 menu must expose presets, status and rejoin controls.")
	else:
		session.is_host = true
		session.state = session.State.PLAYING
		session.roster = {1:{"name":"Host","state":"playing","accepted":true},2:{"name":"Guest","state":"playing","accepted":true}}
		ui.set_language("en")
		session.roster[3] = {"name":"Verbinden …","state":"connecting","accepted":false}
		ui._refresh_roster()
		if ui._roster_labels[3].text.contains("Verbinden"): errors.append("An unaccepted connecting peer must use the selected UI language.")
		session.roster[3].accepted = true
		ui._refresh_roster()
		if not ui._roster_labels[3].text.begins_with("Verbinden …"): errors.append("An accepted player's real name must never be translated.")
		session.roster.erase(3)
		ui.set_shared_settings(load("res://tests/test_presets.gd").VALUES)
		ui.set_presets(["Friends"])
		ui.set_player_status({1:{"peer":1,"state":"playing","latency_ms":-1},2:{"peer":2,"state":"playing","latency_ms":40}})
		if ui._preset_apply.disabled or ui._preset_save.disabled or not ui._roster_labels[2].text.contains("40 ms"): errors.append("A playing host must see usable presets and real guest latency.")
		ui._marker_selector.select(1)
		if ui.selected_marker_kind()!="build": errors.append("Marker selection must return a stable message type.")
		ui.set_language("de")
		if ui._preset_save.text!="Vorlage speichern" or ui.selected_marker_kind()!="build": errors.append("Language switching must translate preset controls and preserve marker selection.")
		session.is_host = false
		ui._refresh()
		if not ui._preset_apply.disabled or not ui._preset_save.disabled or ui._preset_name.editable: errors.append("Guest preset editing must stay locked with existing host ownership.")
		ui.set_update_result({"ok":true,"code":"OK","value":{"version":"0.4.0","status":"newer"}})
		ui.set_language("en")
		if not ui._update_status.text.contains("0.4.0") or not ui._update_download.visible: errors.append("A newer release needs a translated status and a download link.")
		ui.set_update_result({"ok":false,"code":"UPDATE_CONNECTION","value":null})
		if ui._update_download.visible or ui.is_panel_open(): errors.append("A failed update check must not offer a false update or interrupt gameplay.")
		session.state = session.State.OFFLINE
		ui.set_rejoin_available(true,false)
		if not ui._rejoin_button.visible or not ui._rejoin_button.disabled: errors.append("A remembered session must wait while cleanup is busy.")
		ui.set_rejoin_available(true,true)
		if ui._rejoin_button.disabled: errors.append("Completed cleanup must make rejoining available.")
		ui.set_rejoin_available(false,false)
		if ui._rejoin_button.visible: errors.append("No remembered target means no rejoin button.")
	var view: Node3D = load("res://mods/ftn_coop/world_markers.gd").new()
	tree.root.add_child(view)
	var rows := [{"peer":2,"position":Vector3(1,0,2),"kind":"build","remaining":1.0}]
	view.set_markers(rows,session.roster,"en")
	if view._nodes.size()!=1 or not view._nodes[2].get_node("Title").text.contains("Build here"): errors.append("A real 3D marker must show its translated kind.")
	view._process(1.1)
	if not view._nodes.is_empty(): errors.append("Expired marker meshes must be removed without waiting for another packet.")
	view.queue_free()
	ui.queue_free()
	session.queue_free()
	errors.append_array(await _surface(tree))
	errors.append_array(await _runtime_controls(tree))
	await tree.process_frame
	return errors

func _runtime_controls(tree: SceneTree) -> Array[String]:
	var script: Script = load("res://mods/ftn_coop/coop_runtime.gd")
	var probe: Node = script.new()
	if not probe.has_method("_apply_preset") or not probe.has_method("_check_updates"):
		probe.free()
		return ["Runtime wiring for real preset, update and marker actions is missing."]
	probe.free()
	var client: Node = load("res://tests/fixtures/update_http.gd").new()
	var runtime: Node = script.new(client)
	var cfg: Node = load("res://tests/fixtures/game_config.gd").new()
	var game: RefCounted = load("res://tests/fixtures/collaboration_game_boundary.gd").new()
	game.configure_settings(cfg)
	game.tree = tree
	var wire: Node = load("res://tests/fixtures/pipe_transport.gd").new()
	tree.root.add_child(runtime)
	runtime.configure(game,wire,"25963876","0.3.0")
	var path := "user://ftn-runtime-presets-"+str(Time.get_ticks_usec())+".dat"
	runtime._presets.configure(path)
	runtime.start_host()
	await tree.process_frame
	await tree.process_frame
	runtime._process(0.2)
	var errors: Array[String] = []
	runtime.ui._preset_name.text = "Friends"
	runtime.ui._preset_save.pressed.emit()
	cfg.set_prop_cap(440)
	runtime.ui._preset_apply.pressed.emit()
	if cfg.prop_cap!=150 or not FileAccess.file_exists(path): errors.append("Real preset buttons must save and apply the host's actual gameplay values.")
	runtime.ui.set_language("en")
	runtime.ui._marker_selector.select(1)
	runtime.ui.set_panel_open(false)
	var mouse_before := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F3
	key.pressed = true
	runtime._unhandled_input(key)
	runtime._physics_process(0.0)
	var markers: Array = runtime.network.collaboration_snapshot().markers
	if markers.size()!=1 or markers[0].kind!="build": errors.append("F3 must create the selected marker through the real runtime and host controller. mouse="+str(Input.mouse_mode)+" allowed="+str(runtime._marker_input_allowed())+" state="+str(runtime.network.session.state))
	runtime.network._markers.advance(1.0)
	runtime._marker_cooldown = 0.0
	runtime.ui._marker_selector.select(0)
	key.echo = true
	runtime._unhandled_input(key)
	runtime._physics_process(0.0)
	key.echo = false
	runtime.ui.set_panel_open(true)
	runtime._unhandled_input(key)
	runtime._physics_process(0.0)
	runtime.ui.set_panel_open(false)
	var editor := LineEdit.new()
	tree.root.add_child(editor)
	editor.grab_focus()
	runtime._unhandled_input(key)
	runtime._physics_process(0.0)
	editor.queue_free()
	await tree.process_frame
	runtime.network.session.state = runtime.network.session.State.SYNCING
	runtime._unhandled_input(key)
	runtime._physics_process(0.0)
	runtime.network.session.state = runtime.network.session.State.PLAYING
	var retained: Array = runtime.network.collaboration_snapshot().markers
	if retained.size()!=1 or retained[0].kind!="build": errors.append("Echo, an open menu, text input and world loading must not place another marker.")
	runtime.ui._check_update.pressed.emit()
	var deadline := Time.get_ticks_msec()+2500
	while not runtime.ui._update_download.visible and Time.get_ticks_msec()<deadline: await tree.process_frame
	if client.request_count!=1 or not runtime.ui._update_status.text.contains("0.3.10"): errors.append("The real update button must show the parsed HTTP result without changing the session.")
	if runtime.network.session.state!=runtime.network.session.State.PLAYING: errors.append("An update check must leave the current multiplayer session intact.")
	Input.mouse_mode = mouse_before
	runtime._leave()
	runtime.queue_free()
	cfg.queue_free()
	await tree.process_frame
	DirAccess.remove_absolute(path)
	return errors

func _surface(tree: SceneTree) -> Array[String]:
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	if not adapter.has_method("read_marker_target"): return ["Native camera surface capture is missing."]
	var world := Node3D.new()
	var player := NativePlayer.new()
	player.position = Vector3(0,2,0)
	player.camera = Camera3D.new()
	player.add_child(player.camera)
	world.add_child(player)
	var wall := StaticBody3D.new()
	wall.position = Vector3(0,2,-5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,2,0.5)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	tree.root.add_child(world)
	adapter.nodes = {"player":player,"world":world}
	await tree.physics_frame
	await tree.physics_frame
	var result: Dictionary = adapter.read_marker_target()
	var errors: Array[String] = []
	if not result.ok or result.value.distance_to(Vector3(0,2,-4.75))>0.02: errors.append("The native marker ray must hit the actual surface under the camera crosshair.")
	world.queue_free()
	await tree.process_frame
	return errors
