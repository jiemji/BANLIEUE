extends Node2D

signal hotspot_activated(dialogue_id: String, hotspot_data: Dictionary)

const TILE_W: float = 86.0
const TILE_H: float = 43.0
const ORIGIN: Vector2 = Vector2(455.0, 210.0)

var current_loc_id: String = "box_garage"
var pawn_grid_pos: Vector2 = Vector2(3.0, 4.0)
var pawn_target_pos: Vector2 = Vector2(3.0, 4.0)
var pending_hotspot: Dictionary = {}
var input_blocked: bool = false

var train_fantome_active: bool = false
var train_x_progress: float = -2.0
var _pulse_time: float = 0.0
var _backdrop_cache: Dictionary = {}

func _ready() -> void:
	set_location("box_garage")

func set_location(loc_id: String) -> void:
	current_loc_id = loc_id
	var loc: Dictionary = DataLoader.get_location(loc_id)
	var sp_var: Variant = loc.get("spawn", [3, 4])
	if sp_var is Array and (sp_var as Array).size() >= 2:
		var arr: Array = sp_var as Array
		pawn_grid_pos = Vector2(float(arr[0]), float(arr[1]))
	else:
		pawn_grid_pos = Vector2(3.0, 4.0)
	pawn_target_pos = pawn_grid_pos
	pending_hotspot = {}
	queue_redraw()

func trigger_train_fantome() -> void:
	train_fantome_active = true
	train_x_progress = -3.0
	queue_redraw()

func iso_to_screen(gx: float, gy: float) -> Vector2:
	var sx: float = (gx - gy) * (TILE_W * 0.5)
	var sy: float = (gx + gy) * (TILE_H * 0.5)
	return ORIGIN + Vector2(sx, sy)

func screen_to_iso(pos: Vector2) -> Vector2:
	var rel: Vector2 = pos - ORIGIN
	var hw: float = TILE_W * 0.5
	var hh: float = TILE_H * 0.5
	var gx: float = (rel.x / hw + rel.y / hh) * 0.5
	var gy: float = (rel.y / hh - rel.x / hw) * 0.5
	return Vector2(gx, gy)

func _process(delta: float) -> void:
	_pulse_time += delta
	var moved: bool = false
	if pawn_grid_pos.distance_to(pawn_target_pos) > 0.05:
		pawn_grid_pos = pawn_grid_pos.move_toward(pawn_target_pos, delta * 5.2)
		moved = true
	elif not pending_hotspot.is_empty():
		var hs: Dictionary = pending_hotspot
		pending_hotspot = {}
		var dlg_id: String = str(hs.get("dialogue_id", ""))
		if dlg_id != "":
			hotspot_activated.emit(dlg_id, hs)

	if train_fantome_active:
		train_x_progress += delta * 2.1
		if train_x_progress > 10.5:
			train_x_progress = 3.2 # Reste arrêté sur le quai pour couper la ligne de vue
		moved = true

	if moved or GameState.phase == "night":
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if input_blocked:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Ignorer les clics dans le panneau latéral droit ou le bandeau haut
			if mb.position.x > 910.0 or mb.position.y < 54.0:
				return
			var loc: Dictionary = DataLoader.get_location(current_loc_id)
			var gw: int = int(loc.get("grid_w", 8))
			var gh: int = int(loc.get("grid_h", 8))

			# Vérifier clic direct sur hotspot à l'écran
			var hs_list_var: Variant = loc.get("hotspots", [])
			if hs_list_var is Array:
				for hs_var in (hs_list_var as Array):
					if hs_var is Dictionary:
						var hs: Dictionary = hs_var as Dictionary
						var hx: float = float(hs.get("grid_x", 0)) + 0.5
						var hy: float = float(hs.get("grid_y", 0)) + 0.5
						var hs_screen: Vector2 = iso_to_screen(hx, hy)
						if mb.position.distance_to(hs_screen) <= 36.0:
							pawn_target_pos = Vector2(hx, hy)
							pending_hotspot = hs
							AudioRadio.play_cassette_click()
							get_viewport().set_input_as_handled()
							return

			# Sinon déplacement sur la dalle isométrique
			var gpos: Vector2 = screen_to_iso(mb.position)
			if gpos.x >= 0.0 and gpos.x < float(gw) and gpos.y >= 1.0 and gpos.y < float(gh):
				pawn_target_pos = Vector2(clampf(gpos.x, 0.5, float(gw) - 0.5), clampf(gpos.y, 1.2, float(gh) - 0.5))
				pending_hotspot = {}
				get_viewport().set_input_as_handled()

