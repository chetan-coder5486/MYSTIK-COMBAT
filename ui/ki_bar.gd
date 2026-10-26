class_name KiBar
extends Control

@export var player_number: int = 1
@export var character_name: String = "KAAL":
	set(val):
		character_name = val
		queue_redraw()

@export var mirrored: bool = false:
	set(val):
		mirrored = val
		queue_redraw()

var current_ki: float = 0.0
var max_ki: float = 100.0
var display_ki: float = 0.0
var pulse_time: float = 0.0
var shimmer_offset: float = 0.0

# Neutral Yin-Yang inspired frame colors
const FRAME_BG := Color(0.06, 0.07, 0.09, 0.95)
const FRAME_BORDER := Color(0.38, 0.40, 0.46, 1.0)
const FRAME_HIGHLIGHT := Color(0.75, 0.78, 0.84, 0.8)
const FRAME_INNER_SHADOW := Color(0.02, 0.02, 0.03, 0.9)
const NOTCH_INACTIVE := Color(0.3, 0.32, 0.38, 0.6)
const NOTCH_ACTIVE := Color(1.0, 0.95, 0.7, 0.95)

# Character specific energy palettes
# KAAL: Red and Gold
const KAAL_PRIMARY := Color(0.92, 0.16, 0.10, 1.0)
const KAAL_SECONDARY := Color(1.0, 0.80, 0.20, 1.0)
const KAAL_GLOW := Color(1.0, 0.40, 0.15, 0.45)

# NEX: Blue and Cyan
const NEX_PRIMARY := Color(0.10, 0.42, 0.95, 1.0)
const NEX_SECONDARY := Color(0.20, 0.95, 1.0, 1.0)
const NEX_GLOW := Color(0.20, 0.75, 1.0, 0.45)


func _ready() -> void:
	custom_minimum_size = Vector2(370, 22)
	size = custom_minimum_size


func set_ki(current: float, maximum: float) -> void:
	current_ki = clampf(current, 0.0, maximum)
	max_ki = maxf(1.0, maximum)


