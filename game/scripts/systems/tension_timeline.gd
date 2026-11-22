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
var _used_equip_actions: Dictionary = {}
var _interposition_absorb: int = 6

const _EQUIP_ACTION_META: Dictionary = {
	"act_equip_intimidation_look": {"short": "Intimidation Look", "title": "Intimidation Look (Perfecto 1982)", "skill": "baston_pression", "bonus": 2, "bonus_label": "Perfecto", "needs_target": true},
	"act_equip_infiltration": {"short": "Infiltration", "title": "Infiltration discrète (Parka)", "skill": "caves_esquive", "bonus": 2, "bonus_label": "Parka", "needs_target": false},
	"act_equip_boombox": {"short": "Son de Dalle", "title": "Son de Dalle (Ghetto-blaster K7)", "skill": "solidarite_bande", "bonus": 1, "bonus_label": "Boombox", "needs_target": false},
	"act_equip_pochoir": {"short": "Pochoir", "title": "Bomber un mot d'ordre (Pochoir)", "skill": "systeme_d", "bonus": 1, "bonus_label": "Pochoir", "needs_target": true},
	"act_equip_record_fm": {"short": "Capter FM", "title": "Enregistrer la Fréquence (Walkman FM)", "skill": "ondes_radio", "bonus": 1, "bonus_label": "Walkman FM", "needs_target": false},
	"act_equip_pass_mjc": {"short": "Pass Mairie", "title": "Pass Mairie / Carte MJC", "skill": "lecture_rue", "bonus": 2, "bonus_label": "Pass Mairie", "needs_target": true},
	"act_equip_pause_musique": {"short": "Pause TDK", "title": "Pause musique (Cassettes TDK)", "skill": "sang_froid_nerfs", "bonus": 1, "bonus_label": "TDK", "needs_target": false},
	"act_equip_pass_tour": {"short": "Gaine Tour B", "title": "Gaine Tour B (Trousseau)", "skill": "systeme_d", "bonus": 1, "bonus_label": "Trousseau", "needs_target": false}
}

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
	_used_equip_actions.clear()
	_interposition_absorb = 6

	# Ennemis depuis JSON
	var e_list_var: Variant = enc.get("enemies", [])
	if e_list_var is Array:
		for item in (e_list_var as Array):
			if item is Dictionary:
				var ed: Dictionary = (item as Dictionary).duplicate(true)
				var eid: String = str(ed.get("id", ""))
				var res_max: int = int(ed.get("resolve_max", 3))
				if eid == "cousin_so" and GameState.has_flag("ludo_bluffed_cousin"):
					res_max = maxi(2, res_max - 1)
				ed["resolve"] = res_max
				ed["resolve_max"] = res_max
				ed["next_tick"] = int(ed.get("initial_tick", 2))
				var c_ready: bool = bool(ed.get("has_counter_interrupt", false))
				if eid == "so_veteran" and GameState.has_flag("so_veteran_spotted"):
					c_ready = false
				ed["counter_ready"] = c_ready
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
	if GameState.has_flag("so_veteran_spotted"):
		_push_log("Repérage ruelle : la contre-interruption initiale du Chef S.O. Vétéran est neutralisée !")
	for a_item in allies:
		if bool(a_item.get("present", false)):
			var acid: String = str(a_item.get("char_id", ""))
			for act_d in GameState.get_unlocked_equipment_actions(acid):
				if str(act_d.get("id", "")) == "act_equip_caves":
					escape_progress += 1
					_push_log("Passe des chaufferies équipé (%s) : +1 progression Échappée !" % str(a_item.get("name", acid)))
					break

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

