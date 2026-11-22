## Carnet de Bande / Fanzine 1982 : fiches PJ complètes (Esprit/Corps/Énergie, compétences -3..+5, XP, équipement actif, relations).
extends Control

signal closed

const CharacterSheetPanelSlotOrder: Array[String] = ["look_top", "look_bottom", "tool", "fetish"]

var _active_char_id: String = "leader"
var _panel: PanelContainer = null
var _tabs_hbox: HBoxContainer = null
var _lbl_xp: Label = null

# Page gauche : portrait, pion, identité, caractéristiques, jauges, histoire, relations
var _portrait_tex: TextureRect = null
var _pawn_tex: TextureRect = null
var _lbl_identity: Label = null
var _charac_vbox: VBoxContainer = null
var _lbl_gauges: Label = null
var _lbl_bio: Label = null
var _relations_vbox: VBoxContainer = null

# Page droite : compétences (-3..+5), spécialité & actions, équipement + coffre, traits
var _skills_vbox: VBoxContainer = null
var _lbl_specialty: Label = null
var _equip_vbox: VBoxContainer = null
var _stash_vbox: VBoxContainer = null
var _lbl_traits: Label = null

var _tex_cache: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	GameState.state_changed.connect(func() -> void:
		if visible:
			refresh()
	)
	visible = false

## Ouvre le Carnet de Bande sur le personnage demandé (ou le premier disponible).
func open_panel(char_id: String = "") -> void:
	if char_id != "" and GameState.squad_members.has(char_id):
		_active_char_id = char_id
	elif not GameState.squad_members.has(_active_char_id):
		_active_char_id = GameState.squad_members[0] if not GameState.squad_members.is_empty() else "leader"
	visible = true
	refresh()

## Ferme le Carnet de Bande et notifie l'orchestrateur.
func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_LEFT:
				_cycle_member(-1)
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_RIGHT:
				_cycle_member(1)
				get_viewport().set_input_as_handled()

func _cycle_member(step: int) -> void:
	if GameState.squad_members.is_empty():
		return
	var idx: int = GameState.squad_members.find(_active_char_id)
	if idx < 0:
		idx = 0
	var next_idx: int = (idx + step + GameState.squad_members.size()) % GameState.squad_members.size()
	_active_char_id = GameState.squad_members[next_idx]
	AudioRadio.play_cassette_click()
	refresh()

