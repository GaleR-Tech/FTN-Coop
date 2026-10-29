extends RefCounted

const LIMIT := 8192
var current := {"ids":PackedInt32Array(),"kinds":PackedByteArray(),"poses":PackedFloat32Array(),"colors":PackedColorArray()}
var _ids: Dictionary = {}
var _next_id := 1
var native_omissions := 0
var last_native_omission := {}
var _root: Node3D
var _hay: MultiMesh
var _needles: MultiMesh
var _native_mesh: Mesh
var _native_material: Material
var held: Array = []
var hold_frames := {}
var _draw_slots: Dictionary = {}
var _local_peer := 0
var _local_player: WeakRef

func capture_holds(players: Dictionary) -> Array:
	hold_frames.clear()
	var rows := []
	for peer in players:
		var player: Node = players[peer]
		if not is_instance_valid(player): continue
		var hand: Variant = player.get("hand")
		var camera: Variant = player.get("camera")
		if hand is Node and hand.has_method("held_bodies") and camera is Node3D:
			var frame: Transform3D = camera.global_transform.affine_inverse()
			hold_frames[Vector2i(int(peer),0)] = frame
			for body in hand.call("held_bodies"):
				if is_instance_valid(body) and body is Node3D and _ids.has(body):
					rows.append({"id":_ids[body],"peer":int(peer),"tool":0,"offset":frame*body.global_transform})
		for role in ["shovel","pitchfork"]:
			var tool: Variant = player.get(role)
			if not tool is Node or not tool.get("_riding") is Dictionary or not tool.get("body") is Node3D: continue
			var frame: Transform3D = tool.get("body").global_transform.affine_inverse()
			hold_frames[Vector2i(int(peer),1 if role=="shovel" else 2)] = frame
			for body in tool.get("_riding").values():
				if is_instance_valid(body) and body is Node3D and _ids.has(body):
					rows.append({"id":_ids[body],"peer":int(peer),"tool":1 if role=="shovel" else 2,"offset":frame*body.global_transform})
	rows.sort_custom(func(a: Dictionary,b: Dictionary): return a.id<b.id)
	return rows

func validate_holds(rows: Variant, ids: PackedInt32Array) -> bool:
	if not rows is Array or rows.size()>LIMIT: return false
	var known := {}
	for id in ids: known[id] = true
	var previous := 0
	for row in rows:
		if not row is Dictionary or row.size()!=4 or typeof(row.get("id"))!=TYPE_INT or row.id<=previous or not known.has(row.id): return false
		if typeof(row.get("peer"))!=TYPE_INT or row.peer<1 or row.peer>2147483647 or typeof(row.get("tool"))!=TYPE_INT or row.tool not in [0,1,2] or not row.get("offset") is Transform3D: return false
		previous = row.id
		var offset: Transform3D = row.offset
		if not offset.origin.is_finite() or offset.origin.length()>32.0: return false
		for column in [offset.basis.x,offset.basis.y,offset.basis.z]:
			if not column.is_finite() or column.length()>16.0: return false
	return true

func follow_local(peer: int, player: Node) -> void:
	if not is_instance_valid(player): return
	_local_peer = peer
	_local_player = weakref(player)
	for row in held:
		if row.peer!=peer or not _draw_slots.has(row.id): continue
		var anchor: Variant = player.get("camera")
		if row.tool!=0:
			var tool: Variant = player.get("shovel" if row.tool==1 else "pitchfork")
			anchor = tool.get("body") if tool is Node else null
		if not anchor is Node3D: continue
		var slot: Dictionary = _draw_slots[row.id]
		var batch: MultiMesh = _hay if slot.kind==0 else _needles
		batch.set_instance_transform(slot.index,anchor.global_transform*row.offset)

func _refresh_local() -> void:
	if _local_player!=null and is_instance_valid(_local_player.get_ref()): follow_local(_local_peer,_local_player.get_ref())

