extends RefCounted

class Inventory extends Node:
	signal tools_changed
	var owned_tools := {"spade":true}
	func grant(id: String) -> void:
		owned_tools[id] = true
		tools_changed.emit()
	func drop(id: String) -> void:
		owned_tools.erase(id)
		tools_changed.emit()

func run(_tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/shared_tools.gd"): return ["Native tool unlocks must stay shared when one player drops a copy."]
	var state := Inventory.new()
	var scope: RefCounted = load("res://mods/ftn_coop/shared_tools.gd").new()
	scope.configure(state,["spade","pitchfork"])
	var errors: Array[String] = []
	state.drop("spade")
	if not state.owned_tools.has("spade"): errors.append("Dropping one copy must preserve an already shared spade unlock.")
	state.grant("pitchfork")
	state.drop("pitchfork")
	if not state.owned_tools.has("pitchfork"): errors.append("A new purchase must become available to every player until the session ends.")
	state.grant("bucket")
	state.drop("bucket")
	if state.owned_tools.has("bucket"): errors.append("Physical containers must retain native ownership semantics.")
	scope.close()
	state.drop("spade")
	if state.owned_tools.has("spade"): errors.append("Offline play must regain normal drop behavior after leaving co-op.")
	state.free()
	return errors
