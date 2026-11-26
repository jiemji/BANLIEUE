## Orchestrateur principal générique : machine d'états des écrans/menus, transitions N1–N4, Sas et routage pilotés par scenario.json.
extends Node

enum AppState {
	TITLE_MENU,
	NEW_GAME_SETUP,
	IN_GAME,
	PAUSE_MENU
}

const SquadManagerScript: GDScript = preload("res://scripts/systems/squad_manager.gd")
const TensionTimelineScript: GDScript = preload("res://scripts/systems/tension_timeline.gd")
const DialogueRunnerScript: GDScript = preload("res://scripts/systems/dialogue_runner.gd")
const WorldMapViewScript: GDScript = preload("res://scripts/world/world_map_view.gd")
const IsoDistrictViewScript: GDScript = preload("res://scripts/world/iso_district_view.gd")
const HudOverlayScript: GDScript = preload("res://scripts/ui/hud_overlay.gd")
const DialoguePanelScript: GDScript = preload("res://scripts/ui/dialogue_panel.gd")
const TimelinePanelScript: GDScript = preload("res://scripts/ui/timeline_panel.gd")
const CharacterSheetPanelScript: GDScript = preload("res://scripts/ui/character_sheet_panel.gd")
const TitleMenuPanelScript: GDScript = preload("res://scripts/ui/title_menu_panel.gd")
const SaveLoadPanelScript: GDScript = preload("res://scripts/ui/save_load_panel.gd")
const OptionsPanelScript: GDScript = preload("res://scripts/ui/options_panel.gd")
const NewGamePanelScript: GDScript = preload("res://scripts/ui/new_game_panel.gd")
const FilmShader: Shader = preload("res://shaders/film_1982_post.gdshader")

var _squad: Node = null
var _timeline: Node = null
var _dialogue_runner: Node = null

var _world_map_view: Node2D = null
var _iso_view: Node2D = null
var _hud: Control = null
var _dlg_panel: Control = null
var _tl_panel: Control = null
var _char_sheet_panel: Control = null

var _title_menu: Control = null
var _new_game_panel: Control = null
var _save_load_panel: Control = null
var _options_panel: Control = null

var _shader_mat: ShaderMaterial = null
var _sas_overlay: ColorRect = null
var _sas_label: Label = null
var _end_overlay: ColorRect = null
var _end_title_lbl: Label = null
var _end_summary_lbl: Label = null
var _btn_end_replay: Button = null

var _app_state: int = AppState.TITLE_MENU
var _new_game_caller: int = AppState.TITLE_MENU
var _sas_active: bool = false
var _sas_timer: float = 0.0
var _title_cycle_time: float = 0.0
var _combat_shake_timer: float = 0.0
var _last_encounter_id: String = ""

