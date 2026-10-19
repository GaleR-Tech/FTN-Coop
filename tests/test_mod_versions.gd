extends RefCounted

class LobbySteam extends RefCounted:
	var data := {"ftn_coop_protocol":"1","ftn_coop_build":"25963876","ftn_coop_mod":"0.1.1"}
	var left: Array = []
	func getLobbyData(_lobby: int, key: String) -> String: return data.get(key,"")
	func leaveLobby(lobby: int) -> void: left.append(lobby)

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/mod_version.gd"):
		return ["Version mismatch needs safe local/lobby version details and an update hint."]
	var errors: Array[String] = []
	var version: Script = load("res://mods/ftn_coop/mod_version.gd")
	if version.safe_version("0.1.4")!="0.1.4" or version.DOWNLOAD_URL!="https://github.com/GaleR-Tech/FTN-Coop/releases":
		errors.append("Version details must use exact versions and the project's fixed download page.")
	for bad in [null,1,{},"https://evil.invalid","0.1.4\nPRIVATE_NAME","<script>","x".repeat(1000)]:
		if not version.safe_version(bad).is_empty(): errors.append("Untrusted version text must not reach the update hint.")
	var wire: Node = load("res://mods/ftn_coop/steam_transport.gd").new()
	var steam := LobbySteam.new()
	wire._steam = steam
	wire.mod_version = "0.1.4"
	wire._pending_join = 42
	wire._join_generation = wire._generation
	var failed: Array = []
	wire.failed.connect(func(code: String): failed.append(code))
	wire._on_lobby_joined(42,0,false,1)
	if failed!=["MOD_MISMATCH"] or wire.lobby_id!=0 or steam.left!=[42] or wire.version_mismatch_details().get("required")!="0.1.1":
		errors.append("Steam must leave an incompatible lobby before creating a peer and retain its required version.")
	wire.free()
	var ui: Node = load("res://mods/ftn_coop/coop_ui.gd").new()
	tree.root.add_child(ui)
	ui.configure_diagnostics("25963876","0.1.4")
	ui.set_language("en")
	ui.show_error("MOD_MISMATCH",{"required":"0.1.1"})
	if not ui.error_text().contains("0.1.4") or not ui.error_text().contains("0.1.1") or not ui._update.visible:
		errors.append("The English rejection must show installed/required versions and the download button.")
	ui.set_language("de")
	if not ui.error_text().contains("Installiert:") or not ui.error_text().contains("0.1.1"):
		errors.append("Switching language must retain and translate the version mismatch.")
	ui.show_error("MOD_MISMATCH",{"required":"PRIVATE_NAME\nC:/secret"})
	if ui.error_text().contains("PRIVATE_") or ui.diagnostic_report().contains("C:/secret"):
		errors.append("Update messages must sanitize remote version strings.")
	ui.clear_error()
	if ui._update.visible: errors.append("Clearing the version error must hide its download button.")
	ui.queue_free()
	await tree.process_frame
	for remote in ["0.1.1","0.2.0",""]:
		errors.append_array(await _reject_over_wire(tree,remote))
	return errors

func _reject_over_wire(tree: SceneTree, guest_version: String) -> Array[String]:
	var errors: Array[String] = []
	var controllers: Array = []
	var wires: Array = []
	var games: Array = []
	for index in [0,1]:
		var wire: Node = load("res://tests/fixtures/pipe_transport.gd").new()
		wire.peer_id = index+1
		var game: RefCounted = load("res://tests/fixtures/network_game_boundary.gd").new()
		game.tree = tree
		var controller: Node = load("res://mods/ftn_coop/network_controller.gd").new()
		tree.root.add_child(wire)
		tree.root.add_child(controller)
		controller.configure(wire,game,"25963876","0.1.4" if index==0 else guest_version)
		controllers.append(controller)
		wires.append(wire)
		games.append(game)
	wires[0].other = wires[1]
	wires[1].other = wires[0]
	var problems: Array = []
	var details: Array = []
	controllers[1].problem.connect(func(code: String):
		problems.append(code)
		details.append(controllers[1].version_mismatch.duplicate())
	)
	controllers[0].host()
	await tree.process_frame
	controllers[1].join(42)
	for frame in range(12): await tree.process_frame
	if not problems.has("MOD_MISMATCH") or details.is_empty() or details[0].get("required")!="0.1.4":
		errors.append("The real HELLO/REJECT route lost the required host version for "+guest_version)
	if controllers[1].session.state!=controllers[1].session.State.OFFLINE or controllers[1].save_session.guest_open:
		errors.append("Different versions must never open a guest world.")
	if controllers[0].session.state!=controllers[0].session.State.PLAYING or controllers[0].session.roster.size()!=1:
		errors.append("Rejecting an incompatible guest must preserve the host and free the guest slot.")
	for controller in controllers: controller.leave()
	for node in controllers+wires: node.queue_free()
	await tree.process_frame
	return errors
