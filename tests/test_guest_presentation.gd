extends RefCounted

class World extends Node3D:
	var _built := true
	var block_save := false

class Saves extends Node:
	var block_save := false

class Field extends Node:
	func tick_lod(_eye: Vector3) -> void: pass

class Player extends CharacterBody3D:
	var camera := Camera3D.new()
	var current_tool := 0
	func _init() -> void: add_child(camera)

func run(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var visual_script := _script("res://scripts/build/belt_batch.gd")
	var structure_script := _script("res://scripts/build/structure_cull.gd")
	var shadow_script := _script("res://scripts/world/shadow_lod.gd")
	var machine_script := _script("res://scripts/build/robotic_arm.gd")
	var machine_lod := GDScript.new()
	machine_lod.source_code = "extends Node\nstatic var eye := Vector3.INF\nstatic func tick(value: Vector3) -> void: eye = value\n"
	assert(machine_lod.reload()==OK)
	machine_lod.resource_path = "res://scripts/world/machine_lod.gd"
	var world := World.new()
	tree.root.add_child(world)
	var visuals: Node = visual_script.new()
	var structure: Node = structure_script.new()
	var shadows: Node = shadow_script.new()
	var machine: Node = machine_script.new()
	var stopped: Node = visual_script.new()
	stopped.process_mode = Node.PROCESS_MODE_DISABLED
	for node in [visuals,structure,shadows,machine,stopped]: world.add_child(node)
	var saves := Saves.new()
	world.add_child(saves)
	var field := Field.new()
	world.add_child(field)
	var player := Player.new()
	world.add_child(player)
	player.camera.position = Vector3(2,3,4)
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	adapter.nodes = {"world":world,"saves":saves,"field":field,"player":player}
	adapter.set_guest_mode(true)
	adapter.set_guest_mode(true)
	await tree.process_frame
	await tree.process_frame
	if visuals.calls==0 or structure.calls==0:
		errors.append("Guest belt/structure presentation must continue while authoritative world simulation is disabled.")
	if machine.calls!=0 or stopped.calls!=0:
		errors.append("Guest presentation must not restart machines or intentionally disabled draw nodes.")
	adapter.pump_guest_visuals()
	if shadows.eye!=Vector3(2,3,4): errors.append("Guest shadow visibility must follow that guest's own camera.")
	if machine_lod.get("eye")!=Vector3(2,3,4): errors.append("The native static MachineLOD utility must follow the guest camera without a descendant instance.")
	var added: Node = visual_script.new()
	world.add_child(added)
	await tree.process_frame
	await tree.process_frame
	if added.calls==0: errors.append("Presentation nodes created after joining must receive the same guest process scope.")
	adapter.set_guest_mode(false)
	machine_lod.set("eye",Vector3.INF)
	adapter.pump_guest_visuals()
	if machine_lod.get("eye")!=Vector3.INF: errors.append("Leaving guest mode must stop manually ticking static visibility utilities.")
	for node in [visuals,structure,shadows,added]:
		if node.process_mode!=Node.PROCESS_MODE_INHERIT: errors.append("Leaving guest mode must restore each presentation node's original process mode.")
	if stopped.process_mode!=Node.PROCESS_MODE_DISABLED: errors.append("Leaving guest mode changed an originally disabled draw node.")
	world.free()
	# Release the synthetic native paths before another suite loads resources.
	for script in [visual_script,structure_script,shadow_script,machine_script,machine_lod]: script.resource_path = ""
	return errors

func _script(path: String) -> Script:
	var result := GDScript.new()
	result.source_code = "extends Node\nvar calls := 0\nvar eye := Vector3.INF\nfunc _process(_delta: float) -> void: calls += 1\nfunc tick(value: Vector3) -> void: eye = value\n"
	assert(result.reload()==OK)
	result.resource_path = path
	return result
