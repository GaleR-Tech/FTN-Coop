extends Node

signal closed(result: Dictionary)

var guest_open := false
var closing := false
var _opening := false
var _adapter: RefCounted
var _epoch := 0
var _directory_id := ""
var _host_cookie := ""

func configure(adapter: RefCounted) -> void:
	_adapter = adapter

func open_guest(state: Dictionary, session_id: String) -> Dictionary:
	var protocol: RefCounted = load(get_script().resource_path.get_base_dir()+"/protocol.gd").new()
	if not protocol.valid_id(session_id): return _error("SNAPSHOT_INVALID")
	if closing or _opening or (guest_open and _host_cookie!=session_id): return _error("GUEST_SESSION_BUSY")
	_epoch += 1
	var epoch := _epoch
	_opening = true
	guest_open = true
	_host_cookie = session_id
	if _directory_id.is_empty(): _directory_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var restored: Dictionary = await _adapter.restore_guest_world(state,_directory_id)
	if epoch!=_epoch: return _error("GUEST_LOAD_CANCELED")
	_opening = false
	if not restored.ok: await close()
	return restored

func save_host() -> Dictionary:
	if guest_open or closing or _opening: return _error("HOST_ONLY")
	return _adapter.save_host_world()

func close() -> void:
	if closing or (not guest_open and not _opening): return
	_epoch += 1
	closing = true
	_adapter.cancel_guest_restore()
	var result: Dictionary = await _adapter.close_guest_world()
	closing = false
	_opening = false
	if result.ok:
		guest_open = false
		_directory_id = ""
		_host_cookie = ""
	closed.emit(result)

func _error(code: String) -> Dictionary:
	return {"ok":false,"code":code,"value":null}
