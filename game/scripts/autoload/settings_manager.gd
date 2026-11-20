## Gestionnaire global des réglages utilisateur persistés dans user://settings.cfg.
## Pilote le mode d'affichage, le volume audio/FM, le grain 16mm, les secousses et la taille des dialogues.
extends Node

signal settings_changed

const SETTINGS_PATH: String = "user://settings.cfg"

var fullscreen: bool = false
var master_volume: float = 0.80
var muted: bool = false
var radio_ambience: bool = true
var grain_level: String = "1982"
var screen_shake: bool = true
var dialogue_font_scale: String = "normal"

func _ready() -> void:
	load_settings()

## Charge les réglages depuis user://settings.cfg puis applique le mode d'affichage et émet settings_changed.
func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(SETTINGS_PATH)
	if err == OK:
		fullscreen = bool(cfg.get_value("display", "fullscreen", false))
		master_volume = clampf(float(cfg.get_value("audio", "master_volume", 0.80)), 0.0, 1.0)
		muted = bool(cfg.get_value("audio", "muted", false))
		radio_ambience = bool(cfg.get_value("audio", "radio_ambience", true))
		var gl: String = str(cfg.get_value("video", "grain_level", "1982"))
		grain_level = gl if (gl == "off" or gl == "light" or gl == "1982") else "1982"
		screen_shake = bool(cfg.get_value("video", "screen_shake", true))
		var dfs: String = str(cfg.get_value("ui", "dialogue_font_scale", "normal"))
		dialogue_font_scale = dfs if (dfs == "normal" or dfs == "large") else "normal"
	apply_display_setting()
	settings_changed.emit()

## Enregistre l'ensemble des préférences courantes dans user://settings.cfg.
func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "radio_ambience", radio_ambience)
	cfg.set_value("video", "grain_level", grain_level)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.set_value("ui", "dialogue_font_scale", dialogue_font_scale)
	cfg.save(SETTINGS_PATH)

## Restaure tous les paramètres par défaut, applique l'affichage et sauvegarde.
func reset_defaults() -> void:
	fullscreen = false
	master_volume = 0.80
	muted = false
	radio_ambience = true
	grain_level = "1982"
	screen_shake = true
	dialogue_font_scale = "normal"
	apply_display_setting()
	save_settings()
	settings_changed.emit()

## Applique le mode fenêtré ou plein écran (ignoré en exécution headless).
func apply_display_setting() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var target_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target_mode:
		DisplayServer.window_set_mode(target_mode)

## Retourne l'intensité numérique du grain pellicule pour film_1982_post.gdshader.
func get_grain_strength() -> float:
	if grain_level == "off":
		return 0.0
	if grain_level == "light":
		return 0.02
	return 0.042

## Retourne la taille de police (en pixels) utilisée par DialoguePanel.
func get_dialogue_font_size() -> int:
	return 17 if dialogue_font_scale == "large" else 14

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	apply_display_setting()
	save_settings()
	settings_changed.emit()

func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	save_settings()
	settings_changed.emit()

func set_muted(enabled: bool) -> void:
	muted = enabled
	save_settings()
	settings_changed.emit()

func set_radio_ambience(enabled: bool) -> void:
	radio_ambience = enabled
	save_settings()
	settings_changed.emit()

func set_grain_level(level: String) -> void:
	if level != "off" and level != "light" and level != "1982":
		return
	grain_level = level
	save_settings()
	settings_changed.emit()

func set_screen_shake(enabled: bool) -> void:
	screen_shake = enabled
	save_settings()
	settings_changed.emit()

func set_dialogue_font_scale(scale_mode: String) -> void:
	if scale_mode != "normal" and scale_mode != "large":
		return
	dialogue_font_scale = scale_mode
	save_settings()
	settings_changed.emit()
