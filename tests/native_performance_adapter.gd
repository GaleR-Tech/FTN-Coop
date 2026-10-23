extends "res://mods/ftn_coop/game_adapter.gd"

signal applied(event: Dictionary)
var perf := {}
var spill_visuals := []

func _perform_action(actor: Node, kind: String, payload: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super._perform_action(actor,kind,payload)
	record("native_action_"+kind,Time.get_ticks_usec()-started)
	return result

func _live_frame() -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super._live_frame()
	record("capture",Time.get_ticks_usec()-started)
	return result

func _difference(before: Dictionary, after: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super._difference(before,after)
	record("difference",Time.get_ticks_usec()-started)
	return result

func apply_confirmed_event(event: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super.apply_confirmed_event(event)
	record("apply_event",Time.get_ticks_usec()-started)
	for key in last_apply_timings: record("apply_"+str(key),last_apply_timings[key])
	if result.ok: applied.emit(event)
	return result

func _patch_valid(patch: Dictionary) -> bool:
	var started := Time.get_ticks_usec()
	var result := super._patch_valid(patch)
	record("validate_patch",Time.get_ticks_usec()-started)
	return result

func _render_belts(world_id: int, epoch: int) -> void:
	var started := Time.get_ticks_usec()
	super._render_belts(world_id,epoch)
	record("render_belts",Time.get_ticks_usec()-started)

func _clear_guest_belt_spills() -> void:
	super._clear_guest_belt_spills()
	spill_visuals.clear()

func _copy_belt_fallback_meshes(source: Node) -> void:
	var top: bool = source is RigidBody3D and nodes.has("props") and source in nodes.props.get("items")
	var first: int = _guest_belt_spills.get_child_count() if top else 0
	var transform: Transform3D = source.global_transform if source is Node3D else Transform3D.IDENTITY
	super._copy_belt_fallback_meshes(source)
	if top:
		spill_visuals.append({"xform":transform,"meshes":_guest_belt_spills.get_children().slice(first)})

func record(key: String, micros: int) -> void:
	if not perf.has(key): perf[key] = []
	if perf[key].size()<20000: perf[key].append(micros/1000.0)
