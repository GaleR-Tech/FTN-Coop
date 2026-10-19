extends Node

# External native Cfg boundary. Its write guard was checked in the real demo.
var prop_cap := 150
var prop_decay := true
var belt_cap := 600
var belt_decay := true
var auto_clean := false
var auto_clean_seconds := 60.0
var grid_lock := false
var autosave := true
var autosave_seconds := 120.0
var settings_readonly := false
var quality := 2
var mouse_sensitivity := 0.7
var locale := "de"
var path := ""

func save_settings() -> void:
	if settings_readonly or path.is_empty(): return
	var file := ConfigFile.new()
	file.load(path)
	for key in ["prop_cap","prop_decay","belt_cap","belt_decay","auto_clean","auto_clean_seconds","grid_lock","autosave","autosave_seconds"]:
		file.set_value("gameplay",key,get(key))
	for key in ["quality","mouse_sensitivity","locale"]:
		file.set_value("personal",key,get(key))
	file.save(path)

func set_prop_cap(value: int) -> void:
	prop_cap = clampi(value,20,1500)
	save_settings()