func _process(delta: float) -> void:
	pulse_time += delta
	shimmer_offset = fmod(shimmer_offset + delta * 120.0, maxf(1.0, size.x))
	
	# Smooth lerp to actual ki
	if abs(display_ki - current_ki) > 0.05:
		display_ki = lerpf(display_ki, current_ki, delta * 12.0)
		queue_redraw()
	elif display_ki != current_ki:
		display_ki = current_ki
		queue_redraw()
	else:
		# If Ki is full or pulsing, continuously redraw for glow animations
		if current_ki >= 40.0:
			queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var is_kaal: bool = (character_name.to_upper() == "KAAL")
	
	var primary_color: Color = KAAL_PRIMARY if is_kaal else NEX_PRIMARY
	var secondary_color: Color = KAAL_SECONDARY if is_kaal else NEX_SECONDARY
	var glow_color: Color = KAAL_GLOW if is_kaal else NEX_GLOW

	# Outer glow if special/ultimate ready
	if current_ki >= 100.0:
		var ultimate_pulse: float = 0.5 + 0.5 * sin(pulse_time * 8.0)
		var glow_rect := Rect2(-3, -3, w + 6, h + 6)
		draw_rect(glow_rect, Color(secondary_color.r, secondary_color.g, secondary_color.b, 0.3 * ultimate_pulse), false, 2.0)
		draw_rect(Rect2(-1, -1, w + 2, h + 2), Color(primary_color.r, primary_color.g, primary_color.b, 0.5 * ultimate_pulse), false, 1.5)
	elif current_ki >= 40.0:
		var special_pulse: float = 0.5 + 0.5 * sin(pulse_time * 4.0)
		draw_rect(Rect2(-1, -1, w + 2, h + 2), Color(secondary_color.r, secondary_color.g, secondary_color.b, 0.25 * special_pulse), false, 1.0)

	# 1. Base outer frame (Neutral slate / iron)
	var frame_rect := Rect2(0, 0, w, h)
	draw_rect(frame_rect, FRAME_BG, true)
	draw_rect(frame_rect, FRAME_BORDER, false, 1.5)
	
	# Top / inner metallic highlight line
	draw_line(Vector2(1, 1), Vector2(w - 1, 1), FRAME_HIGHLIGHT, 1.0)
	draw_line(Vector2(1, 1), Vector2(1, h - 1), FRAME_HIGHLIGHT, 1.0)
	
	# Yin-yang medallion dimensions
	var disc_radius: float = (h - 2.0) * 0.5
	var disc_center_x: float = disc_radius + 2.0 if not mirrored else w - disc_radius - 2.0
	var disc_center := Vector2(disc_center_x, h * 0.5)

	# Bar fill area bounds
	var bar_margin_left: float = (disc_radius * 2.0 + 5.0) if not mirrored else 4.0
	var bar_margin_right: float = (w - 4.0) if not mirrored else (w - disc_radius * 2.0 - 5.0)
	var bar_w: float = bar_margin_right - bar_margin_left
	var bar_h: float = h - 6.0
	var bar_y: float = 3.0

	# 2. Inner track background (recessed groove)
	var track_rect := Rect2(bar_margin_left, bar_y, bar_w, bar_h)
	draw_rect(track_rect, FRAME_INNER_SHADOW, true)
	draw_rect(track_rect, Color(0.15, 0.16, 0.20, 0.8), false, 1.0)

	# 3. Energy Fill
	var fill_ratio: float = clampf(display_ki / max_ki, 0.0, 1.0)
	if fill_ratio > 0.0:
		var current_fill_w: float = bar_w * fill_ratio
		var fill_x: float = bar_margin_left if not mirrored else (bar_margin_right - current_fill_w)
		var fill_rect := Rect2(fill_x, bar_y + 1, current_fill_w, bar_h - 2)

		# Horizontal gradient slices for rich aesthetic
		var steps: int = int(ceil(current_fill_w / 4.0))
		steps = maxi(1, steps)
		var step_w: float = current_fill_w / float(steps)

		for i in range(steps):
			var t: float = float(i) / float(steps)
			if mirrored:
				t = 1.0 - t
			var slice_color: Color = primary_color.lerp(secondary_color, t)
			
			# Add shimmer wave
			var slice_x_world: float = fill_x + float(i) * step_w
			var dist_to_shimmer: float = abs(slice_x_world - shimmer_offset)
			if dist_to_shimmer < 25.0:
				var shimmer_boost: float = (1.0 - dist_to_shimmer / 25.0) * 0.35
				slice_color = slice_color.lerp(Color.WHITE, shimmer_boost)

			draw_rect(Rect2(fill_x + float(i) * step_w, bar_y + 1, step_w + 0.5, bar_h - 2), slice_color, true)

		# Inner top reflection on the fill
		draw_line(
			Vector2(fill_x, bar_y + 2),
			Vector2(fill_x + current_fill_w, bar_y + 2),
			Color(1.0, 1.0, 1.0, 0.45),
			1.0
		)

	# 4. Special Attack Threshold Notch at 40%
	var notch_ratio: float = 40.0 / 100.0
	var notch_x: float = (bar_margin_left + bar_w * notch_ratio) if not mirrored else (bar_margin_right - bar_w * notch_ratio)
	var notch_active: bool = current_ki >= 40.0
	var notch_col: Color = NOTCH_ACTIVE if notch_active else NOTCH_INACTIVE
	draw_line(Vector2(notch_x, bar_y - 1), Vector2(notch_x, bar_y + bar_h + 1), notch_col, 1.5)
	
	# Notch diamond indicator
	var diamond_pts := PackedVector2Array([
		Vector2(notch_x, bar_y - 3),
		Vector2(notch_x + 2, bar_y - 1),
		Vector2(notch_x, bar_y + 1),
		Vector2(notch_x - 2, bar_y - 1)
	])
	draw_colored_polygon(diamond_pts, notch_col)

	# 5. Neutral Yin-Yang Medallion (Taijitu)
	_draw_yin_yang(disc_center, disc_radius - 1.0)

	# 6. Stylized Labels & Key Hints
	var font := ThemeDB.fallback_font
	var font_size: int = 11
	
	var ki_val_text := "KI %d" % int(round(display_ki))
	var status_text := ""
	var status_color := Color(0.85, 0.85, 0.85, 0.8)

	if current_ki >= 100.0:
		status_text = "ULTIMATE READY [E]" if player_number == 1 else "ULTIMATE READY [ENTER]"
		var flash: float = 0.5 + 0.5 * sin(pulse_time * 10.0)
		status_color = secondary_color.lerp(Color.WHITE, flash)
	elif current_ki >= 40.0:
		status_text = "SPECIAL [Q]" if player_number == 1 else "SPECIAL [R-SHIFT]"
		status_color = secondary_color

	var text_y: float = bar_y + bar_h - 2.5
	if not mirrored:
		draw_string(font, Vector2(bar_margin_left + 6, text_y), ki_val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.9))
		if status_text != "":
			draw_string(font, Vector2(bar_margin_right - 140, text_y), status_text, HORIZONTAL_ALIGNMENT_RIGHT, 135, font_size, status_color)
	else:
		draw_string(font, Vector2(bar_margin_right - 42, text_y), ki_val_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size, Color(1, 1, 1, 0.9))
		if status_text != "":
			draw_string(font, Vector2(bar_margin_left + 6, text_y), status_text, HORIZONTAL_ALIGNMENT_LEFT, 135, font_size, status_color)


func _draw_yin_yang(center: Vector2, r: float) -> void:
	# Outer metallic ring
	draw_circle(center, r + 1.0, Color(0.3, 0.32, 0.38, 1.0))
	draw_circle(center, r, Color(0.1, 0.1, 0.12, 1.0))

	# Procedural Yin-Yang:
	# White half (top/right or right) and Dark half (left)
	var segments: int = 24
	var white_col := Color(0.92, 0.93, 0.95, 1.0)
	var black_col := Color(0.08, 0.08, 0.10, 1.0)

	# Full black circle base
	draw_circle(center, r - 1.0, black_col)

	# White half-circle (angle -PI/2 to PI/2)
	var half_poly := PackedVector2Array()
	half_poly.append(center)
	for i in range(segments + 1):
		var angle: float = -PI * 0.5 + PI * float(i) / float(segments)
		half_poly.append(center + Vector2(cos(angle), sin(angle)) * (r - 1.0))
	draw_colored_polygon(half_poly, white_col)

	# Top inner circle (white) centered at center + Vector2(0, -r/2)
	var r_inner: float = (r - 1.0) * 0.5
	var top_center := center + Vector2(0, -r_inner)
	draw_circle(top_center, r_inner, white_col)

	# Bottom inner circle (black) centered at center + Vector2(0, r/2)
	var bot_center := center + Vector2(0, r_inner)
	draw_circle(bot_center, r_inner, black_col)

	# Small contrasting dots (eye of yin and eye of yang)
	var dot_radius: float = r_inner * 0.32
	draw_circle(top_center, dot_radius, black_col)
	draw_circle(bot_center, dot_radius, white_col)

	# Outer rim highlight
	draw_arc(center, r, 0, TAU, 32, FRAME_HIGHLIGHT, 1.0)
