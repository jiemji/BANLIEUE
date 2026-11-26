## Écran « Nouvelle partie » : sélecteur de Pack Scénario isolé (Option 1B), mode Bande Neuve vs Import de Cassette (Option 3A),
## et personnalisation dynamique des portraits et archétypes du scénario choisi.
extends Control

signal start_game_requested(profile: Dictionary)
signal cancelled
signal scenario_preview_changed(scenario_id: String)

var _lbl_sub: Label = null
var _scenarios_hbox: HBoxContainer = null
var _lbl_scenario_synopsis: Label = null
var _import_hbox: HBoxContainer = null

var _name_edit: LineEdit = null
var _btn_rand_name: Button = null
var _port_grid: GridContainer = null
var _arch_grid: GridContainer = null
var _portrait_cards: Dictionary = {}
var _arch_buttons: Dictionary = {}

var _preview_portrait: TextureRect = null
var _preview_pawn: TextureRect = null
var _preview_port_label: Label = null

var _lbl_arch_title: Label = null
var _lbl_arch_sub: Label = null
var _lbl_arch_story: Label = null
var _lbl_arch_stakes: Label = null
var _lbl_arch_stats: Label = null
var _lbl_arch_spec: Label = null
var _lbl_arch_bonus: Label = null
var _lbl_squad_note: Label = null
var _lbl_summary: Label = null

var _selected_scenario_id: String = ""
var _selected_import_slot: int = 0
var _selected_portrait_id: String = ""
var _selected_archetype_id: String = ""
var _name_cycle_idx: int = 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false

func _make_style(bg: Color, border: Color, border_w: int = 2, pad: int = 12) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_content_margin_all(pad)
	return sb

