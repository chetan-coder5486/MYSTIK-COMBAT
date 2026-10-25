class_name FighterPanel
extends VBoxContainer
## Large per-player preview: tag, name, tagline, portrait and ready state.
## The portrait is the bottom-most art so the fighter's feet can land on the
## stage ring painted into the background.
## Builds its own children so the scene file only positions it.

@export_range(0, 1) var slot: int = 0
@export var tag_text: String = "PLAYER 1"
## Portraits are drawn facing right; flip player 2's so the fighters face each other.
@export var flip_portrait: bool = false

const TAG_SIZE: int = 26
const NAME_SIZE: int = 72
const TAGLINE_SIZE: int = 22
const STATE_SIZE: int = 28
const DIM_TINT: Color = Color(0.78, 0.78, 0.86)

var _tag: Label
var _portrait: TextureRect
var _accent_line: ColorRect
var _name: Label
var _tagline: Label
var _state: Label
var _current: CharacterData
var _tween: Tween


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var slot_color: Color = CharacterCard.SLOT_COLORS[slot]

	_tag = _make_label(TAG_SIZE, slot_color)
	_tag.text = tag_text
	add_child(_tag)

	_name = _make_label(NAME_SIZE, Color.WHITE)
	_name.add_theme_constant_override("outline_size", 8)
	_name.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	add_child(_name)

	_tagline = _make_label(TAGLINE_SIZE, Color(0.8, 0.82, 0.9))
	add_child(_tagline)

	_accent_line = ColorRect.new()
	_accent_line.custom_minimum_size = Vector2(0.0, 4.0)
	_accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_accent_line)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.flip_h = flip_portrait
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.resized.connect(func() -> void: _portrait.pivot_offset = _portrait.size * 0.5)
	add_child(_portrait)

	_state = _make_label(STATE_SIZE, slot_color)
	add_child(_state)
	set_locked(false)


## Swaps the displayed fighter. Does nothing if it is already showing `data`.
func show_character(data: CharacterData) -> void:
	if data == _current:
		return
	_current = data
	_portrait.texture = data.portrait
	_name.text = data.display_name.to_upper()
	_tagline.text = data.tagline
	_accent_line.color = data.accent_color

	_kill_tween()
	_portrait.modulate.a = 0.0
	_portrait.scale = Vector2(0.94, 0.94)
	_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_portrait, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_portrait, "scale", Vector2.ONE, 0.22)


func set_locked(locked: bool) -> void:
	_state.text = "READY" if locked else "SELECTING"
	var tint: Color = Color.WHITE if locked else DIM_TINT
	_portrait.modulate = Color(tint.r, tint.g, tint.b, _portrait.modulate.a)
	if locked and _current != null:
		_kill_tween()
		_portrait.scale = Vector2(1.05, 1.05)
		_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_tween.tween_property(_portrait, "scale", Vector2.ONE, 0.25)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
