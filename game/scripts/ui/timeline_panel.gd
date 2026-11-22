## HUD tactile cinémascope de la Frise Chronologique de Tension (bande magnétique 1982, 1A/2A/3B/4A).
extends Control

var input_blocked: bool = false

var _timeline: Node = null
var _tex_cache: Dictionary = {}

# Bandeau haut : Rail bande magnétique + badges + Journal repliable
var _lbl_header: Label = null
var _lbl_crs: Label = null
var _lbl_escape: Label = null
var _lbl_shield: Label = null
var _btn_journal: Button = null
var _rail_hbox: HBoxContainer = null
var _rail_preview_labels: Dictionary = {}

var _journal_drawer: PanelContainer = null
var _lbl_log: Label = null

# Colonne droite : cartes ennemies cliquables
var _enemies_vbox: VBoxContainer = null
var _enemy_preview_labels: Dictionary = {}

# Bandeau bas-centre : Bark BD 1 ligne + bouton pas-à-pas
var _lbl_bark: Label = null
var _btn_step: Button = null

# Dock bas : 6 portraits alliés + actions 1-4 + prévisualisation survol
var _allies_hbox: HBoxContainer = null
var _lbl_target_banner: Label = null
var _actions_grid: GridContainer = null
var _lbl_preview: Label = null
var _lbl_preview_warn: Label = null

var _crisis_cards: Array[Control] = []
var _current_action_ids: Array[String] = []
var _hover_spec: Dictionary = {}
var _bark_override_text: String = ""
var _anim_time: float = 0.0

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

func _process(delta: float) -> void:
	if not visible:
		return
	_anim_time += delta
	var allow_shake: bool = SettingsManager.screen_shake
	for card in _crisis_cards:
		if is_instance_valid(card):
			card.pivot_offset = card.size * 0.5
			card.rotation = sin(_anim_time * 22.0) * 0.022 if allow_shake else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not visible or input_blocked or _timeline == null or not bool(_timeline.get("active")):
		return
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			var is_waiting: bool = bool(_timeline.get("awaiting_step"))
			if kev.keycode == KEY_SPACE or kev.keycode == KEY_ENTER or kev.keycode == KEY_KP_ENTER:
				if is_waiting:
					_timeline.call("step_next_beat")
					get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_TAB:
				_timeline.call("cycle_target")
				get_viewport().set_input_as_handled()
			elif kev.keycode >= KEY_1 and kev.keycode <= KEY_4:
				if not is_waiting:
					var idx: int = int(kev.keycode - KEY_1)
					if idx >= 0 and idx < _current_action_ids.size():
						_timeline.call("execute_player_action", _current_action_ids[idx])
						get_viewport().set_input_as_handled()