func _build_ui() -> void:
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.03, 0.05, 0.86)
	add_child(shade)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_panel: PanelContainer = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(1180, 684)
	main_panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.08, 0.10, 0.97), Color(0.85, 0.17, 0.17), 3, 16))
	center.add_child(main_panel)

	var root_vb: VBoxContainer = VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 8)
	main_panel.add_child(root_vb)

	# En-tête + Sélecteur de Scénario + Mode Bande Neuve / Import Cassette
	var head_row: HBoxContainer = HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 12)
	root_vb.add_child(head_row)

	var head_vb: VBoxContainer = VBoxContainer.new()
	head_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_vb.add_theme_constant_override("separation", 2)
	head_row.add_child(head_vb)

	var lbl_title: Label = Label.new()
	lbl_title.text = "NOUVELLE PARTIE — SCÉNARIO & CHEF DE BANDE"
	lbl_title.add_theme_font_size_override("font_size", 20)
	lbl_title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	head_vb.add_child(lbl_title)

	_lbl_sub = Label.new()
	_lbl_sub.text = ""
	_lbl_sub.add_theme_font_size_override("font_size", 11)
	_lbl_sub.add_theme_color_override("font_color", Color(0.78, 0.81, 0.86))
	head_vb.add_child(_lbl_sub)

	var scen_bar: PanelContainer = PanelContainer.new()
	scen_bar.add_theme_stylebox_override("panel", _make_style(Color(0.11, 0.11, 0.14), Color(0.32, 0.34, 0.40), 1, 8))
	root_vb.add_child(scen_bar)

	var scen_vb: VBoxContainer = VBoxContainer.new()
	scen_vb.add_theme_constant_override("separation", 5)
	scen_bar.add_child(scen_vb)

	var top_scen_row: HBoxContainer = HBoxContainer.new()
	top_scen_row.add_theme_constant_override("separation", 10)
	scen_vb.add_child(top_scen_row)

	var l_sc_tag: Label = Label.new()
	l_sc_tag.text = "SCÉNARIO :"
	l_sc_tag.add_theme_font_size_override("font_size", 12)
	l_sc_tag.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	top_scen_row.add_child(l_sc_tag)

	_scenarios_hbox = HBoxContainer.new()
	_scenarios_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scenarios_hbox.add_theme_constant_override("separation", 6)
	top_scen_row.add_child(_scenarios_hbox)

	_import_hbox = HBoxContainer.new()
	_import_hbox.add_theme_constant_override("separation", 6)
	top_scen_row.add_child(_import_hbox)

	_lbl_scenario_synopsis = Label.new()
	_lbl_scenario_synopsis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_scenario_synopsis.add_theme_font_size_override("font_size", 11)
	_lbl_scenario_synopsis.add_theme_color_override("font_color", Color(0.84, 0.86, 0.90))
	scen_vb.add_child(_lbl_scenario_synopsis)

	# Corps en 2 colonnes
	var cols: HBoxContainer = HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	root_vb.add_child(cols)

	# === COLONNE GAUCHE : Identité & Galerie de portraits libres ===
	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(440, 0)
	left_col.add_theme_constant_override("separation", 6)
	cols.add_child(left_col)

	var lbl_id: Label = Label.new()
	lbl_id.text = "1. PRÉNOM / SURNOM"
	lbl_id.add_theme_font_size_override("font_size", 12)
	lbl_id.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	left_col.add_child(lbl_id)

	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	left_col.add_child(name_row)

	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.max_length = 20
	_name_edit.placeholder_text = "Ton prénom ou surnom..."
	_name_edit.text_changed.connect(func(_t: String) -> void: _update_summary())
	name_row.add_child(_name_edit)

	_btn_rand_name = Button.new()
	_btn_rand_name.text = "Aléa"
	_btn_rand_name.custom_minimum_size = Vector2(72, 30)
	_btn_rand_name.pressed.connect(_on_cycle_name)
	name_row.add_child(_btn_rand_name)

	var lbl_port: Label = Label.new()
	lbl_port.text = "2. PORTRAIT & PION (CHOIX LIBRE — 100 % COSMÉTIQUE)"
	lbl_port.add_theme_font_size_override("font_size", 12)
	lbl_port.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	left_col.add_child(lbl_port)

	_port_grid = GridContainer.new()
	_port_grid.columns = 3
	_port_grid.add_theme_constant_override("h_separation", 8)
	_port_grid.add_theme_constant_override("v_separation", 6)
	left_col.add_child(_port_grid)

	# Aperçu portrait + pion assorti
	var prev_card: PanelContainer = PanelContainer.new()
	prev_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prev_card.add_theme_stylebox_override("panel", _make_style(Color(0.10, 0.10, 0.13), Color(0.30, 0.32, 0.38), 1, 8))
	left_col.add_child(prev_card)

	var prev_hb: HBoxContainer = HBoxContainer.new()
	prev_hb.add_theme_constant_override("separation", 12)
	prev_card.add_child(prev_hb)

	_preview_portrait = TextureRect.new()
	_preview_portrait.custom_minimum_size = Vector2(112, 112)
	_preview_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	prev_hb.add_child(_preview_portrait)

	_preview_pawn = TextureRect.new()
	_preview_pawn.custom_minimum_size = Vector2(72, 116)
	_preview_pawn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_pawn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_hb.add_child(_preview_pawn)

	var prev_info: VBoxContainer = VBoxContainer.new()
	prev_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_info.alignment = BoxContainer.ALIGNMENT_CENTER
	prev_info.add_theme_constant_override("separation", 4)
	prev_hb.add_child(prev_info)

	_preview_port_label = Label.new()
	_preview_port_label.text = ""
	_preview_port_label.add_theme_font_size_override("font_size", 14)
	_preview_port_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	prev_info.add_child(_preview_port_label)

	var lbl_neutral: Label = Label.new()
	lbl_neutral.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_neutral.text = "Pion en pied assemblé (tête + haut + bas).\nPortrait libre, sans contrainte de stats."
	lbl_neutral.add_theme_font_size_override("font_size", 11)
	lbl_neutral.add_theme_color_override("font_color", Color(0.68, 0.74, 0.82))
	prev_info.add_child(lbl_neutral)

	# === COLONNE DROITE : Archétypes & Histoire personnelle ===
	var right_col: VBoxContainer = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	cols.add_child(right_col)

	var lbl_arch_head: Label = Label.new()
	lbl_arch_head.text = "3. CHOISIS TON ARCHÉTYPE & TON HISTOIRE PERSONNELLE"
	lbl_arch_head.add_theme_font_size_override("font_size", 12)
	lbl_arch_head.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	right_col.add_child(lbl_arch_head)

	_arch_grid = GridContainer.new()
	_arch_grid.columns = 2
	_arch_grid.add_theme_constant_override("h_separation", 8)
	_arch_grid.add_theme_constant_override("v_separation", 6)
	right_col.add_child(_arch_grid)

	# Fiche de l'archétype sélectionné
	var arch_card: PanelContainer = PanelContainer.new()
	arch_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arch_card.add_theme_stylebox_override("panel", _make_style(Color(0.11, 0.11, 0.14), Color(0.95, 0.55, 0.16), 2, 12))
	right_col.add_child(arch_card)

	var a_vb: VBoxContainer = VBoxContainer.new()
	a_vb.add_theme_constant_override("separation", 6)
	arch_card.add_child(a_vb)

	_lbl_arch_title = Label.new()
	_lbl_arch_title.add_theme_font_size_override("font_size", 18)
	_lbl_arch_title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	a_vb.add_child(_lbl_arch_title)

	_lbl_arch_sub = Label.new()
	_lbl_arch_sub.add_theme_font_size_override("font_size", 12)
	_lbl_arch_sub.add_theme_color_override("font_color", Color(0.98, 0.84, 0.28))
	a_vb.add_child(_lbl_arch_sub)

	a_vb.add_child(HSeparator.new())

	_lbl_arch_story = Label.new()
	_lbl_arch_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_arch_story.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lbl_arch_story.add_theme_font_size_override("font_size", 13)
	_lbl_arch_story.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86))
	a_vb.add_child(_lbl_arch_story)

	_lbl_arch_stakes = Label.new()
	_lbl_arch_stakes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_arch_stakes.add_theme_font_size_override("font_size", 11)
	_lbl_arch_stakes.add_theme_color_override("font_color", Color(0.75, 0.84, 0.94))
	a_vb.add_child(_lbl_arch_stakes)

	a_vb.add_child(HSeparator.new())

	_lbl_arch_stats = Label.new()
	_lbl_arch_stats.add_theme_font_size_override("font_size", 12)
	_lbl_arch_stats.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	a_vb.add_child(_lbl_arch_stats)

	_lbl_arch_spec = Label.new()
	_lbl_arch_spec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_arch_spec.add_theme_font_size_override("font_size", 12)
	_lbl_arch_spec.add_theme_color_override("font_color", Color(0.32, 0.68, 0.95))
	a_vb.add_child(_lbl_arch_spec)

	_lbl_arch_bonus = Label.new()
	_lbl_arch_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_arch_bonus.add_theme_font_size_override("font_size", 11)
	_lbl_arch_bonus.add_theme_color_override("font_color", Color(0.86, 0.85, 0.78))
	a_vb.add_child(_lbl_arch_bonus)

	_lbl_squad_note = Label.new()
	_lbl_squad_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_squad_note.add_theme_font_size_override("font_size", 11)
	_lbl_squad_note.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	a_vb.add_child(_lbl_squad_note)

	root_vb.add_child(HSeparator.new())

	# Pied de page
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	root_vb.add_child(footer)

	var btn_back: Button = Button.new()
	btn_back.text = "◄ Retour Menu"
	btn_back.custom_minimum_size = Vector2(150, 38)
	btn_back.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		close_panel()
		cancelled.emit()
	)
	footer.add_child(btn_back)

	_lbl_summary = Label.new()
	_lbl_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_summary.add_theme_font_size_override("font_size", 14)
	_lbl_summary.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	footer.add_child(_lbl_summary)

	var btn_launch: Button = Button.new()
	btn_launch.text = "Lancer la partie ►"
	btn_launch.custom_minimum_size = Vector2(200, 38)
	btn_launch.add_theme_color_override("font_color", Color(0.98, 0.84, 0.28))
	btn_launch.pressed.connect(_on_launch_pressed)
	footer.add_child(btn_launch)

