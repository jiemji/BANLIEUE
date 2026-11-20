extends Node

const ALL_ORDERS: Array[String] = ["Guetter", "Bricoler", "Attendre"]

func regroup_all() -> void:
	var target_loc: String = GameState.get_active_location_id()
	var target_pos: Vector2 = _clamp_walkable_pos(target_loc, GameState.get_active_group_grid_pos())
	for cid in GameState.squad_members:
		var st: Dictionary = GameState.get_member_state(cid)
		st["group_id"] = 0
		st["location_id"] = target_loc
		st["grid_x"] = target_pos.x
		st["grid_y"] = target_pos.y
		st["order_label"] = "En bande"
		GameState.member_states[cid] = st
	GameState.active_group_id = 0
	GameState.add_log("Bande regroupée au complet (%d membres) à %s." % [GameState.squad_members.size(), _loc_name(target_loc)])
	GameState.active_group_changed.emit(0)
	GameState.state_changed.emit()

func split_2_1() -> void:
	var members: Array[String] = GameState.squad_members
	if members.size() < 2:
		return
	var current_loc: String = GameState.get_active_location_id()
	var g0_loc: String = ""
	var g0_pos: Vector2 = Vector2.ZERO
	for i in range(members.size()):
		var cid: String = members[i]
		var st: Dictionary = GameState.get_member_state(cid)
		var m_loc: String = str(st.get("location_id", ""))
		if m_loc == "":
			m_loc = current_loc
			st["location_id"] = m_loc
		var m_pos: Vector2 = Vector2(float(st.get("grid_x", 3.0)), float(st.get("grid_y", 4.0)))
		if i < members.size() - 1:
			st["group_id"] = 0
			st["order_label"] = "Binôme"
			if g0_loc == "":
				g0_loc = m_loc
				g0_pos = _clamp_walkable_pos(g0_loc, m_pos)
			st["grid_x"] = g0_pos.x
			st["grid_y"] = g0_pos.y
		else:
			st["group_id"] = 1
			st["order_label"] = "Guetter"
			var split_pos: Vector2 = _clamp_walkable_pos(m_loc, m_pos)
			if m_loc == g0_loc and split_pos.distance_to(g0_pos) < 0.75:
				split_pos = _pick_spread_pos(m_loc, g0_pos, [g0_pos], 1)
			st["grid_x"] = split_pos.x
			st["grid_y"] = split_pos.y
		GameState.member_states[cid] = st
	GameState.active_group_id = 0
	GameState.add_log("Bande scindée en 2+1 — utilise 1 / 2 ou clique un perso pour basculer.")
	GameState.active_group_changed.emit(0)
	GameState.state_changed.emit()

func split_1_1_1() -> void:
	var members: Array[String] = GameState.squad_members
	var current_loc: String = GameState.get_active_location_id()
	var placed_by_loc: Dictionary = {}
	for i in range(members.size()):
		var cid: String = members[i]
		var st: Dictionary = GameState.get_member_state(cid)
		var m_loc: String = str(st.get("location_id", ""))
		if m_loc == "":
			m_loc = current_loc
			st["location_id"] = m_loc
		var m_pos: Vector2 = _clamp_walkable_pos(m_loc, Vector2(float(st.get("grid_x", 3.0)), float(st.get("grid_y", 4.0))))
		var existing_list: Array[Vector2] = []
		if placed_by_loc.has(m_loc):
			var raw_list: Variant = placed_by_loc.get(m_loc, [])
			if raw_list is Array:
				for p_item in (raw_list as Array):
					if p_item is Vector2:
						existing_list.append(p_item as Vector2)
		var too_close: bool = false
		for ep in existing_list:
			if m_pos.distance_to(ep) < 0.75:
				too_close = true
				break
		if too_close:
			m_pos = _pick_spread_pos(m_loc, m_pos, existing_list, i)
		existing_list.append(m_pos)
		placed_by_loc[m_loc] = existing_list
		st["grid_x"] = m_pos.x
		st["grid_y"] = m_pos.y
		st["group_id"] = i
		st["order_label"] = "En solo" if i == 0 else "Guetter"
		GameState.member_states[cid] = st
	GameState.active_group_id = 0
	GameState.add_log("Bande éclatée en éclaireurs (1+1+1) — clique un perso pour le contrôler.")
	GameState.active_group_changed.emit(0)
	GameState.state_changed.emit()

func switch_to_group(group_id: int) -> void:
	var gmembers: Array[String] = GameState.get_group_members(group_id)
	if gmembers.is_empty():
		return
	GameState.active_group_id = group_id
	AudioRadio.play_cassette_click()
	var loc_id: String = GameState.get_active_location_id()
	GameState.add_log("Bascule sur Groupe %d (%s) — %s." % [group_id + 1, _names_list(gmembers), _loc_name(loc_id)])
	GameState.active_group_changed.emit(group_id)
	GameState.state_changed.emit()

func move_active_group(location_id: String) -> void:
	if not DataLoader.locations.has(location_id):
		return
	var prev_loc: String = GameState.get_active_location_id()
	var gmembers: Array[String] = GameState.get_active_group_members()
	var dest_pos: Vector2 = _loc_spawn(location_id)
	if prev_loc != location_id:
		var occupied: Array[Vector2] = []
		for gid in GameState.get_groups_in_location(location_id):
			if gid != GameState.active_group_id:
				occupied.append(GameState.get_group_grid_pos(gid))
		if not occupied.is_empty():
			var near_spawn: bool = false
			for op in occupied:
				if dest_pos.distance_to(op) < 0.75:
					near_spawn = true
					break
			if near_spawn:
				dest_pos = _pick_spread_pos(location_id, dest_pos, occupied, GameState.active_group_id + 1)

	for cid in gmembers:
		var st: Dictionary = GameState.get_member_state(cid)
		st["location_id"] = location_id
		if prev_loc != location_id:
			st["grid_x"] = dest_pos.x
			st["grid_y"] = dest_pos.y
		GameState.member_states[cid] = st
	if prev_loc != location_id:
		GameState.advance_clock(12)
		GameState.add_log("Groupe %d se rend à %s." % [GameState.active_group_id + 1, _loc_name(location_id)])
	GameState.state_changed.emit()

