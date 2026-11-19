extends Control

signal choice_selected(choice_index: int)

var _panel: PanelContainer = null
var _lbl_speaker: Label = null
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
	visible = false

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(18, 434)
	_panel.size = Vector2(886, 274)
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
	right_col.add_theme_constant_override("separation", 8)
	main_hbox.add_child(right_col)

	_lbl_speaker = Label.new()
	_lbl_speaker.add_theme_font_size_override("font_size", 16)
	_lbl_speaker.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	right_col.add_child(_lbl_speaker)

	_lbl_text = Label.new()
	_lbl_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lbl_text.add_theme_font_size_override("font_size", 14)
	_lbl_text.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	right_col.add_child(_lbl_text)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 5)
	right_col.add_child(_choices_box)

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

	_lbl_speaker.text = str(node_data.get("speaker_name", spk_id))
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
			if tag != "":
				label_txt += "   [%s]" % tag
			if not enabled and lock_r != "":
				label_txt += "  —  (%s)" % lock_r
			btn.text = label_txt
			btn.tooltip_text = label_txt
			btn.clip_text = true
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.disabled = not enabled
			var idx_cap: int = i
			btn.pressed.connect(func() -> void: choice_selected.emit(idx_cap))
			_choices_box.add_child(btn)

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
