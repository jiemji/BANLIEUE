## Modale des options (affichage, audio/FM, grain pellicule 16mm, secousse écran, taille des dialogues).
extends Control

signal closed

var _btn_windowed: Button = null
var _btn_fullscreen: Button = null
var _slider_volume: HSlider = null
var _lbl_volume_val: Label = null
var _btn_mute: Button = null
var _btn_radio: Button = null
var _btn_grain_off: Button = null
var _btn_grain_light: Button = null
var _btn_grain_1982: Button = null
var _btn_shake: Button = null
var _btn_font_normal: Button = null
var _btn_font_large: Button = null

var _suppress_callbacks: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	SettingsManager.settings_changed.connect(_sync_from_settings)
	visible = false

func _make_style(bg: Color, border: Color, border_w: int = 2, pad: int = 20) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_content_margin_all(pad)
	return sb

func _build_ui() -> void:
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.03, 0.05, 0.80)
	add_child(shade)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 560)
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.08, 0.10, 0.97), Color(0.85, 0.17, 0.17), 3, 22))
	center.add_child(panel)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var lbl_title: Label = Label.new()
	lbl_title.text = "OPTIONS — RÉGLAGES 1982"
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	vb.add_child(lbl_title)

	vb.add_child(HSeparator.new())

	# 1. Affichage
	var row_disp: HBoxContainer = _make_option_row("Affichage")
	vb.add_child(row_disp)
	_btn_windowed = Button.new()
	_btn_windowed.text = "Fenêtré"
	_btn_windowed.custom_minimum_size = Vector2(130, 34)
	_btn_windowed.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		SettingsManager.set_fullscreen(false)
	)
	row_disp.add_child(_btn_windowed)
	_btn_fullscreen = Button.new()
	_btn_fullscreen.text = "Plein écran"
	_btn_fullscreen.custom_minimum_size = Vector2(130, 34)
	_btn_fullscreen.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		SettingsManager.set_fullscreen(true)
	)
	row_disp.add_child(_btn_fullscreen)

	# 2. Volume général
	var row_vol: HBoxContainer = _make_option_row("Volume général")
	vb.add_child(row_vol)
	_slider_volume = HSlider.new()
	_slider_volume.min_value = 0.0
	_slider_volume.max_value = 100.0
	_slider_volume.step = 5.0
	_slider_volume.custom_minimum_size = Vector2(210, 28)
	_slider_volume.value_changed.connect(_on_volume_changed)
	row_vol.add_child(_slider_volume)
	_lbl_volume_val = Label.new()
	_lbl_volume_val.custom_minimum_size = Vector2(54, 0)
	_lbl_volume_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_volume_val.add_theme_font_size_override("font_size", 13)
	row_vol.add_child(_lbl_volume_val)

	# 3. Couper le son
	var row_mute: HBoxContainer = _make_option_row("Couper le son")
	vb.add_child(row_mute)
	_btn_mute = Button.new()
	_btn_mute.custom_minimum_size = Vector2(160, 34)
	_btn_mute.pressed.connect(func() -> void:
		SettingsManager.set_muted(not SettingsManager.muted)
		AudioRadio.play_cassette_click()
	)
	row_mute.add_child(_btn_mute)

	# 4. Ambiance Radio FM
	var row_radio: HBoxContainer = _make_option_row("Ambiance Radio FM / Cold Wave")
	vb.add_child(row_radio)
	_btn_radio = Button.new()
	_btn_radio.custom_minimum_size = Vector2(160, 34)
	_btn_radio.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		SettingsManager.set_radio_ambience(not SettingsManager.radio_ambience)
	)
	row_radio.add_child(_btn_radio)

	# 5. Grain pellicule 16mm
	var row_grain: HBoxContainer = _make_option_row("Grain pellicule 16mm")
	vb.add_child(row_grain)
	_btn_grain_off = Button.new()
	_btn_grain_off.text = "Désactivé"
	_btn_grain_off.custom_minimum_size = Vector2(96, 34)
	_btn_grain_off.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		SettingsManager.set_grain_level("off")
	)
	row_grain.add_child(_btn_grain_off)

	_btn_grain_light = Button.new()
	_btn_grain_light.text = "Léger"
	_btn_grain_light.custom_minimum_size = Vector2(96, 34)
	_btn_grain_light.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		SettingsManager.set_grain_level("light")
	)
	row_grain.add_child(_btn_grain_light)

	_btn_grain_1982 = Button.new()
	_btn_grain_1982.text = "1982"
	_btn_grain_1982.custom_minimum_size = Vector2(96, 34)
	_btn_grain_1982.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		SettingsManager.set_grain_level("1982")
	)
	row_grain.add_child(_btn_grain_1982)

	# 6. Secousse d'écran
	var row_shake: HBoxContainer = _make_option_row("Secousse d'écran (Boeing / Crise)")
	vb.add_child(row_shake)
	_btn_shake = Button.new()
	_btn_shake.custom_minimum_size = Vector2(160, 34)
	_btn_shake.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		SettingsManager.set_screen_shake(not SettingsManager.screen_shake)
	)
	row_shake.add_child(_btn_shake)

	# 7. Taille des textes de dialogue
	var row_font: HBoxContainer = _make_option_row("Taille des textes de dialogue")
	vb.add_child(row_font)
	_btn_font_normal = Button.new()
	_btn_font_normal.text = "Normale"
	_btn_font_normal.custom_minimum_size = Vector2(130, 34)
	_btn_font_normal.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		SettingsManager.set_dialogue_font_scale("normal")
	)
	row_font.add_child(_btn_font_normal)
	_btn_font_large = Button.new()
	_btn_font_large.text = "Grande"
	_btn_font_large.custom_minimum_size = Vector2(130, 34)
	_btn_font_large.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		SettingsManager.set_dialogue_font_scale("large")
	)
	row_font.add_child(_btn_font_large)

	vb.add_child(HSeparator.new())

	# Rappel des commandes
	var keys_box: PanelContainer = PanelContainer.new()
	keys_box.add_theme_stylebox_override("panel", _make_style(Color(0.11, 0.11, 0.14), Color(0.28, 0.30, 0.36), 1, 10))
	vb.add_child(keys_box)

	var lbl_keys: Label = Label.new()
	lbl_keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_keys.text = "Raccourcis :  Échap = Menu / Fermer   •   Backspace = Dézoomer (N4→N1)   •   M = Plan de Cradon   •   1/2/3 = Basculer de groupe   •   ZQSD / Flèches = Caméra"
	lbl_keys.add_theme_font_size_override("font_size", 11)
	lbl_keys.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	keys_box.add_child(lbl_keys)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vb.add_child(footer)

	var btn_reset: Button = Button.new()
	btn_reset.text = "Réinitialiser par défaut"
	btn_reset.custom_minimum_size = Vector2(180, 38)
	btn_reset.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		SettingsManager.reset_defaults()
	)
	footer.add_child(btn_reset)

	var f_spacer: Control = Control.new()
	f_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(f_spacer)

	var btn_close: Button = Button.new()
	btn_close.text = "◄ Fermer [Échap]"
	btn_close.custom_minimum_size = Vector2(160, 38)
	btn_close.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		close_panel()
		closed.emit()
	)
	footer.add_child(btn_close)

