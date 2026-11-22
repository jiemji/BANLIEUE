extends Node

var characters: Dictionary = {}
var regions: Dictionary = {}
var departments: Dictionary = {}
var cities: Dictionary = {}
var interiors: Dictionary = {}
var locations: Dictionary = {}
var location_order: Array[String] = []
var dialogues: Dictionary = {}
var encounters: Dictionary = {}
var radio_stations: Array[Dictionary] = []

var player_portraits: Array[Dictionary] = []
var player_archetypes: Array[Dictionary] = []
var player_default_names: Array[String] = []
var skills_catalog: Array[Dictionary] = []
var skills_by_id: Dictionary = {}
var equipment_catalog: Dictionary = {}
var _base_leader_def: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	characters.clear()
	regions.clear()
	departments.clear()
	cities.clear()
	interiors.clear()
	locations.clear()
	location_order.clear()
	dialogues.clear()
	encounters.clear()
	radio_stations.clear()
	player_portraits.clear()
	player_archetypes.clear()
	player_default_names.clear()
	skills_catalog.clear()
	skills_by_id.clear()
	equipment_catalog.clear()
	_base_leader_def.clear()

	var chars_data: Variant = _read_json("res://data/characters.json")
	if chars_data is Dictionary:
		var char_list: Variant = (chars_data as Dictionary).get("characters", [])
		if char_list is Array:
			for item in (char_list as Array):
				if item is Dictionary:
					var d: Dictionary = item as Dictionary
					var cid: String = str(d.get("id", ""))
					if cid != "":
						characters[cid] = d
						if cid == "leader":
							_base_leader_def = d.duplicate(true)

	var prof_data: Variant = _read_json("res://data/player_profiles.json")
	if prof_data is Dictionary:
		var pd: Dictionary = prof_data as Dictionary
		var dn_var: Variant = pd.get("default_names", [])
		if dn_var is Array:
			for nv in (dn_var as Array):
				var ns: String = str(nv).strip_edges()
				if ns != "":
					player_default_names.append(ns)
		var port_var: Variant = pd.get("portraits", [])
		if port_var is Array:
			for pv in (port_var as Array):
				if pv is Dictionary:
					player_portraits.append(pv as Dictionary)
		var arch_var: Variant = pd.get("archetypes", [])
		if arch_var is Array:
			for av in (arch_var as Array):
				if av is Dictionary:
					player_archetypes.append(av as Dictionary)

	_load_world_hierarchy()

	var dlg_data: Variant = _read_json("res://data/dialogues.json")
	if dlg_data is Dictionary:
		var dlg_map: Variant = (dlg_data as Dictionary).get("dialogues", {})
		if dlg_map is Dictionary:
			dialogues = dlg_map as Dictionary

	var enc_data: Variant = _read_json("res://data/timeline_encounters.json")
	if enc_data is Dictionary:
		var enc_map: Variant = (enc_data as Dictionary).get("encounters", {})
		if enc_map is Dictionary:
			encounters = enc_map as Dictionary

	var radio_data: Variant = _read_json("res://data/radio_fm.json")
	if radio_data is Dictionary:
		var st_list: Variant = (radio_data as Dictionary).get("stations", [])
		if st_list is Array:
			for item in (st_list as Array):
				if item is Dictionary:
					radio_stations.append(item as Dictionary)

	var eq_data: Variant = _read_json("res://data/equipment.json")
	if eq_data is Dictionary:
		var eqd: Dictionary = eq_data as Dictionary
		var sk_var: Variant = eqd.get("skills_catalog", [])
		if sk_var is Array:
			for sv in (sk_var as Array):
				if sv is Dictionary:
					var sd: Dictionary = sv as Dictionary
					var sid: String = str(sd.get("id", ""))
					if sid != "":
						skills_catalog.append(sd)
						skills_by_id[sid] = sd
		var it_var: Variant = eqd.get("equipment", [])
		if it_var is Array:
			for iv in (it_var as Array):
				if iv is Dictionary:
					var idict: Dictionary = iv as Dictionary
					var iid: String = str(idict.get("id", ""))
					if iid != "":
						equipment_catalog[iid] = idict

