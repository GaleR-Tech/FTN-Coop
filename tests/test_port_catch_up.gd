extends RefCounted

class Adapter extends RefCounted:
	var _previous_frame := {"state":{"money":42},"heights":PackedFloat32Array([1]),"props":[],"buildings":[],"belts":{},"tech":{},"settings":{}}
	var applied := {}
	func _live_frame() -> Dictionary: return _previous_frame.duplicate(true)
	func poll_host_events() -> Array[Dictionary]: return []
	func apply_confirmed_event(event: Dictionary) -> Dictionary:
		applied = event.patch.duplicate(true)
		return {"ok":true,"code":"OK"}

func run(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var script: Script = load("res://mods/ftn_coop/network_controller.gd")
	var wire: Node = load("res://tests/fixtures/fake_transport.gd").new()
	var adapter := Adapter.new()
	var server: Node = script.new()
	tree.root.add_child(server);server.set_process(false)
	server.configure(wire,adapter,"25963876","0.7.0")
	server.session.is_host = true
	server.session.session_id = "0123456789abcdef0123456789abcdef"
	server.session.roster = {1:{"id":1,"name":"Server","role":"server","accepted":true,"state":"playing"},2:{"id":2,"name":"Guest","role":"player","accepted":true,"state":"syncing"}}
	server._connections[2] = "abcdef0123456789abcdef0123456789"
	server.world_sync.configure(adapter,true)
	server.world_sync.revision = 31
	var transfer: Node = load("res://mods/ftn_coop/snapshot_transfer.gd").new()
	server.add_child(transfer)
	transfer.begin({"mode":"world"},server.session.session_id,1)
	server._pending[2] = {"transfer":transfer,"revision":1,"age":0.0}
	var problems := []
	server.problem.connect(func(code: String): problems.append(code))
	var large := PackedByteArray();large.resize(600000)
	for revision in range(2,32): server._on_confirmed({"revision":revision,"kind":"native","patch":{"bytes":large}})
	if not problems.is_empty() or not transfer.buffered_events().is_empty(): errors.append("Loading peer accumulates unbounded native event history")
	server._finish_world(2,{"stage":"baseline","revision":1})
	if server.session.roster[2].state=="playing" or server.world_sync._ready_peers.has(2): errors.append("Server declares a guest playing before it has applied catch-up")
	var receiver: Node = load("res://mods/ftn_coop/snapshot_transfer.gd").new()
	receiver.configure(server.session.session_id)
	var states := []
	receiver.completed.connect(func(state: Dictionary, revision: int): states.append({"state":state,"revision":revision}))
	var protocol: RefCounted = load("res://mods/ftn_coop/protocol.gd").new()
	for packet in server._tx:
		var decoded: Dictionary = protocol.decode(packet.bytes)
		if decoded.ok and decoded.value.type in ["SNAPSHOT_BEGIN","SNAPSHOT_CHUNK"]: receiver.receive(1,decoded.value.body)
	if states.size()!=1 or states[0].state.get("mode")!="catch_up": errors.append("Loading completion does not send exactly one current-state catch-up")
	else:
		server._finish_world(2,{"stage":"playing","revision":states[0].revision-1})
		if server.session.roster[2].state=="playing": errors.append("Wrong catch-up acknowledgement unlocks gameplay")
		server._finish_world(2,{"stage":"playing","revision":states[0].revision})
		if server.session.roster[2].state!="playing" or not server.world_sync._ready_peers.has(2) or server._pending.has(2): errors.append("Valid final acknowledgement does not unlock and release the loading slot")
		var client: Node = script.new();tree.root.add_child(client);client.set_process(false)
		var guest_adapter := Adapter.new()
		client.configure(wire,guest_adapter,"25963876","0.7.0")
		client.session.state = client.session.State.SYNCING
		client._baseline_received = true
		client.world_sync.revision = 1
		client._on_snapshot_completed(states[0].state,states[0].revision)
		if guest_adapter.applied.get("state",{}).get("money")!=42 or client.world_sync.revision!=states[0].revision: errors.append("Catch-up does not apply the latest state/revision without reopening the world")
		client.session.session_id=server.session.session_id
		client.connection_id="abcdef0123456789abcdef0123456789"
		client.session.roster={1:{"id":1,"name":"Host","accepted":true,"state":"playing"},2:{"id":2,"name":"Guest","accepted":true,"state":"syncing"}}
		client.session.state_changed.connect(func():
			if client.session.state==client.session.State.PLAYING: client.request_action("dig",{"pressed":true})
		)
		var ready: Dictionary = protocol.encode({"protocol":1,"type":"WORLD_READY","session":client.session.session_id,"body":{"stage":"caught_up","revision":states[0].revision,"_connection":client.connection_id}})
		client._on_message(1,0,ready.value)
		var kinds := []
		for packet in client._tx: kinds.append(protocol.decode(packet.bytes).value.type)
		if kinds!=["WORLD_READY","ACTION"]: errors.append("Guest input can reach host before its final readiness acknowledgement")
		guest_adapter.applied.clear()
		client.session.state = client.session.State.PLAYING
		client._on_snapshot_completed(states[0].state,states[0].revision+2)
		if not guest_adapter.applied.is_empty(): errors.append("Playing client accepts an unsolicited baseline replacement")
		client.queue_free()
	receiver.free();server.queue_free()
	await tree.process_frame
	wire.free()
	return errors
