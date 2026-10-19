extends RefCounted

func run(_tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var diagnostic: Node = load("res://mods/ftn_coop/native_network_check.gd").new()
	for value in [12.5, 7, false, "bucket", PackedByteArray([1,2]), [1,2]]:
		var digest: String = diagnostic._digest(value)
		if digest.length()!=64: errors.append("Every native field type needs a real SHA256 fingerprint: "+type_string(typeof(value)))
	if diagnostic._digest(12.5)==diagnostic._digest(13.5): errors.append("Changed native scalar values must have different fingerprints.")
	if diagnostic._digest({"b":2,"a":1})!=diagnostic._digest({"a":1,"b":2}): errors.append("Native dictionary order must not change fingerprints.")
	diagnostic.free()
	return errors
