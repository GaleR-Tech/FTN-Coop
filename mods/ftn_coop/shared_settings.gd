extends RefCounted

# Native V66 setter ranges, checked against the supported demo build.
const SCHEMA := {
	"prop_cap":[TYPE_INT,20,1500],
	"prop_decay":[TYPE_BOOL],
	"belt_cap":[TYPE_INT,20,5000],
	"belt_decay":[TYPE_BOOL],
	"auto_clean":[TYPE_BOOL],
	"auto_clean_seconds":[TYPE_FLOAT,15.0,600.0],
	"grid_lock":[TYPE_BOOL],
	"autosave":[TYPE_BOOL],
	"autosave_seconds":[TYPE_FLOAT,60.0,1800.0],
}

var _config: Node
var _original: Dictionary = {}
var _required: Dictionary = {}
var _original_readonly := false

func configure(config: Node) -> void:
	if _original.is_empty() or config==_config: _config = config

func validate(values: Variant) -> Dictionary:
	if not values is Dictionary or values.size()!=SCHEMA.size(): return _error("SETTINGS_INVALID")
	var normalized := {}
	for key in SCHEMA:
		if not values.has(key): return _error("SETTINGS_INVALID")
		var rule: Array = SCHEMA[key]
		var value: Variant = values[key]
		if rule[0]==TYPE_FLOAT:
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return _error("SETTINGS_INVALID")
			value = float(value)
		elif typeof(value)!=rule[0]: return _error("SETTINGS_INVALID")
		if rule.size()>1 and (value<rule[1] or value>rule[2]): return _error("SETTINGS_INVALID")
		normalized[key] = value
	return _ok(normalized)

func capture() -> Dictionary:
	if not _available(): return _error("CAPABILITY_MISSING")
	var values := {}
	for key in SCHEMA: values[key] = _config.get(key)
	return validate(values)

func accept(values: Variant) -> Dictionary:
	var checked := validate(values)
	if not checked.ok: return checked
	var current := capture()
	if not current.ok: return current
	if _original.is_empty():
		_original = current.value
		_original_readonly = _config.get("settings_readonly")
	_required = checked.value
	return enforce()

func enforce() -> Dictionary:
	if _original.is_empty(): return _ok()
	if not _available(): return _error("CAPABILITY_MISSING")
	# The native writer must never persist temporary host values. Personal
	# changes remain live and are saved after the original gameplay is restored.
	_config.set("settings_readonly",true)
	for key in SCHEMA: _config.set(key,_required[key])
	return _ok()

func release() -> void:
	if _original.is_empty(): return
	if is_instance_valid(_config):
		_config.set("settings_readonly",true)
		for key in SCHEMA: _config.set(key,_original[key])
		_config.set("settings_readonly",_original_readonly)
		if not _original_readonly: _config.call("save_settings")
	_original.clear()
	_required.clear()

func update_host(key: String, value: Variant) -> Dictionary:
	if not _original.is_empty(): return _error("HOST_ONLY")
	if not SCHEMA.has(key): return _error("SETTINGS_INVALID")
	var current := capture()
	if not current.ok: return current
	current.value[key] = value
	var checked := validate(current.value)
	if not checked.ok: return checked
	if not _config.has_method("set_"+key): return _error("CAPABILITY_MISSING")
	_config.call("set_"+key,checked.value[key])
	return capture()

func update_host_values(values: Variant) -> Dictionary:
	if not _original.is_empty(): return _error("HOST_ONLY")
	var checked := validate(values)
	if not checked.ok: return checked
	var before := capture()
	if not before.ok: return before
	for key in SCHEMA:
		if not _config.has_method("set_"+key): return _error("CAPABILITY_MISSING")
	var readonly: bool = _config.get("settings_readonly")
	_config.set("settings_readonly",true)
	for key in SCHEMA: _config.call("set_"+key,checked.value[key])
	var applied := capture()
	if not applied.ok or applied.value!=checked.value:
		for key in SCHEMA: _config.set(key,before.value[key])
		_config.set("settings_readonly",readonly)
		return _error("SETTINGS_INVALID")
	_config.set("settings_readonly",readonly)
	if not readonly: _config.call("save_settings")
	return applied

func _available() -> bool:
	if not is_instance_valid(_config) or not _config.has_method("save_settings"): return false
	var available := {}
	for field in _config.get_property_list(): available[field.name] = true
	for key in SCHEMA:
		if not available.has(key): return false
	return available.has("settings_readonly") and typeof(_config.get("settings_readonly"))==TYPE_BOOL

func _ok(value: Variant=null) -> Dictionary: return {"ok":true,"code":"OK","value":value}
func _error(code: String) -> Dictionary: return {"ok":false,"code":code,"value":null}
