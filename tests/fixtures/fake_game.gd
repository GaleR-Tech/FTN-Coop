extends Node

var secret_token := "fixture-secret-value"
var fixture_counter := 0

func fixture_action(_action: Dictionary) -> Dictionary:
	fixture_counter += 1
	return {"ok": true}