func _build_ui() -> void:
	# 1. Bandeau haut (y=8..116) : Bande magnétique horizontale + compteurs
	var top_panel: PanelContainer = PanelContainer.new()
	top_panel.position = Vector2(10, 8)
	top_panel.size = Vector2(1260, 108)
	top_panel.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.06, 0.08, 0.92), Color(0.95, 0.55, 0.16), 2, 8))
	add_child(top_panel)

	var top_vbox: VBoxContainer = VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 5)
	top_panel.add_child(top_vbox)

	var top_head: HBoxContainer = HBoxContainer.new()
	top_head.add_theme_constant_override("separation", 10)
	top_vbox.add_child(top_head)

	_lbl_header = Label.new()
	_lbl_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_header.add_theme_font_size_override("font_size", 14)
	_lbl_header.add_theme_color_override("font_color", Color(0.96, 0.58, 0.18))
	top_head.add_child(_lbl_header)

	_lbl_shield = Label.new()
	_lbl_shield.add_theme_font_size_override("font_size", 12)
	_lbl_shield.add_theme_color_override("font_color", Color(0.55, 0.88, 0.62))
	top_head.add_child(_lbl_shield)

	_lbl_escape = Label.new()
	_lbl_escape.add_theme_font_size_override("font_size", 12)
	_lbl_escape.add_theme_color_override("font_color", Color(0.96, 0.84, 0.34))
	top_head.add_child(_lbl_escape)

	_lbl_crs = Label.new()
	_lbl_crs.add_theme_font_size_override("font_size", 13)
	_lbl_crs.add_theme_color_override("font_color", Color(0.38, 0.72, 0.98))
	top_head.add_child(_lbl_crs)

	_btn_journal = Button.new()
	_btn_journal.text = "Journal ▸"
	_btn_journal.custom_minimum_size = Vector2(98, 24)
	_btn_journal.focus_mode = Control.FOCUS_NONE
	_btn_journal.pressed.connect(_toggle_journal)
	top_head.add_child(_btn_journal)

	var rail_scroll: ScrollContainer = ScrollContainer.new()
	rail_scroll.custom_minimum_size = Vector2(1240, 68)
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	top_vbox.add_child(rail_scroll)

	_rail_hbox = HBoxContainer.new()
	_rail_hbox.add_theme_constant_override("separation", 6)
	rail_scroll.add_child(_rail_hbox)

	# 2. Tiroir Journal repliable (x=10..470, y=122..406)
	_journal_drawer = PanelContainer.new()
	_journal_drawer.position = Vector2(10, 122)
	_journal_drawer.size = Vector2(460, 284)
	_journal_drawer.visible = false
	_journal_drawer.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.06, 0.08, 0.95), Color(0.45, 0.48, 0.54), 2, 10))
	add_child(_journal_drawer)

	var j_vbox: VBoxContainer = VBoxContainer.new()
	j_vbox.add_theme_constant_override("separation", 6)
	_journal_drawer.add_child(j_vbox)

	var j_head: HBoxContainer = HBoxContainer.new()
	j_vbox.add_child(j_head)

	var j_title: Label = Label.new()
	j_title.text = "JOURNAL DE CONFRONTATION (Fanzine / Radio)"
	j_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	j_title.add_theme_font_size_override("font_size", 12)
	j_title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	j_head.add_child(j_title)

	var btn_j_close: Button = Button.new()
	btn_j_close.text = "✕"
	btn_j_close.custom_minimum_size = Vector2(28, 22)
	btn_j_close.focus_mode = Control.FOCUS_NONE
	btn_j_close.pressed.connect(func() -> void: _journal_drawer.visible = false)
	j_head.add_child(btn_j_close)

	var j_scroll: ScrollContainer = ScrollContainer.new()
	j_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	j_vbox.add_child(j_scroll)

	_lbl_log = Label.new()
	_lbl_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_log.add_theme_font_size_override("font_size", 12)
	_lbl_log.add_theme_color_override("font_color", Color(0.88, 0.87, 0.82))
	j_scroll.add_child(_lbl_log)

	# 3. Colonne droite flottante : Cartes ennemies (x=958..1268, y=124..446)
	var enemies_scroll: ScrollContainer = ScrollContainer.new()
	enemies_scroll.position = Vector2(958, 124)
	enemies_scroll.size = Vector2(310, 322)
	enemies_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	enemies_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	enemies_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(enemies_scroll)

	_enemies_vbox = VBoxContainer.new()
	_enemies_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemies_vbox.add_theme_constant_override("separation", 6)
	enemies_scroll.add_child(_enemies_vbox)

	# 4. Bandeau Bark BD 1 ligne + contrôle pas-à-pas strict (y=442..486)
	var bark_panel: PanelContainer = PanelContainer.new()
	bark_panel.position = Vector2(180, 442)
	bark_panel.size = Vector2(768, 44)
	bark_panel.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.06, 0.08, 0.91), Color(0.86, 0.22, 0.22), 2, 6))
	add_child(bark_panel)

	var bark_hbox: HBoxContainer = HBoxContainer.new()
	bark_hbox.add_theme_constant_override("separation", 10)
	bark_panel.add_child(bark_hbox)

	_lbl_bark = Label.new()
	_lbl_bark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_bark.clip_text = true
	_lbl_bark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_bark.add_theme_font_size_override("font_size", 13)
	_lbl_bark.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	bark_hbox.add_child(_lbl_bark)

	_btn_step = Button.new()
	_btn_step.custom_minimum_size = Vector2(262, 30)
	_btn_step.focus_mode = Control.FOCUS_NONE
	_btn_step.pressed.connect(func() -> void:
		if _timeline != null and bool(_timeline.get("awaiting_step")):
			_timeline.call("step_next_beat")
	)
	bark_hbox.add_child(_btn_step)

	# 5. Dock tactique bas (y=492..712)
	var bottom_panel: PanelContainer = PanelContainer.new()
	bottom_panel.position = Vector2(10, 492)
	bottom_panel.size = Vector2(1260, 220)
	bottom_panel.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.06, 0.08, 0.94), Color(0.85, 0.17, 0.17), 2, 8))
	add_child(bottom_panel)

	var dock_hbox: HBoxContainer = HBoxContainer.new()
	dock_hbox.add_theme_constant_override("separation", 10)
	bottom_panel.add_child(dock_hbox)

	var allies_scroll: ScrollContainer = ScrollContainer.new()
	allies_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	allies_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	allies_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock_hbox.add_child(allies_scroll)

	_allies_hbox = HBoxContainer.new()
	_allies_hbox.add_theme_constant_override("separation", 8)
	allies_scroll.add_child(_allies_hbox)

	var right_actions_col: VBoxContainer = VBoxContainer.new()
	right_actions_col.custom_minimum_size = Vector2(476, 0)
	right_actions_col.add_theme_constant_override("separation", 5)
	dock_hbox.add_child(right_actions_col)

	_lbl_target_banner = Label.new()
	_lbl_target_banner.add_theme_font_size_override("font_size", 12)
	_lbl_target_banner.add_theme_color_override("font_color", Color(0.96, 0.62, 0.22))
	right_actions_col.add_child(_lbl_target_banner)

	_actions_grid = GridContainer.new()
	_actions_grid.columns = 2
	_actions_grid.add_theme_constant_override("h_separation", 6)
	_actions_grid.add_theme_constant_override("v_separation", 5)
	right_actions_col.add_child(_actions_grid)

	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override("panel", _make_box(Color(0.10, 0.10, 0.13, 0.96), Color(0.32, 0.34, 0.40), 1, 6))
	right_actions_col.add_child(preview_panel)

	var pv_vbox: VBoxContainer = VBoxContainer.new()
	pv_vbox.add_theme_constant_override("separation", 2)
	preview_panel.add_child(pv_vbox)

	_lbl_preview = Label.new()
	_lbl_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_preview.add_theme_font_size_override("font_size", 12)
	_lbl_preview.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96))
	pv_vbox.add_child(_lbl_preview)

	_lbl_preview_warn = Label.new()
	_lbl_preview_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_preview_warn.add_theme_font_size_override("font_size", 11)
	_lbl_preview_warn.add_theme_color_override("font_color", Color(1.0, 0.34, 0.34))
	_lbl_preview_warn.visible = false
	pv_vbox.add_child(_lbl_preview_warn)

