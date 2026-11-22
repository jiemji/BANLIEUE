## Écran « Nouvelle partie » : choix libre du prénom et du portrait/pion découplés de la sélection parmi 4 archétypes sociaux.
extends Control

signal start_game_requested(profile: Dictionary)
signal cancelled

var _name_edit: LineEdit = null
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
var _lbl_summary: Label = null

var _selected_portrait_id: String = "player_01"
var _selected_archetype_id: String = "enfant_dalle"
var _name_cycle_idx: int = 0
var _tex_cache: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false

func _make_style(bg: Color, border: Color, border_w: int = 2, pad: int = 14) -> StyleBoxFlat:
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
	main_panel.custom_minimum_size = Vector2(1160, 654)
	main_panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.08, 0.10, 0.97), Color(0.85, 0.17, 0.17), 3, 20))
	center.add_child(main_panel)

	var root_vb: VBoxContainer = VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 12)
	main_panel.add_child(root_vb)

	# En-tête
	var head_vb: VBoxContainer = VBoxContainer.new()
	head_vb.add_theme_constant_override("separation", 2)
	root_vb.add_child(head_vb)

	var lbl_title: Label = Label.new()
	lbl_title.text = "NOUVELLE PARTIE — QUI MÈNE LA BANDE ?"
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	head_vb.add_child(lbl_title)

	var lbl_sub: Label = Label.new()
	lbl_sub.text = "Choisis librement ton visage, ton prénom et ton histoire personnelle à Cradon-lès-Gonesse (1980–1984)."
	lbl_sub.add_theme_font_size_override("font_size", 12)
	lbl_sub.add_theme_color_override("font_color", Color(0.78, 0.81, 0.86))
	head_vb.add_child(lbl_sub)

	root_vb.add_child(HSeparator.new())

	# Corps en 2 colonnes
	var cols: HBoxContainer = HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 18)
	root_vb.add_child(cols)

	# === COLONNE GAUCHE : Identité & Galerie de portraits libres ===
	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(440, 0)
	left_col.add_theme_constant_override("separation", 8)
	cols.add_child(left_col)

	var lbl_id: Label = Label.new()
	lbl_id.text = "1. PRÉNOM / SURNOM"
	lbl_id.add_theme_font_size_override("font_size", 13)
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

	var btn_rand_name: Button = Button.new()
	btn_rand_name.text = "Aléa"
	btn_rand_name.custom_minimum_size = Vector2(72, 32)
	btn_rand_name.pressed.connect(_on_cycle_name)
	name_row.add_child(btn_rand_name)

	var lbl_port: Label = Label.new()
	lbl_port.text = "2. PORTRAIT & PION (CHOIX LIBRE — 100 % COSMÉTIQUE)"
	lbl_port.add_theme_font_size_override("font_size", 12)
	lbl_port.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	left_col.add_child(lbl_port)

	var port_grid: GridContainer = GridContainer.new()
	port_grid.columns = 3
	port_grid.add_theme_constant_override("h_separation", 8)
	port_grid.add_theme_constant_override("v_separation", 8)
	left_col.add_child(port_grid)

	for pv in DataLoader.player_portraits:
		var pid: String = str(pv.get("id", ""))
		var ppath: String = str(pv.get("portrait", ""))
		var plabel: String = str(pv.get("label", pid))

		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(138, 114)
		card.add_theme_stylebox_override("panel", _make_style(Color(0.11, 0.11, 0.14), Color(0.30, 0.32, 0.38), 2, 5))
		port_grid.add_child(card)
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
		cvb.add_theme_constant_override("separation", 3)
		card.add_child(cvb)

		var p_tex: Texture2D = _load_texture_safe(ppath)
		if p_tex != null:
			var tr: TextureRect = TextureRect.new()
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.custom_minimum_size = Vector2(118, 82)
			tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture = p_tex
			cvb.add_child(tr)
		else:
			var ph_lbl: Label = Label.new()
			ph_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ph_lbl.custom_minimum_size = Vector2(118, 82)
			ph_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			ph_lbl.text = "[À illustrer]\n1982"
			ph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ph_lbl.add_theme_font_size_override("font_size", 11)
			ph_lbl.add_theme_color_override("font_color", Color(0.74, 0.72, 0.66))
			cvb.add_child(ph_lbl)

		var plbl: Label = Label.new()
		plbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plbl.text = plabel
		plbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plbl.add_theme_font_size_override("font_size", 11)
		plbl.add_theme_color_override("font_color", Color(0.88, 0.87, 0.82))
		cvb.add_child(plbl)

	# Aperçu portrait + pion assorti
	var prev_card: PanelContainer = PanelContainer.new()
	prev_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prev_card.add_theme_stylebox_override("panel", _make_style(Color(0.10, 0.10, 0.13), Color(0.30, 0.32, 0.38), 1, 10))
	left_col.add_child(prev_card)

	var prev_hb: HBoxContainer = HBoxContainer.new()
	prev_hb.add_theme_constant_override("separation", 12)
	prev_card.add_child(prev_hb)

	_preview_portrait = TextureRect.new()
	_preview_portrait.custom_minimum_size = Vector2(128, 128)
	_preview_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	prev_hb.add_child(_preview_portrait)

	_preview_pawn = TextureRect.new()
	_preview_pawn.custom_minimum_size = Vector2(78, 128)
	_preview_pawn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_pawn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_hb.add_child(_preview_pawn)

	var prev_info: VBoxContainer = VBoxContainer.new()
	prev_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_info.alignment = BoxContainer.ALIGNMENT_CENTER
	prev_info.add_theme_constant_override("separation", 4)
	prev_hb.add_child(prev_info)

	_preview_port_label = Label.new()
	_preview_port_label.text = "Blouson cuir"
	_preview_port_label.add_theme_font_size_override("font_size", 14)
	_preview_port_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	prev_info.add_child(_preview_port_label)

	var lbl_neutral: Label = Label.new()
	lbl_neutral.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_neutral.text = "Pion en pied assorti sur la carte.\nAucune statistique ni contrainte liée à l'apparence."
	lbl_neutral.add_theme_font_size_override("font_size", 11)
	lbl_neutral.add_theme_color_override("font_color", Color(0.68, 0.74, 0.82))
	prev_info.add_child(lbl_neutral)

	# === COLONNE DROITE : 4 Archétypes & Histoire personnelle ===
	var right_col: VBoxContainer = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 10)
	cols.add_child(right_col)

	var lbl_arch_head: Label = Label.new()
	lbl_arch_head.text = "3. CHOISIS TON ARCHÉTYPE & TON HISTOIRE PERSONNELLE"
	lbl_arch_head.add_theme_font_size_override("font_size", 13)
	lbl_arch_head.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	right_col.add_child(lbl_arch_head)

	var arch_grid: GridContainer = GridContainer.new()
	arch_grid.columns = 2
	arch_grid.add_theme_constant_override("h_separation", 8)
	arch_grid.add_theme_constant_override("v_separation", 8)
	right_col.add_child(arch_grid)

	for av in DataLoader.player_archetypes:
		var aid: String = str(av.get("id", ""))
		var b_arch: Button = Button.new()
		b_arch.text = str(av.get("title", aid))
		b_arch.custom_minimum_size = Vector2(0, 40)
		b_arch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var aid_cap: String = aid
		b_arch.pressed.connect(func() -> void: _select_archetype(aid_cap))
		arch_grid.add_child(b_arch)
		_arch_buttons[aid] = b_arch

	# Fiche de l'archétype sélectionné
	var arch_card: PanelContainer = PanelContainer.new()
	arch_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arch_card.add_theme_stylebox_override("panel", _make_style(Color(0.11, 0.11, 0.14), Color(0.95, 0.55, 0.16), 2, 16))
	right_col.add_child(arch_card)

	var a_vb: VBoxContainer = VBoxContainer.new()
	a_vb.add_theme_constant_override("separation", 8)
	arch_card.add_child(a_vb)

	_lbl_arch_title = Label.new()
	_lbl_arch_title.add_theme_font_size_override("font_size", 20)
	_lbl_arch_title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	a_vb.add_child(_lbl_arch_title)

	_lbl_arch_sub = Label.new()
	_lbl_arch_sub.add_theme_font_size_override("font_size", 13)
	_lbl_arch_sub.add_theme_color_override("font_color", Color(0.98, 0.84, 0.28))
	a_vb.add_child(_lbl_arch_sub)

	a_vb.add_child(HSeparator.new())

	_lbl_arch_story = Label.new()
	_lbl_arch_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_arch_story.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lbl_arch_story.add_theme_font_size_override("font_size", 14)
	_lbl_arch_story.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86))
	a_vb.add_child(_lbl_arch_story)

	_lbl_arch_stakes = Label.new()
	_lbl_arch_stakes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_arch_stakes.add_theme_font_size_override("font_size", 12)
	_lbl_arch_stakes.add_theme_color_override("font_color", Color(0.75, 0.84, 0.94))
	a_vb.add_child(_lbl_arch_stakes)

	a_vb.add_child(HSeparator.new())

	_lbl_arch_stats = Label.new()
	_lbl_arch_stats.add_theme_font_size_override("font_size", 13)
	_lbl_arch_stats.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	a_vb.add_child(_lbl_arch_stats)

	_lbl_arch_spec = Label.new()
	_lbl_arch_spec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_arch_spec.add_theme_font_size_override("font_size", 13)
	_lbl_arch_spec.add_theme_color_override("font_color", Color(0.32, 0.68, 0.95))
	a_vb.add_child(_lbl_arch_spec)

	_lbl_arch_bonus = Label.new()
	_lbl_arch_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_arch_bonus.add_theme_font_size_override("font_size", 12)
	_lbl_arch_bonus.add_theme_color_override("font_color", Color(0.86, 0.85, 0.78))
	a_vb.add_child(_lbl_arch_bonus)

	var lbl_squad_note: Label = Label.new()
	lbl_squad_note.text = "Départ : Box-Garage de la Cité avec Karim & Nadia (« Couvre-Feu au Galaxian »)."
	lbl_squad_note.add_theme_font_size_override("font_size", 11)
	lbl_squad_note.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	a_vb.add_child(lbl_squad_note)

	root_vb.add_child(HSeparator.new())

	# Pied de page
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	root_vb.add_child(footer)

	var btn_back: Button = Button.new()
	btn_back.text = "◄ Retour Menu"
	btn_back.custom_minimum_size = Vector2(150, 40)
	btn_back.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		close_panel()
		cancelled.emit()
	)
	footer.add_child(btn_back)

	_lbl_summary = Label.new()
	_lbl_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_summary.add_theme_font_size_override("font_size", 15)
	_lbl_summary.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	footer.add_child(_lbl_summary)

	var btn_launch: Button = Button.new()
	btn_launch.text = "Lancer la partie ►"
	btn_launch.custom_minimum_size = Vector2(200, 40)
	btn_launch.add_theme_color_override("font_color", Color(0.98, 0.84, 0.28))
	btn_launch.pressed.connect(_on_launch_pressed)
	footer.add_child(btn_launch)

