extends Node

const SquadManagerScript: GDScript = preload("res://scripts/systems/squad_manager.gd")
const TensionTimelineScript: GDScript = preload("res://scripts/systems/tension_timeline.gd")
const DialogueRunnerScript: GDScript = preload("res://scripts/systems/dialogue_runner.gd")
const IsoDistrictViewScript: GDScript = preload("res://scripts/world/iso_district_view.gd")
const HudOverlayScript: GDScript = preload("res://scripts/ui/hud_overlay.gd")
const DialoguePanelScript: GDScript = preload("res://scripts/ui/dialogue_panel.gd")
const TimelinePanelScript: GDScript = preload("res://scripts/ui/timeline_panel.gd")
const FilmShader: Shader = preload("res://shaders/film_1982_post.gdshader")

var _squad: Node = null
var _timeline: Node = null
var _dialogue_runner: Node = null

var _iso_view: Node2D = null
var _hud: Control = null
var _dlg_panel: Control = null
var _tl_panel: Control = null

var _shader_mat: ShaderMaterial = null
var _sas_overlay: ColorRect = null
var _sas_label: Label = null
var _end_overlay: ColorRect = null
var _end_summary_lbl: Label = null

var _sas_active: bool = false
var _sas_timer: float = 0.0

func _ready() -> void:
	# 1. Systèmes métiers
	_squad = SquadManagerScript.new()
	add_child(_squad)

	_timeline = TensionTimelineScript.new()
	_timeline.call("set_squad_manager", _squad)
	add_child(_timeline)

	_dialogue_runner = DialogueRunnerScript.new()
	add_child(_dialogue_runner)

	# 2. Vue Isométrique du monde
	_iso_view = IsoDistrictViewScript.new()
	add_child(_iso_view)

	# 3. Calque Post-Process 1982 (grain + bascule N&B/4 couleurs-signaux)
	var fx_layer: CanvasLayer = CanvasLayer.new()
	fx_layer.layer = 5
	add_child(fx_layer)

	var fx_rect: ColorRect = ColorRect.new()
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = FilmShader
	_shader_mat.set_shader_parameter("night_amount", 0.0)
	_shader_mat.set_shader_parameter("grain_strength", 0.042)
	_shader_mat.set_shader_parameter("low_moral_amount", 0.0)
	_shader_mat.set_shader_parameter("shake_amount", 0.0)
	fx_rect.material = _shader_mat
	fx_layer.add_child(fx_rect)

	# 4. Calque UI
	var ui_layer: CanvasLayer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	_hud = HudOverlayScript.new()
	ui_layer.add_child(_hud)

	_dlg_panel = DialoguePanelScript.new()
	ui_layer.add_child(_dlg_panel)

	_tl_panel = TimelinePanelScript.new()
	_tl_panel.call("bind_timeline", _timeline)
	ui_layer.add_child(_tl_panel)

	_build_sas_overlay(ui_layer)
	_build_end_overlay(ui_layer)

	# 5. Câblage des signaux
	_wire_signals()

	# 6. Lancement de la scène d'ouverture au Box-Garage
	_sync_world_location()
	_dialogue_runner.call("start_dialogue", "intro_box_garage")

func _build_sas_overlay(parent_layer: CanvasLayer) -> void:
	_sas_overlay = ColorRect.new()
	_sas_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sas_overlay.color = Color(0.05, 0.05, 0.07, 0.86)
	_sas_overlay.visible = false
	parent_layer.add_child(_sas_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sas_overlay.add_child(center)

	_sas_label = Label.new()
	_sas_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sas_label.add_theme_font_size_override("font_size", 22)
	_sas_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	_sas_label.text = "CRÉPUSCULE SUR CRADON-LÈS-GONESSE\n\nLes rideaux de fer tombent. Un Boeing de Roissy rase la Dalle.\nLes réverbères sodium s'allument — la rue change de règles."
	center.add_child(_sas_label)

func _build_end_overlay(parent_layer: CanvasLayer) -> void:
	_end_overlay = ColorRect.new()
	_end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_overlay.color = Color(0.04, 0.04, 0.06, 0.90)
	_end_overlay.visible = false
	parent_layer.add_child(_end_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 380)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.10)
	sb.border_color = Color(0.85, 0.17, 0.17)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var title: Label = Label.new()
	title.text = "JALON 0 TERMINÉ — « Couvre-Feu au Galaxian »"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	vb.add_child(title)

	_end_summary_lbl = Label.new()
	_end_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_summary_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_end_summary_lbl.add_theme_font_size_override("font_size", 14)
	vb.add_child(_end_summary_lbl)

	var btn_replay: Button = Button.new()
	btn_replay.text = "Rejouer le Niveau-Pilote"
	btn_replay.pressed.connect(_restart_slice)
	vb.add_child(btn_replay)

