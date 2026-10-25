
extends Node

signal combo_changed(fighter: CharacterBody2D, count: int)

@export var combo_window: float = 1.0

var combo_count: int = 0
var combo_timer: float = 0.0

var fighter: CharacterBody2D


func _ready() -> void:
	fighter = get_parent() as CharacterBody2D


func _process(delta: float) -> void:
	if combo_timer <= 0.0:
		return

	combo_timer = maxf(0.0, combo_timer - delta)

	if combo_timer == 0.0:
		combo_count = 0
		combo_changed.emit(fighter, combo_count)


func register_hit() -> void:
	if combo_timer > 0.0:
		combo_count += 1
	else:
		combo_count = 1

	combo_timer = combo_window
	combo_changed.emit(fighter, combo_count)


func reset() -> void:
	combo_count = 0
	combo_timer = 0.0
	combo_changed.emit(fighter, combo_count)
