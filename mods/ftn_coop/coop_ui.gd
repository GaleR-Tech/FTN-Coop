extends CanvasLayer

signal host_requested
signal invite_requested
signal leave_requested
signal save_requested
signal panel_toggled(open: bool)
signal action_requested(kind: String, payload: Dictionary)
signal tool_selected(index: int)
signal copy_report_requested
signal language_changed
signal shared_setting_requested(key: String, value: Variant)

const ERRORS := {
	"SETTINGS_INVALID":"Die gemeinsamen Spieleinstellungen sind ungültig. Tritt der Sitzung erneut bei.",
	"SETTINGS_HOST_ONLY":"Nur der Host kann die gemeinsamen Spieleinstellungen ändern.",
	"SESSION_FULL":"Die Sitzung ist voll. Maximal vier Spieler können gemeinsam spielen.",
	"BUILD_MISMATCH":"Die Spiel-Version stimmt nicht überein. Alle benötigen dieselbe Demo-Version.",
	"MOD_MISMATCH":"Die Koop-Version stimmt nicht überein. Installiert dasselbe Mod-Paket.",
	"LOBBY_VERSION_MISMATCH":"Die Spiel- oder Koop-Version stimmt nicht überein.",
	"PROTOCOL_MISMATCH":"Die Koop-Version stimmt nicht überein.",
	"HOST_DISCONNECTED":"Die Verbindung zum Host wurde beendet. Du kannst erneut beitreten.",
	"HOST_LEFT":"Die Verbindung zum Host wurde beendet. Du kannst erneut beitreten.",
	"GUEST_SESSION_BUSY":"Die vorherige Gastwelt wird noch geschlossen. Warte einen Moment.",
	"GUEST_CLOSE_FAILED":"Die Gastwelt konnte nicht geschlossen werden. Starte die Demo neu.",
	"GUEST_CLEANUP_FAILED":"Temporäre Gastdateien konnten nicht entfernt werden. Beim nächsten Beitritt wird es erneut versucht.",
	"SAVE_BACKUP_FAILED":"Die Sicherung des letzten Spielstands konnte nicht erstellt werden. Es wurde nicht gespeichert.",
	"SAVE_RECOVERY_FAILED":"Der Spielstand konnte nicht wiederhergestellt werden. Seine Sicherung liegt im Speicherordner.",
	"NOT_CONNECTED":"Es besteht keine Verbindung zur Sitzung.",
	"CONNECT_TIMEOUT":"Die Verbindung hat zu lange gedauert. Versuche es erneut.",
	"CONNECTION_TIMEOUT":"Die Verbindung hat zu lange gedauert. Versuche es erneut.",
	"TRANSFER_TIMEOUT":"Die Welt konnte nicht rechtzeitig übertragen werden. Versuche es erneut.",
	"STEAM_TIMEOUT":"Steam hat nicht rechtzeitig geantwortet. Prüfe deine Verbindung und versuche es erneut. Bleibt das Problem bestehen, starte die Demo neu.",
	"STEAM_BUSY":"Steam bearbeitet noch eine vorherige Anfrage. Warte kurz und versuche es erneut. Bleibt das Problem bestehen, starte die Demo neu.",
	"LOBBY_CREATE_FAILED":"Die Steam-Sitzung konnte nicht erstellt werden. Prüfe deine Verbindung zu Steam und versuche es erneut.",
	"LOBBY_JOIN_FAILED":"Der Steam-Sitzung konnte nicht beigetreten werden. Bitte den Host um eine neue Einladung und versuche es erneut.",
	"LOBBY_NOT_FOUND":"Diese Sitzung existiert nicht mehr. Bitte den Host, eine neue Sitzung zu erstellen und dich erneut einzuladen.",
	"LOBBY_NOT_ALLOWED":"Steam erlaubt den Beitritt zu dieser Sitzung nicht. Bitte den Host um eine neue Einladung und prüfe deine Steam-Kontoeinstellungen.",
	"LOBBY_ACCOUNT_LIMITED":"Steam hat den Beitritt wegen einer Kontoeinschränkung abgelehnt. Prüfe die Hinweise zu deinem Steam-Konto.",
	"LOBBY_BLOCKED":"Steam hat den Beitritt wegen einer Blockierung zwischen Teilnehmern abgelehnt. Prüft eure Blockierlisten in Steam.",
	"LOBBY_RATE_LIMITED":"Es gab zu viele Beitrittsversuche in kurzer Zeit. Warte etwas und nimm dann eine neue Einladung an.",
	"HOST_CREATE_FAILED":"Die Verbindung für deine Sitzung konnte nicht gestartet werden. Starte die Demo über Steam neu und versuche es erneut.",
	"CLIENT_CREATE_FAILED":"Die Verbindung zum Host konnte nicht gestartet werden. Starte die Demo über Steam neu und nimm eine neue Einladung an.",
	"SEND_FAILED":"Daten konnten nicht an die Sitzung gesendet werden. Prüfe deine Verbindung und tritt erneut bei.",
	"RESYNC_FAILED":"Der gemeinsame Fortschritt konnte auch nach mehreren Versuchen nicht abgeglichen werden. Tritt der Sitzung erneut bei.",
	"STEAM_NOT_READY":"Steam ist noch nicht bereit. Starte die Demo über Steam.",
	"STEAM_UNSUPPORTED":"Die benötigte Steam-Anbindung ist in dieser Version nicht verfügbar.",
	"RELAY_UNSUPPORTED":"Die Steam-Verbindung konnte nicht vorbereitet werden.",
	"BUILD_UNVERIFIED":"Diese Spiel-Version wurde noch nicht geprüft.",
	"WORLD_NOT_READY":"Lade zuerst einen Spielstand und warte, bis die Welt bereit ist.",
	"INSUFFICIENT_FUNDS":"Das gemeinsame Geld reicht dafür nicht aus.",
	"PURCHASE_REFUSED":"Der Kauf ist gerade nicht möglich.",
	"OUT_OF_REACH":"Gehe näher an das Ziel heran und schaue es an.",
	"BUILD_LOCKED":"Dieses Gebäude ist noch nicht freigeschaltet.",
	"TOOL_LOCKED":"Dieses Werkzeug ist noch nicht freigeschaltet.",
	"PLACEMENT_REFUSED":"An dieser Stelle kann das Gebäude nicht platziert werden.",
	"HOST_ONLY":"Nur der Host kann den gemeinsamen Spielstand speichern.",
	"SAVE_FAILED":"Der Spielstand konnte nicht gespeichert werden.",
	"PEER_NOT_READY":"Warte, bis die Welt vollständig abgeglichen ist.",
	"ACTION_REFUSED":"Diese Aktion ist gerade nicht möglich.",
}

