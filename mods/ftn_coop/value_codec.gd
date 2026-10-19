extends RefCounted

# Explicit data tags: no Resource, Object, Callable or executable deserializer.
const MAX_DEPTH := 32
var _valid := true
var _remaining := 0

func encode(value: Variant, limit: int) -> Dictionary:
	_valid = true
	_remaining = 2000000
	var data: Variant = _pack(value, 0)
	if not _valid:
		return _result(false, "INVALID_PAYLOAD")
	var bytes := JSON.stringify(data, "", false, true).to_utf8_buffer()
	if bytes.size() > limit:
		return _result(false, "PAYLOAD_TOO_LARGE")
	return _result(true, "OK", bytes)

func decode(bytes: PackedByteArray, limit: int) -> Dictionary:
	if bytes.is_empty() or bytes.size() > limit:
		return _result(false, "PAYLOAD_TOO_LARGE" if bytes.size() > limit else "INVALID_PAYLOAD")
	if not _utf8_valid(bytes):
		return _result(false, "INVALID_PAYLOAD")
	var source := bytes.get_string_from_utf8()
	if not _json_bounded(source):
		return _result(false, "INVALID_PAYLOAD")
	var json := JSON.new()
	if json.parse(source) != OK:
		return _result(false, "INVALID_PAYLOAD")
	_valid = true
	_remaining = 2000000
	var value: Variant = _unpack(json.data, 0)
	return _result(true, "OK", value) if _valid else _result(false, "INVALID_PAYLOAD")

func _pack(value: Variant, depth: int) -> Variant:
	_remaining -= 1
	if depth > MAX_DEPTH or _remaining < 0:
		_valid = false
		return null
	match typeof(value):
		TYPE_NIL: return ["n", null]
		TYPE_BOOL: return ["b", value]
		TYPE_INT: return ["i", str(value)]
		TYPE_FLOAT:
			if not is_finite(value): _valid = false
			return ["f", _base64(PackedFloat64Array([value]).to_byte_array())]
		TYPE_STRING, TYPE_STRING_NAME: return ["s", String(value)]
		TYPE_ARRAY:
			var array := []
			for item in value: array.append(_pack(item, depth + 1))
			return ["a", array]
		TYPE_DICTIONARY:
			var entries := []
			for key in value:
				if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT]: _valid = false
				entries.append([_pack(key, depth + 1), _pack(value[key], depth + 1)])
			return ["d", entries]
		TYPE_PACKED_BYTE_ARRAY: return ["u8", _base64(value)]
		TYPE_PACKED_INT32_ARRAY: return ["i32", _base64(value.to_byte_array())]
		TYPE_PACKED_INT64_ARRAY: return ["i64", _base64(value.to_byte_array())]
		TYPE_PACKED_FLOAT32_ARRAY: return ["f32", _base64(value.to_byte_array())]
		TYPE_PACKED_FLOAT64_ARRAY: return ["f64", _base64(value.to_byte_array())]
		TYPE_PACKED_STRING_ARRAY: return ["ss", _pack(Array(value), depth + 1)]
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			var tags := {TYPE_PACKED_VECTOR2_ARRAY:"v2a", TYPE_PACKED_VECTOR3_ARRAY:"v3a", TYPE_PACKED_VECTOR4_ARRAY:"v4a", TYPE_PACKED_COLOR_ARRAY:"ca"}
			return [tags[typeof(value)], _pack(Array(value), depth + 1)]
		TYPE_VECTOR2: return ["v2", [value.x, value.y]]
		TYPE_VECTOR3: return ["v3", [value.x, value.y, value.z]]
		TYPE_VECTOR4: return ["v4", [value.x, value.y, value.z, value.w]]
		TYPE_COLOR: return ["c", [value.r, value.g, value.b, value.a]]
		TYPE_VECTOR2I: return ["v2i", [value.x, value.y]]
		TYPE_VECTOR3I: return ["v3i", [value.x, value.y, value.z]]
		TYPE_BASIS: return ["basis", _pack([value.x, value.y, value.z], depth + 1)]
		TYPE_TRANSFORM3D: return ["t3", _pack([value.basis, value.origin], depth + 1)]
		_:
			_valid = false
			return null