## Ouvre l'écran de création et réinitialise le prénom, le portrait et l'archétype par défaut.
func open_panel() -> void:
	if DataLoader.player_portraits.is_empty() or DataLoader.player_archetypes.is_empty():
		DataLoader.load_all()
	_name_cycle_idx = 0
	var def_name: String = DataLoader.player_default_names[0] if not DataLoader.player_default_names.is_empty() else "Alex"
	_name_edit.text = def_name
	var first_port: String = str(DataLoader.player_portraits[0].get("id", "player_01")) if not DataLoader.player_portraits.is_empty() else "player_01"
	var first_arch: String = str(DataLoader.player_archetypes[0].get("id", "enfant_dalle")) if not DataLoader.player_archetypes.is_empty() else "enfant_dalle"
	_select_portrait(first_port, false)
	_select_archetype(first_arch, false)
	_update_summary()
	visible = true

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
	_selected_portrait_id = portrait_id
	for pid_var in _portrait_cards.keys():
		var pid: String = str(pid_var)
		var card: PanelContainer = _portrait_cards[pid_var] as PanelContainer
		var is_sel: bool = (pid == _selected_portrait_id)
		var b_col: Color = Color(0.95, 0.55, 0.16) if is_sel else Color(0.28, 0.30, 0.36)
		var bg_col: Color = Color(0.16, 0.14, 0.11) if is_sel else Color(0.11, 0.11, 0.14)
		card.add_theme_stylebox_override("panel", _make_style(bg_col, b_col, 3 if is_sel else 1, 5))

	var pdef: Dictionary = DataLoader.get_portrait_def(_selected_portrait_id)
	var p_tex: Texture2D = _load_texture_safe(str(pdef.get("portrait", "")))
	var pw_tex: Texture2D = _load_texture_safe(str(pdef.get("pawn", "")))
	var is_fallback: bool = (p_tex == null or pw_tex == null)
	if p_tex == null:
		p_tex = _load_texture_safe("res://assets/portraits/leader.png")
	if pw_tex == null:
		pw_tex = _load_texture_safe("res://assets/pawns/leader_pawn.png")
	_preview_portrait.texture = p_tex
	_preview_pawn.texture = pw_tex
	var base_lbl: String = str(pdef.get("label", ""))
	_preview_port_label.text = ("%s (visuel provisoire — génération en attente)" % base_lbl) if is_fallback else base_lbl

