extends Control

const ARENA_BG: Texture2D = preload("res://assets/arena/arena_backdrop.jpg")
const KAAL_PORTRAIT: Texture2D = preload("res://assets/characters/kaal/kaal_portrait.png")
const NEX_PORTRAIT: Texture2D = preload("res://assets/characters/nex/nex_portrait.png")

var _controls_modal: Control = null
var _bg_texture_rect: TextureRect = null
var _title_label: Label = null
var _play_button: Button = null
var _buttons: Array[Button] = []


func _ready() -> void:
	_build_background()

	_build_particles()
	_build_hero_cards()
	_build_center_menu()
	_build_footer()
	_build_controls_modal()

	# Start ambient title breathing tween
	_start_title_pulse()

	# Focus first button for immediate gamepad/keyboard navigation
	if _buttons.size() > 0:
		_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.physical_keycode == KEY_ESCAPE:
			if _controls_modal != null and _controls_modal.visible:
				_toggle_controls_modal(false)
			else:
				get_tree().quit()
		elif event.physical_keycode == KEY_C or event.physical_keycode == KEY_TAB:
			if _controls_modal != null:
				_toggle_controls_modal(!_controls_modal.visible)


# --- 1. Background & Atmosphere ----------------------------------------------

func _build_background() -> void:
	# Base arena texture
	_bg_texture_rect = TextureRect.new()
	_bg_texture_rect.texture = ARENA_BG
	_bg_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_texture_rect.position = Vector2.ZERO
	_bg_texture_rect.size = Vector2(1152, 648)
	_bg_texture_rect.pivot_offset = Vector2(576, 324)
	add_child(_bg_texture_rect)

	# Deep cinematic dark tint
	var tint := ColorRect.new()
	tint.position = Vector2.ZERO
	tint.size = Vector2(1152, 648)
	tint.color = Color(0.04, 0.05, 0.09, 0.82)
	add_child(tint)

	# Radial edge vignette (top and bottom gradient bars)
	var top_vignette := ColorRect.new()
	top_vignette.position = Vector2(0, 0)
	top_vignette.size = Vector2(1152, 90)
	top_vignette.color = Color(0.02, 0.02, 0.05, 0.75)
	add_child(top_vignette)

	var bottom_vignette := ColorRect.new()
	bottom_vignette.position = Vector2(0, 560)
	bottom_vignette.size = Vector2(1152, 88)
	bottom_vignette.color = Color(0.02, 0.02, 0.05, 0.88)
	add_child(bottom_vignette)

	# Subtle breathing zoom on backdrop
	var tween := create_tween().set_loops()
	tween.tween_property(_bg_texture_rect, "scale", Vector2(1.03, 1.03), 8.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_bg_texture_rect, "scale", Vector2(1.0, 1.0), 8.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_particles() -> void:
	var embers := CPUParticles2D.new()
	embers.name = "MenuEmbers"
	embers.amount = 38
	embers.lifetime = 4.2
	embers.preprocess = 2.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(576, 10)
	embers.position = Vector2(576, 640)
	embers.direction = Vector2(0, -1)
	embers.spread = 35.0
	embers.gravity = Vector2(0, -15)
	embers.initial_velocity_min = 20.0
	embers.initial_velocity_max = 60.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 4.5
	embers.color = Color(0.65, 0.4, 1.0, 0.6)
	add_child(embers)


# --- 2. Flank Character Showcase Cards ---------------------------------------

func _build_hero_cards() -> void:
	# KAAL CARD (Left)
	var kaal_panel := _create_character_card(
		Vector2(32, 96),
		Vector2(265, 480),
		KAAL_PORTRAIT,
		"KAAL",
		"DIMENSIONAL BRAWLER",
		Color(1.0, 0.78, 0.2), # Gold
		Color(0.9, 0.35, 0.15), # Crimson/Amber
		"115 HP", 1.0,
		"HIGH (SEISMIC)", 0.95,
		"295 PX/S", 0.65,
		"Ancient martial titan wielding earthshaker shocks and devastating astral strikes."
	)
	add_child(kaal_panel)

	# NEX CARD (Right)
	var nex_panel := _create_character_card(
		Vector2(855, 96),
		Vector2(265, 480),
		NEX_PORTRAIT,
		"NEX",
		"NEON SPEEDSTER",
		Color(0.25, 0.85, 1.0), # Cyan
		Color(0.7, 0.35, 1.0),  # Purple
		"90 HP", 0.75,
		"RAPID (AGILE)", 0.8,
		"420 PX/S", 1.0,
		"Cybernetic ninja harnessing lightning rifts and supersonic aerial blades."
	)
	add_child(nex_panel)


func _create_character_card(
	pos: Vector2,
	card_size: Vector2,
	portrait_texture: Texture2D,
	char_name: String,
	subtitle: String,
	accent_color: Color,
	secondary_color: Color,
	stat_hp: String, stat_hp_ratio: float,
	stat_dmg: String, stat_dmg_ratio: float,
	stat_spd: String, stat_spd_ratio: float,
	lore: String
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = card_size
	panel.size = card_size

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.08, 0.13, 0.88)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = accent_color * Color(1, 1, 1, 0.55)
	box.set_corner_radius_all(12)
	box.shadow_color = accent_color * Color(1, 1, 1, 0.15)
	box.shadow_size = 8
	panel.add_theme_stylebox_override("panel", box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Portrait container with border
	var portrait_box := PanelContainer.new()
	portrait_box.custom_minimum_size = Vector2(237, 185)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	p_style.set_corner_radius_all(8)
	p_style.border_width_left = 1
	p_style.border_width_top = 1
	p_style.border_width_right = 1
	p_style.border_width_bottom = 1
	p_style.border_color = secondary_color * Color(1, 1, 1, 0.4)
	portrait_box.add_theme_stylebox_override("panel", p_style)

	var p_texture := TextureRect.new()
	p_texture.texture = portrait_texture
	p_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_box.add_child(p_texture)
	vbox.add_child(portrait_box)

	# Name Label
	var name_lbl := Label.new()
	name_lbl.text = char_name
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", accent_color)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# Subtitle Tag
	var sub_lbl := Label.new()
	sub_lbl.text = "[ %s ]" % subtitle
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 0.75))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_lbl)

	# Divider line
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = accent_color * Color(1, 1, 1, 0.3)
	vbox.add_child(div)

	# Stat Bars
	vbox.add_child(_create_stat_row("HEALTH", stat_hp, stat_hp_ratio, accent_color))
	vbox.add_child(_create_stat_row("DAMAGE", stat_dmg, stat_dmg_ratio, secondary_color))
	vbox.add_child(_create_stat_row("SPEED", stat_spd, stat_spd_ratio, accent_color))

	# Lore Description
	var lore_lbl := Label.new()
	lore_lbl.text = lore
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_lbl.add_theme_font_size_override("font_size", 10)
	lore_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.7))
	lore_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lore_lbl)

	return panel


