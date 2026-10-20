extends Node

var enabled := false
var _adapter: RefCounted
var _player: CharacterBody3D
var _yaw := 0.0
var _pitch := 0.0
var _stamina: RefCounted
var _sprinting := false
var _has_sprint_flag := false
var _speeds := {"SPEED":4.2,"SPRINT":7.0,"GRAVITY":16.0,"JUMP_VELOCITY":4.93}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(adapter: RefCounted) -> Dictionary:
	_adapter = adapter
	var player: Variant = adapter.local_player_body()
	if not player is CharacterBody3D: return {"ok":false,"code":"CAPABILITY_MISSING","value":null}
	_player = player
	_stamina = null
	_has_sprint_flag = false
	var script: Script = _player.get_script()
	if script!=null:
		var constants := script.get_script_constant_map()
		for key in _speeds:
			if constants.get(key) is float and is_finite(constants[key]) and constants[key]>0.0: _speeds[key] = constants[key]
		for property in script.get_script_property_list():
			if property.name=="stamina" and _player.get("stamina") is RefCounted: _stamina = _player.get("stamina")
			if property.name=="_sprinting": _has_sprint_flag = true
	_yaw = player.global_rotation.y
	_pitch = 0.0
	return {"ok":true,"code":"OK","value":null}

func step(delta: float, movement: Vector2, jump: bool, sprint: bool=false) -> void:
	if not enabled or not is_instance_valid(_player) or not _adapter.guest_mode: return
	if not movement.is_finite() or not is_finite(delta) or delta<=0.0: return
	var direction := _player.global_basis*Vector3(movement.limit_length().x,0,movement.limit_length().y)
	var wants := sprint and movement.length_squared()>0.001
	_sprinting = _stamina.call("sprint_allowed",wants,_sprinting) if _stamina!=null else wants
	if _has_sprint_flag: _player.set("_sprinting",_sprinting)
	var speed: float = _speeds.SPRINT if _sprinting else _speeds.SPEED
	if _stamina!=null: speed *= float(_stamina.call("speed_scale"))
	_player.velocity.x = direction.x*speed
	_player.velocity.z = direction.z*speed
	if _player.is_on_floor():
		_player.velocity.y = _speeds.JUMP_VELOCITY*(float(_stamina.call("jump_scale")) if _stamina!=null else 1.0) if jump else -0.1
	else:
		_player.velocity.y -= float(_speeds.GRAVITY)*minf(delta,0.1)
	_player.move_and_slide()
	if _stamina!=null: _stamina.call("tick",delta,_sprinting,Vector2(_player.velocity.x,_player.velocity.z).length())

func _physics_process(delta: float) -> void:
	if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return
	var movement := Vector2(int(_pressed("move_right",KEY_D))-int(_pressed("move_left",KEY_A)),int(_pressed("move_back",KEY_S))-int(_pressed("move_forward",KEY_W)))
	step(delta,movement,_pressed("jump",KEY_SPACE),_pressed("sprint",KEY_SHIFT))

func _pressed(action: String, fallback: int) -> bool:
	return Input.is_action_pressed(action) if InputMap.has_action(action) else Input.is_physical_key_pressed(fallback)

func _input(event: InputEvent) -> void:
	if not enabled or not is_instance_valid(_player) or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x*0.002
		_pitch = clampf(_pitch-event.relative.y*0.002,-1.5,1.5)
		_adapter.set_local_look(_yaw,_pitch)
		get_viewport().set_input_as_handled()