func _unpack(data: Variant, depth: int) -> Variant:
	_remaining -= 1
	if depth > MAX_DEPTH or _remaining < 0 or not data is Array or data.size() != 2 or not data[0] is String:
		_valid = false
		return null
	var tag: String = data[0]
	var body: Variant = data[1]
	match tag:
		"n":
			if body != null: _valid = false
			return null
		"b":
			if not body is bool: _valid = false
			return body
		"i":
			if not body is String or not body.is_valid_int() or str(body.to_int()) != body:
				_valid = false
				return null
			return body.to_int()
		"f":
			if not body is String or not _base64_valid(body):
				_valid = false
				return null
			var raw := Marshalls.base64_to_raw(body)
			if raw.size()!=8:
				_valid = false
				return null
			var number := raw.decode_double(0)
			if not is_finite(number): _valid = false
			return number
		"s":
			if not body is String: _valid = false
			return body
		"a", "d":
			if not body is Array:
				_valid = false
				return null
			if tag == "a":
				var array := []
				for item in body: array.append(_unpack(item, depth + 1))
				return array
			var dictionary := {}
			for entry in body:
				if not entry is Array or entry.size() != 2:
					_valid = false
					return null
				var key: Variant = _unpack(entry[0], depth + 1)
				var value: Variant = _unpack(entry[1], depth + 1)
				if typeof(key) not in [TYPE_STRING, TYPE_INT] or dictionary.has(key):
					_valid = false
					return null
				dictionary[key] = value
			return dictionary
		"u8", "i32", "i64", "f32", "f64":
			if not body is String or not _base64_valid(body):
				_valid = false
				return null
			var raw := Marshalls.base64_to_raw(body) if not body.is_empty() else PackedByteArray()
			var width: int = {"u8":1, "i32":4, "i64":8, "f32":4, "f64":8}[tag]
			if raw.size() % width != 0:
				_valid = false
				return null
			match tag:
				"i32": return raw.to_int32_array()
				"i64": return raw.to_int64_array()
				"f32": return raw.to_float32_array()
				"f64": return raw.to_float64_array()
			return raw
		"v2", "v3", "v4", "c", "v2i", "v3i":
			var length: int = {"v2":2,"v3":3,"v4":4,"c":4,"v2i":2,"v3i":3}[tag]
			if not body is Array or body.size() != length:
				_valid = false
				return null
			for number in body:
				if not (number is int or number is float) or not is_finite(float(number)):
					_valid = false
					return null
			match tag:
				"v2": return Vector2(body[0],body[1])
				"v3": return Vector3(body[0],body[1],body[2])
				"v4": return Vector4(body[0],body[1],body[2],body[3])
				"c": return Color(body[0],body[1],body[2],body[3])
				"v2i": return Vector2i(int(body[0]),int(body[1]))
				"v3i": return Vector3i(int(body[0]),int(body[1]),int(body[2]))
		"basis", "t3", "ss", "v2a", "v3a", "v4a", "ca":
			var array: Variant = _unpack(body, depth + 1)
			if not _valid or not array is Array:
				_valid = false
				return null
			var types := {"ss":TYPE_STRING,"v2a":TYPE_VECTOR2,"v3a":TYPE_VECTOR3,"v4a":TYPE_VECTOR4,"ca":TYPE_COLOR}
			if types.has(tag):
				for item in array:
					if typeof(item) != types[tag]: _valid = false
				if not _valid: return null
				match tag:
					"ss": return PackedStringArray(array)
					"v2a": return PackedVector2Array(array)
					"v3a": return PackedVector3Array(array)
					"v4a": return PackedVector4Array(array)
					"ca": return PackedColorArray(array)
			if tag == "basis" and array.size() == 3 and array[0] is Vector3 and array[1] is Vector3 and array[2] is Vector3:
				return Basis(array[0],array[1],array[2])
			if tag == "t3" and array.size() == 2 and array[0] is Basis and array[1] is Vector3:
				return Transform3D(array[0],array[1])
	_valid = false
	return null

func _base64_valid(value: String) -> bool:
	if value.length() % 4 != 0: return false
	var padding := false
	var count := 0
	for character in value:
		if character == "=":
			padding = true
			count += 1
		elif padding or not "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".contains(character):
			return false
	return count <= 2

func _base64(value: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(value) if not value.is_empty() else ""

func _utf8_valid(bytes: PackedByteArray) -> bool:
	var index := 0
	while index < bytes.size():
		var first: int = bytes[index]
		if first < 128:
			index += 1
			continue
		var length := 2 if first >= 0xc2 and first <= 0xdf else (3 if first >= 0xe0 and first <= 0xef else (4 if first >= 0xf0 and first <= 0xf4 else 0))
		if length == 0 or index + length > bytes.size(): return false
		for offset in range(1, length):
			if bytes[index+offset] < 0x80 or bytes[index+offset] > 0xbf: return false
		var second: int = bytes[index+1]
		if (first == 0xe0 and second < 0xa0) or (first == 0xed and second > 0x9f) or (first == 0xf0 and second < 0x90) or (first == 0xf4 and second > 0x8f): return false
		index += length
	return true

func _json_bounded(value: String) -> bool:
	var depth := 0
	var quoted := false
	var escaped := false
	var index := 0
	while index < value.length():
		var character := value[index]
		if quoted:
			if escaped:
				# Our encoder writes Unicode directly. Reject surrogate escape input
				# before Godot's permissive JSON parser can emit Unicode errors.
				if character == "u" and index + 4 < value.length():
					var hex := value.substr(index+1,4).to_lower()
					if hex.begins_with("d8") or hex.begins_with("d9") or hex.begins_with("da") or hex.begins_with("db") or hex.begins_with("dc") or hex.begins_with("dd") or hex.begins_with("de") or hex.begins_with("df"): return false
				escaped = false
			elif character == "\\": escaped = true
			elif character == '"': quoted = false
		elif character == '"': quoted = true
		elif character in "0123456789-":
			var start := index
			while index < value.length() and value[index] in "0123456789.eE+-": index += 1
			var number := value.substr(start,index-start).to_lower()
			if number.length() > 32: return false
			var exponent := number.find("e")
			if exponent >= 0 and absi(number.substr(exponent+1).to_int()) > 324: return false
			continue
		elif character == "[" or character == "{":
			depth += 1
			if depth > 132: return false
		elif character == "]" or character == "}": depth -= 1
		index += 1
	return not quoted and depth == 0

func _result(ok: bool, code: String, value: Variant = null) -> Dictionary:
	return {"ok":ok,"code":code,"value":value}
