extends RefCounted

class Technology extends Node:
	var rows := {"belt":1,"arm":1}
	var restores := 0
	func to_dict() -> Dictionary: return rows.duplicate(true)
	func from_dict(value: Dictionary,_notify: bool) -> void: restores+=1;rows=value.duplicate(true)

func run(tree: SceneTree) -> Array[String]:
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	if not adapter.has_method("apply_guest_technology"): return ["Unchanged technology invokes expensive native restoration on each full frame"]
	var errors: Array[String] = []
	var tech := Technology.new();tree.root.add_child(tech);adapter.nodes.tech=tech
	adapter.apply_guest_technology(tech.to_dict())
	if tech.restores!=0: errors.append("Already loaded native technology was restored again")
	adapter.apply_guest_technology({"belt":2,"arm":1})
	adapter.apply_guest_technology({"belt":2,"arm":1})
	if tech.restores!=1 or tech.rows.belt!=2: errors.append("Technology update must restore changed data exactly once")
	tech.free()
	return errors
