## Hook scripté optionnel (Option 2A) du scénario témoin « Ronde de Nuit sur l'Ourcq ».
extends RefCounted

func on_encounter_start(_tl: Node, gs: Node, _dl: Node, _ctx: Dictionary) -> void:
	gs.call("set_flag", "ponton_hook_fired", true)