## Ouvre l'écran de création, découvre les scénarios disponibles et charge les options du scénario actif.
func open_panel() -> void:
	DataLoader.discover_scenarios()
	var target_scen: String = DataLoader.active_scenario_id if DataLoader.active_scenario_id != "" else DataLoader.get_default_scenario_id()
	_selected_import_slot = 0
	select_scenario(target_scen, false)
	visible = true

## Sélectionne un pack scénario isolé et reconstruit ses portraits, archétypes et options d'import.
func select_scenario(scenario_id: String, emit_preview: bool = true) -> void:
	if not DataLoader.ensure_scenario_loaded(scenario_id):
		return
	_selected_scenario_id = DataLoader.active_scenario_id
	if not bool(DataLoader.scenario_manifest.get("allow_import_cassette", true)):
		_selected_import_slot = 0

	_lbl_sub.text = str(DataLoader.scenario_manifest.get("new_game_subtitle", DataLoader.scenario_manifest.get("subtitle", "")))
	_lbl_scenario_synopsis.text = str(DataLoader.scenario_manifest.get("synopsis", ""))
	_lbl_squad_note.text = str(DataLoader.scenario_manifest.get("squad_start_note", ""))

	_rebuild_scenario_buttons()
	_rebuild_import_buttons()
	_rebuild_portrait_cards()
	_rebuild_archetype_buttons()

	_name_cycle_idx = 0
	var def_name: String = DataLoader.player_default_names[0] if not DataLoader.player_default_names.is_empty() else "Alex"
	_name_edit.text = def_name
	var first_port: String = str(DataLoader.player_portraits[0].get("id", "")) if not DataLoader.player_portraits.is_empty() else ""
	var first_arch: String = str(DataLoader.player_archetypes[0].get("id", "")) if not DataLoader.player_archetypes.is_empty() else ""

	if _selected_import_slot > 0:
		_apply_import_slot_preview(_selected_import_slot)
	else:
		_name_edit.editable = true
		_btn_rand_name.disabled = false
		_select_portrait(first_port, false)
		_select_archetype(first_arch, false)

	_update_summary()
	if emit_preview:
		scenario_preview_changed.emit(_selected_scenario_id)

