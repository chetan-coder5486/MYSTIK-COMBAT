
extends Node2D

var fighter1: CharacterBody2D
var fighter2: CharacterBody2D

var health_bar1: ProgressBar
var health_bar2: ProgressBar
var status_label: Label
var combo_label1: Label
var combo_label2: Label
var round_dots1: Label
var round_dots2: Label

var round_number: int = 1
var round_wins: Array[int] = [0, 0]
var round_over: bool = false
var match_over: bool = false
var round_timer: float = 99.0

var phase: String = "countdown"
var phase_time: float = 0.0
var countdown_number: int = 3

func apply_character_selection() -> void:
	var kaal_frames = preload("res://kaal_frames.tres")
	var nex_frames = preload("res://nex_frames.tres")

	if GameSettings.player1_character == "KAAL":
		fighter1.animated_sprite.sprite_frames = kaal_frames
	else:
		fighter1.animated_sprite.sprite_frames = nex_frames

	if GameSettings.player2_character == "KAAL":
		fighter2.animated_sprite.sprite_frames = kaal_frames
	else:
		fighter2.animated_sprite.sprite_frames = nex_frames


func _ready() -> void:
	fighter1 = get_node("Fighter1")
	fighter2 = get_node("Fighter2")

	apply_character_selection()
	
	fighter1.health_changed.connect(_on_health_changed)
	fighter2.health_changed.connect(_on_health_changed)
	fighter1.knocked_out.connect(_on_knocked_out)
	fighter2.knocked_out.connect(_on_knocked_out)

	var hud := CanvasLayer.new()
	add_child(hud)

	health_bar1 = make_health_bar(Vector2(30, 25), Color.CRIMSON)
	health_bar2 = make_health_bar(Vector2(742, 25), Color.CRIMSON)
	hud.add_child(health_bar1)
	hud.add_child(health_bar2)

	round_dots1 = Label.new()
	round_dots1.position = Vector2(30, 55)
	round_dots1.add_theme_font_size_override("font_size", 24)
	round_dots1.add_theme_color_override("font_color", Color.YELLOW)
	hud.add_child(round_dots1)

	round_dots2 = Label.new()
	round_dots2.position = Vector2(742, 55)
	round_dots2.add_theme_font_size_override("font_size", 24)
	round_dots2.add_theme_color_override("font_color", Color.YELLOW)
	hud.add_child(round_dots2)

	combo_label1 = Label.new()
	combo_label1.position = Vector2(30, 85)
	combo_label1.add_theme_font_size_override("font_size", 22)
	hud.add_child(combo_label1)

	combo_label2 = Label.new()
	combo_label2.position = Vector2(900, 85)
	combo_label2.add_theme_font_size_override("font_size", 22)
	hud.add_child(combo_label2)

	fighter1.combo_component.combo_changed.connect(_on_combo_changed)
	fighter2.combo_component.combo_changed.connect(_on_combo_changed)

	status_label = Label.new()
	status_label.position = Vector2(450, 20)
	status_label.size = Vector2(300, 50)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 28)
	hud.add_child(status_label)

	# Start the first round.
	prepare_round()


