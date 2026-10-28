extends Node

signal attack_started(kind: String)
signal attack_ended(kind: String)
signal ultimate_requested(fighter: CharacterBody2D)

const LIGHT_STARTUP := 0.10
const LIGHT_ACTIVE := 0.12
const LIGHT_RECOVERY := 0.22
const LIGHT_DAMAGE := 8.0

const HEAVY_STARTUP := 0.24
const HEAVY_ACTIVE := 0.16
const HEAVY_RECOVERY := 0.42
const HEAVY_DAMAGE := 16.0

const SPECIAL_STARTUP := 0.16
const SPECIAL_ACTIVE := 0.18
const SPECIAL_RECOVERY := 0.32
const SPECIAL_DAMAGE := 24.0   # 1.5x normal heavy damage (16.0 * 1.5 = 24.0)
const SPECIAL_KI_COST := 40.0

const ULTIMATE_STARTUP := 0.35
const ULTIMATE_ACTIVE := 0.30
const ULTIMATE_RECOVERY := 0.48
const ULTIMATE_KI_COST := 100.0

# Dynamic character attributes (configured per fighter)
var light_damage: float = 8.0
var heavy_damage: float = 16.0
var special_damage: float = 24.0
var ultimate_damage: float = 48.0
var attack_speed_scale: float = 1.0

const HIT_EFFECT_SCENE: PackedScene = preload("res://scenes/hit_effect.tscn")
const ENERGY_EFFECT_SCENE: PackedScene = preload("res://scenes/energy_effect.tscn")

var attack_kind: String = ""
var attack_time: float = 0.0
var attack_has_hit: bool = false

var fighter: CharacterBody2D


func _ready() -> void:
	fighter = get_parent() as CharacterBody2D


func start_attack(kind: String) -> void:
	if fighter.defeated:
		return

	# Resource checks for Special and Ultimate
	if kind == "special":
		if not fighter.spend_ki(SPECIAL_KI_COST):
			return
	elif kind == "ultimate":
		if not fighter.spend_ki(ULTIMATE_KI_COST):
			return

	attack_kind = kind
	attack_time = 0.0
	attack_has_hit = false
	attack_started.emit(kind)

	# Play matching attack animation scaled to character attack speed
	if fighter.animated_sprite != null:
		var animation_name := ""
		if kind == "light":
			animation_name = "light_attack"
		elif kind in ["heavy", "special", "ultimate"]:
			animation_name = "heavy_attack"

		if (
			animation_name != ""
			and fighter.animated_sprite.sprite_frames != null
			and fighter.animated_sprite.sprite_frames.has_animation(animation_name)
		):
			fighter.animated_sprite.speed_scale = attack_speed_scale
			fighter.animated_sprite.play(animation_name)

	# Special attack launches energy wave projectile
	if kind == "special":
		spawn_energy_wave(false)
	elif kind == "ultimate":
		ultimate_requested.emit(fighter)
		spawn_energy_wave(true)

	fighter.queue_redraw()


func spawn_energy_wave(is_ult: bool) -> void:
	var energy = ENERGY_EFFECT_SCENE.instantiate()
	energy.character_name = fighter.character_name
	energy.facing = fighter.facing
	energy.attacker = fighter
	energy.is_ultimate = is_ult
	energy.damage = get_attack_damage("ultimate") if is_ult else get_attack_damage("special")
	if fighter.character_name.to_upper() == "NEX":
		energy.speed = 820.0
	else:
		energy.speed = 620.0
	energy.arena_left = fighter.arena_left
	energy.arena_right = fighter.arena_right
	
	var spawn_x: float = fighter.global_position.x + fighter.facing * (fighter.BODY_WIDTH * 0.5 + 24.0)
	var spawn_y: float = fighter.global_position.y - 12.0
	energy.global_position = Vector2(spawn_x, spawn_y)
	
	var scene_root := _get_effects_parent()
	if scene_root != null:
		scene_root.add_child(energy)


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

	var startup := get_startup_time(attack_kind)
	var active := get_active_time(attack_kind)
	var recovery := get_recovery_time(attack_kind)

	# Melee hitbox check
	if attack_time >= startup and attack_time < startup + active:
		if not attack_has_hit and get_attack_hitbox().intersects(opponent.get_hurtbox()):
			attack_has_hit = true
			
			var damage := get_attack_damage(attack_kind)
			var landed: bool = opponent.take_damage(
				damage,
				fighter.facing,
				attack_kind
			)

			if landed:
				fighter.combo_component.register_hit()
				fighter.add_ki(12.0) # +12 Ki for a successful hit
				spawn_hit_effect(opponent)
			else:
				opponent.add_ki(3.0)  # +3 Ki for a successful block
				spawn_block_effect(opponent)

	if attack_time >= startup + active + recovery:
		cancel_attack()

	fighter.queue_redraw()


