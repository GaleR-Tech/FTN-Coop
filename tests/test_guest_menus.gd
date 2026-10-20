extends RefCounted

class Menu extends Control:
	var _open := false
	func is_open() -> bool: return _open
	func set_open(value: bool) -> void:
		_open = value
		visible = value
	func _input(_event: InputEvent) -> void: pass

class TechMenu extends Menu:
	var _selected := "hand_carry"
	var _cards := {}
	var _ins_buy := Button.new()
	var _ins_clear := Button.new()
	var money := 100.0
	func _init() -> void:
		add_child(_ins_buy)
		add_child(_ins_clear)
		_ins_buy.pressed.connect(_buy_selected)
		var card := PanelContainer.new()
		add_child(card)
		_cards.hand_carry = card
		card.gui_input.connect(_on_card_input.bind("hand_carry"))
	func _buy_selected() -> void: money -= 10.0
	func _on_card_input(event: InputEvent, id: String) -> void:
		_selected = id
		if event is InputEventMouseButton and event.double_click: _buy_selected()

class PauseMenu extends Menu:
	var exit_button := Button.new()
	var save_button := Button.new()
	var left_locally := false
	func _init() -> void:
		add_child(exit_button)
		add_child(save_button)
		exit_button.pressed.connect(_on_exit_to_title)
		save_button.pressed.connect(_on_save)
	func _on_exit_to_title() -> void: left_locally = true
	func _on_save() -> void: pass

class World extends Node:
	var catalog_panel := Menu.new()
	var tech_panel := TechMenu.new()
	var pause_menu := PauseMenu.new()
	func _init() -> void:
		process_mode = Node.PROCESS_MODE_DISABLED
		add_child(catalog_panel)
		add_child(tech_panel)
		add_child(pause_menu)

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/guest_menus.gd"):
		return ["Guests need the native catalog, research and Escape menus."]
	var bridge: Node = load("res://mods/ftn_coop/guest_menus.gd").new()
	var world := World.new()
	tree.root.add_child(world)
	tree.root.add_child(bridge)
	var errors: Array[String] = []
	if not bridge.bind_world(world): errors.append("The menu bridge must bind the existing native panels.")
	bridge.active = true
	for binding in [["build_catalog",KEY_B],["tech_tree",KEY_T]]:
		InputMap.add_action(binding[0])
		var event := InputEventKey.new()
		event.physical_keycode = binding[1]
		InputMap.action_add_event(binding[0],event)
	var requests: Array = []
	bridge.action_requested.connect(func(kind: String,payload: Dictionary): requests.append([kind,payload]))
	var departures: Array = []
	bridge.leave_requested.connect(func(): departures.append(true))
	await press(tree,KEY_B)
	if not world.catalog_panel.is_open() or not bridge.blocks_gameplay(): errors.append("B must open the native catalog and block world controls.")
	await press(tree,KEY_ESCAPE)
	if world.catalog_panel.is_open() or bridge.blocks_gameplay(): errors.append("Escape must close the catalog before opening a pause menu.")
	await press(tree,KEY_T)
	if not world.tech_panel.is_open(): errors.append("The native research hotkey must open the existing skill tree.")
	world.tech_panel._ins_buy.pressed.emit()
	if world.tech_panel.money!=100.0 or requests!=[["upgrade",{"id":"hand_carry"}]]:
		errors.append("Native research purchases must reach the host without spending guest money locally.")
	var double_click := InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	world.tech_panel._cards.hand_carry.gui_input.emit(double_click)
	if world.tech_panel.money!=100.0 or requests.size()!=2: errors.append("Double-click research must also use one host request.")
	await press(tree,KEY_ESCAPE)
	await press(tree,KEY_ESCAPE)
	if not world.pause_menu.is_open(): errors.append("Escape in the world must open the native pause menu.")
	world.pause_menu.exit_button.pressed.emit()
	if world.pause_menu.left_locally or departures.size()!=1: errors.append("Leaving via the native pause menu must close the co-op session first.")
	if not world.pause_menu.save_button.disabled: errors.append("The guest must not save or quick-load an offline slot from the native pause menu.")
	bridge.detach()
	if world.catalog_panel.process_mode!=Node.PROCESS_MODE_INHERIT or world.tech_panel._ins_clear.disabled:
		errors.append("Closing a guest session must restore native panel behavior.")
	world.tech_panel._ins_buy.pressed.emit()
	if world.tech_panel.money!=90.0 or requests.size()!=2: errors.append("Guest request hooks must be removed on teardown.")
	bridge.queue_free()
	world.queue_free()
	for action in ["build_catalog","tech_tree"]: InputMap.erase_action(action)
	await tree.process_frame
	return errors

func press(tree: SceneTree, key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await tree.process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await tree.process_frame
