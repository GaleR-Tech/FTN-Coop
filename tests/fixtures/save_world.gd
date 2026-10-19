extends Node3D

var _built := false
var block_save := false
var fail_after_partial_write := false
var saves: Node
var field: Node
var state: Node
var tech: Node
var builds: Node
var props: Node

func _init() -> void:
	var fixture: Script = load("res://tests/fixtures/replica_boundary.gd")
	field = fixture.Field.new()
	state = fixture.State.new()
	tech = fixture.Tech.new()
	builds = fixture.Records.new()
	props = fixture.Records.new()
	for node in [field,state,tech,builds,props]: add_child(node)

func _ready() -> void:
	saves = get_tree().root.get_node("FtnSaveBoundary")
	if saves.pending.has("state"): state.from_dict(saves.pending.state)
	for frame in range(3): await get_tree().process_frame
	_built = true

func payload() -> Dictionary:
	return {"version":1,"state":state.to_dict(),"heights":field.heights,"player":Transform3D.IDENTITY,"buildings":builds.to_array(),"props":props.to_array(),"belts":{},"tech":tech.to_dict(),"cell":2.0,"extent":1.0}

func save_now(_background: bool) -> bool:
	if block_save or saves.block_save: return false
	if fail_after_partial_write:
		var file := FileAccess.open(saves.slot_path(saves.current_slot),FileAccess.WRITE)
		file.store_string("partial")
		file.close()
		return false
	return saves.write_file(saves.slot_path(saves.current_slot),payload())

func _exit_tree() -> void:
	if saves!=null and not block_save and not saves.block_save: save_now(false)
