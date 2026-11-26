extends Node2D

signal zoom_in_requested(target_level: int, target_id: String)
signal zoom_out_requested
signal interior_travel_requested(location_id: String)
signal undescribed_clicked(node_name: String, lore: String)

var input_blocked: bool = false
var _zoom_level: int = 1
var _map_id: String = ""
var _hover_id: String = ""
var _hover_lore: String = ""
var _notice_text: String = ""
var _notice_timer: float = 0.0
var _pulse_time: float = 0.0
var _wheel_out_streak: int = 0

var _camera: Camera2D = null
var _focus_world: Vector2 = Vector2(500.0, 380.0)
var _cam_zoom: float = 0.84
var _pan_dragging: bool = false
var _pan_last_screen: Vector2 = Vector2.ZERO

func _ready() -> void:
	_camera = Camera2D.new()
	_camera.enabled = false
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	set_view_active(false)

func set_view_active(active: bool) -> void:
	visible = active
	_pan_dragging = false
	set_process(active)
	set_process_unhandled_input(active)
	if _camera != null:
		_camera.enabled = active
		if active:
			_camera.make_current()
			_apply_camera_transform()

func set_zoom_view(level: int, map_id: String) -> void:
	_zoom_level = clampi(level, 1, 3)
	_map_id = map_id
	_hover_id = ""
	_hover_lore = ""
	_wheel_out_streak = 0
	var data: Dictionary = _get_map_data()
	var mw: float = float(data.get("map_width", 1000.0))
	var mh: float = float(data.get("map_height", 760.0))
	_focus_world = Vector2(mw * 0.5, mh * 0.5)
	_cam_zoom = minf(875.0 / maxf(mw, 1.0), 635.0 / maxf(mh, 1.0))
	_cam_zoom = clampf(_cam_zoom, 0.72, 1.0)
	_apply_camera_transform()
	queue_redraw()

func show_notice(msg: String) -> void:
	_notice_text = msg
	_notice_timer = 4.2
	queue_redraw()

func _get_map_data() -> Dictionary:
	if _zoom_level == 1:
		return DataLoader.get_region(_map_id)
	if _zoom_level == 2:
		return DataLoader.get_department(_map_id)
	return DataLoader.get_city(_map_id)

func _apply_camera_transform() -> void:
	if _camera == null:
		return
	var z: float = clampf(_cam_zoom, 0.65, 1.85)
	_camera.zoom = Vector2(z, z)
	# Compense le panneau latéral droit (918..1280) et le bandeau haut (0..54) : centre utile (455, 387)
	_camera.position = _focus_world + Vector2(185.0, -27.0) / z

func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_time += delta
	if _notice_timer > 0.0:
		_notice_timer = maxf(0.0, _notice_timer - delta)
		if _notice_timer <= 0.0:
			_notice_text = ""
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or input_blocked:
		return

	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _pan_dragging:
			var delta_screen: Vector2 = mm.position - _pan_last_screen
			_pan_last_screen = mm.position
			_focus_world -= delta_screen / maxf(_cam_zoom, 0.1)
			var data: Dictionary = _get_map_data()
			var mw: float = float(data.get("map_width", 1000.0))
			var mh: float = float(data.get("map_height", 760.0))
			_focus_world.x = clampf(_focus_world.x, 80.0, mw - 80.0)
			_focus_world.y = clampf(_focus_world.y, 60.0, mh - 60.0)
			_apply_camera_transform()
			get_viewport().set_input_as_handled()
			return
		_update_hover(mm.position)
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_pan_dragging = mb.pressed
			_pan_last_screen = mb.position
			get_viewport().set_input_as_handled()
			return

		if mb.position.x > 910.0 or mb.position.y < 54.0:
			return

		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_wheel_out_streak = 0
			_cam_zoom = clampf(_cam_zoom + 0.12, 0.72, 1.85)
			_apply_camera_transform()
			get_viewport().set_input_as_handled()
			return

		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			var data_z: Dictionary = _get_map_data()
			var mw_z: float = float(data_z.get("map_width", 1000.0))
			var mh_z: float = float(data_z.get("map_height", 760.0))
			var fit_z: float = clampf(minf(875.0 / maxf(mw_z, 1.0), 635.0 / maxf(mh_z, 1.0)), 0.72, 1.0)
			if _cam_zoom <= fit_z + 0.04:
				_wheel_out_streak += 1
				if _zoom_level > 1 and _wheel_out_streak >= 2:
					_wheel_out_streak = 0
					zoom_out_requested.emit()
					get_viewport().set_input_as_handled()
					return
			else:
				_wheel_out_streak = 0
			_cam_zoom = clampf(_cam_zoom - 0.12, fit_z, 1.85)
			_apply_camera_transform()
			get_viewport().set_input_as_handled()
			return

		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var world_pos: Vector2 = get_canvas_transform().affine_inverse() * mb.position
			_handle_left_click(world_pos)
			get_viewport().set_input_as_handled()

