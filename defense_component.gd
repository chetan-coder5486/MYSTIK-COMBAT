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
		match kind:
			"ultimate":
				fighter.stun_time = 0.65
				fighter.velocity.x = attacker_facing * 520.0
				fighter.velocity.y = -140.0
			"special":
				fighter.stun_time = 0.42
				fighter.velocity.x = attacker_facing * 380.0
				if fighter.is_on_floor():
					fighter.velocity.y = -90.0
			"heavy":
				fighter.stun_time = 0.38
				fighter.velocity.x = attacker_facing * 320.0
				if fighter.is_on_floor():
					fighter.velocity.y = -80.0
			_: # light
				fighter.stun_time = 0.22
				fighter.velocity.x = attacker_facing * 180.0
				if fighter.is_on_floor():
					fighter.velocity.y = -60.0

	fighter.health = maxf(0.0, fighter.health - final_damage)

	# +0.4 Ki gain per point of damage taken (only if not defeated)
	if fighter.health > 0.0:
		fighter.add_ki(final_damage * 0.4)

	if not was_blocked:
		fighter.hit_flash_time = 0.14
		fighter.hit_reaction_time = 0.28 if (kind == "heavy" or kind == "special" or kind == "ultimate") else 0.16

		if fighter.animated_sprite != null:
			var frames: SpriteFrames = fighter.animated_sprite.sprite_frames
			if frames != null and frames.has_animation("hit_reaction"):
				fighter.animated_sprite.play("hit_reaction")
	else:
		# Blocked hit: guard is maintained
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
		# Play KO animation
		if fighter.animated_sprite != null:
			var frames: SpriteFrames = fighter.animated_sprite.sprite_frames
			if frames != null and frames.has_animation("ko"):
				fighter.animated_sprite.play("ko")

		fighter.knocked_out.emit(fighter)

	return not was_blocked
