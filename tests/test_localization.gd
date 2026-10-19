extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	if not FileAccess.file_exists("res://mods/ftn_coop/locale.gd"):
		return ["German and English mod localization is missing."]
	var errors: Array[String] = []
	var locale: RefCounted = load("res://mods/ftn_coop/locale.gd").new()
	for item in [["de_DE","de"],["en_US","en"],["fr_FR","en"]]:
		if locale.default_language(item[0])!=item[1]: errors.append("Unexpected language fallback for "+item[0])
	locale.set_language("en")
	if locale.text("Sitzung erstellen")!="Create session": errors.append("English session controls need actual translations.")
	if locale.text("Schaufel")!="Shovel": errors.append("Mod-owned tool names also need English translations.")
	if locale.set_language("../../secret") or locale.language!="en": errors.append("Unsupported language values must be rejected without changing language.")
	var ui: Node = load("res://mods/ftn_coop/coop_ui.gd").new()
	var session: Node = load("res://mods/ftn_coop/session.gd").new()
	tree.root.add_child(session)
	tree.root.add_child(ui)
	ui.bind_session(session)
	for message in ui.ERRORS.values():
		if locale.text(message)==message: errors.append("English error translation is missing: "+message)
	if not ui.has_method("set_language"):
		errors.append("The live co-op menu needs a language selector.")
	else:
		ui.set_language("de")
		session.state = session.State.SYNCING
		session.roster = {1:{"name":"Host"},2:{"name":"Guest"}}
		ui.set_load_progress("receiving",50,100)
		ui.show_error("TRANSFER_TIMEOUT")
		var original_problem: Dictionary = ui._last_problem.duplicate(true)
		ui.set_language("en")
		if ui._host.text!="Create session" or not ui.progress_text().contains("World data received: 50 %"):
			errors.append("Switching language must update controls and existing load progress.")
		if not ui.error_text().contains("transferred") or ui._last_problem!=original_problem:
			errors.append("Switching language must translate the existing error without losing diagnostic context.")
		if not ui.diagnostic_report().contains("Error:") or not ui.diagnostic_report().contains("TRANSFER_TIMEOUT"):
			errors.append("The copied diagnostic report needs English labels and stable error codes.")
		ui.show_saved()
		if not ui.notice_text().contains("saved at"): errors.append("English saves need translated confirmation.")
		ui.set_language("de")
		if not ui.notice_text().contains("gespeichert") or session.state!=session.State.SYNCING or session.roster.size()!=2:
			errors.append("Language switching must preserve session and saved-notice state.")
		for code in ["STEAM_BUSY","STEAM_TIMEOUT","CONNECTION_TIMEOUT","LOBBY_JOIN_FAILED","LOBBY_CREATE_FAILED","HOST_CREATE_FAILED","CLIENT_CREATE_FAILED","SEND_FAILED","RESYNC_FAILED","LOBBY_NOT_FOUND","LOBBY_NOT_ALLOWED","LOBBY_ACCOUNT_LIMITED","LOBBY_BLOCKED","LOBBY_RATE_LIMITED"]:
			ui.set_language("de")
			ui.show_error(code)
			var german: String = ui.error_text()
			ui.set_language("en")
			if ui._error_code!=code or not ui.diagnostic_report().contains(code) or german.is_empty() or ui.error_text()==german:
				errors.append("Network failure "+code+" must have a translated action and retain its real diagnostic code.")
	var settings := "user://ftn-locale-test-"+str(Time.get_ticks_usec())+".cfg"
	locale.set_language("de")
	if locale.save_preferences(settings)!=OK: errors.append("Language preference could not be saved.")
	var restored: RefCounted = load("res://mods/ftn_coop/locale.gd").new()
	restored.load_preferences(settings)
	if restored.language!="de": errors.append("Saved language preference was not restored.")
	DirAccess.remove_absolute(settings)
	ui.queue_free()
	session.queue_free()
	await tree.process_frame
	return errors
