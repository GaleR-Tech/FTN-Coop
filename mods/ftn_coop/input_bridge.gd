extends Node

signal action_requested(kind: String, payload: Dictionary)

var _primary_held := false
var enabled := false:
	set(value):
		if enabled and not value and _primary_held:
			_primary_held = false
			action_requested.emit("dig",{"pressed":false})
		enabled = value

func capture_event(event: InputEvent) -> Dictionary:
	if not enabled:
		return {"ok": false, "code": "NO_ACTION", "value": null}
	if event.is_echo(): return {"ok":false,"code":"NO_ACTION","value":null}
	if _matches(event,"primary",0,MOUSE_BUTTON_LEFT):
		return {"ok": true, "code": "OK", "value": {"kind": "dig", "payload": {"pressed": event.is_pressed()}}}
	if event.is_pressed():
		var actions := [["secondary",0,MOUSE_BUTTON_RIGHT,"item_interact",{"operation":"secondary"}],["interact",KEY_E,0,"item_interact",{"operation":"pick"}],["drop_tool",KEY_Q,0,"item_interact",{"operation":"drop"}],["throw_item",KEY_F,0,"item_interact",{"operation":"throw"}],["dismantle",KEY_X,0,"demolish",{}]]
		for action in actions:
			if _matches(event,action[0],action[1],action[2]):
				return {"ok":true,"code":"OK","value":{"kind":action[3],"payload":action[4]}}
	return {"ok": false, "code": "NO_ACTION", "value": null}

func _matches(event: InputEvent, action: String, key: int, mouse: int) -> bool:
	if InputMap.has_action(action): return event.is_action(action)
	return (key!=0 and event is InputEventKey and event.physical_keycode==key) or (mouse!=0 and event is InputEventMouseButton and event.button_index==mouse)

func _unhandled_input(event: InputEvent) -> void:
	var action := capture_event(event)
	if action.ok:
		if action.value.kind=="dig": _primary_held = action.value.payload.pressed
		action_requested.emit(action.value.kind, action.value.payload)
		get_viewport().set_input_as_handled()
