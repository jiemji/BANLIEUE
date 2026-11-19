extends Node

signal state_changed
signal phase_changed(new_phase: String)
signal active_group_changed(group_id: int)
signal log_added(entry: String)

var phase: String = "day" # "day", "twilight", "night"
var clock_minutes: int = 17 * 60 + 30
var francs: int = 25
var faveurs: int = 0
var notoriete: int = 1
var fasa_bonus: int = 0

var flags: Dictionary = {}
var clues: Array[String] = []
var activity_log: Array[String] = []

var squad_members: Array[String] = []
var member_states: Dictionary = {} # char_id -> {moral, moral_max, location_id, group_id, order_label, stress_active}
var active_group_id: int = 0
var current_station_idx: int = 0
var last_encounter_outcome: String = ""

func _ready() -> void:
	reset_new_slice()

func reset_new_slice() -> void:
	phase = "day"
	clock_minutes = 17 * 60 + 30
	francs = 25
	faveurs = 0
	notoriete = 1
	fasa_bonus = 0
	flags.clear()
	clues.clear()
	activity_log.clear()
	squad_members.clear()
	member_states.clear()
	active_group_id = 0
	current_station_idx = 0
	last_encounter_outcome = ""

	if DataLoader.characters.is_empty():
		DataLoader.load_all()

	for cid_var in DataLoader.characters.keys():
		var cid: String = str(cid_var)
		var cdef: Dictionary = DataLoader.get_character(cid)
		var in_default: bool = bool(cdef.get("in_squad_default", false))
		var m_start: int = int(cdef.get("moral_start", 60))
		var m_max: int = int(cdef.get("moral_max", 100))
		var threshold: int = int(cdef.get("stress_threshold", 35))
		member_states[cid] = {
			"moral": m_start,
			"moral_max": m_max,
			"location_id": "box_garage",
			"group_id": 0,
			"order_label": "En bande",
			"stress_active": m_start <= threshold
		}
		if in_default:
			squad_members.append(cid)

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

func is_member_in_active_group(char_id: String) -> bool:
	var active_ids: Array[String] = get_active_group_members()
	return active_ids.has(char_id)

func get_total_fasa() -> int:
	var best_fasa: int = 0
	var active_ids: Array[String] = get_active_group_members()
	for cid in active_ids:
		var cdef: Dictionary = DataLoader.get_character(cid)
		var cf: int = int(cdef.get("fasa", 2))
		if cf > best_fasa:
			best_fasa = cf
	var size_bonus: int = max(0, active_ids.size() - 1)
	return best_fasa + fasa_bonus + size_bonus

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
	var m_max: int = int(st.get("moral_max", 100))
	var old_m: int = int(st.get("moral", 60))
	var new_m: int = clampi(old_m + delta, 0, m_max)
	var threshold: int = int(cdef.get("stress_threshold", 35))
	st["moral"] = new_m
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
		var st: Dictionary = get_member_state(char_id)
		st["location_id"] = get_active_location_id()
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
