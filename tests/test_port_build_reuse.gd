extends RefCounted

class Builds extends Node3D:
	var robotic_arms := []
	var generators := []
	var hay_lifts := []
	var hay_stairs := []
	var restore_slice_usec := 1000
	var rows := [{"type":"conveyor","a":Vector3.ZERO,"b":Vector3(10,0,0),"paid":120.0}]
	var clears := 0
	func to_array() -> Array: return rows.duplicate(true)
	func clear() -> void: clears+=1;rows.clear()
	func from_array(value: Array) -> void: rows=value.duplicate(true)

class Generator extends Node3D:
	var fuel := 10.0

func run(tree: SceneTree) -> Array[String]:
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	if not adapter.has_method("apply_guest_buildings"): return ["Full baseline rebuilds unchanged native buildings"]
	var errors: Array[String] = []
	var world := Node.new();tree.root.add_child(world)
	var builds := Builds.new();world.add_child(builds)
	adapter.nodes = {"world":world,"builds":builds}
	var rows: Array = builds.to_array()
	adapter.apply_guest_buildings(rows)
	adapter.apply_guest_buildings(rows)
	if builds.clears!=0: errors.append("Native baseline or catch-up rebuilds unchanged geometry")
	rows.append({"type":"conveyor","a":Vector3(10,0,0),"b":Vector3(20,0,0),"paid":120.0})
	adapter.apply_guest_buildings(rows)
	if builds.clears!=1 or builds.rows.size()!=2: errors.append("Changed building geometry was not restored")
	adapter.apply_guest_buildings(rows)
	if builds.clears!=1: errors.append("Repeated catch-up rebuilt the current geometry")
	var generator := Generator.new();builds.add_child(generator);generator.position=Vector3(2,0,2)
	builds.generators.append(generator)
	rows.append({"type":"hay_generator","position":generator.position,"yaw":0.0,"paid":10.0,"off":false,"port_reach":0.38,"fuel":10.0})
	adapter.apply_guest_buildings(rows)
	var clears := builds.clears
	rows[-1].fuel=9.0
	adapter.apply_guest_buildings(rows)
	if builds.clears!=clears: errors.append("Running machine state rebuilds unchanged building geometry")
	if generator.fuel!=9.0: errors.append("Native machine inventory was not updated")
	var replica: RefCounted = load("res://mods/ftn_coop/building_replica.gd").new()
	if not replica.has_method("difference") or not replica.has_method("expand"):
		errors.append("Running updates still transmit every unchanged building")
	else:
		var before: Array = rows.duplicate(true)
		rows[-1].fuel=8.0
		var delta: Dictionary = replica.difference(before,rows)
		if delta.rows.size()!=1 or delta.rows[0].index!=2: errors.append("Building delta includes unchanged records")
		if not replica.expand(before,delta).ok or replica.expand(before,delta).value!=rows: errors.append("Building delta does not restore exact records")
		for invalid in [{"count":1,"rows":[]},{"count":3,"rows":[{"index":3,"record":{}}]},{"count":3,"rows":[{"index":2,"record":{}},{"index":2,"record":{}}]}]:
			if replica.expand(before,invalid).ok: errors.append("Invalid building delta accepted")
		var patch: Dictionary = adapter._difference({"buildings":before},{"buildings":rows})
		if patch.has("buildings") or not patch.has("buildings_delta"): errors.append("Adapter does not use bounded building deltas")
		adapter.guest_mode=true
		if not adapter.apply_confirmed_event({"patch":patch}).ok or generator.fuel!=8.0: errors.append("Guest did not apply exact native building delta")
		if adapter.apply_confirmed_event({"patch":{"buildings_delta":{"count":1,"rows":[]}}}).ok or generator.fuel!=8.0: errors.append("Invalid delta mutated the guest")
	var checker: Node = load("res://mods/ftn_coop/native_network_check.gd").new()
	checker._adapter = adapter
	if not checker.has_method("_native_building_values"):
		errors.append("Native proof compares cached wire buildings instead of native machine values")
	else:
		# The receive cache says fuel8 while the actual native capture still says10.
		var actual: Array = rows.duplicate(true)
		actual[-1].fuel = 10.0
		builds.rows = actual
		if checker._native_building_values(rows).ok: errors.append("Native proof trusted received cache over stale native inventory")
		builds.rows = rows.duplicate(true)
		if not checker._native_building_values(rows).ok: errors.append("Native proof rejected exact actual machine inventory")
	checker.free()
	world.free()
	return errors
