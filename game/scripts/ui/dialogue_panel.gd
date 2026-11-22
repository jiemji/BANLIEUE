## Boîte de dialogue BD/fanzine : portraits, bandeau verdict _roll_banner et badges de probabilité 🎲 % / Faille.
extends Control

signal choice_selected(choice_index: int)

var _panel: PanelContainer = null
var _lbl_speaker: Label = null
var _roll_banner: PanelContainer = null
var _roll_banner_style: StyleBoxFlat = null
var _lbl_roll_result: Label = null
var _lbl_text: Label = null
var _choices_box: VBoxContainer = null
var _portrait_frame: PanelContainer = null
var _portrait_style: StyleBoxFlat = null
var _portrait_tex: TextureRect = null
var _portrait_rect: ColorRect = null
var _tex_cache: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	SettingsManager.settings_changed.connect(_apply_text_size)
	_apply_text_size()
	visible = false

## Synchronise la taille de police du dialogue avec SettingsManager (Normale ou Grande).
func _apply_text_size() -> void:
	if _lbl_text != null:
		_lbl_text.add_theme_font_size_override("font_size", SettingsManager.get_dialogue_font_size())
	if _lbl_speaker != null:
		_lbl_speaker.add_theme_font_size_override("font_size", SettingsManager.get_dialogue_font_size() + 2)
	if _lbl_roll_result != null:
		_lbl_roll_result.add_theme_font_size_override("font_size", maxi(12, SettingsManager.get_dialogue_font_size() - 1))

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(18, 404)
	_panel.size = Vector2(886, 304)
	_panel.clip_contents = true
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.10, 0.96)
	sb.border_color = Color(0.95, 0.55, 0.16)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var main_hbox: HBoxContainer = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 12)
	_panel.add_child(main_hbox)

	# Portrait stylisé BD/fanzine à gauche
	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(126, 0)
	main_hbox.add_child(left_col)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.custom_minimum_size = Vector2(124, 124)
	_portrait_style = StyleBoxFlat.new()
	_portrait_style.bg_color = Color(0.11, 0.11, 0.13)
	_portrait_style.border_color = Color(0.95, 0.55, 0.16)
	_portrait_style.set_border_width_all(3)
	_portrait_style.set_content_margin_all(3)
	_portrait_frame.add_theme_stylebox_override("panel", _portrait_style)
	left_col.add_child(_portrait_frame)

	_portrait_tex = TextureRect.new()
	_portrait_tex.custom_minimum_size = Vector2(114, 114)
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_tex.visible = false
	_portrait_frame.add_child(_portrait_tex)

	_portrait_rect = ColorRect.new()
	_portrait_rect.custom_minimum_size = Vector2(114, 114)
	_portrait_rect.color = Color(0.95, 0.55, 0.16)
	_portrait_frame.add_child(_portrait_rect)

	var right_col: VBoxContainer = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 6)
	main_hbox.add_child(right_col)

	_lbl_speaker = Label.new()
	_lbl_speaker.add_theme_font_size_override("font_size", 16)
	_lbl_speaker.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	right_col.add_child(_lbl_speaker)

	_roll_banner = PanelContainer.new()
	_roll_banner.visible = false
	_roll_banner_style = StyleBoxFlat.new()
	_roll_banner_style.bg_color = Color(0.11, 0.14, 0.11, 0.96)
	_roll_banner_style.border_color = Color(0.45, 0.85, 0.45)
	_roll_banner_style.set_border_width_all(1)
	_roll_banner_style.set_content_margin_all(5)
	_roll_banner.add_theme_stylebox_override("panel", _roll_banner_style)
	right_col.add_child(_roll_banner)

	_lbl_roll_result = Label.new()
	_lbl_roll_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_roll_result.add_theme_font_size_override("font_size", 12)
	_lbl_roll_result.add_theme_color_override("font_color", Color(0.94, 0.94, 0.88))
	_roll_banner.add_child(_lbl_roll_result)

	_lbl_text = Label.new()
	_lbl_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lbl_text.add_theme_font_size_override("font_size", 14)
	_lbl_text.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	right_col.add_child(_lbl_text)

	var choices_scroll: ScrollContainer = ScrollContainer.new()
	choices_scroll.custom_minimum_size = Vector2(0, 128)
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choices_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right_col.add_child(choices_scroll)

	_choices_box = VBoxContainer.new()
	_choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices_box.add_theme_constant_override("separation", 4)
	choices_scroll.add_child(_choices_box)

