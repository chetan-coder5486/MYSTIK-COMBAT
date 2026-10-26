extends Node2D

@export var lifetime: float = 0.22

var effect_kind: String = "light"
var elapsed: float = 0.0


func _ready() -> void:
	if effect_kind == "ultimate":
		lifetime = 0.40
	elif effect_kind == "special":
		lifetime = 0.26


func _process(delta: float) -> void:
	elapsed += delta

	if elapsed >= lifetime:
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	var progress: float = elapsed / lifetime
	var fade: float = 1.0 - progress

	var radius: float
	var color: Color
	var ray_count: int = 8

	match effect_kind:
		"block":
			radius = 22.0
			color = Color(0.2, 0.65, 1.0, fade)
			ray_count = 6
		"heavy":
			radius = 28.0
			color = Color(1.0, 0.25, 0.08, fade)
			ray_count = 10
		"special":
			radius = 34.0
			color = Color(1.0, 0.82, 0.18, fade)
			ray_count = 12
		"ultimate":
			radius = 55.0
			color = Color(1.0, 0.92, 0.35, fade)
			ray_count = 16
		_:
			radius = 16.0
			color = Color(1.0, 0.85, 0.15, fade)

	var current_radius: float = radius * (0.4 + progress * 0.9)

	# Central bright impact flash
	var core_color := Color(1.0, 1.0, 0.95, fade)
	draw_circle(
		Vector2.ZERO,
		current_radius * 0.45,
		core_color
	)
	
	# Secondary glowing ring for special & ultimate
	if effect_kind in ["special", "ultimate"]:
		draw_arc(
			Vector2.ZERO,
			current_radius * 0.75,
			0,
			TAU,
			24,
			Color(color.r, color.g, color.b, fade * 0.8),
			3.0 if effect_kind == "ultimate" else 2.0
		)

	# Outward impact rays
	for i in range(ray_count):
		var angle: float = TAU * float(i) / float(ray_count) + progress * 0.4
		var direction := Vector2(cos(angle), sin(angle))

		var inner_point: Vector2 = direction * current_radius * 0.4
		var outer_point: Vector2 = direction * current_radius

		var ray_width: float = 2.0
		if effect_kind == "heavy":
			ray_width = 3.0
		elif effect_kind == "special":
			ray_width = 3.5
		elif effect_kind == "ultimate":
			ray_width = 4.5

		draw_line(
			inner_point,
			outer_point,
			color,
			ray_width
		)
