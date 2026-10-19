extends RefCounted

class World extends Node:
	var _built := true
	var block_save := false
	var save_ok := true
	var saved_synchronously := false
	func save_now(background: bool) -> bool:
		saved_synchronously = not background
		return save_ok

class Saves extends Node:
	var current_slot := 3
	var block_save := false
	var world: Node
	func save_dir() -> String: return "user://ftn_coop_tests/capture_boundary"
	func slot_path(slot: int) -> String: return save_dir()+"/slot_"+str(slot)+".dat"
	func _read(slot: int) -> Dictionary:
		if slot != 3 or not world.saved_synchronously:
			return {}
		return {"hay": 123.0, "loose_strands": 7.0, "version": 66}