var _session: Node
var _panel: PanelContainer
var _status: Label
var _error: Label
var _hint: Label
var _roster: Label
var _host: Button
var _invite: Button
var _leave: Button
var _save: Button
var _actions: VBoxContainer
var _badge: Button
var _host_available := false
var _capability_text := "Lade einen Spielstand, um eine Sitzung zu erstellen."
var _shared: Label
var _closing := false
var _progress: Label
var _notice: Label
var _load_stage := "idle"
var _load_received := 0
var _load_total := 0
var _report_build := "unbekannt"
var _report_version := "unbekannt"
var _last_problem: Dictionary = {}
var _locale: RefCounted
var _language_selector: OptionButton
var _error_code := ""
var _notice_kind := ""
var _saved_time := ""
var _summary: Dictionary = {}
var _update: Button
var _version_label: Label
var _required_version := ""
var _settings_toggle: Button
var _settings_box: VBoxContainer
var _settings_hint: Label
var _settings_controls: Dictionary = {}
var _session_settings: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_locale = load(get_script().resource_path.get_base_dir()+"/locale.gd").new()
	_locale.load_preferences()
	layer = 100
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_badge = Button.new()
	_badge.text = "Koop · F2"
	root.add_child(_badge)
	_badge.pressed.connect(func(): set_panel_open(not _panel.visible))
	_panel = PanelContainer.new()
	root.add_child(_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152a30f5")
	style.border_color = Color("d6b667")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel",style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",10)
	scroll.add_child(box)
	var title := Label.new()
	title.text = tr_text("Find The Needle · Koop")
	title.set_meta("ftn_text","Find The Needle · Koop")
	title.add_theme_font_size_override("font_size",23)
	box.add_child(title)
	_version_label = _label(box,"")
	_label(box,"Sprache / Language")
	_language_selector = OptionButton.new()
	_language_selector.add_item("Deutsch")
	_language_selector.add_item("English")
	_language_selector.select(0 if _locale.language=="de" else 1)
	box.add_child(_language_selector)
	_language_selector.item_selected.connect(func(index: int): set_language("de" if index==0 else "en",true))
	_status = _label(box,"Nicht verbunden · 0 / 4")
	_progress = _label(box,"")
	_hint = _label(box,_capability_text)
	_roster = _label(box,"")
	_shared = _label(box,"")
	_host = _button(box,"Sitzung erstellen",func(): host_requested.emit())
	_invite = _button(box,"Freunde einladen",func(): invite_requested.emit())
	_save = _button(box,"Gemeinsamen Fortschritt speichern",func(): save_requested.emit())
	_leave = _button(box,"Sitzung verlassen",func(): leave_requested.emit())
	_settings_toggle = _button(box,"Gemeinsame Spieleinstellungen",func(): _refresh_settings())
	_settings_toggle.toggle_mode = true
	_settings_box = VBoxContainer.new()
	box.add_child(_settings_box)
	_settings_hint = _label(_settings_box,"")
	var labels := {"prop_cap":"Lose Objekte: Maximum","prop_decay":"Lose Objekte automatisch entfernen","belt_cap":"Förderband-Objekte: Maximum","belt_decay":"Förderband-Objekte automatisch entfernen","auto_clean":"Automatisch aufräumen","auto_clean_seconds":"Aufräumintervall (Sekunden)","grid_lock":"Am Bauraster ausrichten","autosave":"Automatisch speichern (Host)","autosave_seconds":"Speicherintervall (Sekunden)"}
	var schema: Dictionary = load(get_script().resource_path.get_base_dir()+"/shared_settings.gd").SCHEMA
	for key in schema: _setting_row(key,labels[key],schema[key])
	_actions = VBoxContainer.new()
	box.add_child(_actions)
	_error = _label(box,"")
	_error.add_theme_color_override("font_color",Color("ffcc99"))
	_notice = _label(box,"")
	_notice.add_theme_color_override("font_color",Color("a9e6b0"))
	_update = _button(box,"Mod-Downloads öffnen",func():
		var version: Script = load(get_script().resource_path.get_base_dir()+"/mod_version.gd")
		OS.shell_open(version.DOWNLOAD_URL)
	)
	_update.visible = false
	_button(box,"Fehlerbericht kopieren",func(): copy_report_requested.emit())
	_label(box,"F2 öffnet und schließt dieses Menü.\nEntwicklungsstand · Internettest ausstehend.").add_theme_font_size_override("font_size",13)
	set_panel_open(false)
	_refresh()