func _update_hover(screen_pos: Vector2) -> void:
	if screen_pos.x > 910.0 or screen_pos.y < 54.0:
		_hover_id = ""
		_hover_lore = ""
		return
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	var hit: Dictionary = _pick_child_at(world_pos)
	var new_id: String = str(hit.get("id", ""))
	if new_id != _hover_id:
		_hover_id = new_id
		_hover_lore = _format_hover_lore(hit)
		queue_redraw()

func _format_hover_lore(node: Dictionary) -> String:
	if node.is_empty():
		return ""
	var nname: String = str(node.get("name", ""))
	if _zoom_level == 1:
		var code: String = str(node.get("code", ""))
		var st_str: String = "Zone jouable (Cliquer pour ouvrir)" if GameState.is_node_playable(node) else "Non décrit au départ"
		return "%s (%s) — %s — %s" % [nname, code, st_str, str(node.get("lore", ""))]
	if _zoom_level == 2:
		var st_str2: String = "Ville jouable (Cliquer pour entrer)" if GameState.is_node_playable(node) else "Commune non décrite"
		var hook_txt: String = ""
		var th_var: Variant = node.get("travel_hooks", {})
		if th_var is Dictionary:
			var conns_var: Variant = (th_var as Dictionary).get("connections", [])
			if conns_var is Array and not (conns_var as Array).is_empty():
				var first_var: Variant = (conns_var as Array)[0]
				if first_var is Dictionary:
					var fd: Dictionary = first_var as Dictionary
					hook_txt = " | %s (%d min · %d F)" % [str(fd.get("mode", "")), int(fd.get("minutes", 0)), int(fd.get("cost_francs", 0))]
		return "%s — %s%s — %s" % [nname, st_str2, hook_txt, str(node.get("lore", ""))]
	var lid: String = str(node.get("id", ""))
	var active_loc: String = GameState.get_active_location_id()
	var d: int = _lookup_distance(active_loc, lid)
	var dist_txt: String = "Position actuelle" if lid == active_loc else ("Trajet ~%d cran(s)" % d)
	return "%s (%s) — %s — Cliquer pour entrer au Niveau 4" % [nname, str(node.get("sector", "")), dist_txt]

func _lookup_distance(from_loc: String, to_loc: String) -> int:
	if from_loc == to_loc:
		return 0
	var loc_def: Dictionary = DataLoader.get_location(from_loc)
	var nv: Variant = loc_def.get("neighbors", {})
	if nv is Dictionary and (nv as Dictionary).has(to_loc):
		var d: int = int((nv as Dictionary).get(to_loc, 2))
		var mods_var: Variant = DataLoader.scenario_manifest.get("travel_modifiers", [])
		if mods_var is Array:
			for mv in (mods_var as Array):
				if mv is Dictionary:
					var md: Dictionary = mv as Dictionary
					var req_flag: String = str(md.get("if_flag", ""))
					if req_flag == "" or GameState.has_flag(req_flag):
						var min_d: int = int(md.get("min_dist", 1))
						var delta_d: int = int(md.get("delta", 0))
						if d > min_d:
							d = maxi(min_d, d + delta_d)
		return d
	return 2

