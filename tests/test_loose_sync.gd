extends RefCounted

class NativeLoose extends Node3D:
	var _mmi := MultiMeshInstance3D.new()
	func _init() -> void:
		_mmi.multimesh = MultiMesh.new()
		_mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		_mmi.multimesh.mesh = QuadMesh.new()
		_mmi.material_override = StandardMaterial3D.new()
		add_child(_mmi)

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/loose_sync.gd"):
		return ["Host-owned loose resource display is not implemented yet."]
	var errors: Array[String] = []
	var module: Script = load("res://mods/ftn_coop/loose_sync.gd")
	var host: RefCounted = module.new()
	var guest: RefCounted = module.new()
	var source := Node3D.new()
	tree.root.add_child(source)
	var hay_a := Node3D.new()
	var hay_b := Node3D.new()
	var needle := Node3D.new()
	for body in [hay_a,hay_b,needle]: source.add_child(body)
	hay_b.position = Vector3(1,2,3)
	hay_a.set_meta("tint",Color(0.9,0.7,0.2,1.0))
	var first: Dictionary = host.capture_sources([hay_a,hay_b],[needle])
	if not first.ok or first.value.ids.size() != 3:
		source.free()
		return ["Hay and needles must receive host-owned stable IDs and poses."]
	var original_ids: PackedInt32Array = first.value.ids.duplicate()
	if not first.value.get("colors") is PackedColorArray or first.value.colors.size()!=3 or first.value.colors[0]!=Color(0.9,0.7,0.2,1.0):
		errors.append("Host straw tint must survive capture instead of being replaced by a uniform placeholder color.")
	var codec: RefCounted = load("res://mods/ftn_coop/value_codec.gd").new()
	var encoded: Dictionary = codec.encode(first.value,1024*1024)
	if not encoded.ok or codec.decode(encoded.value,1024*1024).value != first.value:
		errors.append("Loose frames must round-trip through the actual wire data codec.")
	hay_b.position = Vector3(4,5,6)
	var moved: Dictionary = host.capture_sources([hay_b,hay_a],[needle])
	if moved.value.ids != original_ids: errors.append("Pool order must not change network identity.")
	var removed: Dictionary = host.capture_sources([hay_b],[needle])
	if original_ids[0] in removed.value.ids: errors.append("Consumed hay must disappear from the next authoritative frame.")
	if not guest.apply(first.value,tree.root).ok or guest.current != first.value:
		errors.append("Guest resource visuals must reproduce the host data without native production.")
	var invalid: Dictionary = first.value.duplicate(true)
	invalid.poses[0] = NAN
	if guest.apply(invalid,tree.root).code != "LOOSE_INVALID" or guest.current != first.value:
		errors.append("Invalid loose poses must be rejected before changing the replica.")
	var oversized: Array = []
	oversized.resize(8193)
	if host.capture_sources(oversized,[]).code != "LOOSE_LIMIT": errors.append("Loose resources must have a fixed memory and rendering bound.")
	guest.close()
	var native := NativeLoose.new()
	tree.root.add_child(native)
	if not guest.has_method("use_native_visuals"):
		errors.append("Guest loose straw must reuse native mesh and material resources in its own render-only batch.")
	else:
		guest.use_native_visuals(native)
		guest.apply(first.value,tree.root)
		if guest._hay.mesh!=native._mmi.multimesh.mesh or guest._root.get_child(0).material_override!=native._mmi.material_override:
			errors.append("Replica geometry and shading must come from the native straw renderer without modifying it.")
		if not guest._hay.use_colors:
			errors.append("Native straw batches must enable the captured per-instance host tint.")
		if native._mmi.multimesh.instance_count!=0 or guest._root.get_child_count()!=2:
			errors.append("Guest loose rendering must not borrow native pool slots or create collectible physics bodies.")
		var tinted_bad: Dictionary = first.value.duplicate(true)
		tinted_bad.colors[0] = Color(NAN,0,0,1)
		if guest.apply(tinted_bad,tree.root).ok or guest.current!=first.value: errors.append("Non-finite remote tint must fail before replacing valid resource visuals.")
		guest.close()
	native.free()
	source.free()
	return errors
