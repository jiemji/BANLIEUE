extends Node

var _player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _muted: bool = false

var _mix_rate: float = 22050.0
var _phase_wave: float = 0.0
var _phase_bass: float = 0.0
var _sfx_timer: float = 0.0
var _sfx_kind: String = ""
var _sfx_freq: float = 440.0
var _noise_seed: int = 19820417

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = _mix_rate
	gen.buffer_length = 0.25
	_player.stream = gen
	_player.volume_db = -12.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback

func is_muted() -> bool:
	return _muted

func toggle_mute() -> bool:
	_muted = not _muted
	if _player != null:
		_player.volume_db = -80.0 if _muted else -12.0
	return _muted

func play_cassette_click() -> void:
	_sfx_kind = "click"
	_sfx_timer = 0.06
	_sfx_freq = 640.0

func play_interrupt_hit() -> void:
	_sfx_kind = "hit"
	_sfx_timer = 0.14
	_sfx_freq = 280.0

func play_crisis_buzz() -> void:
	_sfx_kind = "buzz"
	_sfx_timer = 0.35
	_sfx_freq = 110.0

func play_boeing_roar() -> void:
	_sfx_kind = "boeing"
	_sfx_timer = 2.6
	_sfx_freq = 72.0

func play_radio_zap() -> void:
	_sfx_kind = "zap"
	_sfx_timer = 0.20
	_sfx_freq = 320.0

func _process(_delta: float) -> void:
	if _playback == null or _muted:
		return
	var frames_avail: int = _playback.get_frames_available()
	if frames_avail <= 0:
		return
	var to_push: int = mini(frames_avail, 1024)
	var dt: float = 1.0 / _mix_rate
	var is_night: bool = GameState.phase == "night"
	var station_idx: int = GameState.current_station_idx
	var is_phantom_fm: bool = (station_idx == 4)

	for i in range(to_push):
		var sample: float = 0.0

		# Basse Cold Wave feutrée la nuit (impulsion post-punk 1982)
		if is_night:
			_phase_bass += 65.4 * dt
			if _phase_bass > 1.0:
				_phase_bass -= 1.0
			var pulse_env: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
			var saw: float = (_phase_bass * 2.0 - 1.0) * 0.035 * pulse_env
			sample += saw

		# Souffle doux si 104.7 FM sélectionnée
		if is_phantom_fm:
			sample += _next_noise() * (0.025 if is_night else 0.038)

		# Enveloppe SFX ponctuelle
		if _sfx_timer > 0.0:
			_sfx_timer -= dt
			_phase_wave += _sfx_freq * dt
			if _phase_wave > 1.0:
				_phase_wave -= 1.0
			if _sfx_kind == "click":
				sample += sin(_phase_wave * TAU) * 0.24 * clampf(_sfx_timer / 0.06, 0.0, 1.0)
			elif _sfx_kind == "hit":
				var env_h: float = clampf(_sfx_timer / 0.14, 0.0, 1.0)
				sample += (sin(_phase_wave * TAU) + _next_noise() * 0.35) * 0.26 * env_h
			elif _sfx_kind == "buzz":
				var sq: float = 1.0 if _phase_wave < 0.5 else -1.0
				sample += sq * 0.12 * clampf(_sfx_timer / 0.35, 0.0, 1.0)
			elif _sfx_kind == "boeing":
				var env_b: float = sin(clampf(_sfx_timer / 2.6, 0.0, 1.0) * PI)
				sample += (_next_noise() * 0.22 + sin(_phase_wave * TAU) * 0.14) * env_b
			elif _sfx_kind == "zap":
				sample += _next_noise() * 0.18 * clampf(_sfx_timer / 0.20, 0.0, 1.0)

		sample = clampf(sample, -0.65, 0.65)
		_playback.push_frame(Vector2(sample, sample))

func _next_noise() -> float:
	_noise_seed = (_noise_seed * 1103515245 + 12345) & 0x7fffffff
	return (float(_noise_seed) / float(0x7fffffff)) * 2.0 - 1.0
