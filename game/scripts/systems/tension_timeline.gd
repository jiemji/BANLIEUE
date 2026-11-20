extends Node

signal timeline_updated
signal encounter_finished(outcome_id: String, summary: String)
signal train_fantome_arrived_sig

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

var enemies: Array[Dictionary] = []
var allies: Array[Dictionary] = []
var crisis_queue: Array[Dictionary] = []
var combat_log: Array[String] = []

var _squad_manager: Node = null

func set_squad_manager(sm: Node) -> void:
	_squad_manager = sm

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
	enemies.clear()
	allies.clear()
	crisis_queue.clear()
	combat_log.clear()

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

	_check_crisis_triggers()
	AudioRadio.play_cassette_click()
	timeline_updated.emit()

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

func execute_player_action(action_id: String) -> void:
	if not active:
		return
	var actor: Dictionary = get_acting_ally()
	if actor.is_empty():
		_advance_world_ticks()
		return

	var actor_name: String = str(actor.get("name", "Leader"))
	var target: Dictionary = _get_first_active_enemy()

	if action_id == "act_tchatche":
		if not target.is_empty():
			var dmg: int = 2
			if GameState.faveurs > 0 or GameState.has_flag("tour_b_done"):
				dmg = 3
			_damage_enemy(target, dmg)
			_push_log("%s balance les preuves et l'arrêté bidon ! %s perd %d de résolution." % [actor_name, str(target.get("name", "")), dmg])
	elif action_id == "act_pression":
		if not target.is_empty():
			var dmg_p: int = 2 + (1 if GameState.get_total_fasa() >= 5 else 0)
			_damage_enemy(target, dmg_p)
			target["next_tick"] = int(target.get("next_tick", 1)) + 1
			_push_log("%s met son FASA sur la table : %s recule (-%d résolution, +1 cran)." % [actor_name, str(target.get("name", "")), dmg_p])
	elif action_id == "act_repli":
		crs_ticks += 2
		escape_progress += 1
		_push_log("%s repère l'issue vers le quai / les chaufferies (+2 crans CRS, échappée %d/2)." % [actor_name, escape_progress])
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

	_advance_world_ticks()

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
	for e in enemies:
		if not bool(e.get("defeated", false)) and bool(e.get("counter_ready", false)):
			e["counter_ready"] = false
			_push_log("CONTRE-INTERRUPTION ! %s tente un Coup de pression sur %s !" % [str(e.get("name", "")), cname])
			_apply_moral_hit(char_id, -6)

	if spec == "moquerie":
		var target: Dictionary = _get_first_active_enemy()
		if not target.is_empty():
			target["next_tick"] = int(target.get("next_tick", 1)) + 2
			_damage_enemy(target, 1)
			_push_log("INTERRUPTION [Moquerie] — %s casse la charge de %s (-1 résol, +2 crans) !" % [cname, str(target.get("name", ""))])
	elif spec == "interposition":
		interposition_shield += 1
		GameState.modify_moral(char_id, 4)
		_push_log("INTERRUPTION [Interposition] — %s fait bloc sous le réverbère (prochain coup moral amorti) !" % cname)
	elif spec == "reflexe_rue":
		crs_ticks += 2
		escape_progress += 1
		_push_log("INTERRUPTION [Réflexe de rue] — %s pousse une grille métallique (+2 crans CRS, accès quai ouvert) !" % cname)
	elif spec == "sang_froid":
		# Spécialité de L'Échappé·e des Pavillons : calme prioritairement une crise imminente, sinon perce un bluff adverse.
		if not crisis_queue.is_empty():
			var cr: Dictionary = crisis_queue[0]
			var cr_cid: String = str(cr.get("char_id", ""))
			crisis_queue.remove_at(0)
			GameState.modify_moral(cr_cid, 10)
			_push_log("INTERRUPTION [Sang-froid] — %s reprend la main et calme %s à temps (+10 Moral) !" % [cname, cr_cid.capitalize()])
		else:
			var target_sf: Dictionary = _get_first_active_enemy()
			if not target_sf.is_empty():
				target_sf["next_tick"] = int(target_sf.get("next_tick", 1)) + 1
				_damage_enemy(target_sf, 1)
				_push_log("INTERRUPTION [Sang-froid] — %s perce le bluff de %s (-1 résol, +1 cran) !" % [cname, str(target_sf.get("name", ""))])
			else:
				GameState.modify_moral(char_id, 6)
				_push_log("INTERRUPTION [Sang-froid] — %s garde la tête froide (+6 Moral)." % cname)

	if _all_enemies_defeated():
		_finish("social_win", "Entre tchatche, vannes et nerfs d'acier, vous retournez la rue ! Le S.O. lâche l'affaire avant l'arrivée des CRS.")
		return

	timeline_updated.emit()