## Exécute une action tactique du tour actif (Jet de rue 2d6 + Carac + Comp) puis prépare le pas-à-pas suivant.
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
	if action_id == "act_escape_now":
		if can_escape_now():
			_finish("escaped", "Échappée nocturne réussie ! Profitant de la rame du Train Fantôme et de l'ombre du quai, la bande sème le S.O. et les CRS avant de filer sous la Dalle.")
		return

	var pv: Dictionary = _build_action_preview(action_id, actor_id)
	if not bool(pv.get("valid", false)):
		return

	var target: Dictionary = _ensure_valid_target()
	var skill_id: String = str(pv.get("skill_id", "tchatche"))
	var dc: int = int(pv.get("dc", 10))
	var bonus: int = int(pv.get("bonus", 0))
	var bonus_lbl: String = str(pv.get("bonus_label", ""))
	var roll_res: Dictionary = GameState.perform_street_roll(actor_id, skill_id, dc, bonus, bonus_lbl)
	var ok: bool = bool(roll_res.get("success", false))
	var is_bril: bool = bool(roll_res.get("is_brilliant", false))
	var is_crit_s: bool = bool(roll_res.get("is_crit_success", false))
	var is_flaw_b: bool = bool(roll_res.get("is_flaw_blunder", false))
	var roll_hdr: String = str(roll_res.get("roll_summary", ""))
	var fb_kind: String = "ally_brilliant" if is_bril else ("ally_action" if ok else ("ally_flaw" if is_flaw_b else "ally_action"))
	var shake_flag: bool = false
	var effect_msg: String = ""

	if _EQUIP_ACTION_META.has(action_id):
		var u_key: String = "%s:%s" % [actor_id, action_id]
		_used_equip_actions[u_key] = true

	if action_id == "act_tchatche":
		if not target.is_empty():
			var base_dmg: int = 3 if (GameState.faveurs > 0 or GameState.has_flag("tour_b_done")) else 2
			if ok:
				var dmg_t: int = (base_dmg + 1) if is_crit_s else (maxi(3, base_dmg) if is_bril else base_dmg)
				_damage_enemy(target, dmg_t)
				effect_msg = "%s balance les preuves ! %s perd %d de résolution." % [actor_name, str(target.get("name", "")), dmg_t]
				shake_flag = is_bril
			elif is_flaw_b:
				_apply_moral_hit(actor_id, -4)
				effect_msg = "Couac de tchatche (%s) : bafouillage devant le quai (0 dégât, -4 Moral) !" % actor_name
				AudioRadio.play_crisis_buzz()
				shake_flag = true
			else:
				_damage_enemy(target, 1)
				effect_msg = "Tchatche tiède de %s : %s encaisse seulement -1 de résolution." % [actor_name, str(target.get("name", ""))]
	elif action_id == "act_pression":
		if not target.is_empty():
			if ok:
				var dmg_p: int = 3 if is_bril else 2
				var push_c: int = 2 if is_crit_s else 1
				_damage_enemy(target, dmg_p)
				target["next_tick"] = int(target.get("next_tick", 1)) + push_c
				_remove_pending_enemy(str(target.get("id", "")))
				effect_msg = "%s impose son Aura : %s recule (-%d résol., +%d cran) !" % [actor_name, str(target.get("name", "")), dmg_p, push_c]
				shake_flag = true
			elif is_flaw_b:
				_apply_moral_hit(actor_id, -5)
				effect_msg = "Couac de pression (%s) : le S.O. rigole sous ton nez (0 dégât, -5 Moral) !" % actor_name
				AudioRadio.play_crisis_buzz()
				shake_flag = true
			else:
				_damage_enemy(target, 1)
				effect_msg = "Pression hésitante (%s) : -1 résolution sur %s sans le faire reculer." % [actor_name, str(target.get("name", ""))]
	elif action_id == "act_repli":
		if ok:
			var crs_g: int = 3 if is_bril else 2
			crs_ticks += crs_g
			escape_progress += 1
			effect_msg = "%s ouvre la voie vers le quai / les caves (+%d crans CRS, échappée %d/2)." % [actor_name, crs_g, escape_progress]
		elif is_flaw_b:
			_apply_moral_hit(actor_id, -4)
			effect_msg = "Couac d'esquive (%s) : grille bloquée, zéro cran gagné (-4 Moral) !" % actor_name
			AudioRadio.play_crisis_buzz()
			shake_flag = true
		else:
			crs_ticks += 1
			effect_msg = "%s contourne à demi (+1 cran CRS seulement, échappée %d/2)." % [actor_name, escape_progress]
	elif action_id == "act_equip_intimidation_look":
		if not target.is_empty():
			if ok:
				var dmg_il: int = 4 if is_bril else 3
				_damage_enemy(target, dmg_il)
				target["next_tick"] = int(target.get("next_tick", 1)) + 2
				target["counter_ready"] = false
				_remove_pending_enemy(str(target.get("id", "")))
				effect_msg = "[Perfecto] %s glace %s (-%d résol., +2 crans, contre coupé) !" % [actor_name, str(target.get("name", "")), dmg_il]
				shake_flag = true
			elif is_flaw_b:
				_apply_moral_hit(actor_id, -4)
				effect_msg = "[Perfecto] Couac de dégaine (%s) : 0 dégât, -4 Moral !" % actor_name
				AudioRadio.play_crisis_buzz()
				shake_flag = true
			else:
				_damage_enemy(target, 1)
				target["next_tick"] = int(target.get("next_tick", 1)) + 1
				_remove_pending_enemy(str(target.get("id", "")))
				effect_msg = "[Perfecto] Pression partielle sur %s (-1 résol., +1 cran)." % str(target.get("name", ""))
	elif action_id == "act_equip_infiltration":
		if ok:
			var crs_inf: int = 3 if is_bril else 2
			crs_ticks += crs_inf
			escape_progress += 1
			interposition_shield += 1
			effect_msg = "[Parka anonyme] %s se fond dans l'ombre (+%d crans CRS, +1 échappée, +1 bouclier) !" % [actor_name, crs_inf]
		elif is_flaw_b:
			_apply_moral_hit(actor_id, -6)
			effect_msg = "[Parka anonyme] Lampadaire en pleine poire ! (-6 Moral, +0 CRS)"
			AudioRadio.play_crisis_buzz()
			shake_flag = true
		else:
			crs_ticks += 1
			escape_progress += 1
			_apply_moral_hit(actor_id, -3)
			effect_msg = "[Parka anonyme] Passage serré (+1 CRS, +1 échappée, -3 Moral)."
	elif action_id == "act_equip_boombox":
		if ok:
			var mor_b: int = 12 if is_bril else 8
			GameState.modify_moral("all", mor_b)
			_delay_crises_by(1)
			effect_msg = "[Ghetto-blaster] Le son retourne la dalle ! (+%d Moral à tous, crises retardées +1 cran)" % mor_b
		else:
			GameState.modify_moral("all", 4)
			crs_ticks = maxi(1, crs_ticks - 1)
			effect_msg = "[Ghetto-blaster] Vacarme sur le quai (+4 Moral à tous, mais -1 cran CRS !)."
			if is_flaw_b:
				AudioRadio.play_crisis_buzz()
				shake_flag = true
	elif action_id == "act_equip_pochoir":
		if not target.is_empty():
			if ok:
				var dmg_p1: int = 3 if is_bril else 2
				_damage_enemy(target, dmg_p1)
				for oe in enemies:
					if str(oe.get("id", "")) != str(target.get("id", "")) and not bool(oe.get("defeated", false)):
						_damage_enemy(oe, 1)
				GameState.notoriete += 1
				effect_msg = "[Pochoir] Mot d'ordre claqué sous leur nez (-%d résol. cible, -1 aux autres, +1 Notoriété) !" % dmg_p1
				shake_flag = true
			elif is_flaw_b:
				_apply_moral_hit(actor_id, -6)
				effect_msg = "[Pochoir] Buse bouchée en pleine rue ! (-6 Moral)"
				AudioRadio.play_crisis_buzz()
				shake_flag = true
			else:
				_damage_enemy(target, 1)
				_apply_moral_hit(actor_id, -3)
				effect_msg = "[Pochoir] Slogan baveux sur %s (-1 résol., -3 Moral)." % str(target.get("name", ""))
	elif action_id == "act_equip_record_fm":
		if ok:
			crs_ticks += 2
			escape_progress += 1
			turn_count += 2
			effect_msg = "[Walkman FM] Onde calée sur le quai (+2 CRS, +1 échappée, signal Train Fantôme rapproché) !"
			_maybe_trigger_train_fantome()
		elif is_flaw_b:
			_apply_moral_hit(actor_id, -8)
			effect_msg = "[Walkman FM] Larsen glaçant sur 104.7 FM ! (-8 Moral)"
			AudioRadio.play_crisis_buzz()
			shake_flag = true
		else:
			crs_ticks += 1
			_apply_moral_hit(actor_id, -5)
			effect_msg = "[Walkman FM] Friture parasite (+1 CRS, -5 Moral)."
	elif action_id == "act_equip_pass_mjc":
		if not target.is_empty():
			if ok:
				var dmg_mjc: int = 3 if is_bril else 2
				_damage_enemy(target, dmg_mjc)
				target["counter_ready"] = false
				crs_ticks += 1
				effect_msg = "[Pass Mairie] %s sort la carte officielle : %s se fige (-%d résol., contre coupé, +1 CRS) !" % [actor_name, str(target.get("name", "")), dmg_mjc]
			elif is_flaw_b:
				_apply_moral_hit(actor_id, -7)
				effect_msg = "[Pass Mairie] Le tampon sonne faux ! (-7 Moral)"
				AudioRadio.play_crisis_buzz()
				shake_flag = true
			else:
				_damage_enemy(target, 1)
				_apply_moral_hit(actor_id, -4)
				effect_msg = "[Pass Mairie] Papier contesté (-1 résol., -4 Moral)."
	elif action_id == "act_equip_pause_musique":
		var low_id: String = _get_lowest_moral_present_ally_id(actor_id)
		if ok:
			var mor_t: int = 14 if is_bril else 10
			GameState.modify_moral(low_id, mor_t)
			_delay_crisis_for(low_id, 1)
			var lname: String = str(DataLoader.get_character(low_id).get("name", low_id))
			effect_msg = "[Cassettes TDK] Quelques mesures apaisent %s (+%d Moral, crise retardée +1 cran) !" % [lname, mor_t]
		elif is_flaw_b:
			effect_msg = "[Cassettes TDK] Bande emmêlée dans le boîtier (0 Moral récupéré) !"
			AudioRadio.play_crisis_buzz()
		else:
			GameState.modify_moral(actor_id, 5)
			effect_msg = "[Cassettes TDK] Souffle court retrouvé (+5 Moral pour %s)." % actor_name
	elif action_id == "act_equip_pass_tour":
		if ok:
			var crs_pt: int = 3 if is_bril else 2
			crs_ticks += crs_pt
			escape_progress += 1
			effect_msg = "[Trousseau caves] Trappe technique ouverte (+%d crans CRS, échappée %d/2) !" % [crs_pt, escape_progress]
		elif is_flaw_b:
			_apply_moral_hit(actor_id, -6)
			effect_msg = "[Trousseau caves] Clé tordue dans la serrure (-6 Moral, +0 CRS) !"
			AudioRadio.play_crisis_buzz()
			shake_flag = true
		else:
			crs_ticks += 1
			_apply_moral_hit(actor_id, -3)
			effect_msg = "[Trousseau caves] Trappe grinçante (+1 CRS, -3 Moral)."

	_push_log(roll_hdr)
	if effect_msg != "":
		_push_log(effect_msg)
	_emit_feedback(fb_kind, actor_id, actor_name, "%s | %s" % [roll_hdr, effect_msg], shake_flag)

	# Recharge réaction de l'allié qui vient de jouer son tour et le replace à +2 crans
	actor["reaction_ready"] = true
	actor["next_tick"] = 2
	AudioRadio.play_cassette_click()

	if _all_enemies_defeated():
		_finish("social_win", "Le S.O. municipal plie devant vos preuves et la réputation du quartier ! L'arrêté bidon du Galaxian tombe à l'eau avant même l'arrivée des CRS.")
		return

	_ensure_valid_target()
	_check_crisis_triggers()
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
			var dmg_mq: int = 2 if GameState.get_effective_skill(char_id, "tchatche") >= 3 else 1
			target["next_tick"] = int(target.get("next_tick", 1)) + 2
			_damage_enemy(target, dmg_mq)
			_remove_pending_enemy(str(target.get("id", "")))
			var m_msg: String = "INTERRUPTION [Moquerie] — %s casse la charge de %s (-%d résol, +2 crans) !" % [cname, str(target.get("name", "")), dmg_mq]
			_push_log(m_msg)
			if not counter_triggered:
				_emit_feedback("interrupt", char_id, cname, m_msg, true)
	elif spec == "interposition":
		var abs_pow: int = 8 if (GameState.get_effective_skill(char_id, "baston_pression") >= 3 or GameState.get_effective_characteristic(char_id, "corps") >= 4) else 6
		_interposition_absorb = maxi(_interposition_absorb, abs_pow)
		interposition_shield += 1
		GameState.modify_moral(char_id, 4)
		var i_msg: String = "INTERRUPTION [Interposition] — %s fait bloc sous le réverbère (+4 Moral, prochain coup -%d) !" % [cname, abs_pow]
		_push_log(i_msg)
		if not counter_triggered:
			_emit_feedback("interrupt", char_id, cname, i_msg, false)
	elif spec == "reflexe_rue":
		var crs_g_r: int = 3 if GameState.get_effective_skill(char_id, "caves_esquive") >= 3 else 2
		crs_ticks += crs_g_r
		escape_progress += 1
		var rx_msg: String = "INTERRUPTION [Réflexe de rue] — %s pousse une grille métallique (+%d crans CRS, accès quai ouvert) !" % [cname, crs_g_r]
		_push_log(rx_msg)
		if not counter_triggered:
			_emit_feedback("interrupt", char_id, cname, rx_msg, false)
	elif spec == "sang_froid":
		# Spécialité de L'Échappé·e des Pavillons : calme prioritairement une crise imminente, sinon perce un bluff adverse.
		var mor_sf: int = 12 if GameState.get_effective_skill(char_id, "sang_froid_nerfs") >= 3 else 10
		if not crisis_queue.is_empty():
			var cr: Dictionary = crisis_queue[0]
			var cr_cid: String = str(cr.get("char_id", ""))
			crisis_queue.remove_at(0)
			_remove_pending_crisis(cr_cid)
			GameState.modify_moral(cr_cid, mor_sf)
			var sf_msg: String = "INTERRUPTION [Sang-froid] — %s reprend la main et calme %s à temps (+%d Moral) !" % [cname, cr_cid.capitalize(), mor_sf]
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

