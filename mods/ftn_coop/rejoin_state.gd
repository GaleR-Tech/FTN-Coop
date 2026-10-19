extends RefCounted

var _lobby := 0

func remember(lobby: int) -> void:
	if lobby>0: _lobby = lobby

func clear() -> void: _lobby = 0
func target() -> int: return _lobby
func can_rejoin(offline: bool, closing: bool) -> bool: return _lobby>0 and offline and not closing
