extends RefCounted

class ClosingPeer extends MultiplayerPeerExtension:
	var on_poll: Callable
	var polling := false
	var closed_during_poll := false
	var close_calls := 0
	func _poll() -> void:
		polling = true
		on_poll.call()
		polling = false
	func _close() -> void:
		closed_during_poll = closed_during_poll or polling
		close_calls += 1
	func _get_connection_status() -> MultiplayerPeer.ConnectionStatus: return MultiplayerPeer.CONNECTION_CONNECTED
	func _get_available_packet_count() -> int: return 0

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/session.gd"):
		return ["Four-player session is not implemented yet."]
	var errors: Array[String] = []
	var transport: Node = load("res://tests/fixtures/fake_transport.gd").new()
	var session: Node = load("res://mods/ftn_coop/session.gd").new()
	session.configure(transport, "25963876", "0.2.0")
	if not session.host().ok or session.state != session.State.CREATING:
		errors.append("Hosting must wait for the asynchronous lobby callback.")
	transport.hosted.emit(42)
	if session.state != session.State.LOBBY or session.roster.size() != 1:
		errors.append("A created lobby must register its host.")
	var hello := {"protocol": 1, "build": "25963876", "mod_version": "0.2.0", "name": "Friend"}
	for peer_id in [2, 3, 4]:
		transport.connected.emit(peer_id)
		if not session.accept_hello(peer_id, hello).ok:
			errors.append("A compatible friend was rejected.")
	if session.roster.size() != 4 or session.accept_hello(5, hello).code != "SESSION_FULL":
		errors.append("The fifth player must not be admitted.")
	if session.roster[2].state != "syncing":
		errors.append("Hello alone must not mark a guest as playable.")
	if not session.mark_world_ready(2).ok or session.roster[2].state != "playing":
		errors.append("Confirmed world load must make a guest playable.")
	session.accept_hello(2, hello)
	if session.roster[2].state != "playing":
		errors.append("A duplicate hello must not reset a running guest.")
	transport.disconnected.emit(4)
	var wrong := hello.duplicate()
	wrong.build = "another-build"
	if session.accept_hello(4, wrong).code != "BUILD_MISMATCH":
		errors.append("Wrong game build was accepted.")
	wrong = hello.duplicate()
	wrong.protocol = 2
	if session.accept_hello(4, wrong).code != "PROTOCOL_MISMATCH":
		errors.append("Wrong protocol was accepted.")
	wrong = hello.duplicate()
	wrong.mod_version = "different-mod"
	if session.accept_hello(4, wrong).code != "MOD_MISMATCH":
		errors.append("Wrong mod was accepted.")
	session.leave()
	transport.hosted.emit(99)
	transport.connected.emit(6)
	if session.state != session.State.OFFLINE or not session.roster.is_empty():
		errors.append("Late callbacks reopened an abandoned session.")
	session.host()
	transport.hosted.emit(100)
	for peer_id in [2,3,4]:
		transport.connected.emit(peer_id)
	if session.accept_hello(5, hello).code != "SESSION_FULL":
		errors.append("Pending handshakes must reserve their player slots.")
	session._process(16.0)
	if session.roster.size() != 1:
		errors.append("Silent handshakes must not occupy slots forever.")
	session.leave()
	var requests: Array = []
	session.outgoing.connect(func(_peer: int, kind: String, body: Dictionary): requests.append({"kind": kind, "body": body}))
	session.join(200)
	transport.connected.emit(1)
	if session.state != session.State.SYNCING or requests.is_empty() or requests.back().kind != "HELLO":
		errors.append("A client must send hello and await its world after connecting.")
	if not session.has_method("accept_welcome"):
		errors.append("Validated client welcome handling is not implemented yet.")
	else:
		var welcome := {"session_id": "0123456789abcdef0123456789abcdef", "player_id": 2, "mod_version":"0.2.0", "roster": [
			{"id": 1, "name": "Host", "state": "playing", "accepted": true},
			{"id": 2, "name": "Friend", "state": "syncing", "accepted": true},
		]}
		if session.accept_welcome(3, welcome).ok:
			errors.append("Only the host may assign the client roster.")
		var wrong_welcome := welcome.duplicate(true)
		wrong_welcome.mod_version = "0.1.1"
		if session.accept_welcome(1,wrong_welcome).code!="MOD_MISMATCH" or not session.session_id.is_empty():
			errors.append("A mismatched host version must be rejected before accepting its session or roster.")
		wrong_welcome.erase("mod_version")
		if session.accept_welcome(1,wrong_welcome).code!="MOD_MISMATCH":
			errors.append("A host without version information must fail closed.")
		if not session.accept_welcome(1, welcome).ok or session.state != session.State.SYNCING:
			errors.append("A valid welcome must still wait for world completion.")
		session.mark_world_ready(2)
		if session.state != session.State.PLAYING:
			errors.append("A completed guest world must enter play.")
	transport.disconnected.emit(1)
	if session.state != session.State.OFFLINE or not session.roster.is_empty():
		errors.append("Host loss must end the guest session.")
	session.leave()
	session.free()
	transport.free()
	if not FileAccess.file_exists("res://mods/ftn_coop/steam_transport.gd"):
		errors.append("Native Steam transport is not implemented yet.")
	else:
		var native_transport: Node = load("res://mods/ftn_coop/steam_transport.gd").new()
		if native_transport.host(4).get("code") != "STEAM_UNSUPPORTED":
			errors.append("Standalone engine must fail closed without the Steam extension.")
		var failures: Array[String] = []
		native_transport.failed.connect(func(code: String): failures.append(code))
		native_transport._pending_join = 42
		native_transport._join_generation = native_transport._generation
		native_transport._on_lobby_joined(42,0,false,4)
		if failures!=["SESSION_FULL"]: errors.append("Steam's full-lobby response must reach the localized session-full message.")
		for response in [[2,"LOBBY_NOT_FOUND"],[3,"LOBBY_NOT_ALLOWED"],[4,"SESSION_FULL"],[5,"LOBBY_JOIN_FAILED"],[6,"LOBBY_NOT_ALLOWED"],[7,"LOBBY_ACCOUNT_LIMITED"],[9,"LOBBY_NOT_ALLOWED"],[10,"LOBBY_BLOCKED"],[11,"LOBBY_BLOCKED"],[15,"LOBBY_RATE_LIMITED"],[99,"LOBBY_JOIN_FAILED"]]:
			failures.clear()
			native_transport._pending_join = 42
			native_transport._join_generation = native_transport._generation
			native_transport._on_lobby_joined(42,0,false,response[0])
			if failures!=[response[1]] or native_transport.lobby_id!=0:
				errors.append("Steam lobby response "+str(response[0])+" must preserve its actionable reason and leave the session closed.")
		var peer := ClosingPeer.new()
		peer.on_poll = func(): native_transport.close()
		native_transport._peer = peer
		native_transport._process(0.01)
		if native_transport._peer!=null: errors.append("A Steam callback can close its peer while polling.")
		if peer.closed_during_poll: errors.append("A disconnect callback must not close the native Steam peer while its poll is on the stack.")
		await tree.process_frame
		if peer.close_calls!=1: errors.append("A detached Steam peer must still be closed exactly once after polling ends.")
		native_transport.free()
	return errors
