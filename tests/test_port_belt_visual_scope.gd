extends RefCounted

class Props extends Node3D:
	var items: Array = []
	func spawn() -> Node3D:
		var body := Node3D.new();add_child(body);items.append(body)
		var model := MeshInstance3D.new();model.mesh=BoxMesh.new();body.add_child(model)
		return body
	func remove(body: Node3D) -> void: items.erase(body);body.free()

class Saves extends Node:
	var _pending_belts := {}

class World extends Node3D:
	var props: Props
	var restores := 0
	func _restore_belts() -> void:
		restores+=1
		props.spawn();props.spawn()

func run(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var world := World.new();tree.root.add_child(world)
	var props := Props.new();world.add_child(props);world.props=props
	var original := props.spawn()
	var saves := Saves.new();world.add_child(saves)
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	adapter.nodes={"world":world,"props":props,"saves":saves}
	adapter.guest_mode=true;adapter._guest_belts_ready=true
	adapter._guest_belts_world=world.get_instance_id();adapter._belts_epoch=1
	adapter._render_belts(world.get_instance_id(),1)
	if props.items.size()!=1 or props.items[0]!=original: errors.append("Guest belt rendering adds non-authoritative world props")
	if not adapter.get("_guest_belt_spills") is Node or adapter.get("_guest_belt_spills").get_child_count()!=2:
		errors.append("Native fallback cargo has no separate render-only representation")
	adapter._render_belts(world.get_instance_id(),1)
	if props.items.size()!=1: errors.append("Repeated belt rendering duplicates native props")
	if adapter.get("_guest_belt_spills") is Node and adapter.get("_guest_belt_spills").get_child_count()!=2: errors.append("Old fallback visuals accumulate")
	adapter.guest_mode=false
	adapter._render_belts(world.get_instance_id(),1)
	if world.restores!=2 or props.items.size()!=1: errors.append("Belt presentation guard changed a host world")
	var before := {"paths":[],"lifts":[],"stairs":[]}
	for index in range(200): before.paths.append({"a":Vector3(index,0,0),"b":Vector3(index+1,0,0),"records":[]})
	var after: Dictionary = before.duplicate(true)
	after.paths[83].records = [{"kind":0,"strands":50,"needle":-1,"state":{"strands":50},"reach":0.0,"side":0.0,"lift":0.0,"s":0.5,"speed":0.7,"xform":Transform3D(Basis.IDENTITY,Vector3(83.5,0.4,0))}]
	var patch: Dictionary = adapter._difference({"belts":before},{"belts":after})
	if not patch.has("belts_delta") or patch.has("belts"):
		errors.append("Moving cargo still retransmits unchanged belt geometry and empty paths")
	else:
		adapter.guest_mode=true;adapter._guest_belts=before.duplicate(true)
		if not adapter.apply_confirmed_event({"patch":patch}).ok or adapter._guest_belts!=after: errors.append("Belt delta lost cargo or changed native path geometry")
		var codec: RefCounted = load("res://mods/ftn_coop/value_codec.gd").new()
		if codec.encode(patch,1024*1024).value.size()>=codec.encode({"belts":after},1024*1024).value.size()/10: errors.append("One changed belt must fit within a tenth of the full path update")
		for invalid in [{"paths":{"count":199,"rows":[{"index":83,"records":[]}]}},{"paths":{"count":200,"rows":[{"index":-1,"records":[]}]}},{"paths":{"count":200,"rows":[{"index":83,"records":[]},{"index":83,"records":[]}]}}]:
			if adapter.apply_confirmed_event({"patch":{"belts_delta":invalid}}).ok or adapter._guest_belts!=after: errors.append("Malformed belt delta partially changed the native world")
		if adapter.apply_confirmed_event({"patch":{"belts":before,"belts_delta":patch.belts_delta}}).ok: errors.append("Conflicting full and delta belt data accepted")
		if adapter.apply_confirmed_event({"patch":{"belts_delta":{"paths":{"count":200,"rows":[{"index":83,"records":[42]}]}}}}).ok or adapter._guest_belts!=after: errors.append("Malformed cargo reached the native belt importer")
		for field in ["strands","needle","state","reach","side","lift","s","speed"]:
			var malformed: Dictionary = patch.belts_delta.duplicate(true)
			malformed.paths.rows[0].records[0][field] = {} if field!="state" else 7
			if adapter.apply_confirmed_event({"patch":{"belts_delta":malformed}}).ok or adapter._guest_belts!=after: errors.append("Malformed cargo field "+field+" changed the guest cache")
	var changed: Dictionary = after.duplicate(true)
	changed.paths[0].b=Vector3(20,0,0)
	if not adapter._difference({"belts":after},{"belts":changed}).has("belts"): errors.append("Changed belt geometry must retain the complete restore path")
	var replica: RefCounted = load("res://mods/ftn_coop/belt_replica.gd").new()
	for category in ["lifts","stairs"]:
		var vertical := {category:[{"at":Vector3(2,0,2),"rows":[]}]}
		var moving: Dictionary = vertical.duplicate(true)
		moving[category][0].rows=after.paths[83].records.duplicate(true)
		var delta: Dictionary = replica.difference(vertical,moving)
		var expanded: Dictionary = replica.expand(vertical,delta)
		if not expanded.ok or expanded.value!=moving: errors.append("Vertical cargo delta lost native fields")
		delta[category].rows[0].records[0].state=7
		if replica.expand(vertical,delta).ok or not vertical[category][0].rows.is_empty(): errors.append("Malformed vertical cargo changed its baseline")
	world.free()
	return errors