## Retourne la liste ordonnée des actions disponibles pour le membre au cran 0 (base + équipement + échappée).
func get_available_actions_for_actor() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not active:
		return out
	var actor: Dictionary = get_acting_ally()
	var actor_id: String = str(actor.get("char_id", ""))
	if actor_id == "":
		actor_id = _peek_next_present_ally_id()

	var enc: Dictionary = DataLoader.get_encounter(encounter_id)
	var act_list_var: Variant = enc.get("player_actions", [])
	if act_list_var is Array:
		for av in (act_list_var as Array):
			if av is Dictionary:
				var ad: Dictionary = av as Dictionary
				var aid: String = str(ad.get("id", ""))
				var pv: Dictionary = _build_action_preview(aid, actor_id)
				out.append({
					"id": aid,
					"short_label": str(ad.get("label", aid)),
					"chance_pct": int(pv.get("chance_pct", 0)),
					"is_flaw": bool(pv.get("is_flaw", false)),
					"is_equipment": false,
					"used": false,
					"tooltip": "%s\n%s" % [str(ad.get("desc", "")), str(pv.get("roll_formula", ""))]
				})

	for eq_act in GameState.get_unlocked_equipment_actions(actor_id):
		var eq_id: String = str(eq_act.get("id", ""))
		if _EQUIP_ACTION_META.has(eq_id):
			var meta: Dictionary = _EQUIP_ACTION_META.get(eq_id, {}) as Dictionary
			var pv_eq: Dictionary = _build_action_preview(eq_id, actor_id)
			var u_key: String = "%s:%s" % [actor_id, eq_id]
			var is_used: bool = bool(_used_equip_actions.get(u_key, false))
			out.append({
				"id": eq_id,
				"short_label": str(meta.get("short", eq_act.get("label", eq_id))),
				"chance_pct": int(pv_eq.get("chance_pct", 0)),
				"is_flaw": bool(pv_eq.get("is_flaw", false)),
				"is_equipment": true,
				"used": is_used,
				"tooltip": "%s\n%s" % [str(eq_act.get("desc", "")), str(pv_eq.get("roll_formula", ""))]
			})

	if can_escape_now():
		out.append({
			"id": "act_escape_now",
			"short_label": "Filer par le Quai !",
			"chance_pct": 0,
			"is_flaw": false,
			"is_equipment": false,
			"used": false,
			"tooltip": "Repli immédiat de toute la bande vers le souterrain."
		})
	return out

