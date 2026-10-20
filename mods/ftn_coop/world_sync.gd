extends Node

signal confirmed(event: Dictionary)
signal resync_required

const ACTIONS := ["dig","place","demolish","purchase","upgrade","needle_collect","item_interact","machine_config"]
var revision := 0
var is_host := false
var last_resync_reason := ""
var _adapter: RefCounted
var _ready_peers: Dictionary = {}
var _last: Dictionary = {}
var _applying := false

func configure(adapter: RefCounted, host: bool) -> void:
	_adapter = adapter
	is_host = host
	revision = 0
	last_resync_reason = ""
	_ready_peers.clear()
	_last.clear()

func set_ready(peer: int, ready: bool) -> void:
	if ready and peer > 0: _ready_peers[peer] = true
	else:
		_ready_peers.erase(peer)

func remove_peer(peer: int) -> void:
	_ready_peers.erase(peer)
	_last.erase(peer)

func checkpoint() -> Dictionary:
	if not is_host: return _error("HOST_ONLY")
	return {"ok":true,"code":"OK","value":_confirm({"kind":"checkpoint","patch":{}})}

func submit_action(actor: int, sequence: int, kind: String, payload: Dictionary) -> Dictionary:
	if not is_host: return _error("HOST_ONLY")
	if not _ready_peers.has(actor): return _error("PEER_NOT_READY")
	if sequence <= 0 or sequence > 9007199254740991 or kind not in ACTIONS: return _error("ACTION_INVALID")
	if _applying: return _error("ACTION_BUSY")
	if _last.has(actor):
		if sequence == _last[actor].sequence:
			if kind != _last[actor].kind or payload != _last[actor].payload: return _error("SEQUENCE_CONFLICT")
			return _last[actor].result.duplicate(true)
		if sequence < _last[actor].sequence: return _error("STALE_ACTION")
	# Observe earlier native/automatic changes before advancing the remote action.
	poll()
	_applying = true
	var result: Dictionary = _adapter.apply_host_action(actor,kind,payload)
	if result.ok:
		var event := _confirm(result.value)
		result = {"ok":true,"code":"OK","value":event}
	_last[actor] = {"sequence":sequence,"kind":kind,"payload":payload.duplicate(true),"result":result.duplicate(true)}
	_applying = false
	return result

func poll() -> void:
	if not is_host or _applying or _adapter == null: return
	for event in _adapter.poll_host_events(): _confirm(event)

func _confirm(event: Dictionary) -> Dictionary:
	revision += 1
	var confirmed_event := event.duplicate(true)
	confirmed_event.revision = revision
	confirmed.emit(confirmed_event)
	return confirmed_event

func accept_baseline(value: int) -> Dictionary:
	if is_host or value < 0: return _error("INVALID_PAYLOAD")
	revision = value
	last_resync_reason = ""
	return _ok()

func accept_event(sender: int, event: Dictionary) -> Dictionary:
	if is_host or sender != 1: return _error("HOST_ONLY")
	if typeof(event.get("revision")) != TYPE_INT: return _error("INVALID_PAYLOAD")
	if event.revision <= revision: return _error("STALE_REVISION")
	if event.revision != revision + 1:
		last_resync_reason = "REVISION_GAP"
		resync_required.emit()
		return _error("RESYNC_REQUIRED")
	var result: Dictionary = _adapter.apply_confirmed_event(event)
	if result.ok: revision = event.revision
	else:
		last_resync_reason = str(result.code)
		resync_required.emit()
	return result

func _error(code: String) -> Dictionary:
	return {"ok":false,"code":code,"value":null}

func _ok() -> Dictionary:
	return {"ok":true,"code":"OK","value":null}
