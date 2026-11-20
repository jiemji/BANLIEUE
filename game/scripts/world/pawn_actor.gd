extends Node2D

const OutlineShader: Shader = preload("res://shaders/pawn_outline.gdshader")
const DEFAULT_SHADOW_DIR: Vector2 = Vector2(0.8660254, 0.5) # Orientation 4h (+30 deg)

var _shadow_sprite: Sprite2D = null
var _body_sprite: Sprite2D = null
var _body_mat: ShaderMaterial = null
var _name_panel: PanelContainer = null
var _name_style: StyleBoxFlat = null
var _name_label: Label = null

var _target_h: float = 162.0
var _tex_size: Vector2 = Vector2(180.0, 526.0)
var _char_color: Color = Color(0.95, 0.55, 0.16)

func _ready() -> void:
	_shadow_sprite = Sprite2D.new()
	_shadow_sprite.centered = false
	_shadow_sprite.self_modulate = Color(0.0, 0.0, 0.0, 0.42)
	add_child(_shadow_sprite)

	_body_sprite = Sprite2D.new()
	_body_sprite.centered = false
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = OutlineShader
	_body_mat.set_shader_parameter("outline_px", 2.0)
	_body_sprite.material = _body_mat
	add_child(_body_sprite)

	_name_panel = PanelContainer.new()
	_name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_style = StyleBoxFlat.new()
	_name_style.bg_color = Color(0.08, 0.08, 0.10, 0.88)
	_name_style.border_color = _char_color
	_name_style.set_border_width_all(1)
	_name_style.set_content_margin_all(2)
	_name_panel.add_theme_stylebox_override("panel", _name_style)
	add_child(_name_panel)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	_name_panel.add_child(_name_label)

func setup_character(tex: Texture2D, short_name: String, char_color: Color, target_h: float) -> void:
	_target_h = target_h
	_char_color = char_color
	_name_label.text = short_name
	var pw: float = maxf(60.0, float(short_name.length()) * 7.2 + 14.0)
	_name_panel.size = Vector2(pw, 19.0)
	_name_panel.position = Vector2(-pw * 0.5, -target_h - 24.0)

	if tex != null:
		_tex_size = tex.get_size()
		_shadow_sprite.texture = tex
		_body_sprite.texture = tex
		var foot_offset: Vector2 = Vector2(-_tex_size.x * 0.5, -(_tex_size.y - 10.0))
		_body_sprite.offset = foot_offset
		# Plan de contact moyen des deux chaussures en vue 3/4 pour ancrer l'ombre sans vide sous le pied arrière
		_shadow_sprite.offset = Vector2(-_tex_size.x * 0.5, -(_tex_size.y - 22.0))
		var char_px_h: float = maxf(_tex_size.y - 26.0, 1.0)
		var s: float = target_h / char_px_h
		_body_sprite.scale = Vector2(s, s)
		_body_mat.set_shader_parameter("render_size", Vector2(_tex_size.x * s, _tex_size.y * s))

func update_state(action_state: String, is_night: bool, low_moral: bool, lights: Array) -> void:
	var outline_col: Color = _color_for_action(action_state)
	_body_mat.set_shader_parameter("outline_color", outline_col)
	_body_mat.set_shader_parameter("outline_px", 2.0)

	var body_tint: Color = Color(0.84, 0.87, 0.94, 1.0) if is_night else Color.WHITE
	_body_mat.set_shader_parameter("tint_color", body_tint)

	_name_style.border_color = outline_col if action_state != "idle" else _char_color
	update_shadow(lights, is_night, low_moral)

func update_shadow(lights: Array, is_night: bool, low_moral: bool) -> void:
	if _shadow_sprite == null or _shadow_sprite.texture == null:
		return
	var char_px_h: float = maxf(_tex_size.y - 26.0, 1.0)
	var s: float = _target_h / char_px_h
	var shadow_dir: Vector2 = DEFAULT_SHADOW_DIR
	var shadow_len: float = 0.52 if not (is_night or low_moral) else 0.78
	var shadow_alpha: float = 0.42 if not is_night else 0.54

	# Si des sources lumineuses sont definies sur la carte, l'ombre fuit la lumiere dominante
	if not lights.is_empty():
		var best_weight: float = 0.0
		var best_dir: Vector2 = DEFAULT_SHADOW_DIR
		for l_var in lights:
			if l_var is Dictionary:
				var ld: Dictionary = l_var as Dictionary
				var lpos_var: Variant = ld.get("screen_pos", Vector2.ZERO)
				var lpos: Vector2 = lpos_var if lpos_var is Vector2 else Vector2.ZERO
				var radius: float = maxf(float(ld.get("radius", 320.0)), 1.0)
				var strength: float = float(ld.get("strength", 1.0))
				var delta_v: Vector2 = global_position - lpos
				var dist: float = delta_v.length()
				if dist < radius and dist > 2.0:
					var w: float = (1.0 - dist / radius) * strength
					if w > best_weight:
						best_weight = w
						best_dir = delta_v.normalized()
		if best_weight > 0.05:
			shadow_dir = best_dir
			shadow_len = clampf(0.45 + (1.0 - best_weight) * 0.55, 0.40, 0.95)
			shadow_alpha = clampf(0.30 + best_weight * 0.30, 0.28, 0.62)

	var x_axis: Vector2 = Vector2(s, 0.0)
	var y_axis: Vector2 = -shadow_dir * (s * shadow_len)
	var foot_contact_y: float = -12.0 * s
	_shadow_sprite.transform = Transform2D(x_axis, y_axis, Vector2(0.0, foot_contact_y))
	_shadow_sprite.self_modulate = Color(0.0, 0.0, 0.0, shadow_alpha)

func _color_for_action(action_state: String) -> Color:
	if action_state == "moving":
		return Color(0.95, 0.55, 0.16, 1.0)     # Orange sodium
	if action_state == "interacting":
		return Color(0.98, 0.84, 0.28, 1.0)     # Jaune dialogue / interaction
	if action_state == "guarding":
		return Color(0.28, 0.65, 0.96, 1.0)     # Bleu electrique (guet)
	if action_state == "stress":
		return Color(0.92, 0.18, 0.18, 1.0)     # Rouge fanzine (Stress / Crise)
	return Color(0.95, 0.93, 0.87, 0.88)        # Creme fin (repos)