func _ready() -> void:
	# 1. Systèmes métiers
	_squad = SquadManagerScript.new()
	add_child(_squad)

	_timeline = TensionTimelineScript.new()
	_timeline.call("set_squad_manager", _squad)
	add_child(_timeline)

	_dialogue_runner = DialogueRunnerScript.new()
	add_child(_dialogue_runner)

	# 2. Vues du monde (Atlas N1-N3 + Intérieurs isométriques N4)
	_world_map_view = WorldMapViewScript.new()
	add_child(_world_map_view)

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
	_shader_mat.set_shader_parameter("grain_strength", SettingsManager.get_grain_strength())
	_shader_mat.set_shader_parameter("low_moral_amount", 0.0)
	_shader_mat.set_shader_parameter("shake_amount", 0.0)
	fx_rect.material = _shader_mat
	fx_layer.add_child(fx_rect)

	# 4. Calque UI en jeu
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

	_char_sheet_panel = CharacterSheetPanelScript.new()
	ui_layer.add_child(_char_sheet_panel)

	_build_sas_overlay(ui_layer)
	_build_end_overlay(ui_layer)

	# 5. Calque Menus (Accueil, Pause, Nouvelle partie, Sauvegardes, Options)
	var menu_layer: CanvasLayer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)

	_title_menu = TitleMenuPanelScript.new()
	menu_layer.add_child(_title_menu)

	_new_game_panel = NewGamePanelScript.new()
	menu_layer.add_child(_new_game_panel)

	_save_load_panel = SaveLoadPanelScript.new()
	menu_layer.add_child(_save_load_panel)

	_options_panel = OptionsPanelScript.new()
	menu_layer.add_child(_options_panel)

	# 6. Câblage des signaux
	_wire_signals()
	SettingsManager.settings_changed.connect(_apply_shader_settings)
	_apply_shader_settings()

	# 7. Entrée sur l'Écran d'accueil & Menu Principal unifié
	_enter_title_menu()

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
	_sas_label.text = ""
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

	_end_title_lbl = Label.new()
	_end_title_lbl.text = "SCÉNARIO TERMINÉ"
	_end_title_lbl.add_theme_font_size_override("font_size", 20)
	_end_title_lbl.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	vb.add_child(_end_title_lbl)

	_end_summary_lbl = Label.new()
	_end_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_summary_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_end_summary_lbl.add_theme_font_size_override("font_size", 14)
	vb.add_child(_end_summary_lbl)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vb.add_child(btn_row)

	var btn_save_end: Button = Button.new()
	btn_save_end.text = "Sauvegarder sur Cassette"
	btn_save_end.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save_end.pressed.connect(func() -> void: _save_load_panel.call("open_panel", "save"))
	btn_row.add_child(btn_save_end)

	_btn_end_replay = Button.new()
	_btn_end_replay.text = "Rejouer le Scénario"
	_btn_end_replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_end_replay.pressed.connect(_restart_slice)
	btn_row.add_child(_btn_end_replay)

	var btn_to_title: Button = Button.new()
	btn_to_title.text = "Retour au Menu Principal"
	btn_to_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_to_title.pressed.connect(_enter_title_menu)
	btn_row.add_child(btn_to_title)