func _create_stat_row(label: String, val_text: String, ratio: float, color: Color) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var text_row := HBoxContainer.new()
	var l_lbl := Label.new()
	l_lbl.text = label
	l_lbl.add_theme_font_size_override("font_size", 10)
	l_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	text_row.add_child(l_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_row.add_child(spacer)

	var v_lbl := Label.new()
	v_lbl.text = val_text
	v_lbl.add_theme_font_size_override("font_size", 10)
	v_lbl.add_theme_color_override("font_color", color)
	text_row.add_child(v_lbl)
	row.add_child(text_row)

	# Progress bar track
	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(0, 5)
	track.color = Color(0.12, 0.14, 0.22, 0.8)

	var fill := ColorRect.new()
	fill.position = Vector2.ZERO
	fill.size = Vector2(237 * clampf(ratio, 0.0, 1.0), 5)
	fill.color = color
	track.add_child(fill)
	row.add_child(track)

	return row


# --- 3. Center Command Menu (Title & Buttons) --------------------------------

func _build_center_menu() -> void:
	var center := VBoxContainer.new()
	center.position = Vector2(325, 45)
	center.custom_minimum_size = Vector2(502, 530)
	center.size = Vector2(502, 530)
	center.add_theme_constant_override("separation", 14)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	# Super-title badge
	var badge := Label.new()
	badge.text = "✦  THE DIMENSIONAL CLASH  ✦"
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 0.9))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(badge)

	# Main Title
	_title_label = Label.new()
	_title_label.text = "MYSTIK COMBAT"
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.5, 0.1, 0.8, 0.8))
	_title_label.add_theme_constant_override("shadow_offset_x", 0)
	_title_label.add_theme_constant_override("shadow_offset_y", 4)
	_title_label.add_theme_constant_override("shadow_outline_size", 10)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.pivot_offset = Vector2(251, 30)
	center.add_child(_title_label)

	# Subtitle Tagline
	var tagline := Label.new()
	tagline.text = "OFFLINE LOCAL 2-PLAYER MARTIAL SHOWDOWN"
	tagline.add_theme_font_size_override("font_size", 12)
	tagline.add_theme_color_override("font_color", Color(0.65, 0.8, 0.95, 0.75))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(tagline)

	# Glowing Energy Divider
	var div_container := CenterContainer.new()
	div_container.custom_minimum_size = Vector2(0, 16)
	var div_line := ColorRect.new()
	div_line.custom_minimum_size = Vector2(340, 2)
	div_line.color = Color(0.4, 0.8, 1.0, 0.5)
	div_container.add_child(div_line)
	center.add_child(div_container)

	# Spacer
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	center.add_child(sp)

	# Action Buttons
	var btn_box := VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 12)
	center.add_child(btn_box)

	# 1. PLAY BATTLE
	_play_button = _create_styled_button(
		"⚔  ENTER BATTLE  (CHARACTER SELECT)",
		54,
		Color(0.2, 0.85, 1.0),
		Color(0.85, 0.25, 0.95),
		true
	)
	_play_button.pressed.connect(_on_play_pressed)
	btn_box.add_child(_play_button)
	_buttons.append(_play_button)

	# 2. QUICK MATCH
	var quick_btn := _create_styled_button(
		"⚡  QUICK DUEL  (KAAL VS NEX)",
		46,
		Color(1.0, 0.75, 0.2),
		Color(0.9, 0.35, 0.15),
		false
	)
	quick_btn.pressed.connect(_on_quick_fight_pressed)
	btn_box.add_child(quick_btn)
	_buttons.append(quick_btn)

	# 3. OPPONENT MODE TOGGLE (ADAPTIVE AI / LOCAL 2-PLAYER)
	var gs = get_node_or_null("/root/GameSettings")
	var is_ai_init: bool = gs.vs_ai if gs else true
	var mode_btn: Button = _create_styled_button(
		"🤖  MODE: VS ADAPTIVE AI" if is_ai_init else "👥  MODE: LOCAL 2-PLAYER",
		46,
		Color(0.85, 0.45, 1.0) if is_ai_init else Color(0.3, 0.8, 1.0),
		Color(0.5, 0.2, 0.8) if is_ai_init else Color(0.1, 0.4, 0.8),
		false
	)
	mode_btn.pressed.connect(func():
		if gs:
			gs.vs_ai = not gs.vs_ai
			var ai_now: bool = gs.vs_ai
			mode_btn.text = "🤖  MODE: VS ADAPTIVE AI" if ai_now else "👥  MODE: LOCAL 2-PLAYER"
	)
	btn_box.add_child(mode_btn)
	_buttons.append(mode_btn)

	# 4. HOW TO PLAY / CONTROLS
	var controls_btn := _create_styled_button(
		"🎮  HOW TO PLAY  &  CONTROLS",
		46,
		Color(0.5, 0.75, 1.0),
		Color(0.2, 0.5, 0.9),
		false
	)
	controls_btn.pressed.connect(func(): _toggle_controls_modal(true))
	btn_box.add_child(controls_btn)
	_buttons.append(controls_btn)

	# 4. QUIT GAME
	var quit_btn := _create_styled_button(
		"✕  QUIT GAME",
		42,
		Color(0.9, 0.3, 0.35),
		Color(0.6, 0.15, 0.2),
		false
	)
	quit_btn.pressed.connect(_on_quit_pressed)
	btn_box.add_child(quit_btn)
	_buttons.append(quit_btn)


