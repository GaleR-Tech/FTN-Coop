extends RefCounted

const Loose = preload("res://mods/ftn_coop/loose_sync.gd")

# Straw world poses are already part of the same confirmed update. Reuse them
# with one inverse hand/tool frame per owner instead of a second pose per straw.
func pack(rows: Array, source: Dictionary, frames: Dictionary) -> Dictionary:
	if rows.size()<8 or not Loose.new().validate(source) or not Loose.new().validate_holds(rows,source.ids): return {"ok":false}
	var data := {"ids":PackedInt32Array(),"peers":PackedInt32Array(),"tools":PackedByteArray(),"frames":[]}
	var used := {}
	for row in rows:
		var key := Vector2i(row.peer,row.tool)
		if not frames.get(key) is Transform3D: return {"ok":false}
		data.ids.append(row.id)
		data.peers.append(row.peer)
		data.tools.append(row.tool)
		if not used.has(key):
			data.frames.append({"peer":row.peer,"tool":row.tool,"frame":frames[key]})
			used[key] = true
	var restored := expand(data,source)
	if not restored.ok: return restored
	for index in range(rows.size()):
		# Different precision builds and capture-time movement retain the full
		# representation unless reconstruction preserves every native pose bit.
		if var_to_bytes(rows[index].offset)!=var_to_bytes(restored.value[index].offset): return {"ok":false}
	return {"ok":true,"value":data}

func expand(data: Variant, source: Dictionary) -> Dictionary:
	if not data is Dictionary or data.size()!=4 or not data.get("ids") is PackedInt32Array or not data.get("peers") is PackedInt32Array or not data.get("tools") is PackedByteArray or not data.get("frames") is Array: return {"ok":false}
	var count: int = data.ids.size()
	if count>Loose.LIMIT or data.peers.size()!=count or data.tools.size()!=count or data.frames.size()>12 or not Loose.new().validate(source): return {"ok":false}
	var frames := {}
	for row in data.frames:
		if not row is Dictionary or row.size()!=3 or typeof(row.get("peer"))!=TYPE_INT or row.peer<1 or row.peer>2147483647 or typeof(row.get("tool"))!=TYPE_INT or row.tool not in [0,1,2] or not row.get("frame") is Transform3D: return {"ok":false}
		var key := Vector2i(row.peer,row.tool)
		if frames.has(key): return {"ok":false}
		var frame: Transform3D = row.frame
		if not frame.origin.is_finite() or not frame.basis.x.is_finite() or not frame.basis.y.is_finite() or not frame.basis.z.is_finite(): return {"ok":false}
		frames[key] = frame
	var offsets := {}
	for index in range(source.ids.size()): offsets[source.ids[index]] = index
	var result := []
	var used := {}
	for index in range(count):
		var key := Vector2i(data.peers[index],data.tools[index])
		var id: int = data.ids[index]
		if not offsets.has(id) or not frames.has(key): return {"ok":false}
		var at: int = int(offsets[id])*12
		var values: PackedFloat32Array = source.poses
		var pose := Transform3D(Basis(Vector3(values[at],values[at+1],values[at+2]),Vector3(values[at+3],values[at+4],values[at+5]),Vector3(values[at+6],values[at+7],values[at+8])),Vector3(values[at+9],values[at+10],values[at+11]))
		result.append({"id":id,"peer":int(data.peers[index]),"tool":int(data.tools[index]),"offset":frames[key]*pose})
		used[key] = true
	if used.size()!=frames.size() or not Loose.new().validate_holds(result,source.ids): return {"ok":false}
	return {"ok":true,"value":result}
