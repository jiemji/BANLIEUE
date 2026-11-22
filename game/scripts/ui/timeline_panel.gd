## HUD Tactique Isométrique « Frise Haute + Fiche Actif / Minutes / Fiche Survolé + Alerte Charge 10 s » (1280×720).
extends Control

signal targeting_state_changed(target_kind: String, valid_ids: Array, action_id: String)
signal frise_actor_hovered(kind: String, entity_id: String)

var input_blocked: bool = false

var _timeline: Node = null
var _tex_cache: Dictionary = {}

# Zone 1 : Frise Chronologique en haut (cartes rectangulaires verticales)
var _top_panel: PanelContainer = null
var _lbl_header: Label = null
var _lbl_crs: Label = null
var _lbl_escape: Label = null
var _lbl_shield: Label = null
var _rail_hbox: HBoxContainer = null
var _frise_cards: Array[Control] = []

# Zone 2 : Fiche Personnage Actif bas-gauche (PJ ou PNJ)
var _active_sheet_panel: PanelContainer = null
var _active_sheet_style: StyleBoxFlat = null
var _active_sheet_vbox: VBoxContainer = null
var _actions_box: GridContainer = null

# Zone 3 : Minutes du Combat bas-centre
var _minutes_panel: PanelContainer = null
var _lbl_minutes_status: Label = null
var _bark_panel_style: StyleBoxFlat = null
var _lbl_bark: Label = null
var _minutes_scroll: ScrollContainer = null
var _lbl_log: Label = null
var _btn_step: Button = null
var _btn_cancel_target: Button = null

# Zone 4 : Fiche Personnage Survolé bas-droite (même format que la fiche active)
var _hover_panel: PanelContainer = null
var _hover_sheet_style: StyleBoxFlat = null
var _hover_sheet_vbox: VBoxContainer = null

# Zone 5 : Bandeau d'alerte Charge PNJ 10 s (centré haut du plateau, n'obstrue pas les pions)
var _charge_alert_panel: PanelContainer = null
var _lbl_charge_title: Label = null
var _lbl_charge_timer: Label = null
var _bar_charge_timer: ProgressBar = null
var _charge_btns_hbox: HBoxContainer = null

# État de ciblage sur pion & survol
var _pending_kind: String = "" # "" | "action" | "interrupt" | "restrain"
var _pending_id: String = ""
var _pending_target_kind: String = ""
var _pending_valid_targets: Array[String] = []
var _hovered_kind: String = ""
var _hovered_id: String = ""
var _current_action_ids: Array[String] = []
var _bark_override_text: String = ""
var _last_rendered_charge_key: String = ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	visible = false

## Lie ce panneau à l'instance TensionTimeline active.
func bind_timeline(tl: Node) -> void:
	_timeline = tl
	_timeline.timeline_updated.connect(refresh)
	_timeline.encounter_finished.connect(_on_encounter_finished)
	if _timeline.has_signal("combat_feedback_emitted"):
		_timeline.combat_feedback_emitted.connect(_on_combat_feedback)
	if _timeline.has_signal("charge_window_started"):
		_timeline.charge_window_started.connect(_on_charge_window_started)
	if _timeline.has_signal("charge_window_ticked"):
		_timeline.charge_window_ticked.connect(_on_charge_window_ticked)
	if _timeline.has_signal("charge_window_ended"):
		_timeline.charge_window_ended.connect(_on_charge_window_ended)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or input_blocked or _timeline == null or not bool(_timeline.get("active")):
		return
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			var is_waiting: bool = bool(_timeline.get("awaiting_step"))
			var is_charge_win: bool = bool(_timeline.call("is_charge_window_active"))
			if kev.keycode == KEY_SPACE or kev.keycode == KEY_ENTER or kev.keycode == KEY_KP_ENTER:
				if is_waiting and not is_charge_win and _pending_kind == "":
					_timeline.call("step_next_beat")
					get_viewport().set_input_as_handled()
			elif kev.keycode >= KEY_1 and kev.keycode <= KEY_9:
				if not is_waiting and not is_charge_win:
					var idx: int = int(kev.keycode - KEY_1)
					if idx >= 0 and idx < _current_action_ids.size():
						select_action(_current_action_ids[idx])
						get_viewport().set_input_as_handled()

