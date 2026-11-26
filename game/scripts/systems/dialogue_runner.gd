## Interpréteur Data-Driven des dialogues : prérequis, Jets de rue (skill_check), déblocages dynamiques et effets sur GameState.
extends Node

signal node_updated(dialogue_id: String, node_data: Dictionary, choices: Array)
signal dialogue_finished
signal move_requested(location_id: String)
signal twilight_requested
signal encounter_requested(encounter_id: String)
signal slice_completed
signal ending_requested(ending_id: String)
signal skill_roll_resolved(roll_result: Dictionary)

var current_dialogue_id: String = ""
var last_roll_result: Dictionary = {}

## Ouvre un nœud de dialogue, évalue les conditions/jets des choix et injecte l'éventuel verdict précédent.
func start_dialogue(dialogue_id: String) -> void:
	var node: Dictionary = DataLoader.get_dialogue(dialogue_id)
	if node.is_empty():
		return
	current_dialogue_id = dialogue_id
	var node_out: Dictionary = node.duplicate(true)
	if not last_roll_result.is_empty():
		node_out["_last_roll"] = last_roll_result.duplicate(true)
		last_roll_result = {}
	var evaluated: Array[Dictionary] = []
	var raw_choices: Variant = node.get("choices", [])
	if raw_choices is Array:
		for c_item in (raw_choices as Array):
			if c_item is Dictionary:
				var cd: Dictionary = (c_item as Dictionary).duplicate(true)
				var check: Dictionary = _check_conditions(cd.get("conditions", {}))
				var enabled: bool = bool(check.get("ok", true))
				var lock_r: String = str(check.get("reason", ""))
				if cd.has("skill_check") and cd.get("skill_check") is Dictionary:
					var sc: Dictionary = cd.get("skill_check") as Dictionary
					var ff: String = str(sc.get("fail_flag", ""))
					var retryable: bool = bool(sc.get("retryable", false))
					if enabled and ff != "" and (not retryable) and GameState.has_flag(ff):
						enabled = false
						lock_r = "Déjà tenté"
					cd["_roll_preview"] = _evaluate_choice_roll(cd)
				cd["_enabled"] = enabled
				cd["_lock_reason"] = lock_r
				evaluated.append(cd)
	node_updated.emit(dialogue_id, node_out, evaluated)

## Traite le choix sélectionné : exécute un éventuel Jet de rue (next / fail_next) et applique les effets.
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

	var leader_cid: String = DataLoader.get_leader_char_id()
	var triggers: Dictionary = {}
	var next_id: String = str(choice.get("next", ""))
	if choice.has("skill_check") and choice.get("skill_check") is Dictionary:
		var sc: Dictionary = choice.get("skill_check") as Dictionary
		var ff: String = str(sc.get("fail_flag", ""))
		var retryable: bool = bool(sc.get("retryable", false))
		if ff != "" and (not retryable) and GameState.has_flag(ff):
			return
		var rp: Dictionary = _get_choice_roll_params(choice)
		var roll_res: Dictionary = GameState.perform_street_roll(
			str(rp.get("char_id", leader_cid)),
			str(rp.get("skill_id", "")),
			int(rp.get("dc", 10)),
			int(rp.get("bonus", 0)),
			str(rp.get("bonus_label", ""))
		)
		last_roll_result = roll_res.duplicate(true)
		GameState.add_log(str(roll_res.get("roll_summary", "")))
		skill_roll_resolved.emit(roll_res)
		if bool(roll_res.get("success", false)):
			AudioRadio.play_cassette_click()
			if bool(roll_res.get("is_brilliant", false)):
				GameState.add_xp(str(roll_res.get("char_id", leader_cid)), 10)
				last_roll_result["brilliant_xp"] = 10
			triggers = _apply_effects(choice.get("effects", {}))
		else:
			AudioRadio.play_crisis_buzz()
			if ff != "":
				GameState.set_flag(ff, true)
			triggers = _apply_effects(choice.get("fail_effects", {}))
			if bool(roll_res.get("is_flaw_blunder", false)):
				var fex_var: Variant = choice.get("flaw_extra_effects", {})
				if fex_var is Dictionary and not (fex_var as Dictionary).is_empty():
					var ex_tr: Dictionary = _apply_effects(fex_var)
					for tk in ex_tr.keys():
						triggers[tk] = ex_tr.get(tk)
				else:
					GameState.modify_moral(str(roll_res.get("char_id", leader_cid)), -4)
			var fnext: String = str(choice.get("fail_next", ""))
			if fnext != "":
				next_id = fnext
	else:
		AudioRadio.play_cassette_click()
		var eff: Variant = choice.get("effects", {})
		triggers = _apply_effects(eff)

	var end_id: String = str(triggers.get("trigger_ending", ""))
	if end_id != "":
		close_dialogue()
		ending_requested.emit(end_id)
		slice_completed.emit()
		return
	if bool(triggers.get("finish_slice", false)):
		close_dialogue()
		ending_requested.emit("")
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

	if next_id != "":
		start_dialogue(next_id)
	else:
		close_dialogue()

