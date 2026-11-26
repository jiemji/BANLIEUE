## Panneau de Menu unifié servant à la fois d'Écran d'accueil ("title") et de Menu Pause en jeu ("pause").
extends Control

signal resume_requested
signal new_game_requested
signal load_game_requested
signal save_game_requested
signal options_requested
signal return_title_requested
signal quit_requested

var _mode: String = "title" # "title" | "pause"
var _dimmer: ColorRect = null
var _lbl_sub: Label = null
var _lbl_mode_tag: Label = null
var _btn_resume: Button = null
var _btn_new_game: Button = null
var _btn_load: Button = null
var _btn_save: Button = null
var _btn_options: Button = null
var _sep_bottom: HSeparator = null
var _btn_return_title: Button = null
var _btn_quit: Button = null
var _lbl_fm: Label = null
var _lbl_ambient: Label = null

var _confirm_overlay: ColorRect = null
var _lbl_confirm: Label = null
var _pending_action: String = ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	visible = false

func _make_style(bg: Color, border: Color, border_w: int = 3, pad: int = 22) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_content_margin_all(pad)
	return sb

func _build_ui() -> void:
	_dimmer = ColorRect.new()
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.color = Color(0.03, 0.03, 0.05, 0.65)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_dimmer.visible = false
	add_child(_dimmer)

	var col_panel: PanelContainer = PanelContainer.new()
	col_panel.position = Vector2(36, 36)
	col_panel.size = Vector2(380, 648)
	col_panel.add_theme_stylebox_override("panel", _make_style(Color(0.07, 0.07, 0.09, 0.94), Color(0.85, 0.17, 0.17), 3, 24))
	add_child(col_panel)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	col_panel.add_child(vb)

	var lbl_title: Label = Label.new()
	lbl_title.text = "BANLIEUE"
	lbl_title.add_theme_font_size_override("font_size", 40)
	lbl_title.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	vb.add_child(lbl_title)

	_lbl_sub = Label.new()
	_lbl_sub.text = "JDR TACTIQUE & CHRONIQUES DE RUE"
	_lbl_sub.clip_text = true
	_lbl_sub.add_theme_font_size_override("font_size", 13)
	_lbl_sub.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	vb.add_child(_lbl_sub)

	_lbl_mode_tag = Label.new()
	_lbl_mode_tag.text = "ÉCRAN D'ACCUEIL"
	_lbl_mode_tag.add_theme_font_size_override("font_size", 11)
	_lbl_mode_tag.add_theme_color_override("font_color", Color(0.58, 0.68, 0.78))
	vb.add_child(_lbl_mode_tag)

	vb.add_child(HSeparator.new())

	_btn_resume = _make_menu_button("►  Reprendre la partie", Color(0.98, 0.84, 0.28))
	_btn_resume.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		resume_requested.emit()
	)
	vb.add_child(_btn_resume)

	_btn_new_game = _make_menu_button("Nouvelle partie", Color(0.96, 0.94, 0.88))
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	vb.add_child(_btn_new_game)

	_btn_load = _make_menu_button("Charger une partie", Color(0.96, 0.94, 0.88))
	_btn_load.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		load_game_requested.emit()
	)
	vb.add_child(_btn_load)

	_btn_save = _make_menu_button("Sauvegarder la partie", Color(0.96, 0.94, 0.88))
	_btn_save.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		save_game_requested.emit()
	)
	vb.add_child(_btn_save)

	_btn_options = _make_menu_button("Options", Color(0.96, 0.94, 0.88))
	_btn_options.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		options_requested.emit()
	)
	vb.add_child(_btn_options)

	_sep_bottom = HSeparator.new()
	vb.add_child(_sep_bottom)

	_btn_return_title = _make_menu_button("Retour à l'accueil", Color(0.86, 0.84, 0.78))
	_btn_return_title.pressed.connect(_on_return_title_pressed)
	vb.add_child(_btn_return_title)

	_btn_quit = _make_menu_button("Quitter", Color(0.92, 0.42, 0.38))
	_btn_quit.pressed.connect(_on_quit_pressed)
	vb.add_child(_btn_quit)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	vb.add_child(HSeparator.new())

	_lbl_fm = Label.new()
	_lbl_fm.text = "[FM]"
	_lbl_fm.add_theme_font_size_override("font_size", 12)
	_lbl_fm.add_theme_color_override("font_color", Color(0.32, 0.68, 0.95))
	vb.add_child(_lbl_fm)

	_lbl_ambient = Label.new()
	_lbl_ambient.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_ambient.text = "Cycle Jour / Nuit"
	_lbl_ambient.add_theme_font_size_override("font_size", 11)
	_lbl_ambient.add_theme_color_override("font_color", Color(0.76, 0.78, 0.82))
	vb.add_child(_lbl_ambient)

	# Popup de confirmation intégrée
	_confirm_overlay = ColorRect.new()
	_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.color = Color(0.02, 0.02, 0.04, 0.75)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.visible = false
	add_child(_confirm_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.add_child(center)

	var c_panel: PanelContainer = PanelContainer.new()
	c_panel.custom_minimum_size = Vector2(460, 180)
	c_panel.add_theme_stylebox_override("panel", _make_style(Color(0.09, 0.09, 0.12), Color(0.95, 0.55, 0.16), 3, 20))
	center.add_child(c_panel)

	var c_vb: VBoxContainer = VBoxContainer.new()
	c_vb.add_theme_constant_override("separation", 16)
	c_panel.add_child(c_vb)

	_lbl_confirm = Label.new()
	_lbl_confirm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_confirm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lbl_confirm.add_theme_font_size_override("font_size", 14)
	_lbl_confirm.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	c_vb.add_child(_lbl_confirm)

	var c_row: HBoxContainer = HBoxContainer.new()
	c_row.add_theme_constant_override("separation", 12)
	c_row.alignment = BoxContainer.ALIGNMENT_END
	c_vb.add_child(c_row)

	var btn_cancel: Button = Button.new()
	btn_cancel.text = "Annuler"
	btn_cancel.custom_minimum_size = Vector2(110, 36)
	btn_cancel.pressed.connect(close_confirm)
	c_row.add_child(btn_cancel)

	var btn_ok: Button = Button.new()
	btn_ok.text = "Confirmer"
	btn_ok.custom_minimum_size = Vector2(120, 36)
	btn_ok.pressed.connect(_on_confirm_accepted)
	c_row.add_child(btn_ok)

func _make_menu_button(label_txt: String, font_col: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = label_txt
	btn.custom_minimum_size = Vector2(0, 40)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", font_col)
	return btn

## Affiche le menu dans le mode demandé ("title" ou "pause") et rafraîchit l'état des boutons.
func open_menu(mode: String) -> void:
	_mode = "pause" if mode == "pause" else "title"
	_confirm_overlay.visible = false
	_pending_action = ""
	visible = true
	refresh_state()

## Masque le menu et réinitialise toute boîte de confirmation ouverte.
func close_menu() -> void:
	_confirm_overlay.visible = false
	_pending_action = ""
	visible = false

## Actualise la disponibilité des actions (Charger, Sauvegarder, Reprendre) et la ligne d'état du scénario actif.
func refresh_state() -> void:
	var is_pause: bool = (_mode == "pause")
	_dimmer.visible = is_pause
	var scen_sub: String = str(DataLoader.scenario_manifest.get("subtitle", ""))
	if scen_sub != "" and _lbl_sub != null:
		_lbl_sub.text = scen_sub
	var scen_title: String = str(DataLoader.scenario_manifest.get("title", ""))
	_lbl_mode_tag.text = ("PAUSE — %s" % scen_title) if (is_pause and scen_title != "") else ("PAUSE — PARTIE EN COURS" if is_pause else "ÉCRAN D'ACCUEIL")
	_btn_resume.visible = is_pause
	_btn_return_title.visible = is_pause

	var any_save: bool = SaveManager.has_any_save()
	_btn_load.disabled = not any_save
	_btn_load.tooltip_text = "" if any_save else "Aucune cassette enregistrée"

	_btn_save.disabled = not is_pause
	_btn_save.tooltip_text = "" if is_pause else "Disponible en cours de partie"

	if not DataLoader.radio_stations.is_empty():
		var st_idx: int = GameState.current_station_idx % DataLoader.radio_stations.size()
		var st_dict: Dictionary = DataLoader.radio_stations[st_idx]
		_lbl_fm.text = "[FM %s · %s]" % [str(st_dict.get("freq", "")), str(st_dict.get("name", ""))]

	if is_pause:
		var lp_name: String = str(GameState.leader_profile.get("name", "Alex"))
		var loc_id: String = GameState.get_active_location_id()
		var loc_name: String = str(DataLoader.get_location(loc_id).get("name", loc_id))
		_lbl_ambient.text = "%s · %s (%s)" % [lp_name, loc_name, GameState.format_clock()]

## Met à jour le libellé de phase du fond vivant lorsque le menu est en mode accueil.
func set_ambient_phase_label(phase_txt: String) -> void:
	if _lbl_ambient != null and _mode == "title":
		_lbl_ambient.text = phase_txt

## Indique si une popup de confirmation est actuellement affichée.
func has_confirm_open() -> bool:
	return _confirm_overlay != null and _confirm_overlay.visible

## Ferme la popup de confirmation sans exécuter l'action en attente.
func close_confirm() -> void:
	if _confirm_overlay != null:
		_confirm_overlay.visible = false
	_pending_action = ""

func _open_confirm(action_id: String, msg: String) -> void:
	_pending_action = action_id
	_lbl_confirm.text = msg
	_confirm_overlay.visible = true

func _on_new_game_pressed() -> void:
	AudioRadio.play_cassette_click()
	if _mode == "pause":
		_open_confirm("new_game", "Lancer une nouvelle partie ?\nLa progression non sauvegardée de la session en cours sera perdue.")
	else:
		new_game_requested.emit()

func _on_return_title_pressed() -> void:
	AudioRadio.play_cassette_click()
	_open_confirm("return_title", "Revenir à l'écran d'accueil ?\nPense à sauvegarder sur une cassette si tu veux reprendre ici.")

func _on_quit_pressed() -> void:
	AudioRadio.play_cassette_click()
	if _mode == "pause":
		_open_confirm("quit", "Quitter Banlieue maintenant ?\nToute progression non sauvegardée sur une cassette sera perdue.")
	else:
		quit_requested.emit()

func _on_confirm_accepted() -> void:
	var act: String = _pending_action
	close_confirm()
	AudioRadio.play_cassette_click()
	if act == "new_game":
		new_game_requested.emit()
	elif act == "return_title":
		return_title_requested.emit()
	elif act == "quit":
		quit_requested.emit()
