extends RefCounted

class Props extends Node3D:
	var items: Array = []
	func spawn() -> Node3D:
		var body := Node3D.new();add_child(body);items.append(body)
		var model := MeshInstance3D.new();model.mesh=BoxMesh.new();body.add_child(model)
		return body
	func remove(body: Node3D) -> void: items.erase(body);body.free()

class Saves extends Node:
	var _pending_belts := {}

class World extends Node3D:
	var props: Props
	var restores := 0
	func _restore_belts() -> void:
		restores+=1
		props.spawn();props.spawn()

func run(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var world := World.new();tree.root.add_child(world)
	var props := Props.new();world.add_child(props);world.props=props
	var original := props.spawn()
	var saves := Saves.new();world.add_child(saves)
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	adapter.nodes={"world":world,"props":props,"saves":saves}
	adapter.guest_mode=true;adapter._guest_belts_ready=true
	adapter._guest_belts_world=world.get_instance_id();adapter._belts_epoch=1
	adapter._render_belts(world.get_instance_id(),1)
	if props.items.size()!=1 or props.items[0]!=original: errors.append("Guest belt rendering adds non-authoritative world props")
	if not adapter.get("_guest_belt_spills") is Node or adapter.get("_guest_belt_spills").get_child_count()!=2:
		errors.append("Native fallback cargo has no separate render-only representation")
	adapter._render_belts(world.get_instance_id(),1)
	if props.items.size()!=1: errors.append("Repeated belt rendering duplicates native props")
	if adapter.get("_guest_belt_spills") is Node and adapter.get("_guest_belt_spills").get_child_count()!=2: errors.append("Old fallback visuals accumulate")
	adapter.guest_mode=false
	adapter._render_belts(world.get_instance_id(),1)
	if world.restores!=2 or props.items.size()!=1: errors.append("Belt presentation guard changed a host world")
	world.free()
	return errors
