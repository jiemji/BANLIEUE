extends Node

var characters: Dictionary = {}
var locations: Dictionary = {}
var location_order: Array[String] = []
var dialogues: Dictionary = {}
var encounters: Dictionary = {}
var radio_stations: Array[Dictionary] = []

func _ready() -> void:
	load_all()

func load_all() -> void:
	characters.clear()
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

	var locs_data: Variant = _read_json("res://data/locations.json")
	if locs_data is Dictionary:
		var loc_list: Variant = (locs_data as Dictionary).get("locations", [])
		if loc_list is Array:
			for item in (loc_list as Array):
				if item is Dictionary:
					var d: Dictionary = item as Dictionary
					var lid: String = str(d.get("id", ""))
					if lid != "":
						locations[lid] = d
						location_order.append(lid)

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

func get_location(loc_id: String) -> Dictionary:
	var val: Variant = locations.get(loc_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

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
