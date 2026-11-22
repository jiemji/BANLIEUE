## Gestionnaire tactique de la Frise Chronologique de Tension (bande magnétique 1982, pas-à-pas strict 3B, prévisualisation 2A).
extends Node

signal timeline_updated
signal encounter_finished(outcome_id: String, summary: String)
signal train_fantome_arrived_sig
signal combat_feedback_emitted(event_data: Dictionary)

var active: bool = false
var encounter_id: String = ""
var encounter_title: String = ""
var intro_text: String = ""
var turn_count: int = 0
var crs_ticks: int = 4
var train_fantome_turn: int = 3
var train_fantome_arrived: bool = false
var escape_progress: int = 0
var interposition_shield: int = 0

var selected_target_id: String = ""
var awaiting_step: bool = false
var pending_beat_label: String = ""
var last_event: Dictionary = {}

var enemies: Array[Dictionary] = []
var allies: Array[Dictionary] = []
var crisis_queue: Array[Dictionary] = []
var combat_log: Array[String] = []

var _squad_manager: Node = null
var _pending_enemy_ids: Array[String] = []
var _pending_crisis_ids: Array[String] = []

func set_squad_manager(sm: Node) -> void:
	_squad_manager = sm

## Initialise une confrontation sur la frise à partir des données JSON et des présents sur zone.
func start_encounter(enc_id: String) -> void:
	var enc: Dictionary = DataLoader.get_encounter(enc_id)
	if enc.is_empty():
		return
	active = true
	encounter_id = enc_id
	encounter_title = str(enc.get("title", "Confrontation"))
	intro_text = str(enc.get("intro_text", ""))
	turn_count = 1
	crs_ticks = int(enc.get("crs_start_ticks", 4))
	train_fantome_turn = int(enc.get("train_fantome_turn", 3))
	train_fantome_arrived = false
	escape_progress = 1 if GameState.has_flag("has_caves_key") else 0
	interposition_shield = 0
	selected_target_id = ""
	awaiting_step = false
	pending_beat_label = ""
	last_event = {}
	enemies.clear()
	allies.clear()
	crisis_queue.clear()
	combat_log.clear()
	_pending_enemy_ids.clear()
	_pending_crisis_ids.clear()

	# Ennemis depuis JSON
	var e_list_var: Variant = enc.get("enemies", [])
	if e_list_var is Array:
		for item in (e_list_var as Array):
			if item is Dictionary:
				var ed: Dictionary = (item as Dictionary).duplicate(true)
				var res_max: int = int(ed.get("resolve_max", 3))
				if str(ed.get("id", "")) == "cousin_so" and GameState.has_flag("ludo_bluffed_cousin"):
					res_max = maxi(2, res_max - 1)
				ed["resolve"] = res_max
				ed["resolve_max"] = res_max
				ed["next_tick"] = int(ed.get("initial_tick", 2))
				ed["counter_ready"] = bool(ed.get("has_counter_interrupt", false))
				ed["defeated"] = false
				enemies.append(ed)

	# Alliés présents sur place + renforts proches
	var enc_loc: String = str(enc.get("location_id", "gare_rer_y"))
	var reinforce_map: Dictionary = {}
	if _squad_manager != null and _squad_manager.has_method("compute_reinforcements"):
		var reinf_var: Variant = _squad_manager.call("compute_reinforcements", enc_loc)
		if reinf_var is Array:
			for r_item in (reinf_var as Array):
				if r_item is Dictionary:
					var rd: Dictionary = r_item as Dictionary
					reinforce_map[str(rd.get("char_id", ""))] = int(rd.get("ticks", 2))

	var idx: int = 0
	for cid in GameState.squad_members:
		var cdef: Dictionary = DataLoader.get_character(cid)
		var st: Dictionary = GameState.get_member_state(cid)
		var loc_id: String = str(st.get("location_id", "box_garage"))
		var is_here: bool = (int(st.get("group_id", 0)) == GameState.active_group_id) or (loc_id == enc_loc)
		var r_ticks: int = 0 if is_here else int(reinforce_map.get(cid, 2))
		allies.append({
			"char_id": cid,
			"name": str(cdef.get("name", cid)),
			"color_hex": str(cdef.get("color_hex", "#f28c28")),
			"specialty_id": str(cdef.get("specialty_id", "")),
			"specialty_name": str(cdef.get("specialty_name", "")),
			"present": is_here,
			"reinforce_in_ticks": r_ticks,
			"next_tick": idx if is_here else r_ticks + 1,
			"reaction_ready": is_here
		})
		if is_here:
			idx += 1

	_push_log(intro_text)
	if GameState.has_flag("ludo_guetteur"):
		crs_ticks += 1
		_push_log("Ludo fait le guet sur l'avenue : les CRS gagnent +1 cran de retard.")
	if GameState.has_flag("ludo_bluffed_cousin"):
		_push_log("Le baratin de Ludo a déjà semé le doute chez son cousin S.O. (-1 Résolution).")

	_ensure_valid_target()
	_check_crisis_triggers()
	_sync_step_state()
	_emit_feedback("intro", "", encounter_title, intro_text, false)
	AudioRadio.play_cassette_click()
	timeline_updated.emit()