func accept_holds(rows: Array) -> bool:
	if not validate_holds(rows,current.ids): return false
	var owners := {}
	for row in rows: owners[row.id] = Vector2i(row.peer,row.tool)
	var offsets := _offsets(current)
	for previous in held:
		if owners.get(previous.id)==Vector2i(previous.peer,previous.tool) or not _draw_slots.has(previous.id): continue
		var slot: Dictionary = _draw_slots[previous.id]
		var batch: MultiMesh = _hay if slot.kind==0 else _needles
		batch.set_instance_transform(slot.index,_transform(current.poses,offsets[previous.id]))
	held = rows.duplicate(true)
	_refresh_local()
	return true

func use_native_visuals(source: Node) -> void:
	if not is_instance_valid(source): return
	var instance: Variant = source.get("_mmi")
	if not instance is MultiMeshInstance3D or instance.multimesh==null or instance.multimesh.mesh==null: return
	_native_mesh = instance.multimesh.mesh
	_native_material = instance.material_override
	if is_instance_valid(_root):
		_hay.mesh = _native_mesh
		_root.get_child(0).material_override = _native_material

func capture_sources(hay: Array, needles: Array) -> Dictionary:
	if hay.size()+needles.size()>LIMIT: return _error("LOOSE_LIMIT")
	var records := {}
	var seen := {}
	for kind in range(2):
		for body in hay if kind == 0 else needles:
			if not is_instance_valid(body) or not body is Node3D or not body.is_inside_tree(): continue
			var pose: Transform3D = body.global_transform
			var tint: Variant = body.get_meta("tint",Color.WHITE) if kind==0 else Color.WHITE
			var rejected := _native_rejection(pose,tint)
			if not rejected.is_empty():
				# Native transient/falling/fading bodies are not wire input. Omit an
				# unrepresentable body without mutating it or ending everyone's game.
				native_omissions+=1
				last_native_omission={"reason":rejected,"kind":kind,"position":pose.origin,"basis":pose.basis,"tint_type":typeof(tint),"tint":tint if tint is Color else null}
				continue
			if not _ids.has(body):
				if _next_id >= 2147483647: return _error("LOOSE_LIMIT")
				_ids[body] = _next_id
				_next_id += 1
			seen[body] = true
			records[_ids[body]] = {"kind":kind,"transform":pose,"color":tint}
	for body in _ids.keys():
		if not is_instance_valid(body) or not seen.has(body): _ids.erase(body)
	var ids := PackedInt32Array()
	var kinds := PackedByteArray()
	var poses := PackedFloat32Array()
	var colors := PackedColorArray()
	var ordered := records.keys()
	ordered.sort()
	for id in ordered:
		ids.append(id)
		kinds.append(records[id].kind)
		if not records[id].color is Color: return _error("LOOSE_INVALID")
		colors.append(records[id].color)
		var transform: Transform3D = records[id].transform
		for vector in [transform.basis.x,transform.basis.y,transform.basis.z,transform.origin]:
			poses.append_array(PackedFloat32Array([vector.x,vector.y,vector.z]))
	var data := {"ids":ids,"kinds":kinds,"poses":poses,"colors":colors}
	if not validate(data): return _error("LOOSE_INVALID")
	return _ok(data)

func _native_rejection(pose: Transform3D, tint: Variant) -> String:
	if not tint is Color: return "TINT_TYPE"
	for channel in [tint.r,tint.g,tint.b,tint.a]:
		if not is_finite(channel) or channel<0.0 or channel>4.0: return "TINT_RANGE"
	for axis in [pose.basis.x,pose.basis.y,pose.basis.z]:
		if not axis.is_finite() or maxf(absf(axis.x),maxf(absf(axis.y),absf(axis.z)))>8.0: return "BASIS_RANGE"
	if not pose.origin.is_finite() or maxf(absf(pose.origin.x),maxf(absf(pose.origin.y),absf(pose.origin.z)))>2048.0: return "POSITION_RANGE"
	return ""

func validate(data: Dictionary) -> bool:
	if data.size() not in [3,4] or not data.get("ids") is PackedInt32Array or not data.get("kinds") is PackedByteArray or not data.get("poses") is PackedFloat32Array: return false
	var size: int = data.ids.size()
	if size>LIMIT or data.kinds.size()!=size or data.poses.size()!=12*size: return false
	if data.size()==4 and (not data.get("colors") is PackedColorArray or data.colors.size()!=size): return false
	var previous := 0
	for index in range(size):
		if data.ids[index]<=previous or data.kinds[index]>1: return false
		previous = data.ids[index]
		if data.has("colors"):
			var tint: Color = data.colors[index]
			for channel in [tint.r,tint.g,tint.b,tint.a]:
				if not is_finite(channel) or channel<0.0 or channel>4.0: return false
		for component in range(12):
			var value: float = data.poses[index*12+component]
			if not is_finite(value) or absf(value)>(8.0 if component<9 else 2048.0): return false
	return true

