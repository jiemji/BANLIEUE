## Hook scripté optionnel (Option 2A) du gabarit de scénario _template_scenario.
## Remarque : ne jamais utiliser `:=` sur une valeur Variant (règle du validateur GDScript).
extends RefCounted

func on_encounter_start(_tl: Node, gs: Node, _dl: Node, _ctx: Dictionary) -> void:
	gs.call("set_flag", "demo_hook_fired", true)
