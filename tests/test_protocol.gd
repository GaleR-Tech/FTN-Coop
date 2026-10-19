extends RefCounted

func run(_tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/protocol.gd"):
		return ["Validated network protocol is not implemented yet."]
	var protocol: RefCounted = load("res://mods/ftn_coop/protocol.gd").new()
	var errors: Array[String] = []
	var codec: RefCounted = load("res://mods/ftn_coop/value_codec.gd").new()
	for scalar in [13762253.93678915,14.5727403333333,0.1,-0.0,1.0e-200,1.0e200]:
		var packed: Dictionary = codec.encode(scalar,1024)
		var unpacked: Dictionary = codec.decode(packed.value,1024)
		if not unpacked.ok or PackedFloat64Array([unpacked.value]).to_byte_array()!=PackedFloat64Array([scalar]).to_byte_array():
			errors.append("Native double precision scalars must preserve their exact bits across the wire: "+str(scalar))
	var message := {"protocol": 1, "type": "HELLO", "session": "", "body": {
		"integer": 9223372036854775807, "indexed": {7: "needle"},
		"transform": Transform3D(Basis.IDENTITY, Vector3(1.25, 2.0, -3.0)),
		"field": PackedFloat32Array([0.5, 1.25]), "positions": PackedVector3Array([Vector3(1,2,3)]),
		"empty_bytes": PackedByteArray(), "empty_floats": PackedFloat32Array(),
	}}
	var encoded: Dictionary = protocol.encode(message)
	if not encoded.get("ok", false):
		return ["Valid message failed to encode."]
	var decoded: Dictionary = protocol.decode(encoded.value)
	if not decoded.get("ok", false) or decoded.value != message:
		errors.append("Native math, packed arrays, integer keys and 64-bit integers must round-trip exactly.")
	var native_keys := message.duplicate(true)
	native_keys.body[StringName("native_key")] = 7
	var native_encoded: Dictionary = protocol.encode(native_keys)
	if not native_encoded.ok or protocol.decode(native_encoded.value).value != native_keys:
		errors.append("Godot StringName dictionary keys from runtime/dot assignment must round-trip as safe strings.")
	var unsafe := message.duplicate(true)
	unsafe.body = {"object": RefCounted.new()}
	if protocol.encode(unsafe).get("code") != "INVALID_PAYLOAD":
		errors.append("Objects must never be serialized into a network message.")
	if protocol.decode(var_to_bytes_with_objects(RefCounted.new())).get("code") != "INVALID_PAYLOAD":
		errors.append("Foreign binary object data must be rejected before decoding.")
	if protocol.decode(PackedByteArray([255, 255])).get("code") != "INVALID_PAYLOAD":
		errors.append("Invalid UTF-8 must fail without a script error.")
	var oversized := message.duplicate(true)
	oversized.body = {"data": PackedByteArray()}
	oversized.body.data.resize(65537)
	if protocol.encode(oversized).get("code") != "PAYLOAD_TOO_LARGE":
		errors.append("Oversized messages must not be sent.")
	var deep: Dictionary = {}
	var cursor: Dictionary = deep
	for index in range(40):
		cursor.child = {}
		cursor = cursor.child
	unsafe = message.duplicate(true)
	unsafe.body = deep
	if protocol.encode(unsafe).get("code") != "INVALID_PAYLOAD":
		errors.append("Over-deep data must not be serialized.")
	for invalid in [message.merged({"protocol":2},true), message.merged({"type":"EXECUTE"},true), message.merged({"session":"other"},true)]:
		if protocol.encode(invalid).code != "INVALID_PAYLOAD": errors.append("Invalid envelopes must be rejected.")
	for invalid in ['["f",1e9999]', '["v3",[0,0]]', '["i","9223372036854775808"]', '["s","\\ud800"]', '["u8","===="]']:
		if protocol.decode(invalid.to_utf8_buffer()).code != "INVALID_PAYLOAD": errors.append("Malformed typed data must fail safely.")
	return errors
