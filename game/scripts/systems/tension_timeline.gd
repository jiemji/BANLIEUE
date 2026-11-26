## Moteur tactique déclaratif de la Frise Chronologique de Tension (Option 2A : briques d'effets JSON + hook custom_script optionnel).
extends Node

signal timeline_updated
signal encounter_finished(outcome_id: String, summary: String)
signal train_fantome_arrived_sig
signal stage_fx_triggered(fx_id: String)
signal combat_feedback_emitted(event_data: Dictionary)
signal charge_window_started(charge_data: Dictionary)
signal charge_window_ticked(time_left: float, time_max: float)
signal charge_window_ended(outcome: String, summary: String)

const COMBAT_GRID_W: int = 8
const COMBAT_GRID_H: int = 8
const CHARGE_WINDOW_SECONDS: float = 10.0
const CHARGE_STUN_RANK_PENALTY: int = 2

var active: bool = false
var encounter_id: String = ""
var encounter_title: String = ""
var intro_text: String = ""
var turn_count: int = 0
var crs_ticks: int = 4
var train_fantome_arrived: bool = false
var escape_progress: int = 0
var interposition_shield: int = 0

var selected_target_id: String = ""
var awaiting_step: bool = false
var pending_beat_label: String = ""
var last_event: Dictionary = {}
var pending_enemy_charge: Dictionary = {}
var charge_timer_paused: bool = false

var enemies: Array[Dictionary] = []
var allies: Array[Dictionary] = []
var crisis_queue: Array[Dictionary] = []
var combat_log: Array[String] = []

var _squad_manager: Node = null
var _pending_enemy_ids: Array[String] = []
var _pending_crisis_ids: Array[String] = []
var _used_equip_actions: Dictionary = {}
var _interposition_absorb: int = 6
var _explicit_ally_target_id: String = ""
var _explicit_crisis_target_id: String = ""
var _combat_blocked_cells: Dictionary = {}
var _combat_location_id: String = ""
var cover_tiles: Array[Dictionary] = []
var combat_interactables: Array[Dictionary] = []

var _escalation_cfg: Dictionary = {}
var _escape_cfg: Dictionary = {}
var _timed_events: Array[Dictionary] = []
var _fired_timed_events: Dictionary = {}
var _escape_unlocked_by_event: bool = false

func set_squad_manager(sm: Node) -> void:
	_squad_manager = sm

func _process(delta: float) -> void:
	if not active or pending_enemy_charge.is_empty() or charge_timer_paused:
		return
	var tl: float = float(pending_enemy_charge.get("time_left", 0.0)) - delta
	var tm: float = float(pending_enemy_charge.get("time_max", CHARGE_WINDOW_SECONDS))
	if tl <= 0.0:
		pending_enemy_charge["time_left"] = 0.0
		charge_window_ticked.emit(0.0, tm)
		resolve_pending_enemy_charge()
	else:
		pending_enemy_charge["time_left"] = tl
		charge_window_ticked.emit(tl, tm)

## Indique si l'horloge d'escalade (ex. CRS, Fourgon) est activée sur la rencontre active.
func is_escalation_enabled() -> bool:
	return bool(_escalation_cfg.get("enabled", true))

## Retourne le libellé court de l'horloge d'escalade pour l'affichage HUD.
func get_escalation_short_label() -> String:
	var sl: String = str(_escalation_cfg.get("short_label", "CRS"))
	return sl if sl != "" else "CRS"

## Indique si la mécanique d'Échappée est activée sur la rencontre active.
func is_escape_enabled() -> bool:
	return bool(_escape_cfg.get("enabled", true))

## Retourne le seuil de progression requis pour ouvrir l'Échappée.
func get_escape_required_progress() -> int:
	return maxi(1, int(_escape_cfg.get("required_progress", 2)))

## Retourne le texte d'état de l'Échappée pour le bandeau supérieur de la Frise.
func get_escape_status_label() -> String:
	if train_fantome_arrived or _escape_unlocked_by_event:
		var rlbl: String = str(_escape_cfg.get("status_ready_label", "VOIE DÉGAGÉE !"))
		return rlbl if rlbl != "" else "VOIE DÉGAGÉE !"
	return "Échappée : %d/%d" % [escape_progress, get_escape_required_progress()]

## Initialise une confrontation sur la frise à partir des données JSON du pack scénario actif.
func start_encounter(enc_id: String) -> void:
	var enc: Dictionary = DataLoader.get_encounter(enc_id)
	if enc.is_empty():
		return
	active = true
	encounter_id = enc_id
	encounter_title = str(enc.get("title", "Confrontation"))
	intro_text = str(enc.get("intro_text", ""))
	turn_count = 1

	var esc_v: Variant = enc.get("escalation_clock", {})
	_escalation_cfg = (esc_v as Dictionary).duplicate(true) if esc_v is Dictionary else {}
	if not _escalation_cfg.has("enabled"):
		_escalation_cfg["enabled"] = true
	crs_ticks = int(_escalation_cfg.get("start_ticks", int(enc.get("crs_start_ticks", 4))))

	var ecfg_v: Variant = enc.get("escape_config", {})
	_escape_cfg = (ecfg_v as Dictionary).duplicate(true) if ecfg_v is Dictionary else {}
	if not _escape_cfg.has("enabled"):
		_escape_cfg["enabled"] = true

	_timed_events.clear()
	_fired_timed_events.clear()
	_escape_unlocked_by_event = false
	train_fantome_arrived = false
	var te_var: Variant = enc.get("timed_events", [])
	if te_var is Array:
		for tev in (te_var as Array):
			if tev is Dictionary:
				_timed_events.append((tev as Dictionary).duplicate(true))

	escape_progress = 0
	interposition_shield = 0
	selected_target_id = ""
	awaiting_step = false
	pending_beat_label = ""
	last_event = {}
	pending_enemy_charge.clear()
	charge_timer_paused = false
	enemies.clear()
	allies.clear()
	crisis_queue.clear()
	combat_log.clear()
	_pending_enemy_ids.clear()
	_pending_crisis_ids.clear()
	_used_equip_actions.clear()
	_interposition_absorb = 6
	_explicit_ally_target_id = ""
	_explicit_crisis_target_id = ""
	_combat_blocked_cells.clear()
	cover_tiles.clear()
	combat_interactables.clear()

	var default_loc: String = DataLoader.get_start_location_id()
	var enc_loc: String = str(enc.get("location_id", GameState.get_active_location_id()))
	if enc_loc == "":
		enc_loc = default_loc
	_combat_location_id = enc_loc
	var loc_def: Dictionary = DataLoader.get_location(enc_loc)
	var raw_blocked: Variant = loc_def.get("blocked_cells", [])
	if raw_blocked is Array:
		for cv in (raw_blocked as Array):
			if cv is Array and (cv as Array).size() >= 2:
				var ca: Array = cv as Array
				_combat_blocked_cells["%d,%d" % [int(ca[0]), int(ca[1])]] = true

	var raw_covers: Variant = enc.get("cover_tiles", [])
	if raw_covers is Array:
		for cov_v in (raw_covers as Array):
			if cov_v is Dictionary:
				var cov_d: Dictionary = (cov_v as Dictionary).duplicate(true)
				var cx_c: int = clampi(int(cov_d.get("x", 0)), 0, COMBAT_GRID_W - 1)
				var cy_c: int = clampi(int(cov_d.get("y", 1)), 1, COMBAT_GRID_H - 1)
				cov_d["x"] = cx_c
				cov_d["y"] = cy_c
				cover_tiles.append(cov_d)
				if bool(cov_d.get("blocks_movement", false)):
					_combat_blocked_cells["%d,%d" % [cx_c, cy_c]] = true

	var raw_inter: Variant = enc.get("combat_interactables", [])
	if raw_inter is Array:
		for iv in (raw_inter as Array):
			if iv is Dictionary:
				var idict: Dictionary = (iv as Dictionary).duplicate(true)
				idict["x"] = clampi(int(idict.get("x", 0)), 0, COMBAT_GRID_W - 1)
				idict["y"] = clampi(int(idict.get("y", 1)), 1, COMBAT_GRID_H - 1)
				idict["used"] = false
				combat_interactables.append(idict)

	# Ennemis depuis JSON avec positions initiales sur la grille 8x8
	var e_list_var: Variant = enc.get("enemies", [])
	if e_list_var is Array:
		for item in (e_list_var as Array):
			if item is Dictionary:
				var ed: Dictionary = (item as Dictionary).duplicate(true)
				var res_max: int = maxi(1, int(ed.get("resolve_max", 3)))
				ed["resolve"] = res_max
				ed["resolve_max"] = res_max
				ed["next_tick"] = int(ed.get("initial_tick", 2))
				ed["counter_ready"] = bool(ed.get("has_counter_interrupt", false))
				ed["defeated"] = false
				ed["stunned"] = false
				ed["move_points"] = int(ed.get("move_points", 2))
				ed["can_charge"] = bool(ed.get("can_charge", true))
				ed["intercept_bonus"] = int(ed.get("intercept_bonus", 1))
				var sg_var: Variant = ed.get("start_grid", [])
				var gx_e: int = clampi(2 + enemies.size() * 2, 0, COMBAT_GRID_W - 1)
				var gy_e: int = 2
				if sg_var is Array and (sg_var as Array).size() >= 2:
					var sg_arr: Array = sg_var as Array
					gx_e = clampi(int(sg_arr[0]), 0, COMBAT_GRID_W - 1)
					gy_e = clampi(int(sg_arr[1]), 1, COMBAT_GRID_H - 1)
				ed["grid_x"] = gx_e
				ed["grid_y"] = gy_e
				enemies.append(ed)

	# Alliés présents sur place + renforts proches
	var reinforce_map: Dictionary = {}
	if _squad_manager != null and _squad_manager.has_method("compute_reinforcements"):
		var reinf_var: Variant = _squad_manager.call("compute_reinforcements", enc_loc)
		if reinf_var is Array:
			for r_item in (reinf_var as Array):
				if r_item is Dictionary:
					var rd: Dictionary = r_item as Dictionary
					reinforce_map[str(rd.get("char_id", ""))] = int(rd.get("ticks", 2))

	var ally_spawn_cols: Array[int] = [5, 3, 1, 6, 2, 4, 0, 7]
	var idx: int = 0
	for cid in GameState.squad_members:
		var cdef: Dictionary = DataLoader.get_character(cid)
		var st: Dictionary = GameState.get_member_state(cid)
		var loc_id: String = str(st.get("location_id", default_loc))
		var is_here: bool = (int(st.get("group_id", 0)) == GameState.active_group_id) or (loc_id == enc_loc)
		var r_ticks: int = 0 if is_here else int(reinforce_map.get(cid, 2))
		var mp_max: int = compute_ally_move_points(cid)
		var spawn_pos: Vector2i = Vector2i(-1, -1)
		if is_here:
			var pref_x: int = ally_spawn_cols[idx % ally_spawn_cols.size()]
			if is_combat_cell_walkable(pref_x, 6):
				spawn_pos = Vector2i(pref_x, 6)
			else:
				spawn_pos = _find_first_free_ally_spawn_cell()
		allies.append({
			"char_id": cid,
			"name": str(cdef.get("name", cid)),
			"color_hex": str(cdef.get("color_hex", "#f28c28")),
			"specialty_id": str(cdef.get("specialty_id", "")),
			"specialty_name": str(cdef.get("specialty_name", "")),
			"present": is_here,
			"reinforce_in_ticks": r_ticks,
			"next_tick": idx if is_here else r_ticks + 1,
			"reaction_ready": is_here,
			"stunned": false,
			"grid_x": spawn_pos.x,
			"grid_y": spawn_pos.y,
			"move_points_max": mp_max,
			"move_points_left": mp_max if is_here else 0
		})
		if is_here:
			idx += 1

	_push_log(intro_text)
	_apply_encounter_pre_modifiers(enc)
	var enc_hook: String = str(enc.get("custom_script", ""))
	if enc_hook != "":
		_invoke_custom_hook(enc_hook, "on_encounter_start", {"encounter_id": enc_id})

	_ensure_valid_target()
	_check_crisis_triggers()
	_sync_step_state()
	_emit_feedback("intro", "", encounter_title, intro_text, false)
	AudioRadio.play_cassette_click()
	timeline_updated.emit()

func _apply_encounter_pre_modifiers(enc: Dictionary) -> void:
	var pms_var: Variant = enc.get("pre_modifiers", [])
	if not (pms_var is Array):
		return
	for pm_v in (pms_var as Array):
		if not (pm_v is Dictionary):
			continue
		var pm: Dictionary = pm_v as Dictionary
		var req_flag: String = str(pm.get("if_flag", ""))
		if req_flag != "" and not GameState.has_flag(req_flag):
			continue
		var req_eq_act: String = str(pm.get("if_equipped_action", ""))
		var holder_name: String = ""
		if req_eq_act != "":
			var found_holder: bool = false
			for a_item in allies:
				if bool(a_item.get("present", false)):
					var acid: String = str(a_item.get("char_id", ""))
					for act_d in GameState.get_unlocked_equipment_actions(acid):
						if str(act_d.get("id", "")) == req_eq_act:
							found_holder = true
							holder_name = str(a_item.get("name", acid))
							break
					if found_holder:
						break
			if not found_holder:
				continue

		if pm.has("escape_delta"):
			escape_progress += int(pm.get("escape_delta", 0))
		if pm.has("clock_delta") and is_escalation_enabled():
			crs_ticks += int(pm.get("clock_delta", 0))

		var t_tag: String = str(pm.get("target_tag", ""))
		if t_tag != "":
			for en in enemies:
				if _enemy_has_tag(en, t_tag):
					if pm.has("resolve_delta"):
						var min_res: int = maxi(1, int(pm.get("min_resolve", 1)))
						var new_max: int = maxi(min_res, int(en.get("resolve_max", 3)) + int(pm.get("resolve_delta", 0)))
						en["resolve_max"] = new_max
						en["resolve"] = new_max
					if bool(pm.get("clear_counter", false)):
						en["counter_ready"] = false

		var pm_log: String = str(pm.get("log", ""))
		if pm_log != "":
			_push_log(pm_log.replace("{holder}", holder_name))

func _enemy_has_tag(enemy: Dictionary, tag: String) -> bool:
	if tag == "" or enemy.is_empty():
		return false
	if str(enemy.get("id", "")) == tag:
		return true
	var tags_v: Variant = enemy.get("tags", [])
	if tags_v is Array:
		for tv in (tags_v as Array):
			if str(tv) == tag:
				return true
	return false

## Exécute optionnellement un script personnalisé du pack scénario (Option 2A — Hook custom_script).
func _invoke_custom_hook(script_path: String, method_name: String, ctx: Dictionary) -> Variant:
	var resolved: String = DataLoader.resolve_scenario_path(script_path)
	if resolved == "" or not ResourceLoader.exists(resolved):
		return null
	var scr_res: Resource = load(resolved)
	if scr_res is GDScript:
		var inst: RefCounted = (scr_res as GDScript).new()
		if inst != null and inst.has_method(method_name):
			return inst.call(method_name, self, GameState, DataLoader, ctx)
	return null

## Retourne l'allié présent prêt à agir au cran 0, ou un dictionnaire vide.
func get_acting_ally() -> Dictionary:
	if is_charge_window_active():
		return {}
	var best: Dictionary = {}
	var best_tick: int = 999
	for a in allies:
		if bool(a.get("present", false)):
			var t: int = int(a.get("next_tick", 99))
			if t < best_tick:
				best_tick = t
				best = a
	if best_tick == 0:
		return best
	return {}

## Indique si une fenêtre temps réel de 10 s d'interception contre une Charge PNJ est ouverte.
func is_charge_window_active() -> bool:
	return active and not pending_enemy_charge.is_empty()

## Calcule le budget de points de mouvement (2 à 3 cases) d'un PJ par tour selon Corps et Esquive.
func compute_ally_move_points(char_id: String) -> int:
	var corps_v: int = GameState.get_effective_characteristic(char_id, "corps")
	var esq_v: int = GameState.get_effective_skill(char_id, "caves_esquive")
	return 3 if (corps_v >= 4 or esq_v >= 2) else 2

## Distance de grille en cases (norme de Chebyshev : diagonale = 1 case).
func grid_distance(ax: int, ay: int, bx: int, by: int) -> int:
	return maxi(absi(ax - bx), absi(ay - by))

## Retourne la case entière occupée par un pion PJ ou PNJ sur la grille 8x8.
func get_entity_grid_pos(kind: String, entity_id: String) -> Vector2i:
	if kind == "ally":
		var al: Dictionary = _find_ally(entity_id)
		if not al.is_empty():
			return Vector2i(int(al.get("grid_x", -1)), int(al.get("grid_y", -1)))
	elif kind == "enemy":
		var en: Dictionary = _find_enemy(entity_id)
		if not en.is_empty():
			return Vector2i(int(en.get("grid_x", -1)), int(en.get("grid_y", -1)))
	return Vector2i(-1, -1)

## Calcule la distance en cases entre deux entités du plateau de combat (-1 si invalide).
func get_distance_between(kind_a: String, id_a: String, kind_b: String, id_b: String) -> int:
	var pa: Vector2i = get_entity_grid_pos(kind_a, id_a)
	var pb: Vector2i = get_entity_grid_pos(kind_b, id_b)
	if pa.x < 0 or pb.x < 0:
		return -1
	return grid_distance(pa.x, pa.y, pb.x, pb.y)