func restrain_crisis(crisis_char_id: String) -> void:
	if not active:
		return
	var rescuer: Dictionary = {}
	for a in allies:
		var cid: String = str(a.get("char_id", ""))
		if cid != crisis_char_id and bool(a.get("present", false)) and bool(a.get("reaction_ready", false)):
			rescuer = a
			break
	if rescuer.is_empty():
		_push_log("Personne n'a de Réaction disponible pour retenir %s !" % crisis_char_id)
		timeline_updated.emit()
		return

	rescuer["reaction_ready"] = false
	for i in range(crisis_queue.size() - 1, -1, -1):
		if str(crisis_queue[i].get("char_id", "")) == crisis_char_id:
			crisis_queue.remove_at(i)
	GameState.modify_moral(crisis_char_id, 8)
	_push_log("%s plaque %s contre le mur et le calme à temps : Crise d'autonomie contenue (+8 Moral) !" % [str(rescuer.get("name", "")), crisis_char_id.capitalize()])
	AudioRadio.play_cassette_click()
	timeline_updated.emit()

func has_restrain_reaction_for(crisis_char_id: String) -> bool:
	for a in allies:
		var cid: String = str(a.get("char_id", ""))
		if cid != crisis_char_id and bool(a.get("present", false)) and bool(a.get("reaction_ready", false)):
			return true
	return false

func can_escape_now() -> bool:
	return train_fantome_arrived or escape_progress >= 2

func get_ordered_rail_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for a in allies:
		if bool(a.get("present", false)):
			entries.append({
				"kind": "ally",
				"id": str(a.get("char_id", "")),
				"label": str(a.get("name", "")).split(" ")[0],
				"tick": int(a.get("next_tick", 0)),
				"color": str(a.get("color_hex", "#f28c28")),
				"sub": "Prêt" if int(a.get("next_tick", 0)) == 0 else "Réact." if bool(a.get("reaction_ready", false)) else ""
			})
		else:
			entries.append({
				"kind": "reinforcement",
				"id": str(a.get("char_id", "")),
				"label": "Renfort " + str(a.get("name", "")).split(" ")[0],
				"tick": int(a.get("reinforce_in_ticks", 2)),
				"color": "#7ec4cf",
				"sub": "103 SP / pied"
			})
	for e in enemies:
		if not bool(e.get("defeated", false)):
			entries.append({
				"kind": "enemy",
				"id": str(e.get("id", "")),
				"label": str(e.get("name", "")),
				"tick": int(e.get("next_tick", 1)),
				"color": "#d92b2b",
				"sub": "Rés.%d" % int(e.get("resolve", 1))
			})
	for cr in crisis_queue:
		entries.append({
			"kind": "crisis",
			"id": str(cr.get("char_id", "")),
			"label": "CRISE " + str(cr.get("char_id", "")).to_upper(),
			"tick": int(cr.get("ticks_left", 1)),
			"color": "#ff3838",
			"sub": "Préavis !"
		})
	entries.append({
		"kind": "crs",
		"id": "crs",
		"label": "Patrouille CRS",
		"tick": maxi(0, crs_ticks),
		"color": "#3d85ff",
		"sub": "Sirènes"
	})
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(x.get("tick", 0)) < int(y.get("tick", 0))
	)
	return entries

