class_name EnergyEffect
extends Node2D

@export var character_name: String = "KAAL"
@export var facing: float = 1.0
@export var speed: float = 650.0
@export var damage: float = 24.0
@export var lifetime: float = 0.9
@export var arena_left: float = 0.0
@export var arena_right: float = 1152.0
@export var is_ultimate: bool = false

var attacker: CharacterBody2D
var has_hit: bool = false
var elapsed: float = 0.0
var dissipating: bool = false
var dissipate_time: float = 0.0

const HIT_EFFECT_SCENE: PackedScene = preload("res://scenes/hit_effect.tscn")

# KAAL colors
const KAAL_PRIMARY := Color(0.95, 0.20, 0.10)
const KAAL_SECONDARY := Color(1.0, 0.84, 0.18)
const KAAL_CORE := Color(1.0, 0.96, 0.85)

# NEX colors
const NEX_PRIMARY := Color(0.12, 0.45, 1.0)
const NEX_SECONDARY := Color(0.20, 0.95, 1.0)
const NEX_CORE := Color(0.85, 0.98, 1.0)

var trail_particles: Array[Dictionary] = []


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	elapsed += delta
	
	# Update existing trail particles
	var surviving_particles: Array[Dictionary] = []
	for p in trail_particles:
		p.life -= delta
		p.pos += p.vel * delta
		if p.life > 0.0:
			surviving_particles.append(p)
	trail_particles = surviving_particles

	if dissipating:
		dissipate_time += delta
		if dissipate_time >= 0.22:
			queue_free()
			return
		queue_redraw()
		return

	if elapsed >= lifetime:
		dissipating = true
		return

	# Movement
	var move_dist: float = facing * speed * delta
	global_position.x += move_dist

	# Arena boundary collision check
	if global_position.x < arena_left + 15.0 or global_position.x > arena_right - 15.0:
		dissipating = true
		_spawn_burst_particles(12)
		queue_redraw()
		return

	# Add trail sparks
	_add_trail_sparks()

	# Check opponent hit
	if not has_hit and attacker != null:
		var opponent: CharacterBody2D = attacker.find_opponent()
		if opponent != null and not opponent.defeated:
			var hitbox: Rect2 = get_hitbox()
			if hitbox.intersects(opponent.get_hurtbox()):
				has_hit = true
				dissipating = true
				_spawn_burst_particles(20)
				
				var kind_str := "ultimate" if is_ultimate else "special"
				var landed: bool = opponent.take_damage(damage, facing, kind_str)
				
				if landed:
					attacker.combo_component.register_hit()
					attacker.add_ki(12.0) # +12 for successful hit
					_spawn_hit_feedback(opponent, true)
				else:
					opponent.add_ki(3.0)  # +3 for successful block
					_spawn_hit_feedback(opponent, false)

	queue_redraw()


func get_hitbox() -> Rect2:
	var h_size: float = 65.0 if not is_ultimate else 95.0
	var v_size: float = 60.0 if not is_ultimate else 90.0
	return Rect2(
		global_position.x - h_size * 0.5,
		global_position.y - v_size * 0.5,
		h_size,
		v_size
	)


func _add_trail_sparks() -> void:
	var is_kaal: bool = (character_name.to_upper() == "KAAL")
	var primary: Color = KAAL_PRIMARY if is_kaal else NEX_PRIMARY
	var secondary: Color = KAAL_SECONDARY if is_kaal else NEX_SECONDARY

	for i in range(2):
		trail_particles.append({
			"pos": Vector2(randf_range(-15, 15), randf_range(-25, 25)),
			"vel": Vector2(-facing * randf_range(80, 200), randf_range(-80, 80)),
			"life": randf_range(0.15, 0.35),
			"max_life": 0.35,
			"color": primary if randf() > 0.5 else secondary,
			"size": randf_range(2.0, 4.5)
		})


func _spawn_burst_particles(count: int) -> void:
	var is_kaal: bool = (character_name.to_upper() == "KAAL")
	var primary: Color = KAAL_PRIMARY if is_kaal else NEX_PRIMARY
	var secondary: Color = KAAL_SECONDARY if is_kaal else NEX_SECONDARY

	for i in range(count):
		var angle: float = randf_range(0, TAU)
		var spd: float = randf_range(120, 340)
		trail_particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"life": randf_range(0.2, 0.4),
			"max_life": 0.4,
			"color": primary if randf() > 0.4 else secondary,
			"size": randf_range(3.0, 6.0)
		})


