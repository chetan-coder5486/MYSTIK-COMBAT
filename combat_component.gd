
extends Node

const LIGHT_STARTUP := 0.10
const LIGHT_ACTIVE := 0.12
const LIGHT_RECOVERY := 0.22
const LIGHT_DAMAGE := 8.0

const HEAVY_STARTUP := 0.24
const HEAVY_ACTIVE := 0.16
const HEAVY_RECOVERY := 0.42
const HEAVY_DAMAGE := 16.0

const HIT_EFFECT_SCENE: PackedScene = preload("res://scenes/hit_effect.tscn")

var attack_kind: String = ""
var attack_time: float = 0.0
var attack_has_hit: bool = false

var fighter: CharacterBody2D


func _ready() -> void:
	fighter = get_parent() as CharacterBody2D



func start_attack(kind: String) -> void:
	if fighter.defeated:
		return

	attack_kind = kind
	attack_time = 0.0
	attack_has_hit = false

	# Play the matching attack animation when available.
	if fighter.animated_sprite != null:
		var animation_name := ""

		if kind == "light":
			animation_name = "light_attack"
		elif kind == "heavy":
			animation_name = "heavy_attack"

		if (
			animation_name != ""
			and fighter.animated_sprite.sprite_frames != null
			and fighter.animated_sprite.sprite_frames.has_animation(animation_name)
		):
			fighter.animated_sprite.play(animation_name)

	fighter.queue_redraw()

			
func update_attack(delta: float, opponent: CharacterBody2D) -> void:
	if fighter.defeated:
		cancel_attack()
		return

	if attack_kind == "":
		return

	attack_time += delta

	if opponent == null or opponent.defeated:
		finish_attack_if_ready()
		fighter.queue_redraw()
		return

	var startup := LIGHT_STARTUP if attack_kind == "light" else HEAVY_STARTUP
	var active := LIGHT_ACTIVE if attack_kind == "light" else HEAVY_ACTIVE
	var recovery := LIGHT_RECOVERY if attack_kind == "light" else HEAVY_RECOVERY

	if attack_time >= startup and attack_time < startup + active:
		if not attack_has_hit and get_attack_hitbox().intersects(opponent.get_hurtbox()):
			attack_has_hit = true
			
			spawn_hit_effect(opponent)
			
			var damage := LIGHT_DAMAGE if attack_kind == "light" else HEAVY_DAMAGE
			var landed: bool = opponent.take_damage(
				damage,
				fighter.facing,
				attack_kind
			)

			if landed:
				fighter.combo_component.register_hit()
			else:
				spawn_block_effect(opponent)

	if attack_time >= startup + active + recovery:
		cancel_attack()

	fighter.queue_redraw()


func finish_attack_if_ready() -> void:
	var total_time := (
		LIGHT_STARTUP + LIGHT_ACTIVE + LIGHT_RECOVERY
		if attack_kind == "light"
		else HEAVY_STARTUP + HEAVY_ACTIVE + HEAVY_RECOVERY
	)

	if attack_time >= total_time:
		cancel_attack()


func cancel_attack() -> void:
	attack_kind = ""
	attack_time = 0.0
	attack_has_hit = false
	fighter.queue_redraw()


func get_attack_hitbox() -> Rect2:
	var reach := 65.0 if attack_kind == "light" else 85.0
	var hit_height := 38.0 if attack_kind == "light" else 55.0
	var hit_y: float = fighter.global_position.y - 100.0 * 0.55
	var hit_x: float
	if fighter.facing > 0.0:
		hit_x = fighter.global_position.x + fighter.BODY_WIDTH / 2.0
	else:
		hit_x = fighter.global_position.x - fighter.BODY_WIDTH / 2.0 - reach

	return Rect2(hit_x, hit_y, reach, hit_height)


func is_attack_active() -> bool:
	if attack_kind == "":
		return false

	var startup := LIGHT_STARTUP if attack_kind == "light" else HEAVY_STARTUP
	var active := LIGHT_ACTIVE if attack_kind == "light" else HEAVY_ACTIVE

	return attack_time >= startup and attack_time < startup + active


func spawn_hit_effect(opponent: CharacterBody2D) -> void:
	var effect := HIT_EFFECT_SCENE.instantiate()

	effect.effect_kind = attack_kind

	var overlap: Rect2 = (
		get_attack_hitbox().intersection(opponent.get_hurtbox())
	)

	var scene_root := fighter.get_tree().current_scene
	scene_root.add_child(effect)
	effect.global_position = overlap.get_center()


func spawn_block_effect(opponent: CharacterBody2D) -> void:
	var effect := HIT_EFFECT_SCENE.instantiate()
	effect.effect_kind = "block"

	var overlap: Rect2 = (
		get_attack_hitbox().intersection(opponent.get_hurtbox())
	)

	var scene_root := fighter.get_tree().current_scene
	scene_root.add_child(effect)
	effect.global_position = overlap.get_center()