func _draw() -> void:
	var loc: Dictionary = DataLoader.get_location(current_loc_id)
	var is_night: bool = (GameState.phase == "night")
	var low_moral: bool = GameState.get_lowest_moral() <= 40

	var backdrop_path: String = str(loc.get("backdrop", ""))
	var backdrop_tex: Texture2D = _load_texture_safe(backdrop_path) if backdrop_path != "" else null

	if backdrop_tex != null:
		# Fond charcoal accordé au diorama isométrique + cadrage BD encré
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color(0.078, 0.078, 0.094), true)
		var avail: Rect2 = Rect2(20.0, 56.0, 888.0, 650.0)
		var tex_size: Vector2 = backdrop_tex.get_size()
		var scale_fit: float = minf(avail.size.x / maxf(tex_size.x, 1.0), avail.size.y / maxf(tex_size.y, 1.0))
		var draw_size: Vector2 = tex_size * scale_fit
		var draw_pos: Vector2 = avail.position + (avail.size - draw_size) * 0.5
		var tint_col: Color = Color(0.68, 0.72, 0.82) if is_night else Color.WHITE
		draw_texture_rect(backdrop_tex, Rect2(draw_pos, draw_size), false, tint_col)
		draw_rect(Rect2(draw_pos, draw_size), Color(0.06, 0.06, 0.07), false, 2.5)
	else:
		# Fond de scène BD / Nuit
		var bg_col: Color = Color.html(str(loc.get("night_tint", "#181920"))) if is_night else Color.html(str(loc.get("day_tint", "#cfc6b4")))
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), bg_col.darkened(0.28 if not is_night else 0.35), true)

		# Silhouette lointaine des tours / Poudrerie en toile de fond
		_draw_horizon_silhouette(is_night, low_moral)

		var gw: int = int(loc.get("grid_w", 8))
		var gh: int = int(loc.get("grid_h", 8))
		var ink_col: Color = Color(0.06, 0.06, 0.08)

		# 1. Sol isométrique
		for gy in range(gh):
			for gx in range(gw):
				var p0: Vector2 = iso_to_screen(float(gx), float(gy))
				var p1: Vector2 = iso_to_screen(float(gx + 1), float(gy))
				var p2: Vector2 = iso_to_screen(float(gx + 1), float(gy + 1))
				var p3: Vector2 = iso_to_screen(float(gx), float(gy + 1))
				var tile_col: Color = bg_col
				if (gx + gy) % 2 == 0:
					tile_col = tile_col.lightened(0.06)
				else:
					tile_col = tile_col.darkened(0.05)

				if current_loc_id == "gare_rer_y" and (gy == 1 or gy == 2):
					tile_col = Color(0.18, 0.19, 0.22) if is_night else Color(0.32, 0.33, 0.36)
				draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), tile_col)
				draw_polyline(PackedVector2Array([p0, p1, p2, p3, p0]), Color(ink_col.r, ink_col.g, ink_col.b, 0.35), 1.2)

		# 2. Props isométriques triés du fond vers l'avant
		var props_var: Variant = loc.get("props", [])
		if props_var is Array:
			for pv in (props_var as Array):
				if pv is Dictionary:
					_draw_prop(pv as Dictionary, is_night)

	# 3. Train Fantôme sur la Gare RER « du Y »
	if current_loc_id == "gare_rer_y" and (train_fantome_active or (is_night and GameState.has_flag("encounter_gare_done"))):
		_draw_ghost_train()

	# 4. Hotspots interactifs
	var hs_var: Variant = loc.get("hotspots", [])
	if hs_var is Array:
		for hsv in (hs_var as Array):
			if hsv is Dictionary:
				_draw_hotspot(hsv as Dictionary, is_night)

	# 5. Pions du sous-groupe actif
	_draw_active_squad_pawns(is_night, low_moral)

	# 6. Petit détail qui cloche (Girouette RER ou horloge sur gare_rer_y la nuit / bas Moral)
	if current_loc_id == "gare_rer_y" and (is_night or low_moral):
		var sign_pos: Vector2 = iso_to_screen(3.5, 3.0) + Vector2(-72.0, -70.0)
		var odd_txt: String = "CRADON-CENTRE [HORS-PLAN]" if int(_pulse_time * 0.7) % 3 == 0 else "RER B — BIFURCATION Y"
		draw_rect(Rect2(sign_pos, Vector2(168.0, 22.0)), Color(0.08, 0.12, 0.28, 0.92), true)
		draw_rect(Rect2(sign_pos, Vector2(168.0, 22.0)), Color(0.32, 0.68, 0.95), false, 1.5)
		draw_string(ThemeDB.fallback_font, sign_pos + Vector2(6.0, 15.0), odd_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.88, 0.95, 1.0))

