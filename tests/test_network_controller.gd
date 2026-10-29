extends RefCounted

class Inventory extends Node:
	signal tools_changed
	var owned_tools := {"spade":true}
	func drop() -> void:
		owned_tools.erase("spade")
		tools_changed.emit()

class TeardownBoundary extends "res://tests/fixtures/network_game_boundary.gd":
	var inventory := Inventory.new()
	var scope: RefCounted = load("res://mods/ftn_coop/shared_tools.gd").new()
	func start_shared_tools() -> void: scope.configure(inventory,["spade"])
	func stop_shared_tools() -> void: scope.close()
	func remove_actor(_peer: int) -> void: inventory.drop()

class BusyTransport extends "res://tests/fixtures/fake_transport.gd":
	var busy := true
	var delivered: Array[int] = []
	var healthy := 0
	func local_peer_id() -> int: return 1
	func send(_peer: int, _channel: int, bytes: PackedByteArray, _reliable: bool) -> Dictionary:
		if busy and _peer==2: return {"ok":false,"code":"WOULD_BLOCK","value":null}
		var decoded: Dictionary = load("res://mods/ftn_coop/protocol.gd").new().decode(bytes)
		if decoded.ok and decoded.value.type=="EVENT": delivered.append(decoded.value.body.revision)
		if _peer==3: healthy += 1
		return {"ok":true,"code":"OK","value":null}

class NativePeer extends OfflineMultiplayerPeer:
	func get_steam_id_for_peer_id(_peer: int) -> int: return 123

class SteamApi extends RefCounted:
	var result := 25
	var sent := 0
	var last_flags := 0
	func getConnectionInfo(_handle: int) -> Dictionary:
		return {"identity":123,"user_data":2,"connection_state":3}
	func sendMessageToConnection(_handle: int, _bytes: PackedByteArray, _flags: int) -> Dictionary:
		sent += 1
		last_flags = _flags
		return {"result":result,"message_number":sent}

class RejectTransport extends "res://tests/fixtures/fake_transport.gd":
	func reject_peer(peer: int) -> void: disconnected.emit(peer)
	func local_peer_id() -> int: return 1

class FullTransfer extends Node:
	func buffer_event(_event: Dictionary) -> Dictionary: return {"ok":false,"code":"RESYNC_REQUIRED","value":null}

class TrafficTransport extends "res://tests/fixtures/fake_transport.gd":
	var messages: Array[Dictionary] = []
	var blocked := false
	func local_peer_id() -> int: return 1
	func send(peer: int, _channel: int, bytes: PackedByteArray, reliable: bool) -> Dictionary:
		if blocked and peer==2 and reliable: return {"ok":false,"code":"WOULD_BLOCK","value":null}
		var decoded: Dictionary = load("res://mods/ftn_coop/protocol.gd").new().decode(bytes)
		if decoded.ok: messages.append({"peer":peer,"type":decoded.value.type,"body":decoded.value.body,"bytes":bytes.size(),"reliable":reliable})
		return {"ok":true,"code":"OK","value":null}

