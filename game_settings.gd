extends Node

var player1_character: String = "KAAL"
var player2_character: String = "NEX"
var winner_character: String = "KAAL"
var player1_round_wins: int = 0
var player2_round_wins: int = 0
var vs_ai: bool = true
var ai_difficulty: float = 0.85

var bgm_player: AudioStreamPlayer = null
var current_bgm_track: String = ""

const MENU_MUSIC_PATHS: Array[String] = [
	"res://assets/audio/menu_theme.ogg",
	"res://assets/audio/menu_theme.mp3",
	"res://assets/audio/menu_theme.wav",
	"res://assets/audio/menu.ogg",
	"res://assets/audio/menu.mp3",
]

const BATTLE_MUSIC_PATHS: Array[String] = [
	"res://assets/audio/battle_theme.ogg",
	"res://assets/audio/battle_theme.mp3",
	"res://assets/audio/battle_theme.wav",
	"res://assets/audio/battle.ogg",
	"res://assets/audio/battle.mp3",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_input_mappings()
	_setup_audio()
	play_menu_music()


func _setup_audio() -> void:
	if bgm_player == null:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.name = "BgmPlayer"
		bgm_player.bus = "Master"
		bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(bgm_player)


func play_menu_music() -> void:
	_play_track("menu", MENU_MUSIC_PATHS, true)


func play_battle_music() -> void:
	_play_track("battle", BATTLE_MUSIC_PATHS, false)


func stop_music() -> void:
	if bgm_player != null and bgm_player.playing:
		bgm_player.stop()
		current_bgm_track = ""


func set_music_volume(volume_db: float) -> void:
	if bgm_player != null:
		bgm_player.volume_db = volume_db


func _play_track(track_name: String, path_candidates: Array[String], is_menu: bool) -> void:
	_setup_audio()
	if current_bgm_track == track_name and bgm_player.playing:
		return
	
	current_bgm_track = track_name
	
	# Check if user placed an audio file in assets/audio/
	var found_stream: AudioStream = null
	for path in path_candidates:
		if ResourceLoader.exists(path):
			found_stream = load(path)
			if found_stream != null:
				if found_stream is AudioStreamOggVorbis:
					found_stream.loop = true
				elif found_stream is AudioStreamMP3:
					found_stream.loop = true
				break
	
	if found_stream != null:
		_crossfade_to_stream(found_stream, -6.0)
	else:
		# Procedural cyber/mystic combat loop fallback
		var synth_stream := _generate_procedural_bgm(is_menu)
		_crossfade_to_stream(synth_stream, -10.0)


func _crossfade_to_stream(new_stream: AudioStream, target_volume_db: float = -6.0) -> void:
	if bgm_player.playing:
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(bgm_player, "volume_db", -40.0, 0.35)
		tw.tween_callback(func():
			bgm_player.stream = new_stream
			bgm_player.play()
			var tw_in := create_tween()
			tw_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw_in.tween_property(bgm_player, "volume_db", target_volume_db, 0.5)
		)
	else:
		bgm_player.stream = new_stream
		bgm_player.volume_db = target_volume_db
		bgm_player.play()


func _generate_procedural_bgm(is_menu: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var mix_rate := 22050
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	var duration: float = 4.8 if is_menu else 3.55
	var total_samples := int(mix_rate * duration)
	stream.loop_end = total_samples
	
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	
	var base_freq: float = 55.0 if is_menu else 65.4
	var tempo_freq: float = 1.0 / (duration / 8.0)
	
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var beat_phase := fposmod(t * tempo_freq, 1.0)
		
		var note_offset := 0.0
		var beat_idx := int(t * tempo_freq) % 8
		if not is_menu:
			var scale_notes = [0.0, 3.0, 5.0, 7.0, 10.0, 7.0, 5.0, 3.0]
			note_offset = scale_notes[beat_idx]
		else:
			var ambient_notes = [0.0, 0.0, 7.0, 7.0, 5.0, 5.0, 3.0, 2.0]
			note_offset = ambient_notes[beat_idx]
		
		var freq: float = base_freq * pow(2.0, note_offset / 12.0)
		var bass := (sin(t * freq * TAU) + 0.3 * sin(t * freq * 2.0 * TAU)) * exp(-beat_phase * 2.5)
		
		var kick_env := exp(-beat_phase * 16.0)
		var kick := sin(beat_phase * 60.0 * TAU) * kick_env * (0.4 if not is_menu else 0.2)
		
		var sub_beat := fposmod(t * tempo_freq * 2.0, 1.0)
		var hat_env := exp(-sub_beat * 32.0)
		var noise := (sin(t * 4321.0) + sin(t * 8765.0)) * 0.5 * hat_env * 0.12
		
		var pad_freq := base_freq * 4.0
		var pad := (sin(t * pad_freq * TAU) * 0.08 + sin(t * pad_freq * 1.5 * TAU) * 0.06)
		
		var sample_val: float = clampf(bass * 0.35 + kick + noise + pad, -1.0, 1.0)
		var sample_int := int(sample_val * 28000.0)
		bytes.encode_s16(i * 2, sample_int)
		
	stream.data = bytes
	return stream



func ensure_input_mappings() -> void:
	# Define all default bindings with alternatives (IJKL, Numpad, and Gamepads)
	# to prevent keyboard matrix ghosting / lockout on shared local keyboards.
	var mappings := {
		"p1_left": [
			_key(KEY_A),
			_pad_button(JOY_BUTTON_DPAD_LEFT, 0),
			_pad_axis(JOY_AXIS_LEFT_X, -1.0, 0),
		],
		"p1_right": [
			_key(KEY_D),
			_pad_button(JOY_BUTTON_DPAD_RIGHT, 0),
			_pad_axis(JOY_AXIS_LEFT_X, 1.0, 0),
		],
		"p1_jump": [
			_key(KEY_W),
			_pad_button(JOY_BUTTON_DPAD_UP, 0),
			_pad_button(JOY_BUTTON_A, 0),
		],
		"p1_block": [
			_key(KEY_S),
			_pad_button(JOY_BUTTON_DPAD_DOWN, 0),
			_pad_button(JOY_BUTTON_B, 0),
		],
		"p1_light": [
			_key(KEY_F),
			_pad_button(JOY_BUTTON_X, 0),
		],
		"p1_heavy": [
			_key(KEY_G),
			_pad_button(JOY_BUTTON_Y, 0),
		],
		"p1_special": [
			_key(KEY_Q),
			_pad_button(JOY_BUTTON_LEFT_SHOULDER, 0),
		],
		"p1_ultimate": [
			_key(KEY_E),
			_pad_button(JOY_BUTTON_RIGHT_SHOULDER, 0),
		],

		# Player 2: Arrow keys + IJKL cluster (bypasses arrow matrix ghosting) + Numpad + Joypad
		"p2_left": [
			_key(KEY_LEFT),
			_key(KEY_KP_4),
			_pad_button(JOY_BUTTON_DPAD_LEFT, 1),
			_pad_axis(JOY_AXIS_LEFT_X, -1.0, 1),
		],
		"p2_right": [
			_key(KEY_RIGHT),
			_key(KEY_KP_6),
			_pad_button(JOY_BUTTON_DPAD_RIGHT, 1),
			_pad_axis(JOY_AXIS_LEFT_X, 1.0, 1),
		],
		"p2_jump": [
			_key(KEY_UP),
			_key(KEY_KP_8),
			_pad_button(JOY_BUTTON_DPAD_UP, 1),
			_pad_button(JOY_BUTTON_A, 1),
		],
		"p2_block": [
			_key(KEY_DOWN),
			_key(KEY_KP_2),
			_pad_button(JOY_BUTTON_DPAD_DOWN, 1),
			_pad_button(JOY_BUTTON_B, 1),
		],
		"p2_light": [
			_key(KEY_SLASH),
			_key(KEY_KP_1),
			_pad_button(JOY_BUTTON_X, 1),
		],
		"p2_heavy": [
			_key(KEY_PERIOD),
			_key(KEY_KP_3),
			_pad_button(JOY_BUTTON_Y, 1),
		],
		"p2_special": [
			_key(KEY_SHIFT, KEY_LOCATION_RIGHT),
			_key(KEY_KP_7),
			_pad_button(JOY_BUTTON_LEFT_SHOULDER, 1),
		],
		"p2_ultimate": [
			_key(KEY_ENTER),
			_key(KEY_KP_ENTER),
			_key(KEY_KP_9),
			_pad_button(JOY_BUTTON_RIGHT_SHOULDER, 1),
		],
	}

	for action_name in mappings:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.2)
		var existing_events = InputMap.action_get_events(action_name)
		for new_ev: InputEvent in mappings[action_name]:
			var already_bound := false
			for ex_ev in existing_events:
				if new_ev is InputEventKey and ex_ev is InputEventKey:
					if (ex_ev.physical_keycode == new_ev.physical_keycode or (ex_ev.keycode != 0 and ex_ev.keycode == new_ev.physical_keycode)) and ex_ev.location == new_ev.location:
						already_bound = true
						break
				elif new_ev is InputEventJoypadButton and ex_ev is InputEventJoypadButton:
					if ex_ev.button_index == new_ev.button_index and ex_ev.device == new_ev.device:
						already_bound = true
						break
				elif new_ev is InputEventJoypadMotion and ex_ev is InputEventJoypadMotion:
					if ex_ev.axis == new_ev.axis and ex_ev.device == new_ev.device and sign(ex_ev.axis_value) == sign(new_ev.axis_value):
						already_bound = true
						break
			if not already_bound:
				InputMap.action_add_event(action_name, new_ev)


func _key(code: Key, loc: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.location = loc
	return ev


func _pad_button(btn: JoyButton, device: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = btn
	ev.device = device
	return ev


func _pad_axis(axis: JoyAxis, val: float, device: int) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = val
	ev.device = device
	return ev