func make_health_bar(pos: Vector2, bar_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = Vector2(370, 28)
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	bar.modulate = bar_color
	return bar


func update_round_dots() -> void:
	round_dots1.text = ("●" if round_wins[0] >= 1 else "○") + "  " + ("●" if round_wins[0] >= 2 else "○")
	round_dots2.text = ("●" if round_wins[1] >= 1 else "○") + "  " + ("●" if round_wins[1] >= 2 else "○")


func _on_combo_changed(fighter: CharacterBody2D, count: int) -> void:
	var label: Label = combo_label1 if fighter == fighter1 else combo_label2
	label.text = "%d HIT COMBO!" % count if count >= 2 else ""


func _process(delta: float) -> void:
	if match_over:
		return

	if phase == "fight":
		round_timer = maxf(0.0, round_timer - delta)
		status_label.text = "ROUND %d  |  %02d" % [
			round_number, int(ceil(round_timer))
		]

		if round_timer <= 0.0:
			if fighter1.health > fighter2.health:
				end_round(fighter1)
			elif fighter2.health > fighter1.health:
				end_round(fighter2)
			else:
				end_draw_round()
		return

	phase_time -= delta
	if phase_time > 0.0:
		return

	match phase:
		"countdown":
			countdown_number -= 1
			if countdown_number > 0:
				status_label.text = str(countdown_number)
				phase_time = 1.0
			else:
				phase = "fight_call"
				status_label.text = "FIGHT!"
				phase_time = 0.7

		"fight_call":
			phase = "fight"
			round_over = false
			fighter1.set_physics_process(true)
			fighter2.set_physics_process(true)
			status_label.text = "ROUND %d  |  99" % round_number

		"round_result":
			start_next_round()


func _on_health_changed(
	fighter: CharacterBody2D,
	current: float,
	maximum: float
) -> void:
	if maximum <= 0.0:
		return

	if fighter == fighter1:
		health_bar1.value = current / maximum * 100.0
	else:
		health_bar2.value = current / maximum * 100.0


func _on_knocked_out(fighter: CharacterBody2D) -> void:
	if phase != "fight" or round_over or match_over:
		return

	end_round(fighter2 if fighter == fighter1 else fighter1)


func end_round(winner: CharacterBody2D) -> void:
	if round_over or match_over or phase != "fight":
		return

	round_over = true
	phase = "round_result"

	fighter1.set_physics_process(false)
	fighter2.set_physics_process(false)
	fighter1.velocity = Vector2.ZERO
	fighter2.velocity = Vector2.ZERO

	var winner_index: int = 0 if winner == fighter1 else 1
	round_wins[winner_index] += 1

	GameSettings.player1_round_wins = round_wins[0]
	GameSettings.player2_round_wins = round_wins[1]

	update_round_dots()

	if round_wins[winner_index] >= 2:
		match_over = true
		phase = "match_result"

		GameSettings.winner_character = (
			GameSettings.player1_character
			if winner == fighter1
			else GameSettings.player2_character
		)

		get_tree().change_scene_to_file("res://Results.tscn")
		return

	status_label.text = "PLAYER %d WINS ROUND %d" % [
		winner_index + 1, round_number
	]
	phase_time = 1.8


func end_draw_round() -> void:
	if round_over or match_over or phase != "fight":
		return

	round_over = true
	phase = "round_result"

	fighter1.set_physics_process(false)
	fighter2.set_physics_process(false)
	fighter1.velocity = Vector2.ZERO
	fighter2.velocity = Vector2.ZERO

	status_label.text = "DRAW ROUND"
	phase_time = 1.8


func prepare_round() -> void:
	round_over = true
	phase = "countdown"
	countdown_number = 3
	phase_time = 1.0
	round_timer = 99.0

	fighter1.set_physics_process(false)
	fighter2.set_physics_process(false)

	# Reset both fighters.
	for fighter in [fighter1, fighter2]:
		fighter.health = fighter.max_health
		fighter.defeated = false
		fighter.blocking = false
		fighter.stun_time = 0.0
		fighter.hit_flash_time = 0.0
		fighter.hit_reaction_time = 0.0
		fighter.velocity = Vector2.ZERO
		fighter.combat_component.cancel_attack()
		fighter.combo_component.reset()

	fighter1.global_position = Vector2(250, 500)
	fighter2.global_position = Vector2(900, 500)

	# Restore initial directions.
	fighter1.facing = 1.0
	fighter2.facing = -1.0
	
	# Update sprite directions immediately.
	if fighter1.animated_sprite:
		fighter1.animated_sprite.flip_h = fighter1.facing < 0.0

	if fighter2.animated_sprite:
		fighter2.animated_sprite.flip_h = fighter2.facing < 0.0
		
	# Restore idle animations.
	if fighter1.animated_sprite:
		fighter1.animated_sprite.play("idle")
	if fighter2.animated_sprite:
		fighter2.animated_sprite.play("idle")

	fighter1.health_changed.emit(
		fighter1, fighter1.health, fighter1.max_health
	)
	fighter2.health_changed.emit(
		fighter2, fighter2.health, fighter2.max_health
	)

	combo_label1.text = ""
	combo_label2.text = ""
	update_round_dots()
	status_label.text = "3"


func start_next_round() -> void:
	round_number += 1
	prepare_round()


func restart_match() -> void:
	round_wins = [0, 0]
	round_number = 1
	match_over = false
	prepare_round()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo or event.keycode != KEY_R:
		return

	if match_over:
		restart_match()
