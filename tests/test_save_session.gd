extends RefCounted

class NativeBoundary extends RefCounted:
	var tree: SceneTree
	var guest_mode := false
	var ids: Array[String] = []
	var close_calls := 0
	var save_calls := 0
	var cancel_calls := 0
	var fail_restore := false
	var fail_close := false
	func restore_guest_world(_state: Dictionary, id: String) -> Dictionary:
		ids.append(id)
		guest_mode = true
		await tree.create_timer(0.03).timeout
		return {"ok":not fail_restore,"code":"NATIVE_RELOAD_FAILED" if fail_restore else "OK","value":null}
	func cancel_guest_restore() -> void: cancel_calls += 1
	func close_guest_world() -> Dictionary:
		close_calls += 1
		await tree.process_frame
		if fail_close: return {"ok":false,"code":"GUEST_CLEANUP_FAILED","value":null}
		guest_mode = false
		return {"ok":true,"code":"OK","value":null}
	func save_host_world() -> Dictionary:
		save_calls += 1
		return {"ok":true,"code":"OK","value":null}

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/save_session.gd"): return ["Guest persistence and cancellation lifecycle is not implemented yet."]
	var errors: Array[String] = []
	var session: Node = load("res://mods/ftn_coop/save_session.gd").new()
	var native := NativeBoundary.new()
	native.tree = tree
	tree.root.add_child(session)
	session.configure(native)
	var cookie := "0123456789abcdef0123456789abcdef"
	if not (await session.open_guest({},cookie)).ok: errors.append("A valid guest session should load through the native boundary.")
	if native.ids.size()!=1 or native.ids[0]==cookie or native.ids[0].length()!=32: errors.append("Guest storage needs a fresh locally generated ID, independent of the host cookie.")
	if session.save_host().code!="HOST_ONLY" or native.save_calls!=0: errors.append("A guest must not invoke the native host save at all.")
	await session.close()
	if native.guest_mode or session.guest_open or session.closing: errors.append("Closing a guest session must finish native cleanup.")
	var results: Array = []
	_open(session,cookie,results)
	await session.close()
	await tree.create_timer(0.05).timeout
	if results.size()!=1 or results[0].code!="GUEST_LOAD_CANCELED" or session.guest_open: errors.append("A late completed native load must not reopen a canceled guest session.")
	if native.cancel_calls<2 or native.close_calls!=2: errors.append("Cancel must reach the native loader and cleanup exactly once per open.")
	await session.close()
	if native.close_calls!=2: errors.append("Repeated close must be harmless.")
	await session.open_guest({},cookie)
	var owned_id: String = session._directory_id
	native.fail_close = true
	await session.close()
	if not session.guest_open or session._directory_id!=owned_id or session.save_host().ok: errors.append("Failed cleanup must retain its local directory identity and block host saving until retry.")
	native.fail_close = false
	await session.close()
	if session.guest_open or not session._directory_id.is_empty(): errors.append("A successful retry must complete cleanup and release its local identity.")
	native.fail_restore = true
	if (await session.open_guest({},cookie)).ok or native.guest_mode or session.guest_open: errors.append("A failed native load must close its temporary session.")
	var count := native.ids.size()
	if (await session.open_guest({},"../../slot_0")).ok or native.ids.size()!=count: errors.append("Invalid host IDs must be rejected before native loading.")
	if not session.save_host().ok or native.save_calls!=1: errors.append("An offline host save can use the native adapter.")
	session.queue_free()
	await tree.process_frame
	return errors

func _open(session: Node, cookie: String, results: Array) -> void:
	results.append(await session.open_guest({},cookie))