## Indique si une case entière de la grille 8x8 est libre et praticable.
func is_combat_cell_walkable(gx: int, gy: int, ignore_kind: String = "", ignore_id: String = "") -> bool:
	if gx < 0 or gx >= COMBAT_GRID_W or gy < 1 or gy >= COMBAT_GRID_H:
		return false
	if _combat_blocked_cells.has("%d,%d" % [gx, gy]):
		return false
	for a in allies:
		if not bool(a.get("present", false)):
			continue
		if ignore_kind == "ally" and str(a.get("char_id", "")) == ignore_id:
			continue
		if int(a.get("grid_x", -1)) == gx and int(a.get("grid_y", -1)) == gy:
			return false
	for e in enemies:
		if bool(e.get("defeated", false)):
			continue
		if ignore_kind == "enemy" and str(e.get("id", "")) == ignore_id:
			continue
		if int(e.get("grid_x", -1)) == gx and int(e.get("grid_y", -1)) == gy:
			return false
	return true

## Retourne les cases atteignables ("x,y" -> coût PM) du PJ actif par BFS 4 directions.
func get_reachable_cells_for_active_ally() -> Dictionary:
	if not active or awaiting_step or is_charge_window_active():
		return {}
	var actor: Dictionary = get_acting_ally()
	if actor.is_empty() or bool(actor.get("stunned", false)):
		return {}
	var cid: String = str(actor.get("char_id", ""))
	var mp_left: int = int(actor.get("move_points_left", 0))
	if mp_left <= 0:
		return {}
	var sx: int = int(actor.get("grid_x", -1))
	var sy: int = int(actor.get("grid_y", -1))
	if sx < 0 or sy < 1:
		return {}
	var out: Dictionary = {}
	var visited: Dictionary = {"%d,%d" % [sx, sy]: 0}
	var queue: Array[Vector3i] = [Vector3i(sx, sy, 0)]
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var cur: Vector3i = queue[0]
		queue.remove_at(0)
		if cur.z >= mp_left:
			continue
		for dv in dirs:
			var nx: int = cur.x + dv.x
			var ny: int = cur.y + dv.y
			var nk: String = "%d,%d" % [nx, ny]
			var nc: int = cur.z + 1
			if visited.has(nk) and int(visited.get(nk, 999)) <= nc:
				continue
			if not is_combat_cell_walkable(nx, ny, "ally", cid):
				continue
			visited[nk] = nc
			out[nk] = nc
			queue.append(Vector3i(nx, ny, nc))
	return out

## Déplace le PJ actif vers une case bleue accessible sans consommer son action du tour.
func move_active_ally_to(gx: int, gy: int) -> bool:
	if not active or awaiting_step or is_charge_window_active():
		return false
	var actor: Dictionary = get_acting_ally()
	if actor.is_empty() or bool(actor.get("stunned", false)):
		return false
	var reach: Dictionary = get_reachable_cells_for_active_ally()
	var key: String = "%d,%d" % [gx, gy]
	if not reach.has(key):
		return false
	var cost: int = int(reach.get(key, 1))
	var mp_before: int = int(actor.get("move_points_left", 0))
	var cid: String = str(actor.get("char_id", ""))
	var cname: String = str(actor.get("name", cid))
	actor["grid_x"] = gx
	actor["grid_y"] = gy
	actor["move_points_left"] = maxi(0, mp_before - cost)
	var m_msg: String = "%s se déplace sur (%d, %d) (PM restants : %d)." % [cname, gx, gy, int(actor.get("move_points_left", 0))]
	_push_log(m_msg)
	_emit_feedback("move", cid, cname, m_msg, false)
	AudioRadio.play_cassette_click()
	timeline_updated.emit()
	return true

## Retourne le meilleur couvert tactique actif sur une case donnée (couvert bas sur place ou obstacle adjacent).
func get_cover_at_cell(gx: int, gy: int) -> Dictionary:
	var best: Dictionary = {"in_cover": false, "label": "", "defense_bonus": 0, "moral_absorb": 0}
	if gx < 0 or gy < 1:
		return best
	var best_score: int = 0
	for cov in cover_tiles:
		var cx_c: int = int(cov.get("x", -1))
		var cy_c: int = int(cov.get("y", -1))
		var blocks_mv: bool = bool(cov.get("blocks_movement", false))
		var applies: bool = (cx_c == gx and cy_c == gy and not blocks_mv) or (blocks_mv and grid_distance(gx, gy, cx_c, cy_c) == 1)
		if not applies:
			continue
		var def_b: int = maxi(0, int(cov.get("defense_bonus", 1)))
		var mor_a: int = maxi(0, int(cov.get("moral_absorb", 2)))
		var sc: int = def_b * 10 + mor_a
		if sc > best_score:
			best_score = sc
			best = {
				"in_cover": true,
				"label": str(cov.get("label", "Couvert")),
				"defense_bonus": def_b,
				"moral_absorb": mor_a
			}
	return best

## Retourne les informations de couvert tactique applicables à un pion PJ ou PNJ.
func get_entity_cover_info(kind: String, entity_id: String) -> Dictionary:
	var pos: Vector2i = get_entity_grid_pos(kind, entity_id)
	return get_cover_at_cell(pos.x, pos.y)

## Retourne l'élément interactif non consommé situé à la case (gx, gy), ou {} s'il n'y en a aucun.
func get_combat_interactable_at(gx: int, gy: int) -> Dictionary:
	for item in combat_interactables:
		if not bool(item.get("used", false)) and int(item.get("x", -1)) == gx and int(item.get("y", -1)) == gy:
			return item
	return {}

## Retourne les éléments interactifs du décor avec portée et probabilité pour le PJ actif.
func get_available_combat_interactables() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not active or awaiting_step or is_charge_window_active():
		return out
	var actor: Dictionary = get_acting_ally()
	if actor.is_empty() or bool(actor.get("stunned", false)):
		return out
	var actor_id: String = str(actor.get("char_id", DataLoader.get_leader_char_id()))
	var ap: Vector2i = Vector2i(int(actor.get("grid_x", 3)), int(actor.get("grid_y", 6)))
	for item in combat_interactables:
		var ix: int = int(item.get("x", 0))
		var iy: int = int(item.get("y", 1))
		var dist: int = grid_distance(ap.x, ap.y, ix, iy)
		var max_r: int = maxi(1, int(item.get("max_range", 2)))
		var used_flag: bool = bool(item.get("used", false))
		var sk_id: String = str(item.get("skill", "systeme_d"))
		var dc_val: int = int(item.get("dc", 9))
		var rp: Dictionary = GameState.preview_street_roll(actor_id, sk_id, dc_val, 0, "")
		out.append({
			"id": str(item.get("id", "")),
			"label": str(item.get("label", "Interactif")),
			"x": ix,
			"y": iy,
			"distance": dist,
			"max_range": max_r,
			"in_range": (not used_flag) and dist <= max_r,
			"used": used_flag,
			"chance_pct": int(rp.get("chance_pct", 50)),
			"roll_formula": str(rp.get("roll_formula", "")),
			"skill_name": str(rp.get("skill_name", sk_id)),
			"dc": dc_val
		})
	return out

## Déclenche un élément interactif du décor (Jet de rue 2d6 + briques d'effets JSON).
func trigger_combat_interactable(prop_id: String) -> Dictionary:
	if not active or awaiting_step or is_charge_window_active():
		return {"executed": false, "reason": "Action impossible maintenant"}
	var actor: Dictionary = get_acting_ally()
	if actor.is_empty() or bool(actor.get("stunned", false)):
		return {"executed": false, "reason": "Aucun PJ actif"}
	var target_idx: int = -1
	for i in range(combat_interactables.size()):
		if str(combat_interactables[i].get("id", "")) == prop_id:
			target_idx = i
			break
	if target_idx < 0:
		return {"executed": false, "reason": "Élément introuvable"}
	var item: Dictionary = combat_interactables[target_idx]
	if bool(item.get("used", false)):
		return {"executed": false, "reason": "Déjà utilisé"}
	var actor_id: String = str(actor.get("char_id", DataLoader.get_leader_char_id()))
	var actor_name: String = str(actor.get("name", actor_id))
	var dist: int = grid_distance(int(actor.get("grid_x", 3)), int(actor.get("grid_y", 6)), int(item.get("x", 0)), int(item.get("y", 1)))
	var max_r: int = maxi(1, int(item.get("max_range", 2)))
	if dist > max_r:
		return {"executed": false, "reason": "Hors portée (%d > %dc)" % [dist, max_r]}

	var sk_id: String = str(item.get("skill", "systeme_d"))
	var dc_val: int = int(item.get("dc", 9))
	var lbl: String = str(item.get("label", prop_id))
	var roll_res: Dictionary = GameState.perform_street_roll(actor_id, sk_id, dc_val, 0, lbl)
	var success: bool = bool(roll_res.get("success", false))
	var is_bril: bool = bool(roll_res.get("is_brilliant", false))
	var is_crit_s: bool = bool(roll_res.get("is_crit_success", false))
	var r_hdr: String = str(roll_res.get("roll_summary", "%s [%s]" % [actor_name, lbl]))
	_push_log(r_hdr)

	var tgt_e: Dictionary = _ensure_valid_target()
	var ctx: Dictionary = {
		"actor_id": actor_id,
		"actor": actor_name,
		"target": str(tgt_e.get("name", "")),
		"target_enemy": tgt_e,
		"tool": lbl,
		"is_brilliant": is_bril,
		"is_crit_success": is_crit_s,
		"roll_bonus": 0,
		"scaled_active": false,
		"dmg": 0,
		"push": 0,
		"clock": 0,
		"moral": 0,
		"cut_suffix": ""
	}
	var eff_arr: Variant = item.get("effects" if success else "fail_effects", [])
	_execute_effect_bricks(eff_arr, ctx)
	var tpl_msg: String = str(item.get("log_success" if success else "log_fail", ""))
	if tpl_msg == "":
		tpl_msg = "⚙ %s active %s !" % [actor_name, lbl] if success else "⚙ %s rate l'activation de %s." % [actor_name, lbl]
	var final_msg: String = _format_combat_log(tpl_msg, ctx)
	_push_log(final_msg)

	if bool(item.get("one_shot", true)):
		item["used"] = true
		combat_interactables[target_idx] = item

	var tick_cost: int = maxi(1, int(item.get("cost_tick", 2)))
	actor["next_tick"] = int(actor.get("next_tick", 0)) + tick_cost
	actor["move_points_left"] = 0
	AudioRadio.play_cassette_click() if success else AudioRadio.play_crisis_buzz()
	_emit_feedback("ally_brilliant" if success else "ally_flaw", actor_id, actor_name, final_msg, success)

	if _all_enemies_defeated():
		_finish("social_win", _get_win_summary())
		return {"executed": true, "success": success, "summary": final_msg}

	_ensure_valid_target()
	_check_crisis_triggers()
	_sync_step_state()
	timeline_updated.emit()
	return {"executed": true, "success": success, "summary": final_msg}

## Met fin au tour du PJ actif sans attaquer (après déplacement ou attente, coût réduit +1 cran).
func end_active_ally_turn_wait() -> void:
	if not active or awaiting_step or is_charge_window_active():
		return
	var actor: Dictionary = get_acting_ally()
	if actor.is_empty():
		return
	var cid: String = str(actor.get("char_id", ""))
	var cname: String = str(actor.get("name", cid))
	actor["move_points_left"] = 0
	actor["reaction_ready"] = true
	actor["next_tick"] = 1
	var w_msg: String = "%s tient sa position (+1 cran, Réaction prête)." % cname
	_push_log(w_msg)
	_emit_feedback("move", cid, cname, w_msg, false)
	AudioRadio.play_cassette_click()
	_sync_step_state()
	timeline_updated.emit()

## Retourne la case libre adjacente à (target_x, target_y) la plus proche de (from_x, from_y).
func find_closest_adjacent_cell(from_x: int, from_y: int, target_x: int, target_y: int, ignore_kind: String = "", ignore_id: String = "") -> Vector2i:
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_score: int = 999999
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var cx: int = target_x + dx
			var cy: int = target_y + dy
			if not is_combat_cell_walkable(cx, cy, ignore_kind, ignore_id):
				continue
			var md: int = absi(cx - from_x) + absi(cy - from_y)
			var sq: int = (cx - from_x) * (cx - from_x) + (cy - from_y) * (cy - from_y)
			var score: int = md * 100 + sq
			if score < best_score:
				best_score = score
				best_cell = Vector2i(cx, cy)
	return best_cell

func _find_first_free_ally_spawn_cell() -> Vector2i:
	for row_y in [6, 7, 5]:
		for col_x in [5, 3, 1, 6, 2, 4, 0, 7]:
			if is_combat_cell_walkable(col_x, row_y):
				return Vector2i(col_x, row_y)
	return Vector2i(3, 6)

func _roll_2d6() -> Array[int]:
	var d1: int = randi_range(1, 6)
	var d2: int = randi_range(1, 6)
	if not GameState.forced_roll_queue.is_empty():
		var f_var: Variant = GameState.forced_roll_queue[0]
		GameState.forced_roll_queue.remove_at(0)
		if f_var is Array and (f_var as Array).size() >= 2:
			var f_arr: Array = f_var as Array
			d1 = clampi(int(f_arr[0]), 1, 6)
			d2 = clampi(int(f_arr[1]), 1, 6)
	return [d1, d2]

## Sélectionne explicitement un ennemi actif comme cible courante.
func select_target(enemy_id: String) -> void:
	if not active:
		return
	var found: Dictionary = _find_enemy(enemy_id)
	if found.is_empty() or bool(found.get("defeated", false)):
		return
	selected_target_id = enemy_id
	AudioRadio.play_cassette_click()
	timeline_updated.emit()

## Fait tourner la cible active vers le prochain adversaire encore debout.
func cycle_target() -> void:
	if not active:
		return
	var active_ids: Array[String] = []
	for e in enemies:
		if not bool(e.get("defeated", false)):
			active_ids.append(str(e.get("id", "")))
	if active_ids.is_empty():
		selected_target_id = ""
		return
	var cur_idx: int = active_ids.find(selected_target_id)
	var next_idx: int = (cur_idx + 1) % active_ids.size()
	selected_target_id = active_ids[next_idx]
	AudioRadio.play_cassette_click()
	timeline_updated.emit()

## Retourne la cible sélectionnée valide (ou réaligne automatiquement sur le plus proche).
func get_selected_target() -> Dictionary:
	return _ensure_valid_target()

func _compute_action_roll_params(adef: Dictionary, actor_id: String, target: Dictionary) -> Dictionary:
	var skill_id: String = str(adef.get("skill", "tchatche"))
	var dc_source: String = str(adef.get("dc_source", "fixed"))
	var dc: int = int(adef.get("dc_base", 10))
	if dc_source == "enemy_pression":
		dc = int(target.get("dc_pression", 11))
	elif dc_source == "enemy_social":
		dc = int(target.get("dc_social", 11))

	var dmods_v: Variant = adef.get("dc_modifiers", [])
	if dmods_v is Array:
		for dmv in (dmods_v as Array):
			if not (dmv is Dictionary):
				continue
			var dm: Dictionary = dmv as Dictionary
			if dm.has("if_escalation_lte") and crs_ticks > int(dm.get("if_escalation_lte", 0)):
				continue
			var req_fl: String = str(dm.get("if_flag", ""))
			if req_fl != "" and not GameState.has_flag(req_fl):
				continue
			var req_tag: String = str(dm.get("if_target_tag", ""))
			if req_tag != "" and not _enemy_has_tag(target, req_tag):
				continue
			dc += int(dm.get("delta", 0))

	var rprof: Dictionary = GameState.get_ranged_combat_profile(actor_id)
	var has_ranged: bool = bool(rprof.get("has_ranged", false))
	var bonus: int = 0
	var bonus_lbl: String = ""
	var tool_lbl: String = str(adef.get("default_tool_label", ""))

	if bool(adef.get("requires_ranged_tool", false)):
		if has_ranged:
			bonus += int(rprof.get("ranged_bonus", 0))
			bonus_lbl = str(rprof.get("ranged_label", ""))
			if bonus_lbl != "":
				tool_lbl = bonus_lbl
	elif bool(adef.get("uses_throw_bonus", false)):
		var tb: int = int(rprof.get("throw_bonus", 0))
		if tb > 0:
			bonus += tb
			bonus_lbl = str(rprof.get("throw_label", ""))
			if bonus_lbl != "":
				tool_lbl = bonus_lbl

	var rbs_v: Variant = adef.get("roll_bonuses", [])
	if rbs_v is Array:
		for rbv in (rbs_v as Array):
			if not (rbv is Dictionary):
				continue
			var rb: Dictionary = rbv as Dictionary
			var btype: String = str(rb.get("type", "fixed"))
			if btype == "fixed":
				bonus += int(rb.get("val", 0))
				if bonus_lbl == "":
					bonus_lbl = str(rb.get("label", ""))
			elif btype == "any_faveur_or_flag":
				var fl_b: String = str(rb.get("flag", ""))
				if GameState.faveurs > 0 or (fl_b != "" and GameState.has_flag(fl_b)):
					bonus += int(rb.get("val", 1))
					if bonus_lbl == "":
						bonus_lbl = str(rb.get("label", ""))
			elif btype == "if_flag":
				var fl_only: String = str(rb.get("flag", ""))
				if fl_only != "" and GameState.has_flag(fl_only):
					bonus += int(rb.get("val", 1))
					if bonus_lbl == "":
						bonus_lbl = str(rb.get("label", ""))
			elif btype == "aura_tiers":
				var aura_tot: int = GameState.get_total_aura()
				var tiers_v: Variant = rb.get("tiers", [])
				if tiers_v is Array:
					for tv in (tiers_v as Array):
						if tv is Dictionary:
							var td: Dictionary = tv as Dictionary
							if aura_tot >= int(td.get("min_aura", 99)):
								bonus += int(td.get("val", 0))
								if bonus_lbl == "":
									bonus_lbl = "%s %d" % [str(rb.get("label_prefix", "Aura")), aura_tot]
								break

	var cover_dc_bonus: int = 0
	if int(adef.get("min_range", 0)) >= 2 and not target.is_empty():
		var cov_tgt: Dictionary = get_entity_cover_info("enemy", str(target.get("id", "")))
		if bool(cov_tgt.get("in_cover", false)):
			cover_dc_bonus = int(cov_tgt.get("defense_bonus", 1))
			dc += cover_dc_bonus

	return {
		"skill_id": skill_id,
		"dc": dc,
		"bonus": bonus,
		"bonus_label": bonus_lbl,
		"tool_label": tool_lbl,
		"has_ranged_tool": has_ranged,
		"cover_dc_bonus": cover_dc_bonus
	}