func _toggle_journal() -> void:
	_journal_drawer.visible = not _journal_drawer.visible
	_btn_journal.text = "Journal ▾" if _journal_drawer.visible else "Journal ▸"

func _on_combat_feedback(event_data: Dictionary) -> void:
	var txt: String = str(event_data.get("text", ""))
	if txt != "":
		_bark_override_text = txt

func _on_encounter_finished(_outcome_id: String, _summary: String) -> void:
	visible = false
	_journal_drawer.visible = false
	_hover_spec = {}
	_bark_override_text = ""

## Reconstruit l'affichage tactique à partir de l'état courant de TensionTimeline.
func refresh() -> void:
	if _timeline == null:
		return
	_hover_spec = {}
	var is_act: bool = bool(_timeline.get("active"))
	visible = is_act
	if not is_act:
		return

	var title_txt: String = str(_timeline.get("encounter_title"))
	var turn_c: int = int(_timeline.get("turn_count"))
	var crs_t: int = int(_timeline.get("crs_ticks"))
	var esc_p: int = int(_timeline.get("escape_progress"))
	var shield_p: int = int(_timeline.get("interposition_shield"))
	var tf_arrived: bool = bool(_timeline.get("train_fantome_arrived"))
	var is_waiting: bool = bool(_timeline.get("awaiting_step"))
	var step_lbl: String = str(_timeline.get("pending_beat_label"))

	_lbl_header.text = "FRISE DE TENSION — %s  (Tour %d)" % [title_txt, turn_c]
	_lbl_shield.text = ("Bouclier x%d" % shield_p) if shield_p > 0 else ""
	_lbl_escape.text = "TRAIN FANTÔME À QUAI !" if tf_arrived else ("Échappée : %d/2" % esc_p)
	_lbl_crs.text = "CRS : %d cran(s)" % maxi(0, crs_t)
	_lbl_crs.add_theme_color_override("font_color", Color(1.0, 0.36, 0.34) if crs_t <= 2 else Color(0.38, 0.72, 0.98))

	_rebuild_rail()
	_rebuild_enemy_cards()
	_rebuild_ally_cards()
	_rebuild_actions(is_waiting)
	_refresh_bark_and_step(is_waiting, step_lbl)
	_refresh_journal()
	_apply_preview_visuals()

