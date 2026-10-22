extends RefCounted

var current: Array = []

func capture(players: Dictionary) -> Array:
	var rows := []
	var peers := players.keys()
	peers.sort()
	for peer in peers:
		var player: Node = players[peer]
		if not is_instance_valid(player): continue
		var row := {"peer":int(peer)}
		for role in ["shovel","pitchfork"]:
			var tool: Variant = player.get(role)
			if not tool is Node or not tool.has_method("carried_strands") or not tool.has_method("capacity") or not tool.has_method("is_full"): break
			row[role] = {"count":int(tool.call("carried_strands")),"capacity":int(tool.call("capacity")),"full":bool(tool.call("is_full"))}
		if row.size()==3: rows.append(row)
	return rows

func validate(rows: Variant) -> bool:
	if not rows is Array or rows.size()>4: return false
	var previous := 0
	for row in rows:
		if not row is Dictionary or row.size()!=3 or typeof(row.get("peer"))!=TYPE_INT or row.peer<=previous or row.peer>2147483647: return false
		previous = row.peer
		for role in ["shovel","pitchfork"]:
			var tool: Variant = row.get(role)
			if not tool is Dictionary or tool.size()!=3 or not tool.get("full") is bool: return false
			for key in ["count","capacity"]:
				if typeof(tool.get(key))!=TYPE_INT or tool[key]<0 or tool[key]>1048576: return false
	return true

func accept(rows: Variant) -> bool:
	if not validate(rows): return false
	current = rows.duplicate(true)
	return true

func selected(peer: int, tool: int) -> Dictionary:
	if tool not in [1,2]: return {}
	for row in current:
		if row.peer==peer:
			var result: Dictionary = row.shovel.duplicate() if tool==1 else row.pitchfork.duplicate()
			result.tool = tool
			return result
	return {}
