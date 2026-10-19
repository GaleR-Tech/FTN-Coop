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
		errors.append("Unmapped input must not invoke a game action.")
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
