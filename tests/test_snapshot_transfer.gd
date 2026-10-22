extends RefCounted

const SESSION := "0123456789abcdef0123456789abcdef"

func run(_tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/snapshot_transfer.gd"):
		return ["Bounded world transfer is not implemented yet."]
	var module: Script = load("res://mods/ftn_coop/snapshot_transfer.gd")
	var sender: Node = module.new()
	var receiver: Node = module.new()
	receiver.configure(SESSION)
	var errors: Array[String] = []
	var random := RandomNumberGenerator.new()
	random.seed = 123456
	var blob := PackedByteArray()
	blob.resize(90000)
	for index in range(blob.size()):
		blob[index] = random.randi() & 255
	var state := {"hay": 123.0, "heights": PackedFloat32Array([0.5,1.25]), "blob": blob}
	var begun: Dictionary = sender.begin(state, SESSION, 10)
	if not begun.get("ok", false):
		sender.free()
		receiver.free()
		return ["Valid world failed to start a transfer."]
	var frames: Array = begun.value.frames
	var encoded: Dictionary = load("res://mods/ftn_coop/value_codec.gd").new().encode(state,256*1024*1024)
	if sender.has_method("begin_encoded"):
		var shared: Dictionary = sender.begin_encoded(encoded.value,SESSION,10)
		if not shared.ok or shared.value.frames[0].sha256!=frames[0].sha256 or shared.value.frames[0].raw_bytes!=encoded.value.size():
			errors.append("Reusing encoded world data must preserve the exact compressed contents and bounds.")
		if sender.begin_encoded(PackedByteArray(),SESSION,10).code!="INVALID_PAYLOAD" or sender.begin_encoded(encoded.value,"bad",10).code!="INVALID_PAYLOAD":
			errors.append("Pre-encoded transfers must validate empty data and session identity before compression.")
	else: errors.append("World event broadcasts need a bounded transfer entry point for shared encoded bytes.")
	var protocol: RefCounted = load("res://mods/ftn_coop/protocol.gd").new()
	for frame in frames:
		var packet: Dictionary = protocol.encode({"protocol":1,"session":SESSION,"type":frame.kind,"body":frame})
		if not packet.ok or not protocol.decode(packet.value).ok:
			errors.append("Every 32 KiB world chunk must fit into a validated transport packet.")
	var completed: Array = []
	var progress: Array = []
	if receiver.has_signal("progress_changed"):
		receiver.progress_changed.connect(func(received: int, total: int): progress.append([received,total]))
	else: errors.append("Validated world chunks must expose byte progress.")
	receiver.completed.connect(func(world: Dictionary, revision: int): completed.append({"world": world, "revision": revision}))
	receiver.receive(1, frames[0])
	if not progress.is_empty() and progress[-1]!=[0,frames[0].total_bytes]: errors.append("A fresh transfer must begin at zero received bytes.")
	receiver.receive(1, frames[1])
	var progress_count := progress.size()
	receiver.receive(1, frames[1])
	if progress.size()!=progress_count: errors.append("Duplicate chunks must not advance progress.")
	if not completed.is_empty():
		errors.append("Missing or repeated chunks must not load a partial world.")
	for index in range(frames.size() - 1, 1, -1):
		receiver.receive(1, frames[index])
	if completed.size() != 1 or completed[0].world != state or completed[0].revision != 10:
		errors.append("Shuffled chunks must reconstruct the exact world once.")
	if not progress.is_empty() and progress[-1]!=[frames[0].total_bytes,frames[0].total_bytes]: errors.append("Completed data reception must report its exact byte count.")
	if receiver.receive(1, frames[0]).code != "STALE_REVISION":
		errors.append("An old world must not overwrite the current world.")
	receiver.configure("fedcba9876543210fedcba9876543210")
	if receiver.receive(1, frames[0]).code != "SESSION_MISMATCH":
		errors.append("Worlds from an abandoned session must be rejected.")
	receiver.configure(SESSION)
	if receiver.receive(2, frames[0]).code != "HOST_ONLY":
		errors.append("A guest must not supply the shared world.")
	var bad_header: Dictionary = frames[0].duplicate(true)
	bad_header.total_bytes = 64 * 1024 * 1024 + 1
	if receiver.receive(1, bad_header).code != "WORLD_TOO_LARGE":
		errors.append("Oversized compressed world must fail before allocation.")
	bad_header = frames[0].duplicate(true)
	bad_header.raw_bytes = 256 * 1024 * 1024 + 1
	if receiver.receive(1, bad_header).code != "WORLD_TOO_LARGE":
		errors.append("Oversized decompressed world must fail before allocation.")
	var second: Dictionary = sender.begin(state, SESSION, 11)
	var corrupted: Array = second.value.frames.duplicate(true)
	corrupted[corrupted.size()-1].data[0] ^= 1
	for frame in corrupted:
		receiver.receive(1, frame)
	if receiver.last_error != "CHECKSUM_MISMATCH" or completed.size() != 1:
		errors.append("A corrupt world must not be loaded.")
	receiver.receive(1, frames[0])
	receiver._process(121.0)
	if receiver.last_error != "TRANSFER_TIMEOUT":
		errors.append("Incomplete transfers must release their buffers after the deadline.")
	receiver.receive(1, frames[0])
	receiver.cancel()
	if receiver.receive(1, frames[1]).code != "TRANSFER_MISMATCH":
		errors.append("Cancelled chunks must not recreate a transfer.")
	if not sender.has_method("buffer_event"):
		errors.append("Confirmed events during a world transfer need an ordered bounded buffer.")
	else:
		for revision in range(12,4108):
			if not sender.buffer_event({"revision":revision,"kind":"production"}).ok:
				errors.append("4096 subsequent confirmed events must fit the transfer buffer.")
		if sender.buffer_event({"revision":4108}).code != "RESYNC_REQUIRED":
			errors.append("A full event buffer must request a fresh world instead of silently dropping updates.")
		if sender.buffered_events().size() != 4096:
			errors.append("Event replay must preserve the bounded event sequence.")
		sender.begin(state,SESSION,12)
		var large_event := PackedByteArray()
		large_event.resize(8*1024*1024+1)
		if sender.buffer_event({"revision":13,"data":large_event}).code != "RESYNC_REQUIRED":
			errors.append("A few large events must not bypass the transfer buffer memory bound.")
	sender.free()
	receiver.free()
	return errors
