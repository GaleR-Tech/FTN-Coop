extends RefCounted

const CATEGORIES := {"paths":"records","lifts":"rows","stairs":"rows"}

func difference(before: Dictionary, after: Dictionary) -> Dictionary:
	if before.size()!=after.size(): return {}
	var delta := {}
	for category in after:
		if not before.has(category): return {}
		if before[category]==after[category]: continue
		if not CATEGORIES.has(category) or not before[category] is Array or not after[category] is Array or before[category].size()!=after[category].size(): return {}
		var key: String = CATEGORIES[category]
		var rows := []
		for index in range(after[category].size()):
			var previous: Variant = before[category][index]
			var current: Variant = after[category][index]
			if previous==current: continue
			if not previous is Dictionary or not current is Dictionary or not current.get(key) is Array: return {}
			var layout: Dictionary = current.duplicate()
			layout[key] = previous.get(key)
			if layout!=previous: return {}
			rows.append({"index":index,"records":current[key]})
		delta[category] = {"count":after[category].size(),"rows":rows}
	return delta

func expand(before: Dictionary, delta: Variant) -> Dictionary:
	if not delta is Dictionary or delta.is_empty() or delta.size()>3: return {"ok":false}
	var result: Dictionary = before.duplicate()
	for category in delta:
		if not CATEGORIES.has(category) or not before.get(category) is Array: return {"ok":false}
		var changes: Variant = delta[category]
		var baseline: Array = before[category]
		if not changes is Dictionary or changes.size()!=2 or typeof(changes.get("count"))!=TYPE_INT or changes.count!=baseline.size() or changes.count>32768 or not changes.get("rows") is Array or changes.rows.is_empty() or changes.rows.size()>baseline.size(): return {"ok":false}
		var rows: Array = baseline.duplicate()
		var previous := -1
		for change in changes.rows:
			if not change is Dictionary or change.size()!=2 or typeof(change.get("index"))!=TYPE_INT or change.index<=previous or change.index>=baseline.size() or not change.get("records") is Array or change.records.size()>65536: return {"ok":false}
			if not baseline[change.index] is Dictionary: return {"ok":false}
			for record in change.records:
				if not _cargo_valid(record,category=="paths"): return {"ok":false}
			previous = change.index
			var row: Dictionary = baseline[change.index].duplicate()
			row[CATEGORIES[category]] = change.records.duplicate(true)
			rows[change.index] = row
		result[category] = rows
	return {"ok":true,"value":result}

func _cargo_valid(record: Variant, path: bool) -> bool:
	if not record is Dictionary or not record.get("xform") is Transform3D or not record.get("state") is Dictionary: return false
	for field in ["kind","strands","needle"]:
		if typeof(record.get(field))!=TYPE_INT: return false
	if record.kind<0 or record.kind>255: return false
	# Path records require the same schema as a full snapshot. Vertical movers
	# may omit path coordinates, but any supplied coordinates must be numeric.
	for field in ["reach","side","lift","s","speed"]:
		if (path or record.has(field)) and typeof(record.get(field)) not in [TYPE_INT,TYPE_FLOAT]: return false
	return true