func _wire_signals() -> void:
	_iso_view.hotspot_activated.connect(func(dlg_id: String, _hs: Dictionary) -> void:
		_dialogue_runner.call("start_dialogue", dlg_id)
	)
	_iso_view.exit_activated.connect(func(ex: Dictionary) -> void:
		var t_lvl: int = int(ex.get("target_level", 3))
		var t_id: String = str(ex.get("target_id", GameState.current_city_id))
		GameState.set_zoom_view(t_lvl, t_id)
	)
	_iso_view.squad_member_clicked.connect(func(gid: int, _cid: String) -> void:
		_squad.call("switch_to_group", gid)
	)
	_iso_view.call("bind_combat_timeline", _timeline)
	_iso_view.combat_actor_hovered.connect(func(k: String, eid: String) -> void:
		_tl_panel.call("on_stage_actor_hovered", k, eid)
	)
	_iso_view.combat_actor_clicked.connect(func(k: String, eid: String) -> void:
		_tl_panel.call("on_stage_actor_clicked", k, eid)
	)
	_iso_view.combat_cell_clicked.connect(func(gx: int, gy: int) -> void:
		_tl_panel.call("on_stage_cell_clicked", gx, gy)
	)
	_iso_view.combat_cancel_requested.connect(func() -> void:
		_tl_panel.call("cancel_targeting")
	)
	_tl_panel.targeting_state_changed.connect(func(tk: String, vids: Array, aid: String) -> void:
		_iso_view.call("set_combat_targeting", tk, vids, aid)
	)
	_tl_panel.frise_actor_hovered.connect(func(k: String, eid: String) -> void:
		_iso_view.call("set_combat_external_hover", k, eid)
	)

	_world_map_view.zoom_in_requested.connect(func(target_level: int, target_id: String) -> void:
		GameState.set_zoom_view(target_level, target_id)
	)
	_world_map_view.zoom_out_requested.connect(_zoom_out_one_level)
	_world_map_view.interior_travel_requested.connect(func(lid: String) -> void:
		_squad.call("move_active_group", lid)
		GameState.set_zoom_view(4, lid)
	)
	_world_map_view.undescribed_clicked.connect(func(nname: String, _lore: String) -> void:
		GameState.add_log("%s : zone non ouverte dans ce scénario." % nname)
	)

	_hud.squad_regroup_requested.connect(func() -> void: _squad.call("regroup_all"))
	_hud.squad_split_2_1_requested.connect(func() -> void: _squad.call("split_2_1"))
	_hud.squad_split_1_1_1_requested.connect(func() -> void: _squad.call("split_1_1_1"))
	_hud.group_switch_requested.connect(func(gid: int) -> void: _squad.call("switch_to_group", gid))
	_hud.group_order_cycle_requested.connect(func(gid: int) -> void: _squad.call("cycle_group_order", gid))
	_hud.location_travel_requested.connect(func(lid: String) -> void:
		_squad.call("move_active_group", lid)
		GameState.set_zoom_view(4, lid)
	)
	_hud.zoom_level_requested.connect(func(lvl: int) -> void:
		if lvl == 3 and GameState.current_zoom_level == 3:
			GameState.set_zoom_view(4, GameState.get_active_location_id())
		else:
			GameState.set_zoom_view(lvl)
	)
	_hud.zoom_out_requested.connect(_zoom_out_one_level)
	_hud.twilight_requested.connect(_start_twilight_sas)
	_hud.restart_slice_requested.connect(_restart_slice)
	_hud.menu_requested.connect(_open_pause_menu)
	_hud.character_sheet_requested.connect(func() -> void: _toggle_character_sheet())
	_char_sheet_panel.closed.connect(_update_input_lock)

	_dlg_panel.choice_selected.connect(func(idx: int) -> void: _dialogue_runner.call("pick_choice", idx))
	_dialogue_runner.node_updated.connect(func(_id: String, node_data: Dictionary, choices: Array) -> void:
		_dlg_panel.call("show_node", node_data, choices)
	)
	_dialogue_runner.dialogue_finished.connect(func() -> void: _dlg_panel.call("hide_panel"))
	_dialogue_runner.move_requested.connect(func(lid: String) -> void:
		_squad.call("move_active_group", lid)
		GameState.set_zoom_view(4, lid)
	)
	_dialogue_runner.twilight_requested.connect(_start_twilight_sas)
	_dialogue_runner.encounter_requested.connect(func(eid: String) -> void:
		_last_encounter_id = eid
		var enc_def: Dictionary = DataLoader.get_encounter(eid)
		var enc_loc: String = str(enc_def.get("location_id", GameState.get_active_location_id()))
		GameState.set_zoom_view(4, enc_loc)
		if str(_iso_view.get("current_loc_id")) != enc_loc:
			_iso_view.call("set_location", enc_loc)
		_char_sheet_panel.visible = false
		_hud.visible = false
		_timeline.call("start_encounter", eid)
		_iso_view.call("set_combat_stage_mode", true)
		_update_input_lock()
	)
	if _dialogue_runner.has_signal("ending_requested"):
		_dialogue_runner.ending_requested.connect(_show_end_summary)
	else:
		_dialogue_runner.slice_completed.connect(func() -> void: _show_end_summary(""))

	_timeline.train_fantome_arrived_sig.connect(func() -> void: _iso_view.call("trigger_train_fantome"))
	if _timeline.has_signal("stage_fx_triggered"):
		_timeline.stage_fx_triggered.connect(func(fx_id: String) -> void:
			_iso_view.call("trigger_stage_fx", fx_id)
		)
	_timeline.combat_feedback_emitted.connect(_on_combat_feedback_emitted)
	_timeline.encounter_finished.connect(_on_encounter_finished)

	# Signaux des écrans Menus
	_title_menu.resume_requested.connect(_close_pause_menu)
	_title_menu.new_game_requested.connect(_open_new_game_setup)
	_title_menu.load_game_requested.connect(func() -> void: _save_load_panel.call("open_panel", "load"))
	_title_menu.save_game_requested.connect(func() -> void: _save_load_panel.call("open_panel", "save"))
	_title_menu.options_requested.connect(func() -> void: _options_panel.call("open_panel"))
	_title_menu.return_title_requested.connect(_enter_title_menu)
	_title_menu.quit_requested.connect(func() -> void: get_tree().quit())

	_new_game_panel.start_game_requested.connect(_start_new_game)
	_new_game_panel.cancelled.connect(_on_new_game_cancelled)
	if _new_game_panel.has_signal("scenario_preview_changed"):
		_new_game_panel.scenario_preview_changed.connect(_on_scenario_preview_changed)

	_save_load_panel.slot_saved.connect(func(_idx: int) -> void: _title_menu.call("refresh_state"))
	_save_load_panel.slot_loaded.connect(_on_slot_loaded)
	_save_load_panel.closed.connect(func() -> void: _title_menu.call("refresh_state"))

	_options_panel.closed.connect(func() -> void: _title_menu.call("refresh_state"))

	GameState.active_group_changed.connect(_on_active_group_changed)
	GameState.zoom_changed.connect(func(_lvl: int, _mid: String) -> void: _sync_active_view())
	GameState.state_changed.connect(_on_state_changed)

