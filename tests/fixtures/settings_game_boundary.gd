extends "res://tests/fixtures/network_game_boundary.gd"

var config: Node
var settings: RefCounted
var settings_at_load: Dictionary = {}

func configure_settings(value: Node) -> void:
	config = value
	settings = load("res://mods/ftn_coop/shared_settings.gd").new()
	settings.configure(config)

func _live_frame() -> Dictionary:
	var frame := super._live_frame()
	frame.settings = settings.capture().value
	return frame

func apply_shared_settings(values: Variant) -> Dictionary: return settings.accept(values)
func maintain_shared_settings() -> Dictionary: return settings.enforce()
func restore_shared_settings() -> void: settings.release()

func restore_guest_world(state: Dictionary, id: String) -> Dictionary:
	settings_at_load = settings.capture().value
	return await super.restore_guest_world(state,id)

func apply_confirmed_event(event: Dictionary) -> Dictionary:
	if event.get("patch") is Dictionary and event.patch.has("settings"):
		var applied: Dictionary = settings.accept(event.patch.settings)
		if not applied.ok: return applied
	return super.apply_confirmed_event(event)

func close_guest_world() -> Dictionary:
	var closed := super.close_guest_world()
	settings.release()
	return closed