func _wire_signals() -> void:
	_iso_view.hotspot_activated.connect(func(dlg_id: String, _hs: Dictionary) -> void:
		_dialogue_runner.call("start_dialogue", dlg_id)
	)

	_hud.squad_regroup_requested.connect(func() -> void: _squad.call("regroup_all"))
	_hud.squad_split_2_1_requested.connect(func() -> void: _squad.call("split_2_1"))
	_hud.squad_split_1_1_1_requested.connect(func() -> void: _squad.call("split_1_1_1"))
	_hud.group_switch_requested.connect(func(gid: int) -> void: _squad.call("switch_to_group", gid))
	_hud.group_order_cycle_requested.connect(func(gid: int) -> void: _squad.call("cycle_group_order", gid))
	_hud.location_travel_requested.connect(func(lid: String) -> void: _squad.call("move_active_group", lid))
	_hud.twilight_requested.connect(_start_twilight_sas)
	_hud.restart_slice_requested.connect(_restart_slice)

	_dlg_panel.choice_selected.connect(func(idx: int) -> void: _dialogue_runner.call("pick_choice", idx))
	_dialogue_runner.node_updated.connect(func(_id: String, node_data: Dictionary, choices: Array) -> void:
		_dlg_panel.call("show_node", node_data, choices)
	)
	_dialogue_runner.dialogue_finished.connect(func() -> void: _dlg_panel.call("hide_panel"))
	_dialogue_runner.move_requested.connect(func(lid: String) -> void: _squad.call("move_active_group", lid))
	_dialogue_runner.twilight_requested.connect(_start_twilight_sas)
	_dialogue_runner.encounter_requested.connect(func(eid: String) -> void: _timeline.call("start_encounter", eid))
	_dialogue_runner.slice_completed.connect(_show_end_summary)

	_timeline.train_fantome_arrived_sig.connect(func() -> void: _iso_view.call("trigger_train_fantome"))
	_timeline.encounter_finished.connect(_on_encounter_finished)

	GameState.active_group_changed.connect(func(_gid: int) -> void: _sync_world_location())
	GameState.state_changed.connect(_on_state_changed)

func _process(delta: float) -> void:
	if _sas_active:
		_sas_timer += delta
		var prog: float = clampf(_sas_timer / 2.6, 0.0, 1.0)
		_shader_mat.set_shader_parameter("night_amount", prog)
		_shader_mat.set_shader_parameter("shake_amount", sin(prog * PI) * 0.0045)
		if _sas_timer >= 2.6:
			_sas_active = false
			_sas_overlay.visible = false
			_shader_mat.set_shader_parameter("shake_amount", 0.0)
			GameState.set_phase("night")
			GameState.add_log("22 h 10 — La nuit est tombée sur Cradon-lès-Gonesse. Cap sur la Gare RER « du Y » !")
			_iso_view.queue_redraw()

	_update_input_lock()

func _unhandled_input(event: InputEvent) -> void:
	if _sas_active or _end_overlay.visible or _tl_panel.visible or _dlg_panel.visible:
		return
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_1:
				_squad.call("switch_to_group", 0)
			elif kev.keycode == KEY_2:
				_squad.call("switch_to_group", 1)
			elif kev.keycode == KEY_3:
				_squad.call("switch_to_group", 2)

func _on_state_changed() -> void:
	_sync_world_location()
	if not _sas_active:
		var night_val: float = 1.0 if GameState.phase == "night" else 0.0
		_shader_mat.set_shader_parameter("night_amount", night_val)
	var low_m: int = GameState.get_lowest_moral()
	var lm_amount: float = clampf(float(55 - low_m) / 35.0, 0.0, 1.0)
	_shader_mat.set_shader_parameter("low_moral_amount", lm_amount)

func _sync_world_location() -> void:
	var target_loc: String = GameState.get_active_location_id()
	if str(_iso_view.get("current_loc_id")) != target_loc:
		_iso_view.call("set_location", target_loc)
	else:
		_iso_view.queue_redraw()

func _start_twilight_sas() -> void:
	if GameState.phase != "day":
		return
	_sas_active = true
	_sas_timer = 0.0
	_sas_overlay.visible = true
	GameState.set_phase("twilight")
	AudioRadio.play_boeing_roar()

func _on_encounter_finished(_outcome_id: String, _summary: String) -> void:
	_squad.call("regroup_all")
	_squad.call("move_active_group", "box_garage")
	_dialogue_runner.call("start_dialogue", "box_garage_debrief")

func _show_end_summary() -> void:
	var outcome_label: String = "Victoire sociale devant le S.O."
	if GameState.last_encounter_outcome == "escaped":
		outcome_label = "Échappée nocturne par le Quai / Train Fantôme"
	elif GameState.last_encounter_outcome == "crs_rush":
		outcome_label = "Repli d'urgence face aux sirènes CRS"

	var ludo_txt: String = "Recruté au Box-Garage !" if GameState.has_flag("ludo_recruited") else "Resté dehors pour ce soir (+1 Faveur)"
	var moral_lines: Array[String] = []
	for cid in GameState.squad_members:
		var cdef: Dictionary = DataLoader.get_character(cid)
		var st: Dictionary = GameState.get_member_state(cid)
		moral_lines.append("• %s : %d / %d Moral" % [str(cdef.get("name", cid)), int(st.get("moral", 0)), int(st.get("moral_max", 100))])

	_end_summary_lbl.text = (
		"Issue à la Gare RER « du Y » : %s\n" +
		"Statut de Ludo : %s\n\n" +
		"Ressources finales : %d Francs  |  %d Faveurs  |  Notoriété %d  |  FASA %d\n\n" +
		"État de la bande :\n%s\n\n" +
		"Ce prototype Data-Driven valide la bascule libre (1/2/3), le Sas Boeing Jour→Nuit, " +
		"la Frise chronologique à Interruptions hors-tour et le préavis des Crises d'autonomie."
	) % [outcome_label, ludo_txt, GameState.francs, GameState.faveurs, GameState.notoriete, GameState.get_total_fasa(), "\n".join(moral_lines)]
	_end_overlay.visible = true

func _restart_slice() -> void:
	_end_overlay.visible = false
	_sas_overlay.visible = false
	_sas_active = false
	_timeline.set("active", false)
	_tl_panel.visible = false
	_dlg_panel.visible = false
	_iso_view.set("train_fantome_active", false)
	GameState.reset_new_slice()
	_sync_world_location()
	_dialogue_runner.call("start_dialogue", "intro_box_garage")

func _update_input_lock() -> void:
	var blocked: bool = _sas_active or _end_overlay.visible or _tl_panel.visible or _dlg_panel.visible
	_iso_view.set("input_blocked", blocked)
