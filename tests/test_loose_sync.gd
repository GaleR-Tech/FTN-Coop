extends RefCounted

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
	var first: Dictionary = host.capture_sources([hay_a,hay_b],[needle])
	if not first.ok or first.value.ids.size() != 3:
		source.free()
		return ["Hay and needles must receive host-owned stable IDs and poses."]
	var original_ids: PackedInt32Array = first.value.ids.duplicate()
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
	source.free()
	return errors
