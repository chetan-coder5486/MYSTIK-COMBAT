extends Node

var player1_character: String = "KAAL"
var player2_character: String = "NEX"
var winner_character: String = "KAAL"
var player1_round_wins: int = 0
var player2_round_wins: int = 0


func _ready() -> void:
	ensure_input_mappings()


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
