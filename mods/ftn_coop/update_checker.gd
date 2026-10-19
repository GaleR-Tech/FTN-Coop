extends Node

signal completed(result: Dictionary)
const ENDPOINT := "https://api.github.com/repos/GaleR-Tech/FTN-Coop/releases/latest"
var _client: Node
var _current := ""
var _busy := false
var _cooldown := 0.0

func _init(client: Node=null) -> void: _client = client

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _client==null: _client = HTTPRequest.new()
	_client.timeout = 10.0
	_client.body_size_limit = 262144
	_client.max_redirects = 0
	add_child(_client)
	_client.request_completed.connect(_completed)

func configure(current_version: String) -> void: _current = current_version

func check() -> Dictionary:
	if _busy or _cooldown>0: return _error("UPDATE_BUSY")
	if not is_inside_tree() or _client==null: return _error("UPDATE_CONNECTION")
	_busy = true
	_cooldown = 60.0
	var started: int = _client.request(ENDPOINT,PackedStringArray(["Accept: application/vnd.github+json","User-Agent: FTN-Coop","X-GitHub-Api-Version: 2026-03-10"]))
	if started!=OK:
		_busy = false
		var error := _error("UPDATE_CONNECTION")
		completed.emit(error)
		return error
	return {"ok":true,"code":"OK","value":null}

func available() -> bool: return not _busy and _cooldown<=0.0

func _process(delta: float) -> void:
	if is_finite(delta) and delta>=0: _cooldown = maxf(0.0,_cooldown-delta)

func _completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _busy: return
	_busy = false
	completed.emit(parse_release(status,body,_current) if result==HTTPRequest.RESULT_SUCCESS else _error("UPDATE_CONNECTION"))

func _exit_tree() -> void:
	_busy = false
	if is_instance_valid(_client): _client.cancel_request()

static func parse_release(status: int, body: PackedByteArray, current_version: String) -> Dictionary:
	if status in [403,429]: return _error("UPDATE_RATE_LIMITED")
	if status==404: return _error("UPDATE_NO_RELEASE")
	if status!=200: return _error("UPDATE_CONNECTION")
	if body.is_empty() or body.size()>262144: return _error("UPDATE_INVALID")
	var codec: RefCounted = load("res://mods/ftn_coop/value_codec.gd").new()
	if not codec._utf8_valid(body): return _error("UPDATE_INVALID")
	var source := body.get_string_from_utf8()
	# Permit paired JSON surrogate escapes in release text while keeping the
	# codec's depth/numeric/unpaired-surrogate checks before native parsing.
	var paired := RegEx.create_from_string("\\\\u[dD][89aAbB][0-9a-fA-F]{2}\\\\u[dD][cCdDeEfF][0-9a-fA-F]{2}")
	if not codec._json_bounded(paired.sub(source,"",true)): return _error("UPDATE_INVALID")
	var json := JSON.new()
	if json.parse(source)!=OK or not json.data is Dictionary: return _error("UPDATE_INVALID")
	var data: Dictionary = json.data
	if typeof(data.get("draft"))!=TYPE_BOOL or data.draft or typeof(data.get("prerelease"))!=TYPE_BOOL or data.prerelease: return _error("UPDATE_INVALID")
	var version: Variant = data.get("tag_name")
	if not version is String: return _error("UPDATE_INVALID")
	version = version.trim_prefix("v")
	if _parts(version).size()!=3 or _parts(current_version).size()!=3: return _error("UPDATE_INVALID")
	var relation := compare_versions(version,current_version)
	return {"ok":true,"code":"OK","value":{"version":version,"status":"newer" if relation>0 else ("older" if relation<0 else "current")}}

static func compare_versions(a: String, b: String) -> int:
	var left := _parts(a)
	var right := _parts(b)
	if left.size()!=3 or right.size()!=3: return 0
	for i in range(3):
		if left[i]!=right[i]: return 1 if left[i]>right[i] else -1
	return 0

static func _parts(version: String) -> Array[int]:
	var matched := RegEx.create_from_string("^[0-9]{1,4}\\.[0-9]{1,4}\\.[0-9]{1,4}$").search(version)
	var result: Array[int] = []
	if matched==null or matched.get_string()!=version: return result
	for part in version.split("."): result.append(int(part))
	return result

static func _error(code: String) -> Dictionary: return {"ok":false,"code":code,"value":null}
