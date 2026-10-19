extends Node3D

var _nodes: Dictionary = {}
var _records: Dictionary = {}

func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS

func set_markers(rows: Array, roster: Dictionary, language: String) -> void:
	var state: RefCounted = load(get_script().resource_path.get_base_dir()+"/marker_state.gd").new()
	if not state.accept_snapshot(rows).ok: return
	var retained := {}
	var colors: Script = load(get_script().resource_path.get_base_dir()+"/player_colors.gd")
	var locale: RefCounted = load(get_script().resource_path.get_base_dir()+"/locale.gd").new()
	locale.set_language(language)
	var titles := {"point":"Markierung","build":"Hier bauen","needle":"Hier liegt eine Nadel","help":"Hilfe"}
	for row in rows:
		if not roster.has(row.peer): continue
		retained[row.peer] = row.duplicate()
		if not _nodes.has(row.peer):
			var pin := Node3D.new()
			var mesh := MeshInstance3D.new()
			mesh.name = "Pin"
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.18
			cone.height = 0.6
			mesh.mesh = cone
			mesh.position.y = 0.4
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material_override = material
			pin.add_child(mesh)
			var title := Label3D.new()
			title.name = "Title"
			title.position.y = 1.1
			title.font_size = 36
			title.pixel_size = 0.006
			title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			pin.add_child(title)
			add_child(pin)
			_nodes[row.peer] = pin
		var node: Node3D = _nodes[row.peer]
		node.position = row.position
		var color: Color = colors.for_peer(row.peer,roster)
		node.get_node("Pin").material_override.albedo_color = color
		node.get_node("Title").modulate = color
		node.get_node("Title").text = locale.text(titles[row.kind])+"\n"+str(roster[row.peer].get("name",locale.text("Mitspieler"))).left(64)
	for peer in _nodes.keys():
		if not retained.has(peer): _remove(peer)
	_records = retained

func _process(delta: float) -> void:
	if not is_finite(delta) or delta<0: return
	for peer in _records.keys():
		_records[peer].remaining -= delta
		if _records[peer].remaining<=0:
			_remove(peer)
			_records.erase(peer)

func _remove(peer: int) -> void:
	if _nodes.has(peer):
		var node: Node = _nodes[peer]
		remove_child(node)
		node.queue_free()
		_nodes.erase(peer)

func clear() -> void:
	for peer in _nodes.keys(): _remove(peer)
	_records.clear()