func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.05, 0.74)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.position = Vector2(110, 52)
	_panel.size = Vector2(1060, 616)
	_panel.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.08, 0.10, 0.98), Color(0.86, 0.20, 0.20), 3, 14))
	add_child(_panel)

	var root_v: VBoxContainer = VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 10)
	_panel.add_child(root_v)

	# Bandeau onglets PJ + XP + Fermer
	var top_h: HBoxContainer = HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 8)
	root_v.add_child(top_h)

	var title_lbl: Label = Label.new()
	title_lbl.text = "CARNET DE BANDE — FICHES PJ"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	top_h.add_child(title_lbl)

	var tabs_scroll: ScrollContainer = ScrollContainer.new()
	tabs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_scroll.custom_minimum_size = Vector2(0, 32)
	tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	top_h.add_child(tabs_scroll)

	_tabs_hbox = HBoxContainer.new()
	_tabs_hbox.add_theme_constant_override("separation", 6)
	tabs_scroll.add_child(_tabs_hbox)

	_lbl_xp = Label.new()
	_lbl_xp.add_theme_font_size_override("font_size", 13)
	_lbl_xp.add_theme_color_override("font_color", Color(0.98, 0.82, 0.28))
	top_h.add_child(_lbl_xp)

	var btn_close: Button = Button.new()
	btn_close.text = "Fermer [F / Échap]"
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.pressed.connect(close_panel)
	top_h.add_child(btn_close)

	root_v.add_child(HSeparator.new())

	# Double page : Gauche (Identité/Stats/Bio/Relations) | Droite (Compétences/Équipement/Traits)
	var body_h: HBoxContainer = HBoxContainer.new()
	body_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_h.add_theme_constant_override("separation", 14)
	root_v.add_child(body_h)

	# PAGE GAUCHE
	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(448, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", _make_box(Color(0.10, 0.10, 0.13, 0.96), Color(0.28, 0.30, 0.36), 1, 10))
	body_h.add_child(left_panel)

	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(left_scroll)

	var left_v: VBoxContainer = VBoxContainer.new()
	left_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_v.add_theme_constant_override("separation", 8)
	left_scroll.add_child(left_v)

	var vis_h: HBoxContainer = HBoxContainer.new()
	vis_h.add_theme_constant_override("separation", 10)
	left_v.add_child(vis_h)

	_portrait_tex = TextureRect.new()
	_portrait_tex.custom_minimum_size = Vector2(104, 104)
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	vis_h.add_child(_portrait_tex)

	_pawn_tex = TextureRect.new()
	_pawn_tex.custom_minimum_size = Vector2(78, 138)
	_pawn_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pawn_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vis_h.add_child(_pawn_tex)

	_lbl_identity = Label.new()
	_lbl_identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_identity.add_theme_font_size_override("font_size", 12)
	_lbl_identity.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	vis_h.add_child(_lbl_identity)

	var l_ch_title: Label = Label.new()
	l_ch_title.text = "CARACTÉRISTIQUES (1 à 5)"
	l_ch_title.add_theme_font_size_override("font_size", 11)
	l_ch_title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	left_v.add_child(l_ch_title)

	_charac_vbox = VBoxContainer.new()
	_charac_vbox.add_theme_constant_override("separation", 4)
	left_v.add_child(_charac_vbox)

	_lbl_gauges = Label.new()
	_lbl_gauges.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_gauges.add_theme_font_size_override("font_size", 12)
	_lbl_gauges.add_theme_color_override("font_color", Color(0.86, 0.90, 0.95))
	left_v.add_child(_lbl_gauges)

	var l_bio_t: Label = Label.new()
	l_bio_t.text = "IDENTITÉ SOCIALE & ARC PERSONNEL"
	l_bio_t.add_theme_font_size_override("font_size", 11)
	l_bio_t.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	left_v.add_child(l_bio_t)

	_lbl_bio = Label.new()
	_lbl_bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_bio.add_theme_font_size_override("font_size", 11)
	_lbl_bio.add_theme_color_override("font_color", Color(0.84, 0.84, 0.82))
	left_v.add_child(_lbl_bio)

	var l_rel_t: Label = Label.new()
	l_rel_t.text = "THERMOMÈTRE RELATIONNEL DANS LA BANDE"
	l_rel_t.add_theme_font_size_override("font_size", 11)
	l_rel_t.add_theme_color_override("font_color", Color(0.42, 0.78, 0.98))
	left_v.add_child(l_rel_t)

	_relations_vbox = VBoxContainer.new()
	_relations_vbox.add_theme_constant_override("separation", 3)
	left_v.add_child(_relations_vbox)

	# PAGE DROITE
	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _make_box(Color(0.10, 0.10, 0.13, 0.96), Color(0.28, 0.30, 0.36), 1, 10))
	body_h.add_child(right_panel)

	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(right_scroll)

	var right_v: VBoxContainer = VBoxContainer.new()
	right_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_v.add_theme_constant_override("separation", 8)
	right_scroll.add_child(right_v)

	var l_sk_t: Label = Label.new()
	l_sk_t.text = "COMPÉTENCES DE RUE (-3 à +5 · Dépense XP & Bonus équipement)"
	l_sk_t.add_theme_font_size_override("font_size", 11)
	l_sk_t.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	right_v.add_child(l_sk_t)

	_skills_vbox = VBoxContainer.new()
	_skills_vbox.add_theme_constant_override("separation", 4)
	right_v.add_child(_skills_vbox)

	right_v.add_child(HSeparator.new())

	var l_sp_t: Label = Label.new()
	l_sp_t.text = "SPÉCIALITÉ FRISE & ACTIONS DÉBLOQUÉES"
	l_sp_t.add_theme_font_size_override("font_size", 11)
	l_sp_t.add_theme_color_override("font_color", Color(0.42, 0.78, 0.98))
	right_v.add_child(l_sp_t)

	_lbl_specialty = Label.new()
	_lbl_specialty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_specialty.add_theme_font_size_override("font_size", 11)
	_lbl_specialty.add_theme_color_override("font_color", Color(0.88, 0.90, 0.92))
	right_v.add_child(_lbl_specialty)

	right_v.add_child(HSeparator.new())

	var l_eq_t: Label = Label.new()
	l_eq_t.text = "ÉQUIPEMENT DU PJ (4 Emplacements : Haut / Bas / Outil / Fétiche)"
	l_eq_t.add_theme_font_size_override("font_size", 11)
	l_eq_t.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	right_v.add_child(l_eq_t)

	_equip_vbox = VBoxContainer.new()
	_equip_vbox.add_theme_constant_override("separation", 4)
	right_v.add_child(_equip_vbox)

	var l_st_t: Label = Label.new()
	l_st_t.text = "COFFRE DU BOX-GARAGE (cliquer Équiper pour transférer)"
	l_st_t.add_theme_font_size_override("font_size", 11)
	l_st_t.add_theme_color_override("font_color", Color(0.76, 0.80, 0.86))
	right_v.add_child(l_st_t)

	_stash_vbox = VBoxContainer.new()
	_stash_vbox.add_theme_constant_override("separation", 4)
	right_v.add_child(_stash_vbox)

	right_v.add_child(HSeparator.new())

	var l_tr_t: Label = Label.new()
	l_tr_t.text = "TRAITS & CICATRICES DE VÉCU"
	l_tr_t.add_theme_font_size_override("font_size", 11)
	l_tr_t.add_theme_color_override("font_color", Color(0.96, 0.78, 0.34))
	right_v.add_child(l_tr_t)

	_lbl_traits = Label.new()
	_lbl_traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_traits.add_theme_font_size_override("font_size", 11)
	_lbl_traits.add_theme_color_override("font_color", Color(0.86, 0.86, 0.82))
	right_v.add_child(_lbl_traits)