## Retourne l'allié présent prêt à agir au cran 0, ou un dictionnaire vide.
func get_acting_ally() -> Dictionary:
	var best: Dictionary = {}
	var best_tick: int = 999
	for a in allies:
		if bool(a.get("present", false)):
			var t: int = int(a.get("next_tick", 99))
			if t < best_tick:
				best_tick = t
				best = a
	if best_tick == 0:
		return best
	return {}

## Sélectionne explicitement un ennemi actif comme cible courante.
func select_target(enemy_id: String) -> void:
	if not active:
		return
	var found: Dictionary = _find_enemy(enemy_id)
	if found.is_empty() or bool(found.get("defeated", false)):
		return
	selected_target_id = enemy_id
	AudioRadio.play_cassette_click()
	timeline_updated.emit()

## Fait tourner la cible active vers le prochain adversaire encore debout.
func cycle_target() -> void:
	if not active:
		return
	var active_ids: Array[String] = []
	for e in enemies:
		if not bool(e.get("defeated", false)):
			active_ids.append(str(e.get("id", "")))
	if active_ids.is_empty():
		selected_target_id = ""
		return
	var cur_idx: int = active_ids.find(selected_target_id)
	var next_idx: int = (cur_idx + 1) % active_ids.size()
	selected_target_id = active_ids[next_idx]
	AudioRadio.play_cassette_click()
	timeline_updated.emit()

## Retourne la cible sélectionnée valide (ou réaligne automatiquement sur le plus proche).
func get_selected_target() -> Dictionary:
	return _ensure_valid_target()

## Exécute une action tactique du tour actif puis prépare le pas-à-pas suivant.
func execute_player_action(action_id: String) -> void:
	if not active:
		return
	if awaiting_step:
		step_next_beat()
		return
	var actor: Dictionary = get_acting_ally()
	if actor.is_empty():
		_sync_step_state()
		timeline_updated.emit()
		return

	var actor_id: String = str(actor.get("char_id", "leader"))
	var actor_name: String = str(actor.get("name", "Leader"))
	var target: Dictionary = _ensure_valid_target()

	if action_id == "act_tchatche":
		if not target.is_empty():
			var dmg: int = 2
			if GameState.faveurs > 0 or GameState.has_flag("tour_b_done"):
				dmg = 3
			_damage_enemy(target, dmg)
			var msg_t: String = "%s balance les preuves et l'arrêté bidon ! %s perd %d de résolution." % [actor_name, str(target.get("name", "")), dmg]
			_push_log(msg_t)
			_emit_feedback("ally_action", actor_id, actor_name, msg_t, false)
	elif action_id == "act_pression":
		if not target.is_empty():
			var dmg_p: int = 2 + (1 if GameState.get_total_aura() >= 5 else 0)
			_damage_enemy(target, dmg_p)
			target["next_tick"] = int(target.get("next_tick", 1)) + 1
			_remove_pending_enemy(str(target.get("id", "")))
			var msg_p: String = "%s impose son Aura sur la table : %s recule (-%d résolution, +1 cran)." % [actor_name, str(target.get("name", "")), dmg_p]
			_push_log(msg_p)
			_emit_feedback("ally_action", actor_id, actor_name, msg_p, true)
	elif action_id == "act_repli":
		crs_ticks += 2
		escape_progress += 1
		var msg_r: String = "%s repère l'issue vers le quai / les chaufferies (+2 crans CRS, échappée %d/2)." % [actor_name, escape_progress]
		_push_log(msg_r)
		_emit_feedback("ally_action", actor_id, actor_name, msg_r, false)
	elif action_id == "act_escape_now":
		if can_escape_now():
			_finish("escaped", "Échappée nocturne réussie ! Profitant de la rame du Train Fantôme et de l'ombre du quai, la bande sème le S.O. et les CRS avant de filer sous la Dalle.")
			return

	# Recharge réaction de l'allié qui vient de jouer son tour et le replace à +2 crans
	actor["reaction_ready"] = true
	actor["next_tick"] = 2
	AudioRadio.play_cassette_click()

	if _all_enemies_defeated():
		_finish("social_win", "Le S.O. municipal plie devant vos preuves et la réputation du quartier ! L'arrêté bidon du Galaxian tombe à l'eau avant même l'arrivée des CRS.")
		return

	_ensure_valid_target()
	_sync_step_state()
	timeline_updated.emit()

