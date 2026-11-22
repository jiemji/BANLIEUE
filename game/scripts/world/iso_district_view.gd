extends Node2D

signal hotspot_activated(dialogue_id: String, hotspot_data: Dictionary)
signal exit_activated(exit_data: Dictionary)
signal squad_member_clicked(group_id: int, char_id: String)
signal combat_actor_hovered(kind: String, entity_id: String)
signal combat_actor_clicked(kind: String, entity_id: String)
signal combat_cancel_requested

const PawnActorScript: GDScript = preload("res://scripts/world/pawn_actor.gd")
const IsoPropNodeScript: GDScript = preload("res://scripts/world/iso_prop_node.gd")

var current_loc_id: String = "box_garage"
var tile_w: float = 86.0
var tile_h: float = 43.0
var iso_origin: Vector2 = Vector2(455.0, 210.0)
var grid_w: int = 8
var grid_h: int = 8
var render_mode: String = "backdrop"

var pawn_grid_pos: Vector2 = Vector2(3.0, 4.0)
var pawn_target_pos: Vector2 = Vector2(3.0, 4.0)
var pending_hotspot: Dictionary = {}
var pending_exit: Dictionary = {}
var input_blocked: bool = false

var train_fantome_active: bool = false
var train_x_progress: float = -2.0
var _pulse_time: float = 0.0
var _backdrop_cache: Dictionary = {}
var _pawn_container: Node2D = null
var _markers_overlay: Node2D = null
var _pawn_actors: Dictionary = {}
var _npc_actors: Dictionary = {}
var _prop_nodes: Array[Node2D] = []
var _occluder_nodes: Array[Node2D] = []
var _blocked_cells: Dictionary = {}

var _camera: Camera2D = null
var _cam_zoom: float = 1.0
var _cam_min_zoom: float = 0.75
var _cam_max_zoom: float = 1.60
var _cam_follow_squad: bool = false
var _focus_world: Vector2 = Vector2(455.0, 387.0)
var _pan_dragging: bool = false
var _pan_last_screen: Vector2 = Vector2.ZERO
var _manual_pan_offset: Vector2 = Vector2.ZERO
var _title_backdrop_mode: bool = false
var _title_cam_drift: Vector2 = Vector2.ZERO
var _combat_stage_mode: bool = false
var combat_input_blocked: bool = false
var _combat_timeline: Node = null
var _combat_enemy_actors: Dictionary = {}
var _combat_hovered_kind: String = ""
var _combat_hovered_id: String = ""
var _combat_ext_hovered_kind: String = ""
var _combat_ext_hovered_id: String = ""
var _combat_target_kind: String = ""
var _combat_valid_targets: Array[String] = []
var _combat_hit_entries: Array[Dictionary] = []

func _ready() -> void:
	_camera = Camera2D.new()
	_camera.enabled = true
	_camera.position_smoothing_enabled = false
	add_child(_camera)

	_pawn_container = Node2D.new()
	_pawn_container.y_sort_enabled = true
	add_child(_pawn_container)

	_markers_overlay = Node2D.new()
	_markers_overlay.z_index = 3700
	_markers_overlay.draw.connect(_draw_markers_overlay)
	add_child(_markers_overlay)

	set_location("box_garage")
	set_view_active(true)

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

## Bascule le mode fond vivant d'accueil : masque les marqueurs interactifs et applique le cadrage/dérive caméra.
func set_title_backdrop_mode(enabled: bool, drift: Vector2 = Vector2.ZERO) -> void:
	_title_backdrop_mode = enabled
	_title_cam_drift = drift
	if _markers_overlay != null:
		_markers_overlay.visible = not _title_backdrop_mode and not _combat_stage_mode
	_apply_camera_transform()

## Lie la scène isométrique à TensionTimeline pour synchroniser le plateau de combat.
func bind_combat_timeline(tl: Node) -> void:
	_combat_timeline = tl
	if _combat_timeline != null and _combat_timeline.has_signal("timeline_updated"):
		_combat_timeline.timeline_updated.connect(refresh_combat_stage)

## Met à jour l'état de ciblage sur la grille isométrique ("enemy", "ally", "ally_crisis" ou "").
func set_combat_targeting(target_kind: String, valid_ids: Array) -> void:
	_combat_target_kind = target_kind
	_combat_valid_targets.clear()
	for vid in valid_ids:
		_combat_valid_targets.append(str(vid))
	refresh_combat_stage()

## Surligne un pion depuis un survol externe (ex. carte de la Frise haute).
func set_combat_external_hover(kind: String, entity_id: String) -> void:
	_combat_ext_hovered_kind = kind
	_combat_ext_hovered_id = entity_id
	if _combat_stage_mode:
		refresh_combat_stage()

## Force la mise à jour des pions de combat et du quadrillage.
func refresh_combat_stage() -> void:
	if not _combat_stage_mode:
		return
	_sync_pawn_actors()
	queue_redraw()

## Retourne les positions courantes des protagonistes déployés en mode combat.
func get_combat_stage_positions() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for he in _combat_hit_entries:
		var gv: Vector2 = he.get("grid", Vector2.ZERO) as Vector2
		res.append({
			"kind": str(he.get("kind", "")),
			"id": str(he.get("id", "")),
			"gx": gv.x,
			"gy": gv.y
		})
	return res

## Bascule le mode scène ouverte de combat : masque les marqueurs d'exploration et recentre le décor.
func set_combat_stage_mode(enabled: bool) -> void:
	_combat_stage_mode = enabled
	_combat_hovered_kind = ""
	_combat_hovered_id = ""
	_combat_ext_hovered_kind = ""
	_combat_ext_hovered_id = ""
	_combat_target_kind = ""
	_combat_valid_targets.clear()
	if _markers_overlay != null:
		_markers_overlay.visible = not _title_backdrop_mode and not _combat_stage_mode
	for on in _occluder_nodes:
		if is_instance_valid(on):
			on.visible = not enabled
	if enabled:
		_manual_pan_offset = Vector2.ZERO
		_focus_world = iso_to_screen(float(grid_w) * 0.5, float(grid_h) * 0.5)
	else:
		_combat_hit_entries.clear()
		for ek_var in _combat_enemy_actors.keys():
			var enode_var: Variant = _combat_enemy_actors.get(ek_var, null)
			if enode_var is Node2D:
				(enode_var as Node2D).visible = false
		for ak_var in _pawn_actors.keys():
			var anode_var: Variant = _pawn_actors.get(ak_var, null)
			if anode_var is Node2D:
				(anode_var as Node2D).call("set_combat_highlight", false, false, false, false, "", 0.0)
		var loc: Dictionary = DataLoader.get_location(current_loc_id)
		var is_night: bool = (GameState.phase == "night")
		var occ_tint: Color = Color(0.68, 0.72, 0.82) if is_night else Color.WHITE
		for on2 in _occluder_nodes:
			if is_instance_valid(on2):
				on2.modulate = occ_tint
		_rebuild_combat_focus_restore(loc)
	_apply_camera_transform()
	_sync_pawn_actors()
	queue_redraw()

func _rebuild_combat_focus_restore(loc: Dictionary) -> void:
	var cam_var: Variant = loc.get("camera", {})
	if cam_var is Dictionary and bool((cam_var as Dictionary).get("follow_squad", false)):
		_focus_world = iso_to_screen(pawn_grid_pos.x, pawn_grid_pos.y)
	else:
		_focus_world = Vector2(455.0, 387.0)

