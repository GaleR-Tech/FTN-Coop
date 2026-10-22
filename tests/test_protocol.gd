extends RefCounted

func _table_checks(codec: RefCounted, errors: Array[String]) -> void:
	var records := []
	for index in range(120):
		records.append({"id":"hay_wad","state":{"strands":100,"nested":[1,2]},"distance":float(index)*0.123456789,"serial":9223372036854775807-index,"xform":Transform3D(Basis(Vector3.UP,float(index)*0.17),Vector3(index,1.25,-2))})
	var encoded: Dictionary = codec.encode(records,1024*1024)
	var decoded: Dictionary = codec.decode(encoded.value,1024*1024)
	if not decoded.ok or decoded.value!=records: errors.append("Columnar native records must preserve transforms, scalar precision, nested state and int64 IDs exactly.")
	if encoded.value.size()>26000: errors.append("Repeated native records must use bounded columns instead of repeating every key and transform tag.")
	if decoded.ok:
		decoded.value[0].state.nested[0] = 99
		if decoded.value[1].state.nested[0]!=1: errors.append("Repeated table values must decode into independently mutable native records.")
	var mixed := [{"v":{"number":1}},{"v":{"number":1.0}},{"v":{"number":1}},{"v":{"number":1.0}}]
	var mixed_wire: Dictionary = codec.encode(mixed,1024*1024)
	var mixed_read: Dictionary = codec.decode(mixed_wire.value,1024*1024)
	if not mixed_read.ok or typeof(mixed_read.value[0].v.number)!=TYPE_INT or typeof(mixed_read.value[1].v.number)!=TYPE_FLOAT:
		errors.append("Equal scalar values with different native types must keep those types inside constant-looking table cells.")
	var zeros := [{"v":0.0},{"v":-0.0},{"v":0.0},{"v":-0.0}]
	var zero_wire: Dictionary = codec.encode(zeros,1024*1024)
	var zero_read: Dictionary = codec.decode(zero_wire.value,1024*1024)
	if not zero_read.ok or PackedFloat64Array([zero_read.value[0].v,zero_read.value[1].v]).to_byte_array()!=PackedFloat64Array([0.0,-0.0]).to_byte_array():
		errors.append("Constant-looking table columns must preserve signed zero bits.")
	var deep_table: Array = ["i","1"]
	for index in range(17): deep_table = ["rows",[4,[[["s","v"],["one",deep_table]]]]]
	if codec.decode(JSON.stringify(deep_table).to_utf8_buffer(),1024*1024).ok: errors.append("Compact tables must enforce the depth of their expanded native records.")
	var empty_table: Array = ["rows",[4,[]]]
	var deep_records: Array = [{},{},{},{}]
	for index in range(32):
		empty_table = ["a",[empty_table]]
		deep_records = [deep_records]
	if codec.decode(JSON.stringify(empty_table).to_utf8_buffer(),1024*1024).ok or codec.encode(deep_records,1024*1024).ok:
		errors.append("Even an empty table row must count its dictionary level toward the logical depth limit.")
	var packed_rows := []
	for index in range(4): packed_rows.append({"direct":PackedByteArray([1,2]),"nested":{"bytes":PackedInt32Array([1,2])}})
	var packed_wire: Dictionary = codec.encode(packed_rows,1024*1024)
	var packed_read: Dictionary = codec.decode(packed_wire.value,1024*1024)
	if packed_read.ok:
		packed_read.value[0].direct[0] = 99
		packed_read.value[0].nested.bytes[0] = 99
		if packed_read.value[1].direct[0]!=1 or packed_read.value[1].nested.bytes[0]!=1: errors.append("Repeated packed arrays must remain independently mutable, including nested native state.")
	var huge := PackedByteArray()
	huge.resize(700000)
	var expansion := ["rows",[4,[[["s","v"],["one",["u8",Marshalls.raw_to_base64(huge)]]]]]]
	if codec.decode(JSON.stringify(expansion).to_utf8_buffer(),1024*1024).ok: errors.append("Constant cells must charge their expanded payload against the decode budget before copying.")
	var invalid := [
		["rows",[2000001,[]]],
		["rows",[4,[[["s","x"],["many",["a",[["i","1"]]]]]]]],
		["rows",[4,[[["s","x"],["one",["i","1"]]],[["s","x"],["one",["i","2"]]]]]],
		["rows",[4,[[["s","x"],["xforms",["f64",""]]]]]],
		["rows",[4,[[["s","x"],["one",["object",1]]]]]],
	]
	for value in invalid:
		if codec.decode(JSON.stringify(value).to_utf8_buffer(),1024*1024).ok: errors.append("Malformed table dimensions, columns, duplicate keys and object tags must fail before native use.")

func run(_tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/protocol.gd"):
		return ["Validated network protocol is not implemented yet."]
	var protocol: RefCounted = load("res://mods/ftn_coop/protocol.gd").new()
	var errors: Array[String] = []
	var codec: RefCounted = load("res://mods/ftn_coop/value_codec.gd").new()
	_table_checks(codec,errors)
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
