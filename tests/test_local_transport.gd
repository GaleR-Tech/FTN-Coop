extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/local_transport.gd"):
		return ["Loopback-only transport for real process tests is not implemented yet."]
	var errors: Array[String] = []
	var module: Script = load("res://mods/ftn_coop/local_transport.gd")
	var host: Node = module.new()
	var guest: Node = module.new()
	tree.root.add_child(host)
	tree.root.add_child(guest)
	var port := 24000+(randi()%20000)
	host.port = port
	guest.port = port
	var peers: Array = []
	var packets: Dictionary = {}
	var client_ready := [false]
	guest.connected.connect(func(peer: int):
		if peer==1: client_ready[0]=true
	)
	host.connected.connect(func(peer: int): peers.append(peer))
	host.message_received.connect(func(peer: int,channel: int,bytes: PackedByteArray): packets[channel]={"peer":peer,"bytes":bytes})
	var begun: Dictionary = host.host(4)
	if not begun.ok:
		errors.append("Local test server could not bind 127.0.0.1: "+begun.code)
	else:
		guest.join(1)
		var deadline := Time.get_ticks_msec()+2000
		while Time.get_ticks_msec()<deadline and (peers.is_empty() or not client_ready[0]): await tree.process_frame
		if peers.size()!=1 or guest.local_peer_id()<=1: errors.append("Real local peers must connect with distinct IDs.")
		else:
			guest.send(1,0,PackedByteArray([11]),true)
			guest.send(1,1,PackedByteArray([22]),false)
			deadline = Time.get_ticks_msec()+2000
			while Time.get_ticks_msec()<deadline and packets.size()<2: await tree.process_frame
			if packets.size()!=2 or packets[0].bytes!=PackedByteArray([11]) or packets[1].bytes!=PackedByteArray([22]):
				errors.append("Reliable world data and lossy poses must preserve their channels and payloads.")
	guest.close()
	host.close()
	guest.queue_free()
	host.queue_free()
	await tree.process_frame
	return errors