## Déclenche une Interruption hors-tour pour l'allié choisi si sa Réaction est prête.
func trigger_interruption(char_id: String) -> void:
	if not active:
		return
	var ally: Dictionary = _find_ally(char_id)
	if ally.is_empty() or not bool(ally.get("present", false)) or not bool(ally.get("reaction_ready", false)):
		return

	ally["reaction_ready"] = false
	var spec: String = str(ally.get("specialty_id", ""))
	var cname: String = str(ally.get("name", char_id))
	AudioRadio.play_interrupt_hit()

	# Contre-interruption d'un vétéran S.O. si prête
	var counter_triggered: bool = false
	for e in enemies:
		if not bool(e.get("defeated", false)) and bool(e.get("counter_ready", false)):
			e["counter_ready"] = false
			counter_triggered = true
			var c_msg: String = "CONTRE-INTERRUPTION ! %s tente un Coup de pression sur %s (-6 Moral) !" % [str(e.get("name", "")), cname]
			_push_log(c_msg)
			_apply_moral_hit(char_id, -6)
			_emit_feedback("counter", str(e.get("id", "")), str(e.get("name", "")), c_msg, true)

	if spec == "moquerie":
		var target: Dictionary = _ensure_valid_target()
		if not target.is_empty():
			target["next_tick"] = int(target.get("next_tick", 1)) + 2
			_damage_enemy(target, 1)
			_remove_pending_enemy(str(target.get("id", "")))
			var m_msg: String = "INTERRUPTION [Moquerie] — %s casse la charge de %s (-1 résol, +2 crans) !" % [cname, str(target.get("name", ""))]
			_push_log(m_msg)
			if not counter_triggered:
				_emit_feedback("interrupt", char_id, cname, m_msg, true)
	elif spec == "interposition":
		interposition_shield += 1
		GameState.modify_moral(char_id, 4)
		var i_msg: String = "INTERRUPTION [Interposition] — %s fait bloc sous le réverbère (+4 Moral, prochain coup amorti) !" % cname
		_push_log(i_msg)
		if not counter_triggered:
			_emit_feedback("interrupt", char_id, cname, i_msg, false)
	elif spec == "reflexe_rue":
		crs_ticks += 2
		escape_progress += 1
		var rx_msg: String = "INTERRUPTION [Réflexe de rue] — %s pousse une grille métallique (+2 crans CRS, accès quai ouvert) !" % cname
		_push_log(rx_msg)
		if not counter_triggered:
			_emit_feedback("interrupt", char_id, cname, rx_msg, false)
	elif spec == "sang_froid":
		# Spécialité de L'Échappé·e des Pavillons : calme prioritairement une crise imminente, sinon perce un bluff adverse.
		if not crisis_queue.is_empty():
			var cr: Dictionary = crisis_queue[0]
			var cr_cid: String = str(cr.get("char_id", ""))
			crisis_queue.remove_at(0)
			_remove_pending_crisis(cr_cid)
			GameState.modify_moral(cr_cid, 10)
			var sf_msg: String = "INTERRUPTION [Sang-froid] — %s reprend la main et calme %s à temps (+10 Moral) !" % [cname, cr_cid.capitalize()]
			_push_log(sf_msg)
			if not counter_triggered:
				_emit_feedback("interrupt", char_id, cname, sf_msg, false)
		else:
			var target_sf: Dictionary = _ensure_valid_target()
			if not target_sf.is_empty():
				target_sf["next_tick"] = int(target_sf.get("next_tick", 1)) + 1
				_damage_enemy(target_sf, 1)
				_remove_pending_enemy(str(target_sf.get("id", "")))
				var sf2_msg: String = "INTERRUPTION [Sang-froid] — %s perce le bluff de %s (-1 résol, +1 cran) !" % [cname, str(target_sf.get("name", ""))]
				_push_log(sf2_msg)
				if not counter_triggered:
					_emit_feedback("interrupt", char_id, cname, sf2_msg, true)
			else:
				GameState.modify_moral(char_id, 6)
				var sf3_msg: String = "INTERRUPTION [Sang-froid] — %s garde la tête froide (+6 Moral)." % cname
				_push_log(sf3_msg)
				if not counter_triggered:
					_emit_feedback("interrupt", char_id, cname, sf3_msg, false)

	if _all_enemies_defeated():
		_finish("social_win", "Entre tchatche, vannes et nerfs d'acier, vous retournez la rue ! Le S.O. lâche l'affaire avant l'arrivée des CRS.")
		return

	_ensure_valid_target()
	_sync_step_state()
	timeline_updated.emit()

## Dépense la Réaction d'un camarade pour contenir une Crise d'autonomie imminente.
func restrain_crisis(crisis_char_id: String) -> void:
	if not active:
		return
	var rescuer: Dictionary = _find_rescuer_for(crisis_char_id)
	if rescuer.is_empty():
		_push_log("Personne n'a de Réaction disponible pour retenir %s !" % crisis_char_id)
		timeline_updated.emit()
		return

	rescuer["reaction_ready"] = false
	for i in range(crisis_queue.size() - 1, -1, -1):
		if str(crisis_queue[i].get("char_id", "")) == crisis_char_id:
			crisis_queue.remove_at(i)
	_remove_pending_crisis(crisis_char_id)
	GameState.modify_moral(crisis_char_id, 8)
	var r_msg: String = "%s plaque %s contre le mur et le calme à temps : Crise d'autonomie contenue (+8 Moral) !" % [str(rescuer.get("name", "")), crisis_char_id.capitalize()]
	_push_log(r_msg)
	_emit_feedback("restrain", str(rescuer.get("char_id", "")), str(rescuer.get("name", "")), r_msg, false)
	AudioRadio.play_cassette_click()
	_sync_step_state()
	timeline_updated.emit()

func has_restrain_reaction_for(crisis_char_id: String) -> bool:
	return not _find_rescuer_for(crisis_char_id).is_empty()

func can_escape_now() -> bool:
	return train_fantome_arrived or escape_progress >= 2

