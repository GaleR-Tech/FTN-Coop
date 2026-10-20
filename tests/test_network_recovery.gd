extends RefCounted

class SilentTransport extends "res://tests/fixtures/fake_transport.gd":
	func send(_peer: int, _channel: int, _bytes: PackedByteArray, _reliable: bool) -> Dictionary:
		return {"ok":true,"code":"OK","value":null}

func run(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	# A socket that connected without a welcome must not strand the join screen.
	var guest := _guest(tree)
	var problems: Array[String] = []
	guest.controller.problem.connect(func(code: String): problems.append(code))
	guest.controller.join(42)
	guest.wire.connected.emit(1)
	guest.controller._process(16.0)
	if problems != ["CONNECT_TIMEOUT"] or guest.controller.session.state != guest.controller.session.State.OFFLINE:
		errors.append("A connected host that never welcomes its guest must time out and free the session.")
	guest.controller.leave()
	# A retry must get its own time budget, with no failure carried from before.
	problems.clear()
	guest.controller.join(42)
	guest.wire.connected.emit(1)
	guest.controller._process(0.1)
	if not problems.is_empty() or guest.controller.session.state != guest.controller.session.State.SYNCING:
		errors.append("Retrying a timed-out join must start with a fresh wait budget.")
	_dispose(guest)
	await tree.process_frame

	# Welcoming alone is not progress: missing initial world data also expires.
	guest = _guest(tree)
	problems.clear()
	guest.controller.problem.connect(func(code: String): problems.append(code))
	guest.controller.join(42)
	guest.wire.connected.emit(1)
	_deliver(guest.controller,"WELCOME",_welcome())
	guest.controller._process(121.0)
	if problems != ["TRANSFER_TIMEOUT"] or guest.controller.session.state != guest.controller.session.State.OFFLINE:
		errors.append("A welcomed guest must not wait forever for the first world packet.")
	_dispose(guest)
	await tree.process_frame

	# Initial waiting plus transfer may exceed two minutes without stalling.
	guest = _guest(tree)
	problems.clear()
	guest.controller.problem.connect(func(code: String): problems.append(code))
	guest.controller.join(42)
	guest.wire.connected.emit(1)
	_deliver(guest.controller,"WELCOME",_welcome())
	var bulk := PackedByteArray()
	bulk.resize(160000)
	var random := RandomNumberGenerator.new()
	random.seed = 4182
	for index in range(bulk.size()): bulk[index] = random.randi() & 255
	var sender: Node = load("res://mods/ftn_coop/snapshot_transfer.gd").new()
	var transfer: Dictionary = sender.begin({"bulk":bulk},"0123456789abcdef0123456789abcdef",1)
	var frames: Array = transfer.value.frames
	guest.controller._process(70.0)
	_deliver(guest.controller,"SNAPSHOT_BEGIN",frames[0])
	for index in range(1,frames.size()-1):
		guest.controller._process(25.0)
		guest.controller._receiver._process(25.0)
		_deliver(guest.controller,"SNAPSHOT_CHUNK",frames[index])
	if not problems.is_empty() or guest.controller.session.state != guest.controller.session.State.SYNCING:
		errors.append("Actual received world chunks must renew the guest wait budget during a slow transfer.")
	guest.controller._process(121.0)
	if problems != ["TRANSFER_TIMEOUT"]:
		errors.append("A progressing world transfer must still time out if its remaining chunks stop arriving.")
	sender.free()
	_dispose(guest)
	await tree.process_frame

	# Native world creation is asynchronous and must not be cut short by this timer.
	guest = _guest(tree)
	problems.clear()
	guest.controller.problem.connect(func(code: String): problems.append(code))
	guest.controller.join(42)
	guest.wire.connected.emit(1)
	_deliver(guest.controller,"WELCOME",_welcome())
	guest.controller._on_snapshot_completed({"mode":"world","native":{"money":20},"frame":{"money":20}},1)
	guest.controller._process(130.0)
	if not problems.is_empty() or not guest.game.restoring:
		errors.append("A slow native world load must keep its guest session alive.")
	await tree.create_timer(0.05).timeout
	guest.controller._process(0.1)
	if not problems.is_empty() or not guest.controller.save_session.guest_open:
		errors.append("Catch-up must receive a fresh timeout after native world creation.")
	guest.controller._process(70.0)
	_deliver(guest.controller,"EVENT",{"revision":2,"patch":{"money":30}})
	guest.controller._process(70.0)
	if not problems.is_empty() or guest.game.world.get("money")!=30:
		errors.append("Accepted catch-up events must renew the wait budget while shared progress is being applied.")
	guest.controller._process(121.0)
	if problems != ["TRANSFER_TIMEOUT"] or guest.controller.session.state != guest.controller.session.State.OFFLINE or guest.controller.save_session.guest_open:
		errors.append("A missing final world confirmation must time out and close the temporary guest world.")
	_dispose(guest)
	await tree.process_frame
	return errors

func _guest(tree: SceneTree) -> Dictionary:
	var wire := SilentTransport.new()
	var game: RefCounted = load("res://tests/fixtures/network_game_boundary.gd").new()
	game.tree = tree
	var controller: Node = load("res://mods/ftn_coop/network_controller.gd").new()
	tree.root.add_child(wire)
	tree.root.add_child(controller)
	controller.configure(wire,game,"25963876","0.4.0")
	controller.set_process(false)
	return {"controller":controller,"wire":wire,"game":game}

func _welcome() -> Dictionary:
	return {"session_id":"0123456789abcdef0123456789abcdef","player_id":2,"mod_version":"0.4.0","roster":[
		{"id":1,"name":"Host","state":"playing","accepted":true},
		{"id":2,"name":"Guest","state":"syncing","accepted":true},
	]}

func _deliver(controller: Node, kind: String, value: Dictionary) -> void:
	var body := value.duplicate(true)
	body._connection = "fedcba9876543210fedcba9876543210"
	var protocol: RefCounted = load("res://mods/ftn_coop/protocol.gd").new()
	var packet: Dictionary = protocol.encode({"protocol":1,"type":kind,"session":"0123456789abcdef0123456789abcdef","body":body})
	controller._on_message(1,0,packet.value)

func _dispose(guest: Dictionary) -> void:
	guest.controller.leave()
	guest.controller.queue_free()
	guest.wire.queue_free()
