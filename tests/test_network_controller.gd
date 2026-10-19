extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/network_controller.gd"):
		return ["End-to-end session/world message routing is not implemented yet."]
	var errors: Array[String] = []
	var module: Script = load("res://mods/ftn_coop/network_controller.gd")
	var boundary: Script = load("res://tests/fixtures/network_game_boundary.gd")
	var transport: Script = load("res://tests/fixtures/pipe_transport.gd")
	var host_game: RefCounted = boundary.new()
	var guest_game: RefCounted = boundary.new()
	host_game.tree = tree
	guest_game.tree = tree
	var host_wire: Node = transport.new()
	var guest_wire: Node = transport.new()
	guest_wire.peer_id = 2
	host_wire.other = guest_wire
	guest_wire.other = host_wire
	var host: Node = module.new()
	var guest: Node = module.new()
	for node in [host_wire,guest_wire,host,guest]: tree.root.add_child(node)
	host.configure(host_wire,host_game,"25963876","0.1.1")
	guest.configure(guest_wire,guest_game,"25963876","0.1.1")
	var stages: Array[String] = []
	if guest.has_signal("load_progress"):
		guest.load_progress.connect(func(stage: String, _received: int, _total: int): stages.append(stage))
	else: errors.append("The controller must expose transfer, native loading and ready stages.")
	guest._receiver.failed.connect(func(_code: String):
		if not stages.is_empty() and stages[-1]!="waiting": errors.append("A rejected baseline must immediately reset its completed receive indicator.")
	)
	host_wire.corrupt_baselines = 1
	host.host()
	await tree.process_frame
	var buffered_production := [false]
	guest_game.restore_started.connect(func():
		var bulk := PackedByteArray()
		bulk.resize(160000)
		var random := RandomNumberGenerator.new()
		random.seed = 112233
		for index in range(bulk.size()): bulk[index] = random.randi() & 255
		host_game.world.bulk = bulk
		host_game.produce()
		host.world_sync.poll()
		buffered_production[0] = true
	)
	guest.join(42)
	var deadline := Time.get_ticks_msec()+2000
	while Time.get_ticks_msec()<deadline:
		await tree.process_frame
		if guest.session.state == guest.session.State.PLAYING: break
	if host_wire.corrupted_baselines!=1: errors.append("The recovery test must damage one actual transferred baseline.")
	if not stages.is_empty():
		for stage in ["receiving","loading","catching_up","ready"]:
			if not stages.has(stage): errors.append("Missing real join progress stage: "+stage)
		var catch_up := stages.find("catching_up")
		if catch_up>=0 and stages.slice(catch_up+1).has("receiving"):
			errors.append("Large catch-up events must not replace the world catch-up phase with baseline download progress.")
	if guest.session.state != guest.session.State.PLAYING or not buffered_production[0] or guest_game.world != host_game.world:
		errors.append("A corrupted initial baseline must be replaced and replay buffered production before playing. state="+str(guest.session.state)+" buffered="+str(buffered_production)+" revision="+str(guest.world_sync.revision))
	else:
		guest_wire.drop_lossy = true
		guest_game.pose = {"position":Vector3(3,4,5),"rotation":Vector3(-0.7,0.2,0)}
		guest.request_action("purchase",{})
		for frame in range(30): await tree.process_frame
		if host_game.world.money != 0 or guest_game.world != host_game.world:
			errors.append("A guest action must change the host once and return the confirmed state.")
		if host_game.last_action_pose != guest_game.pose:
			errors.append("Reliable world actions must carry their exact look/position even when lossy movement packets disappear.")
		var codec: RefCounted = load("res://mods/ftn_coop/protocol.gd").new()
		var packet: Dictionary = codec.encode({"protocol":1,"type":"ACTION","session":host.session.session_id,"body":{"sequence":1,"kind":"purchase","payload":{},"_connection":guest.connection_id}})
		guest_wire.send(1,0,packet.value,true)
		for frame in range(10): await tree.process_frame
		if host_game.world.money != 0 or guest_game.world != host_game.world: errors.append("Wire retries must not duplicate purchases.")
	guest.leave()
	if not stages.is_empty() and stages[-1]!="idle": errors.append("Leaving must reset displayed transfer progress.")
	host.leave()
	for node in [host,guest,host_wire,guest_wire]: node.queue_free()
	await tree.process_frame
	errors.append_array(await _four_socket_peers(tree))
	return errors

func _four_socket_peers(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/local_transport.gd"): return ["Real socket group transport is missing."]
	var module: Script = load("res://mods/ftn_coop/network_controller.gd")
	var transport: Script = load("res://mods/ftn_coop/local_transport.gd")
	var boundary: Script = load("res://tests/fixtures/network_game_boundary.gd")
	var controllers: Array[Node] = []
	var wires: Array[Node] = []
	var games: Array = []
	var errors: Array[String] = []
	var port := 24000+(randi()%20000)
	for index in range(4):
		var wire: Node = transport.new()
		wire.port = port
		var game: RefCounted = boundary.new()
		game.tree = tree
		var controller: Node = module.new()
		tree.root.add_child(wire)
		tree.root.add_child(controller)
		controller.configure(wire,game,"25963876","0.1.1")
		wires.append(wire)
		games.append(game)
		controllers.append(controller)
	controllers[0].host()
	await tree.process_frame
	for index in [1,2]: controllers[index].join(1)
	if not await _await_playing(tree,[controllers[1],controllers[2]]):
		errors.append("Two guests must load through actual loopback sockets.")
	else:
		for index in [1,2]: controllers[index].request_action("purchase",{})
		await tree.create_timer(0.1).timeout
		if games[0].world.money!=0 or games[1].world!=games[0].world or games[2].world!=games[0].world:
			errors.append("Concurrent purchases through separate real peers must debit the shared funds exactly once.")
		games[0].produce()
		controllers[0].world_sync.poll()
		controllers[3].join(1)
		if not await _await_playing(tree,[controllers[3]]): errors.append("A late fourth participant must load the current world.")
		await tree.create_timer(0.05).timeout
		if controllers[0].session.roster.size()!=4: errors.append("Real sockets must retain exactly four admitted participants.")
		for index in [1,2,3]:
			if games[index].world!=games[0].world: errors.append("Every socket replica must match shared money and production after late join.")
	for controller in controllers:
		controller.leave()
		controller.queue_free()
	for wire in wires: wire.queue_free()
	await tree.process_frame
	return errors

func _await_playing(tree: SceneTree, controllers: Array) -> bool:
	var deadline := Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<deadline:
		var ready := true
		for controller in controllers:
			if controller.session.state!=controller.session.State.PLAYING: ready = false
		if ready: return true
		await tree.process_frame
	return false
