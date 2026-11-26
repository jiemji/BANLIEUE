## Chargeur modulaire de Packs de Scénarios isolés (Option 1B) + Cache centralisé de textures et assemblage RGBA 256×526.
extends Node

const MODULAR_CANVAS_W: int = 256
const MODULAR_CANVAS_H: int = 526
const SCENARIOS_ROOT: String = "res://data/scenarios"
const SCENARIOS_INDEX_PATH: String = "res://data/scenarios_index.json"

var scenarios_catalog: Array[Dictionary] = []
var scenarios_by_id: Dictionary = {}
var active_scenario_id: String = ""
var scenario_manifest: Dictionary = {}

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
var combat_actions_by_id: Dictionary = {}
var combat_actions_order: Array[String] = []
var specialties_by_id: Dictionary = {}
var props_catalog: Dictionary = {}

var _base_leader_def: Dictionary = {}
var _part_image_cache: Dictionary = {}
var _modular_tex_cache: Dictionary = {}
var _texture_cache: Dictionary = {}

func _ready() -> void:
	load_all()

## Vide les caches mémoire des pièces modulaires et textures assemblées à la fermeture de l'arbre.
func _exit_tree() -> void:
	_part_image_cache.clear()
	_modular_tex_cache.clear()
	_texture_cache.clear()

## Découvre automatiquement tous les packs de scénarios isolés présents dans res://data/scenarios/.
func discover_scenarios() -> void:
	scenarios_catalog.clear()
	scenarios_by_id.clear()
	var ordered_ids: Array[String] = []

	if _res_file_exists(SCENARIOS_INDEX_PATH):
		var idx_var: Variant = _read_json(SCENARIOS_INDEX_PATH)
		if idx_var is Dictionary:
			var idx_d: Dictionary = idx_var as Dictionary
			var sc_arr_var: Variant = idx_d.get("scenarios", [])
			if sc_arr_var is Array:
				for sv in (sc_arr_var as Array):
					var sid: String = str(sv).strip_edges()
					if sid != "" and not ordered_ids.has(sid):
						ordered_ids.append(sid)

	var dir: DirAccess = DirAccess.open(SCENARIOS_ROOT)
	if dir != null:
		var found_dirs: Array[String] = []
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while entry != "":
			if dir.current_is_dir() and not entry.begins_with(".") and not entry.begins_with("_"):
				found_dirs.append(entry)
			entry = dir.get_next()
		dir.list_dir_end()
		found_dirs.sort()
		for fd in found_dirs:
			if not ordered_ids.has(fd):
				ordered_ids.append(fd)

	for sid in ordered_ids:
		var manifest_path: String = "%s/%s/scenario.json" % [SCENARIOS_ROOT, sid]
		if not _res_file_exists(manifest_path):
			continue
		var man_var: Variant = _read_json(manifest_path)
		if man_var is Dictionary:
			var man: Dictionary = (man_var as Dictionary).duplicate(true)
			man["id"] = str(man.get("id", sid))
			man["base_dir"] = "%s/%s" % [SCENARIOS_ROOT, sid]
			scenarios_catalog.append(man)
			scenarios_by_id[str(man.get("id", sid))] = man

## Retourne l'identifiant du scénario par défaut défini dans scenarios_index.json (ou le premier pack découvert).
func get_default_scenario_id() -> String:
	if scenarios_catalog.is_empty():
		discover_scenarios()
	if _res_file_exists(SCENARIOS_INDEX_PATH):
		var idx_var: Variant = _read_json(SCENARIOS_INDEX_PATH)
		if idx_var is Dictionary:
			var def_id: String = str((idx_var as Dictionary).get("default_scenario_id", ""))
			if def_id != "" and scenarios_by_id.has(def_id):
				return def_id
	if not scenarios_catalog.is_empty():
		return str(scenarios_catalog[0].get("id", ""))
	return ""

