extends RefCounted

const LIMIT := 8192
var current := {"ids":PackedInt32Array(),"kinds":PackedByteArray(),"poses":PackedFloat32Array()}
var _ids: Dictionary = {}
var _next_id := 1
var _root: Node3D
var _hay: MultiMesh
var _needles: MultiMesh

func capture_sources(hay: Array, needles: Array) -> Dictionary:
	if hay.size()+needles.size()>LIMIT: return _error("LOOSE_LIMIT")
	var records := {}
	var seen := {}
	for kind in range(2):
		for body in hay if kind == 0 else needles:
			if not is_instance_valid(body) or not body is Node3D or not body.is_inside_tree(): continue
			if not _ids.has(body):
				if _next_id >= 2147483647: return _error("LOOSE_LIMIT")
				_ids[body] = _next_id
				_next_id += 1
			seen[body] = true
			records[_ids[body]] = {"kind":kind,"transform":body.global_transform}
	for body in _ids.keys():
		if not is_instance_valid(body) or not seen.has(body): _ids.erase(body)
	var ids := PackedInt32Array()
	var kinds := PackedByteArray()
	var poses := PackedFloat32Array()
	var ordered := records.keys()
	ordered.sort()
	for id in ordered:
		ids.append(id)
		kinds.append(records[id].kind)
		var transform: Transform3D = records[id].transform
		for vector in [transform.basis.x,transform.basis.y,transform.basis.z,transform.origin]:
			poses.append_array(PackedFloat32Array([vector.x,vector.y,vector.z]))
	var data := {"ids":ids,"kinds":kinds,"poses":poses}
	if not validate(data): return _error("LOOSE_INVALID")
	return _ok(data)

func validate(data: Dictionary) -> bool:
	if data.size()!=3 or not data.get("ids") is PackedInt32Array or not data.get("kinds") is PackedByteArray or not data.get("poses") is PackedFloat32Array: return false
	var size: int = data.ids.size()
	if size>LIMIT or data.kinds.size()!=size or data.poses.size()!=12*size: return false
	var previous := 0
	for index in range(size):
		if data.ids[index]<=previous or data.kinds[index]>1: return false
		previous = data.ids[index]
		for component in range(12):
			var value: float = data.poses[index*12+component]
			if not is_finite(value) or absf(value)>(8.0 if component<9 else 2048.0): return false
	return true

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
	for index in range(data.ids.size()):
		var offset: int = index*12
		var p: PackedFloat32Array = data.poses
		var transform := Transform3D(Basis(Vector3(p[offset],p[offset+1],p[offset+2]),Vector3(p[offset+3],p[offset+4],p[offset+5]),Vector3(p[offset+6],p[offset+7],p[offset+8])),Vector3(p[offset+9],p[offset+10],p[offset+11]))
		if data.kinds[index]==0:
			_hay.set_instance_transform(next_hay,transform)
			next_hay += 1
		else:
			_needles.set_instance_transform(next_needle,transform)
			next_needle += 1
	current = data.duplicate(true)
	return _ok()

func _create_visuals(parent: Node) -> void:
	_root = Node3D.new()
	_root.name = "FtnCoopLooseResources"
	parent.add_child(_root)
	var straw := BoxMesh.new()
	straw.size = Vector3(0.025,0.025,0.3)
	_hay = _batch(straw,Color(0.72,0.5,0.15))
	var needle := CylinderMesh.new()
	needle.top_radius = 0.006
	needle.bottom_radius = 0.006
	needle.height = 0.25
	_needles = _batch(needle,Color(0.8,0.85,0.9))

func _batch(mesh: Mesh, color: Color) -> MultiMesh:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	mesh.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	_root.add_child(instance)
	return batch

func close() -> void:
	if is_instance_valid(_root): _root.queue_free()
	_root = null
	_ids.clear()
	current = {"ids":PackedInt32Array(),"kinds":PackedByteArray(),"poses":PackedFloat32Array()}

func _ok(value: Variant=null) -> Dictionary:
	return {"ok":true,"code":"OK","value":value}

func _error(code: String) -> Dictionary:
	return {"ok":false,"code":code,"value":null}
