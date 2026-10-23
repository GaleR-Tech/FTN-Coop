extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var good := Node3D.new();tree.root.add_child(good)
	var bad := Node3D.new();tree.root.add_child(bad)
	var module: RefCounted = load("res://mods/ftn_coop/loose_sync.gd").new()
	var initial: Dictionary = module.capture_sources([good],[])
	var id: int = initial.value.ids[0]
	for kind in range(4):
		bad.transform=Transform3D.IDENTITY;bad.set_meta("tint",Color.WHITE)
		if kind==0: bad.position=Vector3(0,-3000,0)
		if kind==1: bad.scale=Vector3(9,1,1)
		if kind==2: bad.set_meta("tint",Color(10,1,1))
		if kind==3: bad.set_meta("tint","not-a-color")
		var captured: Dictionary = module.capture_sources([good,bad],[])
		if not captured.ok: errors.append("One unrepresentable native body aborts all loose replication: "+str(kind));continue
		if captured.value.ids!=PackedInt32Array([id]) or not module.validate(captured.value): errors.append("Healthy body or stable ID lost during native filtering")
		if not is_instance_valid(bad): errors.append("Replication filtering destroyed a native body")
	var invalid_wire: Dictionary = initial.value.duplicate(true);invalid_wire.poses[9]=3000.0
	if module.validate(invalid_wire): errors.append("Native filtering weakened incoming wire validation")
	bad.transform=Transform3D.IDENTITY;bad.set_meta("tint",Color.WHITE)
	var recovered: Dictionary = module.capture_sources([good,bad],[])
	if not recovered.ok or recovered.value.ids.size()!=2 or recovered.value.ids[0]!=id: errors.append("A recovered native body was not replicated again")
	good.free();bad.free()
	return errors
