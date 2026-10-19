extends Node

signal hosted(lobby_id: int)
signal connected(peer_id: int)
signal disconnected(peer_id: int)
signal failed(code: String)
signal message_received(peer_id: int, channel: int, bytes: PackedByteArray)

func host(_limit: int) -> Dictionary:
	return {"ok": true, "code": "OK", "value": null}

func join(_lobby_id: int) -> Dictionary:
	return {"ok": true, "code": "OK", "value": null}

func close() -> void:
	pass

func reject_peer(_peer_id: int) -> void:
	pass

func local_peer_id() -> int:
	return 2
