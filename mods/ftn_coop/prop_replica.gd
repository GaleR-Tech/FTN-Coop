extends RefCounted

var held: Array = []
var initialized := false
var _records: Array = []

func apply_records(manager: Node, records: Array) -> void:
	var items: Variant = manager.get("items")
	var positions_only: bool = items is Array and initialized and records.size()==_records.size() and items.size()==records.size()
	if positions_only:
		for index in range(records.size()):
			if not is_instance_valid(items[index]) or records[index].id!=_records[index].id or records[index].state!=_records[index].state:
				positions_only = false
				break
	if positions_only:
		for index in range(records.size()): items[index].global_transform = records[index].xform
	else:
		manager.call("clear")
		manager.call("from_array",records)
	_records = records.duplicate(true)
	initialized = true

func capture_held(manager: Node, players: Dictionary) -> Array:
	var result := []
	var items: Variant = manager.get("items")
	if not items is Array: return result
	for index in range(items.size()):
		var body: Node3D = items[index]
		if not is_instance_valid(body) or not body.is_inside_tree(): continue
		var carrier: Variant = body.get("carrier")
		if not carrier is Node: continue
		for peer in players:
			var player: Node = players[peer]
			if not is_instance_valid(player) or carrier!=player: continue
			var camera: Variant = player.get("camera")
			if camera is Node3D and camera.is_inside_tree():
				result.append({"index":index,"peer":int(peer),"offset":camera.global_transform.affine_inverse()*body.global_transform})
			break
	return result

func validate_held(rows: Variant, count: int) -> bool:
	if not rows is Array or rows.size()>count: return false
	var previous := -1
	for row in rows:
		if not row is Dictionary or row.size()!=3 or typeof(row.get("index"))!=TYPE_INT or typeof(row.get("peer"))!=TYPE_INT or not row.get("offset") is Transform3D: return false
		if row.index<=previous or row.index>=count or row.peer<1 or row.peer>2147483647: return false
		previous = row.index
		var transform: Transform3D = row.offset
		if not transform.origin.is_finite() or transform.origin.length()>32.0: return false
		for column in [transform.basis.x,transform.basis.y,transform.basis.z]:
			if not column.is_finite() or column.length()>16.0: return false
	return true

func follow_local(manager: Node, peer: int, camera: Transform3D) -> void:
	var items: Variant = manager.get("items")
	if not items is Array: return
	for row in held:
		if row.peer!=peer or row.index>=items.size(): continue
		var body: Node3D = items[row.index]
		if is_instance_valid(body) and body.is_inside_tree(): body.global_transform = camera*row.offset

func authoritative_view(manager: Node) -> Array:
	var records: Array = manager.call("to_array")
	if records.size()!=_records.size(): return []
	for index in range(records.size()):
		if records[index].id!=_records[index].id: return []
		records[index].xform = _records[index].xform
	return records
