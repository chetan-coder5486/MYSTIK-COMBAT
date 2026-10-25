class_name CharacterCard
extends Control
## One roster tile. Draws its own art, name bar, per-player cursor frames and
## lock chips, so the scene needs no per-card child nodes.

## Emitted on mouse click. Left button = player 1, right button = player 2.
signal activated(index: int, mouse_button: int)

const SLOT_COLORS: Array[Color] = [Color(1.0, 0.25, 0.20), Color(0.25, 0.62, 1.0)]
const SLOT_TAGS: Array[String] = ["P1", "P2"]
const CARD_SIZE: Vector2 = Vector2(168.0, 208.0)
const NAME_BAR_HEIGHT: float = 40.0
const ART_PADDING: float = 8.0
const NAME_FONT_SIZE: int = 22
const CHIP_FONT_SIZE: int = 16

var index: int = -1
var data: CharacterData

var _cursor: Array[bool] = [false, false]
var _locked: Array[bool] = [false, false]
var _hovered: bool = false
## Animated 1.0 -> 0.45 so an un-locked cursor frame "breathes".
var pulse: float = 1.0:
	set(value):
		pulse = value
		queue_redraw()


func setup(p_index: int, p_data: CharacterData) -> void:
	index = p_index
	data = p_data
	queue_redraw()


func set_cursor(slot: int, on: bool) -> void:
	if _cursor[slot] != on:
		_cursor[slot] = on
		queue_redraw()


func set_locked(slot: int, on: bool) -> void:
	if _locked[slot] != on:
		_locked[slot] = on
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	var breathe := create_tween().set_loops()
	breathe.tween_property(self, "pulse", 0.45, 0.45).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(self, "pulse", 1.0, 0.45).set_trans(Tween.TRANS_SINE)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and (
		click.button_index == MOUSE_BUTTON_LEFT or click.button_index == MOUSE_BUTTON_RIGHT
	):
		activated.emit(index, click.button_index)
		accept_event()


func _set_hovered(value: bool) -> void:
	_hovered = value
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var background := Color(0.05, 0.06, 0.09, 0.86)
	draw_rect(rect, background.lightened(0.12) if _hovered else background)
	if data == null:
		return

	var art_area := Rect2(
		ART_PADDING,
		ART_PADDING,
		size.x - ART_PADDING * 2.0,
		size.y - NAME_BAR_HEIGHT - ART_PADDING * 2.0
	)
	if data.portrait:
		draw_texture_rect(data.portrait, _fit(data.portrait.get_size(), art_area), false)

	var bar_top := size.y - NAME_BAR_HEIGHT
	draw_rect(Rect2(0.0, bar_top - 3.0, size.x, 3.0), data.accent_color)
	draw_rect(Rect2(0.0, bar_top, size.x, NAME_BAR_HEIGHT), Color(0.0, 0.0, 0.0, 0.7))
	_draw_centered_text(data.display_name, bar_top + NAME_BAR_HEIGHT * 0.5, NAME_FONT_SIZE, Color.WHITE)

	# Cursor frames: P1 outermost, P2 inset, so two cursors on one card stay readable.
	for slot in SLOT_COLORS.size():
		if not _cursor[slot]:
			continue
		var color: Color = SLOT_COLORS[slot]
		color.a = 1.0 if _locked[slot] else pulse
		draw_rect(rect.grow(-(2.0 + slot * 6.0)), color, false, 4.0)

	# Lock chips: P1 top-left, P2 top-right.
	for slot in SLOT_COLORS.size():
		if not (_cursor[slot] and _locked[slot]):
			continue
		var chip := Rect2(10.0 if slot == 0 else size.x - 10.0 - 44.0, 10.0, 44.0, 24.0)
		draw_rect(chip, SLOT_COLORS[slot])
		_draw_centered_text(SLOT_TAGS[slot], chip.position.y + chip.size.y * 0.5, CHIP_FONT_SIZE,
			Color.WHITE, chip.position.x + chip.size.x * 0.5)


func _fit(source: Vector2, area: Rect2) -> Rect2:
	var factor: float = minf(area.size.x / source.x, area.size.y / source.y)
	var fitted: Vector2 = source * factor
	return Rect2(area.position + Vector2((area.size.x - fitted.x) * 0.5, area.size.y - fitted.y), fitted)


func _draw_centered_text(text: String, center_y: float, font_size: int, color: Color, center_x: float = -1.0) -> void:
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var cx: float = size.x * 0.5 if center_x < 0.0 else center_x
	var baseline: float = center_y + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.5
	draw_string(font, Vector2(cx - width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
