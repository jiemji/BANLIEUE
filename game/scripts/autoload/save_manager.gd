## Gestionnaire des 3 emplacements de sauvegarde manuels (Cassettes A, B, C).
## Sérialise et restaure GameState, l'identifiant du scénario actif et supporte l'import inter-scénarios (Option 3A).
extends Node

const SAVE_DIR: String = "user://saves"
const SLOT_COUNT: int = 3
const SLOT_LABELS: Array[String] = ["Cassette A", "Cassette B", "Cassette C"]
const SCHEMA_VERSION: int = 2

## Retourne le libellé d'affichage de la cassette pour un index 1..3.
func get_slot_label(slot_idx: int) -> String:
	var idx: int = clampi(slot_idx, 1, SLOT_COUNT) - 1
	return SLOT_LABELS[idx]

func get_slot_path(slot_idx: int) -> String:
	var safe_idx: int = clampi(slot_idx, 1, SLOT_COUNT)
	return "%s/slot_%d.json" % [SAVE_DIR, safe_idx]

func slot_exists(slot_idx: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot_idx))

## Indique si au moins une des 3 cassettes contient déjà une sauvegarde.
func has_any_save() -> bool:
	for i in range(1, SLOT_COUNT + 1):
		if slot_exists(i):
			return true
	return false

## Lit le contenu complet d'une cassette JSON (meta + leader_profile + game_state) sans modifier la session active.
func read_slot_full(slot_idx: int) -> Dictionary:
	var path: String = get_slot_path(slot_idx)
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var txt: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		return {}
	return parsed as Dictionary

## Lit uniquement le bloc meta et l'horodatage d'une cassette sans charger la partie.
func read_slot_meta(slot_idx: int) -> Dictionary:
	var data: Dictionary = read_slot_full(slot_idx)
	if data.is_empty():
		return {}
	var meta_var: Variant = data.get("meta", {})
	var meta: Dictionary = (meta_var as Dictionary).duplicate(true) if (meta_var is Dictionary) else {}
	meta["saved_at"] = str(data.get("saved_at", ""))
	if not meta.has("slot_label"):
		meta["slot_label"] = get_slot_label(slot_idx)
	var lp_var: Variant = data.get("leader_profile", {})
	if lp_var is Dictionary:
		var lp: Dictionary = lp_var as Dictionary
		if not meta.has("portrait_path"):
			meta["portrait_path"] = str(lp.get("portrait_path", ""))
	if not meta.has("scenario_id"):
		meta["scenario_id"] = DataLoader.get_default_scenario_id()
	if not meta.has("scenario_title"):
		var sdef: Dictionary = DataLoader.get_scenario_def(str(meta.get("scenario_id", "")))
		meta["scenario_title"] = str(sdef.get("title", str(meta.get("scenario_id", ""))))
	return meta

## Sauvegarde l'état courant de GameState, leader_profile et scenario_id sur la cassette demandée (1..3).
func save_slot(slot_idx: int) -> bool:
	var abs_dir: String = ProjectSettings.globalize_path(SAVE_DIR)
	var mk_err: Error = DirAccess.make_dir_recursive_absolute(abs_dir)
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		push_error("SaveManager: impossible de créer le dossier de sauvegarde: " + abs_dir)
		return false

	var profile: Dictionary = GameState.leader_profile.duplicate(true)
	var arch_id: String = str(profile.get("archetype_id", ""))
	var arch_def: Dictionary = DataLoader.get_archetype_def(arch_id)
	var arch_title: String = str(arch_def.get("title", arch_id))
	var loc_id: String = GameState.get_active_location_id()
	var loc_def: Dictionary = DataLoader.get_location(loc_id)
	var loc_name: String = str(loc_def.get("name", loc_id))
	var saved_at: String = Time.get_datetime_string_from_system(false, false)
	var scen_id: String = GameState.current_scenario_id if GameState.current_scenario_id != "" else DataLoader.active_scenario_id
	var scen_title: String = str(DataLoader.scenario_manifest.get("title", scen_id))

	var payload: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"saved_at": saved_at,
		"meta": {
			"slot_label": get_slot_label(slot_idx),
			"scenario_id": scen_id,
			"scenario_title": scen_title,
			"scenario_completed": GameState.scenario_completed,
			"leader_name": str(profile.get("name", "Alex")),
			"archetype_id": arch_id,
			"archetype_title": arch_title,
			"portrait_id": str(profile.get("portrait_id", "")),
			"portrait_path": str(profile.get("portrait_path", "")),
			"location_id": loc_id,
			"location_name": loc_name,
			"phase": GameState.phase,
			"clock_text": GameState.format_clock(),
			"squad_count": GameState.squad_members.size(),
			"francs": GameState.francs,
			"notoriete": GameState.notoriete
		},
		"leader_profile": profile,
		"game_state": GameState.to_save_dict()
	}

	var path: String = get_slot_path(slot_idx)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: impossible d'écrire: " + path)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

## Charge une cassette existante (1..3), bascule d'abord sur son pack scénario puis restaure GameState.
func load_slot(slot_idx: int) -> bool:
	var data: Dictionary = read_slot_full(slot_idx)
	if data.is_empty():
		return false
	var gs_var: Variant = data.get("game_state", {})
	var lp_var: Variant = data.get("leader_profile", {})
	var meta_var: Variant = data.get("meta", {})
	if not (gs_var is Dictionary) or not (lp_var is Dictionary):
		return false
	var gs_d: Dictionary = gs_var as Dictionary
	var meta_d: Dictionary = meta_var as Dictionary if meta_var is Dictionary else {}
	var scen_id: String = str(gs_d.get("scenario_id", str(meta_d.get("scenario_id", DataLoader.get_default_scenario_id()))))
	if not DataLoader.ensure_scenario_loaded(scen_id):
		return false
	GameState.load_from_save_dict(lp_var as Dictionary, gs_d)
	return true

## Supprime définitivement le fichier JSON d'une cassette (1..3).
func delete_slot(slot_idx: int) -> bool:
	var path: String = get_slot_path(slot_idx)
	if not FileAccess.file_exists(path):
		return false
	var abs_path: String = ProjectSettings.globalize_path(path)
	var err: Error = DirAccess.remove_absolute(abs_path)
	return err == OK

## Formate un horodatage ISO (YYYY-MM-DDTHH:MM:SS) en date lisible DD/MM/YYYY · HH:MM.
func format_saved_at(iso_str: String) -> String:
	if iso_str.length() < 16:
		return iso_str
	var date_part: String = iso_str.substr(0, 10)
	var time_part: String = iso_str.substr(11, 5)
	var parts: PackedStringArray = date_part.split("-")
	if parts.size() == 3:
		return "%s/%s/%s · %s" % [parts[2], parts[1], parts[0], time_part]
	return "%s · %s" % [date_part, time_part]