## Affiche un nœud de dialogue, le bandeau de dernier jet (_roll_banner) et les choix annotés (🎲 % / ⚠ FAILLE).
func show_node(node_data: Dictionary, choices: Array) -> void:
	visible = true
	var spk_id: String = str(node_data.get("speaker_id", "leader"))
	var cdef: Dictionary = DataLoader.get_character(spk_id)
	var pcol: Color = Color.html(str(cdef.get("color_hex", "#f28c28")))
	_portrait_style.border_color = pcol
	_portrait_rect.color = pcol

	var portrait_path: String = str(cdef.get("portrait", ""))
	var tex: Texture2D = _load_texture_safe(portrait_path) if portrait_path != "" else null
	if tex != null:
		_portrait_tex.texture = tex
		_portrait_tex.visible = true
		_portrait_rect.visible = false
	else:
		_portrait_tex.texture = null
		_portrait_tex.visible = false
		_portrait_rect.visible = true

	var spk_display: String = str(node_data.get("speaker_name", spk_id))
	if spk_id == "leader" and (spk_display == "" or spk_display == "Leader" or spk_display == "Toi (Leader)" or spk_display == "leader"):
		spk_display = str(cdef.get("name", "Leader"))
	_lbl_speaker.text = spk_display

	var last_roll_var: Variant = node_data.get("_last_roll", {})
	if last_roll_var is Dictionary and not (last_roll_var as Dictionary).is_empty():
		var rr: Dictionary = last_roll_var as Dictionary
		var ok_r: bool = bool(rr.get("success", false))
		var br_r: bool = bool(rr.get("is_brilliant", false))
		var fl_r: bool = bool(rr.get("is_flaw_blunder", false))
		var xp_r: int = int(rr.get("brilliant_xp", 0))
		var banner_txt: String = str(rr.get("roll_summary", ""))
		if xp_r > 0:
			banner_txt += "  (+%d XP Coup d'éclat !)" % xp_r
		elif fl_r:
			banner_txt += "  (⚠ Faille : contrecoup moral)"
		_lbl_roll_result.text = banner_txt
		if br_r:
			_roll_banner_style.bg_color = Color(0.18, 0.14, 0.06, 0.96)
			_roll_banner_style.border_color = Color(0.98, 0.78, 0.24)
			_lbl_roll_result.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36))
		elif ok_r:
			_roll_banner_style.bg_color = Color(0.08, 0.16, 0.10, 0.96)
			_roll_banner_style.border_color = Color(0.42, 0.86, 0.50)
			_lbl_roll_result.add_theme_color_override("font_color", Color(0.70, 0.96, 0.72))
		else:
			_roll_banner_style.bg_color = Color(0.20, 0.08, 0.09, 0.96)
			_roll_banner_style.border_color = Color(0.95, 0.28, 0.28)
			_lbl_roll_result.add_theme_color_override("font_color", Color(1.0, 0.62, 0.58))
		_roll_banner.visible = true
	else:
		_roll_banner.visible = false

	_lbl_text.text = str(node_data.get("text", ""))

	for child in _choices_box.get_children():
		child.queue_free()

	for i in range(choices.size()):
		var c_var: Variant = choices[i]
		if c_var is Dictionary:
			var cd: Dictionary = c_var as Dictionary
			var btn: Button = Button.new()
			var enabled: bool = bool(cd.get("_enabled", true))
			var tag: String = str(cd.get("tag", ""))
			var lock_r: String = str(cd.get("_lock_reason", ""))
			var label_txt: String = str(cd.get("label", "Continuer"))
			var rp_var: Variant = cd.get("_roll_preview", {})
			var tip_txt: String = label_txt
			if rp_var is Dictionary and not (rp_var as Dictionary).is_empty():
				var rp: Dictionary = rp_var as Dictionary
				var pct: int = int(rp.get("chance_pct", 50))
				var r_name: String = str(rp.get("char_name", "")).split(" ")[0]
				var sk_val: int = int(rp.get("skill_val", 0))
				var flaw_s: String = " ⚠ FAILLE" if bool(rp.get("is_flaw", false)) else ""
				var badge: String = "[🎲 %d%% · %s %+d%s] " % [pct, r_name, sk_val, flaw_s]
				label_txt = badge + label_txt
				tip_txt = "%s\nJet : %s (%d%%)" % [str(cd.get("label", "")), str(rp.get("formula", "")), pct]
				if pct >= 75 and not bool(rp.get("is_flaw", false)):
					btn.add_theme_color_override("font_color", Color(0.68, 0.94, 0.72))
				elif pct >= 45 and not bool(rp.get("is_flaw", false)):
					btn.add_theme_color_override("font_color", Color(0.98, 0.80, 0.34))
				else:
					btn.add_theme_color_override("font_color", Color(0.98, 0.50, 0.46))
			if tag != "":
				label_txt += "   [%s]" % tag
			if not enabled and lock_r != "":
				label_txt += "  —  (%s)" % lock_r
			btn.text = label_txt
			btn.tooltip_text = tip_txt
			btn.clip_text = true
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.disabled = not enabled
			var idx_cap: int = i
			btn.pressed.connect(func() -> void: choice_selected.emit(idx_cap))
			_choices_box.add_child(btn)

## Masque la boîte de dialogue.
func hide_panel() -> void:
	visible = false

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
