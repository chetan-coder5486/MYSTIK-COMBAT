class_name CharacterSelectScreen
extends Control
## Two-player character select.
##
## Responsibilities are split three ways:
##   SelectionModel  - rules and state (no nodes, unit-testable)
##   CharacterCard / FighterPanel - drawing
##   this script     - input, flow (lock -> countdown -> fight) and scene changes
##
## Controls (all remappable in Project Settings > Input Map; the actions are
## only created here when they do not exist yet):
##   P1: A/D/W/S move, F select, G back      pad 0: D-pad/stick, A, B
##   P2: arrows move, Enter select, Backspace back   pad 1: D-pad/stick, A, B
##   Esc: back to menu.   Mouse: left click = P1 pick, right click = P2 pick.

## Both players locked in and the scene is about to change.
signal selection_confirmed(player1: CharacterData, player2: CharacterData)

const SLOT_NAMES: Array[String] = ["p1", "p2"]
const DIRECTIONS: Dictionary = {
	"left": Vector2i.LEFT,
	"right": Vector2i.RIGHT,
	"up": Vector2i.UP,
	"down": Vector2i.DOWN,
}

@export_group("Roster")
@export var roster: Array[CharacterData] = []
@export_range(1, 8) var columns: int = 4
@export var allow_mirror_match: bool = true

@export_group("Flow")
@export_file("*.tscn") var next_scene: String = "res://Main.tscn"
@export_file("*.tscn") var back_scene: String = "res://MainMenu.tscn"
## Seconds between both players locking in and the fight starting.
## Either player can cancel during this window. 0 starts immediately.
@export_range(0.0, 3.0, 0.1) var start_delay: float = 1.0
@export_range(0.0, 1.0, 0.05) var fade_time: float = 0.25

@export_group("Presentation")
@export var background: Texture2D
@export var title: String = "SELECT YOUR FIGHTER"
@export_multiline var hint_text: String = "P1: WASD MOVE  -  F SELECT  -  G BACK          P2: ARROWS / IJKL / NUMPAD MOVE  -  ENTER SELECT  -  BACKSPACE BACK"


@export_group("Audio")
@export var sfx_move: AudioStream
@export var sfx_confirm: AudioStream
@export var sfx_cancel: AudioStream

@onready var _background: TextureRect = %Background
@onready var _title_label: Label = %TitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _hint_label: Label = %HintLabel
@onready var _grid: GridContainer = %RosterGrid
@onready var _back_button: Button = %BackButton
@onready var _fade: ColorRect = %Fade
@onready var _p1_panel: FighterPanel = %P1Panel
@onready var _p2_panel: FighterPanel = %P2Panel

var _model: SelectionModel
var _cards: Array[CharacterCard] = []
var _panels: Array[FighterPanel] = []
var _start_timer: Timer
var _sfx_player: AudioStreamPlayer
var _leaving: bool = false


func _ready() -> void:
	if has_node("/root/ArcadeManager"):
		get_node("/root/ArcadeManager").end_arcade()

	if roster.is_empty():
		push_error("CharacterSelect: 'roster' is empty. Assign CharacterData resources in the Inspector.")
		set_process(false)
		set_process_unhandled_input(false)
		return

	_ensure_input_actions()
	if GameSettings != null and GameSettings.has_method("play_menu_music"):
		GameSettings.play_menu_music()


	_model = SelectionModel.new(roster.size(), columns, allow_mirror_match)
	_model.cursor_moved.connect(_on_cursor_moved)
	_model.lock_changed.connect(_on_lock_changed)

	_panels = [_p1_panel, _p2_panel]
	_start_timer = Timer.new()
	_start_timer.one_shot = true
	_start_timer.timeout.connect(_begin_fight)
	add_child(_start_timer)
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)

	if background:
		_background.texture = background
	_title_label.text = title
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_label.add_theme_constant_override("shadow_outline_size", 6)

	_hint_label.text = hint_text
	_back_button.pressed.connect(_go_back)

	# Clean stylized back button
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.06, 0.08, 0.14, 0.85)
	btn_normal.border_color = Color(0.25, 0.35, 0.55, 0.7)
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.set_corner_radius_all(6)
	_back_button.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.12, 0.16, 0.26, 0.95)
	btn_hover.border_color = Color(1.0, 0.85, 0.28, 0.95)
	_back_button.add_theme_stylebox_override("hover", btn_hover)
	_back_button.add_theme_stylebox_override("focus", btn_hover)

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.04, 0.05, 0.09, 1.0)
	btn_pressed.border_color = Color(1.0, 0.85, 0.28, 1.0)
	_back_button.add_theme_stylebox_override("pressed", btn_pressed)

	_back_button.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	_back_button.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.28))
	_back_button.add_theme_color_override("font_focus_color", Color(1.0, 0.86, 0.28))

	_build_roster()
	_refresh()
	_update_mode_presentation()
	_fade_from_black()


