extends "res://tests/fixtures/fake_world_adapter.gd"

signal restore_started

var tree: SceneTree
var restoring := false
var last_sync_error := ""
var pose := {"position":Vector3.ZERO,"rotation":Vector3.ZERO}
var actor_poses: Dictionary = {}
var last_action_pose: Dictionary = {}
var nodes: Dictionary = {}
var guest_mode: bool:
	get: return guest
func probe(_root: Node) -> Dictionary: return _ok()
func read_local_pose() -> Dictionary: return _ok(pose)
func update_actor_pose(peer: int, value: Dictionary) -> Dictionary:
	actor_poses[peer] = value.duplicate(true)
	return _ok()
func apply_host_action(peer: int, kind: String, payload: Dictionary) -> Dictionary:
	last_action_pose = actor_poses.get(peer,{}).duplicate(true)
	return super.apply_host_action(peer,kind,payload)
func prepare_actor(_peer: int) -> Dictionary: return _ok()
func remove_actor(_peer: int) -> void: pass
func capture_world() -> Dictionary: return _ok(world.duplicate(true))
func _live_frame() -> Dictionary: return world.duplicate(true)
func set_guest_mode(enabled: bool) -> Dictionary:
	guest = enabled
	return _ok()
func restore_guest_world(state: Dictionary, _session: String) -> Dictionary:
	restoring = true
	restore_started.emit()
	await tree.create_timer(0.03).timeout
	guest = true
	world = state.duplicate(true)
	restoring = false
	return _ok()
func apply_confirmed_event(event: Dictionary) -> Dictionary:
	if event.get("kind")=="checkpoint": return _ok()
	world = event.get("patch",event.get("world",{})).duplicate(true)
	return _ok()
func pump_guest_visuals() -> void: pass
func cancel_guest_restore() -> void: pass
func close_guest_world() -> Dictionary:
	guest = false
	return _ok()
func save_host_world() -> Dictionary: return _ok()
func _ok(value: Variant=null) -> Dictionary: return {"ok":true,"code":"OK","value":value}
