extends RefCounted

# These native helpers update draw visibility only. Machinery and world physics
# retain the guest world's disabled process mode.
const DRAW_PATHS := ["res://scripts/build/belt_batch.gd", "res://scripts/build/structure_cull.gd"]
const TICK_PATHS := ["res://scripts/world/shadow_lod.gd"]
const MACHINE_LOD := "res://scripts/world/machine_lod.gd"
var _world: WeakRef
var _tree: SceneTree
var _machine_lod: Script
var _modes := {}
var _tickers := {}

func configure(world: Node) -> void:
	if _world!=null and _world.get_ref()==world: return
	restore()
	if not is_instance_valid(world) or not world.is_inside_tree(): return
	_world = weakref(world)
	_tree = world.get_tree()
	# MachineLOD is a native static registry, not a child in the scene tree.
	if ResourceLoader.exists(MACHINE_LOD):
		var script: Script = load(MACHINE_LOD)
		if script!=null and script.has_method("tick"): _machine_lod = script
	_tree.node_added.connect(_observe)
	_tree.node_removed.connect(_forget)
	_walk(world)

func _walk(node: Node) -> void:
	_observe(node)
	for child in node.get_children(): _walk(child)

func _observe(node: Node) -> void:
	var world: Variant = _world.get_ref() if _world!=null else null
	if not is_instance_valid(world) or not world.is_ancestor_of(node) or node.process_mode==Node.PROCESS_MODE_DISABLED: return
	var script: Script = node.get_script()
	if script==null or (script.resource_path not in DRAW_PATHS and script.resource_path not in TICK_PATHS): return
	var id := node.get_instance_id()
	if _modes.has(id): return
	_modes[id] = {"node":weakref(node),"mode":node.process_mode}
	if script.resource_path in TICK_PATHS and node.has_method("tick"): _tickers[id] = weakref(node)
	node.process_mode = Node.PROCESS_MODE_ALWAYS

func pump(eye: Vector3) -> void:
	if not eye.is_finite(): return
	if _machine_lod!=null: _machine_lod.call("tick",eye)
	for reference in _tickers.values():
		var node: Variant = reference.get_ref()
		if is_instance_valid(node): node.call("tick",eye)

func _forget(node: Node) -> void:
	var id := node.get_instance_id()
	if not _modes.has(id): return
	node.process_mode = _modes[id].mode
	_modes.erase(id)
	_tickers.erase(id)

func restore() -> void:
	if is_instance_valid(_tree):
		_tree.node_added.disconnect(_observe)
		_tree.node_removed.disconnect(_forget)
	_tree = null
	for record in _modes.values():
		var node: Variant = record.node.get_ref()
		if is_instance_valid(node): node.process_mode = record.mode
	_modes.clear()
	_tickers.clear()
	_machine_lod = null
	_world = null