func bind_session(session: Node) -> void:
	if _session!=null:
		if _session.state_changed.is_connected(_refresh): _session.state_changed.disconnect(_refresh)
		if _session.roster_changed.is_connected(_refresh): _session.roster_changed.disconnect(_refresh)
	_session = session
	_session.state_changed.connect(_refresh)
	_session.roster_changed.connect(_refresh)
	_refresh()

func set_host_available(available: bool, explanation: String="") -> void:
	_host_available = available
	_capability_text = explanation if not explanation.is_empty() else "Lade einen Spielstand, um eine Sitzung zu erstellen."
	_refresh()

func set_session_closing(value: bool) -> void:
	_closing = value
	_refresh()

func actions_allowed() -> bool:
	return _session!=null and _session.state==_session.State.PLAYING and _panel!=null and not _panel.visible

func set_panel_open(open: bool) -> void:
	if _panel==null or _panel.visible==open: return
	_panel.visible = open
	panel_toggled.emit(open)

func is_panel_open() -> bool:
	return _panel!=null and _panel.visible

func show_error(code: String, details: Dictionary={}) -> void:
	_error_code = code if ERRORS.has(code) else "UNBEKANNTER_FEHLER"
	var version: Script = load(get_script().resource_path.get_base_dir()+"/mod_version.gd")
	_required_version = version.safe_version(details.get("required")) if code=="MOD_MISMATCH" else ""
	_last_problem = _report_context()
	_last_problem.error = _error_code
	if not _required_version.is_empty(): _last_problem.required_mod_version = _required_version
	_notice_kind = ""
	if _notice!=null: _notice.text = ""
	_refresh_error()
	set_panel_open(true)

