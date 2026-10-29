# Test-only observations of native draw nodes; no simulation or render mutation.
extends RefCounted

func inspect(adapter: RefCounted) -> Dictionary:
	var field: Node = adapter.nodes.field
	var camera: Camera3D = adapter.nodes.player.get("camera")
	var report := {"chunks":0,"piece_nodes":0,"visible_pieces":0,"visible_instances":0,"shell_nodes":0,"shell_instances":0,"invalid_transforms":0,"slot_errors":0,"lod_follows_camera":field.get("_lod_eye").distance_to(camera.global_position)<0.1,"machine_lod_static":false,"presentation":{}}
	if adapter._guest_view!=null and adapter._guest_view._machine_lod!=null:
		for method in adapter._guest_view._machine_lod.get_script_method_list():
			if method.name=="tick" and (int(method.flags)&METHOD_FLAG_STATIC)!=0: report.machine_lod_static = true
	for chunk in field.get("chunks"):
		if not is_instance_valid(chunk): continue
		report.chunks += 1
		var shell: Variant = chunk.get("_surf_mi")
		if shell is MultiMeshInstance3D and shell.multimesh!=null:
			report.shell_nodes += 1
			if shell.is_visible_in_tree(): report.shell_instances += shell.multimesh.instance_count if shell.multimesh.visible_instance_count<0 else shell.multimesh.visible_instance_count
		if chunk.has_method("_set_slots"):
			if int(chunk.get("_shown"))<0 or int(chunk.get("_shown"))>int(chunk.get("_slots")): report.slot_errors += 1
			var pieces: Array = chunk.get("_piece_mis").duplicate()
			if pieces.is_empty() and chunk.get("_mmi") is MultiMeshInstance3D: pieces.append(chunk.get("_mmi"))
			for node in pieces:
				if not node is MultiMeshInstance3D or node.multimesh==null: continue
				report.piece_nodes += 1
				var count: int = node.multimesh.visible_instance_count
				if count<0: count = node.multimesh.instance_count
				if count<=0 or not node.is_visible_in_tree(): continue
				report.visible_pieces += 1
				report.visible_instances += count
				for index in [0,count-1]:
					var pose: Transform3D = node.multimesh.get_instance_transform(index)
					if not pose.origin.is_finite() or not pose.basis.x.is_finite() or not pose.basis.y.is_finite() or not pose.basis.z.is_finite(): report.invalid_transforms += 1
	_scan(adapter.nodes.world,report.presentation)
	return report

func _scan(node: Node, found: Dictionary) -> void:
	var script: Script = node.get_script()
	if script!=null and script.resource_path in ["res://scripts/build/belt_batch.gd","res://scripts/build/structure_cull.gd","res://scripts/world/machine_lod.gd","res://scripts/world/shadow_lod.gd"]:
		var row: Dictionary = found.get(script.resource_path,{"nodes":0,"processing":0,"dirty":0,"near_queue":0})
		row.nodes += 1
		if node.can_process(): row.processing += 1
		for property in script.get_script_property_list():
			if property.name=="_dirty" and node.get("_dirty") is Dictionary: row.dirty += node.get("_dirty").size()
			if property.name=="_near_queue" and node.get("_near_queue") is Dictionary: row.near_queue += node.get("_near_queue").size()
		found[script.resource_path] = row
	for child in node.get_children(): _scan(child,found)