func get_startup_time(kind: String) -> float:
	var base := LIGHT_STARTUP
	match kind:
		"light": base = LIGHT_STARTUP
		"heavy": base = HEAVY_STARTUP
		"special": base = SPECIAL_STARTUP
		"ultimate": base = ULTIMATE_STARTUP
		_: base = LIGHT_STARTUP
	return base / maxf(0.1, attack_speed_scale)


func get_active_time(kind: String) -> float:
	var base := LIGHT_ACTIVE
	match kind:
		"light": base = LIGHT_ACTIVE
		"heavy": base = HEAVY_ACTIVE
		"special": base = SPECIAL_ACTIVE
		"ultimate": base = ULTIMATE_ACTIVE
		_: base = LIGHT_ACTIVE
	return base / maxf(0.1, attack_speed_scale)


func get_recovery_time(kind: String) -> float:
	var base := LIGHT_RECOVERY
	match kind:
		"light": base = LIGHT_RECOVERY
		"heavy": base = HEAVY_RECOVERY
		"special": base = SPECIAL_RECOVERY
		"ultimate": base = ULTIMATE_RECOVERY
		_: base = LIGHT_RECOVERY
	return base / maxf(0.1, attack_speed_scale)


func get_attack_damage(kind: String) -> float:
	match kind:
		"light": return light_damage
		"heavy": return heavy_damage
		"special": return special_damage
		"ultimate": return ultimate_damage
		_: return light_damage


func finish_attack_if_ready() -> void:
	var total_time := (
		get_startup_time(attack_kind)
		+ get_active_time(attack_kind)
		+ get_recovery_time(attack_kind)
	)

	if attack_time >= total_time:
		cancel_attack()


func cancel_attack() -> void:
	var previous_kind := attack_kind
	attack_kind = ""
	attack_time = 0.0
	attack_has_hit = false
	if fighter != null and fighter.animated_sprite != null:
		fighter.animated_sprite.speed_scale = 1.0
	if previous_kind != "":
		attack_ended.emit(previous_kind)
	fighter.queue_redraw()


func get_attack_hitbox() -> Rect2:
	var reach: float = 55.0
	var hit_height: float = 42.0
	
	match attack_kind:
		"heavy":
			reach = 72.0
			hit_height = 54.0
		"special":
			reach = 76.0
			hit_height = 62.0
		"ultimate":
			reach = 90.0
			hit_height = 76.0
		_: # light
			reach = 55.0
			hit_height = 42.0

	var hit_y: float = fighter.global_position.y - 20.0 - hit_height * 0.5
	var hit_x: float
	if fighter.facing > 0.0:
		hit_x = fighter.global_position.x + fighter.BODY_WIDTH * 0.5
	else:
		hit_x = fighter.global_position.x - fighter.BODY_WIDTH * 0.5 - reach

	return Rect2(hit_x, hit_y, reach, hit_height)


func is_attack_active() -> bool:
	if attack_kind == "":
		return false

	var startup := get_startup_time(attack_kind)
	var active := get_active_time(attack_kind)

	return attack_time >= startup and attack_time < startup + active


func _get_effects_parent() -> Node:
	if fighter != null and fighter.is_inside_tree():
		var tree := fighter.get_tree()
		if tree != null and tree.current_scene != null:
			return tree.current_scene
		if fighter.get_parent() != null:
			return fighter.get_parent()
	elif is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.current_scene != null:
			return tree.current_scene
		if get_parent() != null:
			return get_parent()
	return null


func spawn_hit_effect(opponent: CharacterBody2D) -> void:
	var scene_root := _get_effects_parent()
	if scene_root == null:
		return

	var effect := HIT_EFFECT_SCENE.instantiate()
	effect.effect_kind = attack_kind
	scene_root.add_child(effect)

	var overlap: Rect2 = get_attack_hitbox().intersection(opponent.get_hurtbox())
	effect.global_position = overlap.get_center() if overlap.size != Vector2.ZERO else opponent.global_position


func spawn_block_effect(opponent: CharacterBody2D) -> void:
	var scene_root := _get_effects_parent()
	if scene_root == null:
		return

	var effect := HIT_EFFECT_SCENE.instantiate()
	effect.effect_kind = "block"
	scene_root.add_child(effect)

	var overlap: Rect2 = get_attack_hitbox().intersection(opponent.get_hurtbox())
	effect.global_position = overlap.get_center() if overlap.size != Vector2.ZERO else opponent.global_position
