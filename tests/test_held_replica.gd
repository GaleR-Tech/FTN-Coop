extends RefCounted

class State extends Node:
	var money := 7.0
	func to_dict() -> Dictionary: return {"money":money}
	func from_dict(data: Dictionary) -> void: money = data.money

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/held_replica.gd"):
		return ["Held straw must reuse its already transmitted world poses instead of duplicating hundreds of transforms."]
	var errors: Array[String] = []
	var root := Node3D.new()
	tree.root.add_child(root)
	var fixtures: Script = load("res://tests/test_loose_sync.gd")
	var holders := {}
	var bodies := []
	for peer in [2,3,4]:
		var holder: Node3D = fixtures.Holder.new()
		root.add_child(holder)
		holders[peer] = holder
		var anchor: Node3D = holder.camera if peer==2 else holder.shovel.body if peer==3 else holder.pitchfork.body
		anchor.position = Vector3(peer*2,3,4)
		for index in range(24):
			var body := Node3D.new()
			root.add_child(body)
			body.global_position = anchor.global_position+Vector3(index*0.125,0.25,-0.5)
			body.rotation = Vector3(index*0.015625,index*0.03125,index*0.0078125)
			bodies.append(body)
			if peer==2: holder.hand.bodies.append(body)
			else: (holder.shovel if peer==3 else holder.pitchfork)._riding[body.get_instance_id()] = body
	var host: RefCounted = load("res://mods/ftn_coop/loose_sync.gd").new()
	var captured: Dictionary = host.capture_sources(bodies,[])
	var holds: Array = host.capture_holds(holders)
	var replica: RefCounted = load("res://mods/ftn_coop/held_replica.gd").new()
	var packed: Dictionary = replica.pack(holds,captured.value,host.hold_frames)
	if not packed.ok:
		root.free()
		return ["Real host hold capture must produce a compact, lossless owner/anchor representation."]
	var expanded: Dictionary = replica.expand(packed.value,captured.value)
	if not expanded.ok or expanded.value!=holds: errors.append("Compact held straw changed its owners, tools or exact offsets.")
	elif expanded.value[0].offset.origin!=Vector3(0,0.25,-0.5): errors.append("Hold reconstruction must use the owner's actual inverse hand frame.")
	var codec: RefCounted = load("res://mods/ftn_coop/value_codec.gd").new()
	if codec.encode(packed.value,1048576).value.size()>=codec.encode(holds,1048576).value.size()/4:
		errors.append("A loaded hand/shovel/fork must not retransmit their per-straw transforms.")
	var decoded: Dictionary = codec.decode(codec.encode(packed.value,1048576).value,1048576)
	var wire_restored: Dictionary = replica.expand(decoded.value,captured.value)
	if not wire_restored.ok or codec.encode(wire_restored.value,1048576).value!=codec.encode(holds,1048576).value:
		errors.append("Compact held straw must preserve bit-exact canonical data through the real wire codec.")
	var host_adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	host_adapter._loose = host
	var patch: Dictionary = host_adapter._difference({"loose":captured.value,"held_loose":[]},{"loose":captured.value,"held_loose":holds})
	if not patch.has("held_loose_links") or patch.has("held_loose"):
		errors.append("The actual live-world differ must use compact hold links for loaded tools.")
	var guest_adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	var guest: RefCounted = load("res://mods/ftn_coop/loose_sync.gd").new()
	guest.apply(captured.value,root)
	guest_adapter._loose = guest
	var state := State.new()
	root.add_child(state)
	guest_adapter.nodes = {"world":root,"state":state}
	guest_adapter.guest_mode = true
	if not guest_adapter.apply_confirmed_event({"patch":patch}).ok or guest.held!=holds:
		errors.append("The actual guest boundary must restore compact holds using the confirmed loose pool.")
	for body in bodies: body.position += Vector3(0.125,0.0625,0)
	var moved: Dictionary = host.capture_sources(bodies,[])
	var moved_holds: Array = host.capture_holds(holders)
	var combined: Dictionary = host_adapter._difference({"loose":captured.value,"held_loose":holds},{"loose":moved.value,"held_loose":moved_holds})
	var reordered := {"held_loose_links":combined.get("held_loose_links"),"loose_delta":combined.get("loose_delta")}
	if not guest_adapter.apply_confirmed_event({"patch":reordered}).ok or guest.current!=moved.value or guest.held!=moved_holds:
		errors.append("Compact holds must use the new loose poses in the same update, regardless of dictionary order.")
	captured = moved
	holds = moved_holds
	packed = replica.pack(holds,captured.value,host.hold_frames)
	for mutation in ["missing_id","duplicate_frame","wrong_tool","missing_frame","wrong_count","bad_matrix"]:
		var bad: Dictionary = packed.value.duplicate(true)
		match mutation:
			"missing_id": bad.ids[0] = 99999
			"duplicate_frame": bad.frames.append(bad.frames[0])
			"wrong_tool": bad.tools[0] = 9
			"missing_frame": bad.frames.pop_back()
			"wrong_count": bad.peers.resize(1)
			"bad_matrix": bad.frames[0].frame = Transform3D(Basis.IDENTITY,Vector3(INF,0,0))
		if replica.expand(bad,captured.value).ok: errors.append("Malformed held links accepted: "+mutation)
		if guest_adapter.apply_confirmed_event({"patch":{"state_delta":{"money":99.0},"held_loose_links":bad}}).ok or state.money!=7.0 or guest.held!=holds:
			errors.append("Invalid held links must reject the entire update before mutating any guest state: "+mutation)
	var conflicting := {"held_loose":holds,"held_loose_links":packed.value}
	if guest_adapter.apply_confirmed_event({"patch":conflicting}).ok: errors.append("Conflicting full and compact hold representations accepted.")
	for wrong_pool in [[],null]:
		for invalid in [{"held_loose_links":packed.value,"loose":wrong_pool},{"loose":wrong_pool,"held_loose_links":packed.value}]:
			if guest_adapter.apply_confirmed_event({"patch":invalid}).ok or guest.current!=captured.value or guest.held!=holds:
				errors.append("A malformed full loose pool must reject without a script error in either dictionary order.")
	if replica.pack(holds,captured.value,{}).ok: errors.append("Missing capture-time frames must retain the full hold fallback.")
	var fallback: Dictionary = host_adapter._difference({"held_loose":holds},{"held_loose":[]})
	if fallback!={"held_loose":[]} or not guest_adapter.apply_confirmed_event({"patch":fallback}).ok or not guest.held.is_empty():
		errors.append("Dropping the loaded straw must release every compact owner mapping and retain its world poses.")
	guest.close()
	root.free()
	return errors