func _rebuild_scenario_buttons() -> void:
	for c in _scenarios_hbox.get_children():
		c.queue_free()
	for sc_def in DataLoader.scenarios_catalog:
		var sid: String = str(sc_def.get("id", ""))
		var is_sel: bool = (sid == _selected_scenario_id)
		var btn: Button = Button.new()
		var era: String = str(sc_def.get("era", ""))
		btn.text = "%s%s" % [str(sc_def.get("title", sid)), (" · " + era) if era != "" else ""]
		btn.custom_minimum_size = Vector2(0, 30)
		btn.add_theme_font_size_override("font_size", 12)
		if is_sel:
			btn.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34))
			btn.add_theme_stylebox_override("normal", _make_style(Color(0.28, 0.14, 0.08), Color(0.98, 0.64, 0.22), 2, 6))
		var sid_cap: String = sid
		btn.pressed.connect(func() -> void:
			AudioRadio.play_cassette_click()
			select_scenario(sid_cap, true)
		)
		_scenarios_hbox.add_child(btn)

func _rebuild_import_buttons() -> void:
	for c in _import_hbox.get_children():
		c.queue_free()
	if not bool(DataLoader.scenario_manifest.get("allow_import_cassette", true)):
		return

	var l_mode: Label = Label.new()
	l_mode.text = "DÉPART :"
	l_mode.add_theme_font_size_override("font_size", 11)
	l_mode.add_theme_color_override("font_color", Color(0.42, 0.78, 0.98))
	_import_hbox.add_child(l_mode)

	var btn_fresh: Button = Button.new()
	btn_fresh.text = "Bande neuve"
	btn_fresh.custom_minimum_size = Vector2(0, 28)
	btn_fresh.add_theme_font_size_override("font_size", 11)
	if _selected_import_slot == 0:
		btn_fresh.add_theme_color_override("font_color", Color(0.98, 0.86, 0.34))
	btn_fresh.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		set_import_slot(0)
	)
	_import_hbox.add_child(btn_fresh)

	for slot_i in range(1, SaveManager.SLOT_COUNT + 1):
		var exists: bool = SaveManager.slot_exists(slot_i)
		var meta: Dictionary = SaveManager.read_slot_meta(slot_i) if exists else {}
		var b_imp: Button = Button.new()
		var badge_done: String = " ★" if bool(meta.get("scenario_completed", false)) else ""
		b_imp.text = "Import %s%s" % [SaveManager.get_slot_label(slot_i), badge_done]
		b_imp.custom_minimum_size = Vector2(0, 28)
		b_imp.add_theme_font_size_override("font_size", 11)
		b_imp.disabled = not exists
		if exists:
			b_imp.tooltip_text = "Importer %s (%s · %d membres · Notoriété %d)" % [
				str(meta.get("leader_name", "")),
				str(meta.get("scenario_title", "")),
				int(meta.get("squad_count", 3)),
				int(meta.get("notoriete", 1))
			]
		else:
			b_imp.tooltip_text = "Cassette vide"
		if _selected_import_slot == slot_i:
			b_imp.add_theme_color_override("font_color", Color(0.56, 0.96, 0.68))
			b_imp.add_theme_stylebox_override("normal", _make_style(Color(0.10, 0.24, 0.14), Color(0.46, 0.90, 0.56), 2, 5))
		var s_cap: int = slot_i
		b_imp.pressed.connect(func() -> void:
			AudioRadio.play_cassette_click()
			set_import_slot(s_cap)
		)
		_import_hbox.add_child(b_imp)

