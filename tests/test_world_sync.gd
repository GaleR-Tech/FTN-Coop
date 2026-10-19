extends RefCounted

func run(_tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/world_sync.gd"):
		return ["Host-authoritative world synchronization is not implemented yet."]
	var errors: Array[String] = []
	var module: Script = load("res://mods/ftn_coop/world_sync.gd")
	var adapter: RefCounted = load("res://tests/fixtures/fake_world_adapter.gd").new()
	var host: Node = module.new()
	host.configure(adapter, true)
	for peer in range(1,5): host.set_ready(peer,true)
	var events: Array = []
	host.confirmed.connect(func(event: Dictionary): events.append(event))
	if not host.submit_action(2,1,"purchase",{}).ok or host.submit_action(3,1,"purchase",{}).code != "INSUFFICIENT_FUNDS" or adapter.world.money != 0:
		errors.append("Concurrent purchases must be serialized against host funds.")
	if not host.submit_action(2,1,"purchase",{}).ok or events.size() != 1:
		errors.append("Repeating an action must return its result without applying it twice.")
	host.set_ready(2,false)
	host.set_ready(2,true)
	if not host.submit_action(2,1,"purchase",{}).ok or events.size()!=1:
		errors.append("World resynchronization must preserve action deduplication for an existing connection.")
	host.submit_action(2,2,"needle_collect",{"id":7})
	if host.submit_action(3,2,"needle_collect",{"id":7}).code != "ALREADY_COLLECTED" or adapter.world.needles.size() != 1:
		errors.append("A shared needle must be collected at most once.")
	if host.submit_action(8,1,"dig",{}).code != "PEER_NOT_READY": errors.append("Unknown participants must not change the world.")
	host.set_ready(4,false)
	if host.submit_action(4,1,"dig",{}).code != "PEER_NOT_READY": errors.append("Syncing participants must not change the world.")
	host.submit_action(2,3,"dig",{})
	host.submit_action(2,4,"place",{"id":"scanner"})
	adapter.produce()
	host.poll()
	host.poll()
	if events.size() != 5: errors.append("Host production and actions must each emit exactly one event.")
	for peer in range(2,5):
		var replica: RefCounted = load("res://tests/fixtures/fake_world_adapter.gd").new()
		replica.guest = true
		var client: Node = module.new()
		client.configure(replica,false)
		for event in events:
			if not client.accept_event(1,event).ok: errors.append("Ordered host events must be accepted.")
		replica.produce()
		if replica.world != adapter.world: errors.append("Three replicas must match the host without producing resources themselves.")
		if client.accept_event(1,events[-1]).code != "STALE_REVISION": errors.append("Duplicate host events must not apply twice.")
		if client.accept_event(2,{"revision":6}).code != "HOST_ONLY": errors.append("Guests must not confirm events.")
		if client.accept_event(1,{"revision":7}).code != "RESYNC_REQUIRED": errors.append("Missing revisions must require a fresh baseline.")
		client.free()
	host.free()
	return errors
