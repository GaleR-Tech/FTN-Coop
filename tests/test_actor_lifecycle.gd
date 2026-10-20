extends RefCounted

class Tool extends Node:
	var player: Node
	var props: Node
	var _held: Node3D
	var body: Node3D
	var basin: Area3D
	var world_root: Node
	var field: Node
	var live: Node
	func setup(p_world: Node, p_field: Node, p_live: Node, p_props: Node) -> void:
		world_root = p_world
		field = p_field
		live = p_live
		props = p_props
		body = Node3D.new()
		basin = Area3D.new()
		body.add_child(basin)
		p_world.add_child(body)

class Controller extends Node3D:
	var hand := Tool.new()
	var carry := Tool.new()
	var shovel := Tool.new()
	func _init() -> void:
		add_child(hand)
		add_child(carry)
		add_child(shovel)
		hand.player = self
		carry.player = self
		shovel.player = self

func run(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	var boundary: Script = load("res://tests/fixtures/actor_factory_boundary.gd")
	var world := Node3D.new()
	var player: Node3D = boundary.Player.new()
	world.add_child(player)
	tree.root.add_child(world)
	player.head.rotation.x = -0.7
	adapter.nodes = {"world":world,"player":player}
	adapter._actor_factory = boundary.new()
	if absf(adapter.read_local_pose().value.rotation.x+0.7)>0.0001:
		errors.append("Network look direction must include native head pitch, not just body rotation.")
	if adapter.read_local_pose().value.get("tool",-1)!=2:
		errors.append("A reliable actor pose must include the selected native tool.")
	var old_results: Array = []
	var new_results: Array = []
	_prepare(adapter,old_results)
	adapter.remove_actor(2)
	_prepare(adapter,new_results)
	await tree.process_frame
	await tree.process_frame
	if old_results.size()!=1 or old_results[0].code!="ACTOR_CANCELED":
		errors.append("Disconnecting during asynchronous actor creation must cancel the old actor.")
	if new_results.size()!=1 or not new_results[0].ok or world.get_child_count()!=2:
		errors.append("A returning peer must keep exactly its new controller, without an abandoned actor.")
	var actor: Node3D = adapter.actors[2]
	var before := actor.global_transform
	for tool in [99,1]:
		var rejected: Dictionary = adapter.update_actor_pose(2,{"position":Vector3(4,1,3),"rotation":Vector3(0.3,1,0),"tool":tool})
		if rejected.ok or actor.global_transform!=before: errors.append("A rejected tool pose must not partially move the actor or its held resources.")
	adapter.remove_actor(2)
	if actor.carried_load!=0: errors.append("Disconnect must release the active native tool before removing its controller from the tree.")
	await tree.process_frame
	world.free()
	var source := Controller.new()
	var remote := Controller.new()
	var props := Node.new()
	var held := Node3D.new()
	props.add_child(held)
	var tool_world := Node3D.new()
	tool_world.add_child(source)
	tool_world.add_child(remote)
	tree.root.add_child(tool_world)
	source.shovel.setup(tool_world,null,null,props)
	source.carry.props = props
	source.carry._held = held
	var factory: RefCounted = load("res://mods/ftn_coop/native_actor.gd").new()
	if not factory.bind_tools(remote,source).ok or remote.carry.player!=remote or remote.carry.props!=props:
		errors.append("A remote controller needs its own player references and the shared prop manager.")
	if remote.carry._held!=null or source.carry._held!=held:
		errors.append("Preparing a guest must never copy ownership of a tool already held by the host.")
	if remote.shovel.body==source.shovel.body or remote.shovel.basin==source.shovel.basin or remote.shovel.body==null:
		errors.append("Every player's shovel needs its own native body and hay basin, including world-parented tool nodes.")
	remote.free()
	await tree.process_frame
	if tool_world.get_child_count()!=2: errors.append("Removing a remote controller must also remove its generated world-parented tool body.")
	tool_world.free()
	props.free()
	return errors

func _prepare(adapter: RefCounted, results: Array) -> void:
	results.append(await adapter.prepare_actor(2))