func _rebuild_rail() -> void:
	for c in _rail_hbox.get_children():
		c.queue_free()
	_rail_preview_labels.clear()

	var entries_var: Variant = _timeline.call("get_ordered_rail_entries")
	if not (entries_var is Array):
		return
	for ed_var in (entries_var as Array):
		if not (ed_var is Dictionary):
			continue
		var ed: Dictionary = ed_var as Dictionary
		var kind: String = str(ed.get("kind", ""))
		var eid: String = str(ed.get("id", ""))
		var tick_v: int = int(ed.get("tick", 0))
		var col: Color = Color.html(str(ed.get("color", "#f28c28")))
		var is_sel: bool = bool(ed.get("selected", false))
		var is_acting: bool = bool(ed.get("acting", false))

		var token_btn: Button = Button.new()
		token_btn.custom_minimum_size = Vector2(144, 62)
		token_btn.clip_text = true
		token_btn.focus_mode = Control.FOCUS_NONE
		var border_col: Color = Color(1.0, 0.84, 0.25) if (is_sel or is_acting) else col
		var bw: int = 3 if (is_sel or is_acting) else (2 if tick_v == 0 else 1)
		var bg_col: Color = Color(0.24, 0.16, 0.10) if tick_v == 0 else Color(0.12, 0.12, 0.15)
		token_btn.add_theme_stylebox_override("normal", _make_box(bg_col, border_col, bw, 4))
		token_btn.add_theme_stylebox_override("hover", _make_box(bg_col.lightened(0.08), Color(1.0, 0.85, 0.35), bw, 4))
		token_btn.add_theme_stylebox_override("disabled", _make_box(bg_col, border_col, bw, 4))
		token_btn.disabled = (kind != "enemy")
		if kind == "enemy":
			var eid_cap: String = eid
			token_btn.pressed.connect(func() -> void: _timeline.call("select_target", eid_cap))

		var inner: HBoxContainer = HBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 6
		inner.offset_top = 4
		inner.offset_right = -6
		inner.offset_bottom = -4
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 5)
		token_btn.add_child(inner)

		var tex: Texture2D = _load_texture_safe(str(ed.get("portrait", "")))
		if tex != null:
			var tr: TextureRect = TextureRect.new()
			tr.custom_minimum_size = Vector2(36, 48)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.texture = tex
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(tr)

		var tv: VBoxContainer = VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_theme_constant_override("separation", 0)
		inner.add_child(tv)

		var lt: Label = Label.new()
		var mark: String = " [CIBLE]" if is_sel else (" [AGIT]" if is_acting else "")
		lt.text = "Cran %d%s" % [tick_v, mark]
		lt.add_theme_font_size_override("font_size", 10)
		lt.add_theme_color_override("font_color", col)
		lt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(lt)

		var ln: Label = Label.new()
		ln.text = str(ed.get("label", ""))
		ln.clip_text = true
		ln.add_theme_font_size_override("font_size", 11)
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(ln)

		var ls: Label = Label.new()
		ls.text = str(ed.get("sub", ""))
		ls.add_theme_font_size_override("font_size", 10)
		ls.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))
		ls.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(ls)

		var l_pv: Label = Label.new()
		l_pv.visible = false
		l_pv.add_theme_font_size_override("font_size", 10)
		l_pv.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
		l_pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(l_pv)
		_rail_preview_labels[eid] = l_pv

		_rail_hbox.add_child(token_btn)