## Rafraîchit les onglets et les deux pages de la fiche courante.
func refresh() -> void:
	if GameState.squad_members.is_empty():
		return
	if not GameState.squad_members.has(_active_char_id):
		_active_char_id = GameState.squad_members[0]

	_rebuild_tabs()

	var cdef: Dictionary = DataLoader.get_character(_active_char_id)
	var st: Dictionary = GameState.get_member_state(_active_char_id)
	var prog: Dictionary = GameState.get_member_progression(_active_char_id)
	var xp_avail: int = int(prog.get("xp", 0))
	_lbl_xp.text = "XP dispo : %d" % xp_avail

	_portrait_tex.texture = _load_texture_safe(str(cdef.get("portrait", "")))
	_pawn_tex.texture = GameState.get_character_pawn_texture(_active_char_id)

	var home_id: String = str(cdef.get("home_location", "box_garage"))
	var home_name: String = str(DataLoader.get_location(home_id).get("name", home_id))
	var loc_now_id: String = str(st.get("location_id", home_id))
	var loc_now_name: String = str(DataLoader.get_location(loc_now_id).get("name", loc_now_id))
	_lbl_identity.text = "%s (%s ans)\n%s\nTribu : %s\nAttache : %s\nEn ce moment : %s" % [
		str(cdef.get("name", _active_char_id)),
		str(cdef.get("age", 18)),
		str(cdef.get("role", "")),
		str(cdef.get("tribe", "")),
		home_name,
		loc_now_name
	]

	_rebuild_characteristics()
	_lbl_gauges.text = "Attitude : %d   |   Aura : %d   |   Moral : %d / %d\nSeuil Stress : %d (%s)" % [
		GameState.get_effective_attitude_for(_active_char_id),
		GameState.get_effective_aura_for(_active_char_id),
		int(st.get("moral", 60)),
		GameState.get_effective_moral_max(_active_char_id),
		GameState.get_effective_stress_threshold(_active_char_id),
		str(cdef.get("stress_name", "Stress"))
	]

	var bio_txt: String = str(cdef.get("bio", ""))
	var arc_txt: String = str(cdef.get("arc_summary", ""))
	_lbl_bio.text = "%s\nEnjeu : %s" % [bio_txt, arc_txt]

	_rebuild_relations(cdef)
	_rebuild_skills(xp_avail, prog, cdef)
	_rebuild_specialty_and_actions(cdef)
	_rebuild_equipment(prog)
	_rebuild_stash()
	_rebuild_traits(prog)

