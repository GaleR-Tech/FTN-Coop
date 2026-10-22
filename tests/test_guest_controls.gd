extends RefCounted

class BuildStepper extends Node:
	var steps := 0
	var placed := 0
	var _state := 0
	var _anchor := Vector3.ZERO
	func _frame(_delta: float) -> void: pass
	func status() -> Dictionary: return {"ok":true}
	func primary() -> void:
		steps += 1
		if steps==2: placed += 1

class Player extends CharacterBody3D:
	var current_tool := 0
	var build_id := ""
	var build := BuildStepper.new()
	func _init() -> void: add_child(build)
	func is_tool_unlocked(tool: int) -> bool: return tool in [0,1,8]
	func _set_tool(tool: int, _forced: bool) -> void: current_tool = tool
	func equip_build(id: String) -> void:
		if id=="cabinet":
			build_id = id
			current_tool = 8
			build.steps = 0
	func set_look(yaw: float, _pitch: float) -> void: rotation.y = yaw

class CataloguePanel extends Node:
	var _tiles := {"cabinet":null,"scanner":null}
	var _cards := {}
	var factory_calls := 0
	var created: Array[Node] = []
	func _name_line(_id: String) -> HBoxContainer:
		factory_calls += 1
		var row := HBoxContainer.new()
		created.append(row)
		return row

class Shop extends Node:
	func display_ids() -> Array: return ["bucket"]
	func live_price(_id: String) -> float: return 25.0

class World extends Node:
	var catalog_panel: Node
	var tech_panel: Node
	var shop: Node

class EmptyHands extends Node:
	var load_amount := 1
	func drop_held() -> void: load_amount = 0
	func drop_all() -> void: load_amount = 0

class LoadedPlayer extends Player:
	var hand := EmptyHands.new()
	var carry := EmptyHands.new()
	var load_amount := 54
	func drop_active_tool() -> void: load_amount = 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventAction and event.action=="secondary" and event.pressed: load_amount = 0
	func _init() -> void:
		if build.get_parent()==null: add_child(build)
		add_child(hand)
		add_child(carry)

class CompactHotbar extends Player:
	func select_hotbar_slot(index: int) -> void: current_tool = index
	func select_hotbar_key(index: int) -> void:
		current_tool = [0,1,8][index]

class LoadTool extends Node:
	var amount := 54
	func carried_strands() -> int: return amount
	func capacity() -> int: return 162
	func is_full() -> bool: return amount>=162

class LoadPlayer extends Player:
	var shovel := LoadTool.new()
	var pitchfork := LoadTool.new()
	func _init() -> void:
		if build.get_parent()==null: add_child(build)
		add_child(shovel)
		add_child(pitchfork)

