extends RefCounted

# Arm save export clears carried material. Disabled, hidden export copies keep
# the native schema without running native setup, cleanup or save accounting.
const LIFECYCLE := "\nfunc _ready() -> void:\n\tpass\nfunc _exit_tree() -> void:\n\tpass\nfunc _enter_tree() -> void:\n\tpass\n"
const GUARD := "\nfunc _credit_the_undrawn() -> void:\n\tpass\n"
var _source: WeakRef
var _root: Node3D
var _manager: Node
var _arms: Dictionary = {}
var _scripts: Dictionary = {}

func capture(manager: Node) -> Dictionary:
	if not is_instance_valid(manager) or not manager.has_method("to_array"): return _error()
	var arms: Variant = manager.get("robotic_arms")
	if not arms is Array or arms.is_empty():
		close()
		return _ok(manager.call("to_array").duplicate(true))
	for arm in arms:
		if not is_instance_valid(arm) or not arm is Node3D or arm.get_script()==null or not arm.has_method("_credit_the_undrawn"): return _error()
	if manager.get_script()==null: return _error()
	if _source==null or _source.get_ref()!=manager or not is_instance_valid(_manager):
		close()
		_source = weakref(manager)
		_root = Node3D.new()
		_root.name = "FtnCoopLiveBuildCapture"
		_root.process_mode = Node.PROCESS_MODE_DISABLED
		_root.visible = false
		if manager.is_inside_tree(): manager.get_tree().root.add_child(_root)
		var manager_script := _copy_script(manager.get_script(),false)
		if manager_script==null:
			close()
			return _error()
		_manager = manager_script.new()
		_manager.process_mode = Node.PROCESS_MODE_DISABLED
		_root.add_child(_manager)
	_mirror(manager,_manager)
	if manager is Node3D and _manager is Node3D: _manager.transform = manager.global_transform if manager.is_inside_tree() else manager.transform
	var copies: Array = arms.duplicate()
	copies.clear()
	for arm in arms:
		if not _arms.has(arm):
			var original: Script = arm.get_script()
			var script := _copy_script(original,true)
			if script==null: return _error()
			_arms[arm] = script.new()
			_arms[arm].process_mode = Node.PROCESS_MODE_DISABLED
			_manager.add_child(_arms[arm])
		var copy: Node3D = _arms[arm]
		_mirror(arm,copy)
		copy.transform = arm.transform
		copies.append(copy)
	for arm in _arms.keys():
		if not is_instance_valid(arm) or not arms.has(arm):
			_arms[arm].free()
			_arms.erase(arm)
	_manager.set("robotic_arms",copies)
	var rows: Variant = _manager.call("to_array")
	return _ok(rows.duplicate(true)) if rows is Array else _error()

func _copy_script(original: Script, arm: bool) -> Script:
	if not original.resource_path.begins_with("res://"): return null
	if _scripts.has(original): return _scripts[original]
	var script := GDScript.new()
	script.source_code = "extends "+JSON.stringify(original.resource_path)+"\n"+LIFECYCLE+(GUARD if arm else "")
	if script.reload()!=OK: return null
	_scripts[original] = script
	return script

func _mirror(source: Node, target: Node) -> void:
	for property in source.get_script().get_script_property_list():
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)==0: continue
		var value: Variant = source.get(property.name)
		if value is Array or value is Dictionary: value = value.duplicate(true)
		target.set(property.name,value)

func close() -> void:
	if is_instance_valid(_root): _root.free()
	_root = null
	_arms.clear()
	_scripts.clear()
	_manager = null
	_source = null

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:
		if is_instance_valid(_root): _root.free()

func _ok(value: Variant=null) -> Dictionary:
	return {"ok":true,"code":"OK","value":value}

func _error() -> Dictionary:
	return {"ok":false,"code":"CAPABILITY_MISSING","value":null}