func _draw_horizon_silhouette(is_night: bool, low_moral: bool) -> void:
	var sil_col: Color = Color(0.08, 0.08, 0.11, 0.65) if is_night else Color(0.45, 0.44, 0.42, 0.35)
	var towers: Array[Rect2] = [
		Rect2(30, 62, 55, 130),
		Rect2(96, 88, 42, 104),
		Rect2(780, 74, 58, 124),
		Rect2(846, 98, 40, 100)
	]
	for r in towers:
		draw_rect(r, sil_col, true)
	if is_night or low_moral:
		# Halo bleu-pâle discret vers la Poudrerie (coin haut gauche)
		draw_circle(Vector2(140.0, 120.0), 42.0 + sin(_pulse_time * 1.4) * 4.0, Color(0.45, 0.82, 0.92, 0.10))

func _draw_prop(prop: Dictionary, is_night: bool) -> void:
	var ptype: String = str(prop.get("type", "box"))
	var gx: float = float(prop.get("x", 0))
	var gy: float = float(prop.get("y", 0))
	var w: float = float(prop.get("w", 1))
	var h: float = float(prop.get("h", 1))
	var lbl: String = str(prop.get("label", ""))

	if ptype == "rails":
		var r0: Vector2 = iso_to_screen(gx, gy + 0.35)
		var r1: Vector2 = iso_to_screen(gx + w, gy + 0.35)
		var r2: Vector2 = iso_to_screen(gx, gy + 1.45)
		var r3: Vector2 = iso_to_screen(gx + w, gy + 1.45)
		draw_line(r0, r1, Color(0.55, 0.62, 0.72), 2.5)
		draw_line(r2, r3, Color(0.55, 0.62, 0.72), 2.5)
		return
	if ptype == "platform":
		_draw_iso_box(gx, gy, w, h, 8.0, Color(0.52, 0.54, 0.56) if not is_night else Color(0.24, 0.25, 0.28), "")
		return

	var height_px: float = 24.0
	var col: Color = Color(0.65, 0.58, 0.50)
	if ptype == "wall_back":
		height_px = 46.0
		col = Color(0.54, 0.50, 0.46) if not is_night else Color(0.18, 0.18, 0.22)
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

	_draw_iso_box(gx, gy, w, h, height_px, col, lbl)

func _draw_iso_box(gx: float, gy: float, w: float, h: float, height_px: float, top_col: Color, label: String) -> void:
	var b0: Vector2 = iso_to_screen(gx, gy)
	var b1: Vector2 = iso_to_screen(gx + w, gy)
	var b2: Vector2 = iso_to_screen(gx + w, gy + h)
	var b3: Vector2 = iso_to_screen(gx, gy + h)

	var up: Vector2 = Vector2(0.0, -height_px)
	var t0: Vector2 = b0 + up
	var t1: Vector2 = b1 + up
	var t2: Vector2 = b2 + up
	var t3: Vector2 = b3 + up

	var ink: Color = Color(0.06, 0.06, 0.07)
	# Face droite
	draw_colored_polygon(PackedVector2Array([t1, t2, b2, b1]), top_col.darkened(0.26))
	draw_polyline(PackedVector2Array([t1, t2, b2, b1, t1]), ink, 1.5)
	# Face gauche
	draw_colored_polygon(PackedVector2Array([t3, t2, b2, b3]), top_col.darkened(0.14))
	draw_polyline(PackedVector2Array([t3, t2, b2, b3, t3]), ink, 1.5)
	# Dessus
	draw_colored_polygon(PackedVector2Array([t0, t1, t2, t3]), top_col)
	draw_polyline(PackedVector2Array([t0, t1, t2, t3, t0]), ink, 1.8)

	if label != "":
		var center: Vector2 = (t0 + t2) * 0.5
		draw_string(ThemeDB.fallback_font, center + Vector2(-28.0, -6.0), label, HORIZONTAL_ALIGNMENT_CENTER, 72, 11, Color(0.95, 0.94, 0.90))