## Active ou désactive l'import d'une cassette de sauvegarde existante (0 = bande neuve, 1..3 = Cassette A..C).
func set_import_slot(slot_idx: int) -> void:
	if slot_idx > 0 and not SaveManager.slot_exists(slot_idx):
		return
	_selected_import_slot = clampi(slot_idx, 0, SaveManager.SLOT_COUNT)
	_rebuild_import_buttons()
	if _selected_import_slot > 0:
		_apply_import_slot_preview(_selected_import_slot)
	else:
		_name_edit.editable = true
		_btn_rand_name.disabled = false
	_update_summary()

func _apply_import_slot_preview(slot_idx: int) -> void:
	var meta: Dictionary = SaveManager.read_slot_meta(slot_idx)
	if meta.is_empty():
		return
	_name_edit.text = str(meta.get("leader_name", _name_edit.text))
	_name_edit.editable = false
	_btn_rand_name.disabled = true
	var pid: String = str(meta.get("portrait_id", _selected_portrait_id))
	var aid: String = str(meta.get("archetype_id", _selected_archetype_id))
	_select_portrait(pid, false)
	_select_archetype(aid, false)

func _rebuild_portrait_cards() -> void:
	for c in _port_grid.get_children():
		c.queue_free()
	_portrait_cards.clear()

	for pv in DataLoader.player_portraits:
		var pid: String = str(pv.get("id", ""))
		var ppath: String = str(pv.get("portrait", ""))
		var plabel: String = str(pv.get("label", pid))

		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(138, 104)
		card.add_theme_stylebox_override("panel", _make_style(Color(0.11, 0.11, 0.14), Color(0.30, 0.32, 0.38), 2, 4))
		_port_grid.add_child(card)
		_portrait_cards[pid] = card

		var btn_p: Button = Button.new()
		btn_p.flat = true
		btn_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var pid_cap: String = pid
		btn_p.pressed.connect(func() -> void: _select_portrait(pid_cap))
		card.add_child(btn_p)

		var cvb: VBoxContainer = VBoxContainer.new()
		cvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvb.set_anchors_preset(Control.PRESET_FULL_RECT)
		cvb.add_theme_constant_override("separation", 2)
		card.add_child(cvb)

		var p_tex: Texture2D = DataLoader.load_texture_safe(ppath)
		if p_tex != null:
			var tr: TextureRect = TextureRect.new()
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.custom_minimum_size = Vector2(114, 74)
			tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture = p_tex
			cvb.add_child(tr)
		else:
			var ph_lbl: Label = Label.new()
			ph_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ph_lbl.custom_minimum_size = Vector2(114, 74)
			ph_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			ph_lbl.text = "[Portrait]"
			ph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ph_lbl.add_theme_font_size_override("font_size", 11)
			cvb.add_child(ph_lbl)

		var plbl: Label = Label.new()
		plbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plbl.text = plabel
		plbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plbl.add_theme_font_size_override("font_size", 11)
		plbl.add_theme_color_override("font_color", Color(0.88, 0.87, 0.82))
		cvb.add_child(plbl)

