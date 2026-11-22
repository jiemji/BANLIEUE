## HUD unifié « Option A : Frise-Cartes Unifiée » de la Frise Chronologique de Tension (1280×720).
extends Control

var input_blocked: bool = false

var _timeline: Node = null
var _tex_cache: Dictionary = {}

# Barre d'état haute ultra-fine + tiroir Journal repliable
var _lbl_header: Label = null
var _lbl_shield: Label = null
var _lbl_escape: Label = null
var _lbl_crs: Label = null
var _btn_journal: Button = null
var _journal_drawer: PanelContainer = null
var _lbl_log: Label = null

# Bandeau Bark BD 1 ligne + contrôle pas-à-pas strict
var _lbl_bark: Label = null
var _btn_step: Button = null

# Espace dédié Timeline (Frise-Cartes Unifiée)
var _rail_hbox: HBoxContainer = null
var _rail_preview_labels: Dictionary = {}

# Espace dédié Actions dans le timing de la Frise + Prévisualisation survol
var _lbl_target_banner: Label = null
var _actions_hbox: HBoxContainer = null
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
	# 1. Barre d'état haute ultra-fine (y=8..44) : libère toute la scène isométrique dessous
	var top_bar: PanelContainer = PanelContainer.new()
	top_bar.position = Vector2(10, 8)
	top_bar.size = Vector2(1260, 36)
	top_bar.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.06, 0.08, 0.90), Color(0.95, 0.55, 0.16), 1, 5))
	add_child(top_bar)

	var top_head: HBoxContainer = HBoxContainer.new()
	top_head.add_theme_constant_override("separation", 14)
	top_bar.add_child(top_head)

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
	_btn_journal.custom_minimum_size = Vector2(96, 24)
	_btn_journal.focus_mode = Control.FOCUS_NONE
	_btn_journal.pressed.connect(_toggle_journal)
	top_head.add_child(_btn_journal)

	# 2. Tiroir Journal repliable (x=10..470, y=50..370)
	_journal_drawer = PanelContainer.new()
	_journal_drawer.position = Vector2(10, 50)
	_journal_drawer.size = Vector2(460, 320)
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

	# 3. Bandeau Bark BD 1 ligne + contrôle pas-à-pas strict (y=396..438)
	var bark_panel: PanelContainer = PanelContainer.new()
	bark_panel.position = Vector2(10, 396)
	bark_panel.size = Vector2(1260, 42)
	bark_panel.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.06, 0.08, 0.91), Color(0.86, 0.22, 0.22), 2, 5))
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
	_btn_step.custom_minimum_size = Vector2(280, 28)
	_btn_step.focus_mode = Control.FOCUS_NONE
	_btn_step.pressed.connect(func() -> void:
		if _timeline != null and bool(_timeline.get("awaiting_step")):
			_timeline.call("step_next_beat")
	)
	bark_hbox.add_child(_btn_step)

	# 4. Espace dédié Timeline — Frise-Cartes Unifiée (y=444..614)
	var timeline_panel: PanelContainer = PanelContainer.new()
	timeline_panel.position = Vector2(10, 444)
	timeline_panel.size = Vector2(1260, 170)
	timeline_panel.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.06, 0.08, 0.94), Color(0.95, 0.55, 0.16), 2, 6))
	add_child(timeline_panel)

	var tl_vbox: VBoxContainer = VBoxContainer.new()
	tl_vbox.add_theme_constant_override("separation", 4)
	timeline_panel.add_child(tl_vbox)

	var chrono_guide: Label = Label.new()
	chrono_guide.text = "◄ MAINTENANT (Cran 0)  ───  FRISE-CARTES UNIFIÉE (clic ennemi = cible · ⚡ / 🛡 = actions hors-frise)  ───  CRANS SUIVANTS ►"
	chrono_guide.add_theme_font_size_override("font_size", 11)
	chrono_guide.add_theme_color_override("font_color", Color(0.76, 0.78, 0.84))
	tl_vbox.add_child(chrono_guide)

	var rail_scroll: ScrollContainer = ScrollContainer.new()
	rail_scroll.custom_minimum_size = Vector2(1244, 138)
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tl_vbox.add_child(rail_scroll)

	_rail_hbox = HBoxContainer.new()
	_rail_hbox.add_theme_constant_override("separation", 8)
	rail_scroll.add_child(_rail_hbox)

	# 5. Espace dédié Actions dans le timing de la Frise (y=620..712)
	var actions_panel: PanelContainer = PanelContainer.new()
	actions_panel.position = Vector2(10, 620)
	actions_panel.size = Vector2(1260, 92)
	actions_panel.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.06, 0.08, 0.95), Color(0.85, 0.17, 0.17), 2, 8))
	add_child(actions_panel)

	var act_row: HBoxContainer = HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 12)
	actions_panel.add_child(act_row)

	var act_left: VBoxContainer = VBoxContainer.new()
	act_left.custom_minimum_size = Vector2(780, 0)
	act_left.add_theme_constant_override("separation", 5)
	act_row.add_child(act_left)

	_lbl_target_banner = Label.new()
	_lbl_target_banner.add_theme_font_size_override("font_size", 12)
	_lbl_target_banner.add_theme_color_override("font_color", Color(0.96, 0.62, 0.22))
	act_left.add_child(_lbl_target_banner)

	_actions_hbox = HBoxContainer.new()
	_actions_hbox.add_theme_constant_override("separation", 8)
	act_left.add_child(_actions_hbox)

	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override("panel", _make_box(Color(0.10, 0.10, 0.13, 0.96), Color(0.32, 0.34, 0.40), 1, 6))
	act_row.add_child(preview_panel)

	var pv_vbox: VBoxContainer = VBoxContainer.new()
	pv_vbox.add_theme_constant_override("separation", 2)
	preview_panel.add_child(pv_vbox)

	_lbl_preview = Label.new()
	_lbl_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_preview.add_theme_font_size_override("font_size", 11)
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

