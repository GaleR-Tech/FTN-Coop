extends RefCounted

class Saves extends Node:
	var current_slot := 0
	var block_save := false
	var directory := ""
	var pending: Dictionary = {}
	var write_ok := true
	func save_dir() -> String: return directory
	func use_scratch_dir(value: String) -> void:
		directory = value
		DirAccess.make_dir_recursive_absolute(directory)
	func slot_path(slot: int) -> String: return directory+"/slot_"+str(slot)+".dat"
	func finish_write() -> void: pass
	func _clear_pending() -> void: pending.clear()
	func write_file(path: String, value: Dictionary) -> bool:
		if not write_ok: return false
		var codec: RefCounted = load("res://mods/ftn_coop/value_codec.gd").new()
		var encoded: Dictionary = codec.encode(value,1048576)
		if not encoded.ok: return false
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file==null: return false
		file.store_buffer(encoded.value)
		file.close()
		return true
	func _read(slot: int) -> Dictionary:
		var file := FileAccess.open(slot_path(slot),FileAccess.READ)
		if file==null: return {}
		var bytes := file.get_buffer(file.get_length())
		file.close()
		var codec: RefCounted = load("res://mods/ftn_coop/value_codec.gd").new()
		var decoded: Dictionary = codec.decode(bytes,1048576)
		return decoded.value if decoded.ok and decoded.value is Dictionary else {}
	func begin_load(slot: int) -> void:
		current_slot = slot
		pending = _read(slot)