## Avance exactement d'un beat non-allié (une crise, une action ennemie, ou 1 cran du rail).
func step_next_beat() -> void:
	if not active:
		return
	if not awaiting_step:
		_sync_step_state()
		if not awaiting_step:
			return

	if not _pending_crisis_ids.is_empty():
		var cid: String = _pending_crisis_ids[0]
		_pending_crisis_ids.remove_at(0)
		for i in range(crisis_queue.size() - 1, -1, -1):
			if str(crisis_queue[i].get("char_id", "")) == cid:
				crisis_queue.remove_at(i)
		_execute_autonomous_crisis(cid)
	elif not _pending_enemy_ids.is_empty():
		var eid: String = _pending_enemy_ids[0]
		_pending_enemy_ids.remove_at(0)
		var ed: Dictionary = _find_enemy(eid)
		if not ed.is_empty() and not bool(ed.get("defeated", false)) and int(ed.get("next_tick", 0)) <= 0:
			_execute_enemy_turn(ed)
			ed["next_tick"] = int(ed.get("speed", 2))
	else:
		_advance_one_world_tick()
		if not active:
			return

	if _all_enemies_defeated():
		_finish("social_win", "Pression retournée ! Le S.O. municipal et le Skin battent en retraite avant que les CRS ne bouclent l'avenue.")
		return

	_ensure_valid_target()
	_check_crisis_triggers()
	_sync_step_state()
	timeline_updated.emit()

## Prévisualisation en lecture seule d'une action tactique sur la cible active et le rail.
func preview_player_action(action_id: String) -> Dictionary:
	if not active:
		return {"valid": false, "reason": "Hors confrontation"}
	if awaiting_step or get_acting_ally().is_empty():
		return {"valid": false, "reason": "Appuie d'abord sur Espace pour résoudre le beat en attente."}

	var target: Dictionary = _peek_selected_target()
	if action_id == "act_tchatche":
		if target.is_empty():
			return {"valid": false, "reason": "Aucune cible active."}
		var dmg: int = 3 if (GameState.faveurs > 0 or GameState.has_flag("tour_b_done")) else 2
		var ft: int = int(target.get("next_tick", 0))
		return {
			"valid": true,
			"kind": "action",
			"title": "Tchatche / Bluff Attitude",
			"target_id": str(target.get("id", "")),
			"target_name": str(target.get("name", "")),
			"from_tick": ft,
			"to_tick": ft,
			"resolve_delta": -dmg,
			"crs_delta": 0,
			"escape_delta": 0,
			"shield_delta": 0,
			"moral_delta": 0,
			"counter_warning": false,
			"counter_label": "",
			"summary": "%s : -%d Résolution (reste Cran %d)" % [str(target.get("name", "")), dmg, ft]
		}
	elif action_id == "act_pression":
		if target.is_empty():
			return {"valid": false, "reason": "Aucune cible active."}
		var dmg_p: int = 2 + (1 if GameState.get_total_aura() >= 5 else 0)
		var ftp: int = int(target.get("next_tick", 0))
		return {
			"valid": true,
			"kind": "action",
			"title": "Coup de pression (Aura)",
			"target_id": str(target.get("id", "")),
			"target_name": str(target.get("name", "")),
			"from_tick": ftp,
			"to_tick": ftp + 1,
			"resolve_delta": -dmg_p,
			"crs_delta": 0,
			"escape_delta": 0,
			"shield_delta": 0,
			"moral_delta": 0,
			"counter_warning": false,
			"counter_label": "",
			"summary": "%s : -%d Résolution · recule Cran %d → %d" % [str(target.get("name", "")), dmg_p, ftp, ftp + 1]
		}
	elif action_id == "act_repli":
		return {
			"valid": true,
			"kind": "action",
			"title": "Préparer l'échappée",
			"target_id": "crs",
			"target_name": "Patrouille CRS / Quai",
			"from_tick": crs_ticks,
			"to_tick": crs_ticks + 2,
			"resolve_delta": 0,
			"crs_delta": 2,
			"escape_delta": 1,
			"shield_delta": 0,
			"moral_delta": 0,
			"counter_warning": false,
			"counter_label": "",
			"summary": "CRS Cran %d → %d · Échappée %d → %d/2" % [crs_ticks, crs_ticks + 2, escape_progress, mini(2, escape_progress + 1)]
		}
	elif action_id == "act_escape_now":
		var can_esc: bool = can_escape_now()
		return {
			"valid": can_esc,
			"kind": "action",
			"title": "Filer par le Quai / Train Fantôme",
			"target_id": "crs",
			"target_name": "Rame RER du Y",
			"from_tick": 0,
			"to_tick": 0,
			"resolve_delta": 0,
			"crs_delta": 0,
			"escape_delta": 0,
			"shield_delta": 0,
			"moral_delta": 0,
			"counter_warning": false,
			"counter_label": "",
			"reason": "Échappée non ouverte (2/2 ou Train Fantôme requis)" if not can_esc else "",
			"summary": "Repli immédiat de toute la bande vers le souterrain"
		}
	return {"valid": false, "reason": "Action inconnue"}