func difference(before: Dictionary, after: Dictionary) -> Dictionary:
	var old := _offsets(before)
	var keep := _offsets(after)
	var changed := PackedInt32Array()
	var removed := PackedInt32Array()
	for id in old:
		if not keep.has(id): removed.append(id)
	for index in range(after.ids.size()):
		var id: int = after.ids[index]
		var previous: int = old.get(id,-1)
		if previous<0 or before.kinds[previous]!=after.kinds[index] or _tint(before,previous)!=_tint(after,index):
			changed.append(index)
			continue
		if before.poses.slice(previous*12,previous*12+12)!=after.poses.slice(index*12,index*12+12): changed.append(index)
	return {"removed":removed,"updated":_select(after,changed)}

func validate_delta(delta: Dictionary) -> bool:
	if delta.size()!=2 or not delta.get("removed") is PackedInt32Array or not delta.get("updated") is Dictionary or not validate(delta.updated): return false
	if delta.removed.size()>LIMIT: return false
	var old := _offsets(current)
	var updates := _offsets(delta.updated)
	var previous := 0
	for id in delta.removed:
		if id<=previous or not old.has(id) or updates.has(id): return false
		previous = id
		old.erase(id)
	for id in updates: old[id] = true
	return old.size()<=LIMIT

func next_ids(delta: Dictionary) -> PackedInt32Array:
	var ids := _offsets(current)
	for id in delta.removed: ids.erase(id)
	for id in delta.updated.ids: ids[id] = true
	var ordered := ids.keys()
	ordered.sort()
	return PackedInt32Array(ordered)

func merge_delta(delta: Dictionary) -> Dictionary:
	if not validate_delta(delta): return _error("LOOSE_INVALID")
	var old := _offsets(current)
	var updates := _offsets(delta.updated)
	for id in delta.removed: old.erase(id)
	var ids := old.keys()
	for id in updates:
		if not old.has(id): ids.append(id)
	if ids.size()>LIMIT: return _error("LOOSE_INVALID")
	ids.sort()
	var result := {"ids":PackedInt32Array(),"kinds":PackedByteArray(),"poses":PackedFloat32Array(),"colors":PackedColorArray()}
	for id in ids:
		var source: Dictionary = delta.updated if updates.has(id) else current
		var index: int = updates[id] if updates.has(id) else old[id]
		_append(result,source,index)
	return _ok(result)

func apply_delta(delta: Dictionary, parent: Node) -> Dictionary:
	if not validate_delta(delta): return _error("LOOSE_INVALID")
	var old := _offsets(current)
	var updates: Dictionary = delta.updated
	var stable: bool = delta.removed.is_empty() and is_instance_valid(_root)
	for index in range(updates.ids.size()):
		var id: int = updates.ids[index]
		if not old.has(id) or current.kinds[old[id]]!=updates.kinds[index]:
			stable = false
			break
	if stable:
		var data := current.duplicate(true)
		if not data.has("colors"):
			data.colors = PackedColorArray()
			data.colors.resize(data.ids.size())
			data.colors.fill(Color.WHITE)
		for index in range(updates.ids.size()):
			var id: int = updates.ids[index]
			var at: int = old[id]
			for component in range(12): data.poses[at*12+component] = updates.poses[index*12+component]
			data.colors[at] = _tint(updates,index)
			var slot: Dictionary = _draw_slots[id]
			var batch: MultiMesh = _hay if slot.kind==0 else _needles
			batch.set_instance_transform(slot.index,_transform(updates.poses,index))
			batch.set_instance_color(slot.index,data.colors[at])
		current = data
		_refresh_local()
		return _ok()
	var merged := merge_delta(delta)
	return apply(merged.value,parent) if merged.ok else merged

