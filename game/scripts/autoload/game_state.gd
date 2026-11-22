extends Node

signal state_changed
signal phase_changed(new_phase: String)
signal active_group_changed(group_id: int)
signal zoom_changed(level: int, map_id: String)
signal log_added(entry: String)

var phase: String = "day" # "day", "twilight", "night"
var clock_minutes: int = 17 * 60 + 30
var francs: int = 25
var faveurs: int = 0
var notoriete: int = 1
var aura_bonus: int = 0

var flags: Dictionary = {}
var clues: Array[String] = []
var activity_log: Array[String] = []

var squad_members: Array[String] = []
var member_states: Dictionary = {} # char_id -> {moral, moral_max, location_id, group_id, order_label, stress_active}
var member_progression: Dictionary = {} # char_id -> {xp, skills, equipment, traits}
var box_stash: Array[String] = []
var active_group_id: int = 0
var current_station_idx: int = 0
var last_encounter_outcome: String = ""

var current_zoom_level: int = 4
var current_region_id: String = "idf"
var current_department_id: String = "dept_93"
var current_city_id: String = "cradon_les_gonesse"

var has_active_session: bool = false
var leader_profile: Dictionary = {}

func _ready() -> void:
	reset_new_slice({})
	has_active_session = false

## Réinitialise une nouvelle session du niveau-pilote en injectant le profil Leader choisi (nom, portrait, archétype).
func reset_new_slice(profile: Dictionary = {}) -> void:
	phase = "day"
	clock_minutes = 17 * 60 + 30
	francs = 25
	faveurs = 0
	notoriete = 1
	aura_bonus = 0
	flags.clear()
	clues.clear()
	activity_log.clear()
	squad_members.clear()
	member_states.clear()
	member_progression.clear()
	box_stash = ["perfecto_cloute", "parka_anonyme", "cassettes_tdk"]
	active_group_id = 0
	current_station_idx = 0
	last_encounter_outcome = ""
	current_zoom_level = 4
	current_region_id = "idf"
	current_department_id = "dept_93"
	current_city_id = "cradon_les_gonesse"

	if DataLoader.characters.is_empty() or DataLoader.player_archetypes.is_empty():
		DataLoader.load_all()

	var chosen_name: String = str(profile.get("name", "Alex")).strip_edges()
	if chosen_name == "":
		chosen_name = "Alex"
	var chosen_arch_id: String = str(profile.get("archetype_id", "mains_noires"))
	var arch_def: Dictionary = DataLoader.get_archetype_def(chosen_arch_id)
	if not arch_def.is_empty():
		chosen_arch_id = str(arch_def.get("id", chosen_arch_id))
	var chosen_port_id: String = str(profile.get("portrait_id", "player_01"))
	var port_def: Dictionary = DataLoader.get_portrait_def(chosen_port_id)
	if not port_def.is_empty():
		chosen_port_id = str(port_def.get("id", chosen_port_id))

	leader_profile = {
		"name": chosen_name,
		"archetype_id": chosen_arch_id,
		"portrait_id": chosen_port_id,
		"portrait_path": str(port_def.get("portrait", str(profile.get("portrait_path", "")))),
		"pawn_path": str(port_def.get("pawn", str(profile.get("pawn_path", ""))))
	}
	DataLoader.apply_leader_profile(leader_profile)

	if not arch_def.is_empty():
		francs += int(arch_def.get("francs_bonus", 0))
		faveurs += int(arch_def.get("faveurs_bonus", 0))
		aura_bonus += int(arch_def.get("aura_bonus", 0))
		var sf_var: Variant = arch_def.get("start_flags", [])
		if sf_var is Array:
			for fl_var in (sf_var as Array):
				var fl_name: String = str(fl_var)
				if fl_name != "":
					flags[fl_name] = true

	var start_loc: Dictionary = DataLoader.get_location("box_garage")
	var sp_var: Variant = start_loc.get("spawn", [3.0, 4.0])
	var sp_x: float = 3.0
	var sp_y: float = 4.0
	if sp_var is Array and (sp_var as Array).size() >= 2:
		var sp_arr: Array = sp_var as Array
		sp_x = float(sp_arr[0])
		sp_y = float(sp_arr[1])

	for cid_var in DataLoader.characters.keys():
		var cid: String = str(cid_var)
		var cdef: Dictionary = DataLoader.get_character(cid)
		var in_default: bool = bool(cdef.get("in_squad_default", false))
		_ensure_progression_entry(cid, 40 if cid == "leader" else (20 if in_default else 0))
		var m_start: int = int(cdef.get("moral_start", 60))
		var m_max: int = get_effective_moral_max(cid)
		var threshold: int = get_effective_stress_threshold(cid)
		member_states[cid] = {
			"moral": clampi(m_start, 0, m_max),
			"moral_max": m_max,
			"location_id": "box_garage",
			"grid_x": sp_x,
			"grid_y": sp_y,
			"group_id": 0,
			"order_label": "En bande",
			"stress_active": m_start <= threshold
		}
		if in_default:
			squad_members.append(cid)

	var arch_title: String = str(arch_def.get("title", ""))
	if arch_title != "":
		add_log("17 h 30 — %s (%s) au Box-Garage sous la Dalle." % [chosen_name, arch_title])
	else:
		add_log("17 h 30 — Au Box-Garage sous la Dalle. Fais tourner la FM ou file au Galaxian.")
	state_changed.emit()

