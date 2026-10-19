extends Node

var network: Node
var ui: CanvasLayer
var presence: Node3D
var movement: Node
var input_bridge: Node
var _adapter: RefCounted
var _transport: Node
var _build := ""
var _version := ""
var _guest_player_id := 0
var _mouse_before_panel := Input.MOUSE_MODE_VISIBLE
var _selected_build := ""
var _hud_due := 0.0
var _pending_invitation := 0
var _was_host := false
var _transport_ready := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(adapter: RefCounted, transport: Node, build: String, version: String) -> void:
	_adapter = adapter
	_transport = transport
	_build = build
	_version = version
	var base: String = get_script().resource_path.get_base_dir()
	if not transport.is_inside_tree(): add_child(transport)
	network = load(base+"/network_controller.gd").new()
	add_child(network)
	network.configure(transport,adapter,build,version)
	ui = load(base+"/coop_ui.gd").new()
	add_child(ui)
	ui.bind_session(network.session)
	ui.configure_diagnostics(build,version)
	network.load_progress.connect(ui.set_load_progress)
	presence = load(base+"/presence.gd").new()
	add_child(presence)
	movement = load(base+"/guest_movement.gd").new()
	add_child(movement)
	input_bridge = load(base+"/input_bridge.gd").new()
	input_bridge.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(input_bridge)
	ui.host_requested.connect(start_host)
	ui.invite_requested.connect(_invite)
	ui.leave_requested.connect(_leave)
	ui.save_requested.connect(_save)
	ui.copy_report_requested.connect(_copy_report)
	ui.shared_setting_requested.connect(_change_shared_setting)
	ui.language_changed.connect(func():
		if _is_guest(): _populate_actions()
	)
	ui.panel_toggled.connect(_on_panel_toggled)
	ui.action_requested.connect(_request)
	input_bridge.action_requested.connect(_on_primary)
	network.problem.connect(func(code: String): ui.show_error(code,network.version_mismatch))
	network.pose_received.connect(presence.apply_pose)
	network.session.roster_changed.connect(_roster_changed)
	network.session.state_changed.connect(_state_changed)
	network.stopped.connect(_stopped)
	network.save_session.closed.connect(_guest_closed)
	if transport.has_signal("invite_received"): transport.invite_received.connect(join_invitation)
	_prepare_transport()
	refresh_world()

func _prepare_transport() -> void:
	if _transport_ready: return
	if not _transport.has_method("prepare"):
		_transport_ready = true
		return
	var prepared: Dictionary = _transport.prepare()
	if prepared.ok:
		_transport_ready = true
		if _transport.has_method("local_name"): network.session.player_name = _transport.local_name()
	elif prepared.code!="STEAM_NOT_READY": _transport_ready = true

func refresh_world() -> void:
	if _adapter==null or ui==null: return
	if network.save_session.closing:
		ui.set_session_closing(true)
		return
	var checked: Dictionary = _adapter.probe(get_tree().root)
	ui.set_host_available(checked.ok,"Erstelle eine private Sitzung und lade bis zu drei Freunde ein." if checked.ok else (ui.ERRORS.BUILD_UNVERIFIED if _build!="25963876" else "Lade einen Spielstand, um eine Sitzung zu erstellen."))

func start_host() -> void:
	var checked: Dictionary = _adapter.probe(get_tree().root)
	if not checked.ok:
		ui.show_error(checked.code)
		return
	var result: Dictionary = network.host()
	if not result.ok: ui.show_error(result.code)
	else:
		ui.clear_error()
		ui.set_panel_open(true)

func join_invitation(lobby: int) -> void:
	if _build!="25963876":
		ui.show_error("BUILD_UNVERIFIED")
		return
	var result: Dictionary = network.join(lobby)
	if not result.ok:
		if result.code=="GUEST_SESSION_BUSY" and network.save_session.closing: _pending_invitation = lobby
		else: ui.show_error(result.code)
	else:
		ui.clear_error()
		ui.set_panel_open(true)