func _get_title_backdrop_config() -> Dictionary:
	var tb_v: Variant = DataLoader.scenario_manifest.get("title_backdrop", {})
	if tb_v is Dictionary:
		return tb_v as Dictionary
	return {}

func _get_title_backdrop_location() -> String:
	var tb: Dictionary = _get_title_backdrop_config()
	var lid: String = str(tb.get("location_id", ""))
	if lid != "" and DataLoader.locations.has(lid):
		return lid
	return DataLoader.get_start_location_id()

func _on_scenario_preview_changed(_scenario_id: String) -> void:
	if _app_state == AppState.TITLE_MENU or _app_state == AppState.NEW_GAME_SETUP:
		GameState.reset_new_slice({"scenario_id": DataLoader.active_scenario_id})
		GameState.has_active_session = false
		_iso_view.call("set_location", _get_title_backdrop_location())
		_title_menu.call("refresh_state")

func _apply_shader_settings() -> void:
	if _shader_mat == null:
		return
	_shader_mat.set_shader_parameter("grain_strength", SettingsManager.get_grain_strength())
	if not SettingsManager.screen_shake:
		_shader_mat.set_shader_parameter("shake_amount", 0.0)

## Bascule l'application sur l'écran d'accueil avec le décor vivant défini par le scénario actif.
func _enter_title_menu() -> void:
	_app_state = AppState.TITLE_MENU
	_sas_active = false
	_sas_overlay.visible = false
	_end_overlay.visible = false
	_timeline.set("active", false)
	_tl_panel.visible = false
	_char_sheet_panel.visible = false
	_dialogue_runner.call("close_dialogue")
	_dlg_panel.visible = false
	_combat_shake_timer = 0.0
	_iso_view.set("train_fantome_active", false)

	GameState.has_active_session = false
	GameState.reset_new_slice({})

	_hud.visible = false
	_world_map_view.call("set_view_active", false)
	_iso_view.call("set_view_active", true)
	_iso_view.call("set_location", _get_title_backdrop_location())
	_iso_view.call("set_combat_stage_mode", false)
	_iso_view.call("set_title_backdrop_mode", true, Vector2.ZERO)

	AudioRadio.title_mode = true
	_title_cycle_time = 0.0
	_shader_mat.set_shader_parameter("night_amount", 0.0)
	_shader_mat.set_shader_parameter("low_moral_amount", 0.0)
	_shader_mat.set_shader_parameter("shake_amount", 0.0)

	_new_game_panel.call("close_panel")
	_save_load_panel.call("close_panel")
	_options_panel.call("close_panel")
	_title_menu.call("open_menu", "title")
	_update_input_lock()

## Ouvre le Menu Pause par-dessus la partie active et bloque les entrées du monde.
func _open_pause_menu() -> void:
	if _app_state != AppState.IN_GAME or _sas_active:
		return
	_app_state = AppState.PAUSE_MENU
	_title_menu.call("open_menu", "pause")
	_update_input_lock()

## Referme le Menu Pause et ses modales enfants pour rendre la main au jeu.
func _close_pause_menu() -> void:
	if _app_state != AppState.PAUSE_MENU:
		return
	_save_load_panel.call("close_panel")
	_options_panel.call("close_panel")
	_title_menu.call("close_menu")
	_app_state = AppState.IN_GAME
	_update_input_lock()

func _open_new_game_setup() -> void:
	_new_game_caller = AppState.PAUSE_MENU if (_app_state == AppState.PAUSE_MENU and GameState.has_active_session) else AppState.TITLE_MENU
	_app_state = AppState.NEW_GAME_SETUP
	_title_menu.call("close_menu")
	_save_load_panel.call("close_panel")
	_options_panel.call("close_panel")
	_new_game_panel.call("open_panel")
	_update_input_lock()

