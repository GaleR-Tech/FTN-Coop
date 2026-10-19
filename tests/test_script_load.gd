extends RefCounted

func run(_tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var directory := DirAccess.open("res://mods/ftn_coop")
	if directory == null: return ["Own runtime directory is missing."]
	for filename in directory.get_files():
		if not filename.ends_with(".gd"): continue
		var script: Script = load("res://mods/ftn_coop/"+filename)
		if script == null or not script.can_instantiate(): errors.append("Own runtime script does not compile: "+filename)
	return errors
