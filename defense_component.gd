
extends Node

var fighter: CharacterBody2D


func _ready() -> void:
	fighter = get_parent() as CharacterBody2D


func take_damage(
	amount: float,
	attacker_facing: float,
	kind: String
) -> bool:
	if fighter.defeated:
		return false
		
	var opponent: CharacterBody2D = fighter.find_opponent()
	var attacker_is_in_front := false

	if opponent != null:
		attacker_is_in_front = (
			(fighter.global_position.x - opponent.global_position.x)
			* fighter.facing < 0.0
		)

	var was_blocked: bool = fighter.blocking and attacker_is_in_front
	var final_damage: float = amount

	if was_blocked:
		final_damage *= 0.20
	else:
		fighter.stun_time = 0.22 if kind == "light" else 0.38

		fighter.velocity.x = attacker_facing * (
			180.0 if kind == "light" else 320.0
		)

		if fighter.is_on_floor():
			fighter.velocity.y = -80.0

	fighter.health = maxf(0.0, fighter.health - final_damage)
	if not was_blocked:
		fighter.hit_flash_time = 0.12
		fighter.hit_reaction_time = 0.22 if kind == "heavy" else 0.16

		if fighter.player_number == 1 and fighter.animated_sprite:
			if (
			fighter.animated_sprite.sprite_frames != null
			and fighter.animated_sprite.sprite_frames.has_animation("hit_reaction")
			):
				fighter.animated_sprite.play("hit_reaction")
	else:
	# A blocked hit should show the guard, not hit reaction.
		fighter.hit_flash_time = 0.0
		fighter.hit_reaction_time = 0.0

	fighter.health_changed.emit(
		fighter,
		fighter.health,
		fighter.max_health
	)

	if fighter.health <= 0.0:
		fighter.defeated = true
		fighter.blocking = false
		fighter.combat_component.cancel_attack()
	# Play KO animation once.
		if fighter.animated_sprite != null:
			var frames = fighter.animated_sprite.sprite_frames
			if frames != null and frames.has_animation("ko"):
				fighter.animated_sprite.play("ko")

		fighter.knocked_out.emit(fighter)

	return not was_blocked
