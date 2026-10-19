extends RefCounted

const MAX_PACKET := 65536
const TYPES := ["HELLO","WELCOME","REJECT","ROSTER","WORLD_REQUEST","SNAPSHOT_BEGIN","SNAPSHOT_CHUNK","WORLD_READY","ACTION","ACTION_RESULT","EVENT","POSE","RESYNC","MARKER_REQUEST","MARKERS","STATUS_PROBE","STATUS_REPLY","PLAYER_STATUS","LOAD_STATUS"]

func encode(message: Dictionary) -> Dictionary:
	if not _envelope_valid(message): return _error("INVALID_PAYLOAD")
	return _codec().encode(message, MAX_PACKET)

func decode(bytes: PackedByteArray) -> Dictionary:
	var result: Dictionary = _codec().decode(bytes, MAX_PACKET)
	if not result.ok: return result
	if not result.value is Dictionary or not _envelope_valid(result.value): return _error("INVALID_PAYLOAD")
	return result

func _envelope_valid(message: Dictionary) -> bool:
	if message.size() != 4 or typeof(message.get("protocol")) != TYPE_INT or message.protocol != 1: return false
	if not message.get("type") is String or message.type not in TYPES or not message.get("session") is String or not message.get("body") is Dictionary: return false
	if message.session == "": return message.type in ["HELLO", "REJECT"]
	return valid_id(message.session)

func valid_id(value: Variant) -> bool:
	if not value is String or value.length() != 32: return false
	for character in value:
		if not "0123456789abcdef".contains(character): return false
	return true

func _codec() -> RefCounted:
	return load(get_script().resource_path.get_base_dir() + "/value_codec.gd").new()

func _error(code: String) -> Dictionary:
	return {"ok":false,"code":code,"value":null}
