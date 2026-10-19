extends Node

var enabled := false
var _adapter: RefCounted
var _player: CharacterBody3D
var _yaw := 0.0
var _pitch := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(adapter: RefCounted) -> Dictionary:
	_adapter = adapter
	var player: Variant = adapter.local_player_body()
	if not player is CharacterBody3D: return {"ok":false,"code":"CAPABILITY_MISSING","value":null}
	_player = player
	_yaw = player.global_rotation.y
	_pitch = 0.0
	return {"ok":true,"code":"OK","value":null}

func step(delta: float, movement: Vector2, jump: bool) -> void:
	if not enabled or not is_instance_valid(_player) or not _adapter.guest_mode: return
	if not movement.is_finite() or not is_finite(delta) or delta<=0.0: return
	var direction := _player.global_basis*Vector3(movement.limit_length().x,0,movement.limit_length().y)
	_player.velocity.x = direction.x*5.0
	_player.velocity.z = direction.z*5.0
	if _player.is_on_floor():
		_player.velocity.y = 5.5 if jump else -0.1
	else:
		_player.velocity.y -= 18.0*minf(delta,0.1)
	_player.move_and_slide()

func _physics_process(delta: float) -> void:
	if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return
	var movement := Vector2(int(Input.is_physical_key_pressed(KEY_D))-int(Input.is_physical_key_pressed(KEY_A)),int(Input.is_physical_key_pressed(KEY_S))-int(Input.is_physical_key_pressed(KEY_W)))
	step(delta,movement,Input.is_physical_key_pressed(KEY_SPACE))

func _input(event: InputEvent) -> void:
	if not enabled or not is_instance_valid(_player) or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x*0.002
		_pitch = clampf(_pitch-event.relative.y*0.002,-1.5,1.5)
		_adapter.set_local_look(_yaw,_pitch)
		get_viewport().set_input_as_handled()