func _handle_left_click(world_pos: Vector2) -> void:
	var hit: Dictionary = _pick_child_at(world_pos)
	if hit.is_empty():
		return
	var hid: String = str(hit.get("id", ""))
	var hname: String = str(hit.get("name", hid))
	if not GameState.is_node_playable(hit):
		AudioRadio.play_cassette_click()
		var lore: String = str(hit.get("lore", "Zone non encore décrite."))
		show_notice("%s — Non décrit pour l'instant : %s" % [hname, lore])
		undescribed_clicked.emit(hname, lore)
		return

	AudioRadio.play_cassette_click()
	if _zoom_level == 1:
		zoom_in_requested.emit(2, hid)
	elif _zoom_level == 2:
		zoom_in_requested.emit(3, hid)
	elif _zoom_level == 3:
		interior_travel_requested.emit(hid)

func _pick_child_at(world_pos: Vector2) -> Dictionary:
	var data: Dictionary = _get_map_data()
	var ch_var: Variant = data.get("children", [])
	if not (ch_var is Array):
		return {}
	for cv in (ch_var as Array):
		if not (cv is Dictionary):
			continue
		var cd: Dictionary = cv as Dictionary
		if _zoom_level == 1:
			var poly: PackedVector2Array = _to_poly(cd.get("polygon", []))
			if poly.size() >= 3 and Geometry2D.is_point_in_polygon(world_pos, poly):
				return cd
		elif _zoom_level == 2:
			var cpos: Vector2 = _to_vec2(cd.get("pos", [0, 0]))
			var rad: float = float(cd.get("radius", 16.0)) + 10.0
			if world_pos.distance_to(cpos) <= rad:
				return cd
		elif _zoom_level == 3:
			var bpos: Vector2 = _to_vec2(cd.get("pos", [0, 0]))
			var fp: Vector2 = _to_vec2(cd.get("footprint", [144, 72]))
			var rect: Rect2 = Rect2(bpos - fp * 0.5, fp)
			if rect.has_point(world_pos):
				return cd
	return {}

func _draw() -> void:
	var data: Dictionary = _get_map_data()
	if data.is_empty():
		return
	var mw: float = float(data.get("map_width", 1000.0))
	var mh: float = float(data.get("map_height", 760.0))
	var is_night: bool = (GameState.phase == "night")
	var low_moral: bool = GameState.get_lowest_moral() <= 40

	# Fond sombre hors-carte
	draw_rect(Rect2(Vector2(-1200.0, -900.0), Vector2(3600.0, 2800.0)), Color(0.075, 0.078, 0.092), true)

	# Feuille de plan papier IGN / RATP 1982
	var sheet_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(mw, mh))
	draw_rect(Rect2(Vector2(10.0, 10.0), Vector2(mw, mh)), Color(0.03, 0.03, 0.04, 0.55), true)

	var backdrop_path: String = str(data.get("backdrop", ""))
	var backdrop_tex: Texture2D = _load_texture_safe(backdrop_path) if backdrop_path != "" else null
	var ink_col: Color = Color(0.86, 0.88, 0.90) if is_night else Color(0.11, 0.10, 0.09)

	var has_backdrop: bool = (backdrop_tex != null)
	if has_backdrop:
		var tint_b: Color = Color(0.54, 0.58, 0.68) if is_night else Color.WHITE
		draw_texture_rect(backdrop_tex, sheet_rect, false, tint_b)
	else:
		var paper_col: Color = Color.html(str(data.get("night_tint", "#191d26"))) if is_night else Color.html(str(data.get("paper_tint", "#dfd5be")))
		draw_rect(sheet_rect, paper_col, true)
		_draw_paper_grid_and_folds(mw, mh, is_night)

	draw_rect(sheet_rect, ink_col, false, 3.0)
	draw_rect(Rect2(Vector2(6.0, 6.0), Vector2(mw - 12.0, mh - 12.0)), Color(ink_col.r, ink_col.g, ink_col.b, 0.35), false, 1.2)

	if _zoom_level == 1:
		_draw_region_idf(data, is_night, ink_col, has_backdrop)
	elif _zoom_level == 2:
		_draw_department_93(data, is_night, low_moral, ink_col, has_backdrop)
	else:
		_draw_city_cradon(data, is_night, low_moral, ink_col, has_backdrop)

	_draw_cartouche(data, mw, mh, is_night, ink_col)

