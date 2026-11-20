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
	var gx: float = float(prop.get("x", 0.0))
	var gy: float = float(prop.get("y", 0.0))
	var w: float = float(prop.get("w", 1.0))
	var h: float = float(prop.get("h", 1.0))
	var sort_pt: Vector2 = _iso_to_screen(gx + w * 0.5, gy + h * 0.5)
	if ptype == "wall_back":
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
	var gx: float = float(_prop.get("x", 0.0))
	var gy: float = float(_prop.get("y", 0.0))
	var w: float = float(_prop.get("w", 1.0))
	var h: float = float(_prop.get("h", 1.0))
	var lbl: String = str(_prop.get("label", ""))

	var height_px: float = 24.0
	var col: Color = Color(0.65, 0.58, 0.50)
	if ptype == "wall_back":
		height_px = 46.0
		col = Color(0.54, 0.50, 0.46) if not _is_night else Color(0.18, 0.18, 0.22)
	elif ptype == "mob":
		height_px = 18.0
		col = Color(0.95, 0.52, 0.16)
	elif ptype == "sofa":
		height_px = 16.0
		col = Color(0.72, 0.20, 0.22)
	elif ptype == "radio":
		height_px = 14.0
		col = Color(0.22, 0.56, 0.85)
	elif ptype == "arcade":
		height_px = 32.0
		col = Color(0.22, 0.54, 0.92)
	elif ptype == "babyfoot":
		height_px = 20.0
		col = Color(0.62, 0.46, 0.26)
	elif ptype == "counter":
		height_px = 20.0
		col = Color(0.92, 0.78, 0.28)
	elif ptype == "notice":
		height_px = 28.0
		col = Color(0.85, 0.18, 0.18)
	elif ptype == "lodge":
		height_px = 36.0
		col = Color(0.58, 0.62, 0.68)
	elif ptype == "van":
		height_px = 28.0
		col = Color(0.32, 0.42, 0.68)
	elif ptype == "sign_rer":
		height_px = 34.0
		col = Color(0.18, 0.36, 0.82)
	elif ptype == "trash":
		height_px = 22.0
		col = Color(0.48, 0.52, 0.56)

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
