extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	for path in ["avatar","presence","coop_ui"]:
		if not FileAccess.file_exists("res://mods/ftn_coop/"+path+".gd"): return ["Player presence and German co-op controls are not implemented yet."]
	var errors: Array[String] = []
	var presence: Node3D = load("res://mods/ftn_coop/presence.gd").new()
	tree.root.add_child(presence)
	var roster := {1:{"name":"Host"},2:{"name":"Anna"},3:{"name":"Ben"},4:{"name":"Clara"}}
	presence.sync_roster(1,roster)
	if presence.avatars.size()!=3 or presence.avatars.has(1): errors.append("Exactly the three remote players need an avatar.")
	var anna: Node3D = presence.avatars.get(2)
	roster.erase(3)
	presence.sync_roster(1,roster)
	if presence.avatars.size()!=2 or presence.avatars.get(2)!=anna or presence.avatars.has(3): errors.append("Removing one player must preserve the other avatars.")
	presence.apply_pose(2,{"position":Vector3(2,0,3),"rotation":Vector3(0,0.5,0)})
	anna._process(1.0)
	if anna.position.distance_to(Vector3(2,0,3))>0.01: errors.append("A remote avatar must interpolate towards a valid pose.")
	var valid := anna.position
	for bad in [Vector3(NAN,0,0),Vector3(0,INF,0),Vector3(99999,0,0)]:
		presence.apply_pose(2,{"position":bad,"rotation":Vector3.ZERO})
		anna._process(1.0)
		if anna.position!=valid: errors.append("Invalid remote poses must not move an avatar.")
	var ui: Node = load("res://mods/ftn_coop/coop_ui.gd").new()
	var session: Node = load("res://mods/ftn_coop/session.gd").new()
	tree.root.add_child(session)
	tree.root.add_child(ui)
	ui.bind_session(session)
	ui.set_panel_open(false)
	session.state = session.State.SYNCING
	if ui.actions_allowed(): errors.append("No guest world actions are allowed while synchronizing.")
	session.state = session.State.PLAYING
	if not ui.actions_allowed(): errors.append("Ready players can act when the co-op panel is closed.")
	ui.set_panel_open(true)
	if ui.actions_allowed(): errors.append("Menu interaction must not also invoke world actions.")
	for item in [["SESSION_FULL","voll"],["BUILD_MISMATCH","Version"],["HOST_DISCONNECTED","Verbindung"]]:
		ui.show_error(item[0])
		if not ui.error_text().contains(item[1]): errors.append("Missing German explanation for "+item[0])
	ui.queue_free()
	session.queue_free()
	presence.queue_free()
	await tree.process_frame
	if not FileAccess.file_exists("res://mods/ftn_coop/coop_runtime.gd"): return errors+["The co-op menu must be connected to the real session lifecycle."]
	var runtime: Node = load("res://mods/ftn_coop/coop_runtime.gd").new()
	var transport: Node = load("res://tests/fixtures/pipe_transport.gd").new()
	var game: RefCounted = load("res://tests/fixtures/network_game_boundary.gd").new()
	game.tree = tree
	tree.root.add_child(runtime)
	runtime.configure(game,transport,"25963876","0.1.0-dev")
	transport.simulate_invitation(42)
	if transport.join_calls!=1 or runtime.network.session.state!=runtime.network.session.State.JOINING: errors.append("Steam invitations must be received before the player ever hosts or joins manually.")
	runtime.ui.host_requested.emit()
	await tree.process_frame
	await tree.process_frame
	if runtime.network.session.state!=runtime.network.session.State.PLAYING: errors.append("The host button must create a playable host session.")
	runtime.ui.invite_requested.emit()
	if transport.invite_calls!=1: errors.append("The invite button must open exactly one Steam friend picker.")
	runtime.ui.leave_requested.emit()
	if runtime.network.session.state!=runtime.network.session.State.OFFLINE: errors.append("The leave button must close the session.")
	runtime.queue_free()
	await tree.process_frame
	return errors