func _draw_paper_grid_and_folds(mw: float, mh: float, is_night: bool) -> void:
	var grid_c: Color = Color(0.28, 0.32, 0.38, 0.22) if is_night else Color(0.55, 0.50, 0.42, 0.22)
	var fold_c: Color = Color(0.04, 0.04, 0.06, 0.26) if is_night else Color(0.42, 0.36, 0.28, 0.22)
	var x: float = 100.0
	while x < mw:
		draw_line(Vector2(x, 0.0), Vector2(x, mh), grid_c, 1.0)
		x += 100.0
	var y: float = 95.0
	while y < mh:
		draw_line(Vector2(0.0, y), Vector2(mw, y), grid_c, 1.0)
		y += 95.0
	# Plis du plan papier déplié dans la poche
	draw_line(Vector2(mw * 0.5, 0.0), Vector2(mw * 0.5, mh), fold_c, 2.0)
	draw_line(Vector2(0.0, mh * 0.5), Vector2(mw, mh * 0.5), fold_c, 2.0)

func _draw_region_idf(data: Dictionary, is_night: bool, ink_col: Color, has_backdrop: bool = false) -> void:
	var ch_var: Variant = data.get("children", [])
	if ch_var is Array:
		for cv in (ch_var as Array):
			if not (cv is Dictionary):
				continue
			var cd: Dictionary = cv as Dictionary
			var cid: String = str(cd.get("id", ""))
			var is_playable: bool = GameState.is_node_playable(cd)
			var is_hover: bool = (cid == _hover_id)
			var poly: PackedVector2Array = _to_poly(cd.get("polygon", []))
			if poly.size() < 3:
				continue

			var fill_col: Color
			if has_backdrop:
				if is_playable:
					fill_col = Color(0.88, 0.22, 0.20, 0.22 if is_hover else 0.12)
				else:
					fill_col = Color(0.95, 0.88, 0.72, 0.16) if is_hover else Color(0.0, 0.0, 0.0, 0.0)
			else:
				if is_playable:
					fill_col = Color(0.55, 0.16, 0.16, 0.65) if is_night else Color(0.92, 0.44, 0.24, 0.48)
				else:
					fill_col = Color(0.18, 0.21, 0.26, 0.58) if is_night else Color(0.76, 0.72, 0.64, 0.52)
				if is_hover:
					fill_col = fill_col.lightened(0.18)

			if fill_col.a > 0.01:
				draw_colored_polygon(poly, fill_col)
			var closed: PackedVector2Array = poly.duplicate()
			closed.append(poly[0])
			var border_alpha: float = 0.88 if is_playable else (0.35 if has_backdrop else 0.70)
			var border_c: Color = Color(0.92, 0.24, 0.22, border_alpha) if is_playable else Color(ink_col.r, ink_col.g, ink_col.b, border_alpha)
			draw_polyline(closed, border_c, 2.8 if is_playable else (1.1 if has_backdrop else 1.5))

	# Cours d'eau (Seine / Marne)
	var ww_var: Variant = data.get("waterways", [])
	if ww_var is Array and not has_backdrop:
		for wv in (ww_var as Array):
			if wv is Dictionary:
				var pts: PackedVector2Array = _to_poly((wv as Dictionary).get("points", []))
				if pts.size() >= 2:
					draw_polyline(pts, Color(0.32, 0.56, 0.72, 0.85), 4.0)

	# Axe RER B
	var rl_var: Variant = data.get("rail_lines", [])
	if rl_var is Array:
		for rv in (rl_var as Array):
			if rv is Dictionary:
				var rd: Dictionary = rv as Dictionary
				var pts_r: PackedVector2Array = _to_poly(rd.get("points", []))
				if pts_r.size() >= 2:
					var rc: Color = Color.html(str(rd.get("color_hex", "#4aa3df")))
					rc.a = 0.78 if has_backdrop else 1.0
					draw_polyline(pts_r, rc, 2.4 if has_backdrop else 3.2)

	# Étiquettes & feutre rouge sur le 93
	if ch_var is Array:
		for cv in (ch_var as Array):
			if not (cv is Dictionary):
				continue
			var cd: Dictionary = cv as Dictionary
			var cpos: Vector2 = _to_vec2(cd.get("pos", [0, 0]))
			var is_play: bool = GameState.is_node_playable(cd)
			var code: String = str(cd.get("code", ""))
			var cname: String = str(cd.get("name", ""))
			var tag_col: Color = Color(0.96, 0.94, 0.88) if is_night else Color(0.12, 0.11, 0.10)
			if is_play:
				draw_arc(cpos, 32.0 + sin(_pulse_time * 3.0) * 2.5, 0.0, TAU, 32, Color(0.92, 0.18, 0.18), 3.0)
				_draw_map_badge(cpos + Vector2(-58.0, -14.0), "%s — %s ★" % [code, cname], Color(0.88, 0.20, 0.20), is_night)
				_draw_squad_pin(cpos + Vector2(36.0, -24.0), "BANDE")
			elif has_backdrop:
				_draw_map_badge(cpos + Vector2(-42.0, -10.0), "%s · %s" % [code, cname], Color(0.32, 0.30, 0.26, 0.75), is_night)
			else:
				draw_string(ThemeDB.fallback_font, cpos + Vector2(-18.0, -4.0), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tag_col)
				draw_string(ThemeDB.fallback_font, cpos + Vector2(-38.0, 12.0), cname, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(tag_col.r, tag_col.g, tag_col.b, 0.78))