func _format_combat_log(tpl: String, ctx: Dictionary) -> String:
	if tpl == "":
		return ""
	var s: String = tpl
	s = s.replace("{actor}", str(ctx.get("actor", "")))
	s = s.replace("{enemy}", str(ctx.get("enemy", "")))
	s = s.replace("{target}", str(ctx.get("target", "")))
	s = s.replace("{tool}", str(ctx.get("tool", "")))
	s = s.replace("{dmg}", str(ctx.get("dmg", 0)))
	s = s.replace("{push}", str(ctx.get("push", 0)))
	s = s.replace("{clock}", str(ctx.get("clock", 0)))
	s = s.replace("{clock_short}", get_escalation_short_label())
	s = s.replace("{escape}", str(escape_progress))
	s = s.replace("{escape_req}", str(get_escape_required_progress()))
	s = s.replace("{moral}", str(ctx.get("moral", 0)))
	s = s.replace("{absorb}", str(ctx.get("absorb", _interposition_absorb)))
	s = s.replace("{cut_suffix}", str(ctx.get("cut_suffix", "")))
	s = s.replace("{from_tick}", str(ctx.get("from_tick", 0)))
	s = s.replace("{to_tick}", str(ctx.get("to_tick", 0)))
	return s

func _execute_effect_bricks(effects_var: Variant, ctx: Dictionary) -> void:
	if not (effects_var is Array):
		return
	var is_bril: bool = bool(ctx.get("is_brilliant", false))
	var is_crit_s: bool = bool(ctx.get("is_crit_success", false))
	var roll_bonus: int = int(ctx.get("roll_bonus", 0))
	var scaled_active: bool = bool(ctx.get("scaled_active", false))
	var actor_id: String = str(ctx.get("actor_id", ""))
	var target_enemy: Dictionary = ctx.get("target_enemy", {}) as Dictionary if ctx.get("target_enemy", {}) is Dictionary else {}
	var source_enemy: Dictionary = ctx.get("source_enemy", {}) as Dictionary if ctx.get("source_enemy", {}) is Dictionary else {}

	for eff_v in (effects_var as Array):
		if not (eff_v is Dictionary):
			continue
		var eff: Dictionary = eff_v as Dictionary
		var op: String = str(eff.get("op", ""))

		if op == "damage_resolve":
			var base_d: int = int(eff.get("amount", 1))
			if roll_bonus > 0 and eff.has("bonus_if_roll_bonus"):
				base_d += int(eff.get("bonus_if_roll_bonus", 0))
			if is_bril and eff.has("brilliant_amount"):
				base_d = maxi(base_d, int(eff.get("brilliant_amount", base_d)))
			if is_crit_s and eff.has("crit_bonus"):
				base_d += int(eff.get("crit_bonus", 0))
			if scaled_active and eff.has("scaled_bonus"):
				base_d += int(eff.get("scaled_bonus", 0))
			var scope: String = str(eff.get("scope", "target"))
			if scope == "target":
				if not target_enemy.is_empty():
					_damage_enemy(target_enemy, base_d)
					ctx["dmg"] = base_d
			elif scope == "other_enemies":
				var main_eid: String = str(target_enemy.get("id", ""))
				for oe in enemies:
					if str(oe.get("id", "")) != main_eid and not bool(oe.get("defeated", false)):
						_damage_enemy(oe, base_d)
			elif scope == "all_enemies":
				for ae in enemies:
					if not bool(ae.get("defeated", false)):
						_damage_enemy(ae, base_d)

		elif op == "push_ticks":
			if bool(eff.get("only_if_brilliant", false)) and not is_bril:
				continue
			var push_c: int = int(eff.get("amount", 1))
			if is_crit_s and eff.has("crit_amount"):
				push_c = int(eff.get("crit_amount", push_c))
			if scaled_active and eff.has("scaled_bonus"):
				push_c += int(eff.get("scaled_bonus", 0))
			if not target_enemy.is_empty():
				target_enemy["next_tick"] = int(target_enemy.get("next_tick", 1)) + push_c
				_remove_pending_enemy(str(target_enemy.get("id", "")))
				ctx["push"] = push_c

		elif op == "cut_counter":
			if bool(eff.get("only_if_brilliant", false)) and not (is_bril or is_crit_s):
				continue
			if not target_enemy.is_empty() and bool(target_enemy.get("counter_ready", false)):
				target_enemy["counter_ready"] = false
				ctx["cut_suffix"] = " + garde coupée !"

		elif op == "set_counter_ready":
			var val_cr: bool = bool(eff.get("value", true))
			if not source_enemy.is_empty():
				source_enemy["counter_ready"] = val_cr
			elif not target_enemy.is_empty():
				target_enemy["counter_ready"] = val_cr

		elif op == "modify_escalation_clock":
			if not is_escalation_enabled():
				continue
			var c_amt: int = int(eff.get("amount", 0))
			if is_bril and eff.has("brilliant_amount"):
				c_amt = int(eff.get("brilliant_amount", c_amt))
			if scaled_active and eff.has("scaled_bonus"):
				c_amt += int(eff.get("scaled_bonus", 0))
			if eff.has("min_val"):
				crs_ticks = maxi(int(eff.get("min_val", 0)), crs_ticks + c_amt)
			else:
				crs_ticks += c_amt
			ctx["clock"] = c_amt

		elif op == "advance_escape":
			var e_amt: int = int(eff.get("amount", 1))
			escape_progress += e_amt

		elif op == "add_shield":
			var sh_amt: int = int(eff.get("amount", 1))
			var abs_pow: int = int(ctx.get("absorb", int(eff.get("absorb", 6))))
			_interposition_absorb = maxi(_interposition_absorb, abs_pow)
			interposition_shield += sh_amt

		elif op == "modify_moral":
			var m_amt: int = int(eff.get("amount", 0))
			if is_bril and eff.has("brilliant_amount"):
				m_amt = int(eff.get("brilliant_amount", m_amt))
			if scaled_active and eff.has("scaled_bonus"):
				m_amt += int(eff.get("scaled_bonus", 0))
			var use_sh: bool = bool(eff.get("use_shield", m_amt < 0))
			var m_tgt: String = str(eff.get("target", "self"))
			var resolved_cid: String = actor_id
			if m_tgt == "all_allies" or m_tgt == "all":
				resolved_cid = "all"
			elif m_tgt == "ally_target":
				resolved_cid = str(ctx.get("ally_target_id", actor_id))
			elif m_tgt == "crisis_ally":
				resolved_cid = str(ctx.get("crisis_ally_id", actor_id))
			elif m_tgt == "target_ally":
				resolved_cid = str(ctx.get("enemy_target_ally_id", actor_id))
			elif m_tgt == "second_ally":
				resolved_cid = _pick_secondary_present_ally_id(str(ctx.get("enemy_target_ally_id", "")))
			if resolved_cid != "":
				if use_sh and m_amt < 0:
					_apply_moral_hit(resolved_cid, m_amt)
				else:
					GameState.modify_moral(resolved_cid, m_amt)
				ctx["moral"] = m_amt

		elif op == "delay_crises":
			var d_amt: int = int(eff.get("amount", 1))
			var d_tgt: String = str(eff.get("target", "all"))
			if d_tgt == "all":
				_delay_crises_by(d_amt)
			elif d_tgt == "ally_target":
				_delay_crisis_for(str(ctx.get("ally_target_id", actor_id)), d_amt)
			else:
				_delay_crisis_for(actor_id, d_amt)

		elif op == "cancel_crisis":
			var cr_cid: String = str(ctx.get("crisis_ally_id", ""))
			if cr_cid != "":
				for ci in range(crisis_queue.size() - 1, -1, -1):
					if str((crisis_queue[ci] as Dictionary).get("char_id", "")) == cr_cid:
						crisis_queue.remove_at(ci)
				_remove_pending_crisis(cr_cid)

		elif op == "advance_turn_counter":
			turn_count += int(eff.get("amount", 1))
			_check_timed_events()

		elif op == "modify_notoriete":
			GameState.notoriete = maxi(0, GameState.notoriete + int(eff.get("amount", 1)))

		elif op == "set_flag":
			var fl_n: String = str(eff.get("flag", ""))
			if fl_n != "":
				GameState.set_flag(fl_n, bool(eff.get("value", true)))

func _simulate_effect_bricks(effects_var: Variant, roll_bonus: int, scaled_active: bool) -> Dictionary:
	var res: Dictionary = {
		"resolve_delta": 0,
		"push_delta": 0,
		"crs_delta": 0,
		"escape_delta": 0,
		"shield_delta": 0,
		"moral_delta": 0,
		"cuts_counter": false,
		"other_dmg": 0,
		"notoriete_delta": 0,
		"delays_crisis": false
	}
	if not (effects_var is Array):
		return res
	for eff_v in (effects_var as Array):
		if not (eff_v is Dictionary):
			continue
		var eff: Dictionary = eff_v as Dictionary
		var op: String = str(eff.get("op", ""))
		if bool(eff.get("only_if_brilliant", false)):
			continue
		if op == "damage_resolve":
			var d: int = int(eff.get("amount", 1))
			if roll_bonus > 0 and eff.has("bonus_if_roll_bonus"):
				d += int(eff.get("bonus_if_roll_bonus", 0))
			if scaled_active and eff.has("scaled_bonus"):
				d += int(eff.get("scaled_bonus", 0))
			var sc: String = str(eff.get("scope", "target"))
			if sc == "target":
				res["resolve_delta"] = int(res["resolve_delta"]) - d
			else:
				res["other_dmg"] = int(res["other_dmg"]) + d
		elif op == "push_ticks":
			var p: int = int(eff.get("amount", 1))
			if scaled_active and eff.has("scaled_bonus"):
				p += int(eff.get("scaled_bonus", 0))
			res["push_delta"] = int(res["push_delta"]) + p
		elif op == "cut_counter":
			res["cuts_counter"] = true
		elif op == "modify_escalation_clock":
			var c: int = int(eff.get("amount", 0))
			if scaled_active and eff.has("scaled_bonus"):
				c += int(eff.get("scaled_bonus", 0))
			res["crs_delta"] = int(res["crs_delta"]) + c
		elif op == "advance_escape":
			res["escape_delta"] = int(res["escape_delta"]) + int(eff.get("amount", 1))
		elif op == "add_shield":
			res["shield_delta"] = int(res["shield_delta"]) + int(eff.get("amount", 1))
		elif op == "modify_moral":
			var m: int = int(eff.get("amount", 0))
			if scaled_active and eff.has("scaled_bonus"):
				m += int(eff.get("scaled_bonus", 0))
			res["moral_delta"] = int(res["moral_delta"]) + m
		elif op == "modify_notoriete":
			res["notoriete_delta"] = int(res["notoriete_delta"]) + int(eff.get("amount", 1))
		elif op == "delay_crises":
			res["delays_crisis"] = true
	return res

## Exécute une action tactique du tour actif (Jet de rue 2d6 + briques d'effets JSON) puis prépare le pas-à-pas suivant.
func execute_player_action(action_id: String) -> void:
	if not active or is_charge_window_active():
		return
	if awaiting_step:
		step_next_beat()
		return
	var actor: Dictionary = get_acting_ally()
	if actor.is_empty():
		_sync_step_state()
		timeline_updated.emit()
		return

	var default_leader: String = DataLoader.get_leader_char_id()
	var actor_id: String = str(actor.get("char_id", default_leader))
	var actor_name: String = str(actor.get("name", actor_id))
	if action_id == "act_wait":
		end_active_ally_turn_wait()
		return
	if action_id == "act_escape_now":
		if can_escape_now():
			var esc_out: String = str(_escape_cfg.get("outcome_id", "escaped"))
			var esc_sum: String = str(_escape_cfg.get("summary", "Échappée réussie !"))
			_finish(esc_out, esc_sum)
		return

	var adef: Dictionary = DataLoader.get_combat_action_def(action_id)
	if adef.is_empty():
		return
	var pv: Dictionary = _build_action_preview(action_id, actor_id)
	if not bool(pv.get("valid", false)):
		return

	var tk: String = get_action_target_kind(action_id)
	var target: Dictionary = _ensure_valid_target() if tk == "enemy" else {}
	if str(adef.get("movement_mode", "")) == "charge" and not target.is_empty():
		var ax_c: int = int(actor.get("grid_x", 3))
		var ay_c: int = int(actor.get("grid_y", 6))
		var tx_c: int = int(target.get("grid_x", 4))
		var ty_c: int = int(target.get("grid_y", 2))
		var landing: Vector2i = find_closest_adjacent_cell(ax_c, ay_c, tx_c, ty_c, "ally", actor_id)
		if landing.x < 0:
			return
		if bool(target.get("counter_ready", false)) and not bool(target.get("stunned", false)):
			target["counter_ready"] = false
			var dice_i: Array[int] = _roll_2d6()
			var d1_i: int = dice_i[0]
			var d2_i: int = dice_i[1]
			var int_bonus: int = int(target.get("intercept_bonus", 2))
			var dc_int: int = clampi(8 + GameState.get_effective_characteristic(actor_id, "corps") + maxi(0, int(GameState.get_effective_skill(actor_id, "caves_esquive") / 2)), 9, 13)
			var tot_i: int = d1_i + d2_i + int_bonus
			var int_ok: bool = (d1_i == 6 and d2_i == 6) or (not (d1_i == 1 and d2_i == 1) and tot_i >= dc_int)
			var int_hdr: String = "%s 🎲 %d+%d (+%d Interception) = %d / DD %d → %s" % [
				str(target.get("name", "")), d1_i, d2_i, int_bonus, tot_i, dc_int,
				("INTERCEPTION RÉUSSIE !" if int_ok else "INTERCEPTION RATÉE")
			]
			_push_log(int_hdr)
			if int_ok:
				var base_cost: int = maxi(1, int(adef.get("cost_tick", 2)))
				actor["stunned"] = true
				actor["reaction_ready"] = false
				actor["move_points_left"] = 0
				actor["next_tick"] = base_cost + CHARGE_STUN_RANK_PENALTY
				var stun_msg: String = "💥 INTERCEPTION ! %s brise la charge de %s : %s est ASSOMMÉ et perd 2 rangs (+%d crans) !" % [
					str(target.get("name", "")), actor_name, actor_name, base_cost + CHARGE_STUN_RANK_PENALTY
				]
				_push_log(stun_msg)
				AudioRadio.play_interrupt_hit()
				AudioRadio.play_crisis_buzz()
				_emit_feedback("counter", str(target.get("id", "")), str(target.get("name", "")), "%s | %s" % [int_hdr, stun_msg], true)
				_ensure_valid_target()
				_check_crisis_triggers()
				_sync_step_state()
				timeline_updated.emit()
				return
			else:
				_push_log("%s évite l'interception de %s et poursuit sa Charge !" % [actor_name, str(target.get("name", ""))])
		actor["grid_x"] = landing.x
		actor["grid_y"] = landing.y
		actor["move_points_left"] = 0

	var ally_tid: String = _explicit_ally_target_id
	_explicit_ally_target_id = ""
	if tk == "ally":
		if ally_tid == "" or _find_ally(ally_tid).is_empty() or not bool(_find_ally(ally_tid).get("present", false)):
			if str(adef.get("ally_target_default", "lowest_moral")) == "lowest_moral":
				ally_tid = _get_lowest_moral_present_ally_id(actor_id)
			else:
				ally_tid = actor_id

	var skill_id: String = str(pv.get("skill_id", "tchatche"))
	var dc: int = int(pv.get("dc", 10))
	var bonus: int = int(pv.get("bonus", 0))
	var bonus_lbl: String = str(pv.get("bonus_label", ""))
	var tool_lbl: String = str(pv.get("tool_label", bonus_lbl))
	var roll_res: Dictionary = GameState.perform_street_roll(actor_id, skill_id, dc, bonus, bonus_lbl)
	var ok: bool = bool(roll_res.get("success", false))
	var is_bril: bool = bool(roll_res.get("is_brilliant", false))
	var is_crit_s: bool = bool(roll_res.get("is_crit_success", false))
	var is_flaw_b: bool = bool(roll_res.get("is_flaw_blunder", false))
	var roll_hdr: String = str(roll_res.get("roll_summary", ""))
	var fb_kind: String = "ally_brilliant" if is_bril else ("ally_action" if ok else ("ally_flaw" if is_flaw_b else "ally_action"))

	if bool(adef.get("once_per_encounter", bool(adef.get("is_equipment", false)))):
		var u_key: String = "%s:%s" % [actor_id, action_id]
		_used_equip_actions[u_key] = true

	var branch_key: String = "on_success" if ok else ("on_flaw" if (is_flaw_b and adef.has("on_flaw")) else "on_fail")
	var branch_v: Variant = adef.get(branch_key, {})
	var branch: Dictionary = branch_v as Dictionary if branch_v is Dictionary else {}

	var t_display: String = str(target.get("name", "")) if tk == "enemy" else (str(DataLoader.get_character(ally_tid).get("name", ally_tid)) if tk == "ally" else "")
	var ctx: Dictionary = {
		"action_id": action_id,
		"actor_id": actor_id,
		"actor": actor_name,
		"target": t_display,
		"tool": tool_lbl,
		"target_enemy": target,
		"ally_target_id": ally_tid,
		"is_brilliant": is_bril,
		"is_crit_success": is_crit_s,
		"is_flaw": is_flaw_b,
		"roll_bonus": bonus,
		"scaled_active": false,
		"dmg": 0,
		"push": 0,
		"clock": 0,
		"moral": 0,
		"cut_suffix": ""
	}

	var custom_scr: String = str(adef.get("custom_script", ""))
	if custom_scr != "":
		_invoke_custom_hook(custom_scr, "execute_action", ctx)
	else:
		_execute_effect_bricks(branch.get("effects", []), ctx)

	if bool(branch.get("buzz", false)):
		AudioRadio.play_crisis_buzz()
	var shake_flag: bool = bool(branch.get("shake", false)) or (is_bril and bool(branch.get("shake_on_brilliant", false)))
	var log_tpl: String = str(branch.get("brilliant_log", "")) if (is_bril and str(branch.get("brilliant_log", "")) != "") else str(branch.get("log", ""))
	var effect_msg: String = _format_combat_log(log_tpl, ctx)

	_push_log(roll_hdr)
	if effect_msg != "":
		_push_log(effect_msg)
	_emit_feedback(fb_kind, actor_id, actor_name, "%s | %s" % [roll_hdr, effect_msg], shake_flag)

	var tick_cost: int = maxi(1, int(adef.get("cost_tick", 2)))
	actor["reaction_ready"] = true
	actor["move_points_left"] = 0
	actor["next_tick"] = tick_cost
	AudioRadio.play_cassette_click()

	if _all_enemies_defeated():
		_finish("social_win", _get_win_summary())
		return

	_ensure_valid_target()
	_check_crisis_triggers()
	_sync_step_state()
	timeline_updated.emit()