func run(_tree: SceneTree) -> Array[String]:
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	for method in ["local_player_body","select_local_tool","select_local_build","guest_options","set_local_look","shared_summary","pump_local_preview"]:
		if not adapter.has_method(method): return ["Guest controls must use the verified adapter boundary: "+method]
	var errors: Array[String] = []
	if not FileAccess.file_exists("res://mods/ftn_coop/tool_load_state.gd"):
		errors.append("Guests need the host's per-player shovel and pitchfork load, including full and empty transitions.")
	else:
		var loads: RefCounted = load("res://mods/ftn_coop/tool_load_state.gd").new()
		var load_player := LoadPlayer.new()
		var rows: Array = loads.capture({2:load_player})
		if rows!=[{"peer":2,"shovel":{"count":54,"capacity":162,"full":false},"pitchfork":{"count":54,"capacity":162,"full":false}}]:
			errors.append("Tool fill feedback must use the authoritative controller for that peer.")
		load_player.shovel.amount = 162
		loads.accept(loads.capture({2:load_player}))
		if loads.selected(2,1)!={"tool":1,"count":162,"capacity":162,"full":true}:
			errors.append("A full shovel must remain distinguishable from a partly filled pitchfork.")
		load_player.shovel.amount = 0
		loads.accept(loads.capture({2:load_player}))
		if loads.selected(2,1).count!=0 or loads.selected(2,1).full: errors.append("Throwing or emptying must clear the guest's confirmed load indicator.")
		var malformed: Array = loads.current.duplicate(true)
		malformed[0].shovel.count = -1
		if loads.accept(malformed) or loads.selected(2,1).count!=0: errors.append("Invalid tool feedback must leave the previous confirmed load intact.")
		load_player.free()
	var hotbar := CompactHotbar.new()
	adapter.nodes = {"player":hotbar}
	adapter.guest_mode = true
	adapter.select_hotbar_slot(2)
	if hotbar.current_tool!=8: errors.append("The third visible hotbar key must select its displayed building, skipping hidden absolute tool slots.")
	hotbar.free()
	adapter.guest_mode = false
	var player := Player.new()
	var world := World.new()
	var panel := CataloguePanel.new()
	var shop := Shop.new()
	world.catalog_panel = panel
	world.tech_panel = panel
	world.shop = shop
	var title := Label.new()
	title.text = "Schneller scannen"
	panel.add_child(title)
	panel._cards = {"scan_speed":title}
	for id in panel._tiles:
		var tile := Label.new()
		tile.text = "Nadelschrank" if id=="cabinet" else "Scanner"
		panel.add_child(tile)
		panel._tiles[id] = tile
	adapter.nodes = {"world":world,"player":player}
	if adapter.select_local_tool(1).code!="HOST_ONLY": errors.append("Offline selection must remain with the native game.")
	adapter.guest_mode = true
	if not adapter.has_method("apply_local_build_state"):
		errors.append("A guest's native multi-step preview must receive the host-confirmed build anchor.")
	if not adapter.select_local_tool(1).ok or player.current_tool!=1: errors.append("A guest can select an unlocked native tool.")
	if adapter.select_local_tool(2).ok or player.current_tool!=1: errors.append("A guest cannot force a locked native tool.")
	if not adapter.select_local_build("cabinet").ok or adapter.select_local_build("foreign").ok: errors.append("Guest build selection uses only the native catalogue.")
	if adapter.select_local_build("scanner").code!="BUILD_LOCKED": errors.append("A refused native build unlock must be reported.")
	if adapter.has_method("apply_local_build_state"):
		var before_count: int = player.build.placed
		var preview := {"id":"cabinet","state":1,"anchor":Vector3(2,0,3)}
		if not adapter.apply_local_build_state(preview).ok or player.build._state!=1 or player.build._anchor!=Vector3(2,0,3) or player.build.placed!=before_count:
			errors.append("A confirmed anchor must update only the guest preview, without spending or placing locally.")
		preview.anchor = Vector3(INF,0,0)
		if adapter.apply_local_build_state(preview).ok or player.build._anchor!=Vector3(2,0,3): errors.append("Invalid preview updates must leave the previous anchor intact.")
		player.build_id = "other"
		preview.anchor = Vector3.ZERO
		adapter.apply_local_build_state(preview)
		if player.build._anchor!=Vector3(2,0,3): errors.append("A delayed anchor for an old selection must not change a new local selection.")
		player.build_id = "cabinet"
	var options: Dictionary = adapter.guest_options()
	if options.shop.size()!=1 or not options.shop[0].label.contains("Eimer") or options.buildings.size()!=2 or options.upgrades[0].label!="Schneller scannen": errors.append("Guest choices need readable native titles and bounded catalogue IDs.")
	if panel.factory_calls!=0: errors.append("Reading catalogue titles must not create native menu rows.")
	adapter._perform_action(player,"place",{"id":"cabinet"})
	adapter._perform_action(player,"place",{"id":"cabinet"})
	if player.build.placed!=1: errors.append("Successive placement clicks must preserve the native multi-step build operation.")
	var loaded := LoadedPlayer.new()
	loaded.current_tool = 1
	var secondary: Dictionary = adapter._perform_action(loaded,"item_interact",{"operation":"secondary"})
	if not secondary.ok or loaded.load_amount!=0 or loaded.current_tool!=1:
		errors.append("A guest secondary action must use native emptying behavior while keeping the equipped tool.")
	loaded.load_amount = 54
	adapter._perform_action(loaded,"item_interact",{"operation":"drop"})
	if loaded.load_amount!=0: errors.append("Drop must use the native active-tool route, including a loaded shovel.")
	if loaded.hand.load_amount!=0 or loaded.carry.load_amount!=0: errors.append("Dropping the active tool must also release independent hand and carried objects.")
	loaded.free()
	for row in panel.created: row.free()
	player.free()
	world.free()
	panel.free()
	shop.free()
	return errors