func _transform(poses: PackedFloat32Array, index: int) -> Transform3D:
	var at := index*12
	return Transform3D(Basis(Vector3(poses[at],poses[at+1],poses[at+2]),Vector3(poses[at+3],poses[at+4],poses[at+5]),Vector3(poses[at+6],poses[at+7],poses[at+8])),Vector3(poses[at+9],poses[at+10],poses[at+11]))

func _offsets(data: Dictionary) -> Dictionary:
	var result := {}
	for index in range(data.ids.size()): result[data.ids[index]] = index
	return result

func _tint(data: Dictionary, index: int) -> Color:
	return data.colors[index] if data.has("colors") else Color.WHITE

func _select(data: Dictionary, indices: PackedInt32Array) -> Dictionary:
	var result := {"ids":PackedInt32Array(),"kinds":PackedByteArray(),"poses":PackedFloat32Array(),"colors":PackedColorArray()}
	for index in indices: _append(result,data,index)
	return result

func _append(target: Dictionary, source: Dictionary, index: int) -> void:
	target.ids.append(source.ids[index])
	target.kinds.append(source.kinds[index])
	target.colors.append(_tint(source,index))
	target.poses.append_array(source.poses.slice(index*12,index*12+12))

func apply(data: Dictionary, parent: Node) -> Dictionary:
	if not validate(data) or parent==null: return _error("LOOSE_INVALID")
	if not is_instance_valid(_root): _create_visuals(parent)
	var hay_count := 0
	for kind in data.kinds:
		if kind==0: hay_count += 1
	_hay.instance_count = hay_count
	_needles.instance_count = data.ids.size()-hay_count
	var next_hay := 0
	var next_needle := 0
	_draw_slots.clear()
	for index in range(data.ids.size()):
		var offset: int = index*12
		var p: PackedFloat32Array = data.poses
		var transform := Transform3D(Basis(Vector3(p[offset],p[offset+1],p[offset+2]),Vector3(p[offset+3],p[offset+4],p[offset+5]),Vector3(p[offset+6],p[offset+7],p[offset+8])),Vector3(p[offset+9],p[offset+10],p[offset+11]))
		if data.kinds[index]==0:
			_draw_slots[data.ids[index]] = {"kind":0,"index":next_hay}
			_hay.set_instance_transform(next_hay,transform)
			_hay.set_instance_color(next_hay,data.colors[index] if data.has("colors") else Color.WHITE)
			next_hay += 1
		else:
			_draw_slots[data.ids[index]] = {"kind":1,"index":next_needle}
			_needles.set_instance_transform(next_needle,transform)
			next_needle += 1
	current = data.duplicate(true)
	_refresh_local()
	return _ok()

func _create_visuals(parent: Node) -> void:
	_root = Node3D.new()
	_root.name = "FtnCoopLooseResources"
	parent.add_child(_root)
	var straw: Mesh = _native_mesh
	if straw==null:
		var fallback := BoxMesh.new()
		fallback.size = Vector3(0.025,0.025,0.3)
		straw = fallback
	_hay = _batch(straw,Color(0.72,0.5,0.15),_native_mesh!=null)
	_root.get_child(0).material_override = _native_material
	var needle := CylinderMesh.new()
	needle.top_radius = 0.006
	needle.bottom_radius = 0.006
	needle.height = 0.25
	_needles = _batch(needle,Color(0.8,0.85,0.9))

func _batch(mesh: Mesh, color: Color, native: bool=false) -> MultiMesh:
	if not native:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.7
		material.vertex_color_use_as_albedo = true
		mesh.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	_root.add_child(instance)
	return batch

func close() -> void:
	if is_instance_valid(_root): _root.queue_free()
	_root = null
	_ids.clear()
	held.clear()
	hold_frames.clear()
	_local_peer = 0
	_local_player = null
	_draw_slots.clear()
	_native_mesh = null
	_native_material = null
	current = {"ids":PackedInt32Array(),"kinds":PackedByteArray(),"poses":PackedFloat32Array(),"colors":PackedColorArray()}

func _ok(value: Variant=null) -> Dictionary:
	return {"ok":true,"code":"OK","value":value}

func _error(code: String) -> Dictionary:
	return {"ok":false,"code":code,"value":null}