func _draw_department_93(data: Dictionary, is_night: bool, low_moral: bool, ink_col: Color, has_backdrop: bool = false) -> void:
	# Axes routes / canal / RER B Nord en Y
	var rt_var: Variant = data.get("routes", [])
	if rt_var is Array:
		for rv in (rt_var as Array):
			if not (rv is Dictionary):
				continue
			var rd: Dictionary = rv as Dictionary
			var pts: PackedVector2Array = _to_poly(rd.get("points", []))
			if pts.size() < 2:
				continue
			var kind: String = str(rd.get("kind", "road"))
			if has_backdrop and kind != "rail":
				continue
			var col: Color = Color.html(str(rd.get("color_hex", "#4aa3df")))
			col.a = 0.75 if has_backdrop else 1.0
			var width: float = (3.2 if has_backdrop else 4.5) if kind == "rail" else (5.5 if kind == "water" else 2.6)
			draw_polyline(pts, col, width)
			if kind == "rail":
				for i in range(pts.size()):
					draw_circle(pts[i], 3.0 if has_backdrop else 3.5, Color.WHITE)

	# Communes du 93
	var ch_var: Variant = data.get("children", [])
	if not (ch_var is Array):
		return
	for cv in (ch_var as Array):
		if not (cv is Dictionary):
			continue
		var cd: Dictionary = cv as Dictionary
		var cid: String = str(cd.get("id", ""))
		var cpos: Vector2 = _to_vec2(cd.get("pos", [0, 0]))
		var rad: float = float(cd.get("radius", 14.0))
		var is_play: bool = GameState.is_node_playable(cd)
		var is_hover: bool = (cid == _hover_id)

		if is_play:
			var pulse_r: float = rad + 12.0 + sin(_pulse_time * 3.5) * 3.0
			draw_arc(cpos, pulse_r, 0.0, TAU, 32, Color(0.92, 0.18, 0.18), 3.0)
			draw_circle(cpos, rad, Color(0.92, 0.22, 0.20) if not is_hover else Color(0.98, 0.45, 0.22))
			draw_arc(cpos, rad, 0.0, TAU, 24, ink_col, 2.2)
			var cname: String = str(cd.get("name", cid))
			var glitch_lbl: String = str(cd.get("night_glitch_label", ""))
			if bool(cd.get("uncanny_marker", false)) and glitch_lbl != "" and (is_night or low_moral) and int(_pulse_time * 0.7) % 3 == 0:
				cname = glitch_lbl
			_draw_map_badge(cpos + Vector2(-78.0, -46.0), cname, Color(0.90, 0.20, 0.20), is_night)
			_draw_squad_pin(cpos + Vector2(26.0, -18.0), "BANDE")
		else:
			var fill_c: Color = Color(0.28, 0.30, 0.35) if is_night else Color(0.62, 0.58, 0.50)
			if is_hover:
				fill_c = fill_c.lightened(0.22)
			draw_circle(cpos, rad * 0.75, fill_c)
			draw_arc(cpos, rad * 0.75, 0.0, TAU, 20, ink_col, 1.5)
			if has_backdrop:
				_draw_map_badge(cpos + Vector2(rad + 2.0, -11.0), str(cd.get("name", cid)), Color(0.32, 0.30, 0.26, 0.75), is_night)
			else:
				var lbl_col: Color = Color(0.84, 0.86, 0.90) if is_night else Color(0.18, 0.16, 0.14)
				draw_string(ThemeDB.fallback_font, cpos + Vector2(rad + 4.0, 4.0), str(cd.get("name", cid)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, lbl_col)
				draw_string(ThemeDB.fallback_font, cpos + Vector2(rad + 4.0, 17.0), "(Non décrit)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(lbl_col.r, lbl_col.g, lbl_col.b, 0.65))

func _draw_city_cradon(data: Dictionary, is_night: bool, low_moral: bool, ink_col: Color, has_backdrop: bool = false) -> void:
	# 1. Secteurs surfaciques
	var sec_var: Variant = data.get("sectors", [])
	if sec_var is Array:
		for sv in (sec_var as Array):
			if not (sv is Dictionary):
				continue
			var sd: Dictionary = sv as Dictionary
			var poly: PackedVector2Array = _to_poly(sd.get("polygon", []))
			if poly.size() < 3:
				continue
			var scol: Color = Color.html(str(sd.get("color_hex", "#9b8c7d")))
			var alpha: float = (0.08 if has_backdrop else 0.20) if is_night else (0.10 if has_backdrop else 0.26)
			draw_colored_polygon(poly, Color(scol.r, scol.g, scol.b, alpha))
			var closed: PackedVector2Array = poly.duplicate()
			closed.append(poly[0])
			draw_polyline(closed, Color(scol.r, scol.g, scol.b, 0.45 if has_backdrop else 0.75), 1.4 if has_backdrop else 1.8)
			if has_backdrop:
				_draw_map_badge(poly[0] + Vector2(8.0, 8.0), str(sd.get("name", "")).to_upper(), Color(scol.r, scol.g, scol.b, 0.82), is_night)
			else:
				draw_string(ThemeDB.fallback_font, poly[0] + Vector2(12.0, 22.0), str(sd.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(scol.r, scol.g, scol.b, 0.92))

	var fxm_var: Variant = data.get("fx_markers", [])
	if fxm_var is Array:
		for fxv in (fxm_var as Array):
			if fxv is Dictionary:
				var fxd: Dictionary = fxv as Dictionary
				if bool(fxd.get("night_or_low_moral", true)) and not (is_night or low_moral):
					continue
				var fpos: Vector2 = _to_vec2(fxd.get("pos", [175.0, 155.0]))
				var frad: float = float(fxd.get("radius", 48.0)) + sin(_pulse_time * 1.4) * 5.0
				var fc: Color = Color.html(str(fxd.get("color_hex", "#73d9f2")))
				fc.a = float(fxd.get("alpha", 0.14))
				draw_circle(fpos, frad, fc)

	# 2. Axes routiers & RER B en Y
	var roads_var: Variant = data.get("roads", [])
	if roads_var is Array:
		for rv in (roads_var as Array):
			if not (rv is Dictionary):
				continue
			var rd: Dictionary = rv as Dictionary
			var pts: PackedVector2Array = _to_poly(rd.get("points", []))
			if pts.size() < 2:
				continue
			var kind: String = str(rd.get("kind", "road"))
			if kind == "rail":
				draw_polyline(pts, Color(0.28, 0.65, 0.96, 0.82 if has_backdrop else 1.0), 3.4 if has_backdrop else 4.5)
			elif kind == "water":
				draw_polyline(pts, Color(0.24, 0.56, 0.72, 0.72 if has_backdrop else 0.90), 10.0)
				draw_polyline(pts, Color(ink_col.r, ink_col.g, ink_col.b, 0.35), 1.5)
			elif not has_backdrop:
				draw_polyline(pts, Color(0.32, 0.34, 0.40) if is_night else Color(0.58, 0.53, 0.44), 5.0)
				draw_polyline(pts, Color(ink_col.r, ink_col.g, ink_col.b, 0.4), 1.0)

	# 3. Position des sous-groupes actifs + liens de Renfort
	var pos_by_loc: Dictionary = {}
	var ch_var: Variant = data.get("children", [])
	if ch_var is Array:
		for cv in (ch_var as Array):
			if cv is Dictionary:
				var cd0: Dictionary = cv as Dictionary
				pos_by_loc[str(cd0.get("id", ""))] = _to_vec2(cd0.get("pos", [0, 0]))

	var gids: Array[int] = GameState.get_present_group_ids()
	var active_loc: String = GameState.get_active_location_id()
	var active_pos: Vector2 = pos_by_loc.get(active_loc, Vector2.ZERO) as Vector2
	if gids.size() > 1 and pos_by_loc.has(active_loc):
		for gid in gids:
			if gid == GameState.active_group_id:
				continue
			var gm: Array[String] = GameState.get_group_members(gid)
			if gm.is_empty():
				continue
			var gloc: String = str(GameState.get_member_state(gm[0]).get("location_id", ""))
			if pos_by_loc.has(gloc) and gloc != active_loc:
				var gpos: Vector2 = pos_by_loc.get(gloc, Vector2.ZERO) as Vector2
				draw_dashed_line(active_pos, gpos, Color(0.95, 0.55, 0.16, 0.85), 2.5, 7.0)
				var mid: Vector2 = (active_pos + gpos) * 0.5
				var dist: int = _lookup_distance(gloc, active_loc)
				draw_string(ThemeDB.fallback_font, mid + Vector2(-24.0, -6.0), "Renfort %dc" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.55, 0.16))

	# 4. Bâtiments / Lieux cliquables
	if ch_var is Array:
		for cv in (ch_var as Array):
			if not (cv is Dictionary):
				continue
			var cd: Dictionary = cv as Dictionary
			var lid: String = str(cd.get("id", ""))
			var bpos: Vector2 = _to_vec2(cd.get("pos", [0, 0]))
			var fp: Vector2 = _to_vec2(cd.get("footprint", [148, 74]))
			var rect: Rect2 = Rect2(bpos - fp * 0.5, fp)
			var col: Color = Color.html(str(cd.get("color_hex", "#f28c28")))
			var is_hover: bool = (lid == _hover_id)
			var is_current: bool = (lid == active_loc)

			var box_bg: Color = Color(0.11, 0.12, 0.16, 0.94) if is_night else Color(0.95, 0.92, 0.84, 0.96)
			if is_hover:
				box_bg = box_bg.lightened(0.08)
			draw_rect(Rect2(rect.position + Vector2(4.0, 4.0), rect.size), Color(0.0, 0.0, 0.0, 0.32), true)
			draw_rect(rect, box_bg, true)
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8.0)), col, true)
			draw_rect(rect, Color(0.95, 0.55, 0.16) if is_current else ink_col, false, 3.0 if (is_current or is_hover) else 1.8)

			var done_txt: String = " ✓" if GameState.is_location_completed(lid, cd) else ""

			var txt_col: Color = Color(0.96, 0.94, 0.90) if is_night else Color(0.10, 0.10, 0.11)
			var lid_title: String = str(cd.get("name", lid)) + done_txt
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(8.0, 28.0), lid_title, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 16.0), 12, txt_col)

			var sub_txt: String = "Entrer (N4)" if not is_current else "Groupe actif ici"
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(8.0, 46.0), sub_txt, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 16.0), 10, col.darkened(0.15) if not is_night else col)

			# Jetons des groupes sur ce lieu
			var px_off: float = 8.0
			for gid in gids:
				var gm2: Array[String] = GameState.get_group_members(gid)
				if gm2.is_empty():
					continue
				if str(GameState.get_member_state(gm2[0]).get("location_id", "")) == lid:
					var g_tag: String = "G%d" % (gid + 1)
					var g_col: Color = Color(0.95, 0.55, 0.16) if gid == GameState.active_group_id else Color(0.28, 0.65, 0.96)
					_draw_squad_pin(rect.position + Vector2(px_off, rect.size.y - 14.0), g_tag, g_col)
					px_off += 44.0

