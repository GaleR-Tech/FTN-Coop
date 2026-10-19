extends "res://tests/fixtures/settings_game_boundary.gd"

func read_shared_settings() -> Dictionary: return settings.capture()
func update_shared_settings(values: Variant) -> Dictionary: return settings.update_host_values(values)
func read_marker_target() -> Dictionary: return _ok(Vector3(3,0,-4))
# Headless DisplayServer cannot capture a mouse. This external native-input
# boundary supplies that device state; runtime routing and marker state stay real.
func marker_input_allowed() -> bool: return true