func set_location(loc_id: String) -> void:
	current_loc_id = loc_id
	var loc: Dictionary = DataLoader.get_location(loc_id)
	tile_w = float(loc.get("tile_w", 86.0))
	tile_h = float(loc.get("tile_h", 43.0))
	grid_w = maxi(4, int(loc.get("grid_w", 8)))
	grid_h = maxi(4, int(loc.get("grid_h", 8)))
	render_mode = str(loc.get("render_mode", "backdrop"))

	if grid_w == 8 and grid_h == 8 and render_mode == "backdrop":
		iso_origin = Vector2(455.0, 210.0)
	else:
		var mid_rx: float = float(grid_w - grid_h) * tile_w * 0.25
		var mid_ry: float = float(grid_w + grid_h) * tile_h * 0.25
		iso_origin = Vector2(455.0 - mid_rx, 387.0 - mid_ry)

	_blocked_cells.clear()
	var raw_blocked: Variant = loc.get("blocked_cells", [])
	if raw_blocked is Array:
		for cv in (raw_blocked as Array):
			if cv is Array and (cv as Array).size() >= 2:
				var ca: Array = cv as Array
				_blocked_cells["%d,%d" % [int(ca[0]), int(ca[1])]] = true

	var gp: Vector2 = GameState.get_active_group_grid_pos()
	pawn_grid_pos = Vector2(clampf(gp.x, 0.5, float(grid_w) - 0.5), clampf(gp.y, 1.2, float(grid_h) - 0.5))
	pawn_target_pos = pawn_grid_pos
	GameState.set_group_grid_pos(GameState.active_group_id, pawn_grid_pos)
	pending_hotspot = {}
	pending_exit = {}

	var cam_var: Variant = loc.get("camera", {})
	if cam_var is Dictionary:
		var cd: Dictionary = cam_var as Dictionary
		_cam_zoom = float(cd.get("default_zoom", 1.0))
		_cam_min_zoom = float(cd.get("min_zoom", 0.70))
		_cam_max_zoom = float(cd.get("max_zoom", 1.60))
		_cam_follow_squad = bool(cd.get("follow_squad", false))
	else:
		_cam_zoom = 1.0
		_cam_min_zoom = 0.75
		_cam_max_zoom = 1.50
		_cam_follow_squad = false

	_manual_pan_offset = Vector2.ZERO
	_focus_world = iso_to_screen(pawn_grid_pos.x, pawn_grid_pos.y) if _cam_follow_squad else Vector2(455.0, 387.0)
	_rebuild_depth_decor(loc)
	_apply_camera_transform()
	queue_redraw()

func sync_active_group_from_state() -> void:
	var gp: Vector2 = GameState.get_active_group_grid_pos()
	pawn_grid_pos = Vector2(clampf(gp.x, 0.5, float(grid_w) - 0.5), clampf(gp.y, 1.2, float(grid_h) - 0.5))
	pawn_target_pos = pawn_grid_pos
	pending_hotspot = {}
	pending_exit = {}
	_manual_pan_offset = Vector2.ZERO
	if _cam_follow_squad:
		_focus_world = iso_to_screen(pawn_grid_pos.x, pawn_grid_pos.y)
		_apply_camera_transform()
	queue_redraw()

func trigger_train_fantome() -> void:
	train_fantome_active = true
	train_x_progress = -3.0
	queue_redraw()

func iso_to_screen(gx: float, gy: float) -> Vector2:
	var sx: float = (gx - gy) * (tile_w * 0.5)
	var sy: float = (gx + gy) * (tile_h * 0.5)
	return iso_origin + Vector2(sx, sy)

func screen_to_iso(world_pos: Vector2) -> Vector2:
	var rel: Vector2 = world_pos - iso_origin
	var hw: float = tile_w * 0.5
	var hh: float = tile_h * 0.5
	var gx: float = (rel.x / hw + rel.y / hh) * 0.5
	var gy: float = (rel.y / hh - rel.x / hw) * 0.5
	return Vector2(gx, gy)

func _is_cell_blocked(gx: float, gy: float) -> bool:
	var cx: int = int(floor(gx))
	var cy: int = int(floor(gy))
	if cx < 0 or cx >= grid_w or cy < 1 or cy >= grid_h:
		return true
	return _blocked_cells.has("%d,%d" % [cx, cy])

func _apply_camera_transform() -> void:
	if _camera == null or not _camera.enabled:
		return
	if _title_backdrop_mode:
		_camera.zoom = Vector2(1.08, 1.08)
		_camera.position = Vector2(455.0, 387.0) + Vector2(-170.0, 0.0) + _title_cam_drift
		return
	if _combat_stage_mode:
		var cz: float = 0.82
		_camera.zoom = Vector2(cz, cz)
		_camera.position = Vector2(455.0, 342.0) + Vector2(0.0, 58.0 / cz)
		return
	var z: float = clampf(_cam_zoom, _cam_min_zoom, _cam_max_zoom)
	_camera.zoom = Vector2(z, z)
	# Compense le panneau latéral droit (918..1280) et le bandeau haut (0..54) : centre utile (455, 387)
	_camera.position = _focus_world + Vector2(185.0, -27.0) / z