func _loc_spawn(loc_id: String) -> Vector2:
	var ldef: Dictionary = DataLoader.get_location(loc_id)
	var sp_var: Variant = ldef.get("spawn", [3.0, 4.0])
	if sp_var is Array and (sp_var as Array).size() >= 2:
		var arr: Array = sp_var as Array
		return _clamp_walkable_pos(loc_id, Vector2(float(arr[0]), float(arr[1])))
	return _clamp_walkable_pos(loc_id, Vector2(3.0, 4.0))

func _pick_spread_pos(loc_id: String, base: Vector2, occupied: Array[Vector2], seed_idx: int) -> Vector2:
	var candidates: Array[Vector2] = [
		Vector2(-1.15, 0.40),
		Vector2(1.15, 0.35),
		Vector2(0.0, 0.95),
		Vector2(-1.40, -0.35),
		Vector2(1.40, -0.35),
		Vector2(0.0, -0.95)
	]
	var total: int = candidates.size()
	for step in range(total):
		var off: Vector2 = candidates[(seed_idx + step) % total]
		var p: Vector2 = _clamp_walkable_pos(loc_id, base + off)
		var clear: bool = true
		for op in occupied:
			if p.distance_to(op) < 0.72:
				clear = false
				break
		if clear:
			return p
	return _clamp_walkable_pos(loc_id, base + candidates[seed_idx % total])

func _clamp_walkable_pos(loc_id: String, pos: Vector2) -> Vector2:
	var ldef: Dictionary = DataLoader.get_location(loc_id)
	var gw: int = maxi(4, int(ldef.get("grid_w", 8)))
	var gh: int = maxi(4, int(ldef.get("grid_h", 8)))
	var blocked: Dictionary = {}
	var raw_b: Variant = ldef.get("blocked_cells", [])
	if raw_b is Array:
		for cv in (raw_b as Array):
			if cv is Array and (cv as Array).size() >= 2:
				var ca: Array = cv as Array
				blocked["%d,%d" % [int(ca[0]), int(ca[1])]] = true

	var base: Vector2 = Vector2(clampf(pos.x, 0.6, float(gw) - 0.6), clampf(pos.y, 1.3, float(gh) - 0.6))
	if not blocked.has("%d,%d" % [int(floor(base.x)), int(floor(base.y))]):
		return base
	var nudges: Array[Vector2] = [
		Vector2(0.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(-1.0, 0.0),
		Vector2(0.0, -1.0),
		Vector2(1.0, 1.0),
		Vector2(-1.0, 1.0)
	]
	for n in nudges:
		var cand: Vector2 = Vector2(clampf(base.x + n.x, 0.6, float(gw) - 0.6), clampf(base.y + n.y, 1.3, float(gh) - 0.6))
		if not blocked.has("%d,%d" % [int(floor(cand.x)), int(floor(cand.y))]):
			return cand
	return base

func cycle_group_order(group_id: int) -> void:
	var gmembers: Array[String] = GameState.get_group_members(group_id)
	if gmembers.is_empty():
		return
	var first_st: Dictionary = GameState.get_member_state(gmembers[0])
	var cur: String = str(first_st.get("order_label", "Guetter"))
	var idx: int = ALL_ORDERS.find(cur)
	var next_order: String = ALL_ORDERS[(idx + 1) % ALL_ORDERS.size()]
	for cid in gmembers:
		var st: Dictionary = GameState.get_member_state(cid)
		st["order_label"] = next_order
		GameState.member_states[cid] = st
	GameState.state_changed.emit()

func get_location_distance(from_loc: String, to_loc: String) -> int:
	if from_loc == to_loc:
		return 0
	var loc_def: Dictionary = DataLoader.get_location(from_loc)
	var neigh_var: Variant = loc_def.get("neighbors", {})
	if neigh_var is Dictionary:
		var neigh: Dictionary = neigh_var as Dictionary
		if neigh.has(to_loc):
			var d: int = int(neigh.get(to_loc, 2))
			if GameState.has_flag("mobs_tuned") and d > 1:
				d -= 1
			return d
	return 2

func compute_reinforcements(encounter_location_id: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for cid in GameState.squad_members:
		var st: Dictionary = GameState.get_member_state(cid)
		var loc_id: String = str(st.get("location_id", "box_garage"))
		var gid: int = int(st.get("group_id", 0))
		if gid != GameState.active_group_id and loc_id != encounter_location_id:
			var dist: int = get_location_distance(loc_id, encounter_location_id)
			var cdef: Dictionary = DataLoader.get_character(cid)
			list.append({
				"char_id": cid,
				"name": str(cdef.get("name", cid)),
				"from_location": _loc_name(loc_id),
				"ticks": clampi(dist, 1, 4)
			})
	return list

func _loc_name(loc_id: String) -> String:
	var ldef: Dictionary = DataLoader.get_location(loc_id)
	return str(ldef.get("name", loc_id))

func _names_list(ids: Array[String]) -> String:
	var names: Array[String] = []
	for cid in ids:
		var cdef: Dictionary = DataLoader.get_character(cid)
		names.append(str(cdef.get("name", cid)).split(" ")[0])
	return ", ".join(names)
