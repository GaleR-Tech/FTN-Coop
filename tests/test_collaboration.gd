extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	for name in ["marker_state","connection_status","player_colors"]:
		if not FileAccess.file_exists("res://mods/ftn_coop/"+name+".gd"): return ["Missing collaboration module: "+name]
	var errors: Array[String] = []
	var markers: RefCounted = load("res://mods/ftn_coop/marker_state.gd").new()
	var placed: Dictionary = markers.place(2,Vector3(3,0,4),"build",Vector3.ZERO)
	if not placed.ok or markers.snapshot().size()!=1: errors.append("A reachable surface marker must be accepted.")
	if markers.place(2,Vector3.ZERO,"point",Vector3.ZERO).ok: errors.append("Repeated placement within one second must be limited.")
	markers.advance(1.0)
	for args in [[Vector3(51,0,0),"point"],[Vector3(NAN,0,0),"point"],[Vector3.ZERO,"execute"]]:
		if markers.place(2,args[0],args[1],Vector3.ZERO).ok: errors.append("Invalid marker position/type must be rejected.")
	if not markers.place(2,Vector3(1,0,0),"help",Vector3.ZERO).ok or markers.snapshot().size()!=1: errors.append("A new marker must replace only that player's marker.")
	for peer in [3,4,5]: markers.place(peer,Vector3.ZERO,"needle",Vector3.ZERO)
	if markers.place(6,Vector3.ZERO,"point",Vector3.ZERO).ok: errors.append("Marker storage must remain bounded to four participants.")
	var replica: RefCounted = load("res://mods/ftn_coop/marker_state.gd").new()
	if not replica.accept_snapshot(markers.snapshot()).ok: errors.append("Canonical markers must round-trip to display state.")
	var before: Array = replica.snapshot()
	if replica.accept_snapshot([{"peer":2,"position":Vector3.ZERO,"kind":"point","remaining":21.0}]).ok or replica.snapshot()!=before: errors.append("A bad snapshot must be rejected without replacing good markers.")
	markers.remove_peer(3)
	if markers.snapshot().size()!=3: errors.append("A departed player's marker must disappear.")
	markers.advance(20.0)
	if not markers.snapshot().is_empty(): errors.append("Markers must expire after twenty seconds.")
	var status: RefCounted = load("res://mods/ftn_coop/connection_status.gd").new()
	var probe: Dictionary = status.begin(2,1000)
	if not probe.ok: return errors+["A connection probe must start."]
	if status.accept_reply(3,probe.value,1020).ok or status.accept_reply(2,probe.value+1,1020).ok: errors.append("Wrong peer/token must not establish latency.")
	if not status.accept_reply(2,probe.value,1040).ok or status.snapshot(2,1040).get("latency_ms")!=40: errors.append("Correlated latency must measure the actual forty millisecond round trip.")
	if status.accept_reply(2,probe.value,1045).ok: errors.append("Repeated replies must be rejected.")
	status.clear()
	var second: Dictionary = status.begin(2,2000)
	if second.value==probe.value or status.accept_reply(2,probe.value,2040).ok: errors.append("A cleared connection must not reuse or accept an old probe token.")
	if status.snapshot(2,12000).get("latency_ms",0)!=-1: errors.append("Missing/expired replies must be unavailable, never fabricated zero latency.")
	status.remove_peer(2)
	if status.snapshot(2,12000).get("latency_ms",0)!=-1: errors.append("Removing a peer must clear its measurement.")
	errors.append_array(await _routing(tree))
	return errors

func _routing(tree: SceneTree) -> Array[String]:
	var controller: Script = load("res://mods/ftn_coop/network_controller.gd")
	var probe: Node = controller.new()
	if not probe.has_method("request_marker") or not probe.has_signal("player_status_changed"):
		probe.free()
		return ["Authenticated collaboration routing is missing."]
	probe.free()
	var boundary: Script = load("res://tests/fixtures/network_game_boundary.gd")
	var pipe: Script = load("res://tests/fixtures/pipe_transport.gd")
	var host: Node = controller.new()
	var guest: Node = controller.new()
	var host_game: RefCounted = boundary.new()
	var guest_game: RefCounted = boundary.new()
	host_game.tree = tree
	guest_game.tree = tree
	var a: Node = pipe.new()
	var b: Node = pipe.new()
	b.peer_id = 2
	a.other = b
	b.other = a
	for node in [a,b,host,guest]: tree.root.add_child(node)
	host.configure(a,host_game,"25963876","0.3.0")
	guest.configure(b,guest_game,"25963876","0.3.0")
	var flood_bounded := [true]
	guest_game.restore_started.connect(func():
		var codec: RefCounted = load("res://mods/ftn_coop/protocol.gd").new()
		var before: int = host._tx.size()
		for i in range(100):
			var packet: Dictionary = codec.encode({"protocol":1,"type":"LOAD_STATUS","session":host.session.session_id,"body":{"stage":"loading" if i%2==0 else "catching_up","_connection":guest.connection_id}})
			host._on_message(2,0,packet.value)
		flood_bounded[0] = host._tx.size()-before<=8
	)
	host.host()
	await tree.process_frame
	guest.join(42)
	var deadline := Time.get_ticks_msec()+2000
	while guest.session.state!=guest.session.State.PLAYING and Time.get_ticks_msec()<deadline: await tree.process_frame
	var errors: Array[String] = []
	if not flood_bounded[0]: errors.append("Excessive loading-status announcements must not flood the host's reliable queue.")
	if guest.session.state!=guest.session.State.PLAYING: errors.append("Collaboration test must establish a real authenticated session.")
	else:
		if not guest.request_marker(Vector3(3,0,4),"build").ok: errors.append("A guest must request a marker while playing.")
		for frame in range(20): await tree.process_frame
		var snapshot: Dictionary = host.collaboration_snapshot()
		if snapshot.markers.size()!=1 or snapshot.markers[0].peer!=2 or guest.collaboration_snapshot().markers.size()!=1: errors.append("Guest markers must be owned by the authenticated sender and distributed by the host.")
		if not snapshot.players.has(2) or snapshot.players[2].get("latency_ms",-1)<0 or snapshot.players[2].state!="playing": errors.append("Real probe replies and playable state must reach the player status list.")
		var protocol: RefCounted = load("res://mods/ftn_coop/protocol.gd").new()
		var invalid: Dictionary = protocol.encode({"protocol":1,"type":"MARKER_REQUEST","session":host.session.session_id,"body":{"position":Vector3(8,0,0),"kind":"help","_connection":"00000000000000000000000000000000"}})
		host._on_message(2,0,invalid.value)
		if host.collaboration_snapshot().markers!=snapshot.markers: errors.append("A marker with a forged connection cookie must not replace the real marker.")
		host.request_marker(Vector3(1,0,0),"help")
		for frame in range(10): await tree.process_frame
		if guest.collaboration_snapshot().markers.size()!=2: errors.append("The host's own marker must be visible to guests.")
	guest.leave()
	for frame in range(4): await tree.process_frame
	for row in host.collaboration_snapshot().markers:
		if row.peer==2: errors.append("Leaving must remove the departed guest's marker.")
	if not guest.collaboration_snapshot().markers.is_empty() or not guest.collaboration_snapshot().players.is_empty(): errors.append("Leaving must clear all replicated collaboration state.")
	host.leave()
	for node in [host,guest,a,b]: node.queue_free()
	await tree.process_frame
	return errors