func _select_archetype(arch_id: String, play_sfx: bool = true) -> void:
	if play_sfx:
		AudioRadio.play_cassette_click()
	_selected_archetype_id = arch_id
	for aid_var in _arch_buttons.keys():
		var aid: String = str(aid_var)
		var btn: Button = _arch_buttons[aid_var] as Button
		var is_sel: bool = (aid == _selected_archetype_id)
		btn.modulate = Color(1.0, 0.78, 0.36) if is_sel else Color(0.84, 0.86, 0.90)

	var adef: Dictionary = DataLoader.get_archetype_def(_selected_archetype_id)
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
	_update_summary()

func _update_summary() -> void:
	var n: String = _name_edit.text.strip_edges()
	if n == "":
		n = "Alex"
	var adef: Dictionary = DataLoader.get_archetype_def(_selected_archetype_id)
	_lbl_summary.text = "« %s · %s »" % [n, str(adef.get("title", ""))]

func _on_launch_pressed() -> void:
	AudioRadio.play_cassette_click()
	var n: String = _name_edit.text.strip_edges()
	if n == "":
		n = "Alex"
	var pdef: Dictionary = DataLoader.get_portrait_def(_selected_portrait_id)
	var profile: Dictionary = {
		"name": n,
		"archetype_id": _selected_archetype_id,
		"portrait_id": _selected_portrait_id,
		"portrait_path": str(pdef.get("portrait", "")),
		"pawn_path": str(pdef.get("pawn", ""))
	}
	close_panel()
	start_game_requested.emit(profile)

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
