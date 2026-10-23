extends RefCounted

var held: Array = []
var initialized := false
var _records: Array = []
var _local_peer := 0
var _local_camera := Transform3D.IDENTITY

func apply_records(manager: Node, records: Array) -> void:
	var items: Variant = manager.get("items")
	# The native scene loader already restored the baseline bodies. Reuse them,
	# and append only new suffix records instead of instantiating a large world
	# again when one dropped/purchased object is added.
	var before: Array = _records if initialized else manager.call("to_array")
	var positions_only: bool = items is Array and items.size()==before.size()
	if positions_only:
		for index in range(mini(before.size(),records.size())):
			if not is_instance_valid(items[index]) or records[index].id!=before[index].id or records[index].state!=before[index].state:
				positions_only = false
				break
	if positions_only and records.size()>before.size() and not manager.has_method("spawn"): positions_only = false
	if positions_only and records.size()<before.size() and not manager.has_method("remove"): positions_only = false
	if positions_only:
		for index in range(mini(before.size(),records.size())): items[index].global_transform = records[index].xform
		for index in range(before.size(),records.size()):
			manager.call("spawn",records[index].id,records[index].xform,records[index].state)
		for index in range(before.size()-1,records.size()-1,-1): manager.call("remove",items[index])
		# The native from_array replaces the entire manager. Append through its
		# observed spawn API and retain a full restore if creation was refused.
		if manager.get("items").size()!=records.size():
			manager.call("clear")
			manager.call("from_array",records)
	else:
		if not _reconcile_records(manager,before,records):
			manager.call("clear")
			manager.call("from_array",records)
	_records = records.duplicate(true)
	initialized = true
	if _local_peer>0: follow_local(manager,_local_peer,_local_camera)

func _reconcile_records(manager: Node, before: Array, records: Array) -> bool:
	if not manager.has_method("spawn") or not manager.has_method("remove"): return false
	var items: Variant = manager.get("items")
	if not items is Array or items.size()!=before.size(): return false
	var old: Array = items.duplicate()
	var pools := {}
	for index in range(before.size()):
		if not is_instance_valid(old[index]): return false
		var key := str(before[index].id)+":"+str(hash(before[index].state))
		if not pools.has(key): pools[key] = []
		pools[key].append(index)
	var used := {}
	var desired := []
	for index in range(records.size()):
		var record: Dictionary = records[index]
		var chosen := -1
		if index<before.size() and not used.has(index) and before[index].id==record.id and before[index].state==record.state:
			chosen = index
		else:
			var key := str(record.id)+":"+str(hash(record.state))
			var candidates: Array = pools.get(key,[])
			while not candidates.is_empty():
				var candidate: int = candidates.pop_back()
				if not used.has(candidate) and before[candidate].id==record.id and before[candidate].state==record.state:
					chosen = candidate
					break
		var body: Variant
		if chosen>=0:
			body = old[chosen]
			used[chosen] = true
		else: body = manager.call("spawn",record.id,record.xform,record.state)
		if not body is Node3D or not is_instance_valid(body): return false
		body.global_transform = record.xform
		desired.append(body)
	for index in range(old.size()):
		if not used.has(index): manager.call("remove",old[index])
	items = manager.get("items")
	if not items is Array or items.size()!=desired.size(): return false
	# Wire indices identify held props; keep the native array in that exact order.
	items.assign(desired)
	return true

func accept_held(manager: Node, rows: Array) -> void:
	var items: Variant = manager.get("items")
	if items is Array:
		for previous in held:
			if previous.index<items.size() and previous.index<_records.size() and is_instance_valid(items[previous.index]):
				items[previous.index].global_transform = _records[previous.index].xform
	held = rows.duplicate(true)
	if _local_peer>0: follow_local(manager,_local_peer,_local_camera)

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
	_local_peer = peer
	_local_camera = camera
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
