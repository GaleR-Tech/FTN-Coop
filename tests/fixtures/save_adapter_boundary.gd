extends "res://mods/ftn_coop/game_adapter.gd"

var native_saves: Node
var state_schema: Node
var tech_schema: Node

func _main_scene_path() -> String: return "res://tests/fixtures/save_world.tscn"
func _menu_scene_path() -> String: return "res://tests/fixtures/save_menu.tscn"

func bind(root: Node) -> Dictionary:
	nodes = {"saves":native_saves}
	# Real native autoload schemas are available even while the menu is open.
	if state_schema==null:
		state_schema=load("res://tests/fixtures/replica_boundary.gd").State.new()
		tech_schema=load("res://tests/fixtures/replica_boundary.gd").Tech.new()
		native_saves.add_child(state_schema);native_saves.add_child(tech_schema)
	nodes.state=state_schema;nodes.tech=tech_schema
	var scene: Node = root.get_tree().current_scene
	if scene!=null and scene.has_method("payload"):
		nodes.world = scene
		for role in ["field","state","tech","builds","props"]: nodes[role] = scene.get(role)
	return {}