func _invite() -> void:
	var result: Dictionary = _transport.invite() if _transport.has_method("invite") else {"ok":false,"code":"STEAM_UNSUPPORTED"}
	if not result.ok: ui.show_error(result.code)

func _save() -> void:
	if not network.session.is_host or network.session.state!=network.session.State.PLAYING:
		ui.show_error("HOST_ONLY")
		return
	var result: Dictionary = network.save_session.save_host()
	if not result.ok: ui.show_error(result.code)
	else: ui.show_saved()

func _copy_report() -> void:
	DisplayServer.clipboard_set(ui.diagnostic_report())
	ui.show_report_copied()

func _change_shared_setting(key: String, value: Variant) -> void:
	if not network.session.is_host or network.session.state!=network.session.State.PLAYING:
		ui.show_error("SETTINGS_HOST_ONLY")
		return
	if not _adapter.has_method("update_shared_setting"): return
	var changed: Dictionary = _adapter.update_shared_setting(key,value)
	if not changed.ok: ui.show_error(changed.code)
	else:
		ui.set_shared_settings(changed.value)
		network.world_sync.poll()

func _leave() -> void:
	_pending_invitation = 0
	network.leave()

func _guest_closed(result: Dictionary) -> void:
	ui.set_session_closing(false)
	if not result.ok:
		_pending_invitation = 0
		ui.show_error(result.code)
		return
	refresh_world()
	if _pending_invitation>0:
		var lobby := _pending_invitation
		_pending_invitation = 0
		join_invitation(lobby)

func _roster_changed() -> void:
	var session: Node = network.session
	if session.state==session.State.OFFLINE: presence.clear()
	else: presence.sync_roster(_transport.local_peer_id(),session.roster)

