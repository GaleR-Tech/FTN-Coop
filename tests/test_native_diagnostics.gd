extends RefCounted

class Player extends Node:
	var current_tool := 1

class Network extends Node:
	var _transport: Node

class Runtime extends Node:
	var ui: CanvasLayer

func run(tree: SceneTree) -> Array[String]:
	var errors: Array[String] = []
	var diagnostic: Node = load("res://mods/ftn_coop/native_network_check.gd").new()
	for value in [12.5, 7, false, "bucket", PackedByteArray([1,2]), [1,2]]:
		var digest: String = diagnostic._digest(value)
		if digest.length()!=64: errors.append("Every native field type needs a real SHA256 fingerprint: "+type_string(typeof(value)))
	if diagnostic._digest(12.5)==diagnostic._digest(13.5): errors.append("Changed native scalar values must have different fingerprints.")
	if diagnostic._digest({"b":2,"a":1})!=diagnostic._digest({"a":1,"b":2}): errors.append("Native dictionary order must not change fingerprints.")
	var adapter: RefCounted = load("res://mods/ftn_coop/game_adapter.gd").new()
	var player := Player.new()
	adapter.nodes.player = player
	adapter.guest_mode = true
	adapter.set_local_peer(2)
	var network := Network.new()
	var wire: Node = load("res://tests/fixtures/fake_transport.gd").new()
	network._transport = wire
	var runtime := Runtime.new()
	runtime.ui = load("res://mods/ftn_coop/coop_ui.gd").new()
	tree.root.add_child(runtime.ui)
	var session: Node = load("res://mods/ftn_coop/session.gd").new()
	session.state = session.State.PLAYING
	runtime.ui.bind_session(session)
	runtime.ui.set_panel_open(false)
	runtime.ui.set_tool_load({"tool":1,"count":5,"capacity":72,"full":false})
	runtime.ui._process(0.0)
	if not runtime.ui._tool_feedback.visible: errors.append("The native release regression needs an initially visible loaded tool counter.")
	diagnostic._adapter = adapter
	diagnostic._network = network
	diagnostic._runtime = runtime
	diagnostic._checks.tool_load_received = true
	diagnostic._check_guest_load_visuals()
	if not diagnostic._checks.get("tool_load_emptied",false) or runtime.ui._tool_feedback.visible:
		errors.append("Removing a controlled actor must clear its tool display and count as a confirmed end of that native load.")
	for node in [runtime.ui,runtime,session,network,wire,player]: node.free()
	diagnostic.free()
	return errors