## Prévisualisation en lecture seule d'une Interruption hors-tour (incluant alerte Contre-interruption).
func preview_interruption(char_id: String) -> Dictionary:
	if not active:
		return {"valid": false, "reason": "Hors confrontation"}
	var ally: Dictionary = _find_ally(char_id)
	if ally.is_empty() or not bool(ally.get("present", false)):
		return {"valid": false, "reason": "Allié absent du quai"}
	if not bool(ally.get("reaction_ready", false)):
		return {"valid": false, "reason": "Réaction déjà utilisée ce cycle"}

	var counter_warn: bool = false
	var counter_lbl: String = ""
	for e in enemies:
		if not bool(e.get("defeated", false)) and bool(e.get("counter_ready", false)):
			counter_warn = true
			counter_lbl = str(e.get("counter_label", "Contre-interruption prête (-6 Moral)"))
			break

	var spec: String = str(ally.get("specialty_id", ""))
	var cname: String = str(ally.get("name", char_id))
	var target: Dictionary = _peek_selected_target()

	if spec == "moquerie":
		if target.is_empty():
			return {"valid": false, "reason": "Aucune cible active"}
		var ft: int = int(target.get("next_tick", 1))
		return {
			"valid": true,
			"kind": "interruption",
			"title": "%s — Moquerie" % cname,
			"target_id": str(target.get("id", "")),
			"target_name": str(target.get("name", "")),
			"from_tick": ft,
			"to_tick": ft + 2,
			"resolve_delta": -1,
			"crs_delta": 0,
			"escape_delta": 0,
			"shield_delta": 0,
			"moral_delta": 0,
			"counter_warning": counter_warn,
			"counter_label": counter_lbl,
			"summary": "%s : -1 Résol · recule Cran %d → %d" % [str(target.get("name", "")), ft, ft + 2]
		}
	elif spec == "interposition":
		return {
			"valid": true,
			"kind": "interruption",
			"title": "%s — Interposition" % cname,
			"target_id": char_id,
			"target_name": cname,
			"from_tick": 0,
			"to_tick": 0,
			"resolve_delta": 0,
			"crs_delta": 0,
			"escape_delta": 0,
			"shield_delta": 1,
			"moral_delta": 4,
			"counter_warning": counter_warn,
			"counter_label": counter_lbl,
			"summary": "Bouclier Interposition +1 (-6 dégâts au prochain coup) · +4 Moral"
		}
	elif spec == "reflexe_rue":
		return {
			"valid": true,
			"kind": "interruption",
			"title": "%s — Réflexe de rue" % cname,
			"target_id": "crs",
			"target_name": "Patrouille CRS / Quai",
			"from_tick": crs_ticks,
			"to_tick": crs_ticks + 2,
			"resolve_delta": 0,
			"crs_delta": 2,
			"escape_delta": 1,
			"shield_delta": 0,
			"moral_delta": 0,
			"counter_warning": counter_warn,
			"counter_label": counter_lbl,
			"summary": "CRS Cran %d → %d · Échappée +1" % [crs_ticks, crs_ticks + 2]
		}
	elif spec == "sang_froid":
		if not crisis_queue.is_empty():
			var cr: Dictionary = crisis_queue[0]
			var cr_cid: String = str(cr.get("char_id", ""))
			var cr_name: String = str(DataLoader.get_character(cr_cid).get("name", cr_cid))
			return {
				"valid": true,
				"kind": "interruption",
				"title": "%s — Sang-froid" % cname,
				"target_id": cr_cid,
				"target_name": cr_name,
				"from_tick": int(cr.get("ticks_left", 0)),
				"to_tick": 0,
				"resolve_delta": 0,
				"crs_delta": 0,
				"escape_delta": 0,
				"shield_delta": 0,
				"moral_delta": 10,
				"counter_warning": counter_warn,
				"counter_label": counter_lbl,
				"summary": "Annule la crise de %s · +10 Moral" % cr_name
			}
		elif not target.is_empty():
			var fts: int = int(target.get("next_tick", 1))
			return {
				"valid": true,
				"kind": "interruption",
				"title": "%s — Sang-froid" % cname,
				"target_id": str(target.get("id", "")),
				"target_name": str(target.get("name", "")),
				"from_tick": fts,
				"to_tick": fts + 1,
				"resolve_delta": -1,
				"crs_delta": 0,
				"escape_delta": 0,
				"shield_delta": 0,
				"moral_delta": 0,
				"counter_warning": counter_warn,
				"counter_label": counter_lbl,
				"summary": "%s : -1 Résol · recule Cran %d → %d" % [str(target.get("name", "")), fts, fts + 1]
			}
		return {
			"valid": true,
			"kind": "interruption",
			"title": "%s — Sang-froid" % cname,
			"target_id": char_id,
			"target_name": cname,
			"from_tick": 0,
			"to_tick": 0,
			"resolve_delta": 0,
			"crs_delta": 0,
			"escape_delta": 0,
			"shield_delta": 0,
			"moral_delta": 6,
			"counter_warning": counter_warn,
			"counter_label": counter_lbl,
			"summary": "Recentrage (+6 Moral)"
		}

	return {"valid": false, "reason": "Spécialité sans interruption"}

## Prévisualisation en lecture seule du bouton Retenir une Crise d'autonomie.
func preview_restrain(crisis_char_id: String) -> Dictionary:
	var rescuer: Dictionary = _find_rescuer_for(crisis_char_id)
	var cr_name: String = str(DataLoader.get_character(crisis_char_id).get("name", crisis_char_id))
	if rescuer.is_empty():
		return {"valid": false, "reason": "Aucun camarade avec Réaction disponible pour retenir %s." % cr_name}
	var r_name: String = str(rescuer.get("name", ""))
	return {
		"valid": true,
		"kind": "restrain",
		"title": "Retenir %s" % cr_name,
		"target_id": crisis_char_id,
		"target_name": cr_name,
		"from_tick": 0,
		"to_tick": 0,
		"resolve_delta": 0,
		"crs_delta": 0,
		"escape_delta": 0,
		"shield_delta": 0,
		"moral_delta": 8,
		"counter_warning": false,
		"counter_label": "",
		"summary": "%s dépense sa Réaction : calme %s (+8 Moral, crise annulée)" % [r_name, cr_name]
	}