func _draw_cartouche(data: Dictionary, mw: float, mh: float, is_night: bool, ink_col: Color) -> void:
	var c_bg: Color = Color(0.08, 0.09, 0.12, 0.92) if is_night else Color(0.97, 0.94, 0.87, 0.94)
	var c_txt: Color = Color(0.95, 0.94, 0.90) if is_night else Color(0.10, 0.10, 0.11)
	draw_rect(Rect2(Vector2(18.0, 18.0), Vector2(360.0, 56.0)), c_bg, true)
	draw_rect(Rect2(Vector2(18.0, 18.0), Vector2(360.0, 56.0)), ink_col, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(28.0, 40.0), "N%d — %s" % [_zoom_level, str(data.get("name", ""))], HORIZONTAL_ALIGNMENT_LEFT, 340, 14, Color(0.92, 0.25, 0.20) if not is_night else Color(0.95, 0.55, 0.16))
	draw_string(ThemeDB.fallback_font, Vector2(28.0, 60.0), str(data.get("subtitle", "")), HORIZONTAL_ALIGNMENT_LEFT, 340, 11, c_txt)

	# Légende / Info survol ou message bas de plan
	var info_msg: String = _notice_text if _notice_text != "" else _hover_lore
	if info_msg == "":
		info_msg = "Clic gauche : zoomer / entrer  •  Molette : zoom  •  Clic droit : déplacer"
	draw_rect(Rect2(Vector2(18.0, mh - 46.0), Vector2(mw - 36.0, 32.0)), c_bg, true)
	draw_rect(Rect2(Vector2(18.0, mh - 46.0), Vector2(mw - 36.0, 32.0)), ink_col, false, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(28.0, mh - 25.0), info_msg, HORIZONTAL_ALIGNMENT_LEFT, int(mw - 56.0), 11, c_txt)

	# Rose des vents N
	var comp: Vector2 = Vector2(mw - 48.0, 46.0)
	draw_circle(comp, 18.0, c_bg)
	draw_arc(comp, 18.0, 0.0, TAU, 24, ink_col, 1.8)
	draw_string(ThemeDB.fallback_font, comp + Vector2(-5.0, -4.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.88, 0.20, 0.20))
	draw_line(comp + Vector2(0.0, 10.0), comp + Vector2(0.0, -2.0), ink_col, 2.0)