func _on_new_game_cancelled() -> void:
	_new_game_panel.call("close_panel")
	if _new_game_caller == AppState.PAUSE_MENU and GameState.has_active_session:
		DataLoader.ensure_scenario_loaded(GameState.current_scenario_id)
		_app_state = AppState.PAUSE_MENU
		_title_menu.call("open_menu", "pause")
	else:
		_app_state = AppState.TITLE_MENU
		_title_menu.call("open_menu", "title")
	_update_input_lock()

## Démarre une nouvelle session selon le manifeste du scénario sélectionné (neuf ou cassette importée).
func _start_new_game(profile: Dictionary) -> void:
	_title_menu.call("close_menu")
	_new_game_panel.call("close_panel")
	_save_load_panel.call("close_panel")
	_options_panel.call("close_panel")
	_sas_active = false
	_sas_overlay.visible = false
	_end_overlay.visible = false
	_timeline.set("active", false)
	_tl_panel.visible = false
	_char_sheet_panel.visible = false
	_dlg_panel.visible = false
	_combat_shake_timer = 0.0
	_iso_view.set("train_fantome_active", false)

	_iso_view.call("set_combat_stage_mode", false)
	_iso_view.call("set_title_backdrop_mode", false, Vector2.ZERO)
	AudioRadio.title_mode = false

	GameState.reset_new_slice(profile)
	GameState.has_active_session = true
	_app_state = AppState.IN_GAME
	_hud.visible = true

	var start_loc: String = GameState.get_active_location_id()
	_iso_view.call("set_location", start_loc)
	_sync_active_view()
	_on_state_changed()
	_apply_shader_settings()
	_hud.call("refresh")

	var intro_dlg: String = str(DataLoader.scenario_manifest.get("intro_dialogue_id", ""))
	if intro_dlg != "":
		_dialogue_runner.call("start_dialogue", intro_dlg)
	_update_input_lock()

## Restaure les vues, le HUD et le post-process après le chargement d'une cassette manuelle.
func _on_slot_loaded(slot_idx: int) -> void:
	_title_menu.call("close_menu")
	_new_game_panel.call("close_panel")
	_save_load_panel.call("close_panel")
	_options_panel.call("close_panel")
	_sas_active = false
	_sas_overlay.visible = false
	_end_overlay.visible = false
	_timeline.set("active", false)
	_tl_panel.visible = false
	_char_sheet_panel.visible = false
	_dialogue_runner.call("close_dialogue")
	_dlg_panel.visible = false
	_combat_shake_timer = 0.0
	_iso_view.set("train_fantome_active", false)

	_iso_view.call("set_combat_stage_mode", false)
	_iso_view.call("set_title_backdrop_mode", false, Vector2.ZERO)
	AudioRadio.title_mode = false
	_app_state = AppState.IN_GAME
	_hud.visible = true

	_sync_world_location()
	_sync_active_view()
	_on_state_changed()
	_apply_shader_settings()
	_hud.call("refresh")
	GameState.add_log("%s chargée — reprise à %s." % [SaveManager.get_slot_label(slot_idx), GameState.format_clock()])
	_update_input_lock()