## Retourne la liste ordonnée des pions de la bande magnétique (avec portraits, ciblages et alertes).
func get_ordered_rail_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var acting: Dictionary = get_acting_ally()
	var acting_id: String = str(acting.get("char_id", ""))
	for a in allies:
		var cid: String = str(a.get("char_id", ""))
		var cdef: Dictionary = DataLoader.get_character(cid)
		var portrait_p: String = str(cdef.get("portrait", ""))
		if bool(a.get("present", false)):
			var nt: int = int(a.get("next_tick", 0))
			entries.append({
				"kind": "ally",
				"id": cid,
				"label": str(a.get("name", "")).split(" ")[0],
				"tick": nt,
				"color": str(a.get("color_hex", "#f28c28")),
				"sub": "Prêt" if (nt == 0 and cid == acting_id) else "Réact." if bool(a.get("reaction_ready", false)) else "",
				"portrait": portrait_p,
				"acting": (cid == acting_id and not awaiting_step),
				"intent": str(a.get("specialty_name", "")),
				"counter_ready": false,
				"selected": false
			})
		else:
			entries.append({
				"kind": "reinforcement",
				"id": cid,
				"label": "Renfort " + str(a.get("name", "")).split(" ")[0],
				"tick": int(a.get("reinforce_in_ticks", 2)),
				"color": "#7ec4cf",
				"sub": "103 SP / pied",
				"portrait": portrait_p,
				"acting": false,
				"intent": "En approche vers la gare",
				"counter_ready": false,
				"selected": false
			})
	for e in enemies:
		if not bool(e.get("defeated", false)):
			var eid: String = str(e.get("id", ""))
			entries.append({
				"kind": "enemy",
				"id": eid,
				"label": str(e.get("name", "")),
				"tick": int(e.get("next_tick", 1)),
				"color": "#d92b2b",
				"sub": "Rés.%d/%d" % [int(e.get("resolve", 1)), int(e.get("resolve_max", 1))],
				"portrait": str(e.get("portrait", "res://assets/portraits/so_agent.png")),
				"acting": (not _pending_enemy_ids.is_empty() and _pending_enemy_ids[0] == eid),
				"intent": str(e.get("intent_label", "")),
				"counter_ready": bool(e.get("counter_ready", false)),
				"selected": (eid == selected_target_id)
			})
	for cr in crisis_queue:
		var cr_id: String = str(cr.get("char_id", ""))
		var cr_def: Dictionary = DataLoader.get_character(cr_id)
		entries.append({
			"kind": "crisis",
			"id": cr_id,
			"label": "CRISE " + str(cr_def.get("name", cr_id)).split(" ")[0].to_upper(),
			"tick": int(cr.get("ticks_left", 1)),
			"color": "#ff3838",
			"sub": "Préavis !" if int(cr.get("ticks_left", 1)) > 0 else "DÉCLENCHEMENT",
			"portrait": str(cr_def.get("portrait", "")),
			"acting": (not _pending_crisis_ids.is_empty() and _pending_crisis_ids[0] == cr_id),
			"intent": str(cr.get("label", "Crise d'autonomie")),
			"counter_ready": false,
			"selected": false
		})
	entries.append({
		"kind": "crs",
		"id": "crs",
		"label": "Patrouille CRS",
		"tick": maxi(0, crs_ticks),
		"color": "#3d85ff",
		"sub": "Sirènes",
		"portrait": "",
		"acting": false,
		"intent": "Bouclage des sorties RER",
		"counter_ready": false,
		"selected": false
	})
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(x.get("tick", 0)) < int(y.get("tick", 0))
	)
	return entries

func _advance_one_world_tick() -> void:
	turn_count += 1
	crs_ticks -= 1

	# Renforts qui arrivent
	for a in allies:
		if not bool(a.get("present", false)):
			var rt: int = int(a.get("reinforce_in_ticks", 1)) - 1
			a["reinforce_in_ticks"] = rt
			if rt <= 0:
				a["present"] = true
				a["next_tick"] = 0
				a["reaction_ready"] = true
				var r_msg: String = "RENFORT ! %s déboule sur le quai à temps pour couvrir la bande !" % str(a.get("name", ""))
				_push_log(r_msg)
				_emit_feedback("reinforcement", str(a.get("char_id", "")), str(a.get("name", "")), r_msg, false)
		else:
			a["next_tick"] = maxi(0, int(a.get("next_tick", 1)) - 1)

	# Crises d'autonomie en préavis (restent en queue à 0 jusqu'au beat de déclenchement ou Retenir)
	for i in range(crisis_queue.size()):
		var cr: Dictionary = crisis_queue[i]
		var tl: int = maxi(0, int(cr.get("ticks_left", 1)) - 1)
		cr["ticks_left"] = tl
		crisis_queue[i] = cr
		if tl <= 0:
			var cr_cid: String = str(cr.get("char_id", ""))
			if not _pending_crisis_ids.has(cr_cid):
				_pending_crisis_ids.append(cr_cid)

	# Ennemis avancent et s'inscrivent en file pas-à-pas à 0
	for e in enemies:
		if bool(e.get("defeated", false)):
			continue
		var nt: int = maxi(0, int(e.get("next_tick", 1)) - 1)
		e["next_tick"] = nt
		if nt <= 0:
			var eid: String = str(e.get("id", ""))
			if not _pending_enemy_ids.has(eid):
				_pending_enemy_ids.append(eid)

	# Apparition ambiguë du Train Fantôme au quai de la gare du Y
	if not train_fantome_arrived and turn_count >= train_fantome_turn * 2:
		train_fantome_arrived = true
		var tf_msg: String = "PHÉNOMÈNE AMBIGU : Un RER B sans annonce entre en gare — sa ferraille coupe la ligne de vue du S.O. !"
		_push_log(tf_msg)
		_emit_feedback("train_fantome", "train_fantome", "RER B — Train Fantôme", tf_msg, true)
		train_fantome_arrived_sig.emit()

	if crs_ticks <= 0:
		GameState.modify_moral("all", -8)
		GameState.notoriete += 1
		_finish("crs_rush", "Les bottes CRS claquent dans les escaliers : la bande file in extremis dans le souterrain sous les sirènes (-8 Moral, +1 Notoriété).")
		return

