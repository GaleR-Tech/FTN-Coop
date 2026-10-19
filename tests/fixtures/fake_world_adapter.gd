extends RefCounted

# Only the external game boundary is substituted. Session/order/replay are real.
var world := {"money":10,"hay":0,"buildings":[],"needles":[],"production":0}
var guest := false
var pending: Array[Dictionary] = []

func apply_host_action(_actor: int, kind: String, payload: Dictionary) -> Dictionary:
	if guest: return _error("HOST_ONLY")
	match kind:
		"purchase":
			if world.money < 10: return _error("INSUFFICIENT_FUNDS")
			world.money -= 10
		"dig": world.hay += 1
		"place": world.buildings.append(payload.id)
		"needle_collect":
			if payload.id in world.needles: return _error("ALREADY_COLLECTED")
			world.needles.append(payload.id)
		_: return _error("ACTION_UNSUPPORTED")
	return {"ok":true,"code":"OK","value":{"kind":kind,"world":world.duplicate(true)}}

func poll_host_events() -> Array[Dictionary]:
	var events := pending.duplicate(true)
	pending.clear()
	return events

func produce() -> void:
	if guest: return
	world.production += 1
	pending.append({"kind":"production","world":world.duplicate(true)})

func apply_confirmed_event(event: Dictionary) -> Dictionary:
	world = event.world.duplicate(true)
	return {"ok":true,"code":"OK","value":null}

func _error(code: String) -> Dictionary:
	return {"ok":false,"code":code,"value":null}