func _build_ui() -> void:
	# 1. FRISE CHRONOLOGIQUE EN HAUT (x=10..1270, y=8..126)
	_top_panel = PanelContainer.new()
	_top_panel.position = Vector2(10, 8)
	_top_panel.size = Vector2(1260, 118)
	_top_panel.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.06, 0.08, 0.92), Color(0.95, 0.55, 0.16), 2, 6))
	add_child(_top_panel)

	var top_h: HBoxContainer = HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 10)
	_top_panel.add_child(top_h)

	var status_col: VBoxContainer = VBoxContainer.new()
	status_col.custom_minimum_size = Vector2(158, 0)
	status_col.add_theme_constant_override("separation", 3)
	top_h.add_child(status_col)

	_lbl_header = Label.new()
	_lbl_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_header.add_theme_font_size_override("font_size", 12)
	_lbl_header.add_theme_color_override("font_color", Color(0.96, 0.58, 0.18))
	status_col.add_child(_lbl_header)

	_lbl_crs = Label.new()
	_lbl_crs.add_theme_font_size_override("font_size", 12)
	_lbl_crs.add_theme_color_override("font_color", Color(0.38, 0.72, 0.98))
	status_col.add_child(_lbl_crs)

	_lbl_escape = Label.new()
	_lbl_escape.add_theme_font_size_override("font_size", 11)
	_lbl_escape.add_theme_color_override("font_color", Color(0.96, 0.84, 0.34))
	status_col.add_child(_lbl_escape)

	_lbl_shield = Label.new()
	_lbl_shield.add_theme_font_size_override("font_size", 11)
	_lbl_shield.add_theme_color_override("font_color", Color(0.55, 0.88, 0.62))
	status_col.add_child(_lbl_shield)

	var rail_scroll: ScrollContainer = ScrollContainer.new()
	rail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	top_h.add_child(rail_scroll)

	_rail_hbox = HBoxContainer.new()
	_rail_hbox.add_theme_constant_override("separation", 7)
	rail_scroll.add_child(_rail_hbox)

	# 2. FICHE PERSONNAGE ACTIF BAS-GAUCHE (x=10..404, y=478..712)
	_active_sheet_panel = PanelContainer.new()
	_active_sheet_panel.position = Vector2(10, 478)
	_active_sheet_panel.size = Vector2(394, 234)
	_active_sheet_style = _make_box(Color(0.06, 0.07, 0.09, 0.96), Color(0.95, 0.55, 0.16), 2, 8)
	_active_sheet_panel.add_theme_stylebox_override("panel", _active_sheet_style)
	add_child(_active_sheet_panel)

	_active_sheet_vbox = VBoxContainer.new()
	_active_sheet_vbox.add_theme_constant_override("separation", 5)
	_active_sheet_panel.add_child(_active_sheet_vbox)

	# 3. MINUTES DU COMBAT BAS-CENTRE (x=412..868, y=478..712)
	_minutes_panel = PanelContainer.new()
	_minutes_panel.position = Vector2(412, 478)
	_minutes_panel.size = Vector2(456, 234)
	_minutes_panel.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.06, 0.08, 0.95), Color(0.42, 0.44, 0.50), 2, 8))
	add_child(_minutes_panel)

	var min_v: VBoxContainer = VBoxContainer.new()
	min_v.add_theme_constant_override("separation", 5)
	_minutes_panel.add_child(min_v)

	var min_head: HBoxContainer = HBoxContainer.new()
	min_head.add_theme_constant_override("separation", 8)
	min_v.add_child(min_head)

	var l_min_t: Label = Label.new()
	l_min_t.text = "MINUTES DU COMBAT"
	l_min_t.add_theme_font_size_override("font_size", 11)
	l_min_t.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	min_head.add_child(l_min_t)

	_lbl_minutes_status = Label.new()
	_lbl_minutes_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_minutes_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_minutes_status.add_theme_font_size_override("font_size", 11)
	_lbl_minutes_status.add_theme_color_override("font_color", Color(0.76, 0.80, 0.88))
	min_head.add_child(_lbl_minutes_status)

	var bark_panel: PanelContainer = PanelContainer.new()
	_bark_panel_style = _make_box(Color(0.10, 0.09, 0.12, 0.96), Color(0.86, 0.22, 0.22), 1, 5)
	bark_panel.add_theme_stylebox_override("panel", _bark_panel_style)
	min_v.add_child(bark_panel)

	_lbl_bark = Label.new()
	_lbl_bark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_bark.custom_minimum_size = Vector2(0, 32)
	_lbl_bark.add_theme_font_size_override("font_size", 12)
	_lbl_bark.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	bark_panel.add_child(_lbl_bark)

	_minutes_scroll = ScrollContainer.new()
	_minutes_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_minutes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	min_v.add_child(_minutes_scroll)

	_lbl_log = Label.new()
	_lbl_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_log.add_theme_font_size_override("font_size", 11)
	_lbl_log.add_theme_color_override("font_color", Color(0.86, 0.85, 0.80))
	_minutes_scroll.add_child(_lbl_log)

	var min_foot: HBoxContainer = HBoxContainer.new()
	min_foot.add_theme_constant_override("separation", 6)
	min_v.add_child(min_foot)

	_btn_step = Button.new()
	_btn_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_step.custom_minimum_size = Vector2(0, 28)
	_btn_step.focus_mode = Control.FOCUS_NONE
	_btn_step.add_theme_font_size_override("font_size", 12)
	_btn_step.pressed.connect(func() -> void:
		if _timeline != null and bool(_timeline.get("awaiting_step")) and _pending_kind == "":
			_timeline.call("step_next_beat")
	)
	min_foot.add_child(_btn_step)

	_btn_cancel_target = Button.new()
	_btn_cancel_target.text = "✕ Annuler cible"
	_btn_cancel_target.custom_minimum_size = Vector2(126, 28)
	_btn_cancel_target.focus_mode = Control.FOCUS_NONE
	_btn_cancel_target.visible = false
	_btn_cancel_target.add_theme_font_size_override("font_size", 11)
	_btn_cancel_target.add_theme_stylebox_override("normal", _make_box(Color(0.32, 0.11, 0.12), Color(0.95, 0.34, 0.32), 1, 4))
	_btn_cancel_target.pressed.connect(cancel_targeting)
	min_foot.add_child(_btn_cancel_target)

	# 4. FICHE PERSONNAGE SURVOLÉ BAS-DROITE (x=876..1270, y=478..712 — même gabarit que gauche)
	_hover_panel = PanelContainer.new()
	_hover_panel.position = Vector2(876, 478)
	_hover_panel.size = Vector2(394, 234)
	_hover_panel.visible = false
	_hover_sheet_style = _make_box(Color(0.06, 0.07, 0.09, 0.96), Color(0.88, 0.86, 0.78), 2, 8)
	_hover_panel.add_theme_stylebox_override("panel", _hover_sheet_style)
	add_child(_hover_panel)

	_hover_sheet_vbox = VBoxContainer.new()
	_hover_sheet_vbox.add_theme_constant_override("separation", 5)
	_hover_panel.add_child(_hover_sheet_vbox)

	# 5. BANDEAU D'ALERTE CHARGE PNJ 10 s (x=230..1050, y=130..204 — dégage les pions dès y=214)
	_charge_alert_panel = PanelContainer.new()
	_charge_alert_panel.position = Vector2(230, 130)
	_charge_alert_panel.size = Vector2(820, 74)
	_charge_alert_panel.visible = false
	_charge_alert_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_charge_alert_panel.add_theme_stylebox_override("panel", _make_box(Color(0.20, 0.04, 0.05, 0.96), Color(1.0, 0.28, 0.24), 2, 6))
	add_child(_charge_alert_panel)

	var ch_v: VBoxContainer = VBoxContainer.new()
	ch_v.add_theme_constant_override("separation", 4)
	_charge_alert_panel.add_child(ch_v)

	var ch_head: HBoxContainer = HBoxContainer.new()
	ch_head.add_theme_constant_override("separation", 8)
	ch_v.add_child(ch_head)

	_lbl_charge_title = Label.new()
	_lbl_charge_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_charge_title.clip_text = true
	_lbl_charge_title.add_theme_font_size_override("font_size", 12)
	_lbl_charge_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	ch_head.add_child(_lbl_charge_title)

	_lbl_charge_timer = Label.new()
	_lbl_charge_timer.custom_minimum_size = Vector2(72, 0)
	_lbl_charge_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_charge_timer.add_theme_font_size_override("font_size", 13)
	_lbl_charge_timer.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
	ch_head.add_child(_lbl_charge_timer)

	_bar_charge_timer = ProgressBar.new()
	_bar_charge_timer.custom_minimum_size = Vector2(0, 7)
	_bar_charge_timer.show_percentage = false
	_bar_charge_timer.max_value = 10.0
	_bar_charge_timer.value = 10.0
	_bar_charge_timer.modulate = Color(1.0, 0.32, 0.28)
	ch_v.add_child(_bar_charge_timer)

	_charge_btns_hbox = HBoxContainer.new()
	_charge_btns_hbox.add_theme_constant_override("separation", 6)
	ch_v.add_child(_charge_btns_hbox)

## Indique si le joueur est en train de sélectionner une cible PJ ou PNJ sur le plateau isométrique.
func has_pending_targeting() -> bool:
	return _pending_kind != ""

## Annule le mode ciblage en cours et réinitialise la surbrillance sur la grille.
func cancel_targeting() -> void:
	if _pending_kind == "":
		return
	_clear_pending_targeting()
	targeting_state_changed.emit("", [], "")
	refresh()

func _clear_pending_targeting() -> void:
	_pending_kind = ""
	_pending_id = ""
	_pending_target_kind = ""
	_pending_valid_targets.clear()

