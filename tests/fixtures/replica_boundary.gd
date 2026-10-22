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

class LiveState extends Node:
	signal collection_loaded
	signal money_changed(amount: float)
	var data := {"money":10.0,"mission_index":0,"mission_id":"first_hay","needle_stock":[0]}
	func to_dict() -> Dictionary: return data
	func from_dict(value: Dictionary) -> void:
		data = value.duplicate(true)
		collection_loaded.emit()
		money_changed.emit(data.money)

class QuestPanel extends Control:
	var _shown := -1
	var _hold := 0.0
	var _farewell_left := 0.0
	var title := Label.new()
	var progress := Label.new()
	func _init() -> void:
		add_child(title)
		add_child(progress)
	func show_step(index: int) -> void:
		if _hold>0.0: return
		_shown = index
		title.text = "Fill bucket" if index==14 else "Pick up hay"
	func show_progress(value: Dictionary) -> void: progress.text = value.get("text","")

class Missions extends Node:
	func progress_of(id: String) -> Dictionary:
		return {"have":0.5,"need":1.0,"text":"50% full"} if id=="fill_bucket" else {}

class QuestWorld extends Node:
	var quests := QuestPanel.new()
	var mission_cue := QuestPanel.new()
	var missions := Missions.new()
	func _init() -> void:
		add_child(quests)
		add_child(mission_cue)
		add_child(missions)
