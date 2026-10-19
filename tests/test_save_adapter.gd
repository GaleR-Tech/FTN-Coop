extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	var adapter: RefCounted = load("res://tests/fixtures/save_adapter_boundary.gd").new()
	for method in ["close_guest_world","cancel_guest_restore","save_host_world"]:
		if not adapter.has_method(method): return ["Native guest/save lifecycle is missing: "+method]
	var errors: Array[String] = []
	var fixture: Script = load("res://tests/fixtures/save_native_boundary.gd")
	var saves: Node = fixture.Saves.new()
	saves.name = "FtnSaveBoundary"
	tree.root.add_child(saves)
	var original := "user://ftn_coop_tests/"+Crypto.new().generate_random_bytes(16).hex_encode()
	saves.use_scratch_dir(original)
	var snapshot := {"version":1,"state":{"money":50.0},"heights":PackedFloat32Array([1,1,1,1]),"player":Transform3D.IDENTITY,"buildings":[],"props":[],"belts":{},"tech":{"money":10.0},"cell":2.0,"extent":1.0}
	saves.write_file(saves.slot_path(0),snapshot)
	var path: String = saves.slot_path(0)
	var before := FileAccess.get_sha256(path)
	adapter.native_saves = saves
	adapter.bind(tree.root)
	var opened: Dictionary = await adapter.restore_guest_world(snapshot,"0123456789abcdef0123456789abcdef")
	if not opened.ok or not adapter.guest_mode or saves.directory==original: errors.append("Guest loading from the main menu must use isolated native storage.")
	var guest_directory: String = saves.directory
	if adapter.save_host_world().code!="HOST_ONLY" or FileAccess.get_sha256(path)!=before: errors.append("Guest loading and save attempts must preserve the offline slot exactly.")
	var closed: Dictionary = await adapter.close_guest_world()
	if tree.current_scene==null or tree.current_scene.scene_file_path!="res://tests/fixtures/save_menu.tscn": errors.append("Cleanup must not report completion before the actual menu scene has entered the tree.")
	if not closed.ok or adapter.guest_mode or saves.directory!=original or saves.current_slot!=0 or saves.block_save or FileAccess.get_sha256(path)!=before: errors.append("Guest cleanup must unload its world before restoring the original save directory and flags.")
	if DirAccess.dir_exists_absolute(guest_directory): errors.append("Successful guest departure must remove its owned temporary native slot directory.")
	await adapter.restore_guest_world(snapshot,"0123456789abcdef0123456789abcdef")
	var retry_directory: String = saves.directory
	DirAccess.make_dir_absolute(retry_directory+"/unexpected")
	var cleanup_failed: Dictionary = await adapter.close_guest_world()
	if cleanup_failed.code!="GUEST_CLEANUP_FAILED" or not FileAccess.file_exists(retry_directory+"/slot_1.dat"): errors.append("Unexpected nested data must stop cleanup and preserve the owned directory for retry.")
	if saves.directory!=original or FileAccess.get_sha256(path)!=before: errors.append("Cleanup failure must still preserve offline storage and hashes.")
	DirAccess.remove_absolute(retry_directory+"/unexpected")
	if not (await adapter.close_guest_world()).ok or DirAccess.dir_exists_absolute(retry_directory): errors.append("Retry must remove the same owned guest directory once cleanup is possible.")
	var results: Array = []
	_open(adapter,snapshot,results)
	await tree.process_frame
	await adapter.close_guest_world()
	await tree.process_frame
	if results.size()!=1 or results[0].code!="GUEST_LOAD_CANCELED" or adapter.guest_mode or FileAccess.get_sha256(path)!=before: errors.append("Cancel during native construction must not reopen a guest or touch offline saves.")
	saves.write_ok = false
	var failed: Dictionary = await adapter.restore_guest_world(snapshot,"0123456789abcdef0123456789abcdef")
	await adapter.close_guest_world()
	if failed.ok or saves.directory!=original or saves.block_save or FileAccess.get_sha256(path)!=before: errors.append("A failed isolated write must leave the original slot intact after cleanup.")
	saves.write_ok = true
	saves.begin_load(0)
	tree.change_scene_to_file("res://tests/fixtures/save_world.tscn")
	for frame in range(6): await tree.process_frame
	adapter.bind(tree.root)
	adapter.nodes.state.data.money = 901.0
	if not adapter.save_host_world().ok or saves._read(0).state.money!=901.0: errors.append("Host save must persist the actual native world.")
	var good := FileAccess.get_sha256(path)
	adapter.nodes.world.fail_after_partial_write = true
	if adapter.save_host_world().ok or FileAccess.get_sha256(path)!=good or saves._read(0).state.money!=901.0: errors.append("A partially failing native save must retain the last valid slot.")
	adapter.nodes.world.block_save = true
	saves.block_save = true
	tree.change_scene_to_file("res://tests/fixtures/save_menu.tscn")
	await tree.process_frame
	saves.queue_free()
	if tree.current_scene!=null:
		tree.current_scene.queue_free()
		tree.current_scene = null
	await tree.process_frame
	return errors

func _open(adapter: RefCounted, state: Dictionary, results: Array) -> void:
	results.append(await adapter.restore_guest_world(state,"0123456789abcdef0123456789abcdef"))
