extends RefCounted

class Saves extends Node:
	var block_save := false

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/guest_movement.gd"): return ["Isolated guest movement is not implemented yet."]
	var errors: Array[String] = []
	var world := Node3D.new()
	tree.root.add_child(world)
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30,1,30)
	ground_shape.shape = box
	ground.add_child(ground_shape)
	ground.position.y = -0.5
	world.add_child(ground)
	var player := CharacterBody3D.new()
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.3
	body_shape.shape = capsule
	body_shape.position.y = 0.9
	player.add_child(body_shape)
	world.add_child(player)
	player.position.y = 0.2
	var saves := Saves.new()
	world.add_child(saves)
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	adapter.nodes = {"world":world,"player":player,"saves":saves}
	adapter.set_guest_mode(true)
	var mover: Node = load("res://mods/ftn_coop/guest_movement.gd").new()
	tree.root.add_child(mover)
	mover.configure(adapter)
	mover.enabled = true
	# Drive actual Godot physics with native gameplay processing disabled.
	for frame in range(45):
		await tree.physics_frame
		mover.step(1.0/60.0,Vector2(0,-1),false)
	if player.position.z>-1.0 or player.position.y < -0.1: errors.append("The guest must walk and stay on disabled-world collision geometry.")
	var late_body := StaticBody3D.new()
	world.add_child(late_body)
	if late_body.disable_mode!=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE: errors.append("Late restored static building colliders must remain usable by the guest.")
	mover.enabled = false
	var stopped := player.position
	mover.step(1.0,Vector2(1,0),true)
	if player.position!=stopped: errors.append("Loading and menu state must stop guest movement.")
	adapter.set_guest_mode(false)
	if ground.disable_mode!=CollisionObject3D.DISABLE_MODE_REMOVE: errors.append("Closing guest mode must restore original collider behavior.")
	mover.queue_free()
	world.queue_free()
	await tree.process_frame
	return errors