## Reconstruit la Frise-Cartes Unifiée et la barre d'actions selon TensionTimeline.
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

	_rebuild_unified_rail()
	_rebuild_actions(is_waiting)
	_refresh_bark_and_step(is_waiting, step_lbl)
	_refresh_journal()
	_apply_preview_visuals()

func _rebuild_unified_rail() -> void:
	for c in _rail_hbox.get_children():
		c.queue_free()
	_rail_preview_labels.clear()
	_crisis_cards.clear()

	var entries_var: Variant = _timeline.call("get_ordered_rail_entries")
	if not (entries_var is Array):
		return
	for ed_var in (entries_var as Array):
		if not (ed_var is Dictionary):
			continue
		var ed: Dictionary = ed_var as Dictionary
		var kind: String = str(ed.get("kind", ""))
		if kind == "ally":
			_rail_hbox.add_child(_build_ally_card(ed))
		elif kind == "reinforcement":
			_rail_hbox.add_child(_build_reinforcement_card(ed))
		elif kind == "enemy":
			_rail_hbox.add_child(_build_enemy_card(ed))
		elif kind == "crs":
			_rail_hbox.add_child(_build_crs_card(ed))

func _build_ally_card(ed: Dictionary) -> Control:
	var cid: String = str(ed.get("id", ""))
	var tick_v: int = int(ed.get("tick", 0))
	var turn_t: int = int(ed.get("turn_tick", tick_v))
	var in_crisis: bool = bool(ed.get("in_crisis", false))
	var is_acting: bool = bool(ed.get("acting", false))
	var r_ready: bool = bool(ed.get("reaction_ready", false))
	var cr_ticks: int = int(ed.get("crisis_ticks", 0))
	var col_char: Color = Color.html(str(ed.get("color", "#f28c28")))

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(204 if in_crisis else 192, 130)
	var border_col: Color = Color(1.0, 0.24, 0.24) if in_crisis else (Color(0.98, 0.78, 0.26) if is_acting else col_char)
	var bg_col: Color = Color(0.24, 0.08, 0.09, 0.96) if in_crisis else (Color(0.18, 0.14, 0.09, 0.96) if is_acting else Color(0.10, 0.11, 0.14, 0.94))
	card.add_theme_stylebox_override("panel", _make_box(bg_col, border_col, 3 if (in_crisis or is_acting) else 1, 5))
	if in_crisis:
		_crisis_cards.append(card)

	var cv: VBoxContainer = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	card.add_child(cv)

	var head_r: HBoxContainer = HBoxContainer.new()
	cv.add_child(head_r)

	var l_tick: Label = Label.new()
	l_tick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if in_crisis:
		l_tick.text = "🔥 CRISE +%dc" % maxi(0, cr_ticks)
		l_tick.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
	elif is_acting:
		l_tick.text = "MAINTENANT · AGIT"
		l_tick.add_theme_color_override("font_color", Color(1.0, 0.84, 0.30))
	else:
		l_tick.text = "CRAN +%d" % turn_t
		l_tick.add_theme_color_override("font_color", col_char)
	l_tick.add_theme_font_size_override("font_size", 10)
	head_r.add_child(l_tick)

	var l_react: Label = Label.new()
	l_react.text = "⚡ PRÊT" if r_ready else ""
	l_react.add_theme_font_size_override("font_size", 9)
	l_react.add_theme_color_override("font_color", Color(0.42, 0.78, 0.98))
	head_r.add_child(l_react)

	var mid_r: HBoxContainer = HBoxContainer.new()
	mid_r.add_theme_constant_override("separation", 6)
	cv.add_child(mid_r)

	var ptex: TextureRect = TextureRect.new()
	ptex.custom_minimum_size = Vector2(44, 52)
	ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ptex.texture = _load_texture_safe(str(ed.get("portrait", "")))
	mid_r.add_child(ptex)

	var info_v: VBoxContainer = VBoxContainer.new()
	info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_v.add_theme_constant_override("separation", 1)
	mid_r.add_child(info_v)

	var l_name: Label = Label.new()
	l_name.text = str(ed.get("label", cid))
	l_name.clip_text = true
	l_name.add_theme_font_size_override("font_size", 12)
	l_name.add_theme_color_override("font_color", Color.WHITE)
	info_v.add_child(l_name)

	var moral_v: int = int(ed.get("moral", 60))
	var moral_m: int = maxi(1, int(ed.get("moral_max", 100)))
	var thr_v: int = int(ed.get("stress_threshold", 35))
	var l_moral: Label = Label.new()
	l_moral.text = "Mor %d/%d (S.%d)" % [moral_v, moral_m, thr_v]
	l_moral.add_theme_font_size_override("font_size", 10)
	l_moral.add_theme_color_override("font_color", Color(1.0, 0.54, 0.50) if moral_v <= thr_v + 6 else Color(0.84, 0.88, 0.86))
	info_v.add_child(l_moral)

	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.max_value = moral_m
	bar.value = moral_v
	bar.show_percentage = false
	info_v.add_child(bar)

	var l_stats: Label = Label.new()
	l_stats.text = "Att. %d · Aura %d" % [int(ed.get("attitude", 60)), int(ed.get("aura", 3))]
	l_stats.add_theme_font_size_override("font_size", 10)
	l_stats.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74))
	info_v.add_child(l_stats)

	# Actions hors-frise directement sur la fiche
	var foot_r: HBoxContainer = HBoxContainer.new()
	foot_r.add_theme_constant_override("separation", 4)
	cv.add_child(foot_r)

	var btn_int: Button = Button.new()
	btn_int.custom_minimum_size = Vector2(0, 26)
	btn_int.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_int.clip_text = true
	btn_int.focus_mode = Control.FOCUS_NONE
	var sp_name: String = str(ed.get("specialty_name", "Interrupt."))
	btn_int.text = ("⚡ " + sp_name) if r_ready else "[Utilisée]"
	btn_int.disabled = not r_ready
	btn_int.add_theme_font_size_override("font_size", 10)
	var cid_cap: String = cid
	btn_int.pressed.connect(func() -> void: _timeline.call("trigger_interruption", cid_cap))
	btn_int.mouse_entered.connect(func() -> void: _set_hover_spec({"kind": "interrupt", "id": cid_cap}))
	btn_int.mouse_exited.connect(func() -> void: _clear_hover_spec())
	foot_r.add_child(btn_int)

	if in_crisis:
		var btn_ret: Button = Button.new()
		btn_ret.custom_minimum_size = Vector2(74, 26)
		btn_ret.focus_mode = Control.FOCUS_NONE
		btn_ret.text = "🛡 Retenir"
		btn_ret.add_theme_font_size_override("font_size", 10)
		btn_ret.disabled = not bool(_timeline.call("has_restrain_reaction_for", cid_cap))
		btn_ret.add_theme_stylebox_override("normal", _make_box(Color(0.55, 0.14, 0.14), Color(1.0, 0.52, 0.34), 2, 3))
		btn_ret.pressed.connect(func() -> void: _timeline.call("restrain_crisis", cid_cap))
		btn_ret.mouse_entered.connect(func() -> void: _set_hover_spec({"kind": "restrain", "id": cid_cap}))
		btn_ret.mouse_exited.connect(func() -> void: _clear_hover_spec())
		foot_r.add_child(btn_ret)

	var l_pv: Label = Label.new()
	l_pv.visible = false
	l_pv.add_theme_font_size_override("font_size", 9)
	l_pv.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	cv.add_child(l_pv)
	_rail_preview_labels[cid] = l_pv

	return card

