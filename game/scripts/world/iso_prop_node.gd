## Nœud de mobilier isométrique N4 piloté par rules/props_catalog.json (et surcharges locales du décor).
extends Node2D

var _prop: Dictionary = {}
var _tile_w: float = 86.0
var _tile_h: float = 43.0
var _iso_origin: Vector2 = Vector2.ZERO
var _is_night: bool = false

func setup_prop(prop: Dictionary, tile_w_val: float, tile_h_val: float, origin_val: Vector2, is_night_val: bool) -> void:
	_prop = prop
	_tile_w = tile_w_val
	_tile_h = tile_h_val
	_iso_origin = origin_val
	_is_night = is_night_val

	var ptype: String = str(prop.get("type", "box"))
	var pdef: Dictionary = DataLoader.get_prop_def(ptype)
	var shape: String = str(prop.get("shape", str(pdef.get("shape", "box"))))
	var gx: float = float(prop.get("x", 0.0))
	var gy: float = float(prop.get("y", 0.0))
	var w: float = float(prop.get("w", 1.0))
	var h: float = float(prop.get("h", 1.0))
	var sort_pt: Vector2 = _iso_to_screen(gx + w * 0.5, gy + h * 0.5)
	if shape == "wall_back":
		var back_pt: Vector2 = _iso_to_screen(gx + w * 0.5, gy + h)
		z_index = clampi(int(back_pt.y) - 12, -3500, 3500)
	else:
		z_index = clampi(int(sort_pt.y), -3500, 3500)
	queue_redraw()

func set_night(is_night_val: bool) -> void:
	if _is_night != is_night_val:
		_is_night = is_night_val
		queue_redraw()

func _iso_to_screen(gx: float, gy: float) -> Vector2:
	var sx: float = (gx - gy) * (_tile_w * 0.5)
	var sy: float = (gx + gy) * (_tile_h * 0.5)
	return _iso_origin + Vector2(sx, sy)

func _draw() -> void:
	if _prop.is_empty():
		return
	var ptype: String = str(_prop.get("type", "box"))
	var pdef: Dictionary = DataLoader.get_prop_def(ptype)
	var gx: float = float(_prop.get("x", 0.0))
	var gy: float = float(_prop.get("y", 0.0))
	var w: float = float(_prop.get("w", 1.0))
	var h: float = float(_prop.get("h", 1.0))
	var lbl: String = str(_prop.get("label", ""))

	var night_spr: String = str(_prop.get("sprite_night", str(pdef.get("sprite_night", ""))))
	var day_spr: String = str(_prop.get("sprite_day", str(_prop.get("sprite", str(pdef.get("sprite_day", str(pdef.get("sprite", ""))))))))
	var spr_path: String = night_spr if (_is_night and night_spr != "") else day_spr
	if spr_path != "":
		var tex: Texture2D = DataLoader.load_texture_safe(spr_path)
		if tex != null:
			var foot_mid: Vector2 = (_iso_to_screen(gx, gy + h) + _iso_to_screen(gx + w, gy)) * 0.5
			var tsz: Vector2 = tex.get_size()
			var span_w: float = maxf(32.0, (w + h) * _tile_w * 0.5)
			var span_h: float = span_w * (tsz.y / maxf(tsz.x, 1.0))
			var drect: Rect2 = Rect2(Vector2(foot_mid.x - span_w * 0.5, foot_mid.y - span_h + _tile_h * 0.25), Vector2(span_w, span_h))
			var tint_s: Color = Color(0.68, 0.72, 0.82) if (_is_night and night_spr == "") else Color.WHITE
			draw_texture_rect(tex, drect, false, tint_s)
			return

	var height_px: float = float(_prop.get("height_px", float(pdef.get("height_px", 24.0))))
	var day_hex: String = str(_prop.get("day_color", str(pdef.get("day_color", "#a69480"))))
	var night_hex: String = str(_prop.get("night_color", str(pdef.get("night_color", day_hex))))
	var chosen_hex: String = night_hex if (_is_night and night_hex != "") else day_hex
	var col: Color = Color.html(chosen_hex) if chosen_hex != "" else Color(0.65, 0.58, 0.50)

	var b0: Vector2 = _iso_to_screen(gx, gy)
	var b1: Vector2 = _iso_to_screen(gx + w, gy)
	var b2: Vector2 = _iso_to_screen(gx + w, gy + h)
	var b3: Vector2 = _iso_to_screen(gx, gy + h)

	var up: Vector2 = Vector2(0.0, -height_px)
	var t0: Vector2 = b0 + up
	var t1: Vector2 = b1 + up
	var t2: Vector2 = b2 + up
	var t3: Vector2 = b3 + up

	var ink: Color = Color(0.06, 0.06, 0.07)
	draw_colored_polygon(PackedVector2Array([t1, t2, b2, b1]), col.darkened(0.26))
	draw_polyline(PackedVector2Array([t1, t2, b2, b1, t1]), ink, 1.5)
	draw_colored_polygon(PackedVector2Array([t3, t2, b2, b3]), col.darkened(0.14))
	draw_polyline(PackedVector2Array([t3, t2, b2, b3, t3]), ink, 1.5)
	draw_colored_polygon(PackedVector2Array([t0, t1, t2, t3]), col)
	draw_polyline(PackedVector2Array([t0, t1, t2, t3, t0]), ink, 1.8)

	if lbl != "":
		var center: Vector2 = (t0 + t2) * 0.5
		draw_string(ThemeDB.fallback_font, center + Vector2(-28.0, -6.0), lbl, HORIZONTAL_ALIGNMENT_CENTER, 72, 11, Color(0.95, 0.94, 0.90))