## Prévisualisation en lecture seule d'une action tactique sur la cible active et le rail.
func preview_player_action(action_id: String) -> Dictionary:
	if not active:
		return {"valid": false, "reason": "Hors confrontation"}
	var acting: Dictionary = get_acting_ally()
	if awaiting_step or acting.is_empty():
		return {"valid": false, "reason": "Appuie d'abord sur Espace pour résoudre le beat en attente."}
	return _build_action_preview(action_id, str(acting.get("char_id", "leader")))

## Calcule en lecture seule le résultat prévisionnel d'une action tactique ou d'équipement pour un PJ.
func _build_action_preview(action_id: String, actor_id: String) -> Dictionary:
	var target: Dictionary = _peek_selected_target()
	if action_id == "act_escape_now":
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
			"chance_pct": 0,
			"skill_id": "",
			"skill_name": "",
			"skill_val": 0,
			"dc": 0,
			"bonus": 0,
			"bonus_label": "",
			"is_flaw": false,
			"roll_formula": "",
			"fail_summary": "",
			"is_equipment": false,
			"used": false,
			"reason": "Échappée non ouverte (2/2 ou Train Fantôme requis)" if not can_esc else "",
			"summary": "Repli immédiat de toute la bande vers le souterrain"
		}

	if action_id == "act_tchatche":
		if target.is_empty():
			return {"valid": false, "reason": "Aucune cible active."}
		var dc_t: int = int(target.get("dc_social", 11))
		if str(target.get("id", "")) == "cousin_so" and GameState.has_flag("ludo_bluffed_cousin"):
			dc_t -= 1
		var bonus_t: int = 1 if (GameState.faveurs > 0 or GameState.has_flag("tour_b_done")) else 0
		var bl_t: String = "Faveur/Dossier" if bonus_t > 0 else ""
		var rp_t: Dictionary = GameState.preview_street_roll(actor_id, "tchatche", dc_t, bonus_t, bl_t)
		var dmg_t: int = 3 if bonus_t > 0 else 2
		var ft_t: int = int(target.get("next_tick", 0))
		var is_fl_t: bool = bool(rp_t.get("is_flaw", false))
		var fs_t: String = "0 dégât & -4 Moral" if is_fl_t else "-1 Résol."
		return {
			"valid": true,
			"kind": "action",
			"title": "Tchatche / Bluff Attitude",
			"target_id": str(target.get("id", "")),
			"target_name": str(target.get("name", "")),
			"from_tick": ft_t,
			"to_tick": ft_t,
			"resolve_delta": -dmg_t,
			"crs_delta": 0,
			"escape_delta": 0,
			"shield_delta": 0,
			"moral_delta": 0,
			"counter_warning": false,
			"counter_label": "",
			"chance_pct": int(rp_t.get("chance_pct", 50)),
			"skill_id": "tchatche",
			"skill_name": str(rp_t.get("skill_name", "Tchatche")),
			"skill_val": int(rp_t.get("skill_val", 0)),
			"dc": dc_t,
			"bonus": bonus_t,
			"bonus_label": bl_t,
			"is_flaw": is_fl_t,
			"roll_formula": str(rp_t.get("formula", "")),
			"fail_summary": fs_t,
			"is_equipment": false,
			"used": false,
			"summary": "%s : -%d Résol. si réussi (raté : %s)" % [str(target.get("name", "")), dmg_t, fs_t]
		}

	if action_id == "act_pression":
		if target.is_empty():
			return {"valid": false, "reason": "Aucune cible active."}
		var dc_p: int = int(target.get("dc_pression", 11))
		var aura_tot: int = GameState.get_total_aura()
		var bonus_p: int = 2 if aura_tot >= 7 else (1 if aura_tot >= 5 else 0)
		var bl_p: String = ("Aura %d" % aura_tot) if bonus_p > 0 else ""
		var rp_p: Dictionary = GameState.preview_street_roll(actor_id, "baston_pression", dc_p, bonus_p, bl_p)
		var ft_p: int = int(target.get("next_tick", 0))
		var is_fl_p: bool = bool(rp_p.get("is_flaw", false))
		var fs_p: String = "0 dégât & -5 Moral" if is_fl_p else "-1 Résol. (0 recul)"
		return {
			"valid": true,
			"kind": "action",
			"title": "Coup de pression (Aura)",
			"target_id": str(target.get("id", "")),
			"target_name": str(target.get("name", "")),
			"from_tick": ft_p,
			"to_tick": ft_p + 1,
			"resolve_delta": -2,
			"crs_delta": 0,
			"escape_delta": 0,
			"shield_delta": 0,
			"moral_delta": 0,
			"counter_warning": false,
			"counter_label": "",
			"chance_pct": int(rp_p.get("chance_pct", 50)),
			"skill_id": "baston_pression",
			"skill_name": str(rp_p.get("skill_name", "Caisse")),
			"skill_val": int(rp_p.get("skill_val", 0)),
			"dc": dc_p,
			"bonus": bonus_p,
			"bonus_label": bl_p,
			"is_flaw": is_fl_p,
			"roll_formula": str(rp_p.get("formula", "")),
			"fail_summary": fs_p,
			"is_equipment": false,
			"used": false,
			"summary": "%s : -2 Résol. · Cran %d → %d (raté : %s)" % [str(target.get("name", "")), ft_p, ft_p + 1, fs_p]
		}

	if action_id == "act_repli":
		var dc_r: int = 10 + (1 if crs_ticks <= 2 else 0)
		var rp_r: Dictionary = GameState.preview_street_roll(actor_id, "caves_esquive", dc_r, 0, "")
		var is_fl_r: bool = bool(rp_r.get("is_flaw", false))
		var fs_r: String = "+0 CRS & -4 Moral" if is_fl_r else "+1 CRS (0 Échappée)"
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
			"chance_pct": int(rp_r.get("chance_pct", 50)),
			"skill_id": "caves_esquive",
			"skill_name": str(rp_r.get("skill_name", "Caves & Esquive")),
			"skill_val": int(rp_r.get("skill_val", 0)),
			"dc": dc_r,
			"bonus": 0,
			"bonus_label": "",
			"is_flaw": is_fl_r,
			"roll_formula": str(rp_r.get("formula", "")),
			"fail_summary": fs_r,
			"is_equipment": false,
			"used": false,
			"summary": "CRS Cran %d → %d · Échappée %d → %d/2 (raté : %s)" % [crs_ticks, crs_ticks + 2, escape_progress, mini(2, escape_progress + 1), fs_r]
		}

	if _EQUIP_ACTION_META.has(action_id):
		if not GameState.has_equipped_action(actor_id, action_id):
			return {"valid": false, "reason": "Équipement non porté par le membre actif"}
		var u_key: String = "%s:%s" % [actor_id, action_id]
		if bool(_used_equip_actions.get(u_key, false)):
			return {"valid": false, "reason": "Action d'équipement déjà utilisée dans cette confrontation", "used": true, "is_equipment": true}
		var meta: Dictionary = _EQUIP_ACTION_META.get(action_id, {}) as Dictionary
		var needs_tgt: bool = bool(meta.get("needs_target", false))
		if needs_tgt and target.is_empty():
			return {"valid": false, "reason": "Aucune cible active."}
		var sk_e: String = str(meta.get("skill", "systeme_d"))
		var b_e: int = int(meta.get("bonus", 1))
		var bl_e: String = str(meta.get("bonus_label", "Objet"))
		var dc_e: int = 10
		if action_id == "act_equip_intimidation_look":
			dc_e = int(target.get("dc_pression", 11))
		elif action_id == "act_equip_pochoir" or action_id == "act_equip_pass_mjc":
			dc_e = int(target.get("dc_social", 11))
		elif action_id == "act_equip_pause_musique":
			dc_e = 9
		var rp_e: Dictionary = GameState.preview_street_roll(actor_id, sk_e, dc_e, b_e, bl_e)
		var is_fl_e: bool = bool(rp_e.get("is_flaw", false))
		var tid_e: String = str(target.get("id", "")) if needs_tgt else ("crs" if (action_id == "act_equip_infiltration" or action_id == "act_equip_record_fm" or action_id == "act_equip_pass_tour") else actor_id)
		var tname_e: String = str(target.get("name", "")) if needs_tgt else ("Patrouille CRS / Quai" if tid_e == "crs" else actor_id.capitalize())
		var ft_e: int = int(target.get("next_tick", 0)) if needs_tgt else (crs_ticks if tid_e == "crs" else 0)
		var tt_e: int = (ft_e + 2) if action_id == "act_equip_intimidation_look" else (crs_ticks + 2 if (action_id == "act_equip_infiltration" or action_id == "act_equip_record_fm" or action_id == "act_equip_pass_tour") else (crs_ticks + 1 if action_id == "act_equip_pass_mjc" else ft_e))
		var rd_e: int = -3 if action_id == "act_equip_intimidation_look" else ((-2 if (action_id == "act_equip_pochoir" or action_id == "act_equip_pass_mjc") else 0))
		var cd_e: int = 2 if (action_id == "act_equip_infiltration" or action_id == "act_equip_record_fm" or action_id == "act_equip_pass_tour") else (1 if action_id == "act_equip_pass_mjc" else 0)
		var ed_e: int = 1 if (action_id == "act_equip_infiltration" or action_id == "act_equip_record_fm" or action_id == "act_equip_pass_tour") else 0
		var md_e: int = 8 if action_id == "act_equip_boombox" else (10 if action_id == "act_equip_pause_musique" else 0)
		var sum_e: String = "Effet équipement spécial"
		var fail_e: String = "Effet réduit (-Moral)"
		if action_id == "act_equip_intimidation_look":
			sum_e = "%s : -3 Résol · Cran %d→%d · coupe Contre" % [tname_e, ft_e, tt_e]
			fail_e = "0 dégât & -4 Moral" if is_fl_e else "-1 Résol · +1 cran"
		elif action_id == "act_equip_infiltration":
			sum_e = "CRS %d→%d · Échappée +1 · Bouclier +1" % [crs_ticks, crs_ticks + 2]
			fail_e = "+0 CRS & -6 Moral" if is_fl_e else "+1 CRS, +1 Échappée, -3 Moral"
		elif action_id == "act_equip_boombox":
			sum_e = "+8 Moral à tous · Crises +1 cran"
			fail_e = "+4 Moral mais -1 cran CRS"
		elif action_id == "act_equip_pochoir":
			sum_e = "%s -2 Résol · -1 aux autres · +1 Notoriété" % tname_e
			fail_e = "-6 Moral" if is_fl_e else "-1 Résol cible, -3 Moral"
		elif action_id == "act_equip_record_fm":
			sum_e = "CRS +2 · Échappée +1 · Rapproche Train Fantôme"
			fail_e = "-8 Moral" if is_fl_e else "+1 CRS, -5 Moral"
		elif action_id == "act_equip_pass_mjc":
			sum_e = "%s -2 Résol · coupe Contre · +1 CRS" % tname_e
			fail_e = "-7 Moral" if is_fl_e else "-1 Résol, -4 Moral"
		elif action_id == "act_equip_pause_musique":
			sum_e = "+10 Moral allié fragile · retarde crise +1 cran"
			fail_e = "Bande emmêlée (0 Moral)" if is_fl_e else "+5 Moral à l'acteur"
		elif action_id == "act_equip_pass_tour":
			sum_e = "CRS %d→%d · Échappée +1" % [crs_ticks, crs_ticks + 2]
			fail_e = "-6 Moral" if is_fl_e else "+1 CRS, -3 Moral"
		return {
			"valid": true,
			"kind": "action",
			"title": str(meta.get("title", action_id)),
			"target_id": tid_e,
			"target_name": tname_e,
			"from_tick": ft_e,
			"to_tick": tt_e,
			"resolve_delta": rd_e,
			"crs_delta": cd_e,
			"escape_delta": ed_e,
			"shield_delta": 1 if action_id == "act_equip_infiltration" else 0,
			"moral_delta": md_e,
			"counter_warning": false,
			"counter_label": "",
			"chance_pct": int(rp_e.get("chance_pct", 50)),
			"skill_id": sk_e,
			"skill_name": str(rp_e.get("skill_name", sk_e)),
			"skill_val": int(rp_e.get("skill_val", 0)),
			"dc": dc_e,
			"bonus": b_e,
			"bonus_label": bl_e,
			"is_flaw": is_fl_e,
			"roll_formula": str(rp_e.get("formula", "")),
			"fail_summary": fail_e,
			"is_equipment": true,
			"used": false,
			"summary": "%s (raté : %s)" % [sum_e, fail_e]
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
		var dmg_mq: int = 2 if GameState.get_effective_skill(char_id, "tchatche") >= 3 else 1
		var ft: int = int(target.get("next_tick", 1))
		return {
			"valid": true,
			"kind": "interruption",
			"title": "%s — Moquerie" % cname,
			"target_id": str(target.get("id", "")),
			"target_name": str(target.get("name", "")),
			"from_tick": ft,
			"to_tick": ft + 2,
			"resolve_delta": -dmg_mq,
			"crs_delta": 0,
			"escape_delta": 0,
			"shield_delta": 0,
			"moral_delta": 0,
			"counter_warning": counter_warn,
			"counter_label": counter_lbl,
			"summary": "%s : -%d Résol · recule Cran %d → %d" % [str(target.get("name", "")), dmg_mq, ft, ft + 2]
		}
	elif spec == "interposition":
		var abs_pow: int = 8 if (GameState.get_effective_skill(char_id, "baston_pression") >= 3 or GameState.get_effective_characteristic(char_id, "corps") >= 4) else 6
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
			"summary": "Bouclier Interposition +1 (-%d dégâts au prochain coup) · +4 Moral" % abs_pow
		}
	elif spec == "reflexe_rue":
		var crs_g_r: int = 3 if GameState.get_effective_skill(char_id, "caves_esquive") >= 3 else 2
		return {
			"valid": true,
			"kind": "interruption",
			"title": "%s — Réflexe de rue" % cname,
			"target_id": "crs",
			"target_name": "Patrouille CRS / Quai",
			"from_tick": crs_ticks,
			"to_tick": crs_ticks + crs_g_r,
			"resolve_delta": 0,
			"crs_delta": crs_g_r,
			"escape_delta": 1,
			"shield_delta": 0,
			"moral_delta": 0,
			"counter_warning": counter_warn,
			"counter_label": counter_lbl,
			"summary": "CRS Cran %d → %d · Échappée +1" % [crs_ticks, crs_ticks + crs_g_r]
		}
	elif spec == "sang_froid":
		var mor_sf: int = 12 if GameState.get_effective_skill(char_id, "sang_froid_nerfs") >= 3 else 10
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
				"moral_delta": mor_sf,
				"counter_warning": counter_warn,
				"counter_label": counter_lbl,
				"summary": "Annule la crise de %s · +%d Moral" % [cr_name, mor_sf]
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