func _rebuild_archetype_buttons() -> void:
	for c in _arch_grid.get_children():
		c.queue_free()
	_arch_buttons.clear()

	for av in DataLoader.player_archetypes:
		var aid: String = str(av.get("id", ""))
		var b_arch: Button = Button.new()
		b_arch.text = str(av.get("title", aid))
		b_arch.custom_minimum_size = Vector2(0, 36)
		b_arch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var aid_cap: String = aid
		b_arch.pressed.connect(func() -> void: _select_archetype(aid_cap))
		_arch_grid.add_child(b_arch)
		_arch_buttons[aid] = b_arch

## Ferme l'écran de création de partie.
func close_panel() -> void:
	visible = false

func _on_cycle_name() -> void:
	AudioRadio.play_cassette_click()
	if DataLoader.player_default_names.is_empty():
		return
	_name_cycle_idx = (_name_cycle_idx + 1) % DataLoader.player_default_names.size()
	_name_edit.text = DataLoader.player_default_names[_name_cycle_idx]
	_update_summary()

func _select_portrait(portrait_id: String, play_sfx: bool = true) -> void:
	if play_sfx:
		AudioRadio.play_cassette_click()
	var pdef: Dictionary = DataLoader.get_portrait_def(portrait_id)
	_selected_portrait_id = str(pdef.get("id", portrait_id))
	for pid_var in _portrait_cards.keys():
		var pid: String = str(pid_var)
		var card: PanelContainer = _portrait_cards[pid_var] as PanelContainer
		var is_sel: bool = (pid == _selected_portrait_id)
		var b_col: Color = Color(0.95, 0.55, 0.16) if is_sel else Color(0.28, 0.30, 0.36)
		var bg_col: Color = Color(0.16, 0.14, 0.11) if is_sel else Color(0.11, 0.11, 0.14)
		card.add_theme_stylebox_override("panel", _make_style(bg_col, b_col, 3 if is_sel else 1, 4))

	_preview_portrait.texture = DataLoader.load_texture_safe(str(pdef.get("portrait", "")))
	_preview_port_label.text = str(pdef.get("label", ""))
	_update_modular_preview()

## Assemble l'aperçu 256x526 combinant la tête du portrait choisi et les vêtements de départ de l'archétype.
func _update_modular_preview() -> void:
	if _preview_pawn == null:
		return
	var pdef: Dictionary = DataLoader.get_portrait_def(_selected_portrait_id)
	var adef: Dictionary = DataLoader.get_archetype_def(_selected_archetype_id)
	var head_p: String = str(pdef.get("head", ""))
	var top_p: String = str(pdef.get("default_top", ""))
	var bot_p: String = str(pdef.get("default_bottom", ""))

	var eq_var: Variant = adef.get("default_equipment", {})
	if eq_var is Dictionary:
		var eq_d: Dictionary = eq_var as Dictionary
		var top_id: String = str(eq_d.get("look_top", ""))
		if top_id != "":
			var top_sp: String = str(DataLoader.get_equipment_def(top_id).get("sprite", ""))
			if top_sp != "":
				top_p = top_sp
		var bot_id: String = str(eq_d.get("look_bottom", ""))
		if bot_id != "":
			var bot_sp: String = str(DataLoader.get_equipment_def(bot_id).get("sprite", ""))
			if bot_sp != "":
				bot_p = bot_sp

	_preview_pawn.texture = DataLoader.assemble_modular_pawn(head_p, top_p, bot_p)

