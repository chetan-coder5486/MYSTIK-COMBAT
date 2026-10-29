class_name PauseMenu
extends Control
## Dedicated pause menu controller running in PROCESS_MODE_ALWAYS.
## Handles ESC / Gamepad Start hotkeys during pause state when gameplay is frozen.

signal resume_requested
signal restart_requested
signal quit_requested

var controls_modal: Control = null
var subtitle_label: Label = null
var buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if controls_modal != null and controls_modal.visible:
				controls_modal.visible = false
				if buttons.size() > 2:
					buttons[2].grab_focus()
			else:
				resume_requested.emit()
			get_viewport().set_input_as_handled()
			return

	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_BACK:
			if controls_modal != null and controls_modal.visible:
				controls_modal.visible = false
				if buttons.size() > 2:
					buttons[2].grab_focus()
			else:
				resume_requested.emit()
			get_viewport().set_input_as_handled()
			return