func _process(delta: float) -> void:
	if _app_state == AppState.TITLE_MENU or _app_state == AppState.NEW_GAME_SETUP:
		_title_cycle_time += delta
		var u: float = fmod(_title_cycle_time, 28.0) / 28.0
		var raw_mix: float = clampf(0.5 - 0.5 * cos(u * TAU), 0.0, 1.0)
		var night_mix: float = pow(raw_mix, 1.25)
		var drift: Vector2 = Vector2(sin(_title_cycle_time * 0.25) * 16.0, cos(_title_cycle_time * 0.18) * 9.0)
		_iso_view.call("set_title_backdrop_mode", true, drift)
		_shader_mat.set_shader_parameter("night_amount", night_mix)
		_shader_mat.set_shader_parameter("shake_amount", 0.0)
		if _app_state == AppState.TITLE_MENU:
			var tb: Dictionary = _get_title_backdrop_config()
			var phase_txt: String = str(tb.get("day_label", "Jour"))
			if night_mix >= 0.72:
				phase_txt = str(tb.get("night_label", "Nuit"))
			elif night_mix >= 0.25:
				phase_txt = str(tb.get("twilight_label", "Crépuscule"))
			_title_menu.call("set_ambient_phase_label", phase_txt)
		_update_input_lock()
		return

	if _sas_active:
		_sas_timer += delta
		var prog: float = clampf(_sas_timer / 2.6, 0.0, 1.0)
		_shader_mat.set_shader_parameter("night_amount", prog)
		var shake_val: float = (sin(prog * PI) * 0.0045) if SettingsManager.screen_shake else 0.0
		_shader_mat.set_shader_parameter("shake_amount", shake_val)
		if _sas_timer >= 2.6:
			_sas_active = false
			_sas_overlay.visible = false
			_shader_mat.set_shader_parameter("shake_amount", 0.0)
			GameState.set_phase("night")
			var pt_v: Variant = DataLoader.scenario_manifest.get("phase_transitions", {})
			var night_log: String = "La nuit est tombée."
			if pt_v is Dictionary:
				night_log = str((pt_v as Dictionary).get("night_arrival_log", night_log))
			GameState.add_log(night_log)
			_iso_view.queue_redraw()
	elif _shader_mat != null:
		if _combat_shake_timer > 0.0 and SettingsManager.screen_shake:
			_combat_shake_timer = maxf(0.0, _combat_shake_timer - delta)
			_shader_mat.set_shader_parameter("shake_amount", (_combat_shake_timer / 0.22) * 0.0055)
		else:
			_combat_shake_timer = 0.0
			_shader_mat.set_shader_parameter("shake_amount", 0.0)

	_update_input_lock()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo and kev.keycode == KEY_ESCAPE:
			if _save_load_panel.visible:
				if bool(_save_load_panel.call("has_confirm_open")):
					_save_load_panel.call("close_confirm")
				else:
					_save_load_panel.call("close_panel")
					_title_menu.call("refresh_state")
				get_viewport().set_input_as_handled()
				return
			if _options_panel.visible:
				_options_panel.call("close_panel")
				_title_menu.call("refresh_state")
				get_viewport().set_input_as_handled()
				return
			if _new_game_panel.visible:
				_on_new_game_cancelled()
				get_viewport().set_input_as_handled()
				return
			if _char_sheet_panel.visible:
				_char_sheet_panel.call("close_panel")
				get_viewport().set_input_as_handled()
				return
			if _tl_panel.visible and bool(_tl_panel.call("has_pending_targeting")):
				_tl_panel.call("cancel_targeting")
				get_viewport().set_input_as_handled()
				return
			if _app_state == AppState.PAUSE_MENU:
				if bool(_title_menu.call("has_confirm_open")):
					_title_menu.call("close_confirm")
				else:
					_close_pause_menu()
				get_viewport().set_input_as_handled()
				return
			if _app_state == AppState.IN_GAME and not _sas_active:
				_open_pause_menu()
				get_viewport().set_input_as_handled()
				return

	if _app_state != AppState.IN_GAME or _sas_active or _end_overlay.visible or _tl_panel.visible or _dlg_panel.visible or _new_game_panel.visible or _save_load_panel.visible or _options_panel.visible:
		return

	if event is InputEventKey:
		var kev_f: InputEventKey = event as InputEventKey
		if kev_f.pressed and not kev_f.echo and kev_f.keycode == KEY_F:
			_toggle_character_sheet()
			get_viewport().set_input_as_handled()
			return

	if _char_sheet_panel.visible:
		return

	if event is InputEventKey:
		var kev2: InputEventKey = event as InputEventKey
		if kev2.pressed and not kev2.echo:
			if kev2.keycode == KEY_1:
				_squad.call("switch_to_group", 0)
			elif kev2.keycode == KEY_2:
				_squad.call("switch_to_group", 1)
			elif kev2.keycode == KEY_3:
				_squad.call("switch_to_group", 2)
			elif kev2.keycode == KEY_4:
				_squad.call("switch_to_group", 3)
			elif kev2.keycode == KEY_5:
				_squad.call("switch_to_group", 4)
			elif kev2.keycode == KEY_6:
				_squad.call("switch_to_group", 5)
			elif kev2.keycode == KEY_BACKSPACE:
				_zoom_out_one_level()
			elif kev2.keycode == KEY_M:
				if GameState.current_zoom_level == 4:
					GameState.set_zoom_view(3, GameState.current_city_id)
				else:
					GameState.set_zoom_view(4, GameState.get_active_location_id())

