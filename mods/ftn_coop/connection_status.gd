extends RefCounted

var _pending: Dictionary = {}
var _samples: Dictionary = {}
var _serial := 0

func begin(peer: int, now_ms: int) -> Dictionary:
	if peer<=1 or now_ms<0 or (not _pending.has(peer) and _pending.size()>=3): return _error()
	if _pending.has(peer) and now_ms-_pending[peer].sent<9000: return _error()
	_serial += 1
	_pending[peer] = {"token":_serial,"sent":now_ms}
	return {"ok":true,"code":"OK","value":_serial}

func accept_reply(peer: int, token: int, now_ms: int) -> Dictionary:
	if not _pending.has(peer) or token!=_pending[peer].token: return _error()
	var elapsed: int = now_ms-_pending[peer].sent
	if elapsed<0 or elapsed>9000: return _error()
	_pending.erase(peer)
	_samples[peer] = {"latency_ms":elapsed,"received":now_ms}
	return {"ok":true,"code":"OK","value":elapsed}

func snapshot(peer: int, now_ms: int) -> Dictionary:
	if not _samples.has(peer) or now_ms-_samples[peer].received>9000: return {"latency_ms":-1}
	return {"latency_ms":_samples[peer].latency_ms}

func remove_peer(peer: int) -> void:
	_pending.erase(peer)
	_samples.erase(peer)

func clear() -> void:
	_pending.clear()
	_samples.clear()

func _error() -> Dictionary: return {"ok":false,"code":"STATUS_INVALID","value":null}
