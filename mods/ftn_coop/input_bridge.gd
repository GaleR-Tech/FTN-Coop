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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return {"ok": true, "code": "OK", "value": {"kind": "dig", "payload": {"pressed": event.pressed}}}
	if event is InputEventKey and event.pressed and not event.echo:
		var actions := {KEY_E:["item_interact",{"operation":"pick"}],KEY_G:["item_interact",{"operation":"drop"}],KEY_R:["item_interact",{"operation":"throw"}],KEY_DELETE:["demolish",{}]}
		if actions.has(event.physical_keycode):
			var action: Array = actions[event.physical_keycode]
			return {"ok":true,"code":"OK","value":{"kind":action[0],"payload":action[1]}}
	return {"ok": false, "code": "NO_ACTION", "value": null}

func _unhandled_input(event: InputEvent) -> void:
	var action := capture_event(event)
	if action.ok:
		if action.value.kind=="dig": _primary_held = action.value.payload.pressed
		action_requested.emit(action.value.kind, action.value.payload)
		get_viewport().set_input_as_handled()