func _build_reinforcement_card(ed: Dictionary) -> Control:
	var cid: String = str(ed.get("id", ""))
	var tick_v: int = int(ed.get("tick", 2))
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(158, 130)
	card.add_theme_stylebox_override("panel", _make_box(Color(0.09, 0.11, 0.14, 0.88), Color(0.42, 0.64, 0.72), 1, 5))

	var cv: VBoxContainer = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 3)
	card.add_child(cv)

	var l_tick: Label = Label.new()
	l_tick.text = "RENFORT +%d cran(s)" % tick_v
	l_tick.add_theme_font_size_override("font_size", 10)
	l_tick.add_theme_color_override("font_color", Color(0.52, 0.82, 0.90))
	cv.add_child(l_tick)

	var mid_r: HBoxContainer = HBoxContainer.new()
	mid_r.add_theme_constant_override("separation", 6)
	cv.add_child(mid_r)

	var ptex: TextureRect = TextureRect.new()
	ptex.custom_minimum_size = Vector2(40, 48)
	ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ptex.modulate = Color(0.68, 0.74, 0.82)
	ptex.texture = _load_texture_safe(str(ed.get("portrait", "")))
	mid_r.add_child(ptex)

	var iv: VBoxContainer = VBoxContainer.new()
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.add_theme_constant_override("separation", 1)
	mid_r.add_child(iv)

	var l_name: Label = Label.new()
	l_name.text = str(ed.get("label", cid))
	l_name.clip_text = true
	l_name.add_theme_font_size_override("font_size", 11)
	iv.add_child(l_name)

	var l_st: Label = Label.new()
	l_st.text = "Att. %d · Aura %d" % [int(ed.get("attitude", 60)), int(ed.get("aura", 3))]
	l_st.add_theme_font_size_override("font_size", 10)
	l_st.add_theme_color_override("font_color", Color(0.80, 0.82, 0.84))
	iv.add_child(l_st)

	var l_mor: Label = Label.new()
	l_mor.text = "Moral %d/%d" % [int(ed.get("moral", 60)), int(ed.get("moral_max", 100))]
	l_mor.add_theme_font_size_override("font_size", 10)
	l_mor.add_theme_color_override("font_color", Color(0.75, 0.82, 0.84))
	iv.add_child(l_mor)

	var l_sub: Label = Label.new()
	l_sub.text = "En approche (103 SP / pied)"
	l_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_sub.add_theme_font_size_override("font_size", 10)
	l_sub.add_theme_color_override("font_color", Color(0.68, 0.76, 0.84))
	cv.add_child(l_sub)

	return card