func _rebuild_tabs() -> void:
	for c in _tabs_hbox.get_children():
		c.queue_free()
	for cid in GameState.squad_members:
		var cdef: Dictionary = DataLoader.get_character(cid)
		var is_sel: bool = (cid == _active_char_id)
		var b: Button = Button.new()
		b.text = str(cdef.get("name", cid)).split(" ")[0]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		if is_sel:
			b.add_theme_stylebox_override("normal", _make_box(Color(0.32, 0.16, 0.08), Color(0.98, 0.62, 0.22), 2, 5))
		var cid_cap: String = cid
		b.pressed.connect(func() -> void:
			AudioRadio.play_cassette_click()
			_active_char_id = cid_cap
			refresh()
		)
		_tabs_hbox.add_child(b)

func _rebuild_characteristics() -> void:
	for c in _charac_vbox.get_children():
		c.queue_free()
	var specs: Array[Array] = [
		["esprit", "Esprit"],
		["corps", "Corps"],
		["energie", "Énergie"]
	]
	for sp in specs:
		var ch_id: String = str(sp[0])
		var ch_lbl: String = str(sp[1])
		var val: int = GameState.get_effective_characteristic(_active_char_id, ch_id)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lbl: Label = Label.new()
		lbl.text = ch_lbl
		lbl.custom_minimum_size = Vector2(72, 0)
		lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)
		for p in range(5):
			var pip: ColorRect = ColorRect.new()
			pip.custom_minimum_size = Vector2(24, 9)
			pip.color = Color(0.95, 0.58, 0.18) if p < val else Color(0.22, 0.23, 0.28)
			row.add_child(pip)
		var val_l: Label = Label.new()
		val_l.text = "%d / 5" % val
		val_l.add_theme_font_size_override("font_size", 11)
		row.add_child(val_l)
		_charac_vbox.add_child(row)

func _rebuild_relations(cdef: Dictionary) -> void:
	for c in _relations_vbox.get_children():
		c.queue_free()
	var rel_var: Variant = cdef.get("relations", {})
	var rel_d: Dictionary = rel_var as Dictionary if rel_var is Dictionary else {}
	var any_shown: bool = false
	for cid in DataLoader.characters.keys():
		var other_id: String = str(cid)
		if other_id == _active_char_id or not rel_d.has(other_id):
			continue
		var r_entry_v: Variant = rel_d.get(other_id, {})
		if not (r_entry_v is Dictionary):
			continue
		any_shown = true
		var r_entry: Dictionary = r_entry_v as Dictionary
		var status: String = str(r_entry.get("status", "complementaires"))
		var other_name: String = str(DataLoader.get_character(other_id).get("name", other_id)).split(" ")[0]
		var in_band: bool = GameState.squad_members.has(other_id)
		var tag_txt: String = "Soudés" if status == "soudes" else ("⚠ Friction" if status == "friction" else "Complémentaires")
		var col: Color = Color(0.52, 0.88, 0.58) if status == "soudes" else (Color(1.0, 0.40, 0.36) if status == "friction" else Color(0.68, 0.82, 0.94))
		var lbl: Label = Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text = "• %s%s [%s] : %s" % [other_name, "" if in_band else " (hors bande)", tag_txt, str(r_entry.get("label", ""))]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", col if in_band else Color(0.60, 0.62, 0.68))
		_relations_vbox.add_child(lbl)
	if not any_shown:
		var l_none: Label = Label.new()
		l_none.text = "• Aucune relation notée."
		l_none.add_theme_font_size_override("font_size", 11)
		_relations_vbox.add_child(l_none)