func _spawn_hit_feedback(opponent: CharacterBody2D, landed: bool) -> void:
	var scene_root: Node = null
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.current_scene != null:
			scene_root = tree.current_scene
		elif get_parent() != null:
			scene_root = get_parent()
	elif get_parent() != null:
		scene_root = get_parent()

	if scene_root == null:
		return

	var effect := HIT_EFFECT_SCENE.instantiate()
	effect.effect_kind = ("heavy" if is_ultimate else "special") if landed else "block"
	scene_root.add_child(effect)
	var overlap := get_hitbox().intersection(opponent.get_hurtbox())
	effect.global_position = overlap.get_center() if overlap.size != Vector2.ZERO else opponent.global_position


func _draw() -> void:
	var is_kaal: bool = (character_name.to_upper() == "KAAL")
	var primary: Color = KAAL_PRIMARY if is_kaal else NEX_PRIMARY
	var secondary: Color = KAAL_SECONDARY if is_kaal else NEX_SECONDARY
	var core_col: Color = KAAL_CORE if is_kaal else NEX_CORE
	
	var fade: float = 1.0 - (dissipate_time / 0.22) if dissipating else 1.0

	# 1. Trail particles
	for p in trail_particles:
		var p_ratio: float = p.life / p.max_life
		var p_col: Color = p.color
		p_col.a = p_ratio * fade
		draw_circle(p.pos, p.size * p_ratio, p_col)

	if dissipating:
		# Draw lingering burst
		draw_circle(Vector2.ZERO, 35.0 * (1.0 - fade), Color(secondary.r, secondary.g, secondary.b, fade * 0.6))
		return

	# 2. Main crescent energy wave
	var scale_factor: float = 1.35 if is_ultimate else 1.0
	var wave_w: float = 30.0 * scale_factor
	var wave_h: float = 55.0 * scale_factor
	
	# Draw outer energy glow aura
	var aura_color := Color(primary.r, primary.g, primary.b, 0.35 * fade)
	draw_circle(Vector2(facing * 8.0, 0), wave_h * 0.6, aura_color)

	# Crescent arc points
	var outer_pts := PackedVector2Array()
	var inner_pts := PackedVector2Array()
	var arc_steps: int = 14

	for i in range(arc_steps + 1):
		var t: float = float(i) / float(arc_steps)
		var angle: float = lerpf(-PI * 0.45, PI * 0.45, t)
		var outer_r := Vector2(cos(angle) * wave_w * facing, sin(angle) * wave_h)
		var inner_r := Vector2(cos(angle) * (wave_w * 0.4) * facing - (facing * 10.0), sin(angle) * (wave_h * 0.75))
		outer_pts.append(outer_r)
		inner_pts.append(inner_r)

	var poly_pts := PackedVector2Array()
	for pt in outer_pts:
		poly_pts.append(pt)
	for j in range(inner_pts.size() - 1, -1, -1):
		poly_pts.append(inner_pts[j])

	# Draw outer flame/plasma wing
	draw_colored_polygon(poly_pts, Color(primary.r, primary.g, primary.b, 0.85 * fade))

	# Draw inner core flame/plasma
	var core_poly := PackedVector2Array()
	for i in range(arc_steps + 1):
		var t: float = float(i) / float(arc_steps)
		var angle: float = lerpf(-PI * 0.35, PI * 0.35, t)
		core_poly.append(Vector2(cos(angle) * wave_w * 0.75 * facing, sin(angle) * wave_h * 0.65))
	for j in range(arc_steps, -1, -1):
		var t: float = float(j) / float(arc_steps)
		var angle: float = lerpf(-PI * 0.35, PI * 0.35, t)
		core_poly.append(Vector2(cos(angle) * wave_w * 0.25 * facing, sin(angle) * wave_h * 0.45))

	draw_colored_polygon(core_poly, Color(secondary.r, secondary.g, secondary.b, 0.95 * fade))

	# Leading tip hot-point
	draw_circle(Vector2(facing * wave_w, 0), 10.0 * scale_factor, Color(core_col.r, core_col.g, core_col.b, fade))

	# Dragon flame tongues or cyber plasma rays
	for i in range(4):
		var y_off: float = lerpf(-wave_h * 0.6, wave_h * 0.6, float(i) / 3.0)
		var tip_x: float = -facing * randf_range(15.0, 35.0)
		draw_line(
			Vector2(0, y_off),
			Vector2(tip_x, y_off + randf_range(-6, 6)),
			Color(secondary.r, secondary.g, secondary.b, 0.7 * fade),
			2.5 * scale_factor
		)