func _refresh_error() -> void:
	if _error==null: return
	_error.text = "" if _error_code.is_empty() else tr_text(ERRORS.get(_error_code,"Die Aktion konnte nicht abgeschlossen werden. Versuche es erneut."))
	_update.visible = _error_code=="MOD_MISMATCH"
	if _update.visible:
		_error.text += "\n"+tr_text("Installiert: %s · Lobby benötigt: %s") % [tr_text(_report_version),tr_text(_required_version if not _required_version.is_empty() else "unbekannt")]
		_error.text += "\n"+tr_text("Alle müssen dieselbe Mod-Version installieren und die Demo neu starten.")

func error_text() -> String:
	return _error.text if _error!=null else ""

func clear_error() -> void:
	_error_code = ""
	_required_version = ""
	if _update!=null: _update.visible = false
	if _error!=null: _error.text = ""
	_last_problem.clear()

func configure_diagnostics(build: String, version: String) -> void:
	_report_build = _report_value(build,"[0-9]{1,12}")
	_report_version = _report_value(version,"[0-9]{1,4}\\.[0-9]{1,4}\\.[0-9]{1,4}(-[a-z0-9.]{1,16})?")
	_refresh()

func _report_value(value: String, pattern: String) -> String:
	if value.length()>40: return "unbekannt"
	var found := RegEx.create_from_string("^"+pattern+"$").search(value)
	return value if found!=null and found.get_string()==value else "unbekannt"

func _report_context() -> Dictionary:
	var states := ["offline","hosting","joining","lobby","syncing","playing"]
	var state: int = clampi(int(_session.state),0,5) if _session!=null else 0
	return {"state":states[state],"role":"keine" if state==0 else ("Host" if _session.is_host else "Gast"),"players":clampi(_session.roster.size(),0,4) if _session!=null else 0,"stage":_load_stage,"received":_load_received,"total":_load_total,"error":"KEIN_FEHLER"}

func diagnostic_report() -> String:
	# Only fixed fields and allowlisted values; never dump session/adapter data.
	var context: Dictionary = _last_problem if not _last_problem.is_empty() else _report_context()
	var engine: Dictionary = Engine.get_version_info()
	var report: String = tr_text("FTN-Koop Fehlerbericht\nMod-Version: %s\nDemo-Build: %s\nGodot: %d.%d.%d\nSystem: %s\nSitzung: %s\nRolle: %s\nSpieler: %d / 4\nLadephase: %s\nEmpfangene Bytes: %d / %d\nFehler: %s\nInternettest: ausstehend\n") % [tr_text(_report_version),tr_text(_report_build),int(engine.major),int(engine.minor),int(engine.patch),"Windows" if OS.get_name()=="Windows" else tr_text("anderes"),context.state,tr_text(context.role),context.players,context.stage,context.received,context.total,context.error]
	if context.has("required_mod_version"): report += tr_text("Lobby-Mod-Version: %s\n") % context.required_mod_version
	return report