func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_time += delta
	if _combat_stage_mode:
		if train_fantome_active:
			train_x_progress += delta * 2.1
			if train_x_progress > float(grid_w) + 2.5:
				train_x_progress = 3.2
		_sync_pawn_actors()
		queue_redraw()
		return
	var moved: bool = false
	if pawn_grid_pos.distance_to(pawn_target_pos) > 0.05:
		pawn_grid_pos = pawn_grid_pos.move_toward(pawn_target_pos, delta * 5.2)
		GameState.set_group_grid_pos(GameState.active_group_id, pawn_grid_pos)
		moved = true
	elif not pending_hotspot.is_empty():
		var hs: Dictionary = pending_hotspot
		pending_hotspot = {}
		var dlg_id: String = str(hs.get("dialogue_id", ""))
		if dlg_id != "":
			hotspot_activated.emit(dlg_id, hs)
	elif not pending_exit.is_empty():
		var ex: Dictionary = pending_exit
		pending_exit = {}
		exit_activated.emit(ex)

	if train_fantome_active:
		train_x_progress += delta * 2.1
		if train_x_progress > float(grid_w) + 2.5:
			train_x_progress = 3.2
		moved = true

	var did_key_pan: bool = false
	if not input_blocked:
		var pan_vec: Vector2 = Vector2.ZERO
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
			pan_vec.x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			pan_vec.x += 1.0
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
			pan_vec.y -= 1.0
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			pan_vec.y += 1.0
		if pan_vec != Vector2.ZERO:
			var pan_step: Vector2 = pan_vec.normalized() * delta * 340.0 / maxf(_cam_zoom, 0.25)
			_focus_world += pan_step
			if _cam_follow_squad:
				_manual_pan_offset += pan_step
			_clamp_camera_focus()
			_apply_camera_transform()
			did_key_pan = true

	if _cam_follow_squad and not _pan_dragging and not did_key_pan:
		var target_focus: Vector2 = iso_to_screen(pawn_grid_pos.x, pawn_grid_pos.y) + _manual_pan_offset
		if _focus_world.distance_to(target_focus) > 0.5:
			_focus_world = _focus_world.lerp(target_focus, minf(1.0, delta * 7.0))
			_apply_camera_transform()

	if moved or GameState.phase == "night":
		queue_redraw()
	else:
		_sync_pawn_actors()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _combat_stage_mode:
		if not combat_input_blocked:
			_handle_combat_input(event)
		return
	if input_blocked:
		return

	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _pan_dragging:
			var d_screen: Vector2 = mm.position - _pan_last_screen
			_pan_last_screen = mm.position
			var d_world: Vector2 = d_screen / maxf(_cam_zoom, 0.1)
			_focus_world -= d_world
			if _cam_follow_squad:
				_manual_pan_offset -= d_world
			_clamp_camera_focus()
			_apply_camera_transform()
			get_viewport().set_input_as_handled()
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
			_cam_zoom = clampf(_cam_zoom + 0.10, _cam_min_zoom, _cam_max_zoom)
			_apply_camera_transform()
			get_viewport().set_input_as_handled()
			return

		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_cam_zoom = clampf(_cam_zoom - 0.10, _cam_min_zoom, _cam_max_zoom)
			_apply_camera_transform()
			get_viewport().set_input_as_handled()
			return

		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var world_pos: Vector2 = get_canvas_transform().affine_inverse() * mb.position
			var loc: Dictionary = DataLoader.get_location(current_loc_id)
			var backdrop_path: String = str(loc.get("backdrop", ""))
			var has_backdrop: bool = (render_mode == "backdrop" and backdrop_path != "" and _load_texture_safe(backdrop_path) != null)
			var hit_h: float = 166.0 if has_backdrop else 118.0

			# 0. Priorité 1 : Sélectionner un personnage d'un autre sous-groupe présent dans la même pièce
			var hit_candidates: Array[Dictionary] = []
			for gid in GameState.get_groups_in_location(current_loc_id):
				if gid == GameState.active_group_id:
					continue
				for cid in GameState.get_group_members(gid):
					if _pawn_actors.has(cid):
						var act_var: Variant = _pawn_actors.get(cid, null)
						if act_var is Node2D and (act_var as Node2D).visible:
							hit_candidates.append({
								"gid": gid,
								"cid": cid,
								"actor": act_var as Node2D
							})
			hit_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var na: Node2D = a.get("actor", null) as Node2D
				var nb: Node2D = b.get("actor", null) as Node2D
				return na.position.y > nb.position.y
			)
			for cand in hit_candidates:
				var actor_c: Node2D = cand.get("actor", null) as Node2D
				var crect: Rect2 = Rect2(actor_c.position.x - 36.0, actor_c.position.y - hit_h, 72.0, hit_h + 10.0)
				if crect.has_point(world_pos):
					var tgt_gid: int = int(cand.get("gid", 0))
					var tgt_cid: String = str(cand.get("cid", ""))
					squad_member_clicked.emit(tgt_gid, tgt_cid)
					AudioRadio.play_cassette_click()
					get_viewport().set_input_as_handled()
					return

			# 1. Vérifier clic direct sur PNJ visible
			var npcs_visible: Array[Dictionary] = _get_visible_npcs(loc)
			for npc in npcs_visible:
				var nx: float = float(npc.get("grid_x", 3.0))
				var ny: float = float(npc.get("grid_y", 4.0))
				var npos: Vector2 = iso_to_screen(nx, ny)
				var hit_rect: Rect2 = Rect2(npos.x - 36.0, npos.y - hit_h, 72.0, hit_h + 10.0)
				if hit_rect.has_point(world_pos):
					var stand_gx: float = clampf(nx + 0.15, 0.5, float(grid_w) - 0.5)
					var stand_gy: float = clampf(ny + 0.65, 1.2, float(grid_h) - 0.5)
					pawn_target_pos = Vector2(stand_gx, stand_gy)
					pending_exit = {}
					pending_hotspot = {
						"id": str(npc.get("id", "")),
						"label": str(npc.get("label", "")),
						"grid_x": stand_gx,
						"grid_y": stand_gy,
						"dialogue_id": str(npc.get("dialogue_id", ""))
					}
					AudioRadio.play_cassette_click()
					get_viewport().set_input_as_handled()
					return

			# 2. Vérifier clic direct sur hotspot visible
			var hs_list_var: Variant = loc.get("hotspots", [])
			if hs_list_var is Array:
				for hs_var in (hs_list_var as Array):
					if hs_var is Dictionary:
						var hs: Dictionary = hs_var as Dictionary
						var req_phase: String = str(hs.get("phase", "any"))
						if req_phase != "any" and req_phase != GameState.phase and not (req_phase == "day" and GameState.phase == "twilight"):
							continue
						var hx: float = float(hs.get("grid_x", 0)) + 0.5
						var hy: float = float(hs.get("grid_y", 0)) + 0.5
						var hs_screen: Vector2 = iso_to_screen(hx, hy)
						if world_pos.distance_to(hs_screen) <= 36.0:
							pawn_target_pos = Vector2(hx, hy)
							pending_hotspot = hs
							pending_exit = {}
							AudioRadio.play_cassette_click()
							get_viewport().set_input_as_handled()
							return

			# 3. Vérifier clic direct sur sortie vers la carte de ville
			var exits_var: Variant = loc.get("exits", [])
			if exits_var is Array:
				for ex_var in (exits_var as Array):
					if ex_var is Dictionary:
						var ex: Dictionary = ex_var as Dictionary
						var ex_gx: float = float(ex.get("grid_x", float(grid_w) - 1.5))
						var ex_gy: float = float(ex.get("grid_y", float(grid_h) - 1.5))
						var ex_screen: Vector2 = iso_to_screen(ex_gx, ex_gy)
						if world_pos.distance_to(ex_screen) <= 42.0:
							pawn_target_pos = Vector2(clampf(ex_gx, 0.5, float(grid_w) - 0.5), clampf(ex_gy, 1.2, float(grid_h) - 0.5))
							pending_hotspot = {}
							pending_exit = ex
							AudioRadio.play_cassette_click()
							get_viewport().set_input_as_handled()
							return

			# 4. Sinon déplacement sur dalle marchable
			var gpos: Vector2 = screen_to_iso(world_pos)
			if gpos.x >= 0.0 and gpos.x < float(grid_w) and gpos.y >= 1.0 and gpos.y < float(grid_h):
				if not _is_cell_blocked(gpos.x, gpos.y):
					pawn_target_pos = Vector2(clampf(gpos.x, 0.5, float(grid_w) - 0.5), clampf(gpos.y, 1.2, float(grid_h) - 0.5))
					pending_hotspot = {}
					pending_exit = {}
					_manual_pan_offset = Vector2.ZERO
					get_viewport().set_input_as_handled()

func _clamp_camera_focus() -> void:
	var c_top: Vector2 = iso_to_screen(0.0, 0.0)
	var c_right: Vector2 = iso_to_screen(float(grid_w), 0.0)
	var c_bottom: Vector2 = iso_to_screen(float(grid_w), float(grid_h))
	var c_left: Vector2 = iso_to_screen(0.0, float(grid_h))
	_focus_world.x = clampf(_focus_world.x, c_left.x + 40.0, c_right.x - 40.0)
	_focus_world.y = clampf(_focus_world.y, c_top.y + 40.0, c_bottom.y - 40.0)

