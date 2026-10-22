extends RefCounted

class NativeLoose extends Node3D:
	var _mmi := MultiMeshInstance3D.new()
	func _init() -> void:
		_mmi.multimesh = MultiMesh.new()
		_mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		_mmi.multimesh.mesh = QuadMesh.new()
		_mmi.material_override = StandardMaterial3D.new()
		add_child(_mmi)

class HeldTool extends Node:
	var body := Node3D.new()
	var _riding: Dictionary = {}
	func _init() -> void: add_child(body)

class Hand extends Node:
	var bodies: Array = []
	func held_bodies() -> Array: return bodies

class Holder extends Node3D:
	var shovel := HeldTool.new()
	var pitchfork := HeldTool.new()
	var hand := Hand.new()
	var camera := Camera3D.new()
	func _init() -> void:
		add_child(shovel)
		add_child(pitchfork)
		add_child(hand)
		add_child(camera)

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/loose_sync.gd"):
		return ["Host-owned loose resource display is not implemented yet."]
	var errors: Array[String] = []
	var module: Script = load("res://mods/ftn_coop/loose_sync.gd")
	var host: RefCounted = module.new()
	var guest: RefCounted = module.new()
	var source := Node3D.new()
	tree.root.add_child(source)
	var hay_a := Node3D.new()
	var hay_b := Node3D.new()
	var needle := Node3D.new()
	for body in [hay_a,hay_b,needle]: source.add_child(body)
	hay_b.position = Vector3(1,2,3)
	hay_a.set_meta("tint",Color(0.9,0.7,0.2,1.0))
	var first: Dictionary = host.capture_sources([hay_a,hay_b],[needle])
	if not first.ok or first.value.ids.size() != 3:
		source.free()
		return ["Hay and needles must receive host-owned stable IDs and poses."]
	var original_ids: PackedInt32Array = first.value.ids.duplicate()
	if not host.has_method("capture_holds") or not guest.has_method("follow_local"):
		errors.append("The guest's loaded straw must follow its own shovel while retaining the authoritative world transforms.")
	else:
		var holder := Holder.new()
		source.add_child(holder)
		# Native tools map instance IDs to the carried physics bodies.
		holder.shovel._riding[hay_a.get_instance_id()] = hay_a
		var holds: Array = host.capture_holds({2:holder})
		if holds.size()!=1 or holds[0].id!=original_ids[0] or holds[0].peer!=2 or holds[0].tool!=1:
			errors.append("Held straw must map to its owning peer, native tool and stable loose ID.")
			holder.free()
			guest.close()
			source.free()
			return errors
		guest.apply(first.value,tree.root)
		guest.held = holds
		holder.shovel.body.position = Vector3(3,2,1)
		guest.follow_local(2,holder)
		# The headless dummy renderer does not retain GPU transforms. Native
		# integration checks the visible batch; here verify state stays authoritative.
		if guest.current!=first.value:
			errors.append("Local tool motion must not rewrite the authoritative loose snapshot.")
		guest.follow_local(3,holder)
		if not guest.validate_holds(holds,first.value.ids): errors.append("Native held straw offsets must validate against the received pool.")
		holder.shovel._riding.clear()
		holder.hand.bodies = [hay_a]
		var hand_holds: Array = host.capture_holds({2:holder})
		if hand_holds.size()!=1 or hand_holds[0].id!=original_ids[0] or hand_holds[0].tool!=0 or not guest.validate_holds(hand_holds,first.value.ids):
			errors.append("Straw in the native hand must follow its owner's camera using the same stable loose ID.")
		var bad_holds := holds.duplicate(true)
		bad_holds[0].id = 99999
		if guest.validate_holds(bad_holds,first.value.ids): errors.append("Held visuals cannot refer to a missing straw ID.")
		if not guest.has_method("accept_holds"):
			errors.append("Ending local ownership must restore released straw from its authoritative transform.")
		else:
			if guest.accept_holds(bad_holds) or guest.held!=holds: errors.append("Invalid ownership updates must leave the displayed owner mapping intact.")
			if not guest.accept_holds([]) or not guest.held.is_empty() or guest.current!=first.value:
				errors.append("Released straw must clear its owner without changing authoritative world data.")
		holder.free()
	if not first.value.get("colors") is PackedColorArray or first.value.colors.size()!=3 or first.value.colors[0]!=Color(0.9,0.7,0.2,1.0):
		errors.append("Host straw tint must survive capture instead of being replaced by a uniform placeholder color.")
	var codec: RefCounted = load("res://mods/ftn_coop/value_codec.gd").new()
	var encoded: Dictionary = codec.encode(first.value,1024*1024)
	if not encoded.ok or codec.decode(encoded.value,1024*1024).value != first.value:
		errors.append("Loose frames must round-trip through the actual wire data codec.")
	hay_b.position = Vector3(4,5,6)
	var moved: Dictionary = host.capture_sources([hay_b,hay_a],[needle])
	if moved.value.ids != original_ids: errors.append("Pool order must not change network identity.")
	if not host.has_method("difference") or not guest.has_method("apply_delta"):
		errors.append("Moving one loose strand must update that strand without retransmitting the entire native pool.")
	else:
		guest.apply(first.value,tree.root)
		var delta: Dictionary = host.difference(first.value,moved.value)
		if delta.removed!=PackedInt32Array() or delta.updated.ids!=PackedInt32Array([original_ids[1]]):
			errors.append("A one-strand move must contain only its stable ID and new visual state.")
		if not guest.apply_delta(delta,tree.root).ok or guest.current!=moved.value:
			errors.append("Applying sparse loose state must retain the untouched straw and needle.")
		var next: Dictionary = host.capture_sources([hay_b],[needle])
		var removed_delta: Dictionary = host.difference(moved.value,next.value)
		if removed_delta.removed!=PackedInt32Array([original_ids[0]]) or not removed_delta.updated.ids.is_empty():
			errors.append("Removing a consumed strand must send only its ID, without resending surviving transforms.")
		if not guest.apply_delta(removed_delta,tree.root).ok or guest.current!=next.value:
			errors.append("Loose removals must preserve every surviving ID and transform.")
		var bad_delta := removed_delta.duplicate(true)
		bad_delta.removed = PackedInt32Array([99999])
		if guest.apply_delta(bad_delta,tree.root).ok or guest.current!=next.value:
			errors.append("A delta removing an unknown strand must reject atomically.")
		var new_hay := Node3D.new()
		source.add_child(new_hay)
		var added: Dictionary = host.capture_sources([hay_b,new_hay],[needle])
		if not guest.apply_delta(host.difference(next.value,added.value),tree.root).ok or guest.current!=added.value:
			errors.append("A new pool strand must appear while existing straw and needles retain their identity.")
	var removed: Dictionary = host.capture_sources([hay_b],[needle])
	if original_ids[0] in removed.value.ids: errors.append("Consumed hay must disappear from the next authoritative frame.")
	if not guest.apply(first.value,tree.root).ok or guest.current != first.value:
		errors.append("Guest resource visuals must reproduce the host data without native production.")
	var invalid: Dictionary = first.value.duplicate(true)
	invalid.poses[0] = NAN
	if guest.apply(invalid,tree.root).code != "LOOSE_INVALID" or guest.current != first.value:
		errors.append("Invalid loose poses must be rejected before changing the replica.")
	var oversized: Array = []
	oversized.resize(8193)
	if host.capture_sources(oversized,[]).code != "LOOSE_LIMIT": errors.append("Loose resources must have a fixed memory and rendering bound.")
	guest.close()
	var native := NativeLoose.new()
	tree.root.add_child(native)
	if not guest.has_method("use_native_visuals"):
		errors.append("Guest loose straw must reuse native mesh and material resources in its own render-only batch.")
	else:
		guest.use_native_visuals(native)
		guest.apply(first.value,tree.root)
		if guest._hay.mesh!=native._mmi.multimesh.mesh or guest._root.get_child(0).material_override!=native._mmi.material_override:
			errors.append("Replica geometry and shading must come from the native straw renderer without modifying it.")
		if not guest._hay.use_colors:
			errors.append("Native straw batches must enable the captured per-instance host tint.")
		if native._mmi.multimesh.instance_count!=0 or guest._root.get_child_count()!=2:
			errors.append("Guest loose rendering must not borrow native pool slots or create collectible physics bodies.")
		var tinted_bad: Dictionary = first.value.duplicate(true)
		tinted_bad.colors[0] = Color(NAN,0,0,1)
		if guest.apply(tinted_bad,tree.root).ok or guest.current!=first.value: errors.append("Non-finite remote tint must fail before replacing valid resource visuals.")
		guest.close()
	native.free()
	source.free()
	return errors