func _rebuild_skills(xp_avail: int, prog: Dictionary, cdef: Dictionary) -> void:
	for c in _skills_vbox.get_children():
		c.queue_free()
	var prog_sk_var: Variant = prog.get("skills", {})
	var prog_sk: Dictionary = prog_sk_var as Dictionary if prog_sk_var is Dictionary else {}
	var profile_sk_var: Variant = cdef.get("skills", {})
	var profile_sk: Dictionary = profile_sk_var as Dictionary if profile_sk_var is Dictionary else {}

	for sd in DataLoader.skills_catalog:
		var sid: String = str(sd.get("id", ""))
		var sname: String = str(sd.get("name", sid))
		var ch_tag: String = str(sd.get("charac", "esprit")).substr(0, 3).capitalize()
		var base_v: int = GameState.get_base_skill(_active_char_id, sid)
		var eq_b: int = GameState.get_equipment_skill_bonus(_active_char_id, sid)
		var eff_v: int = GameState.get_effective_skill(_active_char_id, sid)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var l_name: Label = Label.new()
		l_name.custom_minimum_size = Vector2(226, 0)
		l_name.clip_text = true
		l_name.text = "%s [%s]" % [sname, ch_tag]
		l_name.tooltip_text = str(sd.get("desc", ""))
		l_name.add_theme_font_size_override("font_size", 11)
		l_name.add_theme_color_override("font_color", Color(0.95, 0.94, 0.88))
		row.add_child(l_name)

		# Jauge visuelle bipolaire [-3 .. 0 .. +5]
		var meter: HBoxContainer = HBoxContainer.new()
		meter.add_theme_constant_override("separation", 2)
		for lvl in [-3, -2, -1, 1, 2, 3, 4, 5]:
			var pip: ColorRect = ColorRect.new()
			pip.custom_minimum_size = Vector2(10, 9)
			if lvl < 0:
				pip.color = Color(0.88, 0.24, 0.24) if eff_v <= lvl else Color(0.20, 0.20, 0.24)
			else:
				pip.color = Color(0.95, 0.62, 0.20) if eff_v >= lvl else Color(0.20, 0.20, 0.24)
			meter.add_child(pip)
		row.add_child(meter)

		var l_val: Label = Label.new()
		l_val.custom_minimum_size = Vector2(82, 0)
		var mod_str: String = (" (%+d)" % eq_b) if eq_b != 0 else ""
		l_val.text = "%+d%s" % [eff_v, mod_str]
		l_val.add_theme_font_size_override("font_size", 11)
		l_val.add_theme_color_override("font_color", Color(1.0, 0.40, 0.36) if eff_v < 0 else (Color(0.96, 0.78, 0.30) if eff_v > 0 else Color(0.75, 0.78, 0.82)))
		row.add_child(l_val)

		var is_new_learn: bool = (base_v == 0) and (not profile_sk.has(sid)) and (not prog_sk.has(sid))
		var cost: int = GameState.get_skill_upgrade_cost(base_v, is_new_learn)
		var btn_up: Button = Button.new()
		btn_up.custom_minimum_size = Vector2(78, 22)
		btn_up.focus_mode = Control.FOCUS_NONE
		btn_up.add_theme_font_size_override("font_size", 10)
		if cost < 0:
			btn_up.text = "MAX"
			btn_up.disabled = true
		else:
			btn_up.text = "+ (%d XP)" % cost
			btn_up.disabled = xp_avail < cost
			var sid_cap: String = sid
			btn_up.pressed.connect(func() -> void:
				if GameState.upgrade_member_skill(_active_char_id, sid_cap):
					AudioRadio.play_cassette_click()
					refresh()
			)
		row.add_child(btn_up)
		_skills_vbox.add_child(row)

func _rebuild_specialty_and_actions(cdef: Dictionary) -> void:
	var lines: Array[String] = []
	lines.append("⚡ %s : %s" % [str(cdef.get("specialty_name", "")), str(cdef.get("specialty_desc", ""))])
	for act_d in GameState.get_unlocked_equipment_actions(_active_char_id):
		lines.append("• [Matos] %s — %s" % [str(act_d.get("label", "")), str(act_d.get("desc", ""))])
	_lbl_specialty.text = "\n".join(lines)

