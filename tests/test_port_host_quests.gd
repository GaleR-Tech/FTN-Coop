extends RefCounted

class Actor extends CharacterBody3D:
	var _sprinting := false

class Menu extends Node:
	var opened := false
	var other: Menu
	var focus: Control
	func set_open(value: bool) -> void:
		opened=value
		if value and other!=null: other.opened=false
		if value and focus!=null: focus.grab_focus()
	func is_open() -> bool: return opened

class Missions extends Node:
	var player: Node
	var tech: Menu
	var saw_open := false
	var observed: Node
	func _watch(_delta: float) -> void:
		saw_open=saw_open or tech.opened
		observed=player

class World extends Node:
	var tech_panel := Menu.new()
	var catalog_panel := Menu.new()
	var missions := Missions.new()
	func _init() -> void:
		add_child(tech_panel);add_child(catalog_panel);add_child(missions)
		tech_panel.other=catalog_panel;catalog_panel.other=tech_panel;missions.tech=tech_panel

class Adapter extends "res://mods/ftn_coop/game_adapter.gd":
	func _live_frame() -> Dictionary: return {"state":{"mission_index":0}}

func run(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var adapter := Adapter.new()
	var world := World.new();tree.root.add_child(world)
	var host := Actor.new();world.add_child(host)
	var guest := Actor.new();world.add_child(guest)
	adapter.nodes={"world":world,"player":host};adapter.actors={2:guest}
	world.missions.player=host
	if not adapter.has_method("replication_players"): errors.append("Shared replication has no explicit playable host ownership")
	else:
		var players: Dictionary = adapter.replication_players()
		if players.get(1)!=host or players.get(2)!=guest: errors.append("Backport hid host tools/held objects from replication")
	if not adapter.has_method("observe_player_activity") or not adapter.has_method("pump_shared_activity"): errors.append("Shared guest movement quest observation is missing")
	else:
		adapter.observe_player_activity(2,{"position":Vector3.ZERO},0.1)
		adapter.observe_player_activity(2,{"position":Vector3(0,0,0.7)},0.1)
		if world.missions.player!=guest or not guest._sprinting: errors.append("Guest sprint did not reach shared native quests")
		host.velocity=Vector3(0,0,8);adapter.pump_shared_activity()
		if world.missions.player!=host: errors.append("Moving host is not eligible for shared quest progress")
		host.velocity=Vector3.ZERO;adapter._player_activity[2].at=Time.get_ticks_msec()-1000
		adapter.pump_shared_activity()
		if guest.velocity!=Vector3.ZERO or world.missions.player!=host: errors.append("Stale guest kept a quest active instead of restoring host")
		adapter.observe_player_activity(2,{"position":Vector3(0,0,100)},0.1)
		if guest.velocity!=Vector3.ZERO: errors.append("Teleport was credited as quest movement")
	var host_input := LineEdit.new();world.add_child(host_input)
	var guest_input := LineEdit.new();world.add_child(guest_input);guest_input.position.y=50
	world.tech_panel.focus=guest_input;world.catalog_panel.opened=true
	host_input.grab_focus()
	var focused := world.get_viewport().gui_get_focus_owner()
	var observed: Dictionary = adapter.apply_host_action(2,"menu_open",{"menu":"tech"})
	if not observed.ok or not world.missions.saw_open: errors.append("Guest research opening does not advance the native shared quest")
	if not world.catalog_panel.opened or world.tech_panel.opened or world.get_viewport().gui_get_focus_owner()!=focused or tree.paused or world.missions.player!=host: errors.append("Guest menu notification disturbed host menu/focus/pause/quest actor")
	if adapter.apply_host_action(2,"menu_open",{"menu":"tech","complete":true}).ok: errors.append("Guest may directly complete a quest")
	world.free()
	return errors
