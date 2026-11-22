extends Node

signal node_updated(dialogue_id: String, node_data: Dictionary, choices: Array)
signal dialogue_finished
signal move_requested(location_id: String)
signal twilight_requested
signal encounter_requested(encounter_id: String)
signal slice_completed

var current_dialogue_id: String = ""

func start_dialogue(dialogue_id: String) -> void:
	var node: Dictionary = DataLoader.get_dialogue(dialogue_id)
	if node.is_empty():
		return
	current_dialogue_id = dialogue_id
	var evaluated: Array[Dictionary] = []
	var raw_choices: Variant = node.get("choices", [])
	if raw_choices is Array:
		for c_item in (raw_choices as Array):
			if c_item is Dictionary:
				var cd: Dictionary = (c_item as Dictionary).duplicate(true)
				var check: Dictionary = _check_conditions(cd.get("conditions", {}))
				cd["_enabled"] = bool(check.get("ok", true))
				cd["_lock_reason"] = str(check.get("reason", ""))
				evaluated.append(cd)
	node_updated.emit(dialogue_id, node, evaluated)

func pick_choice(choice_index: int) -> void:
	if current_dialogue_id == "":
		return
	var node: Dictionary = DataLoader.get_dialogue(current_dialogue_id)
	var raw_choices: Variant = node.get("choices", [])
	if not (raw_choices is Array):
		close_dialogue()
		return
	var arr: Array = raw_choices as Array
	if choice_index < 0 or choice_index >= arr.size():
		close_dialogue()
		return
	var choice_var: Variant = arr[choice_index]
	if not (choice_var is Dictionary):
		close_dialogue()
		return
	var choice: Dictionary = choice_var as Dictionary
	var check: Dictionary = _check_conditions(choice.get("conditions", {}))
	if not bool(check.get("ok", true)):
		return

	AudioRadio.play_cassette_click()
	var eff: Variant = choice.get("effects", {})
	var triggers: Dictionary = _apply_effects(eff)

	if bool(triggers.get("finish_slice", false)):
		close_dialogue()
		slice_completed.emit()
		return
	if bool(triggers.get("trigger_twilight", false)):
		close_dialogue()
		twilight_requested.emit()
		return
	var enc_id: String = str(triggers.get("start_encounter", ""))
	if enc_id != "":
		close_dialogue()
		encounter_requested.emit(enc_id)
		return
	var move_loc: String = str(triggers.get("move_to", ""))
	if move_loc != "":
		move_requested.emit(move_loc)

	var next_id: String = str(choice.get("next", ""))
	if next_id != "":
		start_dialogue(next_id)
	else:
		close_dialogue()

func close_dialogue() -> void:
	current_dialogue_id = ""
	dialogue_finished.emit()