func _make_option_row(label_txt: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl: Label = Label.new()
	lbl.text = label_txt
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86))
	row.add_child(lbl)
	return row

## Ouvre la modale Options et synchronise les contrôles avec SettingsManager.
func open_panel() -> void:
	_sync_from_settings()
	visible = true

## Ferme la modale Options.
func close_panel() -> void:
	visible = false

func _on_volume_changed(val: float) -> void:
	if _suppress_callbacks:
		return
	SettingsManager.set_master_volume(val / 100.0)

func _sync_from_settings() -> void:
	_suppress_callbacks = true
	var fs: bool = SettingsManager.fullscreen
	_style_choice(_btn_windowed, not fs)
	_style_choice(_btn_fullscreen, fs)

	var vol_pct: int = roundi(SettingsManager.master_volume * 100.0)
	_slider_volume.value = float(vol_pct)
	_lbl_volume_val.text = "%d %%" % vol_pct

	_btn_mute.text = "Son coupé : OUI" if SettingsManager.muted else "Son coupé : NON"
	_style_choice(_btn_mute, SettingsManager.muted)

	_btn_radio.text = "Radio FM : ON" if SettingsManager.radio_ambience else "Radio FM : OFF"
	_style_choice(_btn_radio, SettingsManager.radio_ambience)

	_style_choice(_btn_grain_off, SettingsManager.grain_level == "off")
	_style_choice(_btn_grain_light, SettingsManager.grain_level == "light")
	_style_choice(_btn_grain_1982, SettingsManager.grain_level == "1982")

	_btn_shake.text = "Secousse : ON" if SettingsManager.screen_shake else "Secousse : OFF"
	_style_choice(_btn_shake, SettingsManager.screen_shake)

	_style_choice(_btn_font_normal, SettingsManager.dialogue_font_scale == "normal")
	_style_choice(_btn_font_large, SettingsManager.dialogue_font_scale == "large")
	_suppress_callbacks = false

func _style_choice(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	btn.modulate = Color(1.0, 0.78, 0.36) if selected else Color(0.86, 0.88, 0.92)
