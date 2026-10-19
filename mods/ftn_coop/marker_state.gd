extends RefCounted

const KINDS := ["point","build","needle","help"]
var _markers: Dictionary = {}
var _cooldowns: Dictionary = {}

func place(peer: int, position: Vector3, kind: String, origin: Vector3) -> Dictionary:
	if peer<=0 or not position.is_finite() or not origin.is_finite() or position.length()>2048.0 or origin.distance_to(position)>50.0 or kind not in KINDS:
		return _error("MARKER_INVALID")
	if _cooldowns.get(peer,0.0)>0.0: return _error("MARKER_RATE_LIMIT")
	if not _markers.has(peer) and _markers.size()>=4: return _error("MARKER_INVALID")
	_markers[peer] = {"peer":peer,"position":position,"kind":kind,"remaining":20.0}
	_cooldowns[peer] = 1.0
	return {"ok":true,"code":"OK","value":_markers[peer].duplicate()}

func advance(delta: float) -> void:
	if not is_finite(delta) or delta<0: return
	for peer in _markers.keys():
		_markers[peer].remaining -= delta
		if _markers[peer].remaining<=0: _markers.erase(peer)
	for peer in _cooldowns.keys():
		_cooldowns[peer] -= delta
		if _cooldowns[peer]<=0: _cooldowns.erase(peer)

func snapshot() -> Array:
	return _markers.values().duplicate(true)

func accept_snapshot(rows: Variant) -> Dictionary:
	if not rows is Array or rows.size()>4: return _error("MARKER_INVALID")
	var checked := {}
	for row in rows:
		if not row is Dictionary or row.size()!=4 or typeof(row.get("peer"))!=TYPE_INT or row.peer<=0 or checked.has(row.peer): return _error("MARKER_INVALID")
		if not row.get("position") is Vector3 or not row.position.is_finite() or row.position.length()>2048.0 or row.get("kind") not in KINDS: return _error("MARKER_INVALID")
		if typeof(row.get("remaining")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(row.remaining)) or row.remaining<=0 or row.remaining>20: return _error("MARKER_INVALID")
		checked[row.peer] = row.duplicate()
	_markers = checked
	return {"ok":true,"code":"OK","value":null}

func remove_peer(peer: int) -> void:
	_markers.erase(peer)
	_cooldowns.erase(peer)

func clear() -> void:
	_markers.clear()
	_cooldowns.clear()

func _error(code: String) -> Dictionary: return {"ok":false,"code":code,"value":null}