func _draw_map_badge(pos: Vector2, text: String, border_col: Color, is_night: bool) -> void:
	var bg: Color = Color(0.08, 0.09, 0.12, 0.92) if is_night else Color(0.98, 0.96, 0.90, 0.94)
	var fg: Color = Color(0.97, 0.95, 0.90) if is_night else Color(0.10, 0.10, 0.12)
	var w: float = maxf(96.0, float(text.length()) * 7.2 + 16.0)
	draw_rect(Rect2(pos, Vector2(w, 22.0)), bg, true)
	draw_rect(Rect2(pos, Vector2(w, 22.0)), border_col, false, 1.8)
	draw_string(ThemeDB.fallback_font, pos + Vector2(8.0, 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, fg)

func _draw_squad_pin(pos: Vector2, label: String, col: Color = Color(0.95, 0.55, 0.16)) -> void:
	draw_rect(Rect2(pos - Vector2(4.0, 8.0), Vector2(40.0, 16.0)), col, true)
	draw_rect(Rect2(pos - Vector2(4.0, 8.0), Vector2(40.0, 16.0)), Color(0.06, 0.06, 0.07), false, 1.4)
	draw_string(ThemeDB.fallback_font, pos + Vector2(2.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.08, 0.08, 0.09))

func _to_vec2(arr_var: Variant) -> Vector2:
	if arr_var is Array:
		var arr: Array = arr_var as Array
		if arr.size() >= 2:
			return Vector2(float(arr[0]), float(arr[1]))
	return Vector2.ZERO

func _to_poly(arr_var: Variant) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if arr_var is Array:
		for pt in (arr_var as Array):
			out.append(_to_vec2(pt))
	return out

func _load_texture_safe(res_path: String) -> Texture2D:
	return DataLoader.load_texture_safe(res_path)