## Retourne la liste ordonnée des fiches unifiées de la Frise (alliés + crises intégrées, renforts, ennemis, CRS).
func get_ordered_rail_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var acting: Dictionary = get_acting_ally()
	var acting_id: String = str(acting.get("char_id", ""))
	var crisis_map: Dictionary = {}
	for cr in crisis_queue:
		crisis_map[str(cr.get("char_id", ""))] = cr

	for a in allies:
		var cid: String = str(a.get("char_id", ""))
		var cdef: Dictionary = DataLoader.get_character(cid)
		var st: Dictionary = GameState.get_member_state(cid)
		var portrait_p: String = str(cdef.get("portrait", ""))
		var att_val: int = GameState.get_effective_attitude_for(cid)
		var aura_val: int = GameState.get_effective_aura_for(cid)
		var moral_val: int = int(st.get("moral", 60))
		var moral_max_val: int = GameState.get_effective_moral_max(cid)
		var stress_thr: int = GameState.get_effective_stress_threshold(cid)
		if bool(a.get("present", false)):
			var nt: int = int(a.get("next_tick", 0))
			var r_ready: bool = bool(a.get("reaction_ready", false))
			var sp_name: String = str(a.get("specialty_name", ""))
			var in_crisis: bool = crisis_map.has(cid)
			var cr_ticks: int = -1
			var cr_label: String = ""
			if in_crisis:
				var cr_d: Dictionary = crisis_map[cid] as Dictionary
				cr_ticks = int(cr_d.get("ticks_left", 1))
				cr_label = str(cr_d.get("label", "Crise d'autonomie"))
			var is_acting_now: bool = (cid == acting_id and not awaiting_step) or (not _pending_crisis_ids.is_empty() and _pending_crisis_ids[0] == cid)
			var eff_tick: int = mini(nt, cr_ticks) if in_crisis else nt
			var s_rank: int = 0 if is_acting_now else (1 if in_crisis else 2)
			entries.append({
				"kind": "ally",
				"id": cid,
				"label": str(a.get("name", "")).split(" ")[0],
				"tick": eff_tick,
				"turn_tick": nt,
				"color": str(a.get("color_hex", "#f28c28")),
				"sub": "Prêt" if (nt == 0 and cid == acting_id) else "Réact." if r_ready else "",
				"portrait": portrait_p,
				"acting": is_acting_now,
				"intent": sp_name,
				"counter_ready": false,
				"selected": false,
				"attitude": att_val,
				"aura": aura_val,
				"moral": moral_val,
				"moral_max": moral_max_val,
				"stress_threshold": stress_thr,
				"reaction_ready": r_ready,
				"specialty_name": sp_name,
				"in_crisis": in_crisis,
				"crisis_ticks": cr_ticks,
				"crisis_label": cr_label,
				"sort_rank": s_rank
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
				"selected": false,
				"attitude": att_val,
				"aura": aura_val,
				"moral": moral_val,
				"moral_max": moral_max_val,
				"sort_rank": 4
			})
	for e in enemies:
		if not bool(e.get("defeated", false)):
			var eid: String = str(e.get("id", ""))
			var is_e_acting: bool = (not _pending_enemy_ids.is_empty() and _pending_enemy_ids[0] == eid)
			var e_res: int = int(e.get("resolve", 1))
			var e_res_max: int = int(e.get("resolve_max", 1))
			entries.append({
				"kind": "enemy",
				"id": eid,
				"label": str(e.get("name", "")),
				"tick": int(e.get("next_tick", 1)),
				"color": "#d92b2b",
				"sub": "Rés.%d/%d" % [e_res, e_res_max],
				"portrait": str(e.get("portrait", "res://assets/portraits/so_agent.png")),
				"acting": is_e_acting,
				"intent": str(e.get("intent_label", "")),
				"counter_ready": bool(e.get("counter_ready", false)),
				"counter_label": str(e.get("counter_label", "")),
				"resolve": e_res,
				"resolve_max": e_res_max,
				"role": str(e.get("role", "")),
				"selected": (eid == selected_target_id),
				"sort_rank": 0 if is_e_acting else 3
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
		"selected": false,
		"sort_rank": 5
	})
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var tx: int = int(x.get("tick", 0))
		var ty: int = int(y.get("tick", 0))
		if tx != ty:
			return tx < ty
		return int(x.get("sort_rank", 9)) < int(y.get("sort_rank", 9))
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
	_maybe_trigger_train_fantome()

	if crs_ticks <= 0:
		GameState.modify_moral("all", -8)
		GameState.notoriete += 1
		_finish("crs_rush", "Les bottes CRS claquent dans les escaliers : la bande file in extremis dans le souterrain sous les sirènes (-8 Moral, +1 Notoriété).")
		return

