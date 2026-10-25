
extends Node2D

@export var lifetime: float = 0.18

var effect_kind: String = "light"
var elapsed: float = 0.0


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

	match effect_kind:
		"block":
			radius = 20.0
			color = Color(0.2, 0.65, 1.0, fade)
		"heavy":
			radius = 24.0
			color = Color(1.0, 0.2, 0.05, fade)
		_:
			radius = 15.0
			color = Color(1.0, 0.85, 0.15, fade)

	var current_radius: float = radius * (0.5 + progress)

	# Central impact flash.
	draw_circle(
		Vector2.ZERO,
		current_radius * 0.45,
		Color(1.0, 1.0, 0.85, fade)
	)

	# Eight outward impact rays.
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0 + progress * 0.4
		var direction := Vector2(cos(angle), sin(angle))

		var inner_point: Vector2 = direction * current_radius * 0.45
		var outer_point: Vector2 = direction * current_radius

		draw_line(
			inner_point,
			outer_point,
			color,
			3.0 if effect_kind == "heavy" else 2.0
		)
