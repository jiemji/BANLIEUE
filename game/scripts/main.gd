## Orchestrateur principal du jeu : machine d'états des écrans/menus, transitions N1–N4 et Sas Jour→Nuit.
extends Node

## États globaux de navigation entre l'accueil, la création de partie, la session active et le menu pause.
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
var _end_summary_lbl: Label = null

var _app_state: int = AppState.TITLE_MENU
var _new_game_caller: int = AppState.TITLE_MENU
var _sas_active: bool = false
var _sas_timer: float = 0.0
var _title_cycle_time: float = 0.0
var _combat_shake_timer: float = 0.0

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

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vb.add_child(btn_row)

	var btn_replay: Button = Button.new()
	btn_replay.text = "Rejouer le Niveau-Pilote"
	btn_replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_replay.pressed.connect(_restart_slice)
	btn_row.add_child(btn_replay)

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
		var t_id: String = str(ex.get("target_id", "cradon_les_gonesse"))
		GameState.set_zoom_view(t_lvl, t_id)
	)
	_iso_view.squad_member_clicked.connect(func(gid: int, _cid: String) -> void:
		_squad.call("switch_to_group", gid)
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
		GameState.add_log("%s : pas encore décrit dans ce Jalon." % nname)
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
		GameState.set_zoom_view(4, GameState.get_active_location_id())
		_char_sheet_panel.visible = false
		_hud.visible = false
		_iso_view.call("set_combat_stage_mode", true)
		_timeline.call("start_encounter", eid)
		_update_input_lock()
	)
	_dialogue_runner.slice_completed.connect(_show_end_summary)

	_timeline.train_fantome_arrived_sig.connect(func() -> void: _iso_view.call("trigger_train_fantome"))
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

	_save_load_panel.slot_saved.connect(func(_idx: int) -> void: _title_menu.call("refresh_state"))
	_save_load_panel.slot_loaded.connect(_on_slot_loaded)
	_save_load_panel.closed.connect(func() -> void: _title_menu.call("refresh_state"))

	_options_panel.closed.connect(func() -> void: _title_menu.call("refresh_state"))

	GameState.active_group_changed.connect(_on_active_group_changed)
	GameState.zoom_changed.connect(func(_lvl: int, _mid: String) -> void: _sync_active_view())
	GameState.state_changed.connect(_on_state_changed)

func _apply_shader_settings() -> void:
	if _shader_mat == null:
		return
	_shader_mat.set_shader_parameter("grain_strength", SettingsManager.get_grain_strength())
	if not SettingsManager.screen_shake:
		_shader_mat.set_shader_parameter("shake_amount", 0.0)

## Bascule l'application sur l'écran d'accueil avec le Box-Garage vivant en arrière-plan.
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
	_iso_view.call("set_location", "box_garage")
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
		_app_state = AppState.PAUSE_MENU
		_title_menu.call("open_menu", "pause")
	else:
		_app_state = AppState.TITLE_MENU
		_title_menu.call("open_menu", "title")
	_update_input_lock()

## Démarre une nouvelle session au Box-Garage à partir du profil Leader sélectionné.
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

	_iso_view.call("set_location", "box_garage")
	_sync_active_view()
	_apply_shader_settings()
	_dialogue_runner.call("start_dialogue", "intro_box_garage")
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
			var phase_txt: String = "Box-Garage · Jour gouache 1982"
			if night_mix >= 0.72:
				phase_txt = "Box-Garage · Nuit N&B (4 couleurs-signaux)"
			elif night_mix >= 0.25:
				phase_txt = "Box-Garage · Crépuscule sodium"
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
			GameState.add_log("22 h 10 — La nuit est tombée sur Cradon-lès-Gonesse. Cap sur la Gare RER « du Y » !")
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
		_iso_view.call("set_location", "box_garage")
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
	_sas_active = true
	_sas_timer = 0.0
	_sas_overlay.visible = true
	GameState.set_phase("twilight")
	AudioRadio.play_boeing_roar()

func _on_combat_feedback_emitted(event_data: Dictionary) -> void:
	if bool(event_data.get("shake", false)) and SettingsManager.screen_shake:
		_combat_shake_timer = 0.22

func _on_encounter_finished(_outcome_id: String, _summary: String) -> void:
	_combat_shake_timer = 0.0
	_iso_view.call("set_combat_stage_mode", false)
	_hud.visible = (_app_state == AppState.IN_GAME)
	_squad.call("regroup_all")
	_squad.call("move_active_group", "box_garage")
	_dialogue_runner.call("start_dialogue", "box_garage_debrief")
	_update_input_lock()

func _show_end_summary() -> void:
	var outcome_label: String = "Victoire sociale devant le S.O."
	if GameState.last_encounter_outcome == "escaped":
		outcome_label = "Échappée nocturne par le Quai / Train Fantôme"
	elif GameState.last_encounter_outcome == "crs_rush":
		outcome_label = "Repli d'urgence face aux sirènes CRS"

	var ludo_txt: String = "Recruté au Box-Garage !" if GameState.has_flag("ludo_recruited") else "Resté dehors pour ce soir (+1 Faveur)"
	var recruits_extra: Array[String] = []
	if GameState.has_flag("manu_recruited") or GameState.squad_members.has("manu"):
		recruits_extra.append("Manu (Bananes)")
	if GameState.has_flag("zoe_recruited") or GameState.squad_members.has("zoe"):
		recruits_extra.append("Zoé (Kepons)")
	var allies_extra_line: String = ("Renforts du Canal : " + ", ".join(recruits_extra) + "\n") if not recruits_extra.is_empty() else ""
	var moral_lines: Array[String] = []
	for cid in GameState.squad_members:
		var cdef: Dictionary = DataLoader.get_character(cid)
		var st: Dictionary = GameState.get_member_state(cid)
		moral_lines.append("• %s : %d / %d Moral" % [str(cdef.get("name", cid)), int(st.get("moral", 0)), int(st.get("moral_max", 100))])

	_end_summary_lbl.text = (
		"Issue à la Gare RER « du Y » : %s\n" +
		"Statut de Ludo : %s\n%s\n" +
		"Ressources finales : %d Francs  |  %d Faveurs  |  Notoriété %d  |  Aura %d\n\n" +
		"État de la bande (%d membres) :\n%s\n\n" +
		"Ce prototype Data-Driven valide la bascule libre (1–6), le Sas Boeing Jour→Nuit, " +
		"la Frise chronologique à Interruptions hors-tour et le préavis des Crises d'autonomie."
	) % [outcome_label, ludo_txt, allies_extra_line, GameState.francs, GameState.faveurs, GameState.notoriete, GameState.get_total_aura(), GameState.squad_members.size(), "\n".join(moral_lines)]
	_end_overlay.visible = true

func _restart_slice() -> void:
	var kept_profile: Dictionary = GameState.leader_profile.duplicate(true)
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
	_world_map_view.set("input_blocked", blocked)
	_tl_panel.set("input_blocked", menu_open or _sas_active or _end_overlay.visible)