class SaturatedTransport extends "res://tests/fixtures/pipe_transport.gd":
	const CAPACITY := 65536
	var pending: Array[Dictionary] = []
	var buffered_bytes := 0
	var peak := 0
	var blocked := 0
	func send(target: int, channel: int, bytes: PackedByteArray, reliable: bool) -> Dictionary:
		if buffered_bytes+bytes.size()>CAPACITY:
			blocked += 1
			return {"ok":false,"code":"WOULD_BLOCK","value":null} if reliable else _ok()
		buffered_bytes += bytes.size()
		peak = maxi(peak,buffered_bytes)
		pending.append({"target":target,"channel":channel,"bytes":bytes.duplicate(),"due":Time.get_ticks_msec()+100})
		return _ok()
	func _process(_delta: float) -> void:
		while not pending.is_empty() and pending[0].due<=Time.get_ticks_msec():
			var packet: Dictionary = pending.pop_front()
			buffered_bytes -= packet.bytes.size()
			other.message_received.emit(peer_id,packet.channel,packet.bytes)

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
	host.configure(host_wire,host_game,"25963876","0.4.0")
	guest.configure(guest_wire,guest_game,"25963876","0.4.0")
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
		if guest_game.equipped_tool!=1: errors.append("A successful purchase must return the buyer's selected equipment to that guest.")
		if host_game.last_action_pose != guest_game.pose:
			errors.append("Reliable world actions must carry their exact look/position even when lossy movement packets disappear.")
		var codec: RefCounted = load("res://mods/ftn_coop/protocol.gd").new()
		guest_game.equipped_tool = 0
		var packet: Dictionary = codec.encode({"protocol":1,"type":"ACTION","session":host.session.session_id,"body":{"sequence":1,"kind":"purchase","payload":{},"_connection":guest.connection_id}})
		guest_wire.send(1,0,packet.value,true)
		for frame in range(10): await tree.process_frame
		if host_game.world.money != 0 or guest_game.world != host_game.world: errors.append("Wire retries must not duplicate purchases.")
		if guest_game.equipped_tool!=0: errors.append("A retried purchase result must not override a player's later equipment selection.")
		guest.request_action("place",{"id":"belt"})
		for frame in range(15): await tree.process_frame
		if guest_game.preview_stage!=1: errors.append("A host-confirmed placement step must return its preview anchor to the guest.")
		guest.pose_stream_enabled = false
		guest.request_action("item_interact",{"operation":"drop"})
		for frame in range(15): await tree.process_frame
		if guest_game.equipped_tool!=0 or host_game.read_actor_equipment(2).tool!=0: errors.append("A tool drop must unequip the corresponding player on both sides.")
		guest_wire.drop_lossy = false
		var late_pose := {"position":Vector3(3,4,5),"rotation":Vector3.ZERO,"tool":1,"equipment_epoch":0}
		packet = codec.encode({"protocol":1,"type":"POSE","session":host.session.session_id,"body":{"pose":late_pose,"serial":1000000+late_pose.equipment_epoch,"_connection":guest.connection_id}})
		guest_wire.send(1,1,packet.value,false)
		for frame in range(5): await tree.process_frame
		if host_game.read_actor_equipment(2).tool!=0: errors.append("A movement packet sent before the drop confirmation must not put the dropped tool back in that player's hand.")
		late_pose.equipment_epoch = guest._last_equipment_sequence
		packet = codec.encode({"protocol":1,"type":"POSE","session":host.session.session_id,"body":{"pose":late_pose,"serial":1000000+late_pose.equipment_epoch,"_connection":guest.connection_id}})
		guest_wire.send(1,1,packet.value,false)
		for frame in range(5): await tree.process_frame
		if host_game.read_actor_equipment(2).tool!=1: errors.append("A deliberate tool selection after the drop confirmation must remain available.")
	guest.leave()
	if not stages.is_empty() and stages[-1]!="idle": errors.append("Leaving must reset displayed transfer progress.")
	host.leave()
	for node in [host,guest,host_wire,guest_wire]: node.queue_free()
	await tree.process_frame
	errors.append_array(await _four_socket_peers(tree))
	errors.append_array(await _shared_unlock_teardown(tree))
	errors.append_array(await _send_backpressure(tree))
	errors.append_array(_steam_send_results())
	errors.append_array(await _disconnect_during_broadcast(tree))
	errors.append_array(await _fragmented_event_backpressure(tree))
	errors.append_array(await _fair_network_traffic(tree))
	errors.append_array(await _bounded_frame_traffic(tree))
	errors.append_array(await _idle_pose_traffic(tree))
	errors.append_array(await _shared_compressed_events(tree))
	return errors

