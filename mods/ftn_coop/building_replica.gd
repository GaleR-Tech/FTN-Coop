extends RefCounted

# Only observed V66 inventory/counter fields may change without rebuilding the
# native geometry. Configuration, position, tiers and unknown fields still use
# the full native restore path.
const LIVE := {
	"hay_generator":["fuel"],
	"hay_compressor":["stored","needles"],
	"hay_silo":["queued","stored","needles"],
	"haystack_scanner":["banked","stored","loads","blocks"],
	"hay_drone":["trips"],
	"conveyor_splitter":["next_side"],"conveyor_u_splitter":["next_side"],
	"conveyor_t_splitter":["next_side"],"conveyor_joiner":["next_side"],
	"conveyor_u_joiner":["next_side"]
}
const COLLECTION := {
	"hay_generator":"generators","hay_compressor":"compressors",
	"hay_silo":"silos","haystack_scanner":"scanners","hay_drone":"hay_drones",
	"conveyor_splitter":"splitters","conveyor_u_splitter":"splitters",
	"conveyor_t_splitter":"splitters","conveyor_joiner":"joiners",
	"conveyor_u_joiner":"joiners"
}

func difference(before: Array, records: Array) -> Dictionary:
	var rows := []
	for index in range(records.size()):
		if before[index]!=records[index]: rows.append({"index":index,"record":records[index]})
	return {"count":records.size(),"rows":rows}

func expand(before: Array, delta: Variant) -> Dictionary:
	if not delta is Dictionary or delta.size()!=2 or typeof(delta.get("count"))!=TYPE_INT or delta.count!=before.size() or delta.count>32768 or not delta.get("rows") is Array or delta.rows.is_empty() or delta.rows.size()>before.size(): return {"ok":false}
	var result: Array = before.duplicate()
	var previous := -1
	for row in delta.rows:
		if not row is Dictionary or row.size()!=2 or typeof(row.get("index"))!=TYPE_INT or row.index<=previous or row.index>=before.size() or not row.get("record") is Dictionary: return {"ok":false}
		previous = row.index
		result[row.index] = row.record
	return {"ok":true,"value":result}

func layout(records: Array) -> Array:
	var result := []
	for record in records:
		var row: Dictionary = record.duplicate()
		for key in LIVE.get(row.get("type",""),[]): row.erase(key)
		result.append(row)
	return result

func update(manager: Node, before: Array, records: Array) -> bool:
	var properties := {}
	for property in manager.get_property_list(): properties[str(property.name)] = true
	for index in range(records.size()):
		var row: Dictionary = records[index]
		if row==before[index]: continue
		var collection: String = COLLECTION.get(row.get("type",""),"")
		if not properties.has(collection): return false
		var candidates: Variant = manager.get(collection)
		if not candidates is Array: return false
		var target: Node3D
		for candidate in candidates:
			if is_instance_valid(candidate) and candidate is Node3D and candidate.global_position.is_equal_approx(row.position):
				if target!=null: return false
				target = candidate
		if target==null: return false
		if row.type=="hay_silo" and target.has_method("from_dict"):
			target.call("from_dict",row)
			continue
		var fields := {}
		for property in target.get_property_list(): fields[str(property.name)] = true
		for key in LIVE[row.type]:
			if not row.has(key) or row.get(key)==before[index].get(key): continue
			if key=="loads" and target.has_method("restore_loads"):
				target.call("restore_loads",row[key]); continue
			var name: String = "pending_needles" if key=="needles" else key
			if not fields.has(name) or typeof(target.get(name))!=typeof(row[key]): return false
			var value: Variant = row[key]
			target.set(name,value.duplicate(true) if value is Dictionary or value is Array else value)
	return true
