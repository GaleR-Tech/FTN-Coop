extends RefCounted

class Field extends Node:
	var heights := PackedFloat32Array([1.0,1.0,1.0,1.0])
	var dirtied := PackedInt32Array()
	func _dirty_moved(indices: PackedInt32Array) -> void: dirtied = indices
	func _flush_dirty() -> void: pass

class State extends Node:
	var data := {"money":10.0}
	func to_dict() -> Dictionary: return data
	func from_dict(value: Dictionary) -> void: data = value.duplicate(true)

class Tech extends State:
	func from_dict(value: Dictionary, _refund: bool = false) -> void: data = value.duplicate(true)

class NormalizingState extends Node:
	var money := 10.0
	var money_peak := 10.0
	var jetpack_fuel := 0.0
	func to_dict() -> Dictionary: return {"money":money,"money_peak":money_peak,"jetpack_fuel":jetpack_fuel}
	func from_dict(value: Dictionary) -> void:
		money = value.money
		money_peak = maxf(value.money_peak,money)
		jetpack_fuel = 0.0

class Records extends Node:
	var restore_slice_usec := 1000
	var data: Array = []
	func clear() -> void: data.clear()
	func to_array() -> Array: return data
	func from_array(value: Array) -> void: data = value.duplicate(true)
