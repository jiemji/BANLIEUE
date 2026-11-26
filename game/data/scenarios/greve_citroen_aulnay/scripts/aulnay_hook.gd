## Hook scripté optionnel (Option 2A) du scénario « Ondes Libres à Citroën Aulnay ».
extends RefCounted

func on_encounter_start(_tl: Node, gs: Node, _dl: Node, _ctx: Dictionary) -> void:
	gs.call("set_flag", "aulnay_hook_fired", true)
	if bool(gs.call("has_flag", "antenne_calee")):
		gs.call("modify_moral", "all", 4)
		gs.call("add_log", "98.4 FM porte loin : l'antenne des 3000 galvanise la bande (+4 Moral) !")
