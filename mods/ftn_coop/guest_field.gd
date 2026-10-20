extends RefCounted

# Install before fields are instantiated: changing a live script instance can
# invalidate references held by native mesh workers. Keep the native renderer
# and gate only host-authoritative simulation, separately for every field.
const NATIVE := "res://scripts/hay/hay_field.gd"
const GUARD := """
var _ftn_guest_field := false
func ftn_set_guest_field(value: bool) -> void:
	if value and not _ftn_guest_field:
		super.settle_join()
		super._clear_relax_queue()
	_ftn_guest_field = value
func _apply_relax() -> void:
	if not _ftn_guest_field: super._apply_relax()
func _settle() -> void:
	if not _ftn_guest_field: super._settle()
func _start_settle(marks: bool) -> void:
	if not _ftn_guest_field: super._start_settle(marks)
func _tick_last_of_pile(delta: float) -> void:
	if not _ftn_guest_field: super._tick_last_of_pile(delta)
func _relax_once(budget: int, deadline: int=0) -> Dictionary:
	return super._relax_once(0,1) if _ftn_guest_field else super._relax_once(budget,deadline)
"""

static var _installed: Dictionary = {}
var _field: WeakRef

static func install(native: Script=null) -> Dictionary:
	if native==null:
		if not ResourceLoader.exists(NATIVE): return _error()
		native = load(NATIVE)
	if native==null or not native.resource_path.begins_with("res://"): return _error()
	var path := native.resource_path
	if _installed.has(path): return _ok(_installed[path])
	var script := GDScript.new()
	script.source_code = "extends "+JSON.stringify(path)+"\n"+GUARD
	if script.reload()!=OK: return _error()
	script.take_over_path(path)
	_installed[path] = script
	return _ok(script)

func configure(field: Node) -> Dictionary:
	if _field!=null and _field.get_ref()==field: return _ok()
	if not is_instance_valid(field) or not field.has_method("ftn_set_guest_field"): return _error()
	restore()
	field.call("ftn_set_guest_field",true)
	_field = weakref(field)
	return _ok()

func pump(delta: float) -> void:
	var field: Variant = _field.get_ref() if _field!=null else null
	if is_instance_valid(field): field.call("_process",delta)

func restore() -> void:
	var field: Variant = _field.get_ref() if _field!=null else null
	if is_instance_valid(field): field.call("ftn_set_guest_field",false)
	_field = null

static func _ok(value: Variant=null) -> Dictionary: return {"ok":true,"code":"OK","value":value}
static func _error() -> Dictionary: return {"ok":false,"code":"CAPABILITY_MISSING","value":null}