func _start_targeting(pk: String, pid: String, tkind: String) -> void:
	if _timeline == null:
		return
	if _pending_kind == pk and _pending_id == pid:
		cancel_targeting()
		return
	var valid_var: Variant = _timeline.call("get_valid_target_ids_for_action", pid) if pk == "action" else _timeline.call("get_valid_target_ids", tkind)
	var valid_arr: Array[String] = []
	if valid_var is Array:
		for vv in (valid_var as Array):
			valid_arr.append(str(vv))
	if valid_arr.is_empty():
		return
	_pending_kind = pk
	_pending_id = pid
	_pending_target_kind = tkind
	_pending_valid_targets = valid_arr
	targeting_state_changed.emit(tkind, valid_arr, pid if pk == "action" else "")
	refresh()

## Sélectionne une option du tour PJ actif (exécute si sans cible, sinon active le ciblage sur pion).
func select_action(action_id: String) -> void:
	if _timeline == null or not bool(_timeline.get("active")):
		return
	if bool(_timeline.get("awaiting_step")) or bool(_timeline.call("is_charge_window_active")):
		return
	var tkind: String = str(_timeline.call("get_action_target_kind", action_id))
	if tkind == "none":
		_clear_pending_targeting()
		targeting_state_changed.emit("", [], "")
		_timeline.call("execute_player_action", action_id)
	else:
		_start_targeting("action", action_id, tkind)

## Déclenche ou prépare le ciblage d'une Interruption hors-tour.
func select_interruption(char_id: String) -> void:
	if _timeline == null or not bool(_timeline.get("active")) or bool(_timeline.call("is_charge_window_active")):
		return
	var tkind: String = str(_timeline.call("get_interruption_target_kind", char_id))
	if tkind == "none":
		_clear_pending_targeting()
		targeting_state_changed.emit("", [], "")
		_timeline.call("trigger_interruption", char_id)
	else:
		_start_targeting("interrupt", char_id, tkind)

## Prépare le ciblage du pion PJ en Crise d'autonomie à retenir.
func select_restrain() -> void:
	if _timeline == null or not bool(_timeline.get("active")) or bool(_timeline.call("is_charge_window_active")):
		return
	_start_targeting("restrain", "restrain", "ally_crisis")

## Reçoit un clic sur une case vide de la grille isométrique pour déplacer le PJ actif (PM restants).
func on_stage_cell_clicked(gx: int, gy: int) -> void:
	if input_blocked or _timeline == null or not bool(_timeline.get("active")):
		return
	if _pending_kind != "" or bool(_timeline.get("awaiting_step")) or bool(_timeline.call("is_charge_window_active")):
		return
	_timeline.call("move_active_ally_to", gx, gy)

## Reçoit le survol d'un pion depuis le quadrillage isométrique central.
func on_stage_actor_hovered(kind: String, entity_id: String) -> void:
	_hovered_kind = kind
	_hovered_id = entity_id
	_rebuild_hover_panel()

## Reçoit un clic gauche sur un pion du quadrillage isométrique central.
func on_stage_actor_clicked(kind: String, entity_id: String) -> void:
	if _timeline == null or not bool(_timeline.get("active")):
		return
	if bool(_timeline.call("is_charge_window_active")) and kind == "enemy":
		var ch_v: Variant = _timeline.get("pending_enemy_charge")
		if ch_v is Dictionary and str((ch_v as Dictionary).get("enemy_id", "")) == entity_id:
			var cand_v: Variant = _timeline.call("get_charge_interceptor_candidates")
			if cand_v is Array and not (cand_v as Array).is_empty():
				var best_cid: String = ""
				var best_pct: int = -1
				for cv in (cand_v as Array):
					if cv is Dictionary:
						var cd: Dictionary = cv as Dictionary
						var pct_c: int = int(cd.get("chance_pct", 0)) + (1000 if bool(cd.get("is_target_ally", false)) else 0)
						if pct_c > best_pct:
							best_pct = pct_c
							best_cid = str(cd.get("char_id", ""))
				if best_cid != "":
					_timeline.call("trigger_charge_interception", best_cid)
					return
	if _pending_kind != "":
		var kind_ok: bool = ((_pending_target_kind == "enemy" and kind == "enemy") or ((_pending_target_kind == "ally" or _pending_target_kind == "ally_crisis") and kind == "ally"))
		if kind_ok and _pending_valid_targets.has(entity_id):
			var pk: String = _pending_kind
			var pid: String = _pending_id
			_clear_pending_targeting()
			targeting_state_changed.emit("", [], "")
			if pk == "action":
				_timeline.call("execute_player_action_on", pid, entity_id)
			elif pk == "interrupt":
				_timeline.call("trigger_interruption_on", pid, entity_id)
			elif pk == "restrain":
				_timeline.call("restrain_crisis", entity_id)
			return
	if kind == "enemy":
		_timeline.call("select_target", entity_id)
	_hovered_kind = kind
	_hovered_id = entity_id
	_rebuild_hover_panel()

## Met à jour le bandeau Bark BD et sa bordure/teinte selon la gravité de l'événement émis.
func _on_combat_feedback(event_data: Dictionary) -> void:
	var txt: String = str(event_data.get("text", ""))
	if txt != "":
		_bark_override_text = txt
	if _bark_panel_style != null:
		var k: String = str(event_data.get("kind", ""))
		if k == "ally_brilliant":
			_bark_panel_style.border_color = Color(0.98, 0.78, 0.24)
			_bark_panel_style.bg_color = Color(0.14, 0.11, 0.05, 0.96)
		elif k == "ally_flaw" or k == "enemy" or k == "crisis" or k == "counter" or k == "charge_alert":
			_bark_panel_style.border_color = Color(0.92, 0.24, 0.24)
			_bark_panel_style.bg_color = Color(0.14, 0.06, 0.07, 0.96)
		else:
			_bark_panel_style.border_color = Color(0.95, 0.55, 0.16)
			_bark_panel_style.bg_color = Color(0.10, 0.09, 0.12, 0.96)

func _on_charge_window_started(_charge_data: Dictionary) -> void:
	_last_rendered_charge_key = ""
	_sync_charge_alert_panel()

func _on_charge_window_ticked(time_left: float, time_max: float) -> void:
	if _lbl_charge_timer != null:
		_lbl_charge_timer.text = "⏱ %.1f s" % maxf(0.0, time_left)
	if _bar_charge_timer != null:
		_bar_charge_timer.max_value = maxf(0.1, time_max)
		_bar_charge_timer.value = clampf(time_left, 0.0, time_max)

func _on_charge_window_ended(_outcome: String, _summary: String) -> void:
	_last_rendered_charge_key = ""
	if _charge_alert_panel != null:
		_charge_alert_panel.visible = false