func _zoom_out_one_level() -> void:
	if GameState.current_zoom_level > 1:
		GameState.set_zoom_view(GameState.current_zoom_level - 1)

func _sync_active_view() -> void:
	if _app_state == AppState.TITLE_MENU or _app_state == AppState.NEW_GAME_SETUP:
		_world_map_view.call("set_view_active", false)
		_iso_view.call("set_view_active", true)
		_iso_view.call("set_location", _get_title_backdrop_location())
		return
	var zl: int = GameState.current_zoom_level
	if zl == 4:
		_world_map_view.call("set_view_active", false)
		_iso_view.call("set_view_active", true)
		_sync_world_location()
	else:
		_iso_view.call("set_view_active", false)
		var map_id: String = GameState.current_region_id
		if zl == 2:
			map_id = GameState.current_department_id
		elif zl == 3:
			map_id = GameState.current_city_id
		_world_map_view.call("set_zoom_view", zl, map_id)
		_world_map_view.call("set_view_active", true)

func _on_active_group_changed(_gid: int) -> void:
	if _app_state == AppState.TITLE_MENU or _app_state == AppState.NEW_GAME_SETUP:
		return
	_sync_world_location()
	_iso_view.call("sync_active_group_from_state")

func _on_state_changed() -> void:
	if _app_state == AppState.TITLE_MENU or _app_state == AppState.NEW_GAME_SETUP:
		return
	_sync_world_location()
	if GameState.current_zoom_level < 4:
		_world_map_view.queue_redraw()
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
	var pt_v: Variant = DataLoader.scenario_manifest.get("phase_transitions", {})
	if pt_v is Dictionary:
		_sas_label.text = str((pt_v as Dictionary).get("sas_overlay_text", "CRÉPUSCULE"))
	_sas_active = true
	_sas_timer = 0.0
	_sas_overlay.visible = true
	GameState.set_phase("twilight")
	AudioRadio.play_boeing_roar()

func _on_combat_feedback_emitted(event_data: Dictionary) -> void:
	if bool(event_data.get("shake", false)) and SettingsManager.screen_shake:
		_combat_shake_timer = 0.22

## Routage post-confrontation 100 % piloté par le bloc outcomes de la rencontre JSON.
func _on_encounter_finished(outcome_id: String, _summary: String) -> void:
	_combat_shake_timer = 0.0
	_iso_view.call("set_combat_stage_mode", false)
	_hud.visible = (_app_state == AppState.IN_GAME)

	var enc_id: String = str(_timeline.get("encounter_id"))
	if enc_id == "":
		enc_id = _last_encounter_id
	var enc_def: Dictionary = DataLoader.get_encounter(enc_id)
	var outcomes_v: Variant = enc_def.get("outcomes", {})
	var out_cfg: Dictionary = {}
	if outcomes_v is Dictionary:
		var od: Dictionary = outcomes_v as Dictionary
		var specific_v: Variant = od.get(outcome_id, od.get("default", {}))
		if specific_v is Dictionary:
			out_cfg = specific_v as Dictionary

	if bool(out_cfg.get("regroup_squad", true)):
		_squad.call("regroup_all")
	var next_loc: String = str(out_cfg.get("move_to", ""))
	if next_loc != "":
		_squad.call("move_active_group", next_loc)
	_sync_world_location()

	var end_id: String = str(out_cfg.get("trigger_ending", ""))
	var next_dlg: String = str(out_cfg.get("next_dialogue", ""))
	if end_id != "":
		_show_end_summary(end_id)
	elif next_dlg != "":
		_dialogue_runner.call("start_dialogue", next_dlg)
	_update_input_lock()