func _create_styled_button(
	text: String,
	height: int,
	accent: Color,
	secondary: Color,
	is_primary: bool
) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(440, height)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pivot_offset = Vector2(220, height / 2.0)
	btn.add_theme_font_size_override("font_size", 15 if not is_primary else 16)

	# Style Normal
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.08, 0.1, 0.16, 0.88 if not is_primary else 0.95)
	norm.border_width_left = 2
	norm.border_width_top = 2
	norm.border_width_right = 2
	norm.border_width_bottom = 2
	norm.border_color = accent * Color(1, 1, 1, 0.5 if not is_primary else 0.85)
	norm.set_corner_radius_all(8)
	if is_primary:
		norm.shadow_color = accent * Color(1, 1, 1, 0.25)
		norm.shadow_size = 6
	btn.add_theme_stylebox_override("normal", norm)

	# Style Hover
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.12, 0.15, 0.24, 0.96)
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.border_color = accent
	hover.set_corner_radius_all(8)
	hover.shadow_color = accent * Color(1, 1, 1, 0.4)
	hover.shadow_size = 10
	btn.add_theme_stylebox_override("hover", hover)

	# Style Pressed
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = secondary * Color(1, 1, 1, 0.35)
	pressed.border_width_left = 2
	pressed.border_width_top = 2
	pressed.border_width_right = 2
	pressed.border_width_bottom = 2
	pressed.border_color = accent
	pressed.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("pressed", pressed)

	# Style Focus
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.12, 0.15, 0.24, 0.96)
	focus.border_width_left = 2
	focus.border_width_top = 2
	focus.border_width_right = 2
	focus.border_width_bottom = 2
	focus.border_color = Color.WHITE
	focus.set_corner_radius_all(8)
	focus.shadow_color = accent * Color(1, 1, 1, 0.5)
	focus.shadow_size = 12
	btn.add_theme_stylebox_override("focus", focus)

	# Hover micro-animation
	btn.mouse_entered.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.035, 1.035), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

	return btn


