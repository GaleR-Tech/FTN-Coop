extends RefCounted

class Item extends Node3D:
	var item_id := "bucket"
	var data := {"stored":0}
	var carrier: Node

class Props extends Node:
	var items: Array[Node3D] = []
	func clear() -> void:
		for item in items: item.free()
		items.clear()
	func from_array(records: Array) -> void:
		for record in records:
			var item := Item.new()
			item.item_id = record.id
			item.data = record.state.duplicate(true)
			add_child(item)
			item.global_transform = record.xform
			items.append(item)
	func to_array() -> Array:
		var result := []
		for item in items: result.append({"id":item.item_id,"state":item.data.duplicate(true),"xform":item.global_transform})
		return result

class Player extends Node3D:
	var camera := Camera3D.new()
	func _init() -> void: add_child(camera)

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/prop_replica.gd"): return ["Moving replicated props must retain their native bodies."]
	var module: RefCounted = load("res://mods/ftn_coop/prop_replica.gd").new()
	var props := Props.new()
	var player := Player.new()
	tree.root.add_child(props)
	tree.root.add_child(player)
	var errors: Array[String] = []
	var records := [{"id":"bucket","state":{"stored":0},"xform":Transform3D(Basis.IDENTITY,Vector3(1,2,3))}]
	module.apply_records(props,records)
	var original: Node3D = props.items[0]
	records[0].xform.origin = Vector3(4,2,3)
	module.apply_records(props,records)
	if props.items[0]!=original or original.global_position!=Vector3(4,2,3): errors.append("A position-only network update must move the existing prop instead of rebuilding it.")
	original.carrier = player
	var held: Array = module.capture_held(props,{2:player})
	if held.size()!=1 or held[0].peer!=2 or held[0].index!=0: errors.append("Held props need the native carrier's peer and item index.")
	module.held = held
	var camera := player.camera.global_transform
	camera.origin += Vector3(10,0,0)
	module.follow_local(props,2,camera)
	if original.global_position!=Vector3(14,2,3): errors.append("A guest's carried prop must follow its local camera between network updates.")
	module.follow_local(props,3,Transform3D.IDENTITY)
	if original.global_position!=Vector3(14,2,3): errors.append("Local rendering must not move another peer's carried item.")
	var view: Array = module.authoritative_view(props)
	if view.size()!=1 or view[0].xform.origin!=Vector3(4,2,3): errors.append("Prediction must preserve the last authoritative transform for shared-state comparisons.")
	if module.validate_held([{"index":1,"peer":2,"offset":Transform3D.IDENTITY}],1): errors.append("Held metadata must not refer to an absent prop.")
	records[0].state.stored = 3
	module.apply_records(props,records)
	if props.items[0].data.stored!=3: errors.append("Actual native prop state changes must still be restored.")
	props.free()
	player.free()
	return errors