func _select_specialty_mode(spec_def: Dictionary) -> Dictionary:
	var modes_v: Variant = spec_def.get("modes", [])
	if not (modes_v is Array):
		return {}
	var has_cr: bool = not crisis_queue.is_empty()
	var has_en: bool = not get_valid_target_ids("enemy").is_empty()
	for mv in (modes_v as Array):
		if not (mv is Dictionary):
			continue
		var md: Dictionary = mv as Dictionary
		var cond: String = str(md.get("when", "always"))
		if cond == "has_crisis" and has_cr:
			return md
		if cond == "has_enemy" and has_en:
			return md
		if cond == "always":
			return md
	return {}

func _eval_specialty_scaling(char_id: String, mode: Dictionary) -> Dictionary:
	var scaled_ok: bool = false
	var sk_sc_v: Variant = mode.get("skill_scaling", {})
	if sk_sc_v is Dictionary and not (sk_sc_v as Dictionary).is_empty():
		var sk_sc: Dictionary = sk_sc_v as Dictionary
		var sk_id: String = str(sk_sc.get("skill", ""))
		if sk_id != "" and GameState.get_effective_skill(char_id, sk_id) >= int(sk_sc.get("min_val", 3)):
			scaled_ok = true
	var absorb_val: int = _interposition_absorb
	var ab_sc_v: Variant = mode.get("absorb_scaling", {})
	if ab_sc_v is Dictionary and not (ab_sc_v as Dictionary).is_empty():
		var ab_sc: Dictionary = ab_sc_v as Dictionary
		var base_a: int = int(ab_sc.get("base_absorb", 6))
		var boost_a: int = int(ab_sc.get("boosted_absorb", 8))
		var ask: String = str(ab_sc.get("skill", ""))
		var ach: String = str(ab_sc.get("charac", ""))
		var ok_s: bool = ask != "" and GameState.get_effective_skill(char_id, ask) >= int(ab_sc.get("min_skill", 3))
		var ok_c: bool = ach != "" and GameState.get_effective_characteristic(char_id, ach) >= int(ab_sc.get("min_charac", 4))
		absorb_val = boost_a if (ok_s or ok_c) else base_a
	return {"scaled_active": scaled_ok, "absorb": absorb_val}

## Déclenche une Interruption hors-tour pilotée par rules/specialties.json si la Réaction de l'allié est prête.
func trigger_interruption(char_id: String) -> void:
	if not active or is_charge_window_active():
		return
	var ally: Dictionary = _find_ally(char_id)
	if ally.is_empty() or not bool(ally.get("present", false)) or not bool(ally.get("reaction_ready", false)) or bool(ally.get("stunned", false)):
		return

	var spec_id: String = str(ally.get("specialty_id", ""))
	var spec_def: Dictionary = DataLoader.get_specialty_def(spec_id)
	var mode: Dictionary = _select_specialty_mode(spec_def)
	if mode.is_empty():
		return

	ally["reaction_ready"] = false
	var cname: String = str(ally.get("name", char_id))
	AudioRadio.play_interrupt_hit()

	# Contre-interruption d'un adversaire en garde si prête
	var counter_triggered: bool = false
	for e in enemies:
		if not bool(e.get("defeated", false)) and not bool(e.get("stunned", false)) and bool(e.get("counter_ready", false)):
			e["counter_ready"] = false
			counter_triggered = true
			var c_msg: String = "CONTRE-INTERRUPTION ! %s tente un Coup de pression sur %s (-6 Moral) !" % [str(e.get("name", "")), cname]
			_push_log(c_msg)
			_apply_moral_hit(char_id, -6)
			_emit_feedback("counter", str(e.get("id", "")), str(e.get("name", "")), c_msg, true)

	var m_tk: String = str(mode.get("target_kind", "none"))
	var target_en: Dictionary = _ensure_valid_target() if m_tk == "enemy" else {}
	var exp_cr_id: String = _explicit_crisis_target_id
	_explicit_crisis_target_id = ""
	var cr_cid: String = ""
	if m_tk == "ally_crisis" and not crisis_queue.is_empty():
		cr_cid = str((crisis_queue[0] as Dictionary).get("char_id", ""))
		if exp_cr_id != "":
			for cr_d in crisis_queue:
				if str(cr_d.get("char_id", "")) == exp_cr_id:
					cr_cid = exp_cr_id
					break

	var sc_info: Dictionary = _eval_specialty_scaling(char_id, mode)
	var t_disp: String = str(target_en.get("name", "")) if m_tk == "enemy" else (str(DataLoader.get_character(cr_cid).get("name", cr_cid)) if m_tk == "ally_crisis" else cname)
	var ctx: Dictionary = {
		"actor_id": char_id,
		"actor": cname,
		"target": t_disp,
		"target_enemy": target_en,
		"crisis_ally_id": cr_cid,
		"scaled_active": bool(sc_info.get("scaled_active", false)),
		"absorb": int(sc_info.get("absorb", 6)),
		"is_brilliant": false,
		"is_crit_success": false,
		"roll_bonus": 0,
		"dmg": 0,
		"push": 0,
		"clock": 0,
		"moral": 0
	}

	var spec_hook: String = str(mode.get("custom_script", str(spec_def.get("custom_script", ""))))
	if spec_hook != "":
		_invoke_custom_hook(spec_hook, "execute_interruption", ctx)
	else:
		_execute_effect_bricks(mode.get("effects", []), ctx)

	var i_msg: String = _format_combat_log(str(mode.get("log", "")), ctx)
	if i_msg != "":
		_push_log(i_msg)
		if not counter_triggered:
			_emit_feedback("interrupt", char_id, cname, i_msg, bool(mode.get("shake", false)))

	if _all_enemies_defeated():
		_finish("social_win", _get_win_summary())
		return

	_ensure_valid_target()
	_sync_step_state()
	timeline_updated.emit()

## Dépense la Réaction d'un camarade pour contenir une Crise d'autonomie imminente.
func restrain_crisis(crisis_char_id: String) -> void:
	if not active:
		return
	var rescuer: Dictionary = _find_rescuer_for(crisis_char_id)
	if rescuer.is_empty():
		_push_log("Personne n'a de Réaction disponible pour retenir %s !" % crisis_char_id)
		timeline_updated.emit()
		return

	rescuer["reaction_ready"] = false
	for i in range(crisis_queue.size() - 1, -1, -1):
		if str(crisis_queue[i].get("char_id", "")) == crisis_char_id:
			crisis_queue.remove_at(i)
	_remove_pending_crisis(crisis_char_id)
	GameState.modify_moral(crisis_char_id, 8)
	var cr_name: String = str(DataLoader.get_character(crisis_char_id).get("name", crisis_char_id))
	var r_msg: String = "%s plaque %s contre le mur et le calme à temps : Crise d'autonomie contenue (+8 Moral) !" % [str(rescuer.get("name", "")), cr_name]
	_push_log(r_msg)
	_emit_feedback("restrain", str(rescuer.get("char_id", "")), str(rescuer.get("name", "")), r_msg, false)
	AudioRadio.play_cassette_click()
	_sync_step_state()
	timeline_updated.emit()

func has_restrain_reaction_for(crisis_char_id: String) -> bool:
	return not _find_rescuer_for(crisis_char_id).is_empty()

func can_escape_now() -> bool:
	if not is_escape_enabled():
		return false
	return train_fantome_arrived or _escape_unlocked_by_event or escape_progress >= get_escape_required_progress()

## Avance exactement d'un beat non-allié (une crise, une action ennemie, ou 1 cran du rail).
func step_next_beat() -> void:
	if not active or is_charge_window_active():
		return
	if not awaiting_step:
		_sync_step_state()
		if not awaiting_step:
			return

	if not _pending_crisis_ids.is_empty():
		var cid: String = _pending_crisis_ids[0]
		_pending_crisis_ids.remove_at(0)
		for i in range(crisis_queue.size() - 1, -1, -1):
			if str(crisis_queue[i].get("char_id", "")) == cid:
				crisis_queue.remove_at(i)
		_execute_autonomous_crisis(cid)
	elif not _pending_enemy_ids.is_empty():
		var eid: String = _pending_enemy_ids[0]
		_pending_enemy_ids.remove_at(0)
		var ed: Dictionary = _find_enemy(eid)
		if not ed.is_empty() and not bool(ed.get("defeated", false)) and int(ed.get("next_tick", 0)) <= 0:
			_execute_enemy_turn(ed)
			if is_charge_window_active():
				return
	else:
		_advance_one_world_tick()
		if not active:
			return

	if _all_enemies_defeated():
		_finish("social_win", _get_win_summary())
		return

	_ensure_valid_target()
	_check_crisis_triggers()
	_sync_step_state()
	timeline_updated.emit()

## Retourne la bande de portée [min, max] (en cases Chebyshev) pour une action tactique donnée (max=0 si globale).
func get_action_range(action_id: String) -> Dictionary:
	var adef: Dictionary = DataLoader.get_combat_action_def(action_id)
	if adef.is_empty():
		return {"min": 0, "max": 0}
	return {
		"min": int(adef.get("min_range", 0)),
		"max": int(adef.get("max_range", 0))
	}

## Formate un libellé de portée court pour les boutons et infobulles d'action.
func format_range_tag(min_r: int, max_r: int) -> String:
	if max_r <= 0:
		return "∞"
	if min_r == max_r:
		return "%dc" % max_r
	return "%d–%dc" % [min_r, max_r]

func _eval_range_check(action_id: String, actor_id: String, target: Dictionary) -> Dictionary:
	var adef: Dictionary = DataLoader.get_combat_action_def(action_id)
	var rng: Dictionary = get_action_range(action_id)
	var min_r: int = int(rng.get("min", 0))
	var max_r: int = int(rng.get("max", 0))
	var eid: String = str(target.get("id", "")) if not target.is_empty() else ""
	var dist: int = get_distance_between("ally", actor_id, "enemy", eid) if eid != "" else -1
	var in_range: bool = (max_r <= 0) or (dist >= min_r and dist <= max_r)
	var lock_reason: String = ""
	if max_r > 0 and not target.is_empty() and not in_range:
		if dist > max_r:
			lock_reason = "Hors portée (%s req., cible à %dc)" % [format_range_tag(min_r, max_r), dist]
		else:
			lock_reason = "Trop près (%s req., cible à %dc)" % [format_range_tag(min_r, max_r), dist]
	var landing: Vector2i = Vector2i(-1, -1)
	if str(adef.get("movement_mode", "")) == "charge" and not target.is_empty():
		var ap: Vector2i = get_entity_grid_pos("ally", actor_id)
		var ep: Vector2i = get_entity_grid_pos("enemy", eid)
		landing = find_closest_adjacent_cell(ap.x, ap.y, ep.x, ep.y, "ally", actor_id)
		if in_range and landing.x < 0:
			lock_reason = "Aucune case adjacente libre pour charger"
	return {
		"min_range": min_r,
		"max_range": max_r,
		"distance": dist,
		"in_range": in_range,
		"out_of_range": (max_r > 0 and not in_range),
		"landing_cell": landing,
		"lock_reason": lock_reason
	}

## Retourne la liste des cibles valides pour une action précise (filtrée par portée, outil requis et case de Charge).
func get_valid_target_ids_for_action(action_id: String) -> Array[String]:
	var tk: String = get_action_target_kind(action_id)
	if tk == "none":
		return []
	if tk != "enemy":
		return get_valid_target_ids(tk)
	var adef: Dictionary = DataLoader.get_combat_action_def(action_id)
	var acting: Dictionary = get_acting_ally()
	var actor_id: String = str(acting.get("char_id", ""))
	if actor_id == "":
		actor_id = _peek_next_present_ally_id()
	if bool(adef.get("requires_ranged_tool", false)):
		var rprof: Dictionary = GameState.get_ranged_combat_profile(actor_id)
		if not bool(rprof.get("has_ranged", false)):
			return []
	var ap: Vector2i = get_entity_grid_pos("ally", actor_id)
	var rng: Dictionary = get_action_range(action_id)
	var min_r: int = int(rng.get("min", 0))
	var max_r: int = int(rng.get("max", 0))
	var is_charge_m: bool = (str(adef.get("movement_mode", "")) == "charge")
	var out: Array[String] = []
	for e in enemies:
		if bool(e.get("defeated", false)):
			continue
		var eid: String = str(e.get("id", ""))
		var ep: Vector2i = Vector2i(int(e.get("grid_x", 4)), int(e.get("grid_y", 2)))
		var d: int = grid_distance(ap.x, ap.y, ep.x, ep.y)
		if max_r > 0 and (d < min_r or d > max_r):
			continue
		if is_charge_m:
			var land: Vector2i = find_closest_adjacent_cell(ap.x, ap.y, ep.x, ep.y, "ally", actor_id)
			if land.x < 0:
				continue
		out.append(eid)
	return out

