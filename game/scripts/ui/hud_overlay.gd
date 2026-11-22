extends Control

signal squad_regroup_requested
signal squad_split_2_1_requested
signal squad_split_1_1_1_requested
signal group_switch_requested(group_id: int)
signal group_order_cycle_requested(group_id: int)
signal location_travel_requested(location_id: String)
signal zoom_level_requested(level: int)
signal zoom_out_requested
signal twilight_requested
signal radio_zapped(station_idx: int)
signal restart_slice_requested
signal menu_requested

var _lbl_loc: Label = null
var _lbl_phase: Label = null
var _lbl_stats: Label = null
var _btn_mute: Button = null
var _crumb_btns: Array[Button] = []
var _btn_zoom_out: Button = null
var _btn_city_map: Button = null
var _btn_regroup: Button = null

var _groups_box: VBoxContainer = null
var _locations_box: VBoxContainer = null
var _btn_twilight: Button = null
var _lbl_radio_title: Label = null
var _lbl_radio_text: Label = null
var _lbl_clues: Label = null

var _radio_line_idx: int = 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	GameState.state_changed.connect(refresh)
	GameState.phase_changed.connect(func(_p: String) -> void: refresh())
	SettingsManager.settings_changed.connect(_sync_mute_button)
	_sync_mute_button()
	refresh()

func _make_panel_style(bg: Color, border: Color, border_w: int = 2) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_content_margin_all(8)
	return sb