func add_log(msg: String) -> void:
	activity_log.append(msg)
	if activity_log.size() > 40:
		activity_log.remove_at(0)
	log_added.emit(msg)

func get_member_state(char_id: String) -> Dictionary:
	var val: Variant = member_states.get(char_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func get_active_location_id() -> String:
	for cid in squad_members:
		var st: Dictionary = get_member_state(cid)
		if int(st.get("group_id", 0)) == active_group_id:
			return str(st.get("location_id", "box_garage"))
	return "box_garage"

func get_group_members(group_id: int) -> Array[String]:
	var res: Array[String] = []
	for cid in squad_members:
		var st: Dictionary = get_member_state(cid)
		if int(st.get("group_id", 0)) == group_id:
			res.append(cid)
	return res

func get_active_group_members() -> Array[String]:
	return get_group_members(active_group_id)

func get_present_group_ids() -> Array[int]:
	var ids: Array[int] = []
	for cid in squad_members:
		var st: Dictionary = get_member_state(cid)
		var gid: int = int(st.get("group_id", 0))
		if not ids.has(gid):
			ids.append(gid)
	ids.sort()
	return ids

func get_groups_in_location(loc_id: String) -> Array[int]:
	var ids: Array[int] = []
	for cid in squad_members:
		var st: Dictionary = get_member_state(cid)
		if str(st.get("location_id", "box_garage")) == loc_id:
			var gid: int = int(st.get("group_id", 0))
			if not ids.has(gid):
				ids.append(gid)
	ids.sort()
	return ids

func get_group_grid_pos(group_id: int) -> Vector2:
	for cid in squad_members:
		var st: Dictionary = get_member_state(cid)
		if int(st.get("group_id", 0)) == group_id:
			if st.has("grid_x") and st.has("grid_y"):
				return Vector2(float(st.get("grid_x", 3.0)), float(st.get("grid_y", 4.0)))
			var lid: String = str(st.get("location_id", "box_garage"))
			var ldef: Dictionary = DataLoader.get_location(lid)
			var sp_var: Variant = ldef.get("spawn", [3.0, 4.0])
			if sp_var is Array and (sp_var as Array).size() >= 2:
				var arr: Array = sp_var as Array
				return Vector2(float(arr[0]), float(arr[1]))
	return Vector2(3.0, 4.0)

func get_active_group_grid_pos() -> Vector2:
	return get_group_grid_pos(active_group_id)

func set_group_grid_pos(group_id: int, pos: Vector2) -> void:
	for cid in squad_members:
		var st: Dictionary = get_member_state(cid)
		if int(st.get("group_id", 0)) == group_id:
			st["grid_x"] = pos.x
			st["grid_y"] = pos.y
			member_states[cid] = st

func is_member_in_active_group(char_id: String) -> bool:
	var active_ids: Array[String] = get_active_group_members()
	return active_ids.has(char_id)

func get_total_aura() -> int:
	var best_aura: int = 0
	var active_ids: Array[String] = get_active_group_members()
	for cid in active_ids:
		var cf: int = get_effective_aura_for(cid)
		if cf > best_aura:
			best_aura = cf
	var size_bonus: int = max(0, active_ids.size() - 1)
	return best_aura + aura_bonus + size_bonus

func _ensure_progression_entry(char_id: String, initial_xp: int = 0) -> void:
	if member_progression.has(char_id):
		return
	var cdef: Dictionary = DataLoader.get_character(char_id)
	var base_skills: Dictionary = {}
	var raw_sk: Variant = cdef.get("skills", {})
	if raw_sk is Dictionary:
		var skd: Dictionary = raw_sk as Dictionary
		for sk_k in skd.keys():
			base_skills[str(sk_k)] = int(skd.get(sk_k, 0))
	var base_eq: Dictionary = {"look": "", "tool": "", "fetish": ""}
	var raw_eq: Variant = cdef.get("default_equipment", {})
	if raw_eq is Dictionary:
		var eqd: Dictionary = raw_eq as Dictionary
		for sl_k in ["look", "tool", "fetish"]:
			base_eq[sl_k] = str(eqd.get(sl_k, ""))
	var empty_traits: Array[String] = []
	member_progression[char_id] = {
		"xp": initial_xp,
		"skills": base_skills,
		"equipment": base_eq,
		"traits": empty_traits
	}

func get_member_progression(char_id: String) -> Dictionary:
	if not member_progression.has(char_id):
		_ensure_progression_entry(char_id, 0)
	var val: Variant = member_progression.get(char_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func _get_equipped_item_ids(char_id: String) -> Array[String]:
	var res: Array[String] = []
	var prog: Dictionary = get_member_progression(char_id)
	var eq_var: Variant = prog.get("equipment", {})
	if eq_var is Dictionary:
		var eq_d: Dictionary = eq_var as Dictionary
		for slot_k in ["look", "tool", "fetish"]:
			var iid: String = str(eq_d.get(slot_k, ""))
			if iid != "":
				res.append(iid)
	return res

func _sum_equipment_stat_mod(char_id: String, stat_key: String) -> int:
	var total: int = 0
	for iid in _get_equipped_item_ids(char_id):
		var idef: Dictionary = DataLoader.get_equipment_def(iid)
		var sm_var: Variant = idef.get("stat_mods", {})
		if sm_var is Dictionary:
			total += int((sm_var as Dictionary).get(stat_key, 0))
	return total

func get_effective_characteristic(char_id: String, charac_id: String) -> int:
	var cdef: Dictionary = DataLoader.get_character(char_id)
	var ch_var: Variant = cdef.get("characteristics", {})
	var base: int = 3
	if ch_var is Dictionary:
		base = int((ch_var as Dictionary).get(charac_id, 3))
	return clampi(base + _sum_equipment_stat_mod(char_id, charac_id), 1, 5)

func get_base_skill(char_id: String, skill_id: String) -> int:
	var prog: Dictionary = get_member_progression(char_id)
	var sk_var: Variant = prog.get("skills", {})
	if sk_var is Dictionary:
		return clampi(int((sk_var as Dictionary).get(skill_id, 0)), -3, 5)
	return 0

func get_equipment_skill_bonus(char_id: String, skill_id: String) -> int:
	var bonus: int = 0
	for iid in _get_equipped_item_ids(char_id):
		var idef: Dictionary = DataLoader.get_equipment_def(iid)
		var mods_var: Variant = idef.get("skill_mods", {})
		if mods_var is Dictionary:
			bonus += int((mods_var as Dictionary).get(skill_id, 0))
	return bonus

func get_effective_skill(char_id: String, skill_id: String) -> int:
	var base: int = get_base_skill(char_id, skill_id)
	var bonus: int = get_equipment_skill_bonus(char_id, skill_id)
	var total: int = base + bonus
	var unlocked_by_item: bool = false
	for iid in _get_equipped_item_ids(char_id):
		var idef: Dictionary = DataLoader.get_equipment_def(iid)
		var unl_var: Variant = idef.get("unlocks_skills", [])
		if unl_var is Array:
			for u_v in (unl_var as Array):
				if str(u_v) == skill_id:
					unlocked_by_item = true
					break
	if unlocked_by_item and total < 1:
		total = 1
	return clampi(total, -3, 5)

func get_best_active_group_skill(skill_id: String) -> int:
	var best: int = -3
	var active_ids: Array[String] = get_active_group_members()
	if active_ids.is_empty():
		return 0
	for cid in active_ids:
		var val: int = get_effective_skill(cid, skill_id)
		if val > best:
			best = val
	return best

func get_effective_attitude_for(char_id: String) -> int:
	var cdef: Dictionary = DataLoader.get_character(char_id)
	return maxi(0, int(cdef.get("attitude", 60)) + _sum_equipment_stat_mod(char_id, "attitude"))

func get_effective_aura_for(char_id: String) -> int:
	var cdef: Dictionary = DataLoader.get_character(char_id)
	return maxi(0, int(cdef.get("aura", 2)) + _sum_equipment_stat_mod(char_id, "aura"))

func get_effective_moral_max(char_id: String) -> int:
	var cdef: Dictionary = DataLoader.get_character(char_id)
	return maxi(20, int(cdef.get("moral_max", 100)) + _sum_equipment_stat_mod(char_id, "moral_max"))

func get_effective_stress_threshold(char_id: String) -> int:
	var cdef: Dictionary = DataLoader.get_character(char_id)
	return clampi(int(cdef.get("stress_threshold", 35)) + _sum_equipment_stat_mod(char_id, "stress_threshold"), 5, 90)

func get_unlocked_equipment_actions(char_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for iid in _get_equipped_item_ids(char_id):
		var idef: Dictionary = DataLoader.get_equipment_def(iid)
		var acts_var: Variant = idef.get("unlocks_actions", [])
		if acts_var is Array:
			for av in (acts_var as Array):
				if av is Dictionary:
					var ad: Dictionary = av as Dictionary
					var aid: String = str(ad.get("id", ""))
					if aid != "" and not seen.has(aid):
						seen[aid] = true
						out.append(ad.duplicate(true))
	return out

func get_skill_upgrade_cost(current_val: int, is_new_learn: bool = false) -> int:
	if current_val >= 5:
		return -1
	if current_val < 0:
		return 30
	if current_val == 0:
		return 50 if is_new_learn else 40
	if current_val == 1:
		return 60
	if current_val == 2:
		return 90
	if current_val == 3:
		return 130
	return 180

func add_xp(char_id: String, amount: int) -> void:
	if amount <= 0:
		return
	if char_id == "all":
		for cid in squad_members:
			add_xp(cid, amount)
		return
	var prog: Dictionary = get_member_progression(char_id)
	prog["xp"] = int(prog.get("xp", 0)) + amount
	member_progression[char_id] = prog
	var cname: String = str(DataLoader.get_character(char_id).get("name", char_id))
	add_log("XP %s : +%d XP" % [cname, amount])
	state_changed.emit()

func upgrade_member_skill(char_id: String, skill_id: String) -> bool:
	var prog: Dictionary = get_member_progression(char_id)
	var sk_var: Variant = prog.get("skills", {})
	var sk_d: Dictionary = sk_var as Dictionary if sk_var is Dictionary else {}
	var cur_val: int = clampi(int(sk_d.get(skill_id, 0)), -3, 5)
	if cur_val >= 5:
		return false
	var cdef: Dictionary = DataLoader.get_character(char_id)
	var profile_sk_var: Variant = cdef.get("skills", {})
	var in_profile: bool = (profile_sk_var is Dictionary) and (profile_sk_var as Dictionary).has(skill_id)
	var is_new_learn: bool = (cur_val == 0) and (not in_profile) and (not sk_d.has(skill_id))
	var cost: int = get_skill_upgrade_cost(cur_val, is_new_learn)
	var xp_avail: int = int(prog.get("xp", 0))
	if cost < 0 or xp_avail < cost:
		return false
	prog["xp"] = xp_avail - cost
	sk_d[skill_id] = cur_val + 1
	prog["skills"] = sk_d
	member_progression[char_id] = prog
	var sname: String = str(DataLoader.get_skill_def(skill_id).get("name", skill_id))
	var cname: String = str(cdef.get("name", char_id))
	add_log("%s progresse en %s (%+d)" % [cname, sname, cur_val + 1])
	state_changed.emit()
	return true

func add_trait(char_id: String, trait_label: String) -> void:
	if trait_label == "":
		return
	var prog: Dictionary = get_member_progression(char_id)
	var tr_var: Variant = prog.get("traits", [])
	var tr_list: Array[String] = []
	if tr_var is Array:
		for tv in (tr_var as Array):
			tr_list.append(str(tv))
	if not tr_list.has(trait_label):
		tr_list.append(trait_label)
		prog["traits"] = tr_list
		member_progression[char_id] = prog
		var cname: String = str(DataLoader.get_character(char_id).get("name", char_id))
		add_log("Trait acquis (%s) : %s" % [cname, trait_label])
		state_changed.emit()

func add_to_box_stash(item_id: String) -> void:
	if item_id == "" or DataLoader.get_equipment_def(item_id).is_empty():
		return
	if not box_stash.has(item_id):
		box_stash.append(item_id)
		var iname: String = str(DataLoader.get_equipment_def(item_id).get("name", item_id))
		add_log("Coffre Box-Garage : +%s" % iname)
		state_changed.emit()

func has_item_in_active_group_or_stash(item_id: String) -> bool:
	if box_stash.has(item_id):
		return true
	for cid in get_active_group_members():
		if _get_equipped_item_ids(cid).has(item_id):
			return true
	return false

func equip_item(char_id: String, item_id: String) -> bool:
	var idef: Dictionary = DataLoader.get_equipment_def(item_id)
	if idef.is_empty() or not box_stash.has(item_id):
		return false
	var slot_name: String = str(idef.get("slot", ""))
	if slot_name != "look" and slot_name != "tool" and slot_name != "fetish":
		return false
	var prog: Dictionary = get_member_progression(char_id)
	var eq_var: Variant = prog.get("equipment", {})
	var eq_d: Dictionary = (eq_var as Dictionary).duplicate(true) if eq_var is Dictionary else {"look": "", "tool": "", "fetish": ""}
	var idx: int = box_stash.find(item_id)
	if idx >= 0:
		box_stash.remove_at(idx)
	var prev_id: String = str(eq_d.get(slot_name, ""))
	if prev_id != "":
		box_stash.append(prev_id)
	eq_d[slot_name] = item_id
	prog["equipment"] = eq_d
	member_progression[char_id] = prog
	_sync_moral_bounds_for(char_id)
	var cname: String = str(DataLoader.get_character(char_id).get("name", char_id))
	add_log("%s équipe : %s" % [cname, str(idef.get("name", item_id))])
	state_changed.emit()
	return true

func unequip_slot(char_id: String, slot_name: String) -> bool:
	var prog: Dictionary = get_member_progression(char_id)
	var eq_var: Variant = prog.get("equipment", {})
	if not (eq_var is Dictionary):
		return false
	var eq_d: Dictionary = (eq_var as Dictionary).duplicate(true)
	var cur_id: String = str(eq_d.get(slot_name, ""))
	if cur_id == "":
		return false
	eq_d[slot_name] = ""
	prog["equipment"] = eq_d
	member_progression[char_id] = prog
	box_stash.append(cur_id)
	_sync_moral_bounds_for(char_id)
	state_changed.emit()
	return true

func _sync_moral_bounds_for(char_id: String) -> void:
	if not member_states.has(char_id):
		return
	var st: Dictionary = get_member_state(char_id)
	var m_max: int = get_effective_moral_max(char_id)
	var threshold: int = get_effective_stress_threshold(char_id)
	var cur_m: int = clampi(int(st.get("moral", 60)), 0, m_max)
	st["moral"] = cur_m
	st["moral_max"] = m_max
	st["stress_active"] = cur_m <= threshold
	member_states[char_id] = st

func get_lowest_moral() -> int:
	var low: int = 100
	for cid in squad_members:
		var st: Dictionary = get_member_state(cid)
		var m: int = int(st.get("moral", 60))
		if m < low:
			low = m
	return low

func modify_moral(char_id: String, delta: int) -> void:
	if char_id == "all":
		for cid in squad_members:
			modify_moral(cid, delta)
		return
	if not member_states.has(char_id):
		return
	var st: Dictionary = get_member_state(char_id)
	var cdef: Dictionary = DataLoader.get_character(char_id)
	var m_max: int = get_effective_moral_max(char_id)
	var old_m: int = int(st.get("moral", 60))
	var new_m: int = clampi(old_m + delta, 0, m_max)
	var threshold: int = get_effective_stress_threshold(char_id)
	st["moral"] = new_m
	st["moral_max"] = m_max
	st["stress_active"] = new_m <= threshold
	member_states[char_id] = st
	if delta != 0 and squad_members.has(char_id):
		var sign_txt: String = "+" if delta > 0 else ""
		var cname: String = str(cdef.get("name", char_id))
		add_log("Moral %s : %s%d (%d/%d)" % [cname, sign_txt, delta, new_m, m_max])
	state_changed.emit()

func recruit_member(char_id: String) -> void:
	if not DataLoader.characters.has(char_id):
		return
	if not squad_members.has(char_id):
		squad_members.append(char_id)
		var active_pos: Vector2 = get_active_group_grid_pos()
		var st: Dictionary = get_member_state(char_id)
		st["location_id"] = get_active_location_id()
		st["grid_x"] = active_pos.x
		st["grid_y"] = active_pos.y
		st["group_id"] = active_group_id
		st["order_label"] = "Recruté"
		member_states[char_id] = st
		var cdef: Dictionary = DataLoader.get_character(char_id)
		add_log("%s rejoint la bande au Box-Garage !" % str(cdef.get("name", char_id)))
		state_changed.emit()

func set_flag(flag_name: String, val: bool = true) -> void:
	flags[flag_name] = val
	state_changed.emit()

func has_flag(flag_name: String) -> bool:
	return bool(flags.get(flag_name, false))

func unlock_clue(clue_text: String) -> void:
	if clue_text != "" and not clues.has(clue_text):
		clues.append(clue_text)
		add_log("Piste : " + clue_text)
		state_changed.emit()

func set_phase(new_phase: String) -> void:
	if phase == new_phase:
		return
	phase = new_phase
	if new_phase == "twilight":
		clock_minutes = 20 * 60 + 15
	elif new_phase == "night":
		clock_minutes = 22 * 60 + 10
	phase_changed.emit(new_phase)
	state_changed.emit()

func advance_clock(minutes_add: int) -> void:
	clock_minutes = (clock_minutes + minutes_add) % (24 * 60)
	state_changed.emit()

func format_clock() -> String:
	var h: int = int(clock_minutes / 60) % 24
	var m: int = clock_minutes % 60
	return "%02d h %02d" % [h, m]

func cycle_station() -> int:
	if DataLoader.radio_stations.is_empty():
		return 0
	current_station_idx = (current_station_idx + 1) % DataLoader.radio_stations.size()
	state_changed.emit()
	return current_station_idx

func set_zoom_view(level: int, map_id: String = "") -> void:
	var target_lvl: int = clampi(level, 1, 4)
	current_zoom_level = target_lvl
	if target_lvl == 1 and map_id != "":
		current_region_id = map_id
	elif target_lvl == 2 and map_id != "":
		current_department_id = map_id
	elif target_lvl == 3 and map_id != "":
		current_city_id = map_id

	var emit_id: String = map_id
	if emit_id == "":
		if target_lvl == 1:
			emit_id = current_region_id
		elif target_lvl == 2:
			emit_id = current_department_id
		elif target_lvl == 3:
			emit_id = current_city_id
		else:
			emit_id = get_active_location_id()
	zoom_changed.emit(current_zoom_level, emit_id)
	state_changed.emit()

## Sérialise l'état complet de la partie dans un Dictionnaire prêt pour l'export JSON.
func to_save_dict() -> Dictionary:
	var clues_copy: Array[String] = []
	for c in clues:
		clues_copy.append(c)
	var log_copy: Array[String] = []
	for entry in activity_log:
		log_copy.append(entry)
	var squad_copy: Array[String] = []
	for sid in squad_members:
		squad_copy.append(sid)
	var stash_copy: Array[String] = []
	for iid in box_stash:
		stash_copy.append(iid)
	return {
		"phase": phase,
		"clock_minutes": clock_minutes,
		"francs": francs,
		"faveurs": faveurs,
		"notoriete": notoriete,
		"aura_bonus": aura_bonus,
		"flags": flags.duplicate(true),
		"clues": clues_copy,
		"activity_log": log_copy,
		"squad_members": squad_copy,
		"member_states": member_states.duplicate(true),
		"member_progression": member_progression.duplicate(true),
		"box_stash": stash_copy,
		"active_group_id": active_group_id,
		"current_station_idx": current_station_idx,
		"last_encounter_outcome": last_encounter_outcome,
		"current_zoom_level": current_zoom_level,
		"current_region_id": current_region_id,
		"current_department_id": current_department_id,
		"current_city_id": current_city_id
	}

## Restaure le profil du protagoniste et l'état complet d'une session depuis une sauvegarde JSON.
func load_from_save_dict(profile_data: Dictionary, state_data: Dictionary) -> void:
	if DataLoader.characters.is_empty() or DataLoader.player_archetypes.is_empty():
		DataLoader.load_all()

	leader_profile = profile_data.duplicate(true)
	var lp_name: String = str(leader_profile.get("name", "Alex")).strip_edges()
	if lp_name == "":
		lp_name = "Alex"
	leader_profile["name"] = lp_name
	DataLoader.apply_leader_profile(leader_profile)

	phase = str(state_data.get("phase", "day"))
	clock_minutes = int(state_data.get("clock_minutes", 17 * 60 + 30))
	francs = int(state_data.get("francs", 25))
	faveurs = int(state_data.get("faveurs", 0))
	notoriete = int(state_data.get("notoriete", 1))
	aura_bonus = int(state_data.get("aura_bonus", state_data.get("fasa_bonus", 0)))

	flags.clear()
	var fl_var: Variant = state_data.get("flags", {})
	if fl_var is Dictionary:
		var fl_d: Dictionary = fl_var as Dictionary
		for fk in fl_d.keys():
			flags[str(fk)] = bool(fl_d.get(fk, false))

	clues.clear()
	var cl_var: Variant = state_data.get("clues", [])
	if cl_var is Array:
		for cv in (cl_var as Array):
			clues.append(str(cv))

	activity_log.clear()
	var log_var: Variant = state_data.get("activity_log", [])
	if log_var is Array:
		for lv in (log_var as Array):
			activity_log.append(str(lv))

	squad_members.clear()
	var sq_var: Variant = state_data.get("squad_members", [])
	if sq_var is Array:
		for sv in (sq_var as Array):
			squad_members.append(str(sv))

	member_states.clear()
	var ms_var: Variant = state_data.get("member_states", {})
	if ms_var is Dictionary:
		var ms_d: Dictionary = ms_var as Dictionary
		for cid_k in ms_d.keys():
			var st_v: Variant = ms_d.get(cid_k, {})
			if st_v is Dictionary:
				member_states[str(cid_k)] = (st_v as Dictionary).duplicate(true)

	member_progression.clear()
	var mp_var: Variant = state_data.get("member_progression", {})
	if mp_var is Dictionary:
		var mp_d: Dictionary = mp_var as Dictionary
		for pid_k in mp_d.keys():
			var p_v: Variant = mp_d.get(pid_k, {})
			if p_v is Dictionary:
				member_progression[str(pid_k)] = (p_v as Dictionary).duplicate(true)
	for cid_var in DataLoader.characters.keys():
		_ensure_progression_entry(str(cid_var), 0)

	box_stash.clear()
	if state_data.has("box_stash"):
		var bs_var: Variant = state_data.get("box_stash", [])
		if bs_var is Array:
			for iv in (bs_var as Array):
				box_stash.append(str(iv))
	else:
		box_stash = ["perfecto_cloute", "parka_anonyme", "cassettes_tdk"]

	active_group_id = int(state_data.get("active_group_id", 0))
	current_station_idx = int(state_data.get("current_station_idx", 0))
	last_encounter_outcome = str(state_data.get("last_encounter_outcome", ""))
	current_zoom_level = clampi(int(state_data.get("current_zoom_level", 4)), 1, 4)
	current_region_id = str(state_data.get("current_region_id", "idf"))
	current_department_id = str(state_data.get("current_department_id", "dept_93"))
	current_city_id = str(state_data.get("current_city_id", "cradon_les_gonesse"))
	has_active_session = true

	var emit_id: String = current_region_id
	if current_zoom_level == 2:
		emit_id = current_department_id
	elif current_zoom_level == 3:
		emit_id = current_city_id
	elif current_zoom_level == 4:
		emit_id = get_active_location_id()

	phase_changed.emit(phase)
	active_group_changed.emit(active_group_id)
	zoom_changed.emit(current_zoom_level, emit_id)
	state_changed.emit()