func _start_title_pulse() -> void:
	if _title_label == null:
		return
	var tw := create_tween().set_loops()
	tw.tween_property(_title_label, "scale", Vector2(1.025, 1.025), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_title_label, "scale", Vector2(1.0, 1.0), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- 4. Interactive Controls Modal -------------------------------------------

func _build_controls_modal() -> void:
	_controls_modal = Control.new()
	_controls_modal.position = Vector2.ZERO
	_controls_modal.size = Vector2(1152, 648)
	_controls_modal.visible = false
	_controls_modal.z_index = 50
	add_child(_controls_modal)

	# Fullscreen dark overlay
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1152, 648)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.88)
	_controls_modal.add_child(backdrop)

	# Modal dialog box
	var dialog := PanelContainer.new()
	dialog.custom_minimum_size = Vector2(820, 520)
	dialog.size = Vector2(820, 520)
	dialog.position = Vector2(166, 64)

	var d_style := StyleBoxFlat.new()
	d_style.bg_color = Color(0.08, 0.09, 0.14, 0.98)
	d_style.border_width_left = 2
	d_style.border_width_top = 2
	d_style.border_width_right = 2
	d_style.border_width_bottom = 2
	d_style.border_color = Color(0.3, 0.75, 1.0, 0.85)
	d_style.set_corner_radius_all(14)
	d_style.shadow_color = Color(0.1, 0.5, 0.9, 0.25)
	d_style.shadow_size = 18
	dialog.add_theme_stylebox_override("panel", d_style)
	_controls_modal.add_child(dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Modal Header
	var header := HBoxContainer.new()
	var h_title := Label.new()
	h_title.text = "⚔  HOW TO PLAY & CONTROLS GUIDE"
	h_title.add_theme_font_size_override("font_size", 22)
	h_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	header.add_child(h_title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)

	var close_btn := Button.new()
	close_btn.text = "✕ CLOSE [ESC]"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(func(): _toggle_controls_modal(false))
	header.add_child(close_btn)
	vbox.add_child(header)

	var h_div := ColorRect.new()
	h_div.custom_minimum_size = Vector2(0, 1)
	h_div.color = Color(0.3, 0.7, 1.0, 0.3)
	vbox.add_child(h_div)

	# Dual Columns for Player 1 & Player 2
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(cols)

	# P1 Column
	var p1_box := _build_player_control_column(
		"PLAYER 1 (KAAL / NEX)",
		Color(1.0, 0.8, 0.25),
		[
			{"action": "Movement", "keys": "W (Jump)  •  A (Left)  •  D (Right)"},
			{"action": "Defense", "keys": "S (Block - 65% Dmg Reduction)"},
			{"action": "Light Attack", "keys": "F (Fast Combo Opener)"},
			{"action": "Heavy Attack", "keys": "G (Heavy Knockback)"},
			{"action": "Mystic Special", "keys": "Q (Requires 40 Ki)"},
			{"action": "Cinematic Ultimate", "keys": "E (Requires 100 Ki)"},
			{"action": "Gamepad 1", "keys": "Left Stick / D-Pad + Face Buttons"},
		]
	)
	p1_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(p1_box)

	# P2 Column
	var p2_box := _build_player_control_column(
		"PLAYER 2 (NEX / KAAL)",
		Color(0.25, 0.85, 1.0),
		[
			{"action": "Movement", "keys": "↑ or Num 8 (Jump)  •  ← or Num 4  •  → or Num 6"},
			{"action": "Defense", "keys": "↓ or Num 2 (Block - 65% Dmg Reduction)"},
			{"action": "Light Attack", "keys": "/ or Num 1 (Fast Combo Opener)"},
			{"action": "Heavy Attack", "keys": ". or Num 3 (Heavy Knockback)"},
			{"action": "Mystic Special", "keys": "Right Shift or Num 7 (40 Ki)"},
			{"action": "Cinematic Ultimate", "keys": "Enter or Num 9 (100 Ki)"},
			{"action": "Gamepad 2", "keys": "Full Native Gamepad 2 Support"},
		]
	)
	p2_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(p2_box)

	# Rules & Tip Box
	var tip_panel := PanelContainer.new()
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.12, 0.15, 0.24, 0.7)
	t_style.border_width_left = 1
	t_style.border_width_top = 1
	t_style.border_width_right = 1
	t_style.border_width_bottom = 1
	t_style.border_color = Color(1.0, 0.8, 0.2, 0.45)
	t_style.set_corner_radius_all(6)
	tip_panel.add_theme_stylebox_override("panel", t_style)

	var t_margin := MarginContainer.new()
	t_margin.add_theme_constant_override("margin_left", 12)
	t_margin.add_theme_constant_override("margin_top", 8)
	t_margin.add_theme_constant_override("margin_right", 12)
	t_margin.add_theme_constant_override("margin_bottom", 8)
	tip_panel.add_child(t_margin)

	var tip_lbl := Label.new()
	tip_lbl.text = "★ TIP: Best of 3 Knockout duel. Fill Ki by striking or being hit. In-game engineering tools: [F1] Grimoire Frame Data Inspector • [F2] Adaptive AI Brain Overlay • [F5] Live JSON Hot-Reload!"
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_lbl.add_theme_font_size_override("font_size", 11)
	tip_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.65))
	t_margin.add_child(tip_lbl)
	vbox.add_child(tip_panel)