func _advance_world_ticks() -> void:
	while active:
		# Vérifier si un allié présent est à 0
		if not get_acting_ally().is_empty():
			break

		# Faire reculer d'1 cran tous les compteurs
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
					_push_log("RENFORT ! %s déboule sur le quai à temps pour couvrir la bande !" % str(a.get("name", "")))
			else:
				a["next_tick"] = maxi(0, int(a.get("next_tick", 1)) - 1)

		# Crises d'autonomie en préavis
		for i in range(crisis_queue.size() - 1, -1, -1):
			var cr: Dictionary = crisis_queue[i]
			var tl: int = int(cr.get("ticks_left", 1)) - 1
			cr["ticks_left"] = tl
			crisis_queue[i] = cr
			if tl <= 0:
				crisis_queue.remove_at(i)
				_execute_autonomous_crisis(str(cr.get("char_id", "")))

		# Ennemis avancent et agissent à 0
		for e in enemies:
			if bool(e.get("defeated", false)):
				continue
			var nt: int = int(e.get("next_tick", 1)) - 1
			e["next_tick"] = nt
			if nt <= 0:
				_execute_enemy_turn(e)
				e["next_tick"] = int(e.get("speed", 2))

		# Apparition ambiguë du Train Fantôme au quai de la gare du Y
		if not train_fantome_arrived and turn_count >= train_fantome_turn * 2:
			train_fantome_arrived = true
			_push_log("PHÉNOMÈNE AMBIGU : Un RER B sans annonce ni voyageurs entre en gare avec une girouette inconnue — sa ferraille coupe la ligne de vue du S.O. !")
			train_fantome_arrived_sig.emit()

		if _all_enemies_defeated():
			_finish("social_win", "Pression retournée ! Le S.O. municipal et le Skin battent en retraite avant que les CRS ne bouclent l'avenue.")
			return

		if crs_ticks <= 0:
			GameState.modify_moral("all", -8)
			GameState.notoriete += 1
			_finish("crs_rush", "Les bottes CRS claquent dans les escaliers : la bande file in extremis dans le souterrain sous les sirènes (-8 Moral, +1 Notoriété).")
			return

		_check_crisis_triggers()
		if not get_acting_ally().is_empty():
			break

	timeline_updated.emit()

func _execute_enemy_turn(enemy: Dictionary) -> void:
	var eid: String = str(enemy.get("id", ""))
	var ename: String = str(enemy.get("name", eid))
	if eid == "skin_nerveux":
		_push_log("%s lance une Menace FASA ! La pression monte dans le souterrain." % ename)
		_apply_moral_hit("karim", -7)
		_apply_moral_hit("leader", -4)
	elif eid == "cousin_so":
		_push_log("%s bloque la grille du quai et lâche une insulte sèche envers les gars de la Dalle !" % ename)
		_apply_moral_hit("karim", -10)
	elif eid == "so_veteran":
		enemy["counter_ready"] = true
		_push_log("%s cogne sa matraque contre le rail et menace de vous embarquer au poste !" % ename)
		_apply_moral_hit("all", -5)

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
			_push_log("PRÉAVIS CRISE D'AUTONOMIE (%s) : %s serre les poings (explosion dans 2 crans — utilise 'Retenir' !)" % [str(cdef.get("name", cid)), str(cdef.get("stress_name", "Stress"))])

func _execute_autonomous_crisis(cid: String) -> void:
	var cdef: Dictionary = DataLoader.get_character(cid)
	var cname: String = str(cdef.get("name", cid))
	AudioRadio.play_interrupt_hit()
	if cid == "karim":
		var target: Dictionary = _get_first_active_enemy()
		if not target.is_empty():
			_damage_enemy(target, 2)
		crs_ticks = maxi(1, crs_ticks - 1)
		GameState.notoriete += 1
		_push_log("CRISE D'AUTONOMIE ! Karim explose (« Laisse béton ! ») : coup de sang sur le S.O. (-2 résol), mais le vacarme rapproche les CRS (-1 cran, +1 Notoriété) !")
	elif cid == "nadia":
		escape_progress += 1
		GameState.modify_moral("nadia", -6)
		_push_log("CRISE D'AUTONOMIE ! Nadia décroche vers les néons de la voie (+1 échappée, -6 Moral).")
	else:
		GameState.modify_moral(cid, -5)
		_push_log("CRISE D'AUTONOMIE ! %s agit sous pression sans attendre les ordres !" % cname)

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
		_push_log("→ %s lâche l'affaire et recule !" % str(enemy.get("name", "")))

func _all_enemies_defeated() -> bool:
	for e in enemies:
		if not bool(e.get("defeated", false)):
			return false
	return true

func _finish(outcome_id: String, summary: String) -> void:
	active = false
	GameState.last_encounter_outcome = outcome_id
	GameState.set_flag("encounter_gare_done", true)
	GameState.add_log(summary)
	timeline_updated.emit()
	encounter_finished.emit(outcome_id, summary)

func _push_log(msg: String) -> void:
	combat_log.append(msg)
	if combat_log.size() > 12:
		combat_log.remove_at(0)