func _build_enemy_card(ed: Dictionary) -> Control:
	var eid: String = str(ed.get("id", ""))
	var tick_v: int = int(ed.get("tick", 1))
	var is_sel: bool = bool(ed.get("selected", false))
	var is_acting: bool = bool(ed.get("acting", false))
	var counter_on: bool = bool(ed.get("counter_ready", false))
	var res: int = int(ed.get("resolve", 1))
	var res_max: int = maxi(1, int(ed.get("resolve_max", 1)))

	var card_btn: Button = Button.new()
	card_btn.custom_minimum_size = Vector2(216, 130)
	card_btn.focus_mode = Control.FOCUS_NONE
	var b_col: Color = Color(1.0, 0.78, 0.24) if is_sel else (Color(1.0, 0.30, 0.30) if is_acting else Color(0.84, 0.22, 0.22))
	var bg_col: Color = Color(0.20, 0.12, 0.09, 0.96) if is_sel else (Color(0.24, 0.09, 0.10, 0.96) if is_acting else Color(0.11, 0.10, 0.13, 0.94))
	card_btn.add_theme_stylebox_override("normal", _make_box(bg_col, b_col, 3 if (is_sel or is_acting) else 1, 5))
	card_btn.add_theme_stylebox_override("hover", _make_box(bg_col.lightened(0.08), Color(1.0, 0.85, 0.35), 2, 5))
	var eid_cap: String = eid
	card_btn.pressed.connect(func() -> void: _timeline.call("select_target", eid_cap))

	var cv: VBoxContainer = VBoxContainer.new()
	cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	cv.offset_left = 7
	cv.offset_top = 5
	cv.offset_right = -7
	cv.offset_bottom = -5
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_theme_constant_override("separation", 2)
	card_btn.add_child(cv)

	var head_r: HBoxContainer = HBoxContainer.new()
	head_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(head_r)

	var l_tk: Label = Label.new()
	l_tk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_tk.text = ("AGIT !" if is_acting else ("CRAN +%d" % tick_v)) + (" [CIBLE]" if is_sel else "")
	l_tk.add_theme_font_size_override("font_size", 10)
	l_tk.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28) if is_sel else Color(0.98, 0.38, 0.36))
	l_tk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_r.add_child(l_tk)

	var mid_r: HBoxContainer = HBoxContainer.new()
	mid_r.add_theme_constant_override("separation", 6)
	mid_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(mid_r)

	var ptex: TextureRect = TextureRect.new()
	ptex.custom_minimum_size = Vector2(42, 48)
	ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ptex.texture = _load_texture_safe(str(ed.get("portrait", "res://assets/portraits/so_agent.png")))
	ptex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_r.add_child(ptex)

	var iv: VBoxContainer = VBoxContainer.new()
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.add_theme_constant_override("separation", 2)
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_r.add_child(iv)

	var l_name: Label = Label.new()
	l_name.text = str(ed.get("label", eid))
	l_name.clip_text = true
	l_name.add_theme_font_size_override("font_size", 12)
	l_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42) if is_sel else Color(0.95, 0.92, 0.88))
	l_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv.add_child(l_name)

	var pips: HBoxContainer = HBoxContainer.new()
	pips.add_theme_constant_override("separation", 2)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv.add_child(pips)
	for idx_p in range(res_max):
		var pip: ColorRect = ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 7)
		pip.color = Color(0.88, 0.24, 0.22) if idx_p < res else Color(0.22, 0.22, 0.26)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	var l_res: Label = Label.new()
	l_res.text = " %d/%d" % [res, res_max]
	l_res.add_theme_font_size_override("font_size", 10)
	l_res.add_theme_color_override("font_color", Color(0.86, 0.86, 0.88))
	l_res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.add_child(l_res)

	var l_sub: Label = Label.new()
	if counter_on:
		l_sub.text = "⚠ Contre prête (-6 Mor.)"
		l_sub.add_theme_color_override("font_color", Color(1.0, 0.34, 0.34))
	else:
		l_sub.text = str(ed.get("role", ""))
		l_sub.add_theme_color_override("font_color", Color(0.74, 0.76, 0.82))
	l_sub.clip_text = true
	l_sub.add_theme_font_size_override("font_size", 10)
	l_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv.add_child(l_sub)

	var l_int: Label = Label.new()
	l_int.text = str(ed.get("intent", ""))
	l_int.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_int.clip_text = true
	l_int.custom_minimum_size = Vector2(0, 26)
	l_int.add_theme_font_size_override("font_size", 10)
	l_int.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88))
	l_int.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(l_int)

	var l_pv: Label = Label.new()
	l_pv.visible = false
	l_pv.add_theme_font_size_override("font_size", 10)
	l_pv.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	l_pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(l_pv)
	_rail_preview_labels[eid] = l_pv

	return card_btn