func _update_mode_presentation() -> void:
	var vs_cpu: bool = true
	if has_node("/root/GameSettings"):
		vs_cpu = bool(get_node("/root/GameSettings").vs_ai)

	if vs_cpu:
		_title_label.text = "SELECT YOUR FIGHTER — VS CPU"
		_p2_panel.set_tag_text("CPU (AI)")
		_hint_label.text = "P1: WASD MOVE • F SELECT    P2: ARROWS / ENTER    [TAB] TOGGLE P2: CPU / HUMAN"
	else:
		_title_label.text = "SELECT YOUR FIGHTER — LOCAL 2-PLAYER"
		_p2_panel.set_tag_text("PLAYER 2 (HUMAN)")
		_hint_label.text = "P1: WASD MOVE • F SELECT    P2: ARROWS / ENTER    [TAB] TOGGLE P2: CPU / HUMAN"


func _process(_delta: float) -> void:
	if _leaving:
		return
	for slot in SelectionModel.SLOT_COUNT:
		for direction_name: String in DIRECTIONS:
			if Input.is_action_just_pressed(_action(slot, direction_name)):
				_model.move_cursor(slot, DIRECTIONS[direction_name])
		if Input.is_action_just_pressed(_action(slot, "confirm")):
			_confirm(slot)
		if Input.is_action_just_pressed(_action(slot, "cancel")):
			_cancel(slot)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE:
			_go_back()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_TAB:
			if has_node("/root/GameSettings"):
				var gs = get_node("/root/GameSettings")
				gs.vs_ai = not gs.vs_ai
				_update_mode_presentation()
				get_viewport().set_input_as_handled()


# --- Flow -------------------------------------------------------------------

func _confirm(slot: int) -> void:
	if _model.lock(slot):
		_play(sfx_confirm)


func _cancel(slot: int) -> void:
	if _model.unlock(slot):
		_play(sfx_cancel)
	elif not _model.any_locked():
		_go_back()


func _on_cursor_moved(_slot: int, _index: int) -> void:
	_play(sfx_move)
	_refresh()


func _on_lock_changed(_slot: int, _locked: bool) -> void:
	_refresh()
	if _model.all_locked():
		if start_delay > 0.0:
			_start_timer.start(start_delay)
		else:
			_begin_fight()
	else:
		_start_timer.stop()


func _begin_fight() -> void:
	if _leaving:
		return
	var player1: CharacterData = roster[_model.cursor(0)]
	var player2: CharacterData = roster[_model.cursor(1)]
	GameSettings.player1_character = player1.id
	GameSettings.player2_character = player2.id
	selection_confirmed.emit(player1, player2)
	_change_scene(next_scene)


func _go_back() -> void:
	_change_scene(back_scene)


func _change_scene(path: String) -> void:
	if _leaving:
		return
	if not ResourceLoader.exists(path):
		push_error("CharacterSelect: scene not found: '%s'" % path)
		return
	_leaving = true
	_start_timer.stop()
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, fade_time)
	await tween.finished
	if is_inside_tree():
		get_tree().change_scene_to_file(path)


# --- View -------------------------------------------------------------------

func _build_roster() -> void:
	_grid.columns = _model.columns
	for index in roster.size():
		var card := CharacterCard.new()
		card.setup(index, roster[index])
		_grid.add_child(card)
		_cards.append(card)