func _build_ui() -> void:
	# 1. Bandeau supérieur 1982
	var top_bar: PanelContainer = PanelContainer.new()
	top_bar.position = Vector2(10, 6)
	top_bar.size = Vector2(1260, 44)
	top_bar.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.08, 0.10, 0.94), Color(0.85, 0.17, 0.17)))
	add_child(top_bar)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	top_bar.add_child(top_hbox)

	var crumb_labels: Array[String] = ["IDF", "93", "Cradon", "Intérieur"]
	_crumb_btns.clear()
	for idx in range(crumb_labels.size()):
		var b_cr: Button = Button.new()
		b_cr.text = crumb_labels[idx]
		b_cr.add_theme_font_size_override("font_size", 11)
		var lvl_cap: int = idx + 1
		b_cr.pressed.connect(func() -> void: zoom_level_requested.emit(lvl_cap))
		top_hbox.add_child(b_cr)
		_crumb_btns.append(b_cr)

	_btn_zoom_out = Button.new()
	_btn_zoom_out.text = "▲"
	_btn_zoom_out.tooltip_text = "Dézoomer d'un niveau (Backspace)"
	_btn_zoom_out.add_theme_font_size_override("font_size", 11)
	_btn_zoom_out.pressed.connect(func() -> void: zoom_out_requested.emit())
	top_hbox.add_child(_btn_zoom_out)

	_lbl_loc = Label.new()
	_lbl_loc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_loc.clip_text = true
	_lbl_loc.add_theme_font_size_override("font_size", 13)
	_lbl_loc.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	top_hbox.add_child(_lbl_loc)

	_lbl_phase = Label.new()
	_lbl_phase.add_theme_font_size_override("font_size", 14)
	_lbl_phase.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	top_hbox.add_child(_lbl_phase)

	_lbl_stats = Label.new()
	_lbl_stats.add_theme_font_size_override("font_size", 13)
	_lbl_stats.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92))
	top_hbox.add_child(_lbl_stats)

	_btn_mute = Button.new()
	_btn_mute.text = "Son: ON"
	_btn_mute.pressed.connect(_on_mute_pressed)
	top_hbox.add_child(_btn_mute)

	var btn_menu: Button = Button.new()
	btn_menu.text = "Menu"
	btn_menu.tooltip_text = "Menu Principal / Pause (Échap)"
	btn_menu.pressed.connect(func() -> void: menu_requested.emit())
	top_hbox.add_child(btn_menu)

	# 2. Panneau latéral droit (Bande / Lieux / Radio FM / Pistes)
	var side: PanelContainer = PanelContainer.new()
	side.position = Vector2(918, 56)
	side.size = Vector2(352, 656)
	side.add_theme_stylebox_override("panel", _make_panel_style(Color(0.09, 0.09, 0.11, 0.93), Color(0.22, 0.23, 0.27)))
	add_child(side)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)

	var side_vbox: VBoxContainer = VBoxContainer.new()
	side_vbox.custom_minimum_size = Vector2(326, 0)
	side_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(side_vbox)

	# -- Bande modulable
	var lbl_b: Label = Label.new()
	lbl_b.text = "BANDE MODULABLE (Touches 1–6)"
	lbl_b.add_theme_font_size_override("font_size", 13)
	lbl_b.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	side_vbox.add_child(lbl_b)

	var split_row: HBoxContainer = HBoxContainer.new()
	split_row.add_theme_constant_override("separation", 4)
	side_vbox.add_child(split_row)

	_btn_regroup = Button.new()
	_btn_regroup.text = "Soudés"
	_btn_regroup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_regroup.pressed.connect(func() -> void: squad_regroup_requested.emit())
	split_row.add_child(_btn_regroup)

	var b_21: Button = Button.new()
	b_21.text = "2 + 1"
	b_21.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_21.pressed.connect(func() -> void: squad_split_2_1_requested.emit())
	split_row.add_child(b_21)

	var b_111: Button = Button.new()
	b_111.text = "Éclatés"
	b_111.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_111.pressed.connect(func() -> void: squad_split_1_1_1_requested.emit())
	split_row.add_child(b_111)

	_groups_box = VBoxContainer.new()
	_groups_box.add_theme_constant_override("separation", 4)
	side_vbox.add_child(_groups_box)

	side_vbox.add_child(HSeparator.new())

	# -- Carte Cradon-lès-Gonesse
	var lbl_m: Label = Label.new()
	lbl_m.text = "ATLAS & CRADON-LÈS-GONESSE"
	lbl_m.add_theme_font_size_override("font_size", 13)
	lbl_m.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	side_vbox.add_child(lbl_m)

	_btn_city_map = Button.new()
	_btn_city_map.text = "Plan de Cradon (N3) [M]"
	_btn_city_map.pressed.connect(func() -> void: zoom_level_requested.emit(3))
	side_vbox.add_child(_btn_city_map)

	_locations_box = VBoxContainer.new()
	_locations_box.add_theme_constant_override("separation", 3)
	side_vbox.add_child(_locations_box)

	_btn_twilight = Button.new()
	_btn_twilight.text = "Passer au Crépuscule (Boeing → Nuit)"
	_btn_twilight.pressed.connect(func() -> void: twilight_requested.emit())
	side_vbox.add_child(_btn_twilight)

	side_vbox.add_child(HSeparator.new())

	# -- Radio FM
	var radio_head: HBoxContainer = HBoxContainer.new()
	side_vbox.add_child(radio_head)

	_lbl_radio_title = Label.new()
	_lbl_radio_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_radio_title.add_theme_font_size_override("font_size", 12)
	_lbl_radio_title.add_theme_color_override("font_color", Color(0.32, 0.68, 0.95))
	radio_head.add_child(_lbl_radio_title)

	var btn_zap: Button = Button.new()
	btn_zap.text = "Zapper FM"
	btn_zap.pressed.connect(_on_zap_pressed)
	radio_head.add_child(btn_zap)

	_lbl_radio_text = Label.new()
	_lbl_radio_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_radio_text.add_theme_font_size_override("font_size", 11)
	_lbl_radio_text.add_theme_color_override("font_color", Color(0.82, 0.85, 0.88))
	side_vbox.add_child(_lbl_radio_text)

	side_vbox.add_child(HSeparator.new())

	# -- Pistes & Journal
	var lbl_c_head: Label = Label.new()
	lbl_c_head.text = "PISTES & CARNET DE RUE"
	lbl_c_head.add_theme_font_size_override("font_size", 12)
	lbl_c_head.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	side_vbox.add_child(lbl_c_head)

	_lbl_clues = Label.new()
	_lbl_clues.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_clues.add_theme_font_size_override("font_size", 11)
	_lbl_clues.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	side_vbox.add_child(_lbl_clues)