func _resolve_encounter_base_actions(enc: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids_var: Variant = enc.get("player_action_ids", [])
	if ids_var is Array and not (ids_var as Array).is_empty():
		for id_v in (ids_var as Array):
			var aid: String = str(id_v)
			var adef: Dictionary = DataLoader.get_combat_action_def(aid)
			if not adef.is_empty():
				out.append(adef)
		return out
	var legacy_var: Variant = enc.get("player_actions", [])
	if legacy_var is Array:
		for av in (legacy_var as Array):
			if av is Dictionary:
				var ad: Dictionary = av as Dictionary
				var laid: String = str(ad.get("id", ""))
				var ldef: Dictionary = DataLoader.get_combat_action_def(laid)
				out.append(ldef if not ldef.is_empty() else ad)
	return out

## Retourne la liste ordonnée des actions disponibles pour le membre au cran 0 (base + équipement ★ + échappée).
func get_available_actions_for_actor() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not active:
		return out
	var actor: Dictionary = get_acting_ally()
	var actor_id: String = str(actor.get("char_id", ""))
	if actor_id == "":
		actor_id = _peek_next_present_ally_id()
	var rprof: Dictionary = GameState.get_ranged_combat_profile(actor_id)
	var has_ranged: bool = bool(rprof.get("has_ranged", false))

	var enc: Dictionary = DataLoader.get_encounter(encounter_id)
	for ad in _resolve_encounter_base_actions(enc):
		var aid: String = str(ad.get("id", ""))
		var pv: Dictionary = _build_action_preview(aid, actor_id)
		var rng: Dictionary = get_action_range(aid)
		var min_r: int = int(rng.get("min", 0))
		var max_r: int = int(rng.get("max", 0))
		var r_tag: String = format_range_tag(min_r, max_r)
		var valid_targets: Array[String] = get_valid_target_ids_for_action(aid)
		var tk: String = get_action_target_kind(aid)
		var req_tool: bool = bool(ad.get("requires_ranged_tool", false))
		var usable: bool = true
		var lock_reason: String = ""
		if req_tool and not has_ranged:
			usable = false
			lock_reason = str(ad.get("missing_tool_reason", "Outil tir requis"))
		elif tk == "enemy" and valid_targets.is_empty():
			usable = false
			lock_reason = "Hors portée (%s)" % r_tag if action_has_alive_enemies() else "Aucune cible"
		var slbl: String = str(ad.get("label", str(ad.get("short_label", aid))))
		if req_tool and has_ranged and str(rprof.get("ranged_label", "")) != "":
			slbl = "%s (%s)" % [slbl, str(rprof.get("ranged_label", ""))]
		out.append({
			"id": aid,
			"short_label": slbl,
			"chance_pct": int(pv.get("chance_pct", 0)),
			"is_flaw": bool(pv.get("is_flaw", false)),
			"is_equipment": false,
			"used": false,
			"min_range": min_r,
			"max_range": max_r,
			"range_label": r_tag,
			"in_range_count": valid_targets.size(),
			"usable": usable,
			"locked_reason": lock_reason,
			"tooltip": "%s\nPortée : %s\n%s%s" % [
				str(ad.get("desc", "")),
				r_tag,
				str(pv.get("roll_formula", "")),
				("\n🔒 " + lock_reason) if lock_reason != "" else ""
			]
		})

	for eq_act in GameState.get_unlocked_equipment_actions(actor_id):
		var eq_id: String = str(eq_act.get("id", ""))
		var eq_def: Dictionary = DataLoader.get_combat_action_def(eq_id)
		if eq_def.is_empty():
			continue
		var pv_eq: Dictionary = _build_action_preview(eq_id, actor_id)
		var u_key: String = "%s:%s" % [actor_id, eq_id]
		var is_used: bool = bool(_used_equip_actions.get(u_key, false))
		var rng_e: Dictionary = get_action_range(eq_id)
		var min_re: int = int(rng_e.get("min", 0))
		var max_re: int = int(rng_e.get("max", 0))
		var r_tage: String = format_range_tag(min_re, max_re)
		var tke: String = get_action_target_kind(eq_id)
		var vtgts_e: Array[String] = get_valid_target_ids_for_action(eq_id)
		var eq_usable: bool = (not is_used) and (tke != "enemy" or not vtgts_e.is_empty())
		var eq_lock: String = "Déjà utilisé" if is_used else ("Hors portée (%s)" % r_tage if (tke == "enemy" and vtgts_e.is_empty()) else "")
		out.append({
			"id": eq_id,
			"short_label": str(eq_def.get("short_label", eq_act.get("label", eq_id))),
			"chance_pct": int(pv_eq.get("chance_pct", 0)),
			"is_flaw": bool(pv_eq.get("is_flaw", false)),
			"is_equipment": true,
			"used": is_used,
			"min_range": min_re,
			"max_range": max_re,
			"range_label": r_tage,
			"in_range_count": vtgts_e.size(),
			"usable": eq_usable,
			"locked_reason": eq_lock,
			"tooltip": "%s\nPortée : %s\n%s" % [str(eq_act.get("desc", str(eq_def.get("desc", "")))), r_tage, str(pv_eq.get("roll_formula", ""))]
		})

	if can_escape_now():
		out.append({
			"id": "act_escape_now",
			"short_label": str(_escape_cfg.get("action_label", "Filer !")),
			"chance_pct": 0,
			"is_flaw": false,
			"is_equipment": false,
			"used": false,
			"min_range": 0,
			"max_range": 0,
			"range_label": "∞",
			"in_range_count": 0,
			"usable": true,
			"locked_reason": "",
			"tooltip": str(_escape_cfg.get("summary", "Repli immédiat de toute la bande."))
		})
	return out

func action_has_alive_enemies() -> bool:
	for e in enemies:
		if not bool(e.get("defeated", false)):
			return true
	return false

## Prévisualisation en lecture seule d'une action tactique sur la cible active et le rail.
func preview_player_action(action_id: String) -> Dictionary:
	if not active:
		return {"valid": false, "reason": "Hors confrontation"}
	var acting: Dictionary = get_acting_ally()
	if awaiting_step or acting.is_empty():
		return {"valid": false, "reason": "Appuie d'abord sur Espace pour résoudre le beat en attente."}
	return _build_action_preview(action_id, str(acting.get("char_id", DataLoader.get_leader_char_id())))

## Calcule en lecture seule le résultat prévisionnel d'une action tactique ou d'équipement depuis sa définition JSON.
func _build_action_preview(action_id: String, actor_id: String) -> Dictionary:
	if action_id == "act_escape_now":
		var can_esc: bool = can_escape_now()
		return {
			"valid": can_esc,
			"kind": "action",
			"title": str(_escape_cfg.get("action_title", "Repli immédiat")),
			"target_id": str(_escalation_cfg.get("id", "crs")),
			"target_name": str(_escape_cfg.get("target_name", "Sortie")),
			"from_tick": 0,
			"to_tick": 0,
			"resolve_delta": 0,
			"crs_delta": 0,
			"escape_delta": 0,
			"shield_delta": 0,
			"moral_delta": 0,
			"counter_warning": false,
			"counter_label": "",
			"chance_pct": 0,
			"skill_id": "",
			"skill_name": "",
			"skill_val": 0,
			"dc": 0,
			"bonus": 0,
			"bonus_label": "",
			"is_flaw": false,
			"roll_formula": "",
			"fail_summary": "",
			"is_equipment": false,
			"used": false,
			"reason": "Échappée non ouverte" if not can_esc else "",
			"summary": str(_escape_cfg.get("summary", "Repli immédiat de toute la bande"))
		}

	var adef: Dictionary = DataLoader.get_combat_action_def(action_id)
	if adef.is_empty():
		return {"valid": false, "reason": "Action inconnue"}

	var is_eq: bool = bool(adef.get("is_equipment", false))
	if is_eq and not GameState.has_equipped_action(actor_id, action_id):
		return {"valid": false, "reason": "Équipement non porté par le membre actif", "is_equipment": true}
	var u_key: String = "%s:%s" % [actor_id, action_id]
	if bool(adef.get("once_per_encounter", is_eq)) and bool(_used_equip_actions.get(u_key, false)):
		return {"valid": false, "reason": "Action déjà utilisée dans cette confrontation", "used": true, "is_equipment": is_eq}

	var tk: String = get_action_target_kind(action_id)
	var target: Dictionary = _peek_selected_target() if tk == "enemy" else {}
	if tk == "enemy" and target.is_empty():
		return {"valid": false, "reason": "Aucune cible active."}

	var rc: Dictionary = _eval_range_check(action_id, actor_id, target) if tk == "enemy" else {
		"in_range": true, "lock_reason": "", "min_range": 0, "max_range": 0, "distance": 0, "out_of_range": false, "landing_cell": Vector2i(-1, -1)
	}
	var prm: Dictionary = _compute_action_roll_params(adef, actor_id, target)
	var req_tool: bool = bool(adef.get("requires_ranged_tool", false))
	var has_tool: bool = bool(prm.get("has_ranged_tool", false))
	var skill_id: String = str(prm.get("skill_id", "tchatche"))
	var dc: int = int(prm.get("dc", 10))
	var bonus: int = int(prm.get("bonus", 0))
	var blbl: String = str(prm.get("bonus_label", ""))
	var tool_lbl: String = str(prm.get("tool_label", ""))

	var rp: Dictionary = GameState.preview_street_roll(actor_id, skill_id, dc, bonus, blbl)
	var is_fl: bool = bool(rp.get("is_flaw", false))

	var on_succ_v: Variant = adef.get("on_success", {})
	var on_succ: Dictionary = on_succ_v as Dictionary if on_succ_v is Dictionary else {}
	var on_fail_v: Variant = adef.get("on_flaw" if (is_fl and adef.has("on_flaw")) else "on_fail", {})
	var on_fail: Dictionary = on_fail_v as Dictionary if on_fail_v is Dictionary else {}
	var sim: Dictionary = _simulate_effect_bricks(on_succ.get("effects", []), bonus, false)

	var is_charge_m: bool = (str(adef.get("movement_mode", "")) == "charge")
	var land_c: Vector2i = rc.get("landing_cell", Vector2i(-1, -1)) as Vector2i
	var valid: bool = bool(rc.get("in_range", true)) and (not req_tool or has_tool) and (not is_charge_m or land_c.x >= 0)
	var reason: String = str(adef.get("missing_tool_reason", "Outil requis")) if (req_tool and not has_tool) else str(rc.get("lock_reason", ""))

	var tid: String = ""
	var tname: String = ""
	var from_t: int = 0
	var to_t: int = 0
	if tk == "enemy":
		tid = str(target.get("id", ""))
		tname = str(target.get("name", ""))
		from_t = int(target.get("next_tick", 0))
		to_t = from_t + int(sim.get("push_delta", 0))
	elif tk == "ally":
		var low_id: String = _get_lowest_moral_present_ally_id(actor_id)
		tid = low_id
		tname = str(DataLoader.get_character(low_id).get("name", low_id))
	elif str(adef.get("preview_target_id", "")) == "crs" or int(sim.get("crs_delta", 0)) != 0:
		tid = str(_escalation_cfg.get("id", "crs"))
		tname = str(_escalation_cfg.get("label", "Escalade"))
		from_t = crs_ticks
		to_t = crs_ticks + int(sim.get("crs_delta", 0))
	else:
		tid = actor_id
		tname = str(DataLoader.get_character(actor_id).get("name", actor_id))

	var fail_sum: String = str(on_fail.get("preview_fail", "Effet réduit"))
	var parts: Array[String] = []
	if is_charge_m and land_c.x >= 0:
		parts.append("Saute en (%d,%d)" % [land_c.x, land_c.y])
	if int(sim.get("resolve_delta", 0)) != 0:
		parts.append("%s %d Résol." % [tname, int(sim.get("resolve_delta", 0))])
	if int(sim.get("push_delta", 0)) > 0:
		parts.append("Cran %d→%d" % [from_t, to_t])
	if bool(sim.get("cuts_counter", false)):
		parts.append("coupe Contre")
	if int(sim.get("crs_delta", 0)) != 0:
		parts.append("%s %+d" % [get_escalation_short_label(), int(sim.get("crs_delta", 0))])
	if int(sim.get("escape_delta", 0)) > 0:
		parts.append("Échappée +%d" % int(sim.get("escape_delta", 0)))
	if int(sim.get("shield_delta", 0)) > 0:
		parts.append("Bouclier +%d" % int(sim.get("shield_delta", 0)))
	if int(sim.get("moral_delta", 0)) != 0:
		parts.append("%+d Moral" % int(sim.get("moral_delta", 0)))
	if bool(sim.get("delays_crisis", false)):
		parts.append("retarde crise")
	var base_sum: String = " · ".join(parts) if not parts.is_empty() else str(adef.get("title", action_id))
	var full_sum: String = "%s (raté : %s)" % [base_sum, fail_sum]

	var tgt_intercept: bool = is_charge_m and not target.is_empty() and bool(target.get("counter_ready", false)) and not bool(target.get("stunned", false))
	var int_lbl: String = "Interception adverse prête : risque d'être ASSOMMÉ (-2 rangs) !" if tgt_intercept else ""
	var raw_title: String = str(adef.get("title", str(adef.get("label", action_id))))
	var final_title: String = raw_title.replace("{tool}", tool_lbl if tool_lbl != "" else "Outil")

	return {
		"valid": valid,
		"reason": reason,
		"kind": "action",
		"title": final_title,
		"target_id": tid,
		"target_name": tname,
		"from_tick": from_t,
		"to_tick": to_t,
		"resolve_delta": int(sim.get("resolve_delta", 0)),
		"crs_delta": int(sim.get("crs_delta", 0)),
		"escape_delta": int(sim.get("escape_delta", 0)),
		"shield_delta": int(sim.get("shield_delta", 0)),
		"moral_delta": int(sim.get("moral_delta", 0)),
		"counter_warning": tgt_intercept,
		"counter_label": int_lbl,
		"chance_pct": int(rp.get("chance_pct", 50)),
		"skill_id": skill_id,
		"skill_name": str(rp.get("skill_name", skill_id)),
		"skill_val": int(rp.get("skill_val", 0)),
		"dc": dc,
		"bonus": bonus,
		"bonus_label": blbl,
		"tool_label": tool_lbl,
		"is_flaw": is_fl,
		"roll_formula": str(rp.get("formula", "")),
		"fail_summary": fail_sum,
		"is_equipment": is_eq,
		"used": false,
		"requires_ranged_tool": req_tool,
		"has_ranged_tool": has_tool,
		"min_range": int(rc.get("min_range", 0)),
		"max_range": int(rc.get("max_range", 0)),
		"distance": int(rc.get("distance", 0)),
		"out_of_range": bool(rc.get("out_of_range", false)),
		"landing_cell": land_c,
		"summary": full_sum
	}

## Prévisualisation en lecture seule d'une Interruption hors-tour depuis rules/specialties.json.
func preview_interruption(char_id: String) -> Dictionary:
	if not active:
		return {"valid": false, "reason": "Hors confrontation"}
	var ally: Dictionary = _find_ally(char_id)
	if ally.is_empty() or not bool(ally.get("present", false)):
		return {"valid": false, "reason": "Allié absent de la scène"}
	if not bool(ally.get("reaction_ready", false)):
		return {"valid": false, "reason": "Réaction déjà utilisée ce cycle"}

	var spec_id: String = str(ally.get("specialty_id", ""))
	var spec_def: Dictionary = DataLoader.get_specialty_def(spec_id)
	var mode: Dictionary = _select_specialty_mode(spec_def)
	if mode.is_empty():
		return {"valid": false, "reason": "Spécialité sans interruption"}

	var counter_warn: bool = false
	var counter_lbl: String = ""
	for e in enemies:
		if not bool(e.get("defeated", false)) and not bool(e.get("stunned", false)) and bool(e.get("counter_ready", false)):
			counter_warn = true
			counter_lbl = str(e.get("counter_label", "Contre-interruption prête (-6 Moral)"))
			break

	var cname: String = str(ally.get("name", char_id))
	var m_tk: String = str(mode.get("target_kind", "none"))
	var target: Dictionary = _peek_selected_target() if m_tk == "enemy" else {}
	if m_tk == "enemy" and target.is_empty():
		return {"valid": false, "reason": "Aucune cible active"}

	var sc_info: Dictionary = _eval_specialty_scaling(char_id, mode)
	var scaled_ok: bool = bool(sc_info.get("scaled_active", false))
	var abs_val: int = int(sc_info.get("absorb", 6))
	var sim: Dictionary = _simulate_effect_bricks(mode.get("effects", []), 0, scaled_ok)

	var tid: String = char_id
	var tname: String = cname
	var from_t: int = 0
	var to_t: int = 0
	if m_tk == "enemy":
		tid = str(target.get("id", ""))
		tname = str(target.get("name", ""))
		from_t = int(target.get("next_tick", 1))
		to_t = from_t + int(sim.get("push_delta", 0))
	elif m_tk == "ally_crisis" and not crisis_queue.is_empty():
		var cr: Dictionary = crisis_queue[0]
		tid = str(cr.get("char_id", ""))
		tname = str(DataLoader.get_character(tid).get("name", tid))
		from_t = int(cr.get("ticks_left", 0))
		to_t = 0
	elif str(mode.get("preview_target_id", "")) == "crs" or int(sim.get("crs_delta", 0)) != 0:
		tid = str(_escalation_cfg.get("id", "crs"))
		tname = str(_escalation_cfg.get("label", "Escalade"))
		from_t = crs_ticks
		to_t = crs_ticks + int(sim.get("crs_delta", 0))

	var ctx: Dictionary = {
		"actor": cname,
		"target": tname,
		"dmg": absi(int(sim.get("resolve_delta", 0))),
		"push": int(sim.get("push_delta", 0)),
		"clock": int(sim.get("crs_delta", 0)),
		"moral": int(sim.get("moral_delta", 0)),
		"absorb": abs_val,
		"from_tick": from_t,
		"to_tick": to_t
	}
	var sum_txt: String = _format_combat_log(str(mode.get("preview_summary", "")), ctx)

	return {
		"valid": true,
		"kind": "interruption",
		"title": "%s — %s" % [cname, str(spec_def.get("name", spec_id))],
		"target_id": tid,
		"target_name": tname,
		"from_tick": from_t,
		"to_tick": to_t,
		"resolve_delta": int(sim.get("resolve_delta", 0)),
		"crs_delta": int(sim.get("crs_delta", 0)),
		"escape_delta": int(sim.get("escape_delta", 0)),
		"shield_delta": int(sim.get("shield_delta", 0)),
		"moral_delta": int(sim.get("moral_delta", 0)),
		"counter_warning": counter_warn,
		"counter_label": counter_lbl,
		"summary": sum_txt
	}

## Prévisualisation en lecture seule du bouton Retenir une Crise d'autonomie.
func preview_restrain(crisis_char_id: String) -> Dictionary:
	var rescuer: Dictionary = _find_rescuer_for(crisis_char_id)
	var cr_name: String = str(DataLoader.get_character(crisis_char_id).get("name", crisis_char_id))
	if rescuer.is_empty():
		return {"valid": false, "reason": "Aucun camarade avec Réaction disponible pour retenir %s." % cr_name}
	var r_name: String = str(rescuer.get("name", ""))
	return {
		"valid": true,
		"kind": "restrain",
		"title": "Retenir %s" % cr_name,
		"target_id": crisis_char_id,
		"target_name": cr_name,
		"from_tick": 0,
		"to_tick": 0,
		"resolve_delta": 0,
		"crs_delta": 0,
		"escape_delta": 0,
		"shield_delta": 0,
		"moral_delta": 8,
		"counter_warning": false,
		"counter_label": "",
		"summary": "%s dépense sa Réaction : calme %s (+8 Moral, crise annulée)" % [r_name, cr_name]
	}

## Retourne la liste ordonnée des fiches unifiées de la Frise (alliés + crises intégrées, renforts, ennemis, horloge).
func get_ordered_rail_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var acting: Dictionary = get_acting_ally()
	var acting_id: String = str(acting.get("char_id", ""))
	var charging_eid: String = str(pending_enemy_charge.get("enemy_id", "")) if is_charge_window_active() else ""
	var crisis_map: Dictionary = {}
	for cr in crisis_queue:
		crisis_map[str(cr.get("char_id", ""))] = cr

	for a in allies:
		var cid: String = str(a.get("char_id", ""))
		var cdef: Dictionary = DataLoader.get_character(cid)
		var st: Dictionary = GameState.get_member_state(cid)
		var portrait_p: String = str(cdef.get("portrait", ""))
		var att_val: int = GameState.get_effective_attitude_for(cid)
		var aura_val: int = GameState.get_effective_aura_for(cid)
		var moral_val: int = int(st.get("moral", 60))
		var moral_max_val: int = GameState.get_effective_moral_max(cid)
		var stress_thr: int = GameState.get_effective_stress_threshold(cid)
		if bool(a.get("present", false)):
			var nt: int = int(a.get("next_tick", 0))
			var r_ready: bool = bool(a.get("reaction_ready", false))
			var is_stun: bool = bool(a.get("stunned", false))
			var sp_name: String = str(a.get("specialty_name", ""))
			var in_crisis: bool = crisis_map.has(cid)
			var cr_ticks: int = -1
			var cr_label: String = ""
			if in_crisis:
				var cr_d: Dictionary = crisis_map[cid] as Dictionary
				cr_ticks = int(cr_d.get("ticks_left", 1))
				cr_label = str(cr_d.get("label", "Crise d'autonomie"))
			var is_acting_now: bool = (cid == acting_id and not awaiting_step) or (not _pending_crisis_ids.is_empty() and _pending_crisis_ids[0] == cid)
			var eff_tick: int = mini(nt, cr_ticks) if in_crisis else nt
			var s_rank: int = 0 if is_acting_now else (1 if in_crisis else 2)
			var sub_lbl: String = "💫 Assommé" if is_stun else ("Prêt" if (nt == 0 and cid == acting_id) else ("Réact." if r_ready else ""))
			entries.append({
				"kind": "ally",
				"id": cid,
				"label": str(a.get("name", "")).split(" ")[0],
				"tick": eff_tick,
				"turn_tick": nt,
				"color": str(a.get("color_hex", "#f28c28")),
				"sub": sub_lbl,
				"portrait": portrait_p,
				"acting": is_acting_now,
				"stunned": is_stun,
				"grid_x": int(a.get("grid_x", 3)),
				"grid_y": int(a.get("grid_y", 6)),
				"move_points_left": int(a.get("move_points_left", 0)),
				"move_points_max": int(a.get("move_points_max", 2)),
				"intent": sp_name,
				"counter_ready": false,
				"selected": false,
				"attitude": att_val,
				"aura": aura_val,
				"moral": moral_val,
				"moral_max": moral_max_val,
				"stress_threshold": stress_thr,
				"reaction_ready": r_ready,
				"specialty_name": sp_name,
				"in_crisis": in_crisis,
				"crisis_ticks": cr_ticks,
				"crisis_label": cr_label,
				"sort_rank": s_rank
			})
		else:
			entries.append({
				"kind": "reinforcement",
				"id": cid,
				"label": "Renfort " + str(a.get("name", "")).split(" ")[0],
				"tick": int(a.get("reinforce_in_ticks", 2)),
				"color": "#7ec4cf",
				"sub": "En route",
				"portrait": portrait_p,
				"acting": false,
				"intent": "En approche",
				"counter_ready": false,
				"selected": false,
				"attitude": att_val,
				"aura": aura_val,
				"moral": moral_val,
				"moral_max": moral_max_val,
				"sort_rank": 4
			})
	for e in enemies:
		if not bool(e.get("defeated", false)):
			var eid: String = str(e.get("id", ""))
			var is_e_acting: bool = (eid == charging_eid) or (not _pending_enemy_ids.is_empty() and _pending_enemy_ids[0] == eid)
			var is_e_stun: bool = bool(e.get("stunned", false))
			var e_res: int = int(e.get("resolve", 1))
			var e_res_max: int = int(e.get("resolve_max", 1))
			entries.append({
				"kind": "enemy",
				"id": eid,
				"label": str(e.get("name", "")),
				"tick": int(e.get("next_tick", 1)),
				"color": "#d92b2b",
				"sub": "💫 Assommé" if is_e_stun else ("Rés.%d/%d" % [e_res, e_res_max]),
				"portrait": str(e.get("portrait", "res://assets/portraits/so_agent.png")),
				"acting": is_e_acting,
				"stunned": is_e_stun,
				"is_charging": eid == charging_eid,
				"grid_x": int(e.get("grid_x", 4)),
				"grid_y": int(e.get("grid_y", 2)),
				"intent": str(e.get("intent_label", "")),
				"counter_ready": bool(e.get("counter_ready", false)) and not is_e_stun,
				"counter_label": str(e.get("counter_label", "")),
				"resolve": e_res,
				"resolve_max": e_res_max,
				"role": str(e.get("role", "")),
				"selected": (eid == selected_target_id),
				"sort_rank": 0 if is_e_acting else 3
			})
	if is_escalation_enabled():
		entries.append({
			"kind": "crs",
			"id": str(_escalation_cfg.get("id", "crs")),
			"label": str(_escalation_cfg.get("label", "Patrouille")),
			"tick": maxi(0, crs_ticks),
			"clock_max": maxi(6, int(_escalation_cfg.get("start_ticks", 6))),
			"color": str(_escalation_cfg.get("color", "#3d85ff")),
			"sub": str(_escalation_cfg.get("sub", "Urgence")),
			"portrait": str(_escalation_cfg.get("portrait", "")),
			"acting": false,
			"intent": str(_escalation_cfg.get("intent", "")),
			"counter_ready": false,
			"selected": false,
			"sort_rank": 5
		})
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var tx: int = int(x.get("tick", 0))
		var ty: int = int(y.get("tick", 0))
		if tx != ty:
			return tx < ty
		return int(x.get("sort_rank", 9)) < int(y.get("sort_rank", 9))
	)
	return entries