func _execute_enemy_turn(enemy: Dictionary) -> void:
	var eid: String = str(enemy.get("id", ""))
	var ename: String = str(enemy.get("name", eid))
	var bark: String = str(enemy.get("bark", ""))
	if eid == "skin_nerveux":
		_push_log("%s lance une Menace d'Aura ! La pression monte dans le souterrain." % ename)
		_apply_moral_hit("karim", -7)
		_apply_moral_hit("leader", -4)
	elif eid == "cousin_so":
		_push_log("%s bloque la grille du quai et lâche une insulte sèche envers les gars de la Dalle !" % ename)
		_apply_moral_hit("karim", -10)
	elif eid == "so_veteran":
		enemy["counter_ready"] = true
		_push_log("%s cogne sa matraque contre le rail et menace de vous embarquer au poste !" % ename)
		_apply_moral_hit("all", -5)
	var line_msg: String = bark if bark != "" else ("%s passe à l'offensive !" % ename)
	_emit_feedback("enemy", eid, ename, line_msg, true)

func _apply_moral_hit(char_id: String, delta: int) -> void:
	var final_delta: int = delta
	if interposition_shield > 0 and final_delta < 0:
		final_delta = mini(0, final_delta + 6)
		interposition_shield = maxi(0, interposition_shield - 1)
		_push_log("Interposition : l'impact sur le Moral est amorti !")
	GameState.modify_moral(char_id, final_delta)

func _check_crisis_triggers() -> void:
	for a in allies:
		if not bool(a.get("present", false)):
			continue
		var cid: String = str(a.get("char_id", ""))
		var st: Dictionary = GameState.get_member_state(cid)
		var cdef: Dictionary = DataLoader.get_character(cid)
		var moral: int = int(st.get("moral", 60))
		var threshold: int = int(cdef.get("stress_threshold", 35))
		if moral <= threshold and not _is_in_crisis_queue(cid) and not GameState.has_flag("crisis_done_" + cid):
			GameState.set_flag("crisis_done_" + cid, true)
			crisis_queue.append({
				"char_id": cid,
				"ticks_left": 2,
				"label": str(cdef.get("crisis_label", "Crise d'autonomie"))
			})
			AudioRadio.play_crisis_buzz()
			var p_msg: String = "PRÉAVIS CRISE D'AUTONOMIE (%s) : %s serre les poings (explosion dans 2 crans — utilise 'Retenir' !)" % [str(cdef.get("name", cid)), str(cdef.get("stress_name", "Stress"))]
			_push_log(p_msg)
			_emit_feedback("crisis_warn", cid, str(cdef.get("name", cid)), p_msg, false)

func _execute_autonomous_crisis(cid: String) -> void:
	var cdef: Dictionary = DataLoader.get_character(cid)
	var cname: String = str(cdef.get("name", cid))
	AudioRadio.play_interrupt_hit()
	var target: Dictionary = _ensure_valid_target()
	var c_msg: String = ""
	if cid == "karim":
		if not target.is_empty():
			_damage_enemy(target, 2)
		crs_ticks = maxi(1, crs_ticks - 1)
		GameState.notoriete += 1
		c_msg = "CRISE D'AUTONOMIE ! Karim explose (« Laisse béton ! ») : coup de sang sur le S.O. (-2 résol), mais le vacarme rapproche les CRS (-1 cran, +1 Notoriété) !"
	elif cid == "nadia":
		escape_progress += 1
		GameState.modify_moral("nadia", -6)
		c_msg = "CRISE D'AUTONOMIE ! Nadia décroche vers les néons de la voie (+1 échappée, -6 Moral)."
	elif cid == "manu":
		if not target.is_empty():
			_damage_enemy(target, 2)
		GameState.modify_moral("manu", -4)
		c_msg = "CRISE D'AUTONOMIE ! Manu démarre au quart de tour, clé à molette en main (-2 résol sur %s, -4 Moral) !" % str(target.get("name", "S.O."))
	elif cid == "zoe":
		if not target.is_empty():
			target["next_tick"] = int(target.get("next_tick", 1)) + 1
			_remove_pending_enemy(str(target.get("id", "")))
		crs_ticks = maxi(1, crs_ticks - 1)
		GameState.modify_moral("zoe", -5)
		c_msg = "CRISE D'AUTONOMIE ! Zoé nargue le S.O. en plein néon (+1 cran cible, -1 cran CRS, -5 Moral) !"
	elif cid == "ludo":
		crs_ticks = maxi(1, crs_ticks - 1)
		GameState.modify_moral("ludo", -5)
		c_msg = "CRISE D'AUTONOMIE ! Ludo panique et attire l'attention sur l'escalier (-1 cran CRS, -5 Moral)."
	else:
		GameState.modify_moral(cid, -5)
		c_msg = "CRISE D'AUTONOMIE ! %s agit sous pression sans attendre les ordres !" % cname
	_push_log(c_msg)
	_emit_feedback("crisis", cid, cname, c_msg, true)

