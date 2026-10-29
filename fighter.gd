extends CharacterBody2D

signal health_changed(fighter: CharacterBody2D, current: float, maximum: float)
signal ki_changed(fighter: CharacterBody2D, current: float, maximum: float)
signal knocked_out(fighter: CharacterBody2D)

@export var player_number: int = 1
@export var character_name: String = "KAAL"
@export var move_speed: float = 350.0
@export var jump_velocity: float = -790.0
@export var arena_left: float = 0.0
@export var arena_right: float = 1152.0
@export var max_health: float = 100.0

const GRAVITY: float = 1600.0
const BODY_WIDTH: float = 60.0
const BODY_HEIGHT: float = 160.0
const SPRITE_SCALE := Vector2(0.26, 0.26)
const MAX_KI: float = 100.0

var health: float
var ki: float = 0.0
var facing: float = 1.0
var stun_time: float = 0.0
var hit_stop_time: float = 0.0
var _was_hit_stopped: bool = false
var hit_flash_time: float = 0.0
var blocking: bool = false
var defeated: bool = false

@onready var body_visual: ColorRect = $ColorRect
@onready var combo_component = $ComboComponent
@onready var combat_component = $CombatComponent
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

var original_color: Color
const BLOCK_COLOR := Color(0.2, 0.55, 1.0)          # Blue
const HIT_COLOR := Color(1.0, 1.0, 1.0)             # White flash
const LIGHT_ATTACK_COLOR := Color(1.0, 0.85, 0.2)   # Yellow
const HEAVY_ATTACK_COLOR := Color(1.0, 0.25, 0.15)  # Red
const SPECIAL_ATTACK_COLOR := Color(1.0, 0.55, 0.1) # Orange
const ULTIMATE_ATTACK_COLOR := Color(1.0, 0.95, 0.2)# Gold

var hit_reaction_time: float = 0.0
var original_visual_scale: Vector2 = Vector2.ONE

var is_ai: bool = false
var ai_controller: AIController = null

# Arcade & Boss Encounter properties
var is_boss: bool = false
var boss_title: String = ""
var damage_multiplier: float = 1.0
var damage_taken_multiplier: float = 1.0
var boss_aura_time: float = 0.0
var show_hitboxes: bool = false

# Key buffer flags for responsive direct input
var _key_special_pressed: bool = false
var _key_ultimate_pressed: bool = false

# Jump buffer and coyote time to guarantee responsive jumps without frame drops
const JUMP_BUFFER_DURATION: float = 0.15
const COYOTE_DURATION: float = 0.08
var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0



func setup_from_data(data: CharacterData) -> void:
	character_name = data.id
	max_health = data.max_health
	health = data.max_health
	move_speed = data.move_speed
	jump_velocity = data.jump_velocity
	if combat_component:
		combat_component.light_damage = data.light_damage
		combat_component.heavy_damage = data.heavy_damage
		combat_component.special_damage = data.special_damage
		combat_component.ultimate_damage = data.ultimate_damage
		combat_component.attack_speed_scale = data.attack_speed_scale
	if animated_sprite:
		var kaal_frames = preload("res://kaal_frames.tres")
		var nex_frames = preload("res://nex_frames.tres")
		animated_sprite.sprite_frames = kaal_frames if data.id == "KAAL" else nex_frames
		animated_sprite.scale = SPRITE_SCALE
		animated_sprite.position = Vector2(0, -6)
		animated_sprite.play("idle")
	health_changed.emit(self, health, max_health)
	ki_changed.emit(self, ki, MAX_KI)


func setup_boss(boss_hp: float, dmg_mult: float, title: String = "") -> void:
	is_boss = true
	boss_title = title
	max_health = boss_hp
	health = boss_hp
	damage_multiplier = dmg_mult
	health_changed.emit(self, health, max_health)