func _advance_one_world_tick() -> void:
	turn_count += 1
	if is_escalation_enabled():
		crs_ticks -= 1

	# Renforts qui arrivent & récupération PM / réveil au cran 0
	for a in allies:
		var cid_a: String = str(a.get("char_id", ""))
		if not bool(a.get("present", false)):
			var rt: int = int(a.get("reinforce_in_ticks", 1)) - 1
			a["reinforce_in_ticks"] = rt
			if rt <= 0:
				var sp_pos: Vector2i = _find_first_free_ally_spawn_cell()
				var mp_m: int = compute_ally_move_points(cid_a)
				a["present"] = true
				a["next_tick"] = 0
				a["reaction_ready"] = true
				a["stunned"] = false
				a["grid_x"] = sp_pos.x
				a["grid_y"] = sp_pos.y
				a["move_points_max"] = mp_m
				a["move_points_left"] = mp_m
				var r_msg: String = "RENFORT ! %s rejoint la scène à temps pour couvrir la bande !" % str(a.get("name", ""))
				_push_log(r_msg)
				_emit_feedback("reinforcement", cid_a, str(a.get("name", "")), r_msg, false)
		else:
			var old_nt: int = int(a.get("next_tick", 1))
			var new_nt: int = maxi(0, old_nt - 1)
			a["next_tick"] = new_nt
			if old_nt > 0 and new_nt == 0:
				a["stunned"] = false
				var mp_m2: int = compute_ally_move_points(cid_a)
				a["move_points_max"] = mp_m2
				a["move_points_left"] = mp_m2

	# Crises d'autonomie en préavis
	for i in range(crisis_queue.size()):
		var cr: Dictionary = crisis_queue[i]
		var tl: int = maxi(0, int(cr.get("ticks_left", 1)) - 1)
		cr["ticks_left"] = tl
		crisis_queue[i] = cr
		if tl <= 0:
			var cr_cid: String = str(cr.get("char_id", ""))
			if not _pending_crisis_ids.has(cr_cid):
				_pending_crisis_ids.append(cr_cid)

	# Ennemis avancent et s'inscrivent en file pas-à-pas à 0
	for e in enemies:
		if bool(e.get("defeated", false)):
			continue
		var nt: int = maxi(0, int(e.get("next_tick", 1)) - 1)
		e["next_tick"] = nt
		if nt <= 0:
			var eid: String = str(e.get("id", ""))
			if not _pending_enemy_ids.has(eid):
				_pending_enemy_ids.append(eid)

	_check_timed_events()

	if is_escalation_enabled() and crs_ticks <= 0:
		var exp_ctx: Dictionary = {
			"actor_id": "",
			"is_brilliant": false,
			"is_crit_success": false,
			"roll_bonus": 0,
			"scaled_active": false
		}
		_execute_effect_bricks(_escalation_cfg.get("expire_effects", []), exp_ctx)
		var exp_out: String = str(_escalation_cfg.get("expire_outcome", "clock_expired"))
		var exp_sum: String = str(_escalation_cfg.get("expire_summary", "Le temps est écoulé : repli forcé !"))
		_finish(exp_out, exp_sum)
		return

## Vérifie et déclenche les événements programmés définis dans timed_events[] de la rencontre JSON.
func _check_timed_events() -> void:
	for te in _timed_events:
		var te_id: String = str(te.get("id", "timed_ev"))
		if _fired_timed_events.has(te_id):
			continue
		var req_t: int = int(te.get("trigger_turn_ticks", 6))
		if turn_count >= req_t:
			_fired_timed_events[te_id] = true
			if bool(te.get("unlocks_escape", false)):
				_escape_unlocked_by_event = true
				train_fantome_arrived = true
			var te_ctx: Dictionary = {
				"actor_id": "",
				"is_brilliant": false,
				"is_crit_success": false,
				"roll_bonus": 0,
				"scaled_active": false
			}
			_execute_effect_bricks(te.get("effects", []), te_ctx)
			var te_log: String = str(te.get("log", ""))
			if te_log != "":
				_push_log(te_log)
			_emit_feedback(te_id, te_id, str(te.get("title", "Événement")), te_log, bool(te.get("shake", true)))
			var fx_id: String = str(te.get("stage_fx", ""))
			if fx_id != "":
				stage_fx_triggered.emit(fx_id)
				if fx_id == "passing_train":
					train_fantome_arrived_sig.emit()

func _execute_enemy_turn(enemy: Dictionary) -> void:
	enemy["stunned"] = false
	var eid: String = str(enemy.get("id", ""))
	var ename: String = str(enemy.get("name", eid))
	var bark: String = str(enemy.get("bark", ""))
	var ex: int = int(enemy.get("grid_x", 4))
	var ey: int = int(enemy.get("grid_y", 2))
	var tgt_ally: Dictionary = _pick_closest_present_ally(ex, ey)
	if tgt_ally.is_empty():
		enemy["next_tick"] = int(enemy.get("speed", 2))
		return
	var target_aid: String = str(tgt_ally.get("char_id", DataLoader.get_leader_char_id()))
	var target_aname: String = str(tgt_ally.get("name", target_aid))
	var ax: int = int(tgt_ally.get("grid_x", 3))
	var ay: int = int(tgt_ally.get("grid_y", 6))
	var dist: int = grid_distance(ex, ey, ax, ay)

	if dist <= 1:
		_apply_enemy_attack_hit(eid, enemy, target_aid, target_aname, false)
		enemy["next_tick"] = int(enemy.get("speed", 2))
		var line_m: String = bark if bark != "" else ("%s frappe au contact sur %s !" % [ename, target_aname])
		_emit_feedback("enemy", eid, ename, line_m, true)
		return

	if dist >= 2 and dist <= 5 and bool(enemy.get("can_charge", true)):
		var landing: Vector2i = find_closest_adjacent_cell(ex, ey, ax, ay, "enemy", eid)
		if landing.x >= 0:
			pending_enemy_charge = {
				"enemy_id": eid,
				"enemy_name": ename,
				"target_ally_id": target_aid,
				"target_ally_name": target_aname,
				"from_x": ex,
				"from_y": ey,
				"to_x": landing.x,
				"to_y": landing.y,
				"target_x": ax,
				"target_y": ay,
				"time_left": CHARGE_WINDOW_SECONDS,
				"time_max": CHARGE_WINDOW_SECONDS,
				"attempted_allies": []
			}
			var alert_msg: String = "⚡ ALERTE CHARGE (10 s) ! %s fonce vers %s (%d,%d) — déclenche une Interception depuis un PJ !" % [ename, target_aname, landing.x, landing.y]
			_push_log(alert_msg)
			AudioRadio.play_charge_alert()
			_sync_step_state()
			_emit_feedback("charge_alert", eid, ename, alert_msg, true)
			charge_window_started.emit(pending_enemy_charge.duplicate(true))
			timeline_updated.emit()
			return

	var mp_e: int = maxi(1, int(enemy.get("move_points", 2)))
	var moved_e: bool = _move_enemy_toward(enemy, ax, ay, mp_e)
	var new_dist: int = grid_distance(int(enemy.get("grid_x", ex)), int(enemy.get("grid_y", ey)), ax, ay)
	if moved_e:
		_push_log("%s avance sur (%d, %d) face à %s (dist. %dc)." % [ename, int(enemy.get("grid_x", ex)), int(enemy.get("grid_y", ey)), target_aname, new_dist])
	_apply_enemy_attack_hit(eid, enemy, target_aid, target_aname, false)
	enemy["next_tick"] = int(enemy.get("speed", 2))
	var line_msg: String = bark if bark != "" else ("%s passe à l'offensive !" % ename)
	_emit_feedback("enemy", eid, ename, line_msg, true)

func _pick_closest_present_ally(ex: int, ey: int) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = 999999
	for a in allies:
		if not bool(a.get("present", false)):
			continue
		var ax: int = int(a.get("grid_x", 3))
		var ay: int = int(a.get("grid_y", 6))
		var d: int = grid_distance(ex, ey, ax, ay)
		var cid: String = str(a.get("char_id", ""))
		var moral_v: int = int(GameState.get_member_state(cid).get("moral", 60))
		var score: int = d * 1000 + moral_v
		if score < best_score:
			best_score = score
			best = a
	return best

func _pick_secondary_present_ally_id(exclude_cid: String) -> String:
	for a in allies:
		if bool(a.get("present", false)):
			var cid: String = str(a.get("char_id", ""))
			if cid != exclude_cid:
				return cid
	return exclude_cid

func _move_enemy_toward(enemy: Dictionary, target_x: int, target_y: int, max_steps: int) -> bool:
	var eid: String = str(enemy.get("id", ""))
	var cur_x: int = int(enemy.get("grid_x", 4))
	var cur_y: int = int(enemy.get("grid_y", 2))
	var moved_any: bool = false
	for _s in range(max_steps):
		if grid_distance(cur_x, cur_y, target_x, target_y) <= 1:
			break
		var best_x: int = cur_x
		var best_y: int = cur_y
		var best_md: int = absi(cur_x - target_x) + absi(cur_y - target_y)
		for dv in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			var nx: int = cur_x + dv.x
			var ny: int = cur_y + dv.y
			if not is_combat_cell_walkable(nx, ny, "enemy", eid):
				continue
			var md: int = absi(nx - target_x) + absi(ny - target_y)
			if md < best_md:
				best_md = md
				best_x = nx
				best_y = ny
		if best_x == cur_x and best_y == cur_y:
			break
		cur_x = best_x
		cur_y = best_y
		moved_any = true
	enemy["grid_x"] = cur_x
	enemy["grid_y"] = cur_y
	return moved_any