## Déclenche l'arrivée du Train Fantôme RER B dès que le compteur de tours atteint son seuil.
func _maybe_trigger_train_fantome() -> void:
	if not train_fantome_arrived and turn_count >= train_fantome_turn * 2:
		train_fantome_arrived = true
		var tf_msg: String = "PHÉNOMÈNE AMBIGU : Un RER B sans annonce entre en gare — sa ferraille coupe la ligne de vue du S.O. !"
		_push_log(tf_msg)
		_emit_feedback("train_fantome", "train_fantome", "RER B — Train Fantôme", tf_msg, true)
		train_fantome_arrived_sig.emit()

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
		final_delta = mini(0, final_delta + _interposition_absorb)
		interposition_shield = maxi(0, interposition_shield - 1)
		if interposition_shield == 0:
			_interposition_absorb = 6
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
		var threshold: int = GameState.get_effective_stress_threshold(cid)
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
	var xp_reward: int = 35 if outcome_id == "social_win" else (30 if outcome_id == "escaped" else 15)
	GameState.add_xp("all", xp_reward)
	if outcome_id == "social_win" or outcome_id == "escaped":
		GameState.add_trait("leader", "Sang-froid du Quai Y")
	GameState.add_log(summary)
	timeline_updated.emit()
	encounter_finished.emit(outcome_id, summary)

