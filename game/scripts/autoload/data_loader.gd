extends Node

const MODULAR_CANVAS_W: int = 256
const MODULAR_CANVAS_H: int = 526

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
var _part_image_cache: Dictionary = {}
var _modular_tex_cache: Dictionary = {}

func _ready() -> void:
	load_all()

## Vide les caches mémoire des pièces modulaires et textures assemblées à la fermeture de l'arbre.
func _exit_tree() -> void:
	_part_image_cache.clear()
	_modular_tex_cache.clear()

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
	_part_image_cache.clear()
	_modular_tex_cache.clear()

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

## Charge et normalise en RGBA8 (avec cache mémoire) une pièce graphique modulaire (tête, haut ou bas).
func _load_part_image(res_path: String) -> Image:
	if res_path == "":
		return null
	if _part_image_cache.has(res_path):
		var cached_v: Variant = _part_image_cache.get(res_path, null)
		if cached_v is Image:
			return cached_v as Image
		return null
	var img: Image = null
	if ResourceLoader.exists(res_path):
		var loaded: Resource = load(res_path)
		if loaded is Texture2D:
			var timg: Image = (loaded as Texture2D).get_image()
			if timg != null and not timg.is_empty():
				img = timg.duplicate()
	if img == null:
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var disk_img: Image = Image.load_from_file(abs_path)
			if disk_img != null and not disk_img.is_empty():
				img = disk_img
	if img != null:
		if img.is_compressed():
			img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
	_part_image_cache[res_path] = img
	return img

## Blende une sous-région d'une pièce modulaire centrée horizontalement et alignée sur le bas du canevas 256x526.
func _blend_part_region(canvas: Image, part_img: Image, region: Rect2i) -> void:
	if part_img == null or part_img.is_empty():
		return
	var pw: int = part_img.get_width()
	var ph: int = part_img.get_height()
	var ox: int = int((MODULAR_CANVAS_W - pw) * 0.5)
	var oy: int = MODULAR_CANVAS_H - ph
	var full_src: Rect2i = Rect2i(region.position.x - ox, region.position.y - oy, region.size.x, region.size.y)
	var clamped: Rect2i = full_src.intersection(Rect2i(0, 0, pw, ph))
	if clamped.size.x <= 0 or clamped.size.y <= 0:
		return
	var dst_pos: Vector2i = Vector2i(ox + clamped.position.x, oy + clamped.position.y)
	canvas.blend_rect(part_img, clamped, dst_pos)

## Assemble et met en cache un sprite en pied 256x526 à partir de 3 calques RGBA (tête, haut+bras, bas+pieds).
func assemble_modular_pawn(head_path: String, top_path: String, bottom_path: String) -> Texture2D:
	var cache_key: String = "%s|%s|%s" % [head_path, top_path, bottom_path]
	if _modular_tex_cache.has(cache_key):
		var c_tex_v: Variant = _modular_tex_cache.get(cache_key, null)
		if c_tex_v is Texture2D:
			return c_tex_v as Texture2D
		return null

	var h_img: Image = _load_part_image(head_path)
	var t_img: Image = _load_part_image(top_path)
	var b_img: Image = _load_part_image(bottom_path)
	if h_img == null and t_img == null and b_img == null:
		_modular_tex_cache[cache_key] = null
		return null

	var canvas: Image = Image.create_empty(MODULAR_CANVAS_W, MODULAR_CANVAS_H, false, Image.FORMAT_RGBA8)
	if b_img != null:
		_blend_part_region(canvas, b_img, Rect2i(0, 0, MODULAR_CANVAS_W, MODULAR_CANVAS_H))
	if h_img != null:
		_blend_part_region(canvas, h_img, Rect2i(0, 96, MODULAR_CANVAS_W, 48))
	if t_img != null:
		_blend_part_region(canvas, t_img, Rect2i(0, 0, MODULAR_CANVAS_W, MODULAR_CANVAS_H))
	if h_img != null:
		_blend_part_region(canvas, h_img, Rect2i(0, 0, MODULAR_CANVAS_W, 102))
		_blend_part_region(canvas, h_img, Rect2i(0, 102, 104, 34))
		_blend_part_region(canvas, h_img, Rect2i(152, 102, 104, 34))

	var tex: ImageTexture = ImageTexture.create_from_image(canvas)
	_modular_tex_cache[cache_key] = tex
	return tex

## Retourne la texture assemblée 256x526 depuis un dictionnaire d'apparence ({head, top/default_top, bottom/default_bottom}).
func get_appearance_pawn_texture(appearance: Dictionary) -> Texture2D:
	if appearance.is_empty():
		return null
	var head_p: String = str(appearance.get("head", ""))
	var top_p: String = str(appearance.get("top", str(appearance.get("default_top", ""))))
	var bot_p: String = str(appearance.get("bottom", str(appearance.get("default_bottom", ""))))
	return assemble_modular_pawn(head_p, top_p, bot_p)

## Applique le profil du protagoniste (nom, portrait BD, apparence modulaire 3 parties, stats et spécialité) sur characters["leader"].
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
	if _res_file_exists(p_path):
		merged["portrait"] = p_path

	var base_app_var: Variant = _base_leader_def.get("appearance", {})
	var base_app: Dictionary = (base_app_var as Dictionary).duplicate(true) if (base_app_var is Dictionary) else {}
	var head_p: String = str(port_def.get("head", str(profile.get("head_path", str(base_app.get("head", ""))))))
	var top_p: String = str(port_def.get("default_top", str(profile.get("default_top_path", str(base_app.get("default_top", ""))))))
	var bot_p: String = str(port_def.get("default_bottom", str(profile.get("default_bottom_path", str(base_app.get("default_bottom", ""))))))
	merged["appearance"] = {
		"head": head_p if _res_file_exists(head_p) else str(base_app.get("head", "")),
		"default_top": top_p if _res_file_exists(top_p) else str(base_app.get("default_top", "")),
		"default_bottom": bot_p if _res_file_exists(bot_p) else str(base_app.get("default_bottom", ""))
	}

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
