extends Node3D

var avatars: Dictionary = {}

func sync_roster(local_peer: int, roster: Dictionary) -> void:
	for peer in avatars.keys():
		if peer==local_peer or not roster.has(peer):
			avatars[peer].queue_free()
			avatars.erase(peer)
	for peer in roster:
		if peer==local_peer: continue
		if not avatars.has(peer):
			var avatar: Node3D = load(get_script().resource_path.get_base_dir()+"/avatar.gd").new()
			avatar.name = "Mitspieler"+str(peer)
			add_child(avatar)
			avatars[peer] = avatar
		avatars[peer].set_display_name(str(roster[peer].get("name","Mitspieler")))

func apply_pose(peer: int, pose: Dictionary) -> void:
	if avatars.has(peer): avatars[peer].apply_pose(pose)

func clear() -> void:
	for avatar in avatars.values(): avatar.queue_free()
	avatars.clear()