func set_load_progress(stage: String, received: int, total: int) -> void:
	if stage not in ["idle","waiting","receiving","loading","catching_up","ready"]: return
	_load_stage = stage
	_load_total = clampi(total,0,64*1024*1024)
	_load_received = clampi(received,0,_load_total)
	_refresh()

func _refresh_progress() -> void:
	if _progress==null: return
	var texts := {"idle":"","waiting":"Warte auf Weltdaten …","receiving":"Weltdaten werden empfangen …","loading":"Welt wird aufgebaut …","catching_up":"Gemeinsamer Fortschritt wird abgeglichen …","ready":""}
	_progress.text = tr_text(texts[_load_stage])
	if _load_stage=="receiving" and _load_total>0:
		_progress.text = tr_text("Weltdaten empfangen: %d %%") % int(100.0*_load_received/_load_total)

func progress_text() -> String:
	return _progress.text if _progress!=null else ""

func show_saved(clear_problem: bool=true) -> void:
	if clear_problem: clear_error()
	_notice_kind = "saved"
	_saved_time = Time.get_time_string_from_system()
	_refresh_notice()

func show_report_copied() -> void:
	_notice_kind = "copied"
	_refresh_notice()

func _refresh_notice() -> void:
	if _notice==null: return
	_notice.text = ""
	if _notice_kind=="saved": _notice.text = tr_text("Gemeinsamer Fortschritt gespeichert um %s.") % _saved_time
	elif _notice_kind=="copied": _notice.text = tr_text("Fehlerbericht kopiert. Du kannst ihn vor dem Teilen prüfen.")

func notice_text() -> String:
	return _notice.text if _notice!=null else ""

func set_shared_summary(summary: Dictionary) -> void:
	_summary = summary.duplicate()
	if _shared==null: return
	var playing: bool = _session!=null and _session.state==_session.State.PLAYING
	_shared.visible = playing
	if playing:
		var needles := int(summary.get("needles",0))
		_shared.text = tr_text("Gemeinsam: %.0f $ · %d %s") % [float(summary.get("money",0)),needles,tr_text("Nadel" if needles==1 else "Nadeln")]
		_badge.text = tr_text("Koop · %.0f $ · F2") % float(summary.get("money",0))
	else: _badge.text = tr_text("Koop · F2")

func action_container() -> VBoxContainer:
	return _actions