func _ready() -> void:
	# Collide with floor and stage barriers on mask 1, fighters operate on layer 2
	collision_layer = 2
	collision_mask = 1

	health = max_health
	ki = 0.0
	floor_snap_length = 8.0
	original_color = body_visual.color
	add_to_group("fighters")
	
	if animated_sprite:
		animated_sprite.scale = SPRITE_SCALE
		animated_sprite.position = Vector2(0, -6)
		animated_sprite.play("idle")
	else:
		print("AnimatedSprite2D not found for ", name)
	
	# Initially face each other.
	facing = 1.0 if player_number == 1 else -1.0

	health_changed.emit(self, health, max_health)
	ki_changed.emit(self, ki, MAX_KI)
	body_visual.pivot_offset = body_visual.size / 2.0
	original_visual_scale = body_visual.scale

	if player_number == 2:
		var gs = get_node_or_null("/root/GameSettings")
		if gs and gs.get("vs_ai"):
			enable_ai(gs.get("ai_difficulty"))


func enable_ai(diff: float = 0.85) -> void:
	is_ai = true
	if ai_controller == null:
		ai_controller = AIController.new()
		ai_controller.name = "AIController"
		ai_controller.difficulty = diff
		add_child(ai_controller)



func add_ki(amount: float) -> void:
	if defeated or amount <= 0.0:
		return
	ki = clampf(ki + amount, 0.0, MAX_KI)
	ki_changed.emit(self, ki, MAX_KI)


func spend_ki(amount: float) -> bool:
	if ki >= amount:
		ki = clampf(ki - amount, 0.0, MAX_KI)
		ki_changed.emit(self, ki, MAX_KI)
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if is_ai:
		return
	if not (event is InputEventKey):
		return
	if not event.is_pressed() or event.is_echo():
		return

	if player_number == 1:
		if event.physical_keycode == KEY_Q or event.keycode == KEY_Q:
			_key_special_pressed = true
		elif event.physical_keycode == KEY_E or event.keycode == KEY_E:
			_key_ultimate_pressed = true
		elif event.physical_keycode == KEY_W or event.keycode == KEY_W:
			jump_buffer_timer = JUMP_BUFFER_DURATION
	else:
		# Player 2: Support Arrows, IJKL, Numpad, Right Shift, Enter
		if (event.physical_keycode == KEY_SHIFT or event.keycode == KEY_SHIFT) and event.location == KEY_LOCATION_RIGHT:
			_key_special_pressed = true
		elif event.physical_keycode == KEY_Y or event.keycode == KEY_Y or event.physical_keycode == KEY_KP_7:
			_key_special_pressed = true
		elif event.physical_keycode == KEY_ENTER or event.keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			_key_ultimate_pressed = true
		elif event.physical_keycode == KEY_P or event.keycode == KEY_P or event.physical_keycode == KEY_KP_9:
			_key_ultimate_pressed = true
		elif (
			event.physical_keycode == KEY_UP or event.keycode == KEY_UP
			or event.physical_keycode == KEY_I or event.keycode == KEY_I
			or event.physical_keycode == KEY_KP_8
		):
			jump_buffer_timer = JUMP_BUFFER_DURATION



