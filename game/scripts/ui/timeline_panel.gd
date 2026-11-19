extends Control

var _timeline: Node = null

var _lbl_header: Label = null
var _lbl_crs: Label = null
var _rail_hbox: HBoxContainer = null
var _crisis_banner: PanelContainer = null
var _lbl_crisis: Label = null
var _btn_restrain: Button = null
var _actions_box: GridContainer = null
var _interrupts_box: GridContainer = null
var _lbl_log: Label = null

var _active_crisis_char: String = ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	visible = false

func bind_timeline(tl: Node) -> void:
	_timeline = tl
	_timeline.timeline_updated.connect(refresh)
	_timeline.encounter_finished.connect(_on_encounter_finished)

func _build_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(18, 60)
	panel.size = Vector2(886, 646)
	panel.clip_contents = true
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.96)
	sb.border_color = Color(0.85, 0.17, 0.17)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# 1. En-tête Frise
	var head: HBoxContainer = HBoxContainer.new()
	vbox.add_child(head)

	_lbl_header = Label.new()
	_lbl_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_header.add_theme_font_size_override("font_size", 16)
	_lbl_header.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	head.add_child(_lbl_header)

	_lbl_crs = Label.new()
	_lbl_crs.add_theme_font_size_override("font_size", 14)
	_lbl_crs.add_theme_color_override("font_color", Color(0.32, 0.68, 0.95))
	head.add_child(_lbl_crs)

	# 2. Rail horizontal de la Bande Magnétique / Frise Chronologique
	var rail_title: Label = Label.new()
	rail_title.text = "FRISE CHRONOLOGIQUE (0 = Maintenant  →  Crans suivants)"
	rail_title.add_theme_font_size_override("font_size", 12)
	rail_title.add_theme_color_override("font_color", Color(0.75, 0.77, 0.80))
	vbox.add_child(rail_title)

	var rail_frame: PanelContainer = PanelContainer.new()
	var sb_rail: StyleBoxFlat = StyleBoxFlat.new()
	sb_rail.bg_color = Color(0.11, 0.11, 0.14)
	sb_rail.border_color = Color(0.30, 0.31, 0.36)
	sb_rail.set_border_width_all(1)
	sb_rail.set_content_margin_all(8)
	rail_frame.add_theme_stylebox_override("panel", sb_rail)
	vbox.add_child(rail_frame)

	_rail_hbox = HBoxContainer.new()
	_rail_hbox.add_theme_constant_override("separation", 8)
	rail_frame.add_child(_rail_hbox)

	# 3. Bannière Préavis Crise d'Autonomie
	_crisis_banner = PanelContainer.new()
	var sb_cr: StyleBoxFlat = StyleBoxFlat.new()
	sb_cr.bg_color = Color(0.36, 0.08, 0.08)
	sb_cr.border_color = Color(0.95, 0.25, 0.25)
	sb_cr.set_border_width_all(2)
	sb_cr.set_content_margin_all(8)
	_crisis_banner.add_theme_stylebox_override("panel", sb_cr)
	vbox.add_child(_crisis_banner)

	var cr_hbox: HBoxContainer = HBoxContainer.new()
	_crisis_banner.add_child(cr_hbox)

	_lbl_crisis = Label.new()
	_lbl_crisis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_crisis.add_theme_font_size_override("font_size", 13)
	_lbl_crisis.add_theme_color_override("font_color", Color(1.0, 0.88, 0.86))
	cr_hbox.add_child(_lbl_crisis)

	_btn_restrain = Button.new()
	_btn_restrain.text = "Retenir (Dépense Réaction)"
	_btn_restrain.pressed.connect(_on_restrain_pressed)
	cr_hbox.add_child(_btn_restrain)
	_crisis_banner.visible = false

	# 4. Actions de tour normal
	var lbl_act: Label = Label.new()
	lbl_act.text = "ACTION DU TOUR ACTIF (FAVE / FASA & Échappée)"
	lbl_act.add_theme_font_size_override("font_size", 12)
	lbl_act.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	vbox.add_child(lbl_act)

	_actions_box = GridContainer.new()
	_actions_box.columns = 2
	_actions_box.add_theme_constant_override("h_separation", 8)
	_actions_box.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_actions_box)

	# 5. Interruptions hors-tour
	var lbl_int: Label = Label.new()
	lbl_int.text = "INTERRUPTIONS HORS-TOUR PAR SPÉCIALITÉS (1 Réaction / cycle)"
	lbl_int.add_theme_font_size_override("font_size", 12)
	lbl_int.add_theme_color_override("font_color", Color(0.32, 0.68, 0.95))
	vbox.add_child(lbl_int)

	_interrupts_box = GridContainer.new()
	_interrupts_box.columns = 2
	_interrupts_box.add_theme_constant_override("h_separation", 8)
	_interrupts_box.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_interrupts_box)

	vbox.add_child(HSeparator.new())

	# 6. Journal de scène
	_lbl_log = Label.new()
	_lbl_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lbl_log.add_theme_font_size_override("font_size", 12)
	_lbl_log.add_theme_color_override("font_color", Color(0.88, 0.87, 0.82))
	vbox.add_child(_lbl_log)