func _shared_compressed_events(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var wire := TrafficTransport.new()
	var game: RefCounted = load("res://tests/fixtures/network_game_boundary.gd").new()
	game.tree = tree
	var controller: Node = load("res://mods/ftn_coop/network_controller.gd").new()
	for node in [wire,controller]: tree.root.add_child(node)
	controller.configure(wire,game,"25963876","0.7.1")
	controller.set_process(false)
	controller.session.is_host = true
	controller.session.session_id = "0123456789abcdef0123456789abcdef"
	for peer in [2,3,4]:
		controller.session.roster[peer] = {"accepted":true,"state":"playing","name":"Player"}
		controller._connections[peer] = str(peer).repeat(32)
	var props := []
	for index in range(80):
		props.append({"id":"hay_wad","state":{"strands":100},"xform":Transform3D(Basis.IDENTITY,Vector3(index,1,2))})
	var event := {"revision":1,"kind":"native","patch":{"props":props}}
	var protocol: RefCounted = load("res://mods/ftn_coop/protocol.gd").new()
	var raw: Dictionary = protocol.encode({"protocol":1,"type":"EVENT","session":controller.session.session_id,"body":event})
	controller._on_confirmed(event)
	controller._on_confirmed({"revision":2,"patch":{"money":25}})
	var shared_transfer := ""
	for peer in [2,3,4]:
		var receiver: Node = load("res://mods/ftn_coop/snapshot_transfer.gd").new()
		receiver.configure(controller.session.session_id)
		var completed := []
		receiver.completed.connect(func(value: Dictionary,revision: int): completed.append({"value":value,"revision":revision}))
		var bytes := 0
		var revisions := []
		for packet in controller._tx:
			if packet.peer!=peer: continue
			var decoded: Dictionary = protocol.decode(packet.bytes)
			if not decoded.ok:
				errors.append("Compressed event frames must remain valid protocol packets.")
				continue
			var message: Dictionary = decoded.value
			if message.body.get("_connection")!=controller._connections[peer]: errors.append("Shared event preparation must preserve each guest's connection cookie.")
			if message.type=="EVENT": revisions.append(message.body.revision)
			else:
				bytes += packet.bytes.size()
				if message.type=="SNAPSHOT_BEGIN":
					if shared_transfer.is_empty(): shared_transfer = message.body.transfer
					elif shared_transfer!=message.body.transfer: errors.append("One world event must be compressed once and shared across all playing guests.")
				var frame: Dictionary = message.body.duplicate(true)
				frame.erase("_connection")
				receiver.receive(1,frame)
				if not completed.is_empty() and revisions.is_empty(): revisions.append(completed[0].revision)
		if completed.size()!=1 or completed[0].value!={"mode":"event","event":event} or revisions!=[1,2]:
			errors.append("A medium world event must use compressed frames and preserve the following small revision.")
		# The compact pose format already shrinks the raw reference. Keep an
		# absolute wire budget as well as requiring useful compression savings.
		if not raw.ok or bytes>2200 or bytes>=raw.value.size(): errors.append("Medium moving-world updates exceed the wire budget: "+str(bytes)+" bytes")
		receiver.free()
	controller.leave()
	for node in [controller,wire]: node.queue_free()
	await tree.process_frame
	return errors

func _fair_network_traffic(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var wire := TrafficTransport.new()
	var game: RefCounted = load("res://tests/fixtures/network_game_boundary.gd").new()
	game.tree = tree
	var controller: Node = load("res://mods/ftn_coop/network_controller.gd").new()
	for node in [wire,controller]: tree.root.add_child(node)
	controller.configure(wire,game,"25963876","0.7.1")
	controller.set_process(false)
	controller.pose_stream_enabled = false
	controller.session.is_host = true
	controller.session.state = controller.session.State.PLAYING
	controller.session.session_id = "0123456789abcdef0123456789abcdef"
	for revision in range(1,25): controller._queue(2,"EVENT",{"revision":revision,"patch":{}})
	controller._queue(3,"STATUS_PROBE",{"token":7})
	controller._queue(2,"POSE",{"peer":1,"pose":{"position":Vector3(4,0,0)}},false)
	controller._drain_packets(0.01)
	var healthy := false
	var moving := false
	for message in wire.messages:
		if message.peer==3 and message.type=="STATUS_PROBE": healthy = true
		if message.peer==2 and message.type=="POSE": moving = true
	if not healthy: errors.append("A large join stream must not consume another guest's entire frame send budget.")
	if not moving: errors.append("Current movement must pass a backlog of independent reliable world packets in the same frame.")
	for frame in range(5): controller._drain_packets(0.01)
	var revisions: Array = []
	for message in wire.messages:
		if message.type=="EVENT": revisions.append(message.body.revision)
	if revisions!=range(1,25): errors.append("Fair scheduling must preserve every reliable revision exactly once and in order.")
	wire.messages.clear()
	wire.blocked = true
	controller._send_blocked[2] = 20.0
	controller._queue(2,"EVENT",{"revision":25,"patch":{}})
	controller._queue(2,"POSE",{"peer":1,"pose":{"position":Vector3(5,0,0)}},false)
	controller._drain_packets(0.01)
	if wire.messages.size()!=1 or wire.messages[0].type!="POSE" or controller._tx.size()!=1:
		errors.append("A blocked reliable packet must remain queued while an independently deliverable movement packet can leave.")
	if controller._send_blocked.get(2,0.0)<20.0: errors.append("Successful lossy movement must not reset a blocked reliable stream's timeout.")
	wire.blocked = false
	controller._drain_packets(0.01)
	if wire.messages.size()!=2 or wire.messages[1].type!="EVENT" or wire.messages[1].body.revision!=25:
		errors.append("A blocked world packet must still arrive exactly once after movement has passed it.")
	controller.leave()
	for node in [controller,wire]: node.queue_free()
	await tree.process_frame
	return errors

func _bounded_frame_traffic(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var wire := TrafficTransport.new()
	var game: RefCounted = load("res://tests/fixtures/network_game_boundary.gd").new()
	game.tree = tree
	var controller: Node = load("res://mods/ftn_coop/network_controller.gd").new()
	for node in [wire,controller]: tree.root.add_child(node)
	controller.configure(wire,game,"26260645","0.7.2")
	controller.set_process(false)
	controller.session.is_host = true
	controller.session.session_id = "0123456789abcdef0123456789abcdef"
	for peer in [2,3,4]:
		for actor in [1,2,3]: controller._queue(peer,"POSE",{"peer":actor,"pose":{"position":Vector3(actor,0,0)}},false)
		for revision in [1,2,3]: controller._queue(peer,"EVENT",{"revision":revision,"patch":{"blob":"a".repeat(9000)}})
		controller._queue(peer,"ACTION_RESULT",{"sequence":1,"ok":true,"code":"OK"})
	controller._drain_packets(0.033)
	for peer in [2,3,4]:
		var revisions := []
		var answered := false
		for message in wire.messages:
			if message.peer!=peer: continue
			if message.type=="EVENT": revisions.append(message.body.revision)
			if message.type=="ACTION_RESULT": answered = true
		if revisions!=[1,2,3] or not answered: errors.append("Movement must not consume the small-message allowance and delay a guest's bounded world update and action result.")
	for frame in range(8):
		if controller._tx.is_empty(): break
		controller._drain_packets(0.033)
	wire.messages.clear()
	for revision in range(4,24): controller._queue(2,"EVENT",{"revision":revision,"patch":{"blob":"b".repeat(20000)}})
	controller._queue(3,"STATUS_PROBE",{"token":1})
	controller._drain_packets(0.033)
	var bytes := 0
	var healthy := false
	for message in wire.messages:
		if message.peer==2 and message.reliable: bytes += message.bytes
		if message.peer==3: healthy = true
	if bytes>65536 or not healthy or controller._tx.is_empty(): errors.append("Large transfers must obey each peer's byte budget while another peer's control messages remain deliverable.")
	controller.leave()
	for node in [wire,controller]: node.queue_free()
	await tree.process_frame
	return errors

func _idle_pose_traffic(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var wire := TrafficTransport.new()
	var game: RefCounted = load("res://tests/fixtures/network_game_boundary.gd").new()
	game.tree = tree
	var controller: Node = load("res://mods/ftn_coop/network_controller.gd").new()
	for node in [wire,controller]: tree.root.add_child(node)
	controller.configure(wire,game,"25963876","0.7.1")
	controller.set_process(false)
	controller.session.is_host = true
	controller.session.state = controller.session.State.PLAYING
	controller.session.session_id = "0123456789abcdef0123456789abcdef"
	var standing := {"peer":1,"pose":{"position":Vector3.ZERO,"rotation":Vector3.ZERO,"tool":0}}
	controller._queue(2,"POSE",standing,false)
	controller._drain_packets(0.01)
	for frame in range(30):
		controller._queue(2,"POSE",standing,false)
		controller._drain_packets(0.001)
	if wire.messages.size()!=1: errors.append("Unchanged standing poses must not flood the network between keepalives.")
	controller._queue(3,"POSE",standing,false)
	controller._queue(2,"POSE",{"peer":4,"pose":standing.pose},false)
	var changed := standing.duplicate(true)
	changed.pose.tool = 1
	controller._queue(2,"POSE",changed,false)
	controller._drain_packets(0.01)
	if wire.messages.size()!=4: errors.append("New destinations, different players and a changed tool must each publish immediately, even at an unchanged position.")
	await tree.create_timer(0.55).timeout
	controller._queue(2,"POSE",changed,false)
	controller._drain_packets(0.01)
	if wire.messages.size()!=5: errors.append("A stationary player's latest pose must be resent after a half-second keepalive so packet loss can recover.")
	controller._discard_packets(2)
	controller._queue(2,"POSE",changed,false)
	controller._drain_packets(0.01)
	if wire.messages.size()!=6: errors.append("A reused peer connection must publish its first pose immediately, without the departed stream's suppression state.")
	controller.leave()
	controller.session.session_id = "fedcba9876543210fedcba9876543210"
	controller._queue(2,"POSE",changed,false)
	controller._drain_packets(0.01)
	if wire.messages.size()!=7: errors.append("A new session must publish its initial pose immediately even when the same destination and pose were just used.")
	for node in [controller,wire]: node.queue_free()
	await tree.process_frame
	return errors

func _fragmented_event_backpressure(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var host_wire := SaturatedTransport.new()
	var guest_wire: Node = load("res://tests/fixtures/pipe_transport.gd").new()
	guest_wire.peer_id = 2
	host_wire.other = guest_wire
	guest_wire.other = host_wire
	var host: Node = load("res://mods/ftn_coop/network_controller.gd").new()
	var guest: Node = load("res://mods/ftn_coop/network_controller.gd").new()
	for node in [host_wire,guest_wire,host,guest]: tree.root.add_child(node)
	for pair in [[host,host_wire],[guest,guest_wire]]:
		var game: RefCounted = load("res://tests/fixtures/network_game_boundary.gd").new()
		game.tree = tree
		pair[0].configure(pair[1],game,"25963876","0.5.2")
		pair[0].pose_stream_enabled = false
	var loads := [0]
	guest.load_progress.connect(func(stage: String,_received: int,_total: int):
		if stage=="loading": loads[0] += 1
	)
	host.host()
	await tree.process_frame
	guest.join(42)
	if not await _await_playing(tree,[guest]): errors.append("The saturation regression must join with a small valid baseline.")
	else:
		var bulk := PackedByteArray()
		bulk.resize(700000)
		var rng := RandomNumberGenerator.new()
		rng.seed = 38741
		for index in range(bulk.size()): bulk[index] = rng.randi() & 255
		host.world_sync._confirm({"patch":{"bulk":bulk}})
		host.world_sync._confirm({"patch":{"money":25}})
		var deadline := Time.get_ticks_msec()+6000
		while Time.get_ticks_msec()<deadline and guest.world_sync.revision!=host.world_sync.revision: await tree.process_frame
		if guest.world_sync.revision!=host.world_sync.revision or guest._adapter.world!={"money":25} or loads[0]!=1 or not guest.recovery_reason.is_empty():
			errors.append("A fragmented large event followed by a small revision must survive saturation without a missing revision or world reload.")
		if host_wire.blocked==0 or host_wire.peak>SaturatedTransport.CAPACITY: errors.append("The saturation regression must exercise bounded Steam-like backpressure.")
	guest.leave()
	host.leave()
	for node in [host,guest,host_wire,guest_wire]: node.queue_free()
	await tree.process_frame
	return errors

func _disconnect_during_broadcast(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var wire := RejectTransport.new()
	var game: RefCounted = load("res://tests/fixtures/network_game_boundary.gd").new()
	game.tree = tree
	var controller: Node = load("res://mods/ftn_coop/network_controller.gd").new()
	for node in [wire,controller]: tree.root.add_child(node)
	controller.configure(wire,game,"25963876","0.5.2")
	controller.set_process(false)
	controller.session.is_host = true
	controller.session.session_id = "0123456789abcdef0123456789abcdef"
	controller.session.state = controller.session.State.PLAYING
	for peer in [1,2,3]: controller.session.roster[peer] = {"accepted":true,"state":"playing","name":"Player"}
	var transfer := FullTransfer.new()
	controller.add_child(transfer)
	controller._pending[2] = {"transfer":transfer}
	controller._on_confirmed({"revision":7,"patch":{}})
	var delivered := false
	for packet in controller._tx:
		var message: Dictionary = load("res://mods/ftn_coop/protocol.gd").new().decode(packet.bytes)
		if packet.peer==3 and message.ok and message.value.type=="EVENT" and message.value.body.revision==7: delivered = true
	if not delivered: errors.append("Disconnecting a guest during broadcast must not skip a revision for a healthy guest.")
	controller.leave()
	for node in [controller,wire]: node.queue_free()
	await tree.process_frame
	return errors

func _steam_send_results() -> Array[String]:
	var errors: Array[String] = []
	var wire: Node = load("res://mods/ftn_coop/steam_transport.gd").new()
	var api := SteamApi.new()
	wire._steam = api
	wire._peer = NativePeer.new()
	if wire.has_method("_on_network_connection_status_changed"):
		wire._on_network_connection_status_changed(99,{"identity":123,"connection_state":3},2)
	if wire.send(2,0,PackedByteArray([1,2,3]),true).code!="WOULD_BLOCK" or api.sent!=1:
		errors.append("Steam saturation must expose its real LimitExceeded result instead of a successful native wrapper return.")
	api.result = 1
	if not wire.send(2,0,PackedByteArray([1,2,3]),true).ok or api.sent!=2:
		errors.append("A reliable Steam packet must retry through the checked send API once buffer space is available.")
	if api.last_flags!=9: errors.append("Interactive reliable Steam messages must bypass the SDK's optional Nagle delay without losing reliable delivery.")
	wire._steam = null
	wire.free()
	return errors

func _send_backpressure(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var wire := BusyTransport.new()
	var game: RefCounted = load("res://tests/fixtures/network_game_boundary.gd").new()
	game.tree = tree
	var controller: Node = load("res://mods/ftn_coop/network_controller.gd").new()
	for node in [wire,controller]: tree.root.add_child(node)
	controller.configure(wire,game,"25963876","0.5.2")
	controller.set_process(false)
	controller.session.is_host = true
	controller.session.state = controller.session.State.PLAYING
	controller.session.session_id = "0123456789abcdef0123456789abcdef"
	controller._queue(2,"EVENT",{"revision":1,"patch":{}})
	controller._queue(2,"EVENT",{"revision":2,"patch":{}})
	controller._queue(3,"STATUS_PROBE",{"token":1})
	controller._process(0.01)
	if controller._tx.size()!=2 or controller.session.state!=controller.session.State.PLAYING:
		errors.append("A full Steam send buffer must retain reliable packets and keep the session open.")
	if wire.healthy!=1: errors.append("A guest with a saturated send buffer must not block delivery to another guest.")
	for index in range(40): controller._queue(2,"POSE",{"pose":{"position":Vector3(index,0,0)}},false)
	if controller._tx.size()!=3: errors.append("Only the latest waiting movement packet may remain behind a saturated reliable stream.")
	controller._queue(2,"POSE",{"peer":3,"pose":{"position":Vector3(3,0,0)}},false)
	if controller._tx.size()!=4: errors.append("Coalescing movement must preserve a separate latest pose for every actor sent to the same guest.")
	wire.busy = false
	controller._process(0.01)
	if wire.delivered!=[1,2]: errors.append("Reliable packets blocked by Steam must resume in their original revision order, exactly once.")
	controller.leave()
	for node in [controller,wire]: node.queue_free()
	await tree.process_frame
	return errors

func _shared_unlock_teardown(tree: SceneTree) -> Array[String]:
	var game := TeardownBoundary.new()
	game.tree = tree
	var wire: Node = load("res://tests/fixtures/pipe_transport.gd").new()
	var controller: Node = load("res://mods/ftn_coop/network_controller.gd").new()
	for node in [wire,controller]: tree.root.add_child(node)
	controller.configure(wire,game,"25963876","0.4.0")
	controller.host()
	await tree.process_frame
	controller._connections[2] = "guest"
	controller.leave()
	var errors: Array[String] = []
	if not game.inventory.owned_tools.has("spade"):
		errors.append("Ending hosting must preserve shared unlocks while remote actors drop their selected tools.")
	game.inventory.free()
	for node in [controller,wire]: node.queue_free()
	await tree.process_frame
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
		controller.configure(wire,game,"25963876","0.4.0")
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
		var departed: int = wires[2].local_peer_id()
		controllers[2].leave()
		await tree.create_timer(0.1).timeout
		if controllers[0].session.roster.size()!=3 or controllers[0].session.roster.has(departed):
			errors.append("A departing guest must release exactly its own slot over real sockets.")
		for index in [0,1,3]:
			if controllers[index].session.state!=controllers[index].session.State.PLAYING:
				errors.append("One guest leaving must keep the other three participants playing.")
		games[0].produce()
		controllers[0].world_sync.poll()
		controllers[2].join(1)
		if not await _await_playing(tree,[controllers[2]]):
			errors.append("A guest must be able to rejoin the same real-socket session.")
		await tree.create_timer(0.1).timeout
		if controllers[0].session.roster.size()!=4:
			errors.append("A rejoining guest must occupy one slot without retaining its old connection.")
		for index in [1,2,3]:
			if games[index].world!=games[0].world: errors.append("Rejoining must restore the host's latest shared world for every participant.")
		var disconnected: Array = []
		for index in [1,2,3]:
			controllers[index].problem.connect(func(code: String): disconnected.append(code))
		controllers[0].leave()
		await tree.create_timer(0.1).timeout
		if disconnected!=["HOST_LEFT","HOST_LEFT","HOST_LEFT"]:
			errors.append("Ending the host session must tell each of the three socket guests why it ended.")
		for index in [1,2,3]:
			if controllers[index].session.state!=controllers[index].session.State.OFFLINE or controllers[index].save_session.guest_open:
				errors.append("Host departure must close every temporary guest world and release its session.")
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