func _physics_process(delta: float) -> void:
	if hit_stop_time > 0.0:
		hit_stop_time = maxf(0.0, hit_stop_time - delta)
		_was_hit_stopped = true
		if animated_sprite != null and animated_sprite.is_playing():
			animated_sprite.pause()
		velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		return

	if _was_hit_stopped:
		_was_hit_stopped = false
		if animated_sprite != null and not animated_sprite.is_playing() and not blocking:
			animated_sprite.play()

	if defeated:
		hit_stop_time = 0.0
		combat_component.cancel_attack()
		blocking = false

		if animated_sprite != null:
			if animated_sprite.animation != "ko":
				var frames: SpriteFrames = animated_sprite.sprite_frames
				if frames != null and frames.has_animation("ko"):
					animated_sprite.play("ko")
			elif not animated_sprite.is_playing() and animated_sprite.frame < 3:
				animated_sprite.play()

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
	if is_boss:
		boss_aura_time += delta

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
	elif combat_component.attack_kind == "special":
		body_visual.color = SPECIAL_ATTACK_COLOR
	elif combat_component.attack_kind == "ultimate":
		body_visual.color = ULTIMATE_ATTACK_COLOR
	else:
		body_visual.color = original_color

	var left_action := "p1_left" if player_number == 1 else "p2_left"
	var right_action := "p1_right" if player_number == 1 else "p2_right"
	var jump_action := "p1_jump" if player_number == 1 else "p2_jump"
	var light_action := "p1_light" if player_number == 1 else "p2_light"
	var heavy_action := "p1_heavy" if player_number == 1 else "p2_heavy"
	var block_action := "p1_block" if player_number == 1 else "p2_block"
	var special_action := "p1_special" if player_number == 1 else "p2_special"
	var ultimate_action := "p1_ultimate" if player_number == 1 else "p2_ultimate"

	var opponent := find_opponent()

	if is_ai and ai_controller:
		blocking = (
			ai_controller.want_block
			and is_on_floor()
			and combat_component.attack_kind == ""
			and stun_time == 0.0
		)
	else:
		blocking = (
			Input.is_action_pressed(block_action)
			and is_on_floor()
			and combat_component.attack_kind == ""
			and stun_time == 0.0
		)

	# Coyote time & jump buffer management
	if is_on_floor():
		coyote_timer = COYOTE_DURATION
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

	if stun_time > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
		# Clear attack buffers while stunned
		_key_special_pressed = false
		_key_ultimate_pressed = false

	elif combat_component.attack_kind != "":
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		combat_component.update_attack(delta, opponent)
		_key_special_pressed = false
		_key_ultimate_pressed = false

	else:
		var direction := 0.0
		if is_ai and ai_controller:
			direction = ai_controller.move_axis
			if ai_controller.want_jump:
				jump_buffer_timer = JUMP_BUFFER_DURATION
		else:
			direction = Input.get_axis(left_action, right_action)
			if Input.is_action_just_pressed(jump_action):
				jump_buffer_timer = JUMP_BUFFER_DURATION

		# Always face opponent
		if opponent != null:
			if opponent.global_position.x < global_position.x:
				facing = -1.0
			elif opponent.global_position.x > global_position.x:
				facing = 1.0
		update_facing_visual()
		velocity.x = direction * move_speed

		if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0

		if not blocking:
			var want_ultimate: bool = false
			var want_special: bool = false
			var want_light: bool = false
			var want_heavy: bool = false

			if is_ai and ai_controller:
				want_ultimate = ai_controller.want_ultimate
				want_special = ai_controller.want_special
				want_light = ai_controller.want_light
				want_heavy = ai_controller.want_heavy
			else:
				want_ultimate = Input.is_action_just_pressed(ultimate_action) or _key_ultimate_pressed
				want_special = Input.is_action_just_pressed(special_action) or _key_special_pressed
				want_light = Input.is_action_just_pressed(light_action)
				want_heavy = Input.is_action_just_pressed(heavy_action)

			if want_ultimate and ki >= 100.0:
				combat_component.start_attack("ultimate")
			elif want_special and ki >= 40.0:
				combat_component.start_attack("special")
			elif want_light:
				combat_component.start_attack("light")
			elif want_heavy:
				combat_component.start_attack("heavy")

		_key_special_pressed = false
		_key_ultimate_pressed = false

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		# Ensure grounded contact remains solid during horizontal motion
		if velocity.y > 0.0:
			velocity.y = 10.0

	move_and_slide()

	_resolve_pushbox(opponent)
	
	update_animation()
	
	global_position.x = clampf(
		global_position.x,
		arena_left + BODY_WIDTH / 2.0,
		arena_right - BODY_WIDTH / 2.0
	)

	queue_redraw()


