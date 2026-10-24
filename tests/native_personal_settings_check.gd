# Test-only overlay: keep native_network_check.gd as native_settings_base.gd
# in an isolated ModSource, then copy this file over native_network_check.gd.
extends "res://mods/ftn_coop/native_settings_base.gd"

var _personal_cfg: Node
var _personal_audio: Node
var _personal_expected := {}
var _personal_frames := 0

func run(base: String, args: PackedStringArray) -> Dictionary:
	for child in get_tree().root.get_children():
		var script: Script = child.get_script() as Script
		if script==null: continue
		if script.resource_path=="res://autoload/cfg.gd": _personal_cfg=child
		if script.resource_path=="res://autoload/audio.gd": _personal_audio=child
	if _personal_cfg==null or _personal_audio==null: return _finish("PERSONAL_CAPABILITY_MISSING")
	var guest := _argument(args,"--ftn-role=","host")=="guest"
	# Use different real native settings on each process. Their files are private.
	_personal_cfg.call("set_invert_look_x",guest)
	_personal_cfg.call("set_toggle_sprint",guest)
	_personal_cfg.call("set_hud_scale",0.85 if guest else 1.15)
	_personal_cfg.call("set_max_fps",120 if guest else 60)
	_personal_cfg.call("set_quality",0 if guest else 2)
	for bus in _personal_audio.get("volume"):
		_personal_audio.call("set_volume",bus,0.22 if guest else 0.74)
	await get_tree().process_frame
	await get_tree().process_frame
	_personal_expected=_personal_snapshot()
	_checks.personal_before=_personal_expected.duplicate(true)
	var result: Dictionary = await super.run(base,args)
	if not result.ok: return result
	_personal_audio.call("load_settings")
	_checks.personal_after=_personal_snapshot()
	_checks.personal_settings_preserved=_checks.personal_after==_personal_expected and _personal_frames>0
	_checks.personal_frames_checked=_personal_frames
	if not _checks.personal_settings_preserved:
		_fatal="PERSONAL_SETTINGS_RESTORE_FAILED"
		_write("FAIL")
		return {"ok":false,"code":_fatal}
	_write("PASS")
	return result

func _process(delta: float) -> void:
	super._process(delta)
	if _personal_expected.is_empty() or _finished or not _fatal.is_empty(): return
	_personal_frames+=1
	var actual := _personal_snapshot()
	if actual!=_personal_expected:
		_checks.personal_changed=actual
		_fatal="PERSONAL_SETTINGS_CHANGED"

func _personal_snapshot() -> Dictionary:
	var result := {"audio":_personal_audio.get("volume").duplicate(true)}
	for key in ["invert_look_x","toggle_sprint","hud_scale","show_hotkey_bar","locale","max_fps","fullscreen","vsync","quality","renderer"]:
		result[key]=_personal_cfg.get(key)
	return result
