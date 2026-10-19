extends RefCounted

const VALUES := {"prop_cap":300,"prop_decay":false,"belt_cap":1000,"belt_decay":true,"auto_clean":true,"auto_clean_seconds":90.0,"grid_lock":true,"autosave":false,"autosave_seconds":300.0}

func run(_tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/preset_store.gd"): return ["Durable gameplay presets are missing."]
	var errors: Array[String] = []
	var script: Script = load("res://mods/ftn_coop/preset_store.gd")
	var store: RefCounted = script.new()
	var path := "user://ftn-presets-test-"+str(Time.get_ticks_usec())+".dat"
	store.configure(path)
	if not store.save_preset("Friends",VALUES).ok: errors.append("Saving a valid nine-setting preset must succeed.")
	var restarted: RefCounted = script.new()
	restarted.configure(path)
	var loaded: Dictionary = restarted.load_preset("Friends")
	if not loaded.ok or loaded.value!=VALUES: errors.append("A saved preset must preserve all typed settings across a restart.")
	for name in [""," ","x".repeat(33),"bad\nname","bad\u007fname"]:
		if store.save_preset(name,VALUES).ok: errors.append("Blank/control/oversized names must be rejected.")
	for i in range(19): store.save_preset("Preset "+str(i),VALUES)
	if store.save_preset("Twenty first",VALUES).ok: errors.append("The twenty first distinct preset must be rejected.")
	var updated := VALUES.duplicate(true)
	updated.prop_cap = 400
	if not store.save_preset("Friends",updated).ok or store.load_preset("Friends").value.prop_cap!=400: errors.append("Replacing a named preset must remain possible when the list is full.")
	var original_bytes := FileAccess.get_file_as_bytes(path)
	DirAccess.make_dir_recursive_absolute(path+".tmp")
	if store.save_preset("Friends",VALUES).ok or FileAccess.get_file_as_bytes(path)!=original_bytes: errors.append("A failed temporary write must preserve the previous valid preset file.")
	DirAccess.remove_absolute(path+".tmp")
	var temporary := FileAccess.open(path+".tmp",FileAccess.WRITE)
	temporary.close()
	var held := FileAccess.open(path+".tmp",FileAccess.READ)
	var failed_replace: Dictionary = store.save_preset("Friends",VALUES)
	var preserved: Dictionary = store.load_preset("Friends")
	if failed_replace.ok or not preserved.ok or preserved.value!=updated: errors.append("A failed move after temporary writing must preserve the previous valid presets.")
	held.close()
	DirAccess.remove_absolute(path+".tmp")
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(path,path+".bak")
		var recovered: Dictionary = store.load_preset("Friends")
		if not recovered.ok or recovered.value!=updated: errors.append("A restart between backup and installation must recover the previous valid presets.")
		if not store.save_preset("Friends",updated).ok: errors.append("Saving must remain possible after recovering an interrupted replacement.")
	var invalid := VALUES.duplicate(true)
	invalid.quality = 1
	if store.save_preset("Friends",invalid).ok or FileAccess.get_file_as_bytes(path)!=original_bytes: errors.append("Invalid/personal values must leave existing preset storage unchanged.")
	if not store.delete_preset("Friends").ok or store.load_preset("Friends").ok: errors.append("Deleting a named preset must persist its removal.")
	var corrupt := FileAccess.open(path,FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	if store.list_names().ok or store.save_preset("Friends",VALUES).ok or FileAccess.get_file_as_string(path)!="broken": errors.append("Corrupt data must be reported without overwriting it.")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path+".bak")
	var cfg: Node = load("res://tests/fixtures/game_config.gd").new()
	var settings: RefCounted = load("res://mods/ftn_coop/shared_settings.gd").new()
	settings.configure(cfg)
	if not settings.has_method("update_host_values"):
		errors.append("Applying a complete host preset atomically is missing.")
	else:
		var before: Dictionary = settings.capture().value
		if settings.update_host_values(invalid).ok or settings.capture().value!=before: errors.append("A whole invalid preset must leave native gameplay values unchanged.")
		if not settings.update_host_values(VALUES).ok or settings.capture().value!=VALUES: errors.append("A valid complete preset must apply through native setters.")
		settings.accept(VALUES)
		if settings.update_host_values(updated).code!="HOST_ONLY": errors.append("Guests must not apply host presets.")
		settings.release()
	cfg.free()
	return errors