func _sync_charge_alert_panel() -> void:
	if _charge_alert_panel == null or _timeline == null:
		return
	var is_cw: bool = bool(_timeline.call("is_charge_window_active"))
	if not is_cw:
		_charge_alert_panel.visible = false
		_last_rendered_charge_key = ""
		return
	_charge_alert_panel.visible = true
	var ch_v: Variant = _timeline.get("pending_enemy_charge")
	var ch: Dictionary = ch_v as Dictionary if ch_v is Dictionary else {}
	var tl: float = float(ch.get("time_left", 10.0))
	var tm: float = float(ch.get("time_max", 10.0))
	_lbl_charge_timer.text = "⏱ %.1f s" % maxf(0.0, tl)
	_bar_charge_timer.max_value = maxf(0.1, tm)
	_bar_charge_timer.value = clampf(tl, 0.0, tm)

	var cands_v: Variant = _timeline.call("get_charge_interceptor_candidates")
	var cands: Array = cands_v as Array if cands_v is Array else []
	var cid_parts: Array[String] = []
	for cv in cands:
		if cv is Dictionary:
			cid_parts.append(str((cv as Dictionary).get("char_id", "")))
	var ename: String = str(ch.get("enemy_name", "PNJ"))
	var tname: String = str(ch.get("target_ally_name", "PJ"))
	var render_key: String = "%s|%s|%s" % [ename, tname, ",".join(cid_parts)]
	if render_key == _last_rendered_charge_key:
		return
	_last_rendered_charge_key = render_key

	_lbl_charge_title.text = "⚡ CHARGE PNJ ! %s fonce sur %s → (%d,%d) — Clique un PJ ou le pion pour INTERCEPTER (-2 rangs) !" % [
		ename, tname, int(ch.get("to_x", 0)), int(ch.get("to_y", 0))
	]
	for b in _charge_btns_hbox.get_children():
		b.queue_free()

	var l_int: Label = Label.new()
	l_int.text = "Interception (10 s) :"
	l_int.add_theme_font_size_override("font_size", 11)
	l_int.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	_charge_btns_hbox.add_child(l_int)

	if cands.is_empty():
		var l_none: Label = Label.new()
		l_none.text = "Aucun PJ avec Réaction disponible…"
		l_none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l_none.add_theme_font_size_override("font_size", 11)
		l_none.add_theme_color_override("font_color", Color(0.75, 0.65, 0.65))
		_charge_btns_hbox.add_child(l_none)
	else:
		for cv2 in cands:
			if cv2 is Dictionary:
				var cd: Dictionary = cv2 as Dictionary
				var cid: String = str(cd.get("char_id", ""))
				var btn_i: Button = Button.new()
				btn_i.custom_minimum_size = Vector2(0, 26)
				btn_i.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn_i.clip_text = true
				btn_i.focus_mode = Control.FOCUS_NONE
				btn_i.add_theme_font_size_override("font_size", 11)
				var tgt_tag: String = " [Cible]" if bool(cd.get("is_target_ally", false)) else ""
				btn_i.text = "⚡ %s%s · %d%%" % [str(cd.get("name", cid)), tgt_tag, int(cd.get("chance_pct", 50))]
				btn_i.tooltip_text = "%s vs DD %d — Réussite : %s ASSOMMÉ & perd 2 rangs !" % [str(cd.get("skill_name", "")), int(cd.get("dc", 11)), ename]
				btn_i.add_theme_stylebox_override("normal", _make_box(Color(0.12, 0.24, 0.36), Color(0.36, 0.86, 0.98), 1, 4))
				var cid_cap: String = cid
				btn_i.pressed.connect(func() -> void:
					if _timeline != null:
						_timeline.call("trigger_charge_interception", cid_cap)
				)
				_charge_btns_hbox.add_child(btn_i)

	var btn_pass: Button = Button.new()
	btn_pass.text = "Encaisser / Passer ▶"
	btn_pass.custom_minimum_size = Vector2(142, 26)
	btn_pass.focus_mode = Control.FOCUS_NONE
	btn_pass.add_theme_font_size_override("font_size", 10)
	btn_pass.add_theme_stylebox_override("normal", _make_box(Color(0.30, 0.14, 0.12), Color(0.90, 0.42, 0.32), 1, 4))
	btn_pass.pressed.connect(func() -> void:
		if _timeline != null:
			_timeline.call("resolve_pending_enemy_charge")
	)
	_charge_btns_hbox.add_child(btn_pass)

func _on_encounter_finished(_outcome_id: String, _summary: String) -> void:
	visible = false
	_clear_pending_targeting()
	_last_rendered_charge_key = ""
	if _charge_alert_panel != null:
		_charge_alert_panel.visible = false
	_hovered_kind = ""
	_hovered_id = ""
	_bark_override_text = ""
	targeting_state_changed.emit("", [], "")
	frise_actor_hovered.emit("", "")
	if _bark_panel_style != null:
		_bark_panel_style.border_color = Color(0.86, 0.22, 0.22)
		_bark_panel_style.bg_color = Color(0.10, 0.09, 0.12, 0.96)

## Reconstruit la Frise haute, le bandeau d'alerte Charge, la fiche active, les Minutes du combat et la fiche survolée.
func refresh() -> void:
	if _timeline == null:
		return
	var is_act: bool = bool(_timeline.get("active"))
	visible = is_act
	if not is_act:
		if _charge_alert_panel != null:
			_charge_alert_panel.visible = false
		return

	var is_cw_now: bool = bool(_timeline.call("is_charge_window_active"))
	if is_cw_now and _pending_kind != "":
		_clear_pending_targeting()
		targeting_state_changed.emit("", [], "")

	if _pending_kind != "":
		var valid_now_var: Variant = _timeline.call("get_valid_target_ids_for_action", _pending_id) if _pending_kind == "action" else _timeline.call("get_valid_target_ids", _pending_target_kind)
		var valid_now: Array[String] = []
		if valid_now_var is Array:
			for vn in (valid_now_var as Array):
				valid_now.append(str(vn))
		if valid_now.is_empty():
			_clear_pending_targeting()
			targeting_state_changed.emit("", [], "")
		else:
			_pending_valid_targets = valid_now
			targeting_state_changed.emit(_pending_target_kind, _pending_valid_targets, _pending_id if _pending_kind == "action" else "")

	_sync_charge_alert_panel()

	var turn_c: int = int(_timeline.get("turn_count"))
	var crs_t: int = int(_timeline.get("crs_ticks"))
	var esc_p: int = int(_timeline.get("escape_progress"))
	var shield_p: int = int(_timeline.get("interposition_shield"))
	var tf_arrived: bool = bool(_timeline.get("train_fantome_arrived"))
	var is_waiting: bool = bool(_timeline.get("awaiting_step"))
	var step_lbl: String = str(_timeline.get("pending_beat_label"))

	_lbl_header.text = "TOUR %d\n%s" % [turn_c, str(_timeline.get("encounter_title"))]
	_lbl_crs.text = "CRS : %d cran(s)" % maxi(0, crs_t)
	_lbl_crs.add_theme_color_override("font_color", Color(1.0, 0.36, 0.34) if crs_t <= 2 else Color(0.38, 0.72, 0.98))
	_lbl_escape.text = "TRAIN FANTÔME À QUAI !" if tf_arrived else ("Échappée : %d/2" % esc_p)
	_lbl_shield.visible = shield_p > 0
	_lbl_shield.text = "Bouclier Interp. x%d" % shield_p

	_rebuild_top_frise()
	_rebuild_active_sheet_panel(is_waiting)
	_rebuild_minutes_panel(is_waiting, step_lbl)
	_rebuild_hover_panel()

