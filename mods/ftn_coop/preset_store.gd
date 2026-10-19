extends RefCounted

var _path := "user://ftn_coop/presets.dat"

func configure(path: String) -> void: _path = path

func list_names() -> Dictionary:
	var read := _read()
	if not read.ok: return read
	var names: Array = read.value.keys()
	names.sort()
	return _ok(names)

func save_preset(name: String, values: Dictionary) -> Dictionary:
	if not _valid_name(name): return _error("PRESET_NAME_INVALID")
	var valid: Dictionary = _schema().validate(values)
	if not valid.ok: return valid
	var read := _read()
	if not read.ok: return read
	if not read.value.has(name) and read.value.size()>=20: return _error("PRESET_LIMIT")
	read.value[name] = valid.value
	return _write(read.value)

func load_preset(name: String) -> Dictionary:
	var read := _read()
	if not read.ok: return read
	return _ok(read.value[name].duplicate(true)) if read.value.has(name) else _error("PRESET_MISSING")

func delete_preset(name: String) -> Dictionary:
	var read := _read()
	if not read.ok: return read
	if not read.value.has(name): return _error("PRESET_MISSING")
	read.value.erase(name)
	return _write(read.value)

func _read() -> Dictionary:
	var source := _path
	if not FileAccess.file_exists(source):
		source += ".bak"
		if not FileAccess.file_exists(source): return _ok({})
	var file := FileAccess.open(source,FileAccess.READ)
	if file==null or file.get_length()>65536: return _error("PRESET_INVALID")
	var decoded: Dictionary = _codec().decode(file.get_buffer(file.get_length()),65536)
	file.close()
	if not decoded.ok or not decoded.value is Dictionary or decoded.value.size()!=2 or decoded.value.get("format")!=1 or not decoded.value.get("presets") is Dictionary: return _error("PRESET_INVALID")
	var presets: Dictionary = decoded.value.presets
	if presets.size()>20: return _error("PRESET_INVALID")
	for name in presets:
		if not name is String or not _valid_name(name) or not _schema().validate(presets[name]).ok: return _error("PRESET_INVALID")
	return _ok(presets)

func _write(presets: Dictionary) -> Dictionary:
	var encoded: Dictionary = _codec().encode({"format":1,"presets":presets},65536)
	if not encoded.ok: return _error("PRESET_SAVE_FAILED")
	if DirAccess.make_dir_recursive_absolute(_path.get_base_dir())!=OK: return _error("PRESET_SAVE_FAILED")
	var temporary := _path+".tmp"
	var backup := _path+".bak"
	if DirAccess.dir_exists_absolute(temporary): return _error("PRESET_SAVE_FAILED")
	# Recover an interrupted install before starting another generation.
	if not FileAccess.file_exists(_path) and FileAccess.file_exists(backup):
		if DirAccess.rename_absolute(backup,_path)!=OK: return _error("PRESET_SAVE_FAILED")
	if DirAccess.dir_exists_absolute(backup): return _error("PRESET_SAVE_FAILED")
	if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup)!=OK: return _error("PRESET_SAVE_FAILED")
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return _error("PRESET_SAVE_FAILED")
	file.store_buffer(encoded.value)
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK:
		DirAccess.remove_absolute(temporary)
		return _error("PRESET_SAVE_FAILED")
	# Every move targets an absent path: Windows rename deletes existing targets.
	var had_previous := FileAccess.file_exists(_path)
	if had_previous and DirAccess.rename_absolute(_path,backup)!=OK:
		DirAccess.remove_absolute(temporary)
		return _error("PRESET_SAVE_FAILED")
	if DirAccess.rename_absolute(temporary,_path)!=OK:
		if had_previous and not FileAccess.file_exists(_path): DirAccess.rename_absolute(backup,_path)
		DirAccess.remove_absolute(temporary)
		return _error("PRESET_SAVE_FAILED")
	if had_previous: DirAccess.remove_absolute(backup)
	return _ok()

func _valid_name(name: String) -> bool:
	if name.is_empty() or name.length()>32 or name!=name.strip_edges(): return false
	for i in range(name.length()):
		var character := name.unicode_at(i)
		if character<32 or (character>=127 and character<160): return false
	return true

func _schema() -> RefCounted: return load(get_script().resource_path.get_base_dir()+"/shared_settings.gd").new()
func _codec() -> RefCounted: return load(get_script().resource_path.get_base_dir()+"/value_codec.gd").new()
func _ok(value: Variant=null) -> Dictionary: return {"ok":true,"code":"OK","value":value}
func _error(code: String) -> Dictionary: return {"ok":false,"code":code,"value":null}
