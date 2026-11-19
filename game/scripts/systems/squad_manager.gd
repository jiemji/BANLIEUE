extends Node

const ALL_ORDERS: Array[String] = ["Guetter", "Bricoler", "Attendre"]

func regroup_all() -> void:
	var target_loc: String = GameState.get_active_location_id()
	for cid in GameState.squad_members:
		var st: Dictionary = GameState.get_member_state(cid)
		st["group_id"] = 0
		st["location_id"] = target_loc
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
	for i in range(members.size()):
		var cid: String = members[i]
		var st: Dictionary = GameState.get_member_state(cid)
		if i < members.size() - 1:
			st["group_id"] = 0
			st["order_label"] = "Binôme"
		else:
			st["group_id"] = 1
			st["order_label"] = "Guetter"
		if str(st.get("location_id", "")) == "":
			st["location_id"] = current_loc
		GameState.member_states[cid] = st
	GameState.active_group_id = 0
	GameState.add_log("Bande scindée en 2+1 — utilise 1 / 2 pour basculer à la volée.")
	GameState.active_group_changed.emit(0)
	GameState.state_changed.emit()

func split_1_1_1() -> void:
	var members: Array[String] = GameState.squad_members
	for i in range(members.size()):
		var cid: String = members[i]
		var st: Dictionary = GameState.get_member_state(cid)
		st["group_id"] = i
		st["order_label"] = "En solo" if i == 0 else "Guetter"
		GameState.member_states[cid] = st
	GameState.active_group_id = 0
	GameState.add_log("Bande éclatée en éclaireurs (1+1+1) — discrétion max, zéro filet de nuit.")
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
	for cid in gmembers:
		var st: Dictionary = GameState.get_member_state(cid)
		st["location_id"] = location_id
		GameState.member_states[cid] = st
	if prev_loc != location_id:
		GameState.advance_clock(12)
		GameState.add_log("Groupe %d se rend à %s." % [GameState.active_group_id + 1, _loc_name(location_id)])
	GameState.state_changed.emit()

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