func _rebuild_top_frise() -> void:
	for c in _rail_hbox.get_children():
		c.queue_free()
	_frise_cards.clear()

	var entries_var: Variant = _timeline.call("get_ordered_rail_entries")
	if not (entries_var is Array):
		return
	for ed_var in (entries_var as Array):
		if not (ed_var is Dictionary):
			continue
		var ed: Dictionary = ed_var as Dictionary
		var card: Control = _build_frise_vertical_card(ed)
		_rail_hbox.add_child(card)
		_frise_cards.append(card)

func _build_frise_vertical_card(ed: Dictionary) -> Control:
	var kind: String = str(ed.get("kind", ""))
	var eid: String = str(ed.get("id", ""))
	var is_acting: bool = bool(ed.get("acting", false))
	var in_crisis: bool = bool(ed.get("in_crisis", false))
	var is_stun: bool = bool(ed.get("stunned", false))

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(82, 104)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var col_char: Color = Color.html(str(ed.get("color", "#f28c28")))
	var b_col: Color = Color(1.0, 0.82, 0.24) if is_acting else (Color(1.0, 0.28, 0.28) if in_crisis else (Color(0.76, 0.52, 0.98) if is_stun else col_char))
	var bg_col: Color = Color(0.20, 0.14, 0.08, 0.96) if is_acting else (Color(0.22, 0.08, 0.09, 0.96) if in_crisis else (Color(0.16, 0.10, 0.22, 0.95) if is_stun else Color(0.10, 0.11, 0.14, 0.94)))
	card.add_theme_stylebox_override("panel", _make_box(bg_col, b_col, 3 if (is_acting or in_crisis or is_stun) else 1, 4))

	if kind == "ally" or kind == "enemy":
		var k_cap: String = kind
		var id_cap: String = eid
		card.mouse_entered.connect(func() -> void:
			frise_actor_hovered.emit(k_cap, id_cap)
			on_stage_actor_hovered(k_cap, id_cap)
		)
		card.mouse_exited.connect(func() -> void:
			frise_actor_hovered.emit("", "")
			on_stage_actor_hovered("", "")
		)

	var cv: VBoxContainer = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cv)

	var ptex: TextureRect = TextureRect.new()
	ptex.custom_minimum_size = Vector2(72, 62)
	ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ptex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ppath: String = str(ed.get("portrait", ""))
	if ppath != "":
		ptex.texture = _load_texture_safe(ppath)
	if kind == "reinforcement":
		ptex.modulate = Color(0.68, 0.76, 0.84)
	cv.add_child(ptex)

	var l_name: Label = Label.new()
	l_name.text = ("💫 " if is_stun else "") + str(ed.get("label", eid))
	l_name.clip_text = true
	l_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_name.add_theme_font_size_override("font_size", 10)
	l_name.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42) if is_acting else (Color(0.86, 0.72, 1.0) if is_stun else Color(0.95, 0.93, 0.88)))
	l_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(l_name)

	var gauge: ProgressBar = ProgressBar.new()
	gauge.custom_minimum_size = Vector2(0, 8)
	gauge.show_percentage = false
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == "enemy":
		var rmax: int = maxi(1, int(ed.get("resolve_max", 1)))
		gauge.max_value = rmax
		gauge.value = clampi(int(ed.get("resolve", 1)), 0, rmax)
		gauge.modulate = Color(0.95, 0.28, 0.26)
	elif kind == "crs":
		gauge.max_value = 6
		gauge.value = clampi(int(ed.get("tick", 0)), 0, 6)
		gauge.modulate = Color(0.32, 0.68, 1.0)
	else:
		var mmax: int = maxi(1, int(ed.get("moral_max", 100)))
		var mval: int = clampi(int(ed.get("moral", 60)), 0, mmax)
		gauge.max_value = mmax
		gauge.value = mval
		gauge.modulate = Color(0.34, 0.86, 0.48) if not in_crisis else Color(0.98, 0.30, 0.28)
	cv.add_child(gauge)

	return card

func _rebuild_active_sheet_panel(is_waiting: bool) -> void:
	for c in _active_sheet_vbox.get_children():
		c.queue_free()
	_actions_box = null
	_current_action_ids.clear()

	var ent_var: Variant = _timeline.call("get_active_turn_entity")
	var ent: Dictionary = ent_var as Dictionary if ent_var is Dictionary else {}
	var kind: String = str(ent.get("kind", "ally"))
	var eid: String = str(ent.get("id", ""))
	if eid == "":
		return

	var sheet_var: Variant = _timeline.call("get_entity_sheet_data", kind, eid)
	var sheet: Dictionary = sheet_var as Dictionary if sheet_var is Dictionary else {}
	if sheet.is_empty():
		return

	var is_crisis_turn: bool = bool(ent.get("is_crisis_turn", false))
	var border_col: Color = Color(1.0, 0.28, 0.28) if (kind == "enemy" or is_crisis_turn) else Color(0.98, 0.78, 0.24)
	_active_sheet_style.border_color = border_col

	_populate_character_sheet_into(_active_sheet_vbox, sheet, "active", is_waiting, is_crisis_turn)

func _rebuild_hover_panel() -> void:
	for c in _hover_sheet_vbox.get_children():
		c.queue_free()
	if _timeline == null or not bool(_timeline.get("active")) or _hovered_id == "" or (_hovered_kind != "ally" and _hovered_kind != "enemy"):
		_hover_panel.visible = false
		return

	var sheet_var: Variant = _timeline.call("get_entity_sheet_data", _hovered_kind, _hovered_id)
	var sheet: Dictionary = sheet_var as Dictionary if sheet_var is Dictionary else {}
	if sheet.is_empty():
		_hover_panel.visible = false
		return

	_hover_panel.visible = true
	var is_valid_tgt: bool = false
	if _pending_kind != "":
		var kind_ok: bool = ((_pending_target_kind == "enemy" and _hovered_kind == "enemy") or ((_pending_target_kind == "ally" or _pending_target_kind == "ally_crisis") and _hovered_kind == "ally"))
		is_valid_tgt = kind_ok and _pending_valid_targets.has(_hovered_id)
	if is_valid_tgt:
		_hover_sheet_style.border_color = Color(0.98, 0.28, 0.28) if _hovered_kind == "enemy" else Color(0.32, 0.90, 0.98)
	else:
		_hover_sheet_style.border_color = Color.html(str(sheet.get("color_hex", "#e6e2d8")))

	_populate_character_sheet_into(_hover_sheet_vbox, sheet, "hover", bool(_timeline.get("awaiting_step")), false)