## Met à jour le libellé du bouton Son selon l'état global SettingsManager.muted.
func _sync_mute_button() -> void:
	if _btn_mute != null:
		_btn_mute.text = "Son: OFF" if SettingsManager.muted else "Son: ON"

func _on_mute_pressed() -> void:
	AudioRadio.toggle_mute()
	_sync_mute_button()

func _on_zap_pressed() -> void:
	var idx: int = GameState.cycle_station()
	_radio_line_idx = (_radio_line_idx + 1) % 2
	AudioRadio.play_radio_zap()
	radio_zapped.emit(idx)
	refresh()

func refresh() -> void:
	if _lbl_loc == null:
		return
	var loc_id: String = GameState.get_active_location_id()
	var loc: Dictionary = DataLoader.get_location(loc_id)
	var zl: int = GameState.current_zoom_level
	for i in range(_crumb_btns.size()):
		var b_cr: Button = _crumb_btns[i]
		var is_here: bool = (i + 1 == zl)
		b_cr.disabled = is_here
		b_cr.modulate = Color(1.0, 0.72, 0.32) if is_here else Color.WHITE
	if _btn_zoom_out != null:
		_btn_zoom_out.disabled = (zl <= 1)
	if _btn_city_map != null:
		_btn_city_map.text = "Revenir à l'intérieur (N4) [M]" if zl < 4 else "Plan de Cradon (N3) [M]"
	if _btn_regroup != null:
		_btn_regroup.text = "%d Soudés" % GameState.squad_members.size()

	if zl == 1:
		var reg: Dictionary = DataLoader.get_region(GameState.current_region_id)
		_lbl_loc.text = " N1 · %s" % str(reg.get("name", "Île-de-France"))
	elif zl == 2:
		var dept: Dictionary = DataLoader.get_department(GameState.current_department_id)
		_lbl_loc.text = " N2 · %s" % str(dept.get("name", "Seine-Saint-Denis (93)"))
	elif zl == 3:
		var city: Dictionary = DataLoader.get_city(GameState.current_city_id)
		_lbl_loc.text = " N3 · %s" % str(city.get("name", "Cradon-lès-Gonesse"))
	else:
		var gw: int = int(loc.get("grid_w", 8))
		var gh: int = int(loc.get("grid_h", 8))
		var rmode: String = "BD" if str(loc.get("render_mode", "backdrop")) == "backdrop" else "Modulaire"
		_lbl_loc.text = " %s (%dx%d · %s)" % [str(loc.get("name", loc_id)), gw, gh, rmode]

	var phase_label: String = "JOUR"
	if GameState.phase == "twilight":
		phase_label = "CRÉPUSCULE"
	elif GameState.phase == "night":
		phase_label = "NUIT"
	_lbl_phase.text = "[%s · %s]" % [phase_label, GameState.format_clock()]

	_lbl_stats.text = "%d F  |  Faveurs: %d  |  Aura: %d  |  Notoriété: %d" % [
		GameState.francs, GameState.faveurs, GameState.get_total_aura(), GameState.notoriete
	]

	# Rafraîchir groupes
	for c in _groups_box.get_children():
		c.queue_free()

	var gids: Array[int] = GameState.get_present_group_ids()
	for gid in gids:
		var members: Array[String] = GameState.get_group_members(gid)
		var is_act: bool = (gid == GameState.active_group_id)
		var first_st: Dictionary = GameState.get_member_state(members[0])
		var g_loc: String = str(DataLoader.get_location(str(first_st.get("location_id", "box_garage"))).get("name", ""))
		var g_order: String = str(first_st.get("order_label", "Guetter"))

		var card: VBoxContainer = VBoxContainer.new()
		var row: HBoxContainer = HBoxContainer.new()
		card.add_child(row)

		var btn_g: Button = Button.new()
		btn_g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var names_arr: Array[String] = []
		for cid in members:
			var cdef: Dictionary = DataLoader.get_character(cid)
			var st: Dictionary = GameState.get_member_state(cid)
			var m_val: int = int(st.get("moral", 60))
			var tag_stress: String = " [STRESS!]" if bool(st.get("stress_active", false)) else ""
			names_arr.append("%s (%d%s)" % [str(cdef.get("name", cid)).split(" ")[0], m_val, tag_stress])

		btn_g.text = ("%s Groupe %d : %s" % ["►" if is_act else " ", gid + 1, ", ".join(names_arr)])
		btn_g.clip_text = true
		btn_g.tooltip_text = btn_g.text
		var gid_capture: int = gid
		btn_g.pressed.connect(func() -> void: group_switch_requested.emit(gid_capture))
		row.add_child(btn_g)

		if not is_act:
			var btn_ord: Button = Button.new()
			btn_ord.text = g_order
			btn_ord.pressed.connect(func() -> void: group_order_cycle_requested.emit(gid_capture))
			row.add_child(btn_ord)

		var sub_loc: Label = Label.new()
		sub_loc.text = "   @ " + g_loc
		sub_loc.add_theme_font_size_override("font_size", 11)
		sub_loc.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
		card.add_child(sub_loc)
		_groups_box.add_child(card)

	# Rafraîchir carte des lieux
	for c in _locations_box.get_children():
		c.queue_free()

	for lid in DataLoader.location_order:
		var ldef: Dictionary = DataLoader.get_location(lid)
		var here_tags: Array[String] = []
		for gid in gids:
			var gm: Array[String] = GameState.get_group_members(gid)
			if not gm.is_empty():
				var st_g: Dictionary = GameState.get_member_state(gm[0])
				if str(st_g.get("location_id", "")) == lid:
					here_tags.append("G%d" % (gid + 1))

		var b_loc: Button = Button.new()
		var mark_here: String = (" [" + ",".join(here_tags) + "]") if not here_tags.is_empty() else ""
		var done_mark: String = ""
		if lid == "tour_b" and GameState.has_flag("tour_b_done"):
			done_mark = " ✓"
		elif lid == "chez_bebert" and GameState.has_flag("bebert_done"):
			done_mark = " ✓"
		elif lid == "ruelle_relais" and GameState.has_flag("ruelle_done"):
			done_mark = " ✓"
		elif lid == "garage_bananes" and GameState.has_flag("manu_recruited"):
			done_mark = " ✓"
		elif lid == "squat_kepons" and GameState.has_flag("zoe_recruited"):
			done_mark = " ✓"
		elif lid == "lisiere_poudrerie" and GameState.has_flag("poudrerie_done"):
			done_mark = " ✓"
		b_loc.text = "%s%s%s" % [str(ldef.get("name", lid)), mark_here, done_mark]
		b_loc.clip_text = true
		b_loc.tooltip_text = b_loc.text
		b_loc.disabled = (lid == loc_id)
		var lid_cap: String = lid
		b_loc.pressed.connect(func() -> void: location_travel_requested.emit(lid_cap))
		_locations_box.add_child(b_loc)

	_btn_twilight.visible = (GameState.phase == "day")

	# Radio FM
	if not DataLoader.radio_stations.is_empty():
		var st_idx: int = GameState.current_station_idx % DataLoader.radio_stations.size()
		var st_dict: Dictionary = DataLoader.radio_stations[st_idx]
		_lbl_radio_title.text = "FM : %s — %s" % [str(st_dict.get("freq", "")), str(st_dict.get("name", ""))]
		var lines_key: String = "night_lines" if GameState.phase == "night" else "day_lines"
		var lines_var: Variant = st_dict.get(lines_key, [])
		if lines_var is Array and not (lines_var as Array).is_empty():
			var arr: Array = lines_var as Array
			_lbl_radio_text.text = str(arr[_radio_line_idx % arr.size()])
		else:
			_lbl_radio_text.text = "[Grésillements...]"

	# Pistes
	var out_lines: Array[String] = []
	for clue in GameState.clues:
		out_lines.append("• " + clue)
	if out_lines.is_empty():
		out_lines.append("• Explore le Box-Garage ou file au Galaxian.")
	_lbl_clues.text = "\n".join(out_lines)