func _apply_enemy_attack_hit(eid: String, enemy: Dictionary, target_aid: String, target_aname: String, is_charge: bool) -> void:
	var ename: String = str(enemy.get("name", eid))
	var e_hook: String = str(enemy.get("custom_script", ""))
	if e_hook != "":
		_invoke_custom_hook(e_hook, "execute_enemy_attack", {
			"enemy": enemy,
			"target_ally_id": target_aid,
			"target_ally_name": target_aname,
			"is_charge": is_charge
		})
		return

	var atk_key: String = "charge_attack" if is_charge else "melee_attack"
	var atk_v: Variant = enemy.get(atk_key, {})
	if atk_v is Dictionary and not (atk_v as Dictionary).is_empty():
		var atk: Dictionary = atk_v as Dictionary
		var ctx: Dictionary = {
			"enemy": ename,
			"target": target_aname,
			"source_enemy": enemy,
			"enemy_target_ally_id": target_aid,
			"actor_id": "",
			"is_brilliant": false,
			"is_crit_success": false,
			"roll_bonus": 0,
			"scaled_active": false
		}
		var atk_log: String = _format_combat_log(str(atk.get("log", "")), ctx)
		if atk_log != "":
			_push_log(atk_log)
		_execute_effect_bricks(atk.get("effects", []), ctx)
	else:
		_apply_moral_hit(target_aid, -7 if is_charge else -5)

func _get_ally_charge_intercept_params(char_id: String, enemy: Dictionary) -> Dictionary:
	var ally: Dictionary = _find_ally(char_id)
	var spec_id: String = str(ally.get("specialty_id", ""))
	var spec_def: Dictionary = DataLoader.get_specialty_def(spec_id)
	var eid: String = str(enemy.get("id", ""))
	var dc: int = int(enemy.get("dc_pression", 11))

	var sk_id: String = "baston_pression"
	var isk_var: Variant = spec_def.get("intercept_skills", [])
	if isk_var is Array and not (isk_var as Array).is_empty():
		var best_pct: int = -1
		for sk_v in (isk_var as Array):
			var cand_sk: String = str(sk_v)
			if cand_sk == "":
				continue
			var pv_sk: Dictionary = GameState.preview_street_roll(char_id, cand_sk, dc, 0, "")
			var pct_sk: int = int(pv_sk.get("chance_pct", 0))
			if pct_sk > best_pct:
				best_pct = pct_sk
				sk_id = cand_sk

	var tgt_aid: String = str(pending_enemy_charge.get("target_ally_id", ""))
	var dist: int = get_distance_between("ally", char_id, "enemy", eid)
	var bonus: int = 1 if (char_id == tgt_aid or (dist >= 0 and dist <= 3)) else 0
	var blbl: String = "En ligne" if bonus > 0 else ""
	return {
		"skill_id": sk_id,
		"dc": dc,
		"bonus": bonus,
		"bonus_label": blbl,
		"is_target_ally": char_id == tgt_aid,
		"distance": dist
	}

## Retourne la liste des PJ pouvant déclencher une Interception pendant la fenêtre 10 s de Charge PNJ.
func get_charge_interceptor_candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not is_charge_window_active():
		return out
	var eid: String = str(pending_enemy_charge.get("enemy_id", ""))
	var enemy: Dictionary = _find_enemy(eid)
	if enemy.is_empty():
		return out
	var att_var: Variant = pending_enemy_charge.get("attempted_allies", [])
	var attempted: Array = att_var as Array if att_var is Array else []
	for a in allies:
		if not bool(a.get("present", false)) or bool(a.get("stunned", false)) or not bool(a.get("reaction_ready", false)):
			continue
		var cid: String = str(a.get("char_id", ""))
		if attempted.has(cid):
			continue
		var prm: Dictionary = _get_ally_charge_intercept_params(cid, enemy)
		var rp: Dictionary = GameState.preview_street_roll(cid, str(prm.get("skill_id", "baston_pression")), int(prm.get("dc", 11)), int(prm.get("bonus", 0)), str(prm.get("bonus_label", "")))
		out.append({
			"char_id": cid,
			"name": str(a.get("name", cid)).split(" ")[0],
			"skill_id": str(prm.get("skill_id", "")),
			"skill_name": str(rp.get("skill_name", "")),
			"dc": int(prm.get("dc", 11)),
			"bonus": int(prm.get("bonus", 0)),
			"bonus_label": str(prm.get("bonus_label", "")),
			"chance_pct": int(rp.get("chance_pct", 50)),
			"is_flaw": bool(rp.get("is_flaw", false)),
			"is_target_ally": bool(prm.get("is_target_ally", false)),
			"distance": int(prm.get("distance", -1))
		})
	return out

## Tente une Interception depuis un PJ contre le PNJ qui charge pendant la fenêtre de 10 s.
func trigger_charge_interception(ally_id: String) -> Dictionary:
	if not is_charge_window_active():
		return {"executed": false}
	var ally: Dictionary = _find_ally(ally_id)
	if ally.is_empty() or not bool(ally.get("present", false)) or bool(ally.get("stunned", false)) or not bool(ally.get("reaction_ready", false)):
		return {"executed": false}
	var eid: String = str(pending_enemy_charge.get("enemy_id", ""))
	var enemy: Dictionary = _find_enemy(eid)
	if enemy.is_empty():
		pending_enemy_charge.clear()
		_sync_step_state()
		timeline_updated.emit()
		return {"executed": false}
	var att_var: Variant = pending_enemy_charge.get("attempted_allies", [])
	var attempted: Array = att_var as Array if att_var is Array else []
	if attempted.has(ally_id):
		return {"executed": false}

	attempted.append(ally_id)
	pending_enemy_charge["attempted_allies"] = attempted
	ally["reaction_ready"] = false

	var prm: Dictionary = _get_ally_charge_intercept_params(ally_id, enemy)
	var roll_res: Dictionary = GameState.perform_street_roll(
		ally_id,
		str(prm.get("skill_id", "baston_pression")),
		int(prm.get("dc", 11)),
		int(prm.get("bonus", 0)),
		str(prm.get("bonus_label", ""))
	)
	var ok: bool = bool(roll_res.get("success", false))
	var is_bril: bool = bool(roll_res.get("is_brilliant", false))
	var cname: String = str(ally.get("name", ally_id))
	var ename: String = str(enemy.get("name", eid))
	_push_log(str(roll_res.get("roll_summary", "")))

	if ok:
		pending_enemy_charge.clear()
		var pen_ticks: int = int(enemy.get("speed", 2)) + CHARGE_STUN_RANK_PENALTY
		enemy["stunned"] = true
		enemy["counter_ready"] = false
		enemy["next_tick"] = pen_ticks
		if is_bril:
			_damage_enemy(enemy, 1)
		var win_msg: String = "🛑 INTERCEPTION ! %s stoppe la charge de %s : %s est ASSOMMÉ et perd 2 rangs (+%d crans)%s !" % [
			cname, ename, ename, pen_ticks, (" (-1 Résol.)" if is_bril else "")
		]
		_push_log(win_msg)
		AudioRadio.play_interrupt_hit()
		_emit_feedback("interrupt", ally_id, cname, win_msg, true)
		charge_window_ended.emit("intercepted", win_msg)
		if _all_enemies_defeated():
			_finish("social_win", _get_win_summary())
			return {"executed": true, "success": true}
		_ensure_valid_target()
		_check_crisis_triggers()
		_sync_step_state()
		timeline_updated.emit()
		return {"executed": true, "success": true, "summary": win_msg}

	var fail_msg: String = "❌ Interception de %s ratée face à la charge de %s !" % [cname, ename]
	_push_log(fail_msg)
	_emit_feedback("ally_flaw", ally_id, cname, fail_msg, false)
	if get_charge_interceptor_candidates().is_empty():
		resolve_pending_enemy_charge()
	else:
		timeline_updated.emit()
	return {"executed": true, "success": false, "summary": fail_msg}

## Clôt la fenêtre 10 s et fait aboutir la Charge PNJ (impact au corps à corps).
func resolve_pending_enemy_charge() -> void:
	if not is_charge_window_active():
		return
	var ch: Dictionary = pending_enemy_charge.duplicate(true)
	pending_enemy_charge.clear()
	var eid: String = str(ch.get("enemy_id", ""))
	var enemy: Dictionary = _find_enemy(eid)
	if not enemy.is_empty() and not bool(enemy.get("defeated", false)):
		var lx: int = int(ch.get("to_x", int(enemy.get("grid_x", 4))))
		var ly: int = int(ch.get("to_y", int(enemy.get("grid_y", 2))))
		var tgt_aid: String = str(ch.get("target_ally_id", DataLoader.get_leader_char_id()))
		var tgt_aname: String = str(ch.get("target_ally_name", tgt_aid))
		if not is_combat_cell_walkable(lx, ly, "enemy", eid):
			var fb: Vector2i = find_closest_adjacent_cell(int(enemy.get("grid_x", 4)), int(enemy.get("grid_y", 2)), int(ch.get("target_x", 3)), int(ch.get("target_y", 6)), "enemy", eid)
			if fb.x >= 0:
				lx = fb.x
				ly = fb.y
		if is_combat_cell_walkable(lx, ly, "enemy", eid):
			enemy["grid_x"] = lx
			enemy["grid_y"] = ly
		_apply_enemy_attack_hit(eid, enemy, tgt_aid, tgt_aname, true)
		enemy["next_tick"] = int(enemy.get("speed", 2))
		var imp_msg: String = "💥 CHARGE SUBIE : %s bondit sur (%d,%d) et percute %s !" % [str(enemy.get("name", eid)), lx, ly, tgt_aname]
		_push_log(imp_msg)
		AudioRadio.play_interrupt_hit()
		_emit_feedback("enemy", eid, str(enemy.get("name", eid)), imp_msg, true)
		charge_window_ended.emit("impacted", imp_msg)
	_ensure_valid_target()
	_check_crisis_triggers()
	_sync_step_state()
	timeline_updated.emit()

func _apply_moral_hit(char_id: String, delta: int) -> void:
	var final_delta: int = delta
	if final_delta < 0:
		var cov_a: Dictionary = get_entity_cover_info("ally", char_id)
		if bool(cov_a.get("in_cover", false)):
			var cov_abs: int = int(cov_a.get("moral_absorb", 2))
			if cov_abs > 0:
				final_delta = mini(0, final_delta + cov_abs)
				_push_log("🛡️ Couvert (%s) : impact moral réduit de %d !" % [str(cov_a.get("label", "Abri")), cov_abs])
	if interposition_shield > 0 and final_delta < 0:
		final_delta = mini(0, final_delta + _interposition_absorb)
		interposition_shield = maxi(0, interposition_shield - 1)
		if interposition_shield == 0:
			_interposition_absorb = 6
		_push_log("Interposition : l'impact sur le Moral est amorti !")
	GameState.modify_moral(char_id, final_delta)

func _check_crisis_triggers() -> void:
	for a in allies:
		if not bool(a.get("present", false)):
			continue
		var cid: String = str(a.get("char_id", ""))
		var st: Dictionary = GameState.get_member_state(cid)
		var cdef: Dictionary = DataLoader.get_character(cid)
		var moral: int = int(st.get("moral", 60))
		var threshold: int = GameState.get_effective_stress_threshold(cid)
		if moral <= threshold and not _is_in_crisis_queue(cid) and not GameState.has_flag("crisis_done_" + cid):
			GameState.set_flag("crisis_done_" + cid, true)
			crisis_queue.append({
				"char_id": cid,
				"ticks_left": 2,
				"label": str(cdef.get("crisis_label", "Crise d'autonomie"))
			})
			AudioRadio.play_crisis_buzz()
			var p_msg: String = "PRÉAVIS CRISE D'AUTONOMIE (%s) : %s serre les poings (explosion dans 2 crans — utilise 'Retenir' !)" % [str(cdef.get("name", cid)), str(cdef.get("stress_name", "Stress"))]
			_push_log(p_msg)
			_emit_feedback("crisis_warn", cid, str(cdef.get("name", cid)), p_msg, false)

func _execute_autonomous_crisis(cid: String) -> void:
	var cdef: Dictionary = DataLoader.get_character(cid)
	var cname: String = str(cdef.get("name", cid))
	AudioRadio.play_interrupt_hit()
	var target: Dictionary = _ensure_valid_target()
	var cr_cfg_v: Variant = cdef.get("crisis", {})
	var cr_cfg: Dictionary = cr_cfg_v as Dictionary if cr_cfg_v is Dictionary else {}
	var ctx: Dictionary = {
		"actor_id": cid,
		"actor": cname,
		"target": str(target.get("name", "adversaire")),
		"target_enemy": target,
		"is_brilliant": false,
		"is_crit_success": false,
		"roll_bonus": 0,
		"scaled_active": false,
		"dmg": 0,
		"push": 0,
		"clock": 0,
		"moral": 0
	}
	var cr_hook: String = str(cr_cfg.get("custom_script", ""))
	if cr_hook != "":
		_invoke_custom_hook(cr_hook, "execute_crisis", ctx)
	elif not cr_cfg.is_empty():
		_execute_effect_bricks(cr_cfg.get("effects", []), ctx)
	else:
		GameState.modify_moral(cid, -5)
	var c_msg: String = _format_combat_log(str(cr_cfg.get("log", "CRISE D'AUTONOMIE ! {actor} agit sous pression sans attendre les ordres !")), ctx)
	_push_log(c_msg)
	_emit_feedback("crisis", cid, cname, c_msg, true)

func _sync_step_state() -> void:
	if not active:
		awaiting_step = false
		pending_beat_label = ""
		return
	if is_charge_window_active():
		awaiting_step = false
		pending_beat_label = ""
		return
	if not _pending_crisis_ids.is_empty():
		var cid: String = _pending_crisis_ids[0]
		var cname: String = str(DataLoader.get_character(cid).get("name", cid))
		awaiting_step = true
		pending_beat_label = "Crise : %s !" % cname
		return
	if not _pending_enemy_ids.is_empty():
		var eid: String = _pending_enemy_ids[0]
		var ed: Dictionary = _find_enemy(eid)
		awaiting_step = true
		pending_beat_label = "Action : %s" % str(ed.get("name", eid))
		return
	if get_acting_ally().is_empty():
		awaiting_step = true
		pending_beat_label = "Avancer au cran suivant"
		return
	awaiting_step = false
	pending_beat_label = ""

func _emit_feedback(kind: String, actor_id: String, actor_name: String, text: String, shake: bool) -> void:
	last_event = {
		"kind": kind,
		"actor_id": actor_id,
		"actor_name": actor_name,
		"text": text,
		"shake": shake
	}
	combat_feedback_emitted.emit(last_event)

func _find_rescuer_for(crisis_char_id: String) -> Dictionary:
	for a in allies:
		var cid: String = str(a.get("char_id", ""))
		if cid != crisis_char_id and bool(a.get("present", false)) and bool(a.get("reaction_ready", false)) and not bool(a.get("stunned", false)):
			return a
	return {}

func _remove_pending_enemy(eid: String) -> void:
	var idx: int = _pending_enemy_ids.find(eid)
	if idx >= 0:
		_pending_enemy_ids.remove_at(idx)

func _remove_pending_crisis(cid: String) -> void:
	var idx: int = _pending_crisis_ids.find(cid)
	if idx >= 0:
		_pending_crisis_ids.remove_at(idx)

func _is_in_crisis_queue(cid: String) -> bool:
	for cr in crisis_queue:
		if str(cr.get("char_id", "")) == cid:
			return true
	return false

func _find_ally(cid: String) -> Dictionary:
	for a in allies:
		if str(a.get("char_id", "")) == cid:
			return a
	return {}

func _find_enemy(eid: String) -> Dictionary:
	for e in enemies:
		if str(e.get("id", "")) == eid:
			return e
	return {}

func _peek_selected_target() -> Dictionary:
	if selected_target_id != "":
		var chosen: Dictionary = _find_enemy(selected_target_id)
		if not chosen.is_empty() and not bool(chosen.get("defeated", false)):
			return chosen
	return _get_first_active_enemy()

func _ensure_valid_target() -> Dictionary:
	if selected_target_id != "":
		var chosen: Dictionary = _find_enemy(selected_target_id)
		if not chosen.is_empty() and not bool(chosen.get("defeated", false)):
			return chosen
	var fallback: Dictionary = _get_first_active_enemy()
	selected_target_id = str(fallback.get("id", "")) if not fallback.is_empty() else ""
	return fallback

func _get_first_active_enemy() -> Dictionary:
	var best: Dictionary = {}
	var best_tick: int = 999
	for e in enemies:
		if not bool(e.get("defeated", false)):
			var nt: int = int(e.get("next_tick", 99))
			if nt < best_tick:
				best_tick = nt
				best = e
	return best

func _damage_enemy(enemy: Dictionary, dmg: int) -> void:
	var r: int = int(enemy.get("resolve", 1)) - dmg
	enemy["resolve"] = maxi(0, r)
	if r <= 0:
		enemy["defeated"] = true
		_remove_pending_enemy(str(enemy.get("id", "")))
		_push_log("→ %s lâche l'affaire et recule !" % str(enemy.get("name", "")))

func _all_enemies_defeated() -> bool:
	for e in enemies:
		if not bool(e.get("defeated", false)):
			return false
	return true