func _rebuild_enemy_cards() -> void:
	for c in _enemies_vbox.get_children():
		c.queue_free()
	_enemy_preview_labels.clear()

	var enemies_var: Variant = _timeline.get("enemies")
	if not (enemies_var is Array):
		return
	var sel_id: String = str(_timeline.get("selected_target_id"))
	for ev in (enemies_var as Array):
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var eid: String = str(e.get("id", ""))
		var is_defeated: bool = bool(e.get("defeated", false))
		var is_sel: bool = (eid == sel_id and not is_defeated)
		var res: int = int(e.get("resolve", 0))
		var res_max: int = maxi(1, int(e.get("resolve_max", 3)))
		var counter_on: bool = (not is_defeated) and bool(e.get("counter_ready", false))

		var card_btn: Button = Button.new()
		card_btn.custom_minimum_size = Vector2(294, 60 if is_defeated else 98)
		card_btn.disabled = is_defeated
		card_btn.focus_mode = Control.FOCUS_NONE
		var b_col: Color = Color(1.0, 0.72, 0.18) if is_sel else (Color(0.32, 0.34, 0.38) if is_defeated else Color(0.84, 0.22, 0.22))
		var bg_c: Color = Color(0.16, 0.11, 0.09, 0.94) if is_sel else (Color(0.08, 0.08, 0.10, 0.68) if is_defeated else Color(0.08, 0.08, 0.11, 0.90))
		card_btn.add_theme_stylebox_override("normal", _make_box(bg_c, b_col, 3 if is_sel else 1, 7))
		card_btn.add_theme_stylebox_override("hover", _make_box(bg_c.lightened(0.07), Color(1.0, 0.85, 0.35), 2, 7))
		card_btn.add_theme_stylebox_override("disabled", _make_box(bg_c, b_col, 1, 7))
		if not is_defeated:
			var eid_cap: String = eid
			card_btn.pressed.connect(func() -> void: _timeline.call("select_target", eid_cap))

		var row: HBoxContainer = HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 7
		row.offset_top = 5
		row.offset_right = -7
		row.offset_bottom = -5
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		card_btn.add_child(row)

		var tr: TextureRect = TextureRect.new()
		tr.custom_minimum_size = Vector2(46, 54)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture = _load_texture_safe(str(e.get("portrait", "res://assets/portraits/so_agent.png")))
		tr.modulate = Color(0.45, 0.45, 0.45) if is_defeated else Color.WHITE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)

		var col_v: VBoxContainer = VBoxContainer.new()
		col_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col_v.add_theme_constant_override("separation", 2)
		row.add_child(col_v)

		var head_r: HBoxContainer = HBoxContainer.new()
		head_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col_v.add_child(head_r)

		var lbl_n: Label = Label.new()
		lbl_n.text = str(e.get("name", eid)) + (" [HORS JEU]" if is_defeated else (" [CIBLE]" if is_sel else ""))
		lbl_n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_n.clip_text = true
		lbl_n.add_theme_font_size_override("font_size", 12)
		lbl_n.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34) if is_sel else Color(0.95, 0.92, 0.88))
		lbl_n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head_r.add_child(lbl_n)

		if not is_defeated:
			var lbl_tk: Label = Label.new()
			lbl_tk.text = "Cran %d" % int(e.get("next_tick", 0))
			lbl_tk.add_theme_font_size_override("font_size", 11)
			lbl_tk.add_theme_color_override("font_color", Color(0.96, 0.44, 0.40))
			lbl_tk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			head_r.add_child(lbl_tk)

		# Jauge de Résolution segmentée
		var pips: HBoxContainer = HBoxContainer.new()
		pips.add_theme_constant_override("separation", 3)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col_v.add_child(pips)
		for idx_p in range(res_max):
			var pip: ColorRect = ColorRect.new()
			pip.custom_minimum_size = Vector2(22, 7)
			pip.color = Color(0.88, 0.24, 0.22) if idx_p < res else Color(0.22, 0.22, 0.26)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips.add_child(pip)
		var res_lbl: Label = Label.new()
		res_lbl.text = "Rés. %d/%d" % [res, res_max]
		res_lbl.add_theme_font_size_override("font_size", 10)
		res_lbl.add_theme_color_override("font_color", Color(0.84, 0.84, 0.86))
		res_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(res_lbl)

		if not is_defeated:
			var lbl_int: Label = Label.new()
			lbl_int.text = str(e.get("intent_label", ""))
			lbl_int.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl_int.clip_text = true
			lbl_int.custom_minimum_size = Vector2(0, 26)
			lbl_int.add_theme_font_size_override("font_size", 10)
			lbl_int.add_theme_color_override("font_color", Color(0.76, 0.78, 0.84))
			lbl_int.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col_v.add_child(lbl_int)

			if counter_on:
				var lbl_ctr: Label = Label.new()
				lbl_ctr.text = "⚠ " + str(e.get("counter_label", "Contre-interruption prête"))
				lbl_ctr.clip_text = true
				lbl_ctr.add_theme_font_size_override("font_size", 10)
				lbl_ctr.add_theme_color_override("font_color", Color(1.0, 0.34, 0.34))
				lbl_ctr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				col_v.add_child(lbl_ctr)

			var lbl_epv: Label = Label.new()
			lbl_epv.visible = false
			lbl_epv.add_theme_font_size_override("font_size", 10)
			lbl_epv.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))
			lbl_epv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col_v.add_child(lbl_epv)
			_enemy_preview_labels[eid] = lbl_epv

		_enemies_vbox.add_child(card_btn)