func _load_world_hierarchy() -> void:
	var idf_var: Variant = _read_json("res://data/world/idf.json")
	if not (idf_var is Dictionary):
		return
	var idf: Dictionary = idf_var as Dictionary
	var rid: String = str(idf.get("id", "idf"))
	regions[rid] = idf

	var dept_children_var: Variant = idf.get("children", [])
	if not (dept_children_var is Array):
		return
	for dc_var in (dept_children_var as Array):
		if not (dc_var is Dictionary):
			continue
		var dc: Dictionary = dc_var as Dictionary
		var dept_file: String = str(dc.get("child_file", ""))
		if dept_file == "":
			continue
		var dept_var: Variant = _read_json(dept_file)
		if not (dept_var is Dictionary):
			continue
		var dept: Dictionary = dept_var as Dictionary
		var did: String = str(dept.get("id", ""))
		if did != "":
			departments[did] = dept

		var city_children_var: Variant = dept.get("children", [])
		if not (city_children_var is Array):
			continue
		for cc_var in (city_children_var as Array):
			if not (cc_var is Dictionary):
				continue
			var cc: Dictionary = cc_var as Dictionary
			var city_file: String = str(cc.get("child_file", ""))
			if city_file == "":
				continue
			var city_var: Variant = _read_json(city_file)
			if not (city_var is Dictionary):
				continue
			var city: Dictionary = city_var as Dictionary
			var cid: String = str(city.get("id", ""))
			if cid != "":
				cities[cid] = city

			var by_id_file: Dictionary = {}
			var b_children_var: Variant = city.get("children", [])
			if b_children_var is Array:
				for bc_var in (b_children_var as Array):
					if bc_var is Dictionary:
						var bc: Dictionary = bc_var as Dictionary
						var bid: String = str(bc.get("id", ""))
						var bfile: String = str(bc.get("interior_file", ""))
						if bid != "" and bfile != "":
							by_id_file[bid] = bfile

			var ordered_ids: Array[String] = []
			var order_var: Variant = city.get("locations_order", [])
			if order_var is Array:
				for ov in (order_var as Array):
					var olid: String = str(ov)
					if olid != "" and by_id_file.has(olid):
						ordered_ids.append(olid)
			for key_var in by_id_file.keys():
				var klid: String = str(key_var)
				if not ordered_ids.has(klid):
					ordered_ids.append(klid)

			for lid in ordered_ids:
				var ifile: String = str(by_id_file.get(lid, ""))
				if ifile == "":
					continue
				var int_var: Variant = _read_json(ifile)
				if int_var is Dictionary:
					var ind: Dictionary = int_var as Dictionary
					interiors[lid] = ind
					locations[lid] = ind
					if not location_order.has(lid):
						location_order.append(lid)

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("DataLoader: fichier JSON introuvable: " + path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: impossible d'ouvrir: " + path)
		return null
	var txt: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		push_error("DataLoader: JSON invalide dans: " + path)
	return parsed

func get_character(char_id: String) -> Dictionary:
	var val: Variant = characters.get(char_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func get_region(region_id: String) -> Dictionary:
	var val: Variant = regions.get(region_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func get_department(dept_id: String) -> Dictionary:
	var val: Variant = departments.get(dept_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func get_city(city_id: String) -> Dictionary:
	var val: Variant = cities.get(city_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func get_interior(loc_id: String) -> Dictionary:
	var val: Variant = interiors.get(loc_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func get_location(loc_id: String) -> Dictionary:
	return get_interior(loc_id)

func get_dialogue(dlg_id: String) -> Dictionary:
	var val: Variant = dialogues.get(dlg_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func get_encounter(enc_id: String) -> Dictionary:
	var val: Variant = encounters.get(enc_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func get_skill_def(skill_id: String) -> Dictionary:
	var val: Variant = skills_by_id.get(skill_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func get_equipment_def(item_id: String) -> Dictionary:
	var val: Variant = equipment_catalog.get(item_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func get_all_skill_ids() -> Array[String]:
	var res: Array[String] = []
	for sd in skills_catalog:
		res.append(str(sd.get("id", "")))
	return res

## Retourne la définition d'un portrait joueur depuis player_profiles.json (ou le premier disponible).
func get_portrait_def(portrait_id: String) -> Dictionary:
	for pv in player_portraits:
		if str(pv.get("id", "")) == portrait_id:
			return pv
	if not player_portraits.is_empty():
		return player_portraits[0]
	return {}

## Retourne la définition d'un archétype social joueur depuis player_profiles.json.
func get_archetype_def(archetype_id: String) -> Dictionary:
	for av in player_archetypes:
		if str(av.get("id", "")) == archetype_id:
			return av
	if not player_archetypes.is_empty():
		return player_archetypes[0]
	return {}

func _res_file_exists(res_path: String) -> bool:
	if res_path == "":
		return false
	if ResourceLoader.exists(res_path):
		return true
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	return FileAccess.file_exists(abs_path)

## Applique le profil du protagoniste (nom, portrait/pion vérifiés sur disque, stats et spécialité) sur characters["leader"].
func apply_leader_profile(profile: Dictionary) -> void:
	if _base_leader_def.is_empty():
		var existing: Variant = characters.get("leader", {})
		if existing is Dictionary:
			_base_leader_def = (existing as Dictionary).duplicate(true)
	var merged: Dictionary = _base_leader_def.duplicate(true)

	var chosen_name: String = str(profile.get("name", "Alex")).strip_edges()
	if chosen_name != "":
		merged["name"] = chosen_name

	var port_id: String = str(profile.get("portrait_id", "player_01"))
	var port_def: Dictionary = get_portrait_def(port_id)
	var p_path: String = str(port_def.get("portrait", str(profile.get("portrait_path", ""))))
	var pw_path: String = str(port_def.get("pawn", str(profile.get("pawn_path", ""))))
	if _res_file_exists(p_path):
		merged["portrait"] = p_path
	if _res_file_exists(pw_path):
		merged["pawn"] = pw_path

	var arch_id: String = str(profile.get("archetype_id", "mains_noires"))
	var arch_def: Dictionary = get_archetype_def(arch_id)
	if not arch_def.is_empty():
		var keys_to_copy: Array[String] = [
			"attitude", "aura", "moral_start", "moral_max", "stress_threshold",
			"stress_name", "crisis_label", "specialty_id", "specialty_name", "specialty_desc",
			"age", "home_location", "characteristics", "skills", "default_equipment"
		]
		for k in keys_to_copy:
			if arch_def.has(k):
				var v: Variant = arch_def.get(k)
				if v is Dictionary:
					merged[k] = (v as Dictionary).duplicate(true)
				elif v is Array:
					merged[k] = (v as Array).duplicate(true)
				else:
					merged[k] = v
		var arch_title: String = str(arch_def.get("title", ""))
		if arch_title != "":
			merged["role"] = arch_title
		var arch_story: String = str(arch_def.get("story", ""))
		if arch_story != "":
			merged["bio"] = arch_story
		var arch_stakes: String = str(arch_def.get("stakes", ""))
		if arch_stakes != "":
			merged["arc_summary"] = arch_stakes

	characters["leader"] = merged