func _compute_backdrop_rect(backdrop_tex: Texture2D) -> Rect2:
	if grid_w == 8 and grid_h == 8:
		var avail: Rect2 = Rect2(20.0, 56.0, 888.0, 650.0)
		var tex_size: Vector2 = backdrop_tex.get_size()
		var scale_fit: float = minf(avail.size.x / maxf(tex_size.x, 1.0), avail.size.y / maxf(tex_size.y, 1.0))
		var draw_size: Vector2 = tex_size * scale_fit
		var draw_pos: Vector2 = avail.position + (avail.size - draw_size) * 0.5
		return Rect2(draw_pos, draw_size)
	var c_left: Vector2 = iso_to_screen(0.0, float(grid_h))
	var c_right: Vector2 = iso_to_screen(float(grid_w), 0.0)
	var c_top: Vector2 = iso_to_screen(0.0, 0.0)
	var c_bot: Vector2 = iso_to_screen(float(grid_w), float(grid_h))
	var span_w: float = (c_right.x - c_left.x) * 1.25
	var tex_sz: Vector2 = backdrop_tex.get_size()
	var span_h: float = span_w * (tex_sz.y / maxf(tex_sz.x, 1.0))
	var cx: float = (c_left.x + c_right.x) * 0.5
	var cy: float = (c_top.y + c_bot.y) * 0.5 - 24.0
	return Rect2(Vector2(cx - span_w * 0.5, cy - span_h * 0.5), Vector2(span_w, span_h))

func _rebuild_depth_decor(loc: Dictionary) -> void:
	for pn in _prop_nodes:
		if is_instance_valid(pn):
			pn.queue_free()
	_prop_nodes.clear()
	for on in _occluder_nodes:
		if is_instance_valid(on):
			on.queue_free()
	_occluder_nodes.clear()

	if _pawn_container == null:
		return

	var is_night: bool = (GameState.phase == "night")
	var backdrop_path: String = str(loc.get("backdrop", ""))
	var backdrop_tex: Texture2D = _load_texture_safe(backdrop_path) if (render_mode == "backdrop" and backdrop_path != "") else null

	if backdrop_tex != null:
		var draw_rect_target: Rect2 = _compute_backdrop_rect(backdrop_tex)
		var tex_size: Vector2 = backdrop_tex.get_size()
		var scale_xy: Vector2 = Vector2(draw_rect_target.size.x / maxf(tex_size.x, 1.0), draw_rect_target.size.y / maxf(tex_size.y, 1.0))
		var occ_list_var: Variant = loc.get("occluders", [])
		if occ_list_var is Array:
			for ov in (occ_list_var as Array):
				if not (ov is Dictionary):
					continue
				var od: Dictionary = ov as Dictionary
				var sort_z: int = 0
				if bool(od.get("always_front", false)):
					sort_z = 3600
				elif od.has("sort_y_px"):
					var world_sy: float = draw_rect_target.position.y + float(od.get("sort_y_px", 0.0)) * scale_xy.y
					sort_z = clampi(int(world_sy), -3500, 3500)
				elif od.has("sort_grid_x") and od.has("sort_grid_y"):
					var g_pt: Vector2 = iso_to_screen(float(od.get("sort_grid_x", 0.0)), float(od.get("sort_grid_y", 0.0)))
					sort_z = clampi(int(g_pt.y), -3500, 3500)

				var occ_tex_path: String = str(od.get("texture", ""))
				if occ_tex_path != "":
					var occ_tex: Texture2D = _load_texture_safe(occ_tex_path)
					if occ_tex != null:
						var spr: Sprite2D = Sprite2D.new()
						spr.centered = false
						spr.texture = occ_tex
						spr.position = draw_rect_target.position
						var o_sz: Vector2 = occ_tex.get_size()
						spr.scale = Vector2(draw_rect_target.size.x / maxf(o_sz.x, 1.0), draw_rect_target.size.y / maxf(o_sz.y, 1.0))
						spr.z_index = sort_z
						_pawn_container.add_child(spr)
						_occluder_nodes.append(spr)
				else:
					var poly_px_var: Variant = od.get("polygon_px", [])
					if poly_px_var is Array and (poly_px_var as Array).size() >= 3:
						var uv_pts: PackedVector2Array = PackedVector2Array()
						var world_pts: PackedVector2Array = PackedVector2Array()
						for pt_var in (poly_px_var as Array):
							if pt_var is Array and (pt_var as Array).size() >= 2:
								var pa: Array = pt_var as Array
								var px_v: Vector2 = Vector2(float(pa[0]), float(pa[1]))
								uv_pts.append(px_v)
								world_pts.append(draw_rect_target.position + Vector2(px_v.x * scale_xy.x, px_v.y * scale_xy.y))
						if world_pts.size() >= 3:
							var p2d: Polygon2D = Polygon2D.new()
							p2d.texture = backdrop_tex
							p2d.uv = uv_pts
							p2d.polygon = world_pts
							p2d.z_index = sort_z
							_pawn_container.add_child(p2d)
							_occluder_nodes.append(p2d)
	else:
		var props_var: Variant = loc.get("props", [])
		if props_var is Array:
			for pv in (props_var as Array):
				if pv is Dictionary:
					var pd: Dictionary = pv as Dictionary
					var ptype: String = str(pd.get("type", "box"))
					if ptype != "rails" and ptype != "platform":
						var pn: Node2D = IsoPropNodeScript.new()
						_pawn_container.add_child(pn)
						pn.call("setup_prop", pd, tile_w, tile_h, iso_origin, is_night)
						_prop_nodes.append(pn)