func _rebuild_ally_cards() -> void:
	for c in _allies_hbox.get_children():
		c.queue_free()
	_crisis_cards.clear()

	var allies_var: Variant = _timeline.get("allies")
	if not (allies_var is Array):
		return
	var acting_var: Variant = _timeline.call("get_acting_ally")
	var acting_id: String = str((acting_var as Dictionary).get("char_id", "")) if acting_var is Dictionary else ""
	var is_waiting: bool = bool(_timeline.get("awaiting_step"))

	# Index des crises actives par char_id
	var crisis_map: Dictionary = {}
	var cr_q_var: Variant = _timeline.get("crisis_queue")
	if cr_q_var is Array:
		for crv in (cr_q_var as Array):
			if crv is Dictionary:
				var crd: Dictionary = crv as Dictionary
				crisis_map[str(crd.get("char_id", ""))] = crd

	for alv in (allies_var as Array):
		if not (alv is Dictionary):
			continue
		var al: Dictionary = alv as Dictionary
		var cid: String = str(al.get("char_id", ""))
		var present: bool = bool(al.get("present", false))
		var r_ready: bool = bool(al.get("reaction_ready", false))
		var is_acting: bool = (cid == acting_id and present and not is_waiting)
		var in_crisis: bool = crisis_map.has(cid)
		var cdef: Dictionary = DataLoader.get_character(cid)
		var st: Dictionary = GameState.get_member_state(cid)
		var moral: int = int(st.get("moral", 60))
		var moral_max: int = maxi(1, int(st.get("moral_max", 100)))
		var threshold: int = int(cdef.get("stress_threshold", 35))
		var col_char: Color = Color.html(str(al.get("color_hex", "#f28c28")))

		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(142, 198)
		var border_col: Color = Color(1.0, 0.22, 0.22) if in_crisis else (Color(0.98, 0.72, 0.24) if is_acting else (col_char if present else Color(0.32, 0.34, 0.38)))
		var bg_col: Color = Color(0.26, 0.08, 0.09, 0.96) if in_crisis else (Color(0.16, 0.13, 0.09, 0.96) if is_acting else Color(0.10, 0.10, 0.13, 0.94))
		card.add_theme_stylebox_override("panel", _make_box(bg_col, border_col, 3 if (in_crisis or is_acting) else 1, 6))
		if in_crisis:
			_crisis_cards.append(card)

		var cv: VBoxContainer = VBoxContainer.new()
		cv.add_theme_constant_override("separation", 3)
		card.add_child(cv)

		var top_r: HBoxContainer = HBoxContainer.new()
		top_r.add_theme_constant_override("separation", 5)
		cv.add_child(top_r)

		var ptex: TextureRect = TextureRect.new()
		ptex.custom_minimum_size = Vector2(44, 48)
		ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		ptex.texture = _load_texture_safe(str(cdef.get("portrait", "")))
		ptex.modulate = Color.WHITE if present else Color(0.55, 0.55, 0.62)
		top_r.add_child(ptex)

		var nv: VBoxContainer = VBoxContainer.new()
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_theme_constant_override("separation", 1)
		top_r.add_child(nv)

		var l_name: Label = Label.new()
		l_name.text = str(al.get("name", cid)).split(" ")[0]
		l_name.clip_text = true
		l_name.add_theme_font_size_override("font_size", 12)
		l_name.add_theme_color_override("font_color", Color.WHITE if present else Color(0.68, 0.72, 0.78))
		nv.add_child(l_name)

		var l_tag: Label = Label.new()
		l_tag.text = "CRISE !" if in_crisis else ("EN TOUR" if is_acting else ("Cran %d" % int(al.get("next_tick", 0)) if present else ("Renf. %d" % int(al.get("reinforce_in_ticks", 2)))))
		l_tag.add_theme_font_size_override("font_size", 10)
		l_tag.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42) if in_crisis else (Color(1.0, 0.80, 0.30) if is_acting else Color(0.68, 0.82, 0.92)))
		nv.add_child(l_tag)

		# Moral + Stress
		var l_moral: Label = Label.new()
		l_moral.text = "Moral %d/%d (Seuil %d)" % [moral, moral_max, threshold]
		l_moral.add_theme_font_size_override("font_size", 10)
		l_moral.add_theme_color_override("font_color", Color(1.0, 0.54, 0.50) if moral <= threshold + 6 else Color(0.84, 0.88, 0.86))
		cv.add_child(l_moral)

		var bar: ProgressBar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 7)
		bar.max_value = moral_max
		bar.value = moral
		bar.show_percentage = false
		cv.add_child(bar)

		# Bouton Interruption sous le portrait
		var btn_int: Button = Button.new()
		btn_int.custom_minimum_size = Vector2(0, 28)
		btn_int.clip_text = true
		btn_int.focus_mode = Control.FOCUS_NONE
		var sp_name: String = str(al.get("specialty_name", "Interrupt."))
		btn_int.text = ("⚡ " + sp_name) if (present and r_ready) else ("[%s]" % ("Utilisée" if present else "Absent"))
		btn_int.disabled = not (present and r_ready)
		var cid_cap: String = cid
		btn_int.pressed.connect(func() -> void: _timeline.call("trigger_interruption", cid_cap))
		btn_int.mouse_entered.connect(func() -> void: _set_hover_spec({"kind": "interrupt", "id": cid_cap}))
		btn_int.mouse_exited.connect(func() -> void: _clear_hover_spec())
		cv.add_child(btn_int)

		# Bouton Retenir intégré en cas de Crise d'autonomie
		if in_crisis:
			var cr_d: Dictionary = crisis_map[cid] as Dictionary
			var tl_cr: int = int(cr_d.get("ticks_left", 0))
			var btn_ret: Button = Button.new()
			btn_ret.custom_minimum_size = Vector2(0, 30)
			btn_ret.focus_mode = Control.FOCUS_NONE
			btn_ret.text = "🛡 Retenir (%dc)" % tl_cr
			btn_ret.disabled = not bool(_timeline.call("has_restrain_reaction_for", cid_cap))
			btn_ret.add_theme_stylebox_override("normal", _make_box(Color(0.55, 0.14, 0.14), Color(1.0, 0.52, 0.34), 2, 4))
			btn_ret.pressed.connect(func() -> void: _timeline.call("restrain_crisis", cid_cap))
			btn_ret.mouse_entered.connect(func() -> void: _set_hover_spec({"kind": "restrain", "id": cid_cap}))
			btn_ret.mouse_exited.connect(func() -> void: _clear_hover_spec())
			cv.add_child(btn_ret)

		_allies_hbox.add_child(card)

