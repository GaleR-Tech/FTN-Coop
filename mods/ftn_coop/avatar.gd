extends Node3D

var _target := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _initialized := false
var _label: Label3D
var _head: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e8b654")
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.15
	body.mesh = capsule
	body.material_override = material
	body.position.y = 0.8
	add_child(body)
	_head = Node3D.new()
	_head.position.y = 1.5
	add_child(_head)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.23
	sphere.height = 0.46
	head.mesh = sphere
	head.material_override = material
	_head.add_child(head)
	var visor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.33,0.12,0.09)
	visor.mesh = box
	visor.position = Vector3(0,0.03,-0.21)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("17323c")
	visor.material_override = dark
	_head.add_child(visor)
	_label = Label3D.new()
	_label.position.y = 1.95
	_label.font_size = 40
	_label.pixel_size = 0.007
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)

func set_display_name(value: String) -> void:
	if _label!=null: _label.text = value.left(32)

func apply_pose(pose: Dictionary) -> void:
	if not pose.get("position") is Vector3 or not pose.get("rotation") is Vector3: return
	if not pose.position.is_finite() or not pose.rotation.is_finite() or pose.position.length()>2048.0: return
	_target = pose.position
	_yaw = pose.rotation.y
	_pitch = clampf(pose.rotation.x,-1.5,1.5)
	if not _initialized:
		visible = true
		position = _target
		rotation.y = _yaw
		_initialized = true

func _process(delta: float) -> void:
	if not _initialized: return
	var weight := 1.0-exp(-18.0*delta)
	position = position.lerp(_target,weight)
	rotation.y = lerp_angle(rotation.y,_yaw,weight)
	if _head!=null: _head.rotation.x = lerp_angle(_head.rotation.x,_pitch,weight)