func _draw() -> void:
	var loc: Dictionary = DataLoader.get_location(current_loc_id)
	var is_night: bool = (GameState.phase == "night")
	var low_moral: bool = GameState.get_lowest_moral() <= 40

	var backdrop_path: String = str(loc.get("backdrop", ""))
	var backdrop_tex: Texture2D = _load_texture_safe(backdrop_path) if (render_mode == "backdrop" and backdrop_path != "") else null

	if backdrop_tex != null:
		draw_rect(Rect2(Vector2(-1200.0, -900.0), Vector2(3600.0, 2800.0)), Color(0.078, 0.078, 0.094), true)
		var draw_rect_target: Rect2 = _compute_backdrop_rect(backdrop_tex)
		var tint_col: Color = Color(0.68, 0.72, 0.82) if is_night else Color.WHITE
		draw_texture_rect(backdrop_tex, draw_rect_target, false, tint_col)
		draw_rect(draw_rect_target, Color(0.06, 0.06, 0.07), false, 2.5)
	else:
		var bg_col: Color = Color.html(str(loc.get("night_tint", "#181920"))) if is_night else Color.html(str(loc.get("day_tint", "#cfc6b4")))
		draw_rect(Rect2(Vector2(-1200.0, -900.0), Vector2(3600.0, 2800.0)), bg_col.darkened(0.28 if not is_night else 0.35), true)
		_draw_horizon_silhouette(is_night, low_moral)

		var ink_col: Color = Color(0.06, 0.06, 0.08)
		var zones_var: Variant = loc.get("zones", [])
		for gy in range(grid_h):
			for gx in range(grid_w):
				var p0: Vector2 = iso_to_screen(float(gx), float(gy))
				var p1: Vector2 = iso_to_screen(float(gx + 1), float(gy))
				var p2: Vector2 = iso_to_screen(float(gx + 1), float(gy + 1))
				var p3: Vector2 = iso_to_screen(float(gx), float(gy + 1))
				var tile_col: Color = _zone_tint_at(gx, gy, zones_var, is_night, bg_col)
				if (gx + gy) % 2 == 0:
					tile_col = tile_col.lightened(0.06)
				else:
					tile_col = tile_col.darkened(0.05)

				if current_loc_id == "gare_rer_y" and (gy == 1 or gy == 2):
					tile_col = Color(0.18, 0.19, 0.22) if is_night else Color(0.32, 0.33, 0.36)
				if _blocked_cells.has("%d,%d" % [gx, gy]):
					tile_col = tile_col.darkened(0.18)
				draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), tile_col)
				draw_polyline(PackedVector2Array([p0, p1, p2, p3, p0]), Color(ink_col.r, ink_col.g, ink_col.b, 0.35), 1.2)

		var props_var: Variant = loc.get("props", [])
		if props_var is Array:
			for pv in (props_var as Array):
				if pv is Dictionary:
					var pd: Dictionary = pv as Dictionary
					var ptype: String = str(pd.get("type", "box"))
					if ptype == "rails" or ptype == "platform":
						_draw_prop(pd, is_night)

		if zones_var is Array:
			for zv in (zones_var as Array):
				if zv is Dictionary:
					var zd: Dictionary = zv as Dictionary
					var zname: String = str(zd.get("name", ""))
					if zname != "":
						var zpos: Vector2 = iso_to_screen(float(zd.get("x", 0)) + 0.3, float(zd.get("y", 1)) + float(zd.get("h", 4)) - 0.5)
						draw_string(ThemeDB.fallback_font, zpos, zname.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 180, 10, Color(0.95, 0.94, 0.88, 0.45) if is_night else Color(0.18, 0.16, 0.14, 0.50))

	if current_loc_id == "gare_rer_y" and (train_fantome_active or (is_night and GameState.has_flag("encounter_gare_done"))):
		_draw_ghost_train()

	if _combat_stage_mode:
		_draw_combat_iso_grid()

	_sync_pawn_actors()
	if _markers_overlay != null:
		_markers_overlay.queue_redraw()

func _draw_markers_overlay() -> void:
	if _markers_overlay == null:
		return
	var loc: Dictionary = DataLoader.get_location(current_loc_id)
	var is_night: bool = (GameState.phase == "night")
	var low_moral: bool = GameState.get_lowest_moral() <= 40

	var exits_var: Variant = loc.get("exits", [])
	if exits_var is Array:
		for exv in (exits_var as Array):
			if exv is Dictionary:
				_draw_exit_marker_on(_markers_overlay, exv as Dictionary, is_night)

	var hs_var: Variant = loc.get("hotspots", [])
	if hs_var is Array:
		for hsv in (hs_var as Array):
			if hsv is Dictionary:
				_draw_hotspot_on(_markers_overlay, hsv as Dictionary, is_night)

	if current_loc_id == "gare_rer_y" and (is_night or low_moral):
		var sign_pos: Vector2 = iso_to_screen(3.5, 3.0) + Vector2(-72.0, -70.0)
		var odd_txt: String = "CRADON-CENTRE [HORS-PLAN]" if int(_pulse_time * 0.7) % 3 == 0 else "RER B — BIFURCATION Y"
		_markers_overlay.draw_rect(Rect2(sign_pos, Vector2(168.0, 22.0)), Color(0.08, 0.12, 0.28, 0.92), true)
		_markers_overlay.draw_rect(Rect2(sign_pos, Vector2(168.0, 22.0)), Color(0.32, 0.68, 0.95), false, 1.5)
		_markers_overlay.draw_string(ThemeDB.fallback_font, sign_pos + Vector2(6.0, 15.0), odd_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.88, 0.95, 1.0))

func _zone_tint_at(gx: int, gy: int, zones_var: Variant, is_night: bool, fallback_col: Color) -> Color:
	if zones_var is Array:
		for zv in (zones_var as Array):
			if not (zv is Dictionary):
				continue
			var zd: Dictionary = zv as Dictionary
			var zx: int = int(zd.get("x", 0))
			var zy: int = int(zd.get("y", 0))
			var zw: int = int(zd.get("w", 0))
			var zh: int = int(zd.get("h", 0))
			if gx >= zx and gx < zx + zw and gy >= zy and gy < zy + zh:
				var hex_str: String = str(zd.get("night_tint", "")) if is_night else str(zd.get("day_tint", ""))
				if hex_str != "":
					return Color.html(hex_str)
	return fallback_col