## Retourne le manifeste d'un scénario par son identifiant.
func get_scenario_def(scenario_id: String) -> Dictionary:
	if scenarios_by_id.is_empty():
		discover_scenarios()
	var val: Variant = scenarios_by_id.get(scenario_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

## Retourne le dossier racine res:// du pack scénario demandé (ou du scénario actif).
func get_scenario_base_dir(scenario_id: String = "") -> String:
	var sid: String = scenario_id if scenario_id != "" else active_scenario_id
	var sdef: Dictionary = get_scenario_def(sid)
	var bdir: String = str(sdef.get("base_dir", ""))
	if bdir != "":
		return bdir
	return "%s/%s" % [SCENARIOS_ROOT, sid]

## Résout un chemin relatif au pack scénario courant ou conserve un chemin res:// / user:// absolu.
func resolve_scenario_path(path: String, scenario_id: String = "") -> String:
	var p: String = path.strip_edges()
	if p == "":
		return ""
	if p.begins_with("res://") or p.begins_with("user://"):
		return p
	return "%s/%s" % [get_scenario_base_dir(scenario_id), p.trim_prefix("/")]

## S'assure que le pack du scénario demandé est chargé comme scénario actif.
func ensure_scenario_loaded(scenario_id: String) -> bool:
	if scenarios_catalog.is_empty():
		discover_scenarios()
	var target_id: String = scenario_id if (scenario_id != "" and scenarios_by_id.has(scenario_id)) else get_default_scenario_id()
	if target_id == "":
		return false
	if active_scenario_id != target_id or characters.is_empty():
		load_all(target_id)
	return active_scenario_id == target_id

## Charge intégralement les catalogues isolés du pack scénario demandé.
func load_all(scenario_id: String = "") -> void:
	discover_scenarios()
	var target_id: String = scenario_id.strip_edges()
	if target_id == "" or not scenarios_by_id.has(target_id):
		target_id = active_scenario_id if (active_scenario_id != "" and scenarios_by_id.has(active_scenario_id)) else get_default_scenario_id()

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
	combat_actions_by_id.clear()
	combat_actions_order.clear()
	specialties_by_id.clear()
	props_catalog.clear()
	_base_leader_def.clear()
	_part_image_cache.clear()
	_modular_tex_cache.clear()
	_texture_cache.clear()

	if target_id == "":
		push_error("DataLoader: aucun pack de scénario trouvé dans " + SCENARIOS_ROOT)
		return

	active_scenario_id = target_id
	scenario_manifest = get_scenario_def(target_id).duplicate(true)
	var pack_root: String = get_scenario_base_dir(target_id)
	var leader_cid: String = get_leader_char_id()

	# 1. Règles du pack (skills, actions de combat, spécialités, mobilier isométrique)
	for rule_file in _list_json_files(pack_root + "/rules"):
		var rdata: Variant = _read_json(rule_file)
		if rdata is Dictionary:
			_ingest_rules_dict(rdata as Dictionary)

	# 2. Équipements (et compétences éventuelles intégrées)
	for eq_file in _list_json_files(pack_root + "/equipment"):
		var eq_var: Variant = _read_json(eq_file)
		if eq_var is Dictionary:
			_ingest_equipment_dict(eq_var as Dictionary)

	# 3. Personnages & Profils joueur
	for ch_file in _list_json_files(pack_root + "/characters"):
		var ch_var: Variant = _read_json(ch_file)
		if ch_var is Dictionary:
			_ingest_characters_or_profiles(ch_var as Dictionary, leader_cid)

	# 4. Hiérarchie cartographique N1-N4 + intérieurs autonomes éventuels
	_load_world_hierarchy(pack_root)
	for int_file in _list_json_files(pack_root + "/maps/interiors"):
		var int_var: Variant = _read_json(int_file)
		if int_var is Dictionary:
			var ind: Dictionary = int_var as Dictionary
			var lid: String = str(ind.get("id", ""))
			if lid != "" and not interiors.has(lid):
				interiors[lid] = ind
				locations[lid] = ind
				location_order.append(lid)

	# 5. Dialogues
	for dlg_file in _list_json_files(pack_root + "/dialogues"):
		var dlg_var: Variant = _read_json(dlg_file)
		if dlg_var is Dictionary:
			var dmap_v: Variant = (dlg_var as Dictionary).get("dialogues", {})
			if dmap_v is Dictionary:
				var dmap: Dictionary = dmap_v as Dictionary
				for dk in dmap.keys():
					var dv: Variant = dmap.get(dk)
					if dv is Dictionary:
						dialogues[str(dk)] = dv as Dictionary

	# 6. Rencontres tactiques
	for enc_file in _list_json_files(pack_root + "/encounters"):
		var enc_var: Variant = _read_json(enc_file)
		if enc_var is Dictionary:
			var emap_v: Variant = (enc_var as Dictionary).get("encounters", {})
			if emap_v is Dictionary:
				var emap: Dictionary = emap_v as Dictionary
				for ek in emap.keys():
					var ev: Variant = emap.get(ek)
					if ev is Dictionary:
						encounters[str(ek)] = ev as Dictionary

	# 7. Bande FM (radio_fm.json ou dossier radio/)
	var radio_single: String = pack_root + "/radio_fm.json"
	if _res_file_exists(radio_single):
		var rad_v: Variant = _read_json(radio_single)
		if rad_v is Dictionary:
			_ingest_radio_dict(rad_v as Dictionary)
	for rad_file in _list_json_files(pack_root + "/radio"):
		var rad_v2: Variant = _read_json(rad_file)
		if rad_v2 is Dictionary:
			_ingest_radio_dict(rad_v2 as Dictionary)

func _list_json_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	var names: Array[String] = []
	dir.list_dir_begin()
	var fn: String = dir.get_next()
	while fn != "":
		if not dir.current_is_dir() and fn.ends_with(".json"):
			names.append(fn)
		fn = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for n in names:
		out.append("%s/%s" % [dir_path, n])
	return out

func _ingest_rules_dict(rd: Dictionary) -> void:
	var sk_var: Variant = rd.get("skills_catalog", [])
	if sk_var is Array:
		for sv in (sk_var as Array):
			if sv is Dictionary:
				var sd: Dictionary = sv as Dictionary
				var sid: String = str(sd.get("id", ""))
				if sid != "" and not skills_by_id.has(sid):
					skills_catalog.append(sd)
					skills_by_id[sid] = sd

	var act_var: Variant = rd.get("actions", [])
	if act_var is Array:
		for av in (act_var as Array):
			if av is Dictionary:
				var ad: Dictionary = av as Dictionary
				var aid: String = str(ad.get("id", ""))
				if aid != "":
					combat_actions_by_id[aid] = ad
					if not combat_actions_order.has(aid):
						combat_actions_order.append(aid)

	var sp_var: Variant = rd.get("specialties", [])
	if sp_var is Array:
		for spv in (sp_var as Array):
			if spv is Dictionary:
				var spd: Dictionary = spv as Dictionary
				var spid: String = str(spd.get("id", ""))
				if spid != "":
					specialties_by_id[spid] = spd

	var pr_var: Variant = rd.get("props", {})
	if pr_var is Dictionary:
		var prd: Dictionary = pr_var as Dictionary
		for pk in prd.keys():
			var pv: Variant = prd.get(pk)
			if pv is Dictionary:
				props_catalog[str(pk)] = pv as Dictionary

func _ingest_equipment_dict(eqd: Dictionary) -> void:
	_ingest_rules_dict(eqd)
	var it_var: Variant = eqd.get("equipment", [])
	if it_var is Array:
		for iv in (it_var as Array):
			if iv is Dictionary:
				var idict: Dictionary = iv as Dictionary
				var iid: String = str(idict.get("id", ""))
				if iid != "":
					equipment_catalog[iid] = idict
					# Permet à un équipement de déclarer directement son bloc combat_action sans toucher rules/combat_actions.json
					var acts_var: Variant = idict.get("unlocks_actions", [])
					if acts_var is Array:
						for uav in (acts_var as Array):
							if uav is Dictionary:
								var uad: Dictionary = uav as Dictionary
								var uaid: String = str(uad.get("id", ""))
								if uaid != "" and uad.has("combat_action") and uad.get("combat_action") is Dictionary:
									var cad: Dictionary = (uad.get("combat_action") as Dictionary).duplicate(true)
									cad["id"] = uaid
									cad["is_equipment"] = true
									if not cad.has("short_label"):
										cad["short_label"] = str(uad.get("label", uaid))
									combat_actions_by_id[uaid] = cad

func _ingest_characters_or_profiles(d: Dictionary, leader_cid: String) -> void:
	var char_list: Variant = d.get("characters", [])
	if char_list is Array:
		for item in (char_list as Array):
			if item is Dictionary:
				var cd: Dictionary = item as Dictionary
				var cid: String = str(cd.get("id", ""))
				if cid != "":
					characters[cid] = cd
					if cid == leader_cid:
						_base_leader_def = cd.duplicate(true)
	elif d.has("id") and d.has("appearance") and not d.has("archetypes"):
		var single_id: String = str(d.get("id", ""))
		if single_id != "":
			characters[single_id] = d
			if single_id == leader_cid:
				_base_leader_def = d.duplicate(true)

	var dn_var: Variant = d.get("default_names", [])
	if dn_var is Array:
		for nv in (dn_var as Array):
			var ns: String = str(nv).strip_edges()
			if ns != "" and not player_default_names.has(ns):
				player_default_names.append(ns)

	var port_var: Variant = d.get("portraits", [])
	if port_var is Array:
		for pv in (port_var as Array):
			if pv is Dictionary:
				player_portraits.append(pv as Dictionary)

	var arch_var: Variant = d.get("archetypes", [])
	if arch_var is Array:
		for av in (arch_var as Array):
			if av is Dictionary:
				player_archetypes.append(av as Dictionary)

func _ingest_radio_dict(rd: Dictionary) -> void:
	var st_list: Variant = rd.get("stations", [])
	if st_list is Array:
		for item in (st_list as Array):
			if item is Dictionary:
				radio_stations.append(item as Dictionary)

func _load_world_hierarchy(pack_root: String) -> void:
	var root_rel: String = str(scenario_manifest.get("world_root_file", "world/idf.json"))
	var root_path: String = resolve_scenario_path(root_rel)
	if root_path == "" or not _res_file_exists(root_path):
		return
	var reg_var: Variant = _read_json(root_path)
	if not (reg_var is Dictionary):
		return
	var reg: Dictionary = reg_var as Dictionary
	var rid: String = str(reg.get("id", "region_0"))
	regions[rid] = reg

	var dept_children_var: Variant = reg.get("children", [])
	if not (dept_children_var is Array):
		return
	for dc_var in (dept_children_var as Array):
		if not (dc_var is Dictionary):
			continue
		var dc: Dictionary = dc_var as Dictionary
		var dept_file: String = resolve_scenario_path(str(dc.get("child_file", "")))
		if dept_file == "" or not _res_file_exists(dept_file):
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
			var city_file: String = resolve_scenario_path(str(cc.get("child_file", "")))
			if city_file == "" or not _res_file_exists(city_file):
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
						var bfile: String = resolve_scenario_path(str(bc.get("interior_file", "")))
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
				if ifile == "" or not _res_file_exists(ifile):
					continue
				var int_var: Variant = _read_json(ifile)
				if int_var is Dictionary:
					var ind: Dictionary = int_var as Dictionary
					interiors[lid] = ind
					locations[lid] = ind
					if not location_order.has(lid):
						location_order.append(lid)

	if pack_root == "":
		return

func _read_json(path: String) -> Variant:
	var resolved: String = resolve_scenario_path(path)
	if not FileAccess.file_exists(resolved):
		push_error("DataLoader: fichier JSON introuvable: " + resolved)
		return null
	var file: FileAccess = FileAccess.open(resolved, FileAccess.READ)
	if file == null:
		push_error("DataLoader: impossible d'ouvrir: " + resolved)
		return null
	var txt: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		push_error("DataLoader: JSON invalide dans: " + resolved)
	return parsed

## Retourne l'identifiant du personnage Leader défini par le scénario actif.
func get_leader_char_id() -> String:
	var lcid: String = str(scenario_manifest.get("leader_char_id", "leader"))
	return lcid if lcid != "" else "leader"

## Retourne l'identifiant du lieu de départ défini par le scénario actif.
func get_start_location_id() -> String:
	var sh_v: Variant = scenario_manifest.get("start_hierarchy", {})
	if sh_v is Dictionary:
		var lid: String = str((sh_v as Dictionary).get("location_id", ""))
		if lid != "":
			return lid
	if not location_order.is_empty():
		return location_order[0]
	return ""

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

func get_combat_action_def(action_id: String) -> Dictionary:
	var val: Variant = combat_actions_by_id.get(action_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func get_specialty_def(spec_id: String) -> Dictionary:
	var val: Variant = specialties_by_id.get(spec_id, {})
	if val is Dictionary:
		return val as Dictionary
	return {}

func get_prop_def(prop_type: String) -> Dictionary:
	var val: Variant = props_catalog.get(prop_type, {})
	if val is Dictionary:
		return val as Dictionary
	var fb: Variant = props_catalog.get("box", {})
	if fb is Dictionary:
		return fb as Dictionary
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
	var resolved: String = resolve_scenario_path(res_path)
	if resolved == "":
		return false
	if ResourceLoader.exists(resolved):
		return true
	var abs_path: String = ProjectSettings.globalize_path(resolved)
	return FileAccess.file_exists(abs_path)

## Charge et met en cache une Texture2D depuis un chemin res:// ou relatif au pack scénario actif.
func load_texture_safe(res_path: String) -> Texture2D:
	var resolved: String = resolve_scenario_path(res_path)
	if resolved == "":
		return null
	if _texture_cache.has(resolved):
		var cached: Variant = _texture_cache.get(resolved, null)
		if cached is Texture2D:
			return cached as Texture2D
		return null
	var tex: Texture2D = null
	if ResourceLoader.exists(resolved):
		var loaded: Resource = load(resolved)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	if tex == null:
		var abs_path: String = ProjectSettings.globalize_path(resolved)
		if FileAccess.file_exists(abs_path):
			var img: Image = Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_texture_cache[resolved] = tex
	return tex

## Charge et normalise en RGBA8 (avec cache mémoire) une pièce graphique modulaire (tête, haut ou bas).
func _load_part_image(res_path: String) -> Image:
	var resolved: String = resolve_scenario_path(res_path)
	if resolved == "":
		return null
	if _part_image_cache.has(resolved):
		var cached_v: Variant = _part_image_cache.get(resolved, null)
		if cached_v is Image:
			return cached_v as Image
		return null
	var img: Image = null
	if ResourceLoader.exists(resolved):
		var loaded: Resource = load(resolved)
		if loaded is Texture2D:
			var timg: Image = (loaded as Texture2D).get_image()
			if timg != null and not timg.is_empty():
				img = timg.duplicate()
	if img == null:
		var abs_path: String = ProjectSettings.globalize_path(resolved)
		if FileAccess.file_exists(abs_path):
			var disk_img: Image = Image.load_from_file(abs_path)
			if disk_img != null and not disk_img.is_empty():
				img = disk_img
	if img != null:
		if img.is_compressed():
			img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
	_part_image_cache[resolved] = img
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
	var rh: String = resolve_scenario_path(head_path)
	var rt: String = resolve_scenario_path(top_path)
	var rb: String = resolve_scenario_path(bottom_path)
	var cache_key: String = "%s|%s|%s" % [rh, rt, rb]
	if _modular_tex_cache.has(cache_key):
		var c_tex_v: Variant = _modular_tex_cache.get(cache_key, null)
		if c_tex_v is Texture2D:
			return c_tex_v as Texture2D
		return null

	var h_img: Image = _load_part_image(rh)
	var t_img: Image = _load_part_image(rt)
	var b_img: Image = _load_part_image(rb)
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

## Applique le profil du protagoniste (nom, portrait BD, apparence modulaire 3 parties, stats et spécialité) sur le personnage Leader.
func apply_leader_profile(profile: Dictionary) -> void:
	var leader_cid: String = get_leader_char_id()
	if _base_leader_def.is_empty():
		var existing: Variant = characters.get(leader_cid, {})
		if existing is Dictionary:
			_base_leader_def = (existing as Dictionary).duplicate(true)
	var merged: Dictionary = _base_leader_def.duplicate(true)

	var default_name: String = player_default_names[0] if not player_default_names.is_empty() else "Alex"
	var chosen_name: String = str(profile.get("name", default_name)).strip_edges()
	if chosen_name != "":
		merged["name"] = chosen_name

	var port_id: String = str(profile.get("portrait_id", ""))
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

	var arch_id: String = str(profile.get("archetype_id", ""))
	var arch_def: Dictionary = get_archetype_def(arch_id)
	if not arch_def.is_empty():
		var keys_to_copy: Array[String] = [
			"attitude", "aura", "moral_start", "moral_max", "stress_threshold",
			"stress_name", "crisis_label", "crisis", "specialty_id", "specialty_name", "specialty_desc",
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

	characters[leader_cid] = merged