func _build_crs_card(ed: Dictionary) -> Control:
	var tick_v: int = int(ed.get("tick", 0))
	var urgent: bool = tick_v <= 2
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 130)
	var col_b: Color = Color(1.0, 0.36, 0.34) if urgent else Color(0.24, 0.52, 1.0)
	card.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.11, 0.18, 0.94), col_b, 2 if urgent else 1, 6))

	var cv: VBoxContainer = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	card.add_child(cv)

	var l_tk: Label = Label.new()
	l_tk.text = "CRAN +%d" % tick_v
	l_tk.add_theme_font_size_override("font_size", 11)
	l_tk.add_theme_color_override("font_color", col_b)
	cv.add_child(l_tk)

	var l_n: Label = Label.new()
	l_n.text = "Patrouille CRS"
	l_n.add_theme_font_size_override("font_size", 12)
	l_n.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	cv.add_child(l_n)

	var l_i: Label = Label.new()
	l_i.text = str(ed.get("intent", "Bouclage des sorties RER"))
	l_i.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_i.add_theme_font_size_override("font_size", 10)
	l_i.add_theme_color_override("font_color", Color(0.72, 0.80, 0.92))
	cv.add_child(l_i)

	var l_pv: Label = Label.new()
	l_pv.visible = false
	l_pv.add_theme_font_size_override("font_size", 10)
	l_pv.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	cv.add_child(l_pv)
	_rail_preview_labels["crs"] = l_pv

	return card

