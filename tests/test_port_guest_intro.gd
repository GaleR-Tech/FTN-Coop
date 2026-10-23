extends RefCounted

class Intro extends Node:
	var aborted := false
	func abort() -> void: aborted = true

class World extends Node:
	var _built := false
	var intro := Intro.new()
	var quests := Node.new()
	var mission_cue := Node.new()
	func _init() -> void: add_child(intro); add_child(quests); add_child(mission_cue)

func run(_tree: SceneTree) -> Array[String]:
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	if not adapter.has_method("prepare_guest_presentation"): return ["Guest intro remains frozen over the joined world"]
	var errors: Array[String] = []
	var world := World.new()
	adapter.nodes.world = world
	adapter.prepare_guest_presentation()
	if world.intro.aborted: errors.append("Loading intro ended before world construction")
	world._built = true
	adapter.prepare_guest_presentation()
	if not world.intro.aborted: errors.append("Built guest world retained a frozen intro")
	if world.quests.process_mode!=Node.PROCESS_MODE_ALWAYS or world.mission_cue.process_mode!=Node.PROCESS_MODE_ALWAYS: errors.append("Native guest HUD timers remain frozen")
	world.free()
	return errors