func _build_player_control_column(title: String, title_col: Color, rows: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", title_col)
	col.add_child(heading)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = title_col * Color(1, 1, 1, 0.35)
	col.add_child(div)

	for item in rows:
		var row := HBoxContainer.new()
		var a_lbl := Label.new()
		a_lbl.text = item["action"] + ":"
		a_lbl.custom_minimum_size = Vector2(110, 0)
		a_lbl.add_theme_font_size_override("font_size", 11)
		a_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		row.add_child(a_lbl)

		var k_lbl := Label.new()
		k_lbl.text = item["keys"]
		k_lbl.add_theme_font_size_override("font_size", 11)
		k_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		row.add_child(k_lbl)
		col.add_child(row)

	return col


func _toggle_controls_modal(show_modal: bool) -> void:
	if _controls_modal == null:
		return
	_controls_modal.visible = show_modal
	if show_modal:
		_controls_modal.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(_controls_modal, "modulate", Color(1, 1, 1, 1), 0.2)
	else:
		if _buttons.size() > 0:
			_buttons[0].grab_focus()


# --- 5. Footer Bar -----------------------------------------------------------

func _build_footer() -> void:
	var footer := HBoxContainer.new()
	footer.position = Vector2(30, 616)
	footer.size = Vector2(1092, 24)

	var ver := Label.new()
	ver.text = "MYSTIK COMBAT v1.2.0 • OFFLINE DUEL ENGINE"
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.65))
	footer.add_child(ver)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(sp)

	var hint := Label.new()
	hint.text = "[W / S / ↑ / ↓] Navigate  •  [Enter / Space] Select  •  [Esc] Quit  •  [C] Controls"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.65))
	footer.add_child(hint)

	add_child(footer)


# --- Scene Transitions -------------------------------------------------------

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/character_select/character_select.tscn")


func _on_quick_fight_pressed() -> void:
	GameSettings.player1_character = "KAAL"
	GameSettings.player2_character = "NEX"
	get_tree().change_scene_to_file("res://Main.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