func _get_win_summary() -> String:
	var enc: Dictionary = DataLoader.get_encounter(encounter_id)
	var outs_v: Variant = enc.get("outcomes", {})
	if outs_v is Dictionary:
		var ws: String = str((outs_v as Dictionary).get("win_summary", ""))
		if ws != "":
			return ws
	return "Les adversaires plient sous la pression de la bande !"

func _finish(outcome_id: String, summary: String) -> void:
	active = false
	awaiting_step = false
	pending_beat_label = ""
	pending_enemy_charge.clear()
	charge_timer_paused = false
	_pending_enemy_ids.clear()
	_pending_crisis_ids.clear()
	_explicit_ally_target_id = ""
	_explicit_crisis_target_id = ""
	GameState.last_encounter_outcome = outcome_id

	var enc: Dictionary = DataLoader.get_encounter(encounter_id)
	var outs_v: Variant = enc.get("outcomes", {})
	if outs_v is Dictionary:
		var outs: Dictionary = outs_v as Dictionary
		var def_fl_v: Variant = outs.get("default_flags", {})
		if def_fl_v is Dictionary:
			var def_fl: Dictionary = def_fl_v as Dictionary
			for fk in def_fl.keys():
				GameState.set_flag(str(fk), bool(def_fl.get(fk, true)))
		var ocfg_v: Variant = outs.get(outcome_id, {})
		if ocfg_v is Dictionary:
			var ocfg: Dictionary = ocfg_v as Dictionary
			if ocfg.has("xp_all"):
				GameState.add_xp("all", int(ocfg.get("xp_all", 0)))
			var gt_v: Variant = ocfg.get("grant_trait", {})
			if gt_v is Dictionary:
				var gt: Dictionary = gt_v as Dictionary
				var gt_cid: String = str(gt.get("char_id", DataLoader.get_leader_char_id()))
				var gt_tr: String = str(gt.get("trait", ""))
				if gt_tr != "":
					GameState.add_trait(gt_cid, gt_tr)
			var sf_v: Variant = ocfg.get("set_flag", null)
			if sf_v is String and str(sf_v) != "":
				GameState.set_flag(str(sf_v), true)
			elif sf_v is Dictionary:
				var sfd: Dictionary = sf_v as Dictionary
				for sk_f in sfd.keys():
					GameState.set_flag(str(sk_f), bool(sfd.get(sk_f, true)))

	GameState.add_log(summary)
	timeline_updated.emit()
	encounter_finished.emit(outcome_id, summary)

func _push_log(msg: String) -> void:
	if msg == "":
		return
	combat_log.append(msg)
	if combat_log.size() > 36:
		combat_log.remove_at(0)

## Retourne l'entité actuellement active ou en attente immédiate d'exécution sur la Frise.
func get_active_turn_entity() -> Dictionary:
	if not active:
		return {}
	if is_charge_window_active():
		return {"kind": "enemy", "id": str(pending_enemy_charge.get("enemy_id", "")), "is_crisis_turn": false, "is_waiting_tick": false, "is_charge_window": true}
	if not _pending_crisis_ids.is_empty():
		return {"kind": "ally", "id": _pending_crisis_ids[0], "is_crisis_turn": true, "is_waiting_tick": false}
	if not _pending_enemy_ids.is_empty():
		return {"kind": "enemy", "id": _pending_enemy_ids[0], "is_crisis_turn": false, "is_waiting_tick": false}
	var acting: Dictionary = get_acting_ally()
	if not acting.is_empty():
		return {"kind": "ally", "id": str(acting.get("char_id", "")), "is_crisis_turn": false, "is_waiting_tick": false}
	for ed in get_ordered_rail_entries():
		var k: String = str(ed.get("kind", ""))
		if k == "ally" or k == "enemy":
			return {"kind": k, "id": str(ed.get("id", "")), "is_crisis_turn": false, "is_waiting_tick": true}
	return {}

## Indique le type de cible requis par une action ("enemy", "ally" ou "none").
func get_action_target_kind(action_id: String) -> String:
	if action_id == "act_escape_now" or action_id == "act_wait":
		return "none"
	var adef: Dictionary = DataLoader.get_combat_action_def(action_id)
	return str(adef.get("target_kind", "none"))

## Indique le type de cible requis par l'Interruption d'un allié ("enemy", "ally_crisis" ou "none").
func get_interruption_target_kind(char_id: String) -> String:
	var ally: Dictionary = _find_ally(char_id)
	var spec_id: String = str(ally.get("specialty_id", ""))
	var spec_def: Dictionary = DataLoader.get_specialty_def(spec_id)
	var mode: Dictionary = _select_specialty_mode(spec_def)
	if mode.is_empty():
		return "none"
	var tk: String = str(mode.get("target_kind", "none"))
	if tk == "enemy" and get_valid_target_ids("enemy").is_empty():
		return "none"
	return tk

## Retourne les IDs valides pour un type de ciblage sur la grille isométrique ("enemy", "ally" ou "ally_crisis").
func get_valid_target_ids(target_kind: String) -> Array[String]:
	var out: Array[String] = []
	if target_kind == "enemy":
		for e in enemies:
			if not bool(e.get("defeated", false)):
				out.append(str(e.get("id", "")))
	elif target_kind == "ally":
		for a in allies:
			if bool(a.get("present", false)):
				out.append(str(a.get("char_id", "")))
	elif target_kind == "ally_crisis":
		for cr in crisis_queue:
			var cid: String = str(cr.get("char_id", ""))
			var al: Dictionary = _find_ally(cid)
			if not al.is_empty() and bool(al.get("present", false)):
				out.append(cid)
	return out

## Prévisualise en lecture seule une action ciblée sur un pion donné sans modifier selected_target_id.
func preview_player_action_on(action_id: String, target_id: String) -> Dictionary:
	if not active:
		return {"valid": false, "reason": "Hors confrontation"}
	var acting: Dictionary = get_acting_ally()
	if awaiting_step or acting.is_empty():
		return {"valid": false, "reason": "Appuie d'abord sur Espace pour résoudre le beat en attente."}
	var saved_tid: String = selected_target_id
	var tk: String = get_action_target_kind(action_id)
	if tk == "enemy" and target_id != "":
		selected_target_id = target_id
	var pv: Dictionary = _build_action_preview(action_id, str(acting.get("char_id", DataLoader.get_leader_char_id())))
	selected_target_id = saved_tid
	if tk == "ally" and target_id != "" and bool(pv.get("valid", false)):
		var tname: String = str(DataLoader.get_character(target_id).get("name", target_id))
		pv["target_id"] = target_id
		pv["target_name"] = tname
		pv["summary"] = "%+d Moral sur %s (raté : %s)" % [int(pv.get("moral_delta", 0)), tname, str(pv.get("fail_summary", ""))]
	return pv

## Exécute une action tactique en visant explicitement le pion target_id cliqué sur la grille.
func execute_player_action_on(action_id: String, target_id: String) -> void:
	if not active:
		return
	var tk: String = get_action_target_kind(action_id)
	if tk == "enemy" and target_id != "":
		var en: Dictionary = _find_enemy(target_id)
		if en.is_empty() or bool(en.get("defeated", false)):
			return
		selected_target_id = target_id
	elif tk == "ally" and target_id != "":
		_explicit_ally_target_id = target_id
	execute_player_action(action_id)

## Prévisualise en lecture seule une Interruption ciblée sur un pion précis sans muter la file.
func preview_interruption_on(char_id: String, target_id: String) -> Dictionary:
	var saved_tid: String = selected_target_id
	var tk: String = get_interruption_target_kind(char_id)
	if tk == "enemy" and target_id != "":
		selected_target_id = target_id
	var pv: Dictionary = preview_interruption(char_id)
	selected_target_id = saved_tid
	if tk == "ally_crisis" and target_id != "" and bool(pv.get("valid", false)):
		var cname: String = str(DataLoader.get_character(char_id).get("name", char_id))
		var tname: String = str(DataLoader.get_character(target_id).get("name", target_id))
		pv["target_id"] = target_id
		pv["target_name"] = tname
		pv["summary"] = "%s calme la crise de %s · %+d Moral" % [cname, tname, int(pv.get("moral_delta", 10))]
	return pv

## Exécute une Interruption hors-tour en visant explicitement target_id (ennemi ou PJ en crise).
func trigger_interruption_on(char_id: String, target_id: String) -> void:
	if not active:
		return
	var tk: String = get_interruption_target_kind(char_id)
	if tk == "enemy" and target_id != "":
		selected_target_id = target_id
	elif tk == "ally_crisis" and target_id != "":
		_explicit_crisis_target_id = target_id
	trigger_interruption(char_id)

## Retourne toutes les données de fiche (PJ ou PNJ) nécessaires à l'affichage bas-gauche/bas-droite.
func get_entity_sheet_data(kind: String, entity_id: String) -> Dictionary:
	if kind == "ally":
		var ally: Dictionary = _find_ally(entity_id)
		var cdef: Dictionary = DataLoader.get_character(entity_id)
		var st: Dictionary = GameState.get_member_state(entity_id)
		var prog: Dictionary = GameState.get_member_progression(entity_id)
		if cdef.is_empty():
			return {}
		var cr_ticks: int = -1
		var cr_label: String = ""
		var in_crisis: bool = false
		for cr in crisis_queue:
			if str(cr.get("char_id", "")) == entity_id:
				in_crisis = true
				cr_ticks = int(cr.get("ticks_left", 1))
				cr_label = str(cr.get("label", "Crise d'autonomie"))
				break

		var sk_entries: Array[Dictionary] = []
		for sk_var in DataLoader.skills_catalog:
			if sk_var is Dictionary:
				var skd: Dictionary = sk_var as Dictionary
				var skid: String = str(skd.get("id", ""))
				var sval: int = GameState.get_effective_skill(entity_id, skid)
				if sval != 0:
					sk_entries.append({
						"name": str(skd.get("name", skid)).split(" ")[0],
						"val": sval,
						"score": abs(sval) * 10 + (1 if sval > 0 else 0)
					})
		sk_entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
			return int(x.get("score", 0)) > int(y.get("score", 0))
		)
		var top_skills: Array[String] = []
		for si in range(mini(4, sk_entries.size())):
			var se: Dictionary = sk_entries[si]
			top_skills.append("%s %+d" % [str(se.get("name", "")), int(se.get("val", 0))])

		var eq_names: Array[String] = []
		var eq_var: Variant = prog.get("equipment", {})
		if eq_var is Dictionary:
			var eq_d: Dictionary = eq_var as Dictionary
			for sl in ["look_top", "look_bottom", "tool", "fetish"]:
				var iid: String = str(eq_d.get(sl, ""))
				if iid != "":
					var idef: Dictionary = DataLoader.get_equipment_def(iid)
					eq_names.append(str(idef.get("name", iid)))

		var cov_ally: Dictionary = get_entity_cover_info("ally", entity_id)
		return {
			"kind": "ally",
			"id": entity_id,
			"name": str(cdef.get("name", entity_id)),
			"role": str(cdef.get("role", "")),
			"tribe": str(cdef.get("tribe", "")),
			"portrait": str(cdef.get("portrait", "")),
			"color_hex": str(cdef.get("color_hex", "#f28c28")),
			"moral": int(st.get("moral", 60)),
			"moral_max": GameState.get_effective_moral_max(entity_id),
			"stress_threshold": GameState.get_effective_stress_threshold(entity_id),
			"attitude": GameState.get_effective_attitude_for(entity_id),
			"aura": GameState.get_effective_aura_for(entity_id),
			"esprit": GameState.get_effective_characteristic(entity_id, "esprit"),
			"corps": GameState.get_effective_characteristic(entity_id, "corps"),
			"energie": GameState.get_effective_characteristic(entity_id, "energie"),
			"top_skills": top_skills,
			"equipped_items": eq_names,
			"specialty_id": str(ally.get("specialty_id", cdef.get("specialty_id", ""))),
			"specialty_name": str(ally.get("specialty_name", cdef.get("specialty_name", ""))),
			"specialty_desc": str(cdef.get("specialty_desc", "")),
			"reaction_ready": bool(ally.get("reaction_ready", false)),
			"stunned": bool(ally.get("stunned", false)),
			"grid_x": int(ally.get("grid_x", 3)),
			"grid_y": int(ally.get("grid_y", 6)),
			"move_points_left": int(ally.get("move_points_left", 0)),
			"move_points_max": int(ally.get("move_points_max", compute_ally_move_points(entity_id))),
			"in_cover": bool(cov_ally.get("in_cover", false)),
			"cover_label": str(cov_ally.get("label", "")),
			"cover_defense": int(cov_ally.get("defense_bonus", 0)),
			"cover_absorb": int(cov_ally.get("moral_absorb", 0)),
			"in_crisis": in_crisis,
			"crisis_ticks": cr_ticks,
			"crisis_label": cr_label,
			"next_tick": int(ally.get("next_tick", 0)),
			"present": bool(ally.get("present", false)),
			"reinforce_in_ticks": int(ally.get("reinforce_in_ticks", 0))
		}

	if kind == "enemy":
		var ed: Dictionary = _find_enemy(entity_id)
		if ed.is_empty():
			return {}
		var is_e_stun: bool = bool(ed.get("stunned", false))
		var cov_en: Dictionary = get_entity_cover_info("enemy", entity_id)
		return {
			"kind": "enemy",
			"id": entity_id,
			"name": str(ed.get("name", entity_id)),
			"role": str(ed.get("role", "")),
			"portrait": str(ed.get("portrait", "res://assets/portraits/so_agent.png")),
			"color_hex": "#d92b2b",
			"resolve": int(ed.get("resolve", 1)),
			"resolve_max": int(ed.get("resolve_max", 1)),
			"dc_social": int(ed.get("dc_social", 11)),
			"dc_pression": int(ed.get("dc_pression", 11)),
			"intent_label": str(ed.get("intent_label", "")),
			"bark": str(ed.get("bark", "")),
			"counter_ready": bool(ed.get("counter_ready", false)) and not is_e_stun,
			"counter_label": str(ed.get("counter_label", "")),
			"stunned": is_e_stun,
			"is_charging": is_charge_window_active() and str(pending_enemy_charge.get("enemy_id", "")) == entity_id,
			"grid_x": int(ed.get("grid_x", 4)),
			"grid_y": int(ed.get("grid_y", 2)),
			"move_points": int(ed.get("move_points", 2)),
			"in_cover": bool(cov_en.get("in_cover", false)),
			"cover_label": str(cov_en.get("label", "")),
			"cover_defense": int(cov_en.get("defense_bonus", 0)),
			"cover_absorb": int(cov_en.get("moral_absorb", 0)),
			"next_tick": int(ed.get("next_tick", 1)),
			"defeated": bool(ed.get("defeated", false))
		}
	return {}

## Retourne les réactions hors-frise prêtes et les crises pouvant être retenues immédiatement.
func get_ready_reactions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in allies:
		if bool(a.get("present", false)) and bool(a.get("reaction_ready", false)) and not bool(a.get("stunned", false)):
			var cid: String = str(a.get("char_id", ""))
			var spec_id: String = str(a.get("specialty_id", ""))
			var spec_def: Dictionary = DataLoader.get_specialty_def(spec_id)
			if not spec_def.is_empty() and not bool(spec_def.get("has_interruption", true)):
				continue
			out.append({
				"kind": "interrupt",
				"char_id": cid,
				"name": str(a.get("name", cid)).split(" ")[0],
				"specialty_name": str(a.get("specialty_name", "Interrupt."))
			})
	return out

## Retourne l'ID de l'allié présent le plus proche du cran 0 (repli lorsque awaiting_step est actif).
func _peek_next_present_ally_id() -> String:
	var best_id: String = DataLoader.get_leader_char_id()
	var best_t: int = 999
	for a in allies:
		if bool(a.get("present", false)):
			var nt: int = int(a.get("next_tick", 99))
			if nt < best_t:
				best_t = nt
				best_id = str(a.get("char_id", best_id))
	return best_id

## Retourne l'ID de l'allié présent dont le Moral est actuellement le plus bas.
func _get_lowest_moral_present_ally_id(fallback_id: String) -> String:
	var best_id: String = fallback_id
	var low_m: int = 999
	for a in allies:
		if bool(a.get("present", false)):
			var cid: String = str(a.get("char_id", ""))
			var m: int = int(GameState.get_member_state(cid).get("moral", 60))
			if m < low_m:
				low_m = m
				best_id = cid
	return best_id

## Retarde toutes les Crises d'autonomie en préavis de ticks_add crans.
func _delay_crises_by(ticks_add: int) -> void:
	for i in range(crisis_queue.size()):
		var cr: Dictionary = crisis_queue[i]
		cr["ticks_left"] = int(cr.get("ticks_left", 1)) + ticks_add
		crisis_queue[i] = cr
		_remove_pending_crisis(str(cr.get("char_id", "")))

## Retarde d'un nombre de crans donné le préavis de Crise d'autonomie d'un PJ ciblé.
func _delay_crisis_for(char_id: String, ticks_add: int) -> void:
	for i in range(crisis_queue.size()):
		var cr: Dictionary = crisis_queue[i]
		if str(cr.get("char_id", "")) == char_id:
			cr["ticks_left"] = int(cr.get("ticks_left", 1)) + ticks_add
			crisis_queue[i] = cr
			_remove_pending_crisis(char_id)
