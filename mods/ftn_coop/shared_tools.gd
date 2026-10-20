extends RefCounted

var _state: Node
var _allowed: Dictionary = {}
var _unlocked: Dictionary = {}
var _updating := false

func configure(state: Node, ids: Array) -> void:
	close()
	_state = state
	for id in ids:
		if id is String and not id.is_empty(): _allowed[id] = true
	_state.connect("tools_changed",_changed)
	_changed()

func _changed() -> void:
	if _updating or not is_instance_valid(_state): return
	_updating = true
	var owned: Dictionary = _state.get("owned_tools").duplicate(true)
	for id in owned:
		if _allowed.has(id) and owned[id]==true: _unlocked[id] = true
	var restored := false
	for id in _unlocked:
		if not owned.has(id):
			owned[id] = true
			restored = true
	if restored:
		_state.set("owned_tools",owned)
		_state.emit_signal("tools_changed")
	_updating = false

func contains(id: String) -> bool:
	return _unlocked.has(id)

func close() -> void:
	if is_instance_valid(_state) and _state.is_connected("tools_changed",_changed):
		_state.disconnect("tools_changed",_changed)
	_state = null
	_allowed.clear()
	_unlocked.clear()