func _on_restrain_pressed() -> void:
	if _timeline != null and _active_crisis_char != "":
		_timeline.call("restrain_crisis", _active_crisis_char)

func _on_encounter_finished(_outcome_id: String, _summary: String) -> void:
	visible = false

func refresh() -> void:
	if _timeline == null:
		return
	var is_act: bool = bool(_timeline.get("active"))
	visible = is_act
	if not is_act:
		return

	var title_txt: String = str(_timeline.get("encounter_title"))
	var turn_c: int = int(_timeline.get("turn_count"))
	var crs_t: int = int(_timeline.get("crs_ticks"))
	var esc_p: int = int(_timeline.get("escape_progress"))
	var tf_arrived: bool = bool(_timeline.get("train_fantome_arrived"))

	_lbl_header.text = "%s  (Tour %d)" % [title_txt, turn_c]
	var tf_tag: String = "  |  TRAIN FANTÔME À QUAI !" if tf_arrived else ("  |  Échappée: %d/2" % esc_p)
	_lbl_crs.text = "CRS dans %d cran(s)%s" % [maxi(0, crs_t), tf_tag]

	# Rail de crans
	for c in _rail_hbox.get_children():
		c.queue_free()

	var entries_var: Variant = _timeline.call("get_ordered_rail_entries")
	if entries_var is Array:
		var entries: Array = entries_var as Array
		var limit: int = mini(entries.size(), 7)
		for i in range(limit):
			var ed_var: Variant = entries[i]
			if ed_var is Dictionary:
				var ed: Dictionary = ed_var as Dictionary
				var card: PanelContainer = PanelContainer.new()
				card.custom_minimum_size = Vector2(114, 72)
				var sb_card: StyleBoxFlat = StyleBoxFlat.new()
				var col: Color = Color.html(str(ed.get("color", "#f28c28")))
				sb_card.bg_color = Color(0.14, 0.14, 0.18) if int(ed.get("tick", 1)) > 0 else Color(0.24, 0.18, 0.12)
				sb_card.border_color = col
				sb_card.set_border_width_all(2 if int(ed.get("tick", 1)) == 0 else 1)
				sb_card.set_content_margin_all(5)
				card.add_theme_stylebox_override("panel", sb_card)

				var cv: VBoxContainer = VBoxContainer.new()
				card.add_child(cv)

				var lt: Label = Label.new()
				lt.text = "[Cran %d]" % int(ed.get("tick", 0))
				lt.add_theme_font_size_override("font_size", 11)
				lt.add_theme_color_override("font_color", col)
				cv.add_child(lt)

				var ln: Label = Label.new()
				ln.text = str(ed.get("label", ""))
				ln.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				ln.add_theme_font_size_override("font_size", 11)
				cv.add_child(ln)

				var ls: Label = Label.new()
				ls.text = str(ed.get("sub", ""))
				ls.add_theme_font_size_override("font_size", 10)
				ls.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))
				cv.add_child(ls)

				_rail_hbox.add_child(card)

	# Préavis de Crise d'autonomie
	var cr_q_var: Variant = _timeline.get("crisis_queue")
	_active_crisis_char = ""
	if cr_q_var is Array and not (cr_q_var as Array).is_empty():
		var first_cr_var: Variant = (cr_q_var as Array)[0]
		if first_cr_var is Dictionary:
			var cr_d: Dictionary = first_cr_var as Dictionary
			_active_crisis_char = str(cr_d.get("char_id", ""))
			var tl_cr: int = int(cr_d.get("ticks_left", 1))
			_lbl_crisis.text = "PRÉAVIS CRISE D'AUTONOMIE (%s) dans %d cran(s) : %s" % [
				_active_crisis_char.capitalize(), tl_cr, str(cr_d.get("label", ""))
			]
			var can_restrain: bool = bool(_timeline.call("has_restrain_reaction_for", _active_crisis_char))
			_btn_restrain.disabled = not can_restrain
			_crisis_banner.visible = true
	else:
		_crisis_banner.visible = false

	# Boutons Actions de tour
	for c in _actions_box.get_children():
		c.queue_free()

	var actor_var: Variant = _timeline.call("get_acting_ally")
	var actor: Dictionary = actor_var as Dictionary if actor_var is Dictionary else {}
	var actor_name: String = str(actor.get("name", "Bande")).split(" ")[0]

	var enc: Dictionary = DataLoader.get_encounter(str(_timeline.get("encounter_id")))
	var act_list_var: Variant = enc.get("player_actions", [])
	if act_list_var is Array:
		for av in (act_list_var as Array):
			if av is Dictionary:
				var ad: Dictionary = av as Dictionary
				var aid: String = str(ad.get("id", ""))
				var btn: Button = Button.new()
				btn.text = "%s : %s" % [actor_name, str(ad.get("label", aid))]
				btn.tooltip_text = str(ad.get("desc", ""))
				btn.clip_text = true
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var aid_cap: String = aid
				btn.pressed.connect(func() -> void: _timeline.call("execute_player_action", aid_cap))
				_actions_box.add_child(btn)

	if bool(_timeline.call("can_escape_now")):
		var btn_esc: Button = Button.new()
		btn_esc.text = "FILER PAR LE QUAI / TRAIN FANTÔME !"
		btn_esc.pressed.connect(func() -> void: _timeline.call("execute_player_action", "act_escape_now"))
		_actions_box.add_child(btn_esc)

	# Boutons Interruptions hors-tour
	for c in _interrupts_box.get_children():
		c.queue_free()

	var allies_var: Variant = _timeline.get("allies")
	if allies_var is Array:
		for alv in (allies_var as Array):
			if alv is Dictionary:
				var al: Dictionary = alv as Dictionary
				if not bool(al.get("present", false)):
					continue
				var cid: String = str(al.get("char_id", ""))
				var r_ready: bool = bool(al.get("reaction_ready", false))
				var bi: Button = Button.new()
				bi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var tag_r: String = "PRÊTE" if r_ready else "Utilisée"
				bi.text = "%s — %s [%s]" % [
					str(al.get("name", cid)).split(" ")[0],
					str(al.get("specialty_name", "")),
					tag_r
				]
				bi.clip_text = true
				bi.tooltip_text = bi.text
				bi.disabled = not r_ready
				var cid_cap: String = cid
				bi.pressed.connect(func() -> void: _timeline.call("trigger_interruption", cid_cap))
				_interrupts_box.add_child(bi)

	# Journal combat
	var log_var: Variant = _timeline.get("combat_log")
	if log_var is Array:
		var lines: Array[String] = []
		for lv in (log_var as Array):
			lines.append("▸ " + str(lv))
		_lbl_log.text = "\n".join(lines)