func _resolve_pushbox(opponent: CharacterBody2D) -> void:
	if opponent == null or opponent.defeated or defeated:
		return

	var dx: float = global_position.x - opponent.global_position.x
	var dy: float = absf(global_position.y - opponent.global_position.y)

	# If jumping high enough over opponent, allow clean crossover without horizontal stop
	if dy >= 70.0:
		return

	var min_dist: float = BODY_WIDTH # 60.0 px
	var dist: float = absf(dx)

	if dist < min_dist:
		var overlap: float = min_dist - dist
		var push_dir: float = signf(dx)
		if push_dir == 0.0:
			push_dir = -1.0 if player_number == 1 else 1.0

		if is_on_floor() and opponent.is_on_floor():
			global_position.x += push_dir * (overlap * 0.5)
			opponent.global_position.x -= push_dir * (overlap * 0.5)
		else:
			global_position.x += push_dir * overlap

		global_position.x = clampf(
			global_position.x,
			arena_left + BODY_WIDTH / 2.0,
			arena_right - BODY_WIDTH / 2.0
		)
		opponent.global_position.x = clampf(
			opponent.global_position.x,
			arena_left + BODY_WIDTH / 2.0,
			arena_right - BODY_WIDTH / 2.0
		)


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
	kind: String,
	move_data: Dictionary = {}
) -> bool:
	return $DefenseComponent.take_damage(
		amount,
		attacker_facing,
		kind,
		move_data
	)


func find_opponent() -> CharacterBody2D:
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if fighter != self and is_instance_valid(fighter):
			return fighter as CharacterBody2D

	return null


func _draw() -> void:
	# Boss Dimensional Aura
	if is_boss and not defeated:
		var pulse: float = sin(boss_aura_time * 5.0) * 0.5 + 0.5
		var is_kaal: bool = (character_name.to_upper() == "KAAL")
		var aura_col: Color = Color(0.95, 0.25, 0.15, 0.4 + pulse * 0.3) if is_kaal else Color(0.15, 0.5, 1.0, 0.4 + pulse * 0.3)
		var core_col: Color = Color(1.0, 0.85, 0.2, 0.7) if is_kaal else Color(0.6, 0.95, 1.0, 0.7)

		# Ground ring
		draw_arc(Vector2(0, BODY_HEIGHT * 0.45), 45.0 + pulse * 10.0, 0.0, TAU, 24, aura_col, 3.5)
		draw_arc(Vector2(0, BODY_HEIGHT * 0.45), 25.0 + pulse * 5.0, 0.0, TAU, 16, core_col, 2.0)

		# Orbiting dimensional wisps
		for i in range(4):
			var angle: float = boss_aura_time * 2.5 + float(i) * (PI * 0.5)
			var wisp_pos := Vector2(cos(angle) * 38.0, sin(angle * 1.5) * 55.0)
			draw_circle(wisp_pos, 4.0 + pulse * 3.0, aura_col)
			draw_circle(wisp_pos, 2.0, core_col)

	# Debug hurtbox and attack hitboxes (Hidden by default; toggleable with F3)
	if show_hitboxes:
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

		# Draw attack hitbox only during active frames
		if combat_component.is_attack_active():
			var hitbox: Rect2 = combat_component.get_attack_hitbox()
			hitbox.position -= global_position

			var box_col: Color = Color(1.0, 0.1, 0.1, 0.45)
			if combat_component.attack_kind == "special":
				box_col = Color(1.0, 0.6, 0.1, 0.45)
			elif combat_component.attack_kind == "ultimate":
				box_col = Color(1.0, 0.9, 0.1, 0.55)

			draw_rect(hitbox, box_col, true)
			draw_rect(hitbox, Color.RED if combat_component.attack_kind != "ultimate" else Color.GOLD, false, 2.0)


func update_animation() -> void:
	if animated_sprite == null or defeated:
		return

	# Attacks have priority
	if combat_component.attack_kind != "":
		return

	# Blocking has priority over hit reaction
	if blocking and is_on_floor():
		if animated_sprite.animation != "block":
			animated_sprite.play("block")
			animated_sprite.set_frame_and_progress(1, 0.0)
		animated_sprite.pause()
		return

	# Finish unblocked hit reaction
	if animated_sprite.animation == "hit_reaction" and animated_sprite.is_playing():
		return

	# Jump
	if not is_on_floor():
		if animated_sprite.animation != "jump":
			animated_sprite.play("jump")
		return

	# Walk or idle
	if abs(velocity.x) > 10.0:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")


func update_facing_visual() -> void:
	if animated_sprite != null:
		animated_sprite.flip_h = facing < 0.0