func _rebuild_actions(is_waiting: bool) -> void:
	for c in _actions_grid.get_children():
		c.queue_free()
	_current_action_ids.clear()

	var actor_var: Variant = _timeline.call("get_acting_ally")
	var actor: Dictionary = actor_var as Dictionary if actor_var is Dictionary else {}
	var actor_name: String = str(actor.get("name", "Bande")).split(" ")[0]
	var tgt_var: Variant = _timeline.call("get_selected_target")
	var tgt_name: String = str((tgt_var as Dictionary).get("name", "Aucune")) if tgt_var is Dictionary else "Aucune"

	_lbl_target_banner.text = "Cible : %s [Tab]  |  Actions %s [1–4] :" % [tgt_name, actor_name]

	var enc: Dictionary = DataLoader.get_encounter(str(_timeline.get("encounter_id")))
	var act_list_var: Variant = enc.get("player_actions", [])
	var slot_num: int = 1
	if act_list_var is Array:
		for av in (act_list_var as Array):
			if not (av is Dictionary):
				continue
			var ad: Dictionary = av as Dictionary
			var aid: String = str(ad.get("id", ""))
			_current_action_ids.append(aid)
			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(228, 34)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.clip_text = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.disabled = is_waiting or actor.is_empty()
			btn.text = "[%d] %s" % [slot_num, str(ad.get("label", aid))]
			var aid_cap: String = aid
			btn.pressed.connect(func() -> void: _timeline.call("execute_player_action", aid_cap))
			btn.mouse_entered.connect(func() -> void: _set_hover_spec({"kind": "action", "id": aid_cap}))
			btn.mouse_exited.connect(func() -> void: _clear_hover_spec())
			_actions_grid.add_child(btn)
			slot_num += 1

	if bool(_timeline.call("can_escape_now")):
		_current_action_ids.append("act_escape_now")
		var btn_esc: Button = Button.new()
		btn_esc.custom_minimum_size = Vector2(228, 34)
		btn_esc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_esc.clip_text = true
		btn_esc.focus_mode = Control.FOCUS_NONE
		btn_esc.disabled = is_waiting or actor.is_empty()
		btn_esc.text = "[%d] Filer par le Quai !" % slot_num
		btn_esc.add_theme_stylebox_override("normal", _make_box(Color(0.28, 0.20, 0.07), Color(0.98, 0.78, 0.26), 2, 4))
		btn_esc.pressed.connect(func() -> void: _timeline.call("execute_player_action", "act_escape_now"))
		btn_esc.mouse_entered.connect(func() -> void: _set_hover_spec({"kind": "action", "id": "act_escape_now"}))
		btn_esc.mouse_exited.connect(func() -> void: _clear_hover_spec())
		_actions_grid.add_child(btn_esc)