## Ferme le dialogue en cours et réinitialise le dernier verdict de jet.
func close_dialogue() -> void:
	current_dialogue_id = ""
	last_roll_result = {}
	dialogue_finished.emit()

## Résout les paramètres du meilleur lanceur et des bonus contextuels d'un choix à skill_check.
func _get_choice_roll_params(choice: Dictionary) -> Dictionary:
	var sc_var: Variant = choice.get("skill_check", {})
	if not (sc_var is Dictionary):
		return {}
	var sc: Dictionary = sc_var as Dictionary
	var sk_id: String = str(sc.get("skill", ""))
	var dc: int = int(sc.get("dc", 10))
	var spec_char: String = str(sc.get("char_id", ""))
	var bonus: int = 0
	var bonus_parts: Array[String] = []
	var bval: int = int(sc.get("bonus_val", 2))

	var bf: String = str(sc.get("bonus_if_flag", ""))
	if bf != "" and GameState.has_flag(bf):
		bonus += bval
		bonus_parts.append("Piste")
	var ba: String = str(sc.get("bonus_if_action", ""))
	if ba != "" and GameState.has_action_in_active_group(ba):
		bonus += bval
		bonus_parts.append("Équip.")
	var bi: String = str(sc.get("bonus_if_item", ""))
	if bi != "" and GameState.has_item_in_active_group_or_stash(bi):
		bonus += bval
		var b_iname: String = str(DataLoader.get_equipment_def(bi).get("name", "Objet"))
		bonus_parts.append(b_iname.split(" ")[0])

	var leader_cid: String = DataLoader.get_leader_char_id()
	var roller: Dictionary = GameState.get_best_active_group_roller(sk_id, spec_char)
	var roller_id: String = str(roller.get("char_id", leader_cid))
	if ba != "":
		var carrier_id: String = GameState.get_active_group_member_with_action(ba)
		if carrier_id != "":
			var carrier_preview: Dictionary = GameState.preview_street_roll(carrier_id, sk_id, dc, bonus, " + ".join(bonus_parts))
			var best_preview: Dictionary = GameState.preview_street_roll(roller_id, sk_id, dc, bonus, " + ".join(bonus_parts))
			if int(carrier_preview.get("chance_pct", 0)) >= int(best_preview.get("chance_pct", 0)):
				roller_id = carrier_id

	return {
		"char_id": roller_id,
		"skill_id": sk_id,
		"dc": dc,
		"bonus": bonus,
		"bonus_label": " + ".join(bonus_parts)
	}

## Calcule la prévisualisation en lecture seule (_roll_preview) d'un choix à Jet de rue.
func _evaluate_choice_roll(choice: Dictionary) -> Dictionary:
	var rp: Dictionary = _get_choice_roll_params(choice)
	if rp.is_empty():
		return {}
	return GameState.preview_street_roll(
		str(rp.get("char_id", DataLoader.get_leader_char_id())),
		str(rp.get("skill_id", "")),
		int(rp.get("dc", 10)),
		int(rp.get("bonus", 0)),
		str(rp.get("bonus_label", ""))
	)

