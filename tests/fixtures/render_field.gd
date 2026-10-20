extends Node

var heights := PackedFloat32Array([1.0,2.0])
var rendered := 0
var joined := 0
func settle_join() -> void: joined += 1
func _clear_relax_queue() -> void: pass
func _land_jobs() -> void: pass
func _apply_relax() -> void: heights[0] += 1
func _settle() -> void: heights[0] += 1
func _start_settle(_marks: bool) -> void: heights[0] += 1
func _tick_last_of_pile(_delta: float) -> void: heights[0] += 1
func _relax_once(budget: int, deadline: int=0) -> Dictionary:
	if budget!=0 or deadline!=1: heights[0] += 1
	return {}
func _process(delta: float) -> void:
	_land_jobs()
	_relax_once(100)
	_apply_relax()
	_settle()
	_start_settle(true)
	_tick_last_of_pile(delta)
	rendered += 1