func _draw_exit_marker_on(canvas: Node2D, ex: Dictionary, is_night: bool) -> void:
	var cx: float = float(ex.get("grid_x", float(grid_w) - 1.5))
	var cy: float = float(ex.get("grid_y", float(grid_h) - 1.5))
	var center: Vector2 = iso_to_screen(cx, cy)
	var col: Color = Color.html(str(ex.get("color_hex", "#4aa3df")))
	var pulse: float = 13.0 + sin(_pulse_time * 3.0) * 2.5
	var pts: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -pulse * 0.55),
		center + Vector2(pulse, 0.0),
		center + Vector2(0.0, pulse * 0.55),
		center + Vector2(-pulse, 0.0)
	])
	canvas.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.24))
	canvas.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), col, 2.0)

	var lbl: String = "← " + str(ex.get("label", "Sortir"))
	var bp: Vector2 = center + Vector2(-58.0, 12.0)
	var bg_b: Color = Color(0.08, 0.09, 0.12, 0.88) if is_night else Color(0.10, 0.09, 0.08, 0.84)
	canvas.draw_rect(Rect2(bp, Vector2(126.0, 18.0)), bg_b, true)
	canvas.draw_rect(Rect2(bp, Vector2(126.0, 18.0)), col, false, 1.4)
	canvas.draw_string(ThemeDB.fallback_font, bp + Vector2(5.0, 13.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, 118, 10, Color(0.95, 0.96, 0.98))

func _draw_horizon_silhouette(is_night: bool, low_moral: bool) -> void:
	var sil_col: Color = Color(0.08, 0.08, 0.11, 0.65) if is_night else Color(0.45, 0.44, 0.42, 0.35)
	var towers: Array[Rect2] = [
		Rect2(-20, 40, 62, 140),
		Rect2(60, 74, 46, 110),
		Rect2(810, 60, 62, 134),
		Rect2(890, 92, 48, 108)
	]
	for r in towers:
		draw_rect(r, sil_col, true)
	if is_night or low_moral:
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
	draw_colored_polygon(PackedVector2Array([t1, t2, b2, b1]), top_col.darkened(0.26))
	draw_polyline(PackedVector2Array([t1, t2, b2, b1, t1]), ink, 1.5)
	draw_colored_polygon(PackedVector2Array([t3, t2, b2, b3]), top_col.darkened(0.14))
	draw_polyline(PackedVector2Array([t3, t2, b2, b3, t3]), ink, 1.5)
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

func _draw_hotspot_on(canvas: Node2D, hs: Dictionary, is_night: bool) -> void:
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
	canvas.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.28))
	canvas.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), col, 2.2)

	var lbl: String = str(hs.get("label", "Inspecter"))
	var badge_pos: Vector2 = center + Vector2(-56.0, -34.0)
	var bg_badge: Color = Color(0.08, 0.08, 0.10, 0.86) if is_night else Color(0.10, 0.09, 0.08, 0.82)
	canvas.draw_rect(Rect2(badge_pos, Vector2(142.0, 20.0)), bg_badge, true)
	canvas.draw_rect(Rect2(badge_pos, Vector2(142.0, 20.0)), col, false, 1.5)
	canvas.draw_string(ThemeDB.fallback_font, badge_pos + Vector2(5.0, 14.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, 134, 11, Color(0.97, 0.95, 0.90))

func _get_visible_npcs(loc: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw_npcs: Variant = loc.get("npcs", [])
	if not (raw_npcs is Array):
		return out
	for nv in (raw_npcs as Array):
		if not (nv is Dictionary):
			continue
		var nd: Dictionary = nv as Dictionary
		var req_phase: String = str(nd.get("phase", "any"))
		if req_phase != "any" and req_phase != GameState.phase and not (req_phase == "day" and GameState.phase == "twilight"):
			continue
		var cid: String = str(nd.get("char_id", ""))
		if bool(nd.get("hide_if_in_squad", false)) and GameState.squad_members.has(cid):
			continue
		var hide_flag: String = str(nd.get("hide_if_flag", ""))
		if hide_flag != "" and GameState.has_flag(hide_flag):
			continue
		var req_flag: String = str(nd.get("require_flag", ""))
		if req_flag != "" and not GameState.has_flag(req_flag):
			continue
		var cdef: Dictionary = DataLoader.get_character(cid)
		var pawn_path: String = str(cdef.get("pawn", ""))
		if pawn_path == "" or _load_texture_safe(pawn_path) == null:
			continue
		out.append(nd)
	return out

func _sync_pawn_actors() -> void:
	if _pawn_container == null:
		return
	if _combat_stage_mode and _combat_timeline != null and bool(_combat_timeline.get("active")):
		_sync_combat_pawns()
		return
	var loc: Dictionary = DataLoader.get_location(current_loc_id)
	var is_night: bool = (GameState.phase == "night")
	var low_moral: bool = GameState.get_lowest_moral() <= 40
	var backdrop_path: String = str(loc.get("backdrop", ""))
	var has_backdrop: bool = (render_mode == "backdrop" and backdrop_path != "" and _load_texture_safe(backdrop_path) != null)
	var target_h: float = 162.0 if has_backdrop else 112.0

	var screen_lights: Array[Dictionary] = []
	var raw_lights: Variant = loc.get("lights", [])
	if raw_lights is Array:
		for lv in (raw_lights as Array):
			if lv is Dictionary:
				var ld: Dictionary = lv as Dictionary
				var lpos: Vector2 = iso_to_screen(float(ld.get("grid_x", 0.0)), float(ld.get("grid_y", 0.0)))
				screen_lights.append({
					"screen_pos": lpos,
					"radius": float(ld.get("radius", 320.0)),
					"strength": float(ld.get("strength", 1.0))
				})

	var offsets: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(-54.0, 16.0), Vector2(54.0, 16.0), Vector2(0.0, 32.0), Vector2(-78.0, 34.0), Vector2(78.0, 34.0)]
	var is_moving: bool = pawn_grid_pos.distance_to(pawn_target_pos) > 0.05
	var groups_here: Array[int] = GameState.get_groups_in_location(current_loc_id)
	var is_split: bool = GameState.get_present_group_ids().size() > 1

	var visible_cids: Array[String] = []
	for gid in groups_here:
		for cid in GameState.get_group_members(gid):
			visible_cids.append(cid)

	for existing_id_var in _pawn_actors.keys():
		var existing_id: String = str(existing_id_var)
		var node_var: Variant = _pawn_actors.get(existing_id, null)
		if node_var is Node2D:
			(node_var as Node2D).visible = visible_cids.has(existing_id)

	for gid in groups_here:
		var is_active_grp: bool = (gid == GameState.active_group_id)
		var grp_members: Array[String] = GameState.get_group_members(gid)
		var base_grid: Vector2 = pawn_grid_pos if is_active_grp else GameState.get_group_grid_pos(gid)
		var base_screen: Vector2 = iso_to_screen(base_grid.x, base_grid.y)

		for i in range(grp_members.size()):
			var cid: String = grp_members[i]
			var cdef: Dictionary = DataLoader.get_character(cid)
			var st: Dictionary = GameState.get_member_state(cid)
			var col: Color = Color.html(str(cdef.get("color_hex", "#f28c28")))
			var pos: Vector2 = base_screen + offsets[i % offsets.size()]

			var actor: Node2D = null
			if _pawn_actors.has(cid):
				var a_var: Variant = _pawn_actors.get(cid, null)
				if a_var is Node2D:
					actor = a_var as Node2D
			if actor == null:
				actor = PawnActorScript.new()
				_pawn_container.add_child(actor)
				_pawn_actors[cid] = actor

			var pawn_path: String = str(cdef.get("pawn", ""))
			var pawn_tex: Texture2D = _load_texture_safe(pawn_path) if pawn_path != "" else null
			var base_name: String = str(cdef.get("name", cid)).split(" ")[0]
			var label_txt: String = base_name
			if is_split:
				label_txt = ("► " + base_name) if is_active_grp else ("G%d · %s" % [gid + 1, base_name])

			actor.visible = true
			actor.position = pos
			actor.z_index = clampi(int(pos.y), -3500, 3500)
			actor.modulate = Color.WHITE if (not is_split or is_active_grp) else Color(0.84, 0.87, 0.92, 1.0)
			actor.call("setup_character", pawn_tex, label_txt, col, target_h)

			var action_state: String = "idle"
			if bool(st.get("stress_active", false)):
				action_state = "stress"
			elif is_active_grp:
				if not pending_hotspot.is_empty() or not pending_exit.is_empty() or input_blocked:
					action_state = "interacting"
				elif is_moving:
					action_state = "moving"
				elif str(st.get("order_label", "")) == "Guetter":
					action_state = "guarding"
			elif str(st.get("order_label", "")) == "Guetter":
				action_state = "guarding"

			actor.call("update_state", action_state, is_night, low_moral, screen_lights)

	for npc_key_var in _npc_actors.keys():
		var npc_key: String = str(npc_key_var)
		var nnode_var: Variant = _npc_actors.get(npc_key, null)
		if nnode_var is Node2D:
			(nnode_var as Node2D).visible = false

	var visible_npcs: Array[Dictionary] = _get_visible_npcs(loc)
	for npc in visible_npcs:
		var nid: String = str(npc.get("id", ""))
		var cid: String = str(npc.get("char_id", ""))
		if nid == "" or cid == "":
			continue
		var cdef: Dictionary = DataLoader.get_character(cid)
		var pawn_path: String = str(cdef.get("pawn", ""))
		var pawn_tex: Texture2D = _load_texture_safe(pawn_path)
		if pawn_tex == null:
			continue
		var npc_actor: Node2D = null
		if _npc_actors.has(nid):
			var na_var: Variant = _npc_actors.get(nid, null)
			if na_var is Node2D:
				npc_actor = na_var as Node2D
		if npc_actor == null:
			npc_actor = PawnActorScript.new()
			_pawn_container.add_child(npc_actor)
			_npc_actors[nid] = npc_actor

		var col: Color = Color.html(str(cdef.get("color_hex", "#d9c252")))
		var short_name: String = str(npc.get("label", str(cdef.get("name", cid)).split(" ")[0]))
		var npos: Vector2 = iso_to_screen(float(npc.get("grid_x", 3.0)), float(npc.get("grid_y", 4.0)))
		npc_actor.visible = true
		npc_actor.position = npos
		npc_actor.z_index = clampi(int(npos.y), -3500, 3500)
		npc_actor.call("setup_character", pawn_tex, short_name, col, target_h)
		var npc_state: String = str(npc.get("action_state", "interacting"))
		npc_actor.call("update_state", npc_state, is_night, low_moral, screen_lights)

	var occ_tint: Color = Color(0.68, 0.72, 0.82) if is_night else Color.WHITE
	for on in _occluder_nodes:
		if is_instance_valid(on):
			on.modulate = occ_tint
	for pn in _prop_nodes:
		if is_instance_valid(pn):
			pn.call("set_night", is_night)

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

## Gère survol et clic sur les pions déployés en mode combat isométrique.
func _handle_combat_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if mm.position.y < 126.0 or mm.position.y > 478.0:
			if _combat_hovered_kind != "" or _combat_hovered_id != "":
				_combat_hovered_kind = ""
				_combat_hovered_id = ""
				refresh_combat_stage()
				combat_actor_hovered.emit("", "")
			return
		var world_pos: Vector2 = get_canvas_transform().affine_inverse() * mm.position
		var hit: Dictionary = _pick_combat_actor_at(world_pos)
		var hk: String = str(hit.get("kind", ""))
		var hid: String = str(hit.get("id", ""))
		if hk != _combat_hovered_kind or hid != _combat_hovered_id:
			_combat_hovered_kind = hk
			_combat_hovered_id = hid
			refresh_combat_stage()
			combat_actor_hovered.emit(hk, hid)
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			combat_cancel_requested.emit()
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if mb.position.y < 126.0 or mb.position.y > 478.0:
				return
			var click_world: Vector2 = get_canvas_transform().affine_inverse() * mb.position
			var hit_c: Dictionary = _pick_combat_actor_at(click_world)
			if not hit_c.is_empty():
				combat_actor_clicked.emit(str(hit_c.get("kind", "")), str(hit_c.get("id", "")))
				AudioRadio.play_cassette_click()
				get_viewport().set_input_as_handled()

func _pick_combat_actor_at(world_pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_y: float = -99999.0
	for he in _combat_hit_entries:
		var sp: Vector2 = he.get("screen", Vector2.ZERO) as Vector2
		var hh: float = float(he.get("hit_h", 132.0))
		var rect: Rect2 = Rect2(sp.x - 38.0, sp.y - hh, 76.0, hh + 14.0)
		if rect.has_point(world_pos) and sp.y > best_y:
			best_y = sp.y
			best = he
	return best

func _is_combat_targetable(kind: String, eid: String) -> bool:
	if _combat_target_kind == "":
		return false
	if _combat_target_kind == "enemy" and kind == "enemy":
		return _combat_valid_targets.has(eid)
	if (_combat_target_kind == "ally" or _combat_target_kind == "ally_crisis") and kind == "ally":
		return _combat_valid_targets.has(eid)
	return false

## Dessine le quadrillage isométrique 2:1, les axes de déploiement (PJ bas→gauche, PNJ haut→droite) et les dalles ciblées.
func _draw_combat_iso_grid() -> void:
	for gy in range(grid_h):
		for gx in range(grid_w):
			var p0: Vector2 = iso_to_screen(float(gx), float(gy))
			var p1: Vector2 = iso_to_screen(float(gx + 1), float(gy))
			var p2: Vector2 = iso_to_screen(float(gx + 1), float(gy + 1))
			var p3: Vector2 = iso_to_screen(float(gx), float(gy + 1))
			var fill_col: Color = Color(0.06, 0.08, 0.12, 0.16)
			var line_col: Color = Color(0.84, 0.88, 0.96, 0.24)
			var lw: float = 1.1
			if gy == 6 and gx >= 1 and gx <= 5:
				fill_col = Color(0.95, 0.55, 0.16, 0.14)
				line_col = Color(0.96, 0.64, 0.28, 0.42)
			elif gy == 2 and gx >= 1 and gx <= 5:
				fill_col = Color(0.86, 0.20, 0.22, 0.14)
				line_col = Color(0.94, 0.34, 0.34, 0.42)
			draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), fill_col)
			draw_polyline(PackedVector2Array([p0, p1, p2, p3, p0]), line_col, lw)

	var eff_h_kind: String = _combat_hovered_kind if _combat_hovered_id != "" else _combat_ext_hovered_kind
	var eff_h_id: String = _combat_hovered_id if _combat_hovered_id != "" else _combat_ext_hovered_id
	var active_ent: Dictionary = {}
	if _combat_timeline != null:
		var ae_var: Variant = _combat_timeline.call("get_active_turn_entity")
		if ae_var is Dictionary:
			active_ent = ae_var as Dictionary
	var act_k: String = str(active_ent.get("kind", ""))
	var act_id: String = str(active_ent.get("id", ""))

	for he in _combat_hit_entries:
		var k: String = str(he.get("kind", ""))
		var eid: String = str(he.get("id", ""))
		var gpos: Vector2 = he.get("grid", Vector2.ZERO) as Vector2
		var cx: int = clampi(int(floor(gpos.x)), 0, grid_w - 1)
		var cy: int = clampi(int(floor(gpos.y)), 0, grid_h - 1)
		var is_a: bool = (k == act_k and eid == act_id)
		var is_h: bool = (k == eff_h_kind and eid == eff_h_id)
		var is_t: bool = _is_combat_targetable(k, eid)
		if is_a or is_h or is_t:
			var t0: Vector2 = iso_to_screen(float(cx), float(cy))
			var t1: Vector2 = iso_to_screen(float(cx + 1), float(cy))
			var t2: Vector2 = iso_to_screen(float(cx + 1), float(cy + 1))
			var t3: Vector2 = iso_to_screen(float(cx), float(cy + 1))
			var dcol: Color = Color(1.0, 0.84, 0.24)
			if is_h:
				dcol = Color(1.0, 0.94, 0.56)
			elif is_t and not is_a:
				dcol = Color(0.98, 0.28, 0.28) if k == "enemy" else Color(0.32, 0.88, 0.96)
			draw_colored_polygon(PackedVector2Array([t0, t1, t2, t3]), Color(dcol.r, dcol.g, dcol.b, 0.22))
			draw_polyline(PackedVector2Array([t0, t1, t2, t3, t0]), dcol, 2.2)

