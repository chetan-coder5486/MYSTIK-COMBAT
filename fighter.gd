
extends CharacterBody2D

signal health_changed(fighter: CharacterBody2D, current: float, maximum: float)
signal knocked_out(fighter: CharacterBody2D)

@export var player_number: int = 1
@export var move_speed: float = 350.0
@export var jump_velocity: float = -650.0
@export var arena_left: float = 0.0
@export var arena_right: float = 1152.0
@export var max_health: float = 100.0

const GRAVITY: float = 1600.0
const BODY_WIDTH: float = 40.0
const BODY_HEIGHT: float = 100.0

var health: float
var facing: float = 1.0
var stun_time: float = 0.0
var hit_flash_time: float = 0.0
var blocking: bool = false
var defeated: bool = false

@onready var body_visual: ColorRect = $ColorRect
@onready var combo_component = $ComboComponent
@onready var combat_component = $CombatComponent
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

var original_color: Color
const BLOCK_COLOR := Color(0.2, 0.55, 1.0)   # Blue
const HIT_COLOR := Color(1.0, 1.0, 1.0)      # White flash
const LIGHT_ATTACK_COLOR := Color(1.0, 0.85, 0.2)  # Yellow
const HEAVY_ATTACK_COLOR := Color(1.0, 0.25, 0.15) # Red
var hit_reaction_time: float = 0.0
var original_visual_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	health = max_health
	original_color = body_visual.color
	add_to_group("fighters")
	
	if animated_sprite:
		animated_sprite.play("idle")
	else:
		print("AnimatedSprite2D not found for ", name)
	
	# Initially face each other.
	facing = 1.0 if player_number == 1 else -1.0

	health_changed.emit(self, health, max_health)
	body_visual.pivot_offset = body_visual.size / 2.0
	original_visual_scale = body_visual.scale


func _physics_process(delta: float) -> void:
	if defeated:
		combat_component.cancel_attack()
		blocking = false

		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)

		if not is_on_floor():
			velocity.y += GRAVITY * delta

		move_and_slide()

		global_position.x = clampf(
			global_position.x,
			arena_left + BODY_WIDTH / 2.0,
			arena_right - BODY_WIDTH / 2.0
		)
		return

	stun_time = maxf(0.0, stun_time - delta)
	hit_flash_time = maxf(0.0, hit_flash_time - delta)
	
	hit_reaction_time = maxf(0.0, hit_reaction_time - delta)

	if hit_reaction_time > 0.0:
		body_visual.scale = original_visual_scale * Vector2(1.2, 0.8)
	else:
		body_visual.scale = original_visual_scale

	if hit_flash_time > 0.0:
		body_visual.color = HIT_COLOR
	elif blocking:
		body_visual.color = BLOCK_COLOR
	elif combat_component.attack_kind == "light":
		body_visual.color = LIGHT_ATTACK_COLOR
	elif combat_component.attack_kind == "heavy":
		body_visual.color = HEAVY_ATTACK_COLOR
	else:
		body_visual.color = original_color

	var left_action := "p1_left" if player_number == 1 else "p2_left"
	var right_action := "p1_right" if player_number == 1 else "p2_right"
	var jump_action := "p1_jump" if player_number == 1 else "p2_jump"
	var light_action := "p1_light" if player_number == 1 else "p2_light"
	var heavy_action := "p1_heavy" if player_number == 1 else "p2_heavy"
	var block_action := "p1_block" if player_number == 1 else "p2_block"

	var opponent := find_opponent()

	blocking = (
		Input.is_action_pressed(block_action)
		and is_on_floor()
		and combat_component.attack_kind == ""
		and stun_time == 0.0
	)

	if stun_time > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)

	elif combat_component.attack_kind != "":
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		combat_component.update_attack(delta, opponent)

	else:
		var direction := Input.get_axis(left_action, right_action)

# Always face the opponent.
		if opponent != null:
			if opponent.global_position.x < global_position.x:
				facing = -1.0
			elif opponent.global_position.x > global_position.x:
				facing = 1.0
		update_facing_visual()
		velocity.x = direction * move_speed

		if Input.is_action_just_pressed(jump_action) and is_on_floor():
			velocity.y = jump_velocity

		if not blocking:
			if Input.is_action_just_pressed(light_action):
				combat_component.start_attack("light")
			elif Input.is_action_just_pressed(heavy_action):
				combat_component.start_attack("heavy")

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	move_and_slide()
	
	update_animation()
	
	global_position.x = clampf(
		global_position.x,
		arena_left + BODY_WIDTH / 2.0,
		arena_right - BODY_WIDTH / 2.0
	)

	queue_redraw()


func get_hurtbox() -> Rect2:
	return Rect2(
		global_position.x - BODY_WIDTH / 2.0,
		global_position.y - BODY_HEIGHT / 2.0,
		BODY_WIDTH,
		BODY_HEIGHT
	)


func take_damage(
	amount: float,
	attacker_facing: float,
	kind: String
) -> bool:
	return $DefenseComponent.take_damage(
		amount,
		attacker_facing,
		kind
	)


func find_opponent() -> CharacterBody2D:
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if fighter != self and is_instance_valid(fighter):
			return fighter as CharacterBody2D

	return null


func _draw() -> void:
	# Debug hurtbox.
	draw_rect(
		Rect2(
			-BODY_WIDTH / 2.0,
			-BODY_HEIGHT / 2.0,
			BODY_WIDTH,
			BODY_HEIGHT
		),
		Color(0.1, 0.9, 0.2, 0.25),
		false,
		2.0
	)

	# Draw the attack hitbox only during active frames.
	if combat_component.is_attack_active():
		var hitbox: Rect2 = combat_component.get_attack_hitbox()
		hitbox.position -= global_position

		draw_rect(hitbox, Color(1.0, 0.1, 0.1, 0.45), true)
		draw_rect(hitbox, Color.RED, false, 2.0)


func update_animation() -> void:
	if animated_sprite == null or defeated:
		return

	# Attacks have priority.
	if combat_component.attack_kind != "":
		return

	# Blocking has priority over hit reaction.
	if blocking and is_on_floor():
		if animated_sprite.animation != "block":
			animated_sprite.play("block")
			animated_sprite.set_frame_and_progress(1, 0.0)
		animated_sprite.pause()
		return

	# Finish an unblocked hit reaction.
	if animated_sprite.animation == "hit_reaction" and animated_sprite.is_playing():
		return

	# Jump.
	if not is_on_floor():
		if animated_sprite.animation != "jump":
			animated_sprite.play("jump")
		return

	# Walk or idle.
	if abs(velocity.x) > 10.0:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")


func update_facing_visual() -> void:
	if animated_sprite != null:
		animated_sprite.flip_h = facing < 0.0