func _draw_ghost_train() -> void:
	var c_start: Vector2 = iso_to_screen(train_x_progress, 1.5)
	var c_end: Vector2 = iso_to_screen(train_x_progress + 3.8, 1.5)
	var body_dir: Vector2 = (c_end - c_start)
	var up: Vector2 = Vector2(0.0, -34.0)
	var poly: PackedVector2Array = PackedVector2Array([c_start, c_end, c_end + up, c_start + up])
	draw_colored_polygon(poly, Color(0.16, 0.22, 0.34, 0.94))
	draw_polyline(poly, Color(0.45, 0.85, 0.96), 2.0)
	for i in range(4):
		var f: float = 0.14 + float(i) * 0.21
		var win_p: Vector2 = c_start + body_dir * f + Vector2(0.0, -22.0)
		draw_rect(Rect2(win_p, Vector2(18.0, 10.0)), Color(0.65, 0.92, 0.98, 0.88), true)

func _draw_hotspot(hs: Dictionary, is_night: bool) -> void:
	var req_phase: String = str(hs.get("phase", "any"))
	if req_phase != "any" and req_phase != GameState.phase and not (req_phase == "day" and GameState.phase == "twilight"):
		return
	var hx: float = float(hs.get("grid_x", 0)) + 0.5
	var hy: float = float(hs.get("grid_y", 0)) + 0.5
	var center: Vector2 = iso_to_screen(hx, hy)
	var col: Color = Color.html(str(hs.get("color_hex", "#f28c28")))
	var pulse: float = 16.0 + sin(_pulse_time * 4.0) * 3.5

	var pts: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -pulse * 0.55),
		center + Vector2(pulse, 0.0),
		center + Vector2(0.0, pulse * 0.55),
		center + Vector2(-pulse, 0.0)
	])
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.28))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), col, 2.2)

	var lbl: String = str(hs.get("label", "Inspecter"))
	var badge_pos: Vector2 = center + Vector2(-56.0, -34.0)
	var bg_badge: Color = Color(0.08, 0.08, 0.10, 0.86) if is_night else Color(0.10, 0.09, 0.08, 0.82)
	draw_rect(Rect2(badge_pos, Vector2(142.0, 20.0)), bg_badge, true)
	draw_rect(Rect2(badge_pos, Vector2(142.0, 20.0)), col, false, 1.5)
	draw_string(ThemeDB.fallback_font, badge_pos + Vector2(5.0, 14.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, 134, 11, Color(0.97, 0.95, 0.90))

func _draw_active_squad_pawns(is_night: bool, low_moral: bool) -> void:
	var members: Array[String] = GameState.get_active_group_members()
	var offsets: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(-22.0, 8.0), Vector2(22.0, 8.0), Vector2(0.0, 16.0)]
	var base_screen: Vector2 = iso_to_screen(pawn_grid_pos.x, pawn_grid_pos.y)

	for i in range(members.size()):
		var cid: String = members[i]
		var cdef: Dictionary = DataLoader.get_character(cid)
		var col: Color = Color.html(str(cdef.get("color_hex", "#f28c28")))
		var off: Vector2 = offsets[i % offsets.size()]
		var pos: Vector2 = base_screen + off

		# Ombre portée qui s'allonge la nuit / bas Moral ("petit détail qui cloche")
		var shadow_len: float = 16.0 if not (is_night or low_moral) else 34.0
		draw_line(pos, pos + Vector2(shadow_len, 6.0), Color(0.04, 0.04, 0.05, 0.55), 5.0)

		# Corps stylisé BD encré
		draw_circle(pos + Vector2(0.0, -14.0), 11.0, col)
		draw_arc(pos + Vector2(0.0, -14.0), 11.0, 0.0, TAU, 24, Color(0.06, 0.06, 0.07), 2.4)
		draw_circle(pos + Vector2(0.0, -28.0), 7.5, Color(0.93, 0.84, 0.76))
		draw_arc(pos + Vector2(0.0, -28.0), 7.5, 0.0, TAU, 20, Color(0.06, 0.06, 0.07), 2.2)

		var short_name: String = str(cdef.get("name", cid)).split(" ")[0]
		draw_string(ThemeDB.fallback_font, pos + Vector2(-24.0, -40.0), short_name, HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color(0.98, 0.96, 0.92))

func _load_texture_safe(res_path: String) -> Texture2D:
	if res_path == "":
		return null
	if _backdrop_cache.has(res_path):
		var cached: Variant = _backdrop_cache.get(res_path, null)
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
	_backdrop_cache[res_path] = tex
	return tex
