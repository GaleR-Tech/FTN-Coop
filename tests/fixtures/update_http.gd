extends Node

signal request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
var timeout := 10.0
var body_size_limit := 262144
var max_redirects := 0
var request_count := 0
var requested_url := ""
var payload := '{"tag_name":"v0.3.10","draft":false,"prerelease":false}'
var response_code := 200
var _server := TCPServer.new()
var _client := HTTPRequest.new()
var _socket: StreamPeerTCP
var _received := ""
var _port := 0

func _ready() -> void:
	_server.listen(0,"127.0.0.1")
	_port = _server.get_local_port()
	add_child(_client)
	_client.request_completed.connect(func(result: int, status: int, headers: PackedStringArray, body: PackedByteArray): request_completed.emit(result,status,headers,body))

func request(url: String, headers: PackedStringArray) -> int:
	request_count += 1
	requested_url = url
	_client.timeout = timeout
	_client.body_size_limit = body_size_limit
	_client.max_redirects = max_redirects
	_received = ""
	return _client.request("http://127.0.0.1:"+str(_port)+"/latest",headers)

func cancel_request() -> void: _client.cancel_request()

func _process(_delta: float) -> void:
	if _server.is_connection_available(): _socket = _server.take_connection()
	if _socket==null: return
	_socket.poll()
	var available := _socket.get_available_bytes()
	if available>0:
		var data := _socket.get_data(available)
		if data[0]==OK: _received += data[1].get_string_from_utf8()
	if not _received.contains("\r\n\r\n"): return
	var response := "HTTP/1.1 "+str(response_code)+" Response\r\nContent-Type: application/json\r\nContent-Length: "+str(payload.to_utf8_buffer().size())+"\r\nConnection: close\r\n\r\n"+payload
	_socket.put_data(response.to_utf8_buffer())
	_socket.disconnect_from_host()
	_socket = null

func _exit_tree() -> void:
	_server.stop()
	if _socket!=null: _socket.disconnect_from_host()
