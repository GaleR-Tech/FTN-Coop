extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/input_bridge.gd"):
		return ["Own input request bridge is not implemented yet."]
	var bridge: Node = load("res://mods/ftn_coop/input_bridge.gd").new()
	var errors: Array[String] = []
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	if bridge.capture_event(event).get("code") != "NO_ACTION":
		errors.append("Disabled bridge must not intercept single-player input.")
	bridge.enabled = true
	var pressed: Dictionary = bridge.capture_event(event)
	if pressed.get("value") != {"kind": "dig", "payload": {"pressed": true}}:
		errors.append("Primary press must become a bounded dig request.")
	event.pressed = false
	if bridge.capture_event(event).get("value") != {"kind": "dig", "payload": {"pressed": false}}:
		errors.append("Primary release must not be lost.")
	event.button_index = MOUSE_BUTTON_RIGHT
	if bridge.capture_event(event).get("code") != "NO_ACTION":
		errors.append("Releasing right click must not throw a second time.")
	event.pressed = true
	if bridge.capture_event(event).get("value")!={"kind":"item_interact","payload":{"operation":"secondary"}}:
		errors.append("Right click must request the native secondary action, separately from throwing a whole tool with F.")
	for row in [[KEY_Q,"drop"],[KEY_F,"throw"]]:
		var key := InputEventKey.new()
		key.physical_keycode = row[0]
		key.pressed = true
		if bridge.capture_event(key).get("value")!={"kind":"item_interact","payload":{"operation":row[1]}}:
			errors.append("Guests must support the native drop/throw keys.")
	_rebinding_checks(bridge,errors)
	tree.root.add_child(bridge)
	var button := Button.new()
	button.position = Vector2(20,20)
	button.size = Vector2(200,80)
	tree.root.add_child(button)
	await tree.process_frame
	var requests: Array = []
	bridge.action_requested.connect(func(kind: String, payload: Dictionary): requests.append([kind,payload]))
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(50,50)
	event.pressed = true
	Input.parse_input_event(event.duplicate())
	await tree.process_frame
	if not requests.is_empty(): errors.append("A click consumed by a menu must never become a world action.")
	event.pressed = false
	Input.parse_input_event(event.duplicate())
	await tree.process_frame
	button.queue_free()
	await tree.process_frame
	requests.clear()
	event.position = Vector2(400,200)
	event.pressed = true
	Input.parse_input_event(event.duplicate())
	await tree.process_frame
	bridge.enabled = false
	if requests.size()!=2 or requests[-1][1].get("pressed")!=false: errors.append("Opening a menu must release an already-held primary action.")
	bridge.queue_free()
	await tree.process_frame
	return errors

func _rebinding_checks(bridge: Node, errors: Array[String]) -> void:
	var saved := {}
	for action in ["primary","secondary","drop_tool"]:
		saved[action] = InputMap.action_get_events(action) if InputMap.has_action(action) else null
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
	for row in [["primary",MOUSE_BUTTON_MIDDLE],["secondary",MOUSE_BUTTON_XBUTTON1],["drop_tool",MOUSE_BUTTON_RIGHT]]:
		var binding := InputEventMouseButton.new()
		binding.button_index = row[1]
		InputMap.action_add_event(row[0],binding)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_P
	InputMap.action_add_event("secondary",keyboard)
	for row in [[MOUSE_BUTTON_LEFT,null],[MOUSE_BUTTON_RIGHT,{"kind":"item_interact","payload":{"operation":"drop"}}],[MOUSE_BUTTON_XBUTTON1,{"kind":"item_interact","payload":{"operation":"secondary"}}],[MOUSE_BUTTON_MIDDLE,{"kind":"dig","payload":{"pressed":true}}]]:
		var event := InputEventMouseButton.new()
		event.button_index = row[0]
		event.pressed = true
		if bridge.capture_event(event).get("value")!=row[1]: errors.append("Guest mouse actions must respect the game's current bindings.")
	keyboard.pressed = true
	if bridge.capture_event(keyboard).get("value")!={"kind":"item_interact","payload":{"operation":"secondary"}}: errors.append("Secondary must also work when rebound to a keyboard key.")
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_RIGHT_X
	axis.axis_value = 1.0
	InputMap.action_add_event("primary",axis)
	if bridge.capture_event(axis).get("value")!={"kind":"dig","payload":{"pressed":true}}: errors.append("Native axis bindings must not assume a mouse/key pressed property.")
	for action in saved:
		InputMap.erase_action(action)
		if saved[action]!=null:
			InputMap.add_action(action)
			for event in saved[action]: InputMap.action_add_event(action,event)