func _push_log(msg: String) -> void:
	combat_log.append(msg)
	if combat_log.size() > 12:
		combat_log.remove_at(0)

## Retourne l'ID de l'allié présent le plus proche du cran 0 (repli lorsque awaiting_step est actif).
func _peek_next_present_ally_id() -> String:
	var best_id: String = "leader"
	var best_t: int = 999
	for a in allies:
		if bool(a.get("present", false)):
			var nt: int = int(a.get("next_tick", 99))
			if nt < best_t:
				best_t = nt
				best_id = str(a.get("char_id", "leader"))
	return best_id

## Retourne l'ID de l'allié présent dont le Moral est actuellement le plus bas.
func _get_lowest_moral_present_ally_id(fallback_id: String) -> String:
	var best_id: String = fallback_id
	var low_m: int = 999
	for a in allies:
		if bool(a.get("present", false)):
			var cid: String = str(a.get("char_id", ""))
			var m: int = int(GameState.get_member_state(cid).get("moral", 60))
			if m < low_m:
				low_m = m
				best_id = cid
	return best_id

## Retarde toutes les Crises d'autonomie en préavis de ticks_add crans.
func _delay_crises_by(ticks_add: int) -> void:
	for i in range(crisis_queue.size()):
		var cr: Dictionary = crisis_queue[i]
		cr["ticks_left"] = int(cr.get("ticks_left", 1)) + ticks_add
		crisis_queue[i] = cr
		_remove_pending_crisis(str(cr.get("char_id", "")))

## Retarde d'un nombre de crans donné le préavis de Crise d'autonomie d'un PJ ciblé.
func _delay_crisis_for(char_id: String, ticks_add: int) -> void:
	for i in range(crisis_queue.size()):
		var cr: Dictionary = crisis_queue[i]
		if str(cr.get("char_id", "")) == char_id:
			cr["ticks_left"] = int(cr.get("ticks_left", 1)) + ticks_add
			crisis_queue[i] = cr
			_remove_pending_crisis(char_id)