func _check_conditions(cond_var: Variant) -> Dictionary:
	if not (cond_var is Dictionary):
		return {"ok": true, "reason": ""}
	var cond: Dictionary = cond_var as Dictionary
	if cond.is_empty():
		return {"ok": true, "reason": ""}

	if cond.has("min_francs"):
		var req_f: int = int(cond.get("min_francs", 0))
		if GameState.francs < req_f:
			return {"ok": false, "reason": "Manque %d F" % req_f}
	if cond.has("min_faveurs"):
		var req_fv: int = int(cond.get("min_faveurs", 0))
		if GameState.faveurs < req_fv:
			return {"ok": false, "reason": "%d Faveur requise" % req_fv}
	if cond.has("min_aura"):
		var req_fa: int = int(cond.get("min_aura", 0))
		if GameState.get_total_aura() < req_fa:
			return {"ok": false, "reason": "Aura %d requis" % req_fa}
	if cond.has("min_skill"):
		var ms_var: Variant = cond.get("min_skill", {})
		if ms_var is Dictionary:
			var msd: Dictionary = ms_var as Dictionary
			var sk_id: String = str(msd.get("id", ""))
			var req_v: int = int(msd.get("val", 1))
			if GameState.get_best_active_group_skill(sk_id) < req_v:
				var sk_name: String = str(DataLoader.get_skill_def(sk_id).get("name", sk_id))
				return {"ok": false, "reason": "%s %d+ requis" % [sk_name, req_v]}
	if cond.has("require_item"):
		var req_item: String = str(cond.get("require_item", ""))
		if req_item != "" and not GameState.has_item_in_active_group_or_stash(req_item):
			var iname: String = str(DataLoader.get_equipment_def(req_item).get("name", req_item))
			return {"ok": false, "reason": "Objet requis : %s" % iname}
	if cond.has("require_member"):
		var req_m: String = str(cond.get("require_member", ""))
		if not GameState.is_member_in_active_group(req_m):
			return {"ok": false, "reason": "%s doit être dans ce groupe" % req_m.capitalize()}
	if cond.has("require_flag"):
		var rf: String = str(cond.get("require_flag", ""))
		if not GameState.has_flag(rf):
			return {"ok": false, "reason": "Prérequis manquant"}
	if cond.has("require_not_flag"):
		var rnf: String = str(cond.get("require_not_flag", ""))
		if GameState.has_flag(rnf):
			return {"ok": false, "reason": "Déjà fait"}
	if cond.has("require_phase"):
		var rp: String = str(cond.get("require_phase", ""))
		if GameState.phase != rp:
			var label_p: String = "De nuit uniquement" if rp == "night" else "De jour uniquement"
			return {"ok": false, "reason": label_p}
	return {"ok": true, "reason": ""}

func _apply_effects(eff_var: Variant) -> Dictionary:
	var triggers: Dictionary = {}
	if not (eff_var is Dictionary):
		return triggers
	var eff: Dictionary = eff_var as Dictionary

	if eff.has("francs"):
		var df: int = int(eff.get("francs", 0))
		GameState.francs = maxi(0, GameState.francs + df)
	if eff.has("faveurs"):
		GameState.faveurs += int(eff.get("faveurs", 0))
	if eff.has("notoriete"):
		GameState.notoriete += int(eff.get("notoriete", 0))
	if eff.has("aura_bonus"):
		GameState.aura_bonus += int(eff.get("aura_bonus", 0))

	if eff.has("set_flag"):
		var sf_var: Variant = eff.get("set_flag", {})
		if sf_var is Dictionary:
			var sf: Dictionary = sf_var as Dictionary
			for k in sf.keys():
				GameState.set_flag(str(k), bool(sf.get(k, true)))

	if eff.has("moral"):
		var m_var: Variant = eff.get("moral", {})
		if m_var is Dictionary:
			var md: Dictionary = m_var as Dictionary
			for cid in md.keys():
				GameState.modify_moral(str(cid), int(md.get(cid, 0)))

	if eff.has("unlock_clue"):
		GameState.unlock_clue(str(eff.get("unlock_clue", "")))

	if eff.has("recruit"):
		GameState.recruit_member(str(eff.get("recruit", "")))
	if eff.has("add_xp"):
		var xp_var: Variant = eff.get("add_xp", {})
		if xp_var is Dictionary:
			var xpd: Dictionary = xp_var as Dictionary
			GameState.add_xp(str(xpd.get("target", "all")), int(xpd.get("amount", 0)))
	if eff.has("grant_item"):
		GameState.add_to_box_stash(str(eff.get("grant_item", "")))
	if eff.has("add_trait"):
		var tr_var: Variant = eff.get("add_trait", {})
		if tr_var is Dictionary:
			var trd: Dictionary = tr_var as Dictionary
			GameState.add_trait(str(trd.get("char_id", "leader")), str(trd.get("trait", "")))

	if eff.has("move_to"):
		triggers["move_to"] = str(eff.get("move_to", ""))
	if eff.has("trigger_twilight"):
		triggers["trigger_twilight"] = bool(eff.get("trigger_twilight", false))
	if eff.has("start_encounter"):
		triggers["start_encounter"] = str(eff.get("start_encounter", ""))
	if eff.has("finish_slice"):
		triggers["finish_slice"] = bool(eff.get("finish_slice", false))

	GameState.state_changed.emit()
	return triggers
