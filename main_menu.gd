
extends Control

@onready var play_button: Button = $MenuContainer/PlayButton
@onready var quit_button: Button = $MenuContainer/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/character_select/character_select.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