## Remplit indifféremment la fiche gauche (personnage actif) ou droite (personnage survolé) avec le même gabarit.
func _populate_character_sheet_into(parent: VBoxContainer, sheet: Dictionary, mode: String, is_waiting: bool, is_crisis_turn: bool) -> void:
	var kind: String = str(sheet.get("kind", "ally"))
	var eid: String = str(sheet.get("id", ""))

	# En-tête commun : Portrait + Identité + Stats utiles
	var head_h: HBoxContainer = HBoxContainer.new()
	head_h.add_theme_constant_override("separation", 8)
	parent.add_child(head_h)

	var ptex: TextureRect = TextureRect.new()
	ptex.custom_minimum_size = Vector2(54, 62)
	ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ptex.texture = _load_texture_safe(str(sheet.get("portrait", "")))
	head_h.add_child(ptex)

	var info_v: VBoxContainer = VBoxContainer.new()
	info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_v.add_theme_constant_override("separation", 2)
	head_h.add_child(info_v)

	var title_row: HBoxContainer = HBoxContainer.new()
	info_v.add_child(title_row)

	var l_name: Label = Label.new()
	l_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_name.clip_text = true
	l_name.text = "%s — %s" % [str(sheet.get("name", eid)), str(sheet.get("role", ""))]
	l_name.add_theme_font_size_override("font_size", 12)
	l_name.add_theme_color_override("font_color", Color.WHITE)
	title_row.add_child(l_name)

	var l_badge: Label = Label.new()
	if mode == "active":
		if is_crisis_turn:
			l_badge.text = "🔥 CRISE"
			l_badge.add_theme_color_override("font_color", Color(1.0, 0.36, 0.36))
		elif kind == "enemy":
			l_badge.text = "TOUR PNJ"
			l_badge.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
		else:
			l_badge.text = "TOUR PJ"
			l_badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.30))
	else:
		l_badge.text = "SURVOL"
		l_badge.add_theme_color_override("font_color", Color(0.82, 0.90, 0.98))
	l_badge.add_theme_font_size_override("font_size", 10)
	title_row.add_child(l_badge)

	if kind == "ally":
		var mp_l: int = int(sheet.get("move_points_left", 0))
		var mp_m: int = int(sheet.get("move_points_max", 2))
		var stun_s: String = "  ·  💫 ASSOMMÉ" if bool(sheet.get("stunned", false)) else ""
		var l_st1: Label = Label.new()
		l_st1.clip_text = true
		l_st1.text = "Mor %d/%d · PM %d/%d · Att %d · Aura %d%s" % [
			int(sheet.get("moral", 60)),
			int(sheet.get("moral_max", 100)),
			mp_l,
			mp_m,
			int(sheet.get("attitude", 60)),
			int(sheet.get("aura", 3)),
			stun_s
		]
		l_st1.add_theme_font_size_override("font_size", 10)
		l_st1.add_theme_color_override("font_color", Color(0.86, 0.90, 0.94))
		info_v.add_child(l_st1)

		var sk_var: Variant = sheet.get("top_skills", [])
		var sk_str: String = ", ".join(sk_var as Array) if sk_var is Array else ""
		var l_st2: Label = Label.new()
		l_st2.clip_text = true
		l_st2.text = "Esp %d · Cor %d · Én %d  |  %s" % [
			int(sheet.get("esprit", 3)),
			int(sheet.get("corps", 3)),
			int(sheet.get("energie", 3)),
			sk_str
		]
		l_st2.add_theme_font_size_override("font_size", 10)
		l_st2.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
		info_v.add_child(l_st2)
	else:
		var rmax_e: int = maxi(1, int(sheet.get("resolve_max", 1)))
		var rcur_e: int = int(sheet.get("resolve", 1))
		var stun_es: String = " · 💫 ASSOMMÉ" if bool(sheet.get("stunned", false)) else ""
		var l_es1: Label = Label.new()
		l_es1.clip_text = true
		l_es1.text = "Résol. %d/%d · DD Soc %d · DD Pres %d%s" % [
			rcur_e, rmax_e, int(sheet.get("dc_social", 11)), int(sheet.get("dc_pression", 11)), stun_es
		]
		l_es1.add_theme_font_size_override("font_size", 10)
		l_es1.add_theme_color_override("font_color", Color(1.0, 0.68, 0.64))
		info_v.add_child(l_es1)

		var l_es2: Label = Label.new()
		l_es2.clip_text = true
		l_es2.text = ("⚠ Intercept./Contre prêt" if bool(sheet.get("counter_ready", false)) else "Pas de contre active") + "  ·  Cran +%d" % int(sheet.get("next_tick", 1))
		l_es2.add_theme_font_size_override("font_size", 10)
		l_es2.add_theme_color_override("font_color", Color(1.0, 0.40, 0.40) if bool(sheet.get("counter_ready", false)) else Color(0.76, 0.80, 0.86))
		info_v.add_child(l_es2)

	# Corps central spécifique Actif vs Survol
	var is_cw_sheet: bool = bool(_timeline.call("is_charge_window_active"))
	if mode == "active":
		if kind == "ally" and not is_crisis_turn and not is_waiting and not is_cw_sheet:
			var act_scroll: ScrollContainer = ScrollContainer.new()
			act_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			act_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			parent.add_child(act_scroll)

			_actions_box = GridContainer.new()
			_actions_box.columns = 2
			_actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_actions_box.add_theme_constant_override("h_separation", 6)
			_actions_box.add_theme_constant_override("v_separation", 4)
			act_scroll.add_child(_actions_box)

			var avail_var: Variant = _timeline.call("get_available_actions_for_actor")
			var avail_list: Array = avail_var as Array if avail_var is Array else []
			var slot_num: int = 1
			for av in avail_list:
				if not (av is Dictionary):
					continue
				var ad: Dictionary = av as Dictionary
				var aid: String = str(ad.get("id", ""))
				var is_eq: bool = bool(ad.get("is_equipment", false))
				var is_used: bool = bool(ad.get("used", false))
				var usable: bool = bool(ad.get("usable", true))
				var lock_r: String = str(ad.get("locked_reason", ""))
				var pct: int = int(ad.get("chance_pct", 0))
				var is_fl: bool = bool(ad.get("is_flaw", false))
				var r_tag: String = str(ad.get("range_label", ""))
				var r_suffix: String = (" (%s)" % r_tag) if (r_tag != "" and r_tag != "∞") else ""
				var slbl: String = str(ad.get("short_label", aid))
				var tkind: String = str(_timeline.call("get_action_target_kind", aid))
				var tgt_mark: String = " 🎯" if (tkind != "none" and usable) else ""
				_current_action_ids.append(aid)

				var btn: Button = Button.new()
				btn.custom_minimum_size = Vector2(0, 29)
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.clip_text = true
				btn.focus_mode = Control.FOCUS_NONE
				btn.disabled = (is_used or not usable)
				btn.tooltip_text = str(ad.get("tooltip", slbl))
				btn.add_theme_font_size_override("font_size", 10)

				var is_sel_pending: bool = (_pending_kind == "action" and _pending_id == aid)
				if aid == "act_escape_now":
					btn.text = "[%d] %s" % [slot_num, slbl]
					btn.add_theme_stylebox_override("normal", _make_box(Color(0.28, 0.20, 0.07), Color(0.98, 0.78, 0.26), 2, 4))
				elif is_sel_pending:
					btn.text = "[%d] 🎯 CLIC PION…" % slot_num
					btn.add_theme_stylebox_override("normal", _make_box(Color(0.36, 0.22, 0.06), Color(1.0, 0.90, 0.34), 2, 4))
				elif is_eq:
					if is_used:
						btn.text = "[%d] ★ %s [Util.]" % [slot_num, slbl]
					elif not usable:
						btn.text = "[%d] ★ %s%s [H.P.]" % [slot_num, slbl, r_suffix]
					else:
						btn.text = "[%d] ★ %s%s%s · %d%%%s" % [slot_num, slbl, r_suffix, tgt_mark, pct, (" ⚠" if is_fl else "")]
						btn.add_theme_stylebox_override("normal", _make_box(Color(0.18, 0.14, 0.08), Color(0.92, 0.70, 0.24), 1, 4))
				elif not usable:
					var lock_short: String = "Outil tir" if aid == "act_tir" and "Outil" in lock_r else "H.P."
					btn.text = "[%d] 🔒 %s%s · %s" % [slot_num, slbl, r_suffix, lock_short]
				else:
					btn.text = "[%d] %s%s%s · %d%%%s" % [slot_num, slbl, r_suffix, tgt_mark, pct, (" ⚠" if is_fl else "")]
					if is_fl:
						btn.add_theme_color_override("font_color", Color(1.0, 0.56, 0.52))
						btn.add_theme_stylebox_override("normal", _make_box(Color(0.16, 0.09, 0.10), Color(0.88, 0.34, 0.32), 1, 4))

				var aid_cap: String = aid
				btn.pressed.connect(func() -> void: select_action(aid_cap))
				_actions_box.add_child(btn)
				slot_num += 1
		else:
			var desc_panel: PanelContainer = PanelContainer.new()
			desc_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			desc_panel.add_theme_stylebox_override("panel", _make_box(Color(0.10, 0.10, 0.13, 0.95), Color(0.34, 0.34, 0.40), 1, 6))
			parent.add_child(desc_panel)

			var l_body: Label = Label.new()
			l_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l_body.add_theme_font_size_override("font_size", 11)
			if is_cw_sheet:
				l_body.text = "⚡ CHARGE EN COURS (%s) !\nClique un PJ sur le bandeau ci-dessus ou ce pion pour l'intercepter avant la fin des 10 s !" % str(sheet.get("name", ""))
				l_body.add_theme_color_override("font_color", Color(1.0, 0.62, 0.44))
			elif is_crisis_turn:
				l_body.text = "🔥 CRISE D'AUTONOMIE IMMINENTE : %s\nRetiens %s hors-frise ou résous avec [Espace]." % [str(sheet.get("crisis_label", "")), str(sheet.get("name", ""))]
				l_body.add_theme_color_override("font_color", Color(1.0, 0.58, 0.54))
			elif kind == "enemy":
				l_body.text = "Intention : %s\n%s" % [str(sheet.get("intent_label", "")), str(sheet.get("bark", ""))]
				l_body.add_theme_color_override("font_color", Color(0.95, 0.88, 0.82))
			else:
				l_body.text = "En attente du prochain cran (%s) — hors-frise utilisables ci-dessous." % str(sheet.get("specialty_name", ""))
				l_body.add_theme_color_override("font_color", Color(0.84, 0.88, 0.92))
			desc_panel.add_child(l_body)

		# Pied de fiche active : Fin tour (+1c) + Réactions hors-frise + Retenir crise
		var react_h: HBoxContainer = HBoxContainer.new()
		react_h.add_theme_constant_override("separation", 4)
		parent.add_child(react_h)

		if kind == "ally" and not is_crisis_turn and not is_waiting and not is_cw_sheet:
			var btn_wait: Button = Button.new()
			btn_wait.text = "⏳ Fin (+1c)"
			btn_wait.custom_minimum_size = Vector2(76, 26)
			btn_wait.focus_mode = Control.FOCUS_NONE
			btn_wait.tooltip_text = "Clôturer le tour sans attaquer (+1 cran, garde Réaction)"
			btn_wait.add_theme_font_size_override("font_size", 10)
			btn_wait.pressed.connect(func() -> void:
				if _timeline != null:
					_clear_pending_targeting()
					targeting_state_changed.emit("", [], "")
					_timeline.call("end_active_ally_turn_wait")
			)
			react_h.add_child(btn_wait)

		var l_hr: Label = Label.new()
		l_hr.text = "Hors-frise:"
		l_hr.add_theme_font_size_override("font_size", 10)
		l_hr.add_theme_color_override("font_color", Color(0.42, 0.78, 0.98))
		react_h.add_child(l_hr)

		var rlist_var: Variant = _timeline.call("get_ready_reactions")
		if rlist_var is Array:
			for rv in (rlist_var as Array):
				if rv is Dictionary:
					var rd: Dictionary = rv as Dictionary
					var rcid: String = str(rd.get("char_id", ""))
					var btn_r: Button = Button.new()
					btn_r.custom_minimum_size = Vector2(0, 26)
					btn_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					btn_r.clip_text = true
					btn_r.focus_mode = Control.FOCUS_NONE
					btn_r.add_theme_font_size_override("font_size", 10)
					var r_tk: String = str(_timeline.call("get_interruption_target_kind", rcid))
					btn_r.text = ("🎯 " if (_pending_kind == "interrupt" and _pending_id == rcid) else "⚡ ") + str(rd.get("name", rcid))
					btn_r.tooltip_text = str(rd.get("specialty_name", "Interruption")) + (" (clic sur pion requis)" if r_tk != "none" else "")
					var rcid_cap: String = rcid
					btn_r.pressed.connect(func() -> void: select_interruption(rcid_cap))
					react_h.add_child(btn_r)

		var cq_var: Variant = _timeline.get("crisis_queue")
		if cq_var is Array and not (cq_var as Array).is_empty():
			var btn_ret: Button = Button.new()
			btn_ret.custom_minimum_size = Vector2(78, 26)
			btn_ret.focus_mode = Control.FOCUS_NONE
			btn_ret.add_theme_font_size_override("font_size", 10)
			btn_ret.text = "🛡 Retenir"
			btn_ret.add_theme_stylebox_override("normal", _make_box(Color(0.50, 0.14, 0.14), Color(1.0, 0.52, 0.34), 1, 3))
			btn_ret.pressed.connect(select_restrain)
			react_h.add_child(btn_ret)
	else:
		# Corps & Pied Fiche Survolée (droite) — même structure visuelle
		var mid_box: PanelContainer = PanelContainer.new()
		mid_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mid_box.add_theme_stylebox_override("panel", _make_box(Color(0.10, 0.10, 0.13, 0.95), Color(0.32, 0.34, 0.40), 1, 6))
		parent.add_child(mid_box)

		var mid_v: VBoxContainer = VBoxContainer.new()
		mid_v.add_theme_constant_override("separation", 4)
		mid_box.add_child(mid_v)

		var l_det: Label = Label.new()
		l_det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l_det.add_theme_font_size_override("font_size", 11)
		if kind == "ally":
			var eq_var: Variant = sheet.get("equipped_items", [])
			var eq_str: String = ", ".join(eq_var as Array) if eq_var is Array and not (eq_var as Array).is_empty() else "Matériel léger"
			var cr_line: String = ("\n🔥 Crise : %s (+%dc)" % [str(sheet.get("crisis_label", "")), int(sheet.get("crisis_ticks", 0))]) if bool(sheet.get("in_crisis", false)) else ""
			l_det.text = "Spécialité : %s\nMatos : %s%s" % [str(sheet.get("specialty_name", "")), eq_str, cr_line]
			l_det.add_theme_color_override("font_color", Color(0.90, 0.90, 0.86))
		else:
			l_det.text = "Intention : %s\n%s" % [str(sheet.get("intent_label", "")), str(sheet.get("bark", ""))]
			l_det.add_theme_color_override("font_color", Color(0.96, 0.88, 0.82))
		mid_v.add_child(l_det)

		var l_pv_tgt: Label = Label.new()
		l_pv_tgt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l_pv_tgt.add_theme_font_size_override("font_size", 11)
		var dist_str: String = ""
		var ent_act_v: Variant = _timeline.call("get_active_turn_entity")
		if ent_act_v is Dictionary:
			var ent_act: Dictionary = ent_act_v as Dictionary
			var ak_act: String = str(ent_act.get("kind", ""))
			var aid_act: String = str(ent_act.get("id", ""))
			if aid_act != "" and not (ak_act == kind and aid_act == eid):
				var d_val: int = int(_timeline.call("get_distance_between", ak_act, aid_act, kind, eid))
				if d_val >= 0:
					dist_str = "Dist. : %d case(s) · " % d_val
		if _pending_kind != "":
			var k_ok: bool = ((_pending_target_kind == "enemy" and kind == "enemy") or ((_pending_target_kind == "ally" or _pending_target_kind == "ally_crisis") and kind == "ally"))
			if k_ok and _pending_valid_targets.has(eid):
				var pv_res: Dictionary = {}
				if _pending_kind == "action":
					var pva: Variant = _timeline.call("preview_player_action_on", _pending_id, eid)
					if pva is Dictionary:
						pv_res = pva as Dictionary
				elif _pending_kind == "interrupt":
					var pvi: Variant = _timeline.call("preview_interruption_on", _pending_id, eid)
					if pvi is Dictionary:
						pv_res = pvi as Dictionary
				elif _pending_kind == "restrain":
					var pvr: Variant = _timeline.call("preview_restrain", eid)
					if pvr is Dictionary:
						pv_res = pvr as Dictionary
				var pct_v: int = int(pv_res.get("chance_pct", 0))
				var pct_s: String = ("🎲 %d%% · " % pct_v) if pct_v > 0 else ""
				var warn_s: String = ""
				if bool(pv_res.get("counter_warning", false)):
					warn_s = "\n⚠ %s" % str(pv_res.get("counter_label", "INTERCEPTION / CONTRE PRÊT !"))
				elif bool(pv_res.get("is_flaw", false)):
					warn_s = "\n⚠ FAILLE (%s %+d)" % [str(pv_res.get("skill_name", "")), int(pv_res.get("skill_val", -1))]
				l_pv_tgt.text = "🎯 CIBLE VALIDE (%s%s)%s%s\n▸ Clic gauche sur le pion pour valider" % [dist_str, pct_s, str(pv_res.get("summary", "")), warn_s]
				l_pv_tgt.add_theme_color_override("font_color", Color(1.0, 0.88, 0.34))
			elif _pending_kind == "action" and kind == "enemy":
				var pva_bad: Variant = _timeline.call("preview_player_action_on", _pending_id, eid)
				var bad_r: String = str((pva_bad as Dictionary).get("reason", "Hors portée / non ciblable")) if pva_bad is Dictionary else "Non ciblable"
				l_pv_tgt.text = "%s🚫 %s" % [dist_str, bad_r]
				l_pv_tgt.add_theme_color_override("font_color", Color(0.95, 0.56, 0.44))
			else:
				l_pv_tgt.text = "%sNon ciblable pour l'option sélectionnée." % dist_str
				l_pv_tgt.add_theme_color_override("font_color", Color(0.62, 0.64, 0.70))
		else:
			var stun_tag: String = "💫 ASSOMMÉ · " if bool(sheet.get("stunned", false)) else ""
			l_pv_tgt.text = "%s%sProchain tour dans +%d cran(s)." % [dist_str, stun_tag, int(sheet.get("next_tick", 0))]
			l_pv_tgt.add_theme_color_override("font_color", Color(0.86, 0.74, 1.0) if bool(sheet.get("stunned", false)) else Color(0.70, 0.78, 0.88))
		mid_v.add_child(l_pv_tgt)

