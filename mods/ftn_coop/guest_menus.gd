extends Node

signal action_requested(kind: String,payload: Dictionary)
signal leave_requested

var active := false
var _world: Node
var _panels: Array[Node] = []
var _modes: Array[Dictionary] = []
var _hooks: Array[Dictionary] = []
var _disabled: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func bind_world(world: Node) -> bool:
	if is_instance_valid(_world) and _world==world: return true
	detach()
	if world==null: return false
	for role in ["catalog_panel","tech_panel","pause_menu"]:
		var panel: Variant = world.get(role)
		if not panel is Node or not panel.has_method("set_open") or not panel.has_method("is_open"):
			detach()
			return false
		_panels.append(panel)
	_world = world
	for panel in _panels:
		_modes.append({"node":panel,"mode":panel.process_mode,"input":panel.is_processing_input(),"unhandled":panel.is_processing_unhandled_input(),"keys":panel.is_processing_unhandled_key_input()})
		panel.process_mode = Node.PROCESS_MODE_ALWAYS
		panel.set_process_input(false)
		panel.set_process_unhandled_input(false)
		panel.set_process_unhandled_key_input(false)
	var tech := _panels[1]
	if not _hook(tech.get("_ins_buy"),"pressed",tech,"_buy_selected",_buy_selected):
		detach()
		return false
	for id in tech.get("_cards"):
		var card: Node = tech.get("_cards")[id]
		for connection in card.get_signal_connection_list("gui_input"):
			var original: Callable = connection.callable
			if original.get_object()==tech and original.get_method()=="_on_card_input":
				_replace(card,"gui_input",connection,_card_input.bind(original,str(id)))
	_disable(tech.get("_ins_clear"))
	var pause := _panels[2]
	var pending: Array[Node] = [pause]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if not node is BaseButton: continue
		for connection in node.get_signal_connection_list("pressed"):
			var original: Callable = connection.callable
			if original.get_object()!=pause: continue
			if original.get_method()=="_on_exit_to_title":
				_replace(node,"pressed",connection,func(): leave_requested.emit())
			elif original.get_method() in ["_on_save","_on_quick_load_pressed","_on_quick_load","_on_slot_pressed"]:
				_disable(node)
	return true

func _hook(node: Node, signal_name: String, owner: Node, method: String, replacement: Callable) -> bool:
	if node==null: return false
	for connection in node.get_signal_connection_list(signal_name):
		var callback: Callable = connection.callable
		if callback.get_object()==owner and callback.get_method()==method:
			_replace(node,signal_name,connection,replacement)
			return true
	return false

func _replace(node: Node, signal_name: String, connection: Dictionary, replacement: Callable) -> void:
	node.disconnect(signal_name,connection.callable)
	node.connect(signal_name,replacement)
	_hooks.append({"node":node,"signal":signal_name,"original":connection.callable,"flags":connection.flags,"replacement":replacement})

func _disable(button: BaseButton) -> void:
	if button==null: return
	_disabled.append({"node":button,"disabled":button.disabled})
	button.disabled = true

func blocks_gameplay() -> bool:
	for panel in _panels:
		if is_instance_valid(panel) and panel.call("is_open"): return true
	return false

func close_panels() -> void:
	for panel in _panels:
		if is_instance_valid(panel) and panel.call("is_open"): panel.call("set_open",false)

func _typing() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

func _input(event: InputEvent) -> void:
	if not active or not is_instance_valid(_world) or _panels.size()!=3: return
	if _panels[1].call("is_open") and event.is_action_pressed("ui_accept") and not _typing():
		_buy_selected()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel"):
			var open: Node
			for panel in _panels:
				if panel.call("is_open"):
					open = panel
					break
			if open!=null: open.call("set_open",false)
			else: _panels[2].call("set_open",true)
			get_viewport().set_input_as_handled()
			return
		if not _typing() and not _panels[2].call("is_open"):
			for binding in [["build_catalog",0],["tech_tree",1]]:
				if InputMap.has_action(binding[0]) and event.is_action_pressed(binding[0]):
					var panel := _panels[int(binding[1])]
					var was_open: bool = panel.call("is_open")
					close_panels()
					panel.call("set_open",not was_open)
					panel.set_process_input(false)
					get_viewport().set_input_as_handled()
					return
	# Preserve native search, scrolling and menu shortcuts. Purchase shortcuts
	# and opening/closing were handled above before native offline callbacks.
	for panel in _panels:
		if panel.call("is_open") and panel.has_method("_input"):
			panel.call("_input",event)
			break

func _buy_selected() -> void:
	if not active or _panels.size()!=3: return
	var id: Variant = _panels[1].get("_selected")
	if id is String and _panels[1].get("_cards").has(id):
		action_requested.emit("upgrade",{"id":id})

func _card_input(event: InputEvent, original: Callable, id: String) -> void:
	if not active: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
		var select: InputEventMouseButton = event.duplicate()
		select.double_click = false
		original.call(select)
		action_requested.emit("upgrade",{"id":id})
	else: original.call(event)

func _process(_delta: float) -> void:
	for panel in _panels:
		if is_instance_valid(panel): panel.set_process_input(false)
	for record in _disabled:
		if is_instance_valid(record.node): record.node.disabled = true

func detach() -> void:
	active = false
	close_panels()
	for hook in _hooks:
		if not is_instance_valid(hook.node): continue
		if hook.node.is_connected(hook.signal,hook.replacement): hook.node.disconnect(hook.signal,hook.replacement)
		if hook.original.is_valid() and not hook.node.is_connected(hook.signal,hook.original): hook.node.connect(hook.signal,hook.original,hook.flags)
	for record in _modes:
		if not is_instance_valid(record.node): continue
		record.node.process_mode = record.mode
		record.node.set_process_input(record.input)
		record.node.set_process_unhandled_input(record.unhandled)
		record.node.set_process_unhandled_key_input(record.keys)
	for record in _disabled:
		if is_instance_valid(record.node): record.node.disabled = record.disabled
	_hooks.clear()
	_modes.clear()
	_disabled.clear()
	_panels.clear()
	_world = null

func _exit_tree() -> void:
	detach()