func _select_archetype(arch_id: String, play_sfx: bool = true) -> void:
	if play_sfx:
		AudioRadio.play_cassette_click()
	var adef: Dictionary = DataLoader.get_archetype_def(arch_id)
	_selected_archetype_id = str(adef.get("id", arch_id))
	for aid_var in _arch_buttons.keys():
		var aid: String = str(aid_var)
		var btn: Button = _arch_buttons[aid_var] as Button
		var is_sel: bool = (aid == _selected_archetype_id)
		btn.modulate = Color(1.0, 0.78, 0.36) if is_sel else Color(0.84, 0.86, 0.90)

	_lbl_arch_title.text = str(adef.get("title", ""))
	_lbl_arch_sub.text = str(adef.get("subtitle", ""))
	_lbl_arch_story.text = str(adef.get("story", ""))
	_lbl_arch_stakes.text = "Enjeu intime : " + str(adef.get("stakes", ""))
	var ch_var: Variant = adef.get("characteristics", {})
	var ch_d: Dictionary = ch_var as Dictionary if ch_var is Dictionary else {}
	var sk_var: Variant = adef.get("skills", {})
	var sk_parts: Array[String] = []
	if sk_var is Dictionary:
		var sk_d: Dictionary = sk_var as Dictionary
		for sk_k in sk_d.keys():
			var sname: String = str(DataLoader.get_skill_def(str(sk_k)).get("name", str(sk_k))).split(" ")[0]
			sk_parts.append("%s %+d" % [sname, int(sk_d.get(sk_k, 0))])
	_lbl_arch_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_arch_stats.text = (
		"Esprit %d  ·  Corps %d  ·  Énergie %d\n" +
		"Attitude %d  |  Aura %d  |  Moral %d / %d  |  Seuil Stress %d (%s)\n" +
		"Compétences : %s"
	) % [
		int(ch_d.get("esprit", 3)),
		int(ch_d.get("corps", 3)),
		int(ch_d.get("energie", 3)),
		int(adef.get("attitude", 60)),
		int(adef.get("aura", 3)),
		int(adef.get("moral_start", 70)),
		int(adef.get("moral_max", 100)),
		int(adef.get("stress_threshold", 30)),
		str(adef.get("stress_name", "Stress")),
		", ".join(sk_parts)
	]
	_lbl_arch_spec.text = "Spécialité Frise [%s] : %s" % [
		str(adef.get("specialty_name", "")),
		str(adef.get("specialty_desc", ""))
	]
	_lbl_arch_bonus.text = "Atout de départ : " + str(adef.get("bonus_summary", ""))
	_update_modular_preview()
	_update_summary()

func _update_summary() -> void:
	var n: String = _name_edit.text.strip_edges()
	if n == "":
		n = "Alex"
	var adef: Dictionary = DataLoader.get_archetype_def(_selected_archetype_id)
	var scen_title: String = str(DataLoader.scenario_manifest.get("title", _selected_scenario_id))
	var imp_tag: String = (" [Import %s]" % SaveManager.get_slot_label(_selected_import_slot)) if _selected_import_slot > 0 else ""
	_lbl_summary.text = "« %s · %s » — %s%s" % [n, str(adef.get("title", "")), scen_title, imp_tag]

func _on_launch_pressed() -> void:
	AudioRadio.play_cassette_click()
	var n: String = _name_edit.text.strip_edges()
	if n == "":
		n = "Alex"
	var pdef: Dictionary = DataLoader.get_portrait_def(_selected_portrait_id)
	var profile: Dictionary = {
		"scenario_id": _selected_scenario_id,
		"import_slot_idx": _selected_import_slot,
		"name": n,
		"archetype_id": _selected_archetype_id,
		"portrait_id": _selected_portrait_id,
		"portrait_path": str(pdef.get("portrait", "")),
		"head_path": str(pdef.get("head", "")),
		"default_top_path": str(pdef.get("default_top", "")),
		"default_bottom_path": str(pdef.get("default_bottom", ""))
	}
	close_panel()
	start_game_requested.emit(profile)