## Construit dynamiquement l'écran de fin à partir du bloc endings de scenario.json.
func _show_end_summary(_ending_id: String = "") -> void:
	GameState.scenario_completed = true
	var end_v: Variant = DataLoader.scenario_manifest.get("endings", {})
	var end_cfg: Dictionary = end_v as Dictionary if end_v is Dictionary else {}
	var scen_title: String = str(DataLoader.scenario_manifest.get("title", "Scénario"))
	_end_title_lbl.text = str(end_cfg.get("banner_title", "SCÉNARIO TERMINÉ — « %s »" % scen_title))
	_btn_end_replay.text = str(end_cfg.get("replay_button_label", "Rejouer le Scénario"))

	var out_labels_v: Variant = end_cfg.get("outcome_labels", {})
	var out_labels: Dictionary = out_labels_v as Dictionary if out_labels_v is Dictionary else {}
	var outcome_key: String = GameState.last_encounter_outcome
	var outcome_label: String = str(out_labels.get(outcome_key, str(out_labels.get("default", outcome_key if outcome_key != "" else "Résolu"))))

	var extra_lines: Array[String] = []
	var notes_v: Variant = end_cfg.get("status_notes", [])
	if notes_v is Array:
		for nv in (notes_v as Array):
			if not (nv is Dictionary):
				continue
			var nd: Dictionary = nv as Dictionary
			var n_lbl: String = str(nd.get("label", ""))
			if nd.has("if_flag"):
				var fl: String = str(nd.get("if_flag", ""))
				var val_txt: String = str(nd.get("true_text", "Oui")) if GameState.has_flag(fl) else str(nd.get("false_text", "Non"))
				extra_lines.append("%s : %s" % [n_lbl, val_txt])
			elif nd.has("join_present_squad") and nd.get("join_present_squad") is Array:
				var joined: Array[String] = []
				for jv in (nd.get("join_present_squad") as Array):
					if jv is Dictionary:
						var jd: Dictionary = jv as Dictionary
						var jcid: String = str(jd.get("char_id", ""))
						var jfl: String = str(jd.get("flag", ""))
						if (jfl != "" and GameState.has_flag(jfl)) or (jcid != "" and GameState.squad_members.has(jcid)):
							joined.append(str(jd.get("text", jcid)))
				if not joined.is_empty():
					extra_lines.append("%s : %s" % [n_lbl, ", ".join(joined)])

	var moral_lines: Array[String] = []
	for cid in GameState.squad_members:
		var cdef: Dictionary = DataLoader.get_character(cid)
		var st: Dictionary = GameState.get_member_state(cid)
		moral_lines.append("• %s : %d / %d Moral" % [str(cdef.get("name", cid)), int(st.get("moral", 0)), int(st.get("moral_max", 100))])

	var notes_block: String = ("\n".join(extra_lines) + "\n\n") if not extra_lines.is_empty() else "\n"
	var footer_txt: String = str(end_cfg.get("footer_text", ""))
	var footer_block: String = ("\n\n" + footer_txt) if footer_txt != "" else ""

	_end_summary_lbl.text = (
		"Issue principale : %s\n%s" +
		"Ressources finales : %d Francs  |  %d Faveurs  |  Notoriété %d  |  Aura %d\n\n" +
		"État de la bande (%d membres) :\n%s%s"
	) % [
		outcome_label,
		notes_block,
		GameState.francs,
		GameState.faveurs,
		GameState.notoriete,
		GameState.get_total_aura(),
		GameState.squad_members.size(),
		"\n".join(moral_lines),
		footer_block
	]
	_end_overlay.visible = true

func _restart_slice() -> void:
	var kept_profile: Dictionary = GameState.leader_profile.duplicate(true)
	kept_profile["scenario_id"] = GameState.current_scenario_id
	_start_new_game(kept_profile)

func _toggle_character_sheet(char_id: String = "") -> void:
	if _app_state != AppState.IN_GAME or _sas_active or _end_overlay.visible or _tl_panel.visible or _dlg_panel.visible:
		return
	if _char_sheet_panel.visible:
		_char_sheet_panel.call("close_panel")
	else:
		_char_sheet_panel.call("open_panel", char_id)
	AudioRadio.play_cassette_click()
	_update_input_lock()

func _update_input_lock() -> void:
	var menu_open: bool = (_app_state != AppState.IN_GAME) or _new_game_panel.visible or _save_load_panel.visible or _options_panel.visible
	var blocked: bool = menu_open or _sas_active or _end_overlay.visible or _tl_panel.visible or _dlg_panel.visible or _char_sheet_panel.visible
	_iso_view.set("input_blocked", blocked)
	_iso_view.set("combat_input_blocked", menu_open or _sas_active or _end_overlay.visible)
	_world_map_view.set("input_blocked", blocked)
	_tl_panel.set("input_blocked", menu_open or _sas_active or _end_overlay.visible)
	_timeline.set("charge_timer_paused", menu_open or _sas_active or _end_overlay.visible)
