extends CanvasLayer

signal host_requested
signal invite_requested
signal leave_requested
signal save_requested
signal panel_toggled(open: bool)
signal action_requested(kind: String, payload: Dictionary)
signal tool_selected(index: int)
signal copy_report_requested

const ERRORS := {
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
	"TRANSFER_TIMEOUT":"Die Welt konnte nicht rechtzeitig übertragen werden. Versuche es erneut.",
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	title.text = "Find The Needle · Koop"
	title.add_theme_font_size_override("font_size",23)
	box.add_child(title)
	_status = _label(box,"Nicht verbunden · 0 / 4")
	_progress = _label(box,"")
	_hint = _label(box,_capability_text)
	_roster = _label(box,"")
	_shared = _label(box,"")
	_host = _button(box,"Sitzung erstellen",func(): host_requested.emit())
	_invite = _button(box,"Freunde einladen",func(): invite_requested.emit())
	_save = _button(box,"Gemeinsamen Fortschritt speichern",func(): save_requested.emit())
	_leave = _button(box,"Sitzung verlassen",func(): leave_requested.emit())
	_actions = VBoxContainer.new()
	box.add_child(_actions)
	_error = _label(box,"")
	_error.add_theme_color_override("font_color",Color("ffcc99"))
	_notice = _label(box,"")
	_notice.add_theme_color_override("font_color",Color("a9e6b0"))
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

func show_error(code: String) -> void:
	_last_problem = _report_context()
	_last_problem.error = code if ERRORS.has(code) else "UNBEKANNTER_FEHLER"
	if _notice!=null: _notice.text = ""
	if _error!=null: _error.text = ERRORS.get(code,"Die Aktion konnte nicht abgeschlossen werden. Versuche es erneut.")
	set_panel_open(true)

func error_text() -> String:
	return _error.text if _error!=null else ""

func clear_error() -> void:
	if _error!=null: _error.text = ""
	_last_problem.clear()

func configure_diagnostics(build: String, version: String) -> void:
	_report_build = _report_value(build,"[0-9]{1,12}")
	_report_version = _report_value(version,"[0-9]{1,4}\\.[0-9]{1,4}\\.[0-9]{1,4}(-[a-z0-9.]{1,16})?")

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
	return "FTN-Koop Fehlerbericht\nMod-Version: %s\nDemo-Build: %s\nGodot: %d.%d.%d\nSystem: %s\nSitzung: %s\nRolle: %s\nSpieler: %d / 4\nLadephase: %s\nEmpfangene Bytes: %d / %d\nFehler: %s\nInternettest: ausstehend\n" % [_report_version,_report_build,int(engine.major),int(engine.minor),int(engine.patch),"Windows" if OS.get_name()=="Windows" else "anderes",context.state,context.role,context.players,context.stage,context.received,context.total,context.error]

func set_load_progress(stage: String, received: int, total: int) -> void:
	if stage not in ["idle","waiting","receiving","loading","catching_up","ready"]: return
	_load_stage = stage
	_load_total = clampi(total,0,64*1024*1024)
	_load_received = clampi(received,0,_load_total)
	if _progress==null: return
	var texts := {"idle":"","waiting":"Warte auf Weltdaten …","receiving":"Weltdaten werden empfangen …","loading":"Welt wird aufgebaut …","catching_up":"Gemeinsamer Fortschritt wird abgeglichen …","ready":""}
	_progress.text = texts[stage]
	if stage=="receiving" and _load_total>0:
		_progress.text = "Weltdaten empfangen: %d %%" % int(100.0*_load_received/_load_total)
	_refresh()

func progress_text() -> String:
	return _progress.text if _progress!=null else ""

func show_saved(clear_problem: bool=true) -> void:
	if clear_problem: clear_error()
	if _notice!=null: _notice.text = "Gemeinsamer Fortschritt gespeichert um "+Time.get_time_string_from_system()+"."

func show_report_copied() -> void:
	if _notice!=null: _notice.text = "Fehlerbericht kopiert. Du kannst ihn vor dem Teilen prüfen."

func notice_text() -> String:
	return _notice.text if _notice!=null else ""

func set_shared_summary(summary: Dictionary) -> void:
	if _shared==null: return
	var playing: bool = _session!=null and _session.state==_session.State.PLAYING
	_shared.visible = playing
	if playing:
		var needles := int(summary.get("needles",0))
		_shared.text = "Gemeinsam: %.0f $ · %d %s" % [float(summary.get("money",0)),needles,"Nadel" if needles==1 else "Nadeln"]
		_badge.text = "Koop · %.0f $ · F2" % float(summary.get("money",0))
	else: _badge.text = "Koop · F2"

func action_container() -> VBoxContainer:
	return _actions

func _refresh() -> void:
	if _status==null: return
	var offline: bool = _session==null or _session.state==_session.State.OFFLINE
	var hosting: bool = not offline and _session.is_host
	var playing: bool = not offline and _session.state==_session.State.PLAYING
	_progress.visible = not offline and not hosting and not _closing and _load_stage not in ["idle","ready"]
	var names := ["Nicht verbunden","Sitzung wird erstellt …","Verbindung wird hergestellt …","Welt wird vorbereitet …","Welt wird geladen …","Gemeinsam spielbereit"]
	_status.text = names[_session.state if _session!=null else 0]+" · "+str(_session.roster.size() if _session!=null else 0)+" / 4"
	_host.visible = offline
	_host.disabled = not _host_available or _closing
	_invite.visible = hosting
	_save.visible = hosting and playing
	_leave.visible = not offline
	_actions.visible = playing and not hosting
	_hint.text = _capability_text if offline else ("Du bist Host. Der gemeinsame Fortschritt gehört zu deinem Spielstand." if hosting else "Du spielst in der Welt des Hosts. Dein Einzelspielerstand bleibt getrennt.")
	var lines := PackedStringArray()
	if _session!=null:
		for peer in _session.roster: lines.append("• "+str(_session.roster[peer].get("name","Mitspieler")))
	_roster.text = "\n".join(lines)
	if _closing:
		_status.text = "Gastwelt wird geschlossen …"
		_hint.text = "Warte, bis das Hauptmenü wieder bereit ist."

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F2:
		set_panel_open(not _panel.visible)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var viewport := get_viewport().get_visible_rect().size
	var width := minf(390,viewport.x-24)
	_panel.position = Vector2(viewport.x-width-12,52)
	_panel.size = Vector2(width,maxf(120,minf(640,viewport.y-64)))
	_badge.position = Vector2(viewport.x-222,10)
	_badge.size = Vector2(210,32)

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
