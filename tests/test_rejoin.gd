extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/rejoin_state.gd"): return ["Explicit remembered-session rejoin is missing."]
	var state: RefCounted = load("res://mods/ftn_coop/rejoin_state.gd").new()
	var errors: Array[String] = []
	state.remember(42)
	if not state.can_rejoin(true,false) or state.can_rejoin(true,true) or state.can_rejoin(false,false): errors.append("Rejoin eligibility must require offline state and completed cleanup.")
	state.clear()
	if state.target()!=0: errors.append("Voluntary leave must forget the target.")
	var pipe: Script = load("res://tests/fixtures/pipe_transport.gd")
	var a: Node = pipe.new()
	var b: Node = pipe.new()
	b.peer_id = 2
	a.other = b
	b.other = a
	var boundary: Script = load("res://tests/fixtures/rejoin_game_boundary.gd")
	var host_game: RefCounted = boundary.new()
	var guest_game: RefCounted = boundary.new()
	host_game.tree = tree
	guest_game.tree = tree
	var host: Node = load("res://mods/ftn_coop/network_controller.gd").new()
	var runtime: Node = load("res://mods/ftn_coop/coop_runtime.gd").new()
	for node in [a,host,runtime]: tree.root.add_child(node)
	host.configure(a,host_game,"25963876","0.4.0")
	runtime.configure(guest_game,b,"25963876","0.4.0")
	if not runtime.has_method("rejoin_last_session"):
		errors.append("The runtime must offer a cleanup-gated explicit rejoin action.")
	else:
		host.host()
		await tree.process_frame
		runtime.join_invitation(42)
		await _wait_playing(tree,runtime.network)
		var old_cookie: String = runtime.network.connection_id
		b.close()
		runtime.rejoin_last_session()
		runtime.rejoin_last_session()
		if b.join_calls!=1 or not runtime.network.save_session.closing: errors.append("Rejoin must wait for native cleanup instead of overlapping the old guest world.")
		await _wait_playing(tree,runtime.network)
		if b.join_calls!=2 or runtime.network.connection_id==old_cookie or runtime.network.session.state!=runtime.network.session.State.PLAYING: errors.append("Exactly one fresh authenticated join must follow cleanup.")
		runtime._leave()
		await tree.create_timer(0.08).timeout
		runtime.rejoin_last_session()
		if b.join_calls!=2: errors.append("Choosing Leave must remove the automatic rejoin target.")
		runtime.join_invitation(42)
		await _wait_playing(tree,runtime.network)
		b.close()
		runtime.join_invitation(43)
		await _wait_playing(tree,runtime.network)
		if runtime._rejoin.target()!=43 or b.join_calls!=4: errors.append("A newer invitation must replace the cleanup-pending old rejoin target.")
		if b.joined_lobbies!=[42,42,42,43]: errors.append("The real join boundary must receive the replacement lobby rather than an old pending invitation.")
		guest_game.fail_close = true
		b.close()
		runtime.rejoin_last_session()
		await tree.create_timer(0.08).timeout
		runtime.rejoin_last_session()
		if b.join_calls!=4 or not runtime.network.save_session.guest_open: errors.append("Failed cleanup must retain the old guest world and block any new join.")
		guest_game.fail_close = false
		runtime._leave()
		await tree.create_timer(0.08).timeout
	host.leave()
	for node in [runtime,host,a]: node.queue_free()
	await tree.process_frame
	return errors

func _wait_playing(tree: SceneTree, controller: Node) -> void:
	var deadline := Time.get_ticks_msec()+2000
	while controller.session.state!=controller.session.State.PLAYING and Time.get_ticks_msec()<deadline: await tree.process_frame