func _refresh_bark_and_step(is_waiting: bool, step_lbl: String) -> void:
	var bark_txt: String = _bark_override_text
	if bark_txt == "":
		var log_var: Variant = _timeline.get("combat_log")
		if log_var is Array and not (log_var as Array).is_empty():
			bark_txt = str((log_var as Array)[(log_var as Array).size() - 1])
	_lbl_bark.text = "▸ " + bark_txt

	if is_waiting:
		_btn_step.disabled = false
		_btn_step.text = "[Espace] %s ▶" % step_lbl
		_btn_step.add_theme_stylebox_override("normal", _make_box(Color(0.46, 0.18, 0.10), Color(0.98, 0.72, 0.24), 2, 4))
	else:
		_btn_step.disabled = true
		var act_v: Variant = _timeline.call("get_acting_ally")
		var a_name: String = str((act_v as Dictionary).get("name", "Bande")).split(" ")[0] if act_v is Dictionary else "Bande"
		_btn_step.text = "Tour de %s [1–4]" % a_name
		_btn_step.add_theme_stylebox_override("normal", _make_box(Color(0.14, 0.14, 0.18), Color(0.36, 0.38, 0.44), 1, 4))

func _refresh_journal() -> void:
	var log_var: Variant = _timeline.get("combat_log")
	if log_var is Array:
		var lines: Array[String] = []
		for lv in (log_var as Array):
			lines.append("▸ " + str(lv))
		_lbl_log.text = "\n".join(lines)

func _set_hover_spec(spec: Dictionary) -> void:
	_hover_spec = spec
	_apply_preview_visuals()

func _clear_hover_spec() -> void:
	_hover_spec = {}
	_apply_preview_visuals()

func _apply_preview_visuals() -> void:
	for k in _rail_preview_labels.keys():
		var lbl_r: Label = _rail_preview_labels[k] as Label
		if is_instance_valid(lbl_r):
			lbl_r.visible = false
	for k2 in _enemy_preview_labels.keys():
		var lbl_e: Label = _enemy_preview_labels[k2] as Label
		if is_instance_valid(lbl_e):
			lbl_e.visible = false

	_lbl_preview_warn.visible = false
	if _hover_spec.is_empty() or _timeline == null:
		_lbl_preview.text = "Survole une action [1–4], ⚡ Interruption ou 🛡 Retenir pour prévisualiser Crans & Contre-interruptions."
		return

	var pv_var: Variant = null
	var kind: String = str(_hover_spec.get("kind", ""))
	var item_id: String = str(_hover_spec.get("id", ""))
	if kind == "action":
		pv_var = _timeline.call("preview_player_action", item_id)
	elif kind == "interrupt":
		pv_var = _timeline.call("preview_interruption", item_id)
	elif kind == "restrain":
		pv_var = _timeline.call("preview_restrain", item_id)

	if not (pv_var is Dictionary):
		return
	var pv: Dictionary = pv_var as Dictionary
	if not bool(pv.get("valid", false)):
		_lbl_preview.text = "Indisponible : %s" % str(pv.get("reason", ""))
		return

	_lbl_preview.text = "%s — %s" % [str(pv.get("title", "")), str(pv.get("summary", ""))]
	if bool(pv.get("counter_warning", false)):
		_lbl_preview_warn.visible = true
		_lbl_preview_warn.text = "⚠ CONTRE-INTERRUPTION : %s (-6 Moral !)" % str(pv.get("counter_label", ""))

	var tid: String = str(pv.get("target_id", ""))
	var from_t: int = int(pv.get("from_tick", 0))
	var to_t: int = int(pv.get("to_tick", 0))
	var res_d: int = int(pv.get("resolve_delta", 0))

	if _rail_preview_labels.has(tid):
		var rl: Label = _rail_preview_labels[tid] as Label
		if is_instance_valid(rl):
			var parts: Array[String] = []
			if res_d < 0:
				parts.append("%d Rés." % res_d)
			if to_t != from_t:
				parts.append("Cran %d→%d" % [from_t, to_t])
			if kind == "restrain":
				parts.append("ANNULÉE")
			rl.text = " | ".join(parts) if not parts.is_empty() else "IMPACT"
			rl.visible = true

	if _enemy_preview_labels.has(tid):
		var el: Label = _enemy_preview_labels[tid] as Label
		if is_instance_valid(el):
			el.text = "Aperçu : %s" % str(pv.get("summary", ""))
			el.visible = true

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