func _refresh() -> void:
	for card in _cards:
		for slot in SelectionModel.SLOT_COUNT:
			var on_card: bool = _model.cursor(slot) == card.index
			card.set_cursor(slot, on_card)
			card.set_locked(slot, on_card and _model.is_locked(slot))
	for slot in SelectionModel.SLOT_COUNT:
		_panels[slot].show_character(roster[_model.cursor(slot)])
		_panels[slot].set_locked(_model.is_locked(slot))
	_status_label.text = _status_text()


func _status_text() -> String:
	if _model.all_locked():
		return "FIGHT!"
	if _model.any_locked():
		var waiting: int = 1 if _model.is_locked(0) else 0
		return "WAITING FOR PLAYER %d" % (waiting + 1)
	return ""


func _fade_from_black() -> void:
	_fade.modulate.a = 1.0
	create_tween().tween_property(_fade, "modulate:a", 0.0, fade_time)


func _play(_stream: AudioStream) -> void:
	return


# --- Input map --------------------------------------------------------------

func _action(slot: int, suffix: String) -> StringName:
	return StringName("select_%s_%s" % [SLOT_NAMES[slot], suffix])


## Registers default bindings for any menu action that is missing, so the
## screen works out of the box. Define the actions in Project Settings to
## override or extend them; existing actions are never touched.
func _ensure_input_actions() -> void:
	for slot in SelectionModel.SLOT_COUNT:
		var bindings: Dictionary = _default_bindings(slot)
		for suffix: String in bindings:
			var action: StringName = _action(slot, suffix)
			if InputMap.has_action(action):
				continue
			InputMap.add_action(action, 0.5)
			for event: InputEvent in bindings[suffix]:
				InputMap.action_add_event(action, event)


func _default_bindings(slot: int) -> Dictionary:
	if slot == 0:
		return {
			"left": [_key(KEY_A), _pad_button(JOY_BUTTON_DPAD_LEFT, 0), _pad_axis(JOY_AXIS_LEFT_X, -1.0, 0)],
			"right": [_key(KEY_D), _pad_button(JOY_BUTTON_DPAD_RIGHT, 0), _pad_axis(JOY_AXIS_LEFT_X, 1.0, 0)],
			"up": [_key(KEY_W), _pad_button(JOY_BUTTON_DPAD_UP, 0), _pad_axis(JOY_AXIS_LEFT_Y, -1.0, 0)],
			"down": [_key(KEY_S), _pad_button(JOY_BUTTON_DPAD_DOWN, 0), _pad_axis(JOY_AXIS_LEFT_Y, 1.0, 0)],
			"confirm": [_key(KEY_F), _pad_button(JOY_BUTTON_A, 0)],
			"cancel": [_key(KEY_G), _pad_button(JOY_BUTTON_B, 0)],
		}
	return {
		"left": [_key(KEY_LEFT), _key(KEY_J), _key(KEY_KP_4), _pad_button(JOY_BUTTON_DPAD_LEFT, 1), _pad_axis(JOY_AXIS_LEFT_X, -1.0, 1)],
		"right": [_key(KEY_RIGHT), _key(KEY_L), _key(KEY_KP_6), _pad_button(JOY_BUTTON_DPAD_RIGHT, 1), _pad_axis(JOY_AXIS_LEFT_X, 1.0, 1)],
		"up": [_key(KEY_UP), _key(KEY_I), _key(KEY_KP_8), _pad_button(JOY_BUTTON_DPAD_UP, 1), _pad_axis(JOY_AXIS_LEFT_Y, -1.0, 1)],
		"down": [_key(KEY_DOWN), _key(KEY_K), _key(KEY_KP_5), _key(KEY_KP_2), _pad_button(JOY_BUTTON_DPAD_DOWN, 1), _pad_axis(JOY_AXIS_LEFT_Y, 1.0, 1)],
		"confirm": [_key(KEY_ENTER), _key(KEY_KP_ENTER), _pad_button(JOY_BUTTON_A, 1)],
		"cancel": [_key(KEY_BACKSPACE), _pad_button(JOY_BUTTON_B, 1)],
	}



func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _pad_button(button: JoyButton, device: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = device
	return event


func _pad_axis(axis: JoyAxis, value: float, device: int) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	event.device = device
	return event
