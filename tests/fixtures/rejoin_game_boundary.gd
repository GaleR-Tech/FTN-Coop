extends "res://tests/fixtures/network_game_boundary.gd"

var close_calls := 0
var fail_close := false

func close_guest_world() -> Dictionary:
	close_calls += 1
	await tree.create_timer(0.05).timeout
	if fail_close: return {"ok":false,"code":"GUEST_CLEANUP_FAILED","value":null}
	guest = false
	return _ok()