func _rebuild_actions(is_waiting: bool) -> void:
	for c in _actions_hbox.get_children():
		c.queue_free()
	_current_action_ids.clear()

	var actor_var: Variant = _timeline.call("get_acting_ally")
	var actor: Dictionary = actor_var as Dictionary if actor_var is Dictionary else {}
	var actor_name: String = str(actor.get("name", "Bande")).split(" ")[0]
	var tgt_var: Variant = _timeline.call("get_selected_target")
	var tgt_name: String = str((tgt_var as Dictionary).get("name", "Aucune")) if tgt_var is Dictionary else "Aucune"

	_lbl_target_banner.text = "Timing de %s  |  Cible : %s [Tab]  |  Actions de frise [1–4] :" % [actor_name, tgt_name]

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
			btn.custom_minimum_size = Vector2(0, 42)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.clip_text = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.disabled = is_waiting or actor.is_empty()
			btn.text = "[%d] %s" % [slot_num, str(ad.get("label", aid))]
			var aid_cap: String = aid
			btn.pressed.connect(func() -> void: _timeline.call("execute_player_action", aid_cap))
			btn.mouse_entered.connect(func() -> void: _set_hover_spec({"kind": "action", "id": aid_cap}))
			btn.mouse_exited.connect(func() -> void: _clear_hover_spec())
			_actions_hbox.add_child(btn)
			slot_num += 1

	if bool(_timeline.call("can_escape_now")):
		_current_action_ids.append("act_escape_now")
		var btn_esc: Button = Button.new()
		btn_esc.custom_minimum_size = Vector2(0, 42)
		btn_esc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_esc.clip_text = true
		btn_esc.focus_mode = Control.FOCUS_NONE
		btn_esc.disabled = is_waiting or actor.is_empty()
		btn_esc.text = "[%d] Filer par le Quai !" % slot_num
		btn_esc.add_theme_stylebox_override("normal", _make_box(Color(0.28, 0.20, 0.07), Color(0.98, 0.78, 0.26), 2, 4))
		btn_esc.pressed.connect(func() -> void: _timeline.call("execute_player_action", "act_escape_now"))
		btn_esc.mouse_entered.connect(func() -> void: _set_hover_spec({"kind": "action", "id": "act_escape_now"}))
		btn_esc.mouse_exited.connect(func() -> void: _clear_hover_spec())
		_actions_hbox.add_child(btn_esc)

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

	_lbl_preview_warn.visible = false
	if _hover_spec.is_empty() or _timeline == null:
		_lbl_preview.text = "Survole une action [1–4], ⚡ Interruption ou 🛡 Retenir pour prévisualiser l'impact sur la frise."
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
				parts.append("CRISE ANNULÉE")
			rl.text = "Aperçu : " + (" | ".join(parts) if not parts.is_empty() else str(pv.get("summary", "IMPACT")))
			rl.visible = true

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
