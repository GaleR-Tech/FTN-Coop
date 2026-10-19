extends RefCounted

const MAX_NODES := 384
const MAX_VISITS := 8192
const MAX_DEPTH := 10
const MAX_MEMBERS := 192

func inspect(root: Node) -> Dictionary:
	if root == null or not is_instance_valid(root):
		return {"ok": false, "code": "ROOT_MISSING", "value": null}
	var steam := {
		"singleton": Engine.has_singleton("Steam"),
		"multiplayer_peer": ClassDB.class_exists("SteamMultiplayerPeer"),
		"methods": [],
		"transport_methods": {},
		"peer_methods": [],
	}
	if steam.singleton:
		# Read signatures only. Never invoke Steam account or game operations.
		steam.methods = _method_signatures(Engine.get_singleton("Steam").get_method_list())
		for method_name in ["createLobby", "joinLobby", "leaveLobby", "setLobbyData", "getLobbyData", "getLobbyOwner", "getSteamID", "activateGameOverlayInviteDialog", "get_steam_init_result"]:
			steam.transport_methods[method_name] = Engine.get_singleton("Steam").has_method(method_name)
	if steam.multiplayer_peer:
		steam.peer_methods = _method_signatures(ClassDB.class_get_method_list("SteamMultiplayerPeer", true))
	var nodes: Array[Dictionary] = []
	var scripts: Dictionary = {}
	var pending: Array[Dictionary] = [{"node": root, "indices": [], "depth": 0}]
	var truncated := false
	var cursor := 0
	while cursor < pending.size() and cursor < MAX_VISITS and nodes.size() < MAX_NODES:
		var entry: Dictionary = pending[cursor]
		cursor += 1
		var node: Node = entry.node
		if not is_instance_valid(node):
			continue
		var descriptor := {
			"indices": entry.indices,
			"type": node.get_class(),
			"scene": node.scene_file_path,
			"script": "",
		}
		var script: Script = node.get_script() as Script
		if script != null:
			var script_key := script.resource_path
			if script_key.is_empty():
				script_key = "runtime-script-" + str(script.get_instance_id())
			descriptor.script = script_key
			if not scripts.has(script_key):
				var members := {"methods": _method_signatures(script.get_script_method_list()), "properties": []}
				for property in script.get_script_property_list().slice(0, MAX_MEMBERS):
					members.properties.append({"name": str(property.name), "type": int(property.type)})
				scripts[script_key] = members
		if script != null or node == root:
			nodes.append(descriptor)
		if int(entry.depth) < MAX_DEPTH:
			for child_index in range(node.get_child_count()):
				if pending.size() >= MAX_VISITS:
					truncated = true
					break
				var indices: Array = entry.indices.duplicate()
				indices.append(child_index)
				pending.append({"node": node.get_child(child_index), "indices": indices, "depth": int(entry.depth) + 1})
		elif node.get_child_count() > 0:
			truncated = true
	return {"ok": true, "code": "OK", "value": {
		"engine": str(Engine.get_version_info().get("string", "unknown")),
		"steam": steam,
		"nodes": nodes,
		"scripts": scripts,
		"truncated": truncated or cursor < pending.size(),
		"bindings_verified": false,
		"capabilities": {},
	}}

func _method_signatures(methods: Array) -> Array[Dictionary]:
	var signatures: Array[Dictionary] = []
	for method in methods.slice(0, MAX_MEMBERS):
		var signature := {"name": str(method.name), "args": [], "return_type": int(method.get("return", {}).get("type", TYPE_NIL))}
		for argument in method.get("args", []):
			signature.args.append({"name": str(argument.name), "type": int(argument.type)})
		signatures.append(signature)
	return signatures