func _state_changed() -> void:
	if network.session.state==network.session.State.PLAYING and network.session.is_host: _was_host = true
	if network.session.state==network.session.State.PLAYING and not network.session.is_host:
		_populate_actions()
		ui.set_panel_open(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _stopped() -> void:
	input_bridge.enabled = false
	movement.enabled = false
	_guest_player_id = 0
	presence.clear()
	ui.set_panel_open(true)
	ui.set_session_closing(network.save_session.closing)
	if _was_host:
		_was_host = false
		await get_tree().process_frame
		var saved: Dictionary = network.save_session.save_host()
		if not saved.ok: ui.show_error(saved.code)
		else: ui.show_saved(false)

func _on_panel_toggled(open: bool) -> void:
	if open:
		_mouse_before_panel = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		input_bridge.enabled = false
		movement.enabled = false
		if network.session.state==network.session.State.PLAYING and not network.session.is_host: _populate_actions()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _is_guest() else _mouse_before_panel

func _is_guest() -> bool:
	return network!=null and network.session.state==network.session.State.PLAYING and not network.session.is_host and _adapter.guest_mode

func _process(delta: float) -> void:
	if network==null: return
	var guest := _is_guest()
	input_bridge.enabled = guest and ui.actions_allowed()
	movement.enabled = input_bridge.enabled
	if guest:
		var body: CharacterBody3D = _adapter.local_player_body()
		if body!=null and body.get_instance_id()!=_guest_player_id:
			var bound: Dictionary = movement.configure(_adapter)
			if not bound.ok: ui.show_error(bound.code)
			else: _guest_player_id = body.get_instance_id()
		if input_bridge.enabled: _adapter.pump_local_preview(delta)
	_hud_due += delta
	if _hud_due>=0.2:
		_hud_due = 0.0
		_prepare_transport()
		if _adapter.has_method("shared_summary"): ui.set_shared_summary(_adapter.shared_summary())
		if _adapter.has_method("read_shared_settings"):
			var settings: Dictionary = _adapter.read_shared_settings()
			ui.set_shared_settings(settings.value if settings.ok else {})

func _on_primary(kind: String, payload: Dictionary) -> void:
	if not _is_guest(): return
	if kind=="dig" and payload.get("pressed")==false:
		_request(kind,payload)
		return
	if not ui.actions_allowed(): return
	if kind=="dig" and not _selected_build.is_empty():
		var pose: Dictionary = _adapter.read_local_pose()
		if pose.ok and pose.value.get("tool")==8:
			if payload.get("pressed")==true: _request("place",{"id":_selected_build})
			return
	_request(kind,payload)

func _request(kind: String, payload: Dictionary) -> void:
	if not _is_guest():
		ui.show_error("PEER_NOT_READY")
		return
	var result: Dictionary = network.request_action(kind,payload)
	if not result.ok: ui.show_error(result.code)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_guest() or not ui.actions_allowed(): return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_8:
		_select_tool(event.physical_keycode-KEY_1)
		get_viewport().set_input_as_handled()

func _select_tool(index: int) -> void:
	var result: Dictionary = _adapter.select_local_tool(index)
	if not result.ok: ui.show_error(result.code)

func _populate_actions() -> void:
	if not _adapter.has_method("guest_options"): return
	var box: VBoxContainer = ui.action_container()
	var choices: Dictionary = {}
	for row in box.get_children():
		for control in row.get_children():
			if control is OptionButton and control.has_meta("ftn_choice") and control.selected>=0:
				choices[control.get_meta("ftn_choice")] = control.get_item_metadata(control.selected)
	box.set_meta("ftn_choices",choices)
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var options: Dictionary = _adapter.guest_options()
	ui._label(box,"Gaststeuerung: WASD · Maus · Leertaste\n1–8 Werkzeug · E aufnehmen · G ablegen\nR werfen · Entf abbauen · Linksklick benutzen").add_theme_font_size_override("font_size",13)
	_option_row(box,"Werkzeug",options.get("tools",[]),"Auswählen",func(id: Variant):
		_select_tool(int(id))
		ui.set_panel_open(false)
	)
	_option_row(box,"Am Laden kaufen",options.get("shop",[]),"Kaufen",func(id: Variant): _request("purchase",{"id":str(id)}))
	_option_row(box,"Gebäude",options.get("buildings",[]),"Bauen",func(id: Variant):
		var selected: Dictionary = _adapter.select_local_build(str(id))
		if not selected.ok: ui.show_error(selected.code)
		else:
			_selected_build = str(id)
			ui.set_panel_open(false)
	)
	_option_row(box,"Forschung",options.get("upgrades",[]),"Verbessern",func(id: Variant): _request("upgrade",{"id":str(id)}))
	ui._button(box,"Nadel im angeschauten Schrank ablegen",func(): _request("needle_collect",{"operation":"deposit"}))
	var row := HBoxContainer.new()
	box.add_child(row)
	ui._button(row,"Maschine an",func(): _request("machine_config",{"switched_off":false})).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui._button(row,"Maschine aus",func(): _request("machine_config",{"switched_off":true})).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _option_row(box: Node, label: String, options: Array, button_text: String, callback: Callable) -> void:
	if options.is_empty(): return
	ui._label(box,label)
	var row := HBoxContainer.new()
	box.add_child(row)
	var selector := OptionButton.new()
	selector.set_meta("ftn_choice",label)
	selector.fit_to_longest_item = false
	selector.custom_minimum_size.x = 120
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.clip_text = true
	for option in options:
		var title: String = ui.tr_text(option.label_key) if option.has("label_key") else str(option.label)
		if option.has("label_key") and option.has("price"): title += " · %.0f $" % float(option.price)
		selector.add_item(title)
		selector.set_item_metadata(selector.item_count-1,option.id)
		if box.get_meta("ftn_choices",{}).get(label)==option.id: selector.select(selector.item_count-1)
	row.add_child(selector)
	ui._button(row,button_text,func(): callback.call(selector.get_item_metadata(selector.selected)))