func _rebuild_equipment(prog: Dictionary) -> void:
	for c in _equip_vbox.get_children():
		c.queue_free()
	var eq_var: Variant = prog.get("equipment", {})
	var eq_d: Dictionary = eq_var as Dictionary if eq_var is Dictionary else {}
	var slot_labels: Dictionary = {"look_top": "Haut", "look_bottom": "Bas", "tool": "Outil", "fetish": "Fétiche"}
	for sl in CharacterSheetPanelSlotOrder:
		var iid: String = str(eq_d.get(sl, ""))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lbl: Label = Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 11)
		if iid != "":
			var idef: Dictionary = DataLoader.get_equipment_def(iid)
			lbl.text = "[%s] %s — %s" % [str(slot_labels.get(sl, sl)), str(idef.get("name", iid)), _format_item_bonus(idef)]
			row.add_child(lbl)
			var btn_rm: Button = Button.new()
			btn_rm.text = "Retirer"
			btn_rm.focus_mode = Control.FOCUS_NONE
			btn_rm.add_theme_font_size_override("font_size", 10)
			var sl_cap: String = sl
			btn_rm.pressed.connect(func() -> void:
				if GameState.unequip_slot(_active_char_id, sl_cap):
					AudioRadio.play_cassette_click()
					refresh()
			)
			row.add_child(btn_rm)
		else:
			lbl.text = "[%s] — Emplacement libre —" % str(slot_labels.get(sl, sl))
			lbl.add_theme_color_override("font_color", Color(0.58, 0.60, 0.66))
			row.add_child(lbl)
		_equip_vbox.add_child(row)

func _rebuild_stash() -> void:
	for c in _stash_vbox.get_children():
		c.queue_free()
	if GameState.box_stash.is_empty():
		var l_emp: Label = Label.new()
		l_emp.text = "• Coffre vide."
		l_emp.add_theme_font_size_override("font_size", 11)
		l_emp.add_theme_color_override("font_color", Color(0.62, 0.64, 0.70))
		_stash_vbox.add_child(l_emp)
		return
	var slot_labels: Dictionary = {"look_top": "Haut", "look_bottom": "Bas", "tool": "Outil", "fetish": "Fétiche"}
	for iid in GameState.box_stash:
		var idef: Dictionary = DataLoader.get_equipment_def(iid)
		if idef.is_empty():
			continue
		var sl: String = str(idef.get("slot", "tool"))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lbl: Label = Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.text = "• [%s] %s (%s)" % [str(slot_labels.get(sl, sl)), str(idef.get("name", iid)), _format_item_bonus(idef)]
		row.add_child(lbl)
		var btn_eq: Button = Button.new()
		btn_eq.text = "Équiper"
		btn_eq.focus_mode = Control.FOCUS_NONE
		btn_eq.add_theme_font_size_override("font_size", 10)
		var iid_cap: String = iid
		btn_eq.pressed.connect(func() -> void:
			if GameState.equip_item(_active_char_id, iid_cap):
				AudioRadio.play_cassette_click()
				refresh()
		)
		row.add_child(btn_eq)
		_stash_vbox.add_child(row)

func _rebuild_traits(prog: Dictionary) -> void:
	var tr_var: Variant = prog.get("traits", [])
	var lines: Array[String] = []
	if tr_var is Array:
		for tv in (tr_var as Array):
			lines.append("★ " + str(tv))
	if lines.is_empty():
		_lbl_traits.text = "• Aucun trait marqué pour l'instant (gagnés lors des scènes clés)."
	else:
		_lbl_traits.text = "\n".join(lines)

func _format_item_bonus(idef: Dictionary) -> String:
	var parts: Array[String] = []
	var sm_v: Variant = idef.get("stat_mods", {})
	if sm_v is Dictionary:
		var sm: Dictionary = sm_v as Dictionary
		for k in sm.keys():
			parts.append("%s %+d" % [str(k).capitalize(), int(sm.get(k, 0))])
	var skm_v: Variant = idef.get("skill_mods", {})
	if skm_v is Dictionary:
		var skm: Dictionary = skm_v as Dictionary
		for sk in skm.keys():
			var sname: String = str(DataLoader.get_skill_def(str(sk)).get("name", str(sk))).split(" ")[0]
			parts.append("%s %+d" % [sname, int(skm.get(sk, 0))])
	var act_v: Variant = idef.get("unlocks_actions", [])
	if act_v is Array and not (act_v as Array).is_empty():
		var first_a: Variant = (act_v as Array)[0]
		if first_a is Dictionary:
			parts.append("Action: " + str((first_a as Dictionary).get("label", "")))
	return ", ".join(parts) if not parts.is_empty() else str(idef.get("desc", ""))

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