func _sync_step_state() -> void:
	if not active:
		awaiting_step = false
		pending_beat_label = ""
		return
	if not _pending_crisis_ids.is_empty():
		var cid: String = _pending_crisis_ids[0]
		var cname: String = str(DataLoader.get_character(cid).get("name", cid))
		awaiting_step = true
		pending_beat_label = "Crise : %s !" % cname
		return
	if not _pending_enemy_ids.is_empty():
		var eid: String = _pending_enemy_ids[0]
		var ed: Dictionary = _find_enemy(eid)
		awaiting_step = true
		pending_beat_label = "Action : %s" % str(ed.get("name", eid))
		return
	if get_acting_ally().is_empty():
		awaiting_step = true
		pending_beat_label = "Avancer au cran suivant"
		return
	awaiting_step = false
	pending_beat_label = ""

func _emit_feedback(kind: String, actor_id: String, actor_name: String, text: String, shake: bool) -> void:
	last_event = {
		"kind": kind,
		"actor_id": actor_id,
		"actor_name": actor_name,
		"text": text,
		"shake": shake
	}
	combat_feedback_emitted.emit(last_event)

func _find_rescuer_for(crisis_char_id: String) -> Dictionary:
	for a in allies:
		var cid: String = str(a.get("char_id", ""))
		if cid != crisis_char_id and bool(a.get("present", false)) and bool(a.get("reaction_ready", false)):
			return a
	return {}

func _remove_pending_enemy(eid: String) -> void:
	var idx: int = _pending_enemy_ids.find(eid)
	if idx >= 0:
		_pending_enemy_ids.remove_at(idx)

func _remove_pending_crisis(cid: String) -> void:
	var idx: int = _pending_crisis_ids.find(cid)
	if idx >= 0:
		_pending_crisis_ids.remove_at(idx)

func _is_in_crisis_queue(cid: String) -> bool:
	for cr in crisis_queue:
		if str(cr.get("char_id", "")) == cid:
			return true
	return false

func _find_ally(cid: String) -> Dictionary:
	for a in allies:
		if str(a.get("char_id", "")) == cid:
			return a
	return {}

func _find_enemy(eid: String) -> Dictionary:
	for e in enemies:
		if str(e.get("id", "")) == eid:
			return e
	return {}

func _peek_selected_target() -> Dictionary:
	if selected_target_id != "":
		var chosen: Dictionary = _find_enemy(selected_target_id)
		if not chosen.is_empty() and not bool(chosen.get("defeated", false)):
			return chosen
	return _get_first_active_enemy()

func _ensure_valid_target() -> Dictionary:
	if selected_target_id != "":
		var chosen: Dictionary = _find_enemy(selected_target_id)
		if not chosen.is_empty() and not bool(chosen.get("defeated", false)):
			return chosen
	var fallback: Dictionary = _get_first_active_enemy()
	selected_target_id = str(fallback.get("id", "")) if not fallback.is_empty() else ""
	return fallback

func _get_first_active_enemy() -> Dictionary:
	var best: Dictionary = {}
	var best_tick: int = 999
	for e in enemies:
		if not bool(e.get("defeated", false)):
			var nt: int = int(e.get("next_tick", 99))
			if nt < best_tick:
				best_tick = nt
				best = e
	return best

func _damage_enemy(enemy: Dictionary, dmg: int) -> void:
	var r: int = int(enemy.get("resolve", 1)) - dmg
	enemy["resolve"] = maxi(0, r)
	if r <= 0:
		enemy["defeated"] = true
		_remove_pending_enemy(str(enemy.get("id", "")))
		_push_log("→ %s lâche l'affaire et recule !" % str(enemy.get("name", "")))

func _all_enemies_defeated() -> bool:
	for e in enemies:
		if not bool(e.get("defeated", false)):
			return false
	return true

func _finish(outcome_id: String, summary: String) -> void:
	active = false
	awaiting_step = false
	pending_beat_label = ""
	_pending_enemy_ids.clear()
	_pending_crisis_ids.clear()
	GameState.last_encounter_outcome = outcome_id
	GameState.set_flag("encounter_gare_done", true)
	GameState.add_log(summary)
	timeline_updated.emit()
	encounter_finished.emit(outcome_id, summary)

func _push_log(msg: String) -> void:
	combat_log.append(msg)
	if combat_log.size() > 12:
		combat_log.remove_at(0)
