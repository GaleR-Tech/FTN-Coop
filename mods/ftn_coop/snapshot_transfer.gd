extends Node

signal completed(state: Dictionary, revision: int)
signal failed(code: String)
signal progress_changed(received_bytes: int, total_bytes: int)

const CHUNK_BYTES := 32768
const MAX_PACKED := 64 * 1024 * 1024
const MAX_RAW := 256 * 1024 * 1024
const TIMEOUT := 120.0
var session_id := ""
var last_revision := -1
var last_error := ""
var _header: Dictionary = {}
var _chunks: Dictionary = {}
var _elapsed := 0.0
var _baseline := -1
var _events: Array[Dictionary] = []
var _events_bytes := 0
var _received_bytes := 0

func configure(id: String) -> void:
	if id != session_id: last_revision = -1
	session_id = id
	cancel()

func begin(state: Dictionary, id: String, revision: int) -> Dictionary:
	if not _protocol().valid_id(id) or revision < 0: return _error("INVALID_PAYLOAD")
	var encoded: Dictionary = _codec().encode(state, MAX_RAW)
	if not encoded.ok: return _error("WORLD_TOO_LARGE" if encoded.code == "PAYLOAD_TOO_LARGE" else encoded.code)
	return begin_encoded(encoded.value,id,revision)

# Internal callers may reuse bytes already validated by value_codec.encode.
func begin_encoded(raw: PackedByteArray, id: String, revision: int) -> Dictionary:
	if not _protocol().valid_id(id) or revision < 0 or raw.is_empty(): return _error("INVALID_PAYLOAD")
	if raw.size()>MAX_RAW: return _error("WORLD_TOO_LARGE")
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	if packed.is_empty() or packed.size() > MAX_PACKED: return _error("WORLD_TOO_LARGE")
	var transfer_id := Crypto.new().generate_random_bytes(16).hex_encode()
	_baseline = revision
	_events.clear()
	_events_bytes = 0
	var count := ceili(float(packed.size()) / CHUNK_BYTES)
	var frames: Array[Dictionary] = [{"kind":"SNAPSHOT_BEGIN","session":id,"transfer":transfer_id,"revision":revision,"total_bytes":packed.size(),"raw_bytes":raw.size(),"chunks":count,"sha256":_sha(packed)}]
	# Most live updates fit one chunk. Keep its header and data together so
	# reliable control traffic does not wait for a second queue allowance.
	if count==1:
		frames[0].data = packed
		return _ok({"transfer_id":transfer_id,"revision":revision,"frames":frames})
	for index in range(count):
		frames.append({"kind":"SNAPSHOT_CHUNK","session":id,"transfer":transfer_id,"revision":revision,"index":index,"data":packed.slice(index*CHUNK_BYTES, mini((index+1)*CHUNK_BYTES,packed.size()))})
	return _ok({"transfer_id":transfer_id,"revision":revision,"frames":frames})

func buffer_event(event: Dictionary) -> Dictionary:
	if _baseline < 0 or typeof(event.get("revision")) != TYPE_INT: return _error("INVALID_PAYLOAD")
	if _events.size() >= 4096: return _error("RESYNC_REQUIRED")
	if event.revision != _baseline + _events.size() + 1: return _error("RESYNC_REQUIRED")
	var bytes := var_to_bytes(event).size()
	if _events_bytes + bytes > 8*1024*1024: return _error("RESYNC_REQUIRED")
	_events.append(event.duplicate(true))
	_events_bytes += bytes
	return _ok()

func buffered_events() -> Array[Dictionary]:
	return _events.duplicate(true)

