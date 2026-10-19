extends RefCounted

class Player extends Node3D:
	var head: Node3D
	var current_tool := 2
	func _init() -> void:
		head = Node3D.new()
		add_child(head)

class Actor extends Node3D:
	var hand: Node = null
	var carry: Node = null
	var current_tool := 0
	var carried_load := 1
	func drop_active_tool() -> void: carried_load = 0
	func set_look(yaw: float, pitch: float) -> void: rotation = Vector3(pitch,yaw,0)
	func is_tool_unlocked(_tool: int) -> bool: return false
	func _set_tool(tool: int, _force: bool) -> void: current_tool = tool

func create(_source: Node, world: Node, _peer: int) -> Dictionary:
	var actor := Actor.new()
	world.add_child(actor)
	return {"ok":true,"code":"OK","value":actor}

func bind_tools(actor: Node, _source: Node) -> Dictionary:
	return {"ok":true,"code":"OK","value":actor}
