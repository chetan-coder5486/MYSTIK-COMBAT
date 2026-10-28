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
var current_move: Dictionary = {}

var fighter: CharacterBody2D


func _ready() -> void:
	fighter = get_parent() as CharacterBody2D


func start_attack(kind: String) -> void:
	if fighter.defeated:
		return

	if has_node("/root/Grimoire"):
		current_move = get_node("/root/Grimoire").get_move(fighter.character_name, kind)
	else:
		current_move = {}

	var ki_cost: float = current_move.get("ki_cost", 0.0) if current_move.size() > 0 else (SPECIAL_KI_COST if kind == "special" else (ULTIMATE_KI_COST if kind == "ultimate" else 0.0))

	# Resource checks for Special and Ultimate
	if ki_cost > 0.0:
		if not fighter.spend_ki(ki_cost):
			return

	attack_kind = kind
	attack_time = 0.0
	attack_has_hit = false
	attack_started.emit(kind)

	# Play matching attack animation scaled to character attack speed
	if fighter.animated_sprite != null:
		var animation_name: String = str(current_move.get("animation", "")) if current_move.size() > 0 else ""
		if animation_name == "":
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
	var dmg_mult: float = fighter.damage_multiplier if "damage_multiplier" in fighter else 1.0
	energy.damage = (get_attack_damage("ultimate") if is_ult else get_attack_damage("special")) * dmg_mult
	if fighter.character_name.to_upper() == "NEX":
		energy.speed = 820.0
	else:
		energy.speed = 620.0
	energy.arena_left = fighter.arena_left
	energy.arena_right = fighter.arena_right
	
	var spawn_x: float = fighter.global_position.x + fighter.facing * (fighter.BODY_WIDTH * 0.5 + 24.0)
	var spawn_y: float = fighter.global_position.y - 12.0
	energy.global_position = Vector2(spawn_x, spawn_y)
	
	var scene_root: Node = _get_effects_parent()
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
			
			var base_dmg: float = get_attack_damage(attack_kind)
			var mult: float = fighter.damage_multiplier if "damage_multiplier" in fighter else 1.0
			var damage: float = base_dmg * mult
			var landed: bool = opponent.take_damage(
				damage,
				fighter.facing,
				attack_kind,
				current_move
			)

			if landed:
				var stop_frames: int = current_move.get("hit_stop_frames", 4) if current_move.size() > 0 else 4
				if has_node("/root/HitStop"):
					get_node("/root/HitStop").trigger(stop_frames)

				var shake: float = current_move.get("screen_shake", 0.0) if current_move.size() > 0 else 0.0
				_apply_screen_shake(shake)

				var ki_gain: float = current_move.get("ki_gain_on_hit", 12.0) if current_move.size() > 0 else 12.0
				fighter.combo_component.register_hit()
				fighter.add_ki(ki_gain)
				spawn_hit_effect(opponent)
			else:
				var ki_gain_block: float = current_move.get("ki_gain_on_block", 3.0) if current_move.size() > 0 else 3.0
				opponent.add_ki(ki_gain_block)
				spawn_block_effect(opponent)

	if attack_time >= startup + active + recovery:
		cancel_attack()

	fighter.queue_redraw()


func get_startup_time(kind: String) -> float:
	var move: Dictionary = current_move if current_move.size() > 0 and attack_kind == kind else (
		get_node("/root/Grimoire").get_move(fighter.character_name, kind) if has_node("/root/Grimoire") else {}
	)
	var base: float = move.get("startup", LIGHT_STARTUP) if move.size() > 0 else LIGHT_STARTUP
	return base / maxf(0.1, attack_speed_scale)


func get_active_time(kind: String) -> float:
	var move: Dictionary = current_move if current_move.size() > 0 and attack_kind == kind else (
		get_node("/root/Grimoire").get_move(fighter.character_name, kind) if has_node("/root/Grimoire") else {}
	)
	var base: float = move.get("active", LIGHT_ACTIVE) if move.size() > 0 else LIGHT_ACTIVE
	return base / maxf(0.1, attack_speed_scale)


func get_recovery_time(kind: String) -> float:
	var move: Dictionary = current_move if current_move.size() > 0 and attack_kind == kind else (
		get_node("/root/Grimoire").get_move(fighter.character_name, kind) if has_node("/root/Grimoire") else {}
	)
	var base: float = move.get("recovery", LIGHT_RECOVERY) if move.size() > 0 else LIGHT_RECOVERY
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
	current_move = {}
	if fighter != null and fighter.animated_sprite != null:
		fighter.animated_sprite.speed_scale = 1.0
	if previous_kind != "":
		attack_ended.emit(previous_kind)
	fighter.queue_redraw()


func get_attack_hitbox() -> Rect2:
	var reach: float = 55.0
	var hit_height: float = 42.0

	if current_move.size() > 0:
		reach = current_move.get("reach", 55.0)
		hit_height = current_move.get("hit_height", 42.0)
	else:
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


func _apply_screen_shake(intensity: float) -> void:
	if intensity <= 0.0:
		return
	var scene_root: Node = _get_effects_parent()
	if scene_root != null and scene_root.has_method("apply_shake"):
		scene_root.apply_shake(intensity)
	elif scene_root != null and "shake_intensity" in scene_root:
		scene_root.shake_intensity = maxf(scene_root.shake_intensity, intensity)


func is_attack_active() -> bool:
	if attack_kind == "":
		return false

	var startup: float = get_startup_time(attack_kind)
	var active: float = get_active_time(attack_kind)

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
	var scene_root: Node = _get_effects_parent()
	if scene_root == null:
		return

	var effect := HIT_EFFECT_SCENE.instantiate()
	effect.effect_kind = attack_kind
	scene_root.add_child(effect)

	var overlap: Rect2 = get_attack_hitbox().intersection(opponent.get_hurtbox())
	effect.global_position = overlap.get_center() if overlap.size != Vector2.ZERO else opponent.global_position


func spawn_block_effect(opponent: CharacterBody2D) -> void:
	var scene_root: Node = _get_effects_parent()
	if scene_root == null:
		return

	var effect := HIT_EFFECT_SCENE.instantiate()
	effect.effect_kind = "block"
	scene_root.add_child(effect)

	var overlap: Rect2 = get_attack_hitbox().intersection(opponent.get_hurtbox())
	effect.global_position = overlap.get_center() if overlap.size != Vector2.ZERO else opponent.global_position