func receive(peer_id: int, frame: Dictionary) -> Dictionary:
	if peer_id != 1: return _error("HOST_ONLY")
	if frame.get("session") != session_id: return _error("SESSION_MISMATCH")
	if not _protocol().valid_id(frame.get("transfer")) or typeof(frame.get("revision")) != TYPE_INT or frame.revision < 0: return _error("INVALID_PAYLOAD")
	if frame.get("kind") == "SNAPSHOT_BEGIN":
		if frame.has("data") and (frame.get("chunks")!=1 or not frame.data is PackedByteArray or frame.data.size()!=frame.get("total_bytes") or frame.data.size()>CHUNK_BYTES): return _error("INVALID_PAYLOAD")
		var begun := _start(frame)
		if not begun.ok or not frame.has("data"): return begun
		return receive(peer_id,{"kind":"SNAPSHOT_CHUNK","session":frame.session,"transfer":frame.transfer,"revision":frame.revision,"index":0,"data":frame.data})
	if frame.get("kind") != "SNAPSHOT_CHUNK": return _error("INVALID_PAYLOAD")
	if _header.is_empty() or frame.transfer != _header.transfer or frame.revision != _header.revision: return _error("TRANSFER_MISMATCH")
	if typeof(frame.get("index")) != TYPE_INT or frame.index < 0 or frame.index >= _header.chunks or not frame.get("data") is PackedByteArray: return _error("INVALID_PAYLOAD")
	var expected: int = CHUNK_BYTES if frame.index < _header.chunks-1 else _header.total_bytes - frame.index*CHUNK_BYTES
	if frame.data.size() != expected: return _error("INVALID_PAYLOAD")
	if _chunks.has(frame.index):
		return _ok() if _chunks[frame.index] == frame.data else _fail("CHUNK_CONFLICT")
	_chunks[frame.index] = frame.data.duplicate()
	_received_bytes += frame.data.size()
	progress_changed.emit(_received_bytes,int(_header.total_bytes))
	if _chunks.size() != _header.chunks: return _ok()
	var packed := PackedByteArray()
	for index in range(_header.chunks): packed.append_array(_chunks[index])
	if _sha(packed) != _header.sha256: return _fail("CHECKSUM_MISMATCH")
	var raw := packed.decompress(_header.raw_bytes, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != _header.raw_bytes: return _fail("DECOMPRESSION_FAILED")
	var decoded: Dictionary = _codec().decode(raw, MAX_RAW)
	if not decoded.ok or not decoded.value is Dictionary: return _fail("SNAPSHOT_INVALID")
	last_revision = _header.revision
	cancel()
	completed.emit(decoded.value, last_revision)
	return _ok()

func _start(frame: Dictionary) -> Dictionary:
	for key in ["total_bytes","raw_bytes","chunks"]:
		if typeof(frame.get(key)) != TYPE_INT or frame[key] <= 0: return _error("INVALID_PAYLOAD")
	if frame.total_bytes > MAX_PACKED or frame.raw_bytes > MAX_RAW: return _error("WORLD_TOO_LARGE")
	if frame.revision <= last_revision: return _error("STALE_REVISION")
	if frame.chunks != ceili(float(frame.total_bytes)/CHUNK_BYTES): return _error("INVALID_PAYLOAD")
	if not frame.get("sha256") is String or frame.sha256.length() != 64: return _error("INVALID_PAYLOAD")
	for character in frame.sha256:
		if not "0123456789abcdef".contains(character): return _error("INVALID_PAYLOAD")
	if not _header.is_empty():
		if frame == _header: return _ok()
		if frame.revision <= _header.revision: return _error("STALE_REVISION")
	cancel()
	_header = frame.duplicate(true)
	progress_changed.emit(0,int(_header.total_bytes))
	return _ok()

func cancel() -> void:
	_header.clear()
	_chunks.clear()
	_received_bytes = 0
	_elapsed = 0.0
	_baseline = -1
	_events.clear()
	_events_bytes = 0

func _process(delta: float) -> void:
	if _header.is_empty(): return
	_elapsed += delta
	if _elapsed >= TIMEOUT: _fail("TRANSFER_TIMEOUT")

func _fail(code: String) -> Dictionary:
	cancel()
	last_error = code
	failed.emit(code)
	return _error(code)

func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _codec() -> RefCounted:
	return load(get_script().resource_path.get_base_dir()+"/value_codec.gd").new()

func _protocol() -> RefCounted:
	return load(get_script().resource_path.get_base_dir()+"/protocol.gd").new()

func _error(code: String) -> Dictionary:
	return {"ok":false,"code":code,"value":null}

func _ok(value: Variant = null) -> Dictionary:
	return {"ok":true,"code":"OK","value":value}
