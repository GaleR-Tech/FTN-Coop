extends RefCounted

const SHARED := ["field","warehouse","shop","leaderboards","map","bay_door","floor_hatch","board","sell_all_dialog","catalog","rake_panel","pelletizer_panel","launcher_panel","lamp_panel","switch_box_panel","tag_show","splitter_panel","t_panel","lift_panel","silo_panel","paint_panel","arm_panel","arm_links","drone_panel","drone_zone","wire_mode","machine_panel","pole_panel","tech_panel","inspector","needle_drawer","demo_end_dialog","needle_panel","load_panel","pause_menu","bug_report"]
const TOOLS := ["hand","shovel","pitchfork","broom","detector","yard_vac","lighter","build","carry","aim"]

func create(source: Node, world: Node, peer_id: int) -> Dictionary:
	if source == null or world == null or source.get_script() == null or source.get_script().resource_path != "res://scripts/player/player.gd" or peer_id <= 1:
		return {"ok":false,"code":"CAPABILITY_MISSING","value":null}
	# Instantiate the game's own controller without reading encrypted sources.
	var actor: Node = source.get_script().new()
	actor.name = "FtnCoopController" + str(peer_id)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	for member in SHARED: actor.set(member,source.get(member))
	world.add_child(actor)
	if actor.get("camera") is Camera3D: actor.get("camera").current = false
	if source.get("camera") is Camera3D: source.get("camera").current = true
	return {"ok":true,"code":"OK","value":actor}

func bind_tools(actor: Node, source: Node) -> Dictionary:
	for role in TOOLS:
		var original: Variant = source.get(role)
		var target: Variant = actor.get(role)
		if not original is Node or not target is Node: continue
		for property in original.get_script().get_script_property_list():
			if property.type != TYPE_OBJECT: continue
			var reference: Variant = original.get(property.name)
			if not reference is Node: continue
			if reference == source: target.set(property.name,actor)
			elif source.is_ancestor_of(reference):
				var replacement: Node = actor.get_node_or_null(source.get_path_to(reference))
				if replacement != null: target.set(property.name,replacement)
			elif not str(property.name).begins_with("_"):
				# Only public world dependencies are shared. Private runtime
				# references such as carry._held belong to the original player.
				target.set(property.name,reference)
	if actor.get("camera") is Camera3D: actor.get("camera").current = false
	if source.get("camera") is Camera3D: source.get("camera").current = true
	# The player controller stays disabled: it must never read host input.
	# Native tool animations, pickup flight and held bodies need their ticks.
	for role in TOOLS:
		var tool: Variant = actor.get(role)
		if tool is Node:
			tool.process_mode = Node.PROCESS_MODE_PAUSABLE
			tool.set_process_input(false)
			tool.set_process_unhandled_input(false)
			tool.set_process_unhandled_key_input(false)
	if not actor.get("hand") is Node or actor.get("hand") == source.get("hand"):
		return {"ok":false,"code":"ACTOR_NOT_READY","value":null}
	return {"ok":true,"code":"OK","value":actor}