func _setting_row(key: String, title: String, rule: Array) -> void:
	var row := HBoxContainer.new()
	_settings_box.add_child(row)
	var label := _label(row,title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if rule[0]==TYPE_BOOL:
		var control := CheckBox.new()
		control.toggled.connect(func(value: bool): shared_setting_requested.emit(key,value))
		row.add_child(control)
		_settings_controls[key] = control
	else:
		var control := SpinBox.new()
		control.min_value = rule[1]
		control.max_value = rule[2]
		control.step = 1
		control.custom_minimum_size.x = 108
		control.value_changed.connect(func(value: float):
			shared_setting_requested.emit(key,int(value) if rule[0]==TYPE_INT else value)
		)
		row.add_child(control)
		_settings_controls[key] = control

func set_shared_settings(values: Dictionary) -> void:
	_session_settings = values.duplicate(true)
	_refresh_settings()

func _refresh_settings() -> void:
	if _settings_toggle==null: return
	var active: bool = _session!=null and _session.state!=_session.State.OFFLINE and not _session_settings.is_empty()
	_settings_toggle.visible = active
	_settings_box.visible = active and _settings_toggle.button_pressed
	var editable: bool = active and _session.is_host and _session.state==_session.State.PLAYING and not _closing
	_settings_hint.text = tr_text("Änderungen gelten für die gesamte Sitzung." if editable else "Vom Host vorgegeben. Deine eigenen Werte werden beim Verlassen wiederhergestellt.")
	for key in _settings_controls:
		var control: Control = _settings_controls[key]
		if control is CheckBox:
			control.disabled = not editable
			control.set_pressed_no_signal(_session_settings.get(key,false)==true)
		else:
			control.editable = editable
			if _session_settings.has(key): control.set_value_no_signal(_session_settings[key])
		control.tooltip_text = "" if editable else tr_text("Vom Host vorgegeben")

func _refresh() -> void:
	if _status==null: return
	_version_label.text = tr_text("Installierte Mod-Version: %s") % tr_text(_report_version)
	_refresh_settings()
	_refresh_progress()
	var offline: bool = _session==null or _session.state==_session.State.OFFLINE
	var hosting: bool = not offline and _session.is_host
	var playing: bool = not offline and _session.state==_session.State.PLAYING
	_progress.visible = not offline and not hosting and not _closing and _load_stage not in ["idle","ready"]
	var names := ["Nicht verbunden","Sitzung wird erstellt …","Verbindung wird hergestellt …","Welt wird vorbereitet …","Welt wird geladen …","Gemeinsam spielbereit"]
	_status.text = tr_text(names[_session.state if _session!=null else 0])+" · "+str(_session.roster.size() if _session!=null else 0)+" / 4"
	_host.visible = offline
	_host.disabled = not _host_available or _closing
	_invite.visible = hosting
	_save.visible = hosting and playing
	_leave.visible = not offline
	_actions.visible = playing and not hosting
	_hint.text = tr_text(_capability_text if offline else ("Du bist Host. Der gemeinsame Fortschritt gehört zu deinem Spielstand." if hosting else "Du spielst in der Welt des Hosts. Dein Einzelspielerstand bleibt getrennt."))
	var lines := PackedStringArray()
	if _session!=null:
		for peer in _session.roster:
			var member: Dictionary = _session.roster[peer]
			var display_name: String = tr_text("Verbinden …") if member.get("state")=="connecting" and not member.get("accepted",false) else str(member.get("name",tr_text("Mitspieler")))
			lines.append("• "+display_name)
	_roster.text = "\n".join(lines)
	if _closing:
		_status.text = tr_text("Gastwelt wird geschlossen …")
		_hint.text = tr_text("Warte, bis das Hauptmenü wieder bereit ist.")
	set_shared_summary(_summary)

func tr_text(key: String) -> String:
	return _locale.text(key) if _locale!=null else key

func set_language(value: String, persist: bool=false) -> void:
	if _locale==null or not _locale.set_language(value): return
	if persist: _locale.save_preferences()
	_language_selector.select(0 if value=="de" else 1)
	_translate_controls(self)
	_refresh_error()
	_refresh_notice()
	_refresh()
	language_changed.emit()

func _translate_controls(node: Node) -> void:
	if node.has_meta("ftn_text"): node.set("text",tr_text(str(node.get_meta("ftn_text"))))
	for child in node.get_children(): _translate_controls(child)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F2:
		set_panel_open(not _panel.visible)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var viewport := get_viewport().get_visible_rect().size
	var width := minf(390,viewport.x-24)
	_panel.position = Vector2(viewport.x-width-12,52)
	_panel.size = Vector2(width,maxf(120,minf(640,viewport.y-112)))
	_badge.position = Vector2(maxf(12,viewport.x-222),maxf(12,viewport.y-44))
	_badge.size = Vector2(210,32)

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = tr_text(text)
	label.set_meta("ftn_text",text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = tr_text(text)
	button.set_meta("ftn_text",text)
	button.custom_minimum_size.y = 38
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
