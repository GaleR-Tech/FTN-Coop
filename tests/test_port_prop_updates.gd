extends RefCounted

class Item extends Node3D:
	var id := "bucket"
	var state := {"stored":0}

class Props extends Node:
	var items: Array = []
	var clears := 0
	var created := 0
	func clear() -> void:
		clears += 1
		for item in items: item.free()
		items.clear()
	func from_array(rows: Array) -> void:
		clear()
		for row in rows:
			spawn(row.id,row.xform,row.state)
	func spawn(id: String,xform:Transform3D,state:Dictionary) -> Node3D:
		var item := Item.new();item.id=id;item.state=state.duplicate(true)
		add_child(item);item.global_transform=xform;items.append(item);created+=1
		return item
	func remove(item: Node3D) -> void: items.erase(item);item.free()
	func to_array() -> Array:
		var rows := []
		for item in items: rows.append({"id":item.id,"state":item.state.duplicate(true),"xform":item.global_transform})
		return rows

func run(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var props := Props.new();tree.root.add_child(props)
	var rows := []
	for index in range(600): rows.append({"id":"bucket","state":{"stored":0},"xform":Transform3D(Basis.IDENTITY,Vector3(index,0,0))})
	props.from_array(rows)
	props.clears = 0
	var original: Node3D = props.items[0]
	var module: RefCounted = load("res://mods/ftn_coop/prop_replica.gd").new()
	module.apply_records(props,rows)
	if props.clears!=0 or props.created!=600 or props.items[0]!=original: errors.append("Initial baseline rebuilds 600 props that the native loader already created")
	original = props.items[0]
	rows.append({"id":"bucket","state":{"stored":0},"xform":Transform3D.IDENTITY})
	module.apply_records(props,rows)
	if props.clears!=0 or props.created!=601 or props.items[0]!=original or props.items.size()!=601: errors.append("Appending one prop rebuilds the existing large world")
	rows.pop_back()
	module.apply_records(props,rows)
	if props.clears!=0 or props.items[0]!=original or props.items.size()!=600: errors.append("Removing a suffix prop rebuilds the large world")
	rows[300].state.stored = 1
	module.apply_records(props,rows)
	if props.clears!=0 or props.created!=602 or props.items[0]!=original or props.items[300].state.stored!=1: errors.append("One changed prop state rebuilds the other 599 native bodies")
	rows[400] = {"id":"spade","state":{"tool":"spade"},"xform":Transform3D.IDENTITY}
	module.apply_records(props,rows)
	var spade: Node3D = props.items[400]
	rows.push_front(rows.pop_at(400))
	module.apply_records(props,rows)
	if props.clears!=0 or props.created!=603 or props.items[0]!=spade: errors.append("Reordering props rebuilds matching native bodies")
	rows.remove_at(200)
	module.apply_records(props,rows)
	if props.clears!=0 or props.created!=603 or props.items.size()!=599 or props.items[0]!=spade: errors.append("Deleting a middle prop rebuilds the large world")
	props.free()
	return errors