func _rebuild_minutes_panel(is_waiting: bool, step_lbl: String) -> void:
	var is_cw_min: bool = bool(_timeline.call("is_charge_window_active"))
	if is_cw_min:
		_lbl_minutes_status.text = "⚡ CHARGE PNJ — INTERCEPTE OU ENCAISSE !"
		_lbl_minutes_status.add_theme_color_override("font_color", Color(1.0, 0.36, 0.32))
	elif _pending_kind != "":
		_lbl_minutes_status.text = "🎯 Clique le pion ciblé sur la scène"
		_lbl_minutes_status.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
	elif is_waiting:
		_lbl_minutes_status.text = "BEAT PRÊT ([Espace])"
		_lbl_minutes_status.add_theme_color_override("font_color", Color(0.98, 0.72, 0.24))
	else:
		_lbl_minutes_status.text = "Tour PJ — Case bleue (PM) ou Action [1–9]"
		_lbl_minutes_status.add_theme_color_override("font_color", Color(0.70, 0.88, 0.74))

	var bark_txt: String = _bark_override_text
	if bark_txt == "":
		var log_var: Variant = _timeline.get("combat_log")
		if log_var is Array and not (log_var as Array).is_empty():
			bark_txt = str((log_var as Array)[(log_var as Array).size() - 1])
	_lbl_bark.text = "▸ " + bark_txt

	var log_arr_var: Variant = _timeline.get("combat_log")
	if log_arr_var is Array:
		var lines: Array[String] = []
		for lv in (log_arr_var as Array):
			lines.append("▸ " + str(lv))
		_lbl_log.text = "\n".join(lines)
		_minutes_scroll.set_deferred("scroll_vertical", 99999)

	_btn_cancel_target.visible = (_pending_kind != "")
	if is_waiting and not is_cw_min and _pending_kind == "":
		_btn_step.disabled = false
		_btn_step.text = "[Espace] %s ▶" % step_lbl
		_btn_step.add_theme_stylebox_override("normal", _make_box(Color(0.46, 0.18, 0.10), Color(0.98, 0.72, 0.24), 2, 4))
	else:
		_btn_step.disabled = true
		_btn_step.text = "Alerte Charge (10 s) en cours…" if is_cw_min else ("Sélectionne un pion sur la scène…" if _pending_kind != "" else "Case bleue (PM) · Action [1–9] · ⚡")
		_btn_step.add_theme_stylebox_override("normal", _make_box(Color(0.14, 0.14, 0.18), Color(0.36, 0.38, 0.44), 1, 4))

func _make_box(bg: Color, border: Color, bw: int, pad: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_content_margin_all(pad)
	return sb

func _load_texture_safe(res_path: String) -> Texture2D:
	if res_path == "":
		return null
	if _tex_cache.has(res_path):
		var cached: Variant = _tex_cache.get(res_path, null)
		if cached is Texture2D:
			return cached as Texture2D
		return null
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		var loaded: Resource = load(res_path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	if tex == null:
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img: Image = Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_tex_cache[res_path] = tex
	return tex
