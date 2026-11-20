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
