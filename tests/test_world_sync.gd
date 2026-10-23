extends RefCounted

class NativeWorld extends Node:
	var missions: Node

class CapturingAdapter extends "res://mods/ftn_coop/game_adapter.gd":
	var captures := 0
	var native_count := 0
	var action_count := 0
	var refuse := false
	var fail_capture := false
	func _live_frame() -> Dictionary:
		captures += 1
		if fail_capture:
			last_sync_error = "WORLD_NOT_READY"
			return {}
		return {"state":{"native_count":native_count,"action_count":action_count}}
	func _perform_action(_actor: Node, _kind: String, _payload: Dictionary) -> Dictionary:
		if refuse: return _error("ACTION_REFUSED")
		action_count += 1
		return _ok()

func _native_capture_checks(tree: SceneTree, errors: Array[String]) -> void:
	var adapter := CapturingAdapter.new()
	var world := NativeWorld.new()
	var actor := Node.new()
	world.add_child(actor)
	tree.root.add_child(world)
	adapter.nodes = {"world":world}
	adapter.actors[2] = actor
	adapter._previous_frame = adapter._live_frame()
	adapter.captures = 0
	adapter.native_count = 1
	var sync: Node = load("res://mods/ftn_coop/world_sync.gd").new()
	sync.configure(adapter,true)
	sync.set_ready(2,true)
	var events := []
	sync.confirmed.connect(func(event: Dictionary): events.append(event))
	var result: Dictionary = sync.submit_action(2,1,"dig",{"pressed":true})
	if not result.ok or adapter.captures!=1 or events.size()!=1:
		errors.append("Native actions must capture and confirm one combined world change, not traverse a large factory twice")
	if result.ok and result.value.patch!={"state_delta":{"native_count":1,"action_count":1}}:
		errors.append("Combining native action capture lost automatic production or the guest action")
	var captures := adapter.captures
	sync.submit_action(2,1,"dig",{"pressed":true})
	if adapter.captures!=captures or adapter.action_count!=1: errors.append("Replayed native actions captured or modified the world twice")
	adapter.native_count = 2
	adapter.refuse = true
	if sync.submit_action(2,2,"dig",{"pressed":true}).ok: errors.append("Refused native action was accepted")
	sync.poll()
	if events[-1].patch!={"state_delta":{"native_count":2}}: errors.append("Refused action swallowed automatic world progress")
	adapter.refuse = false
	adapter.fail_capture = true
	var revision: int = sync.revision
	var failed: Dictionary = sync.submit_action(2,3,"dig",{"pressed":true})
	if failed.ok or failed.code!="WORLD_NOT_READY" or sync.revision!=revision:
		errors.append("Failed native world capture must not confirm an empty action patch")
	sync.free()
	world.free()

func run(_tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/world_sync.gd"):
		return ["Host-authoritative world synchronization is not implemented yet."]
	var errors: Array[String] = []
	_native_capture_checks(_tree,errors)
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
		if client.get("last_resync_reason")!="REVISION_GAP": errors.append("World recovery must retain the actual reason for an unexpected reload.")
		client.accept_baseline(7)
		if client.get("last_resync_reason")!="": errors.append("An accepted baseline must clear the old recovery reason.")
		client.free()
	host.free()
	return errors