## Aligne les héros présents (axe bas vers gauche) et les PNJ (axe haut vers droite) sur le quadrillage isométrique.
func _sync_combat_pawns() -> void:
	_combat_hit_entries.clear()
	var loc: Dictionary = DataLoader.get_location(current_loc_id)
	var is_night: bool = (GameState.phase == "night")
	var low_moral: bool = GameState.get_lowest_moral() <= 40

	var screen_lights: Array[Dictionary] = []
	var raw_lights: Variant = loc.get("lights", [])
	if raw_lights is Array:
		for lv in (raw_lights as Array):
			if lv is Dictionary:
				var ld: Dictionary = lv as Dictionary
				var lpos: Vector2 = iso_to_screen(float(ld.get("grid_x", 0.0)), float(ld.get("grid_y", 0.0)))
				screen_lights.append({
					"screen_pos": lpos,
					"radius": float(ld.get("radius", 320.0)),
					"strength": float(ld.get("strength", 1.0))
				})

	for nkey_var in _npc_actors.keys():
		var nvar: Variant = _npc_actors.get(nkey_var, null)
		if nvar is Node2D:
			(nvar as Node2D).visible = false
	for pkey_var in _pawn_actors.keys():
		var pvar: Variant = _pawn_actors.get(pkey_var, null)
		if pvar is Node2D:
			(pvar as Node2D).visible = false
	for ekey_var in _combat_enemy_actors.keys():
		var evar: Variant = _combat_enemy_actors.get(ekey_var, null)
		if evar is Node2D:
			(evar as Node2D).visible = false

	var active_ent: Dictionary = {}
	var ae_var: Variant = _combat_timeline.call("get_active_turn_entity")
	if ae_var is Dictionary:
		active_ent = ae_var as Dictionary
	var act_kind: String = str(active_ent.get("kind", ""))
	var act_id: String = str(active_ent.get("id", ""))
	var eff_h_kind: String = _combat_hovered_kind if _combat_hovered_id != "" else _combat_ext_hovered_kind
	var eff_h_id: String = _combat_hovered_id if _combat_hovered_id != "" else _combat_ext_hovered_id
	var target_h: float = 126.0

	# 1. Héros du groupe présents : axe bas vers gauche (gy = 6.2, gx décroissant de 4.8..5.5 vers 1.2..2.2)
	var present_allies: Array[Dictionary] = []
	var allies_var: Variant = _combat_timeline.get("allies")
	if allies_var is Array:
		for av in (allies_var as Array):
			if av is Dictionary and bool((av as Dictionary).get("present", false)):
				present_allies.append(av as Dictionary)

	var na: int = present_allies.size()
	for i in range(na):
		var al: Dictionary = present_allies[i]
		var cid: String = str(al.get("char_id", ""))
		var cdef: Dictionary = DataLoader.get_character(cid)
		var st: Dictionary = GameState.get_member_state(cid)
		var col: Color = Color.html(str(cdef.get("color_hex", "#f28c28")))
		var gx: float = 3.4
		if na >= 2:
			var hi_x: float = 4.8 if na <= 3 else 5.5
			var lo_x: float = 2.0 if na <= 3 else 1.2
			gx = lerpf(hi_x, lo_x, float(i) / float(na - 1))
		var gy: float = 6.2
		var pos: Vector2 = iso_to_screen(gx, gy)

		var actor: Node2D = null
		if _pawn_actors.has(cid):
			var a_var: Variant = _pawn_actors.get(cid, null)
			if a_var is Node2D:
				actor = a_var as Node2D
		if actor == null:
			actor = PawnActorScript.new()
			_pawn_container.add_child(actor)
			_pawn_actors[cid] = actor

		var pawn_path: String = str(cdef.get("pawn", ""))
		var pawn_tex: Texture2D = _load_texture_safe(pawn_path) if pawn_path != "" else null
		var base_name: String = str(cdef.get("name", cid)).split(" ")[0]
		actor.visible = true
		actor.position = pos
		actor.z_index = clampi(int(pos.y), -3500, 3500)
		if pawn_tex != null:
			actor.call("setup_character", pawn_tex, base_name, col, target_h)
		else:
			var ptex_fb: Texture2D = _load_texture_safe(str(cdef.get("portrait", "")))
			actor.call("setup_standee_character", ptex_fb, base_name, col, target_h)

		var is_a: bool = (act_kind == "ally" and act_id == cid)
		var is_t: bool = _is_combat_targetable("ally", cid)
		var is_h: bool = (eff_h_kind == "ally" and eff_h_id == cid)
		var is_dim: bool = (_combat_target_kind != "" and not is_t and not is_a)
		var state_str: String = "stress" if bool(st.get("stress_active", false)) else ("interacting" if is_a else "idle")
		actor.call("update_state", state_str, is_night, low_moral, screen_lights)
		actor.call("set_combat_highlight", is_a, is_t, is_h, is_dim, "ally", _pulse_time)
		_combat_hit_entries.append({
			"kind": "ally",
			"id": cid,
			"grid": Vector2(gx, gy),
			"screen": pos,
			"hit_h": target_h + 10.0,
			"actor": actor
		})

	# 2. PNJ ennemis actifs : axe haut vers droite (gy = 2.0, gx croissant de 2.4 vers 5.6)
	var alive_enemies: Array[Dictionary] = []
	var enemies_var: Variant = _combat_timeline.get("enemies")
	if enemies_var is Array:
		for ev in (enemies_var as Array):
			if ev is Dictionary and not bool((ev as Dictionary).get("defeated", false)):
				alive_enemies.append(ev as Dictionary)

	var ne: int = alive_enemies.size()
	for j in range(ne):
		var en: Dictionary = alive_enemies[j]
		var eid: String = str(en.get("id", ""))
		var gxe: float = 4.0
		if ne >= 2:
			var lo_xe: float = 2.4 if ne <= 3 else 1.8
			var hi_xe: float = 5.6 if ne <= 3 else 6.2
			gxe = lerpf(lo_xe, hi_xe, float(j) / float(ne - 1))
		var gye: float = 2.0
		var epos: Vector2 = iso_to_screen(gxe, gye)

		var e_actor: Node2D = null
		if _combat_enemy_actors.has(eid):
			var ea_var: Variant = _combat_enemy_actors.get(eid, null)
			if ea_var is Node2D:
				e_actor = ea_var as Node2D
		if e_actor == null:
			e_actor = PawnActorScript.new()
			_pawn_container.add_child(e_actor)
			_combat_enemy_actors[eid] = e_actor

		var e_name: String = str(en.get("name", eid))
		var e_port: Texture2D = _load_texture_safe(str(en.get("portrait", "res://assets/portraits/so_agent.png")))
		var e_col: Color = Color(0.88, 0.24, 0.24)
		e_actor.visible = true
		e_actor.position = epos
		e_actor.z_index = clampi(int(epos.y), -3500, 3500)
		e_actor.call("setup_standee_character", e_port, e_name, e_col, target_h)

		var e_is_a: bool = (act_kind == "enemy" and act_id == eid)
		var e_is_t: bool = _is_combat_targetable("enemy", eid)
		var e_is_h: bool = (eff_h_kind == "enemy" and eff_h_id == eid)
		var e_is_dim: bool = (_combat_target_kind != "" and not e_is_t and not e_is_a)
		e_actor.call("update_state", "idle", is_night, low_moral, screen_lights)
		e_actor.call("set_combat_highlight", e_is_a, e_is_t, e_is_h, e_is_dim, "enemy", _pulse_time)
		_combat_hit_entries.append({
			"kind": "enemy",
			"id": eid,
			"grid": Vector2(gxe, gye),
			"screen": epos,
			"hit_h": target_h + 10.0,
			"actor": e_actor
		})