## Évalue l'ensemble des prérequis d'un choix (ressources, compétences, objets, actions équipées, flags, phase, notoriété).
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
	if cond.has("min_notoriete"):
		var req_not: int = int(cond.get("min_notoriete", 0))
		if GameState.notoriete < req_not:
			return {"ok": false, "reason": "Notoriété %d+ requise" % req_not}
	if cond.has("max_notoriete"):
		var max_not: int = int(cond.get("max_notoriete", 99))
		if GameState.notoriete > max_not:
			return {"ok": false, "reason": "Trop de Notoriété (%d max)" % max_not}
	if cond.has("min_moral"):
		var req_mor: int = int(cond.get("min_moral", 0))
		if GameState.get_lowest_moral() < req_mor:
			return {"ok": false, "reason": "Moral %d+ requis" % req_mor}
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
	if cond.has("require_action"):
		var req_act: String = str(cond.get("require_action", ""))
		if req_act != "" and not GameState.has_action_in_active_group(req_act):
			return {"ok": false, "reason": "Équiper : %s" % _find_item_name_for_action(req_act)}
	if cond.has("require_member"):
		var req_m: String = str(cond.get("require_member", ""))
		if not GameState.is_member_in_active_group(req_m):
			var m_name: String = str(DataLoader.get_character(req_m).get("name", req_m.capitalize()))
			return {"ok": false, "reason": "%s doit être dans ce groupe" % m_name}
	if cond.has("require_flag"):
		var rf: String = str(cond.get("require_flag", ""))
		if not GameState.has_flag(rf):
			return {"ok": false, "reason": "Prérequis manquant"}
	if cond.has("require_not_flag"):
		var rnf: String = str(cond.get("require_not_flag", ""))
		if GameState.has_flag(rnf):
			return {"ok": false, "reason": "Déjà fait"}
	if cond.has("has_clue"):
		var hc: String = str(cond.get("has_clue", ""))
		if hc != "" and not GameState.clues.has(hc):
			return {"ok": false, "reason": "Piste manquante"}
	if cond.has("require_outcome"):
		var ro: String = str(cond.get("require_outcome", ""))
		if ro != "" and GameState.last_encounter_outcome != ro:
			return {"ok": false, "reason": "Issue différente"}
	if cond.has("require_phase"):
		var rp: String = str(cond.get("require_phase", ""))
		if GameState.phase != rp:
			var label_p: String = "De nuit uniquement" if rp == "night" else "De jour uniquement"
			return {"ok": false, "reason": label_p}
	return {"ok": true, "reason": ""}

## Applique les effets d'un nœud sur GameState et retourne les déclencheurs spéciaux (move_to, rencontre, crépuscule, fin).
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
	if eff.has("advance_clock"):
		GameState.advance_clock(int(eff.get("advance_clock", 0)))
	if eff.has("set_phase"):
		GameState.set_phase(str(eff.get("set_phase", GameState.phase)))

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
	if eff.has("unlock_location"):
		var unl_v: Variant = eff.get("unlock_location")
		if unl_v is Array:
			for uv in (unl_v as Array):
				GameState.unlock_node(str(uv))
		else:
			GameState.unlock_node(str(unl_v))

	if eff.has("recruit"):
		GameState.recruit_member(str(eff.get("recruit", "")))
	if eff.has("add_xp"):
		var xp_var: Variant = eff.get("add_xp", {})
		if xp_var is Dictionary:
			var xpd: Dictionary = xp_var as Dictionary
			GameState.add_xp(str(xpd.get("target", "all")), int(xpd.get("amount", 0)))
	if eff.has("grant_item"):
		GameState.add_to_box_stash(str(eff.get("grant_item", "")))
	if eff.has("remove_item"):
		GameState.remove_item_from_group_or_stash(str(eff.get("remove_item", "")))
	if eff.has("add_trait"):
		var tr_var: Variant = eff.get("add_trait", {})
		if tr_var is Dictionary:
			var trd: Dictionary = tr_var as Dictionary
			GameState.add_trait(str(trd.get("char_id", DataLoader.get_leader_char_id())), str(trd.get("trait", "")))

	if eff.has("move_to"):
		triggers["move_to"] = str(eff.get("move_to", ""))
	if eff.has("trigger_twilight"):
		triggers["trigger_twilight"] = bool(eff.get("trigger_twilight", false))
	if eff.has("start_encounter"):
		triggers["start_encounter"] = str(eff.get("start_encounter", ""))
	if eff.has("trigger_ending"):
		triggers["trigger_ending"] = str(eff.get("trigger_ending", ""))
	if eff.has("finish_slice"):
		triggers["finish_slice"] = bool(eff.get("finish_slice", false))

	GameState.state_changed.emit()
	return triggers

## Recherche dans DataLoader le nom de l'équipement fournissant une action donnée pour les info-bulles de blocage.
func _find_item_name_for_action(action_id: String) -> String:
	for iid_var in DataLoader.equipment_catalog.keys():
		var idef: Dictionary = DataLoader.get_equipment_def(str(iid_var))
		var acts_var: Variant = idef.get("unlocks_actions", [])
		if acts_var is Array:
			for av in (acts_var as Array):
				if av is Dictionary and str((av as Dictionary).get("id", "")) == action_id:
					return str(idef.get("name", action_id))
	return action_id
