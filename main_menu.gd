extends Control

const ARENA_BG: Texture2D = preload("res://assets/arena/arena_backdrop.jpg")
const KAAL_PORTRAIT: Texture2D = preload("res://assets/characters/kaal/kaal_portrait.png")
const NEX_PORTRAIT: Texture2D = preload("res://assets/characters/nex/nex_portrait.png")

var _controls_modal: Control = null
var _gauntlet_modal: Control = null
var _selected_gauntlet_char: String = "KAAL"
var _selected_gauntlet_diff: String = "WARRIOR"

var _bg_texture_rect: TextureRect = null
var _title_label: Label = null
var _buttons: Array[Button] = []
var _button_tweens: Dictionary = {}

# Key art nodes for breathing bob
var _kaal_art: TextureRect = null
var _nex_art: TextureRect = null


func _ready() -> void:
	if has_node("/root/GameSettings"):
		var gs = get_node("/root/GameSettings")
		if gs.has_method("play_menu_music"):
			gs.play_menu_music()

	_build_background()
	_build_particles()
	_build_key_art()
	_build_scrim()
	_build_left_menu()
	_build_footer()
	_build_controls_modal()
	_build_gauntlet_modal()

	# Start dynamic art idle breathing animation
	_start_key_art_breathing()

	# Focus first menu item for immediate gamepad/keyboard navigation
	if _buttons.size() > 0:
		_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	if event.physical_keycode == KEY_ESCAPE:
		if _gauntlet_modal != null and _gauntlet_modal.visible:
			_toggle_gauntlet_modal(false)
		elif _controls_modal != null and _controls_modal.visible:
			_toggle_controls_modal(false)
		else:
			get_tree().quit()
	elif event.physical_keycode == KEY_C or event.physical_keycode == KEY_TAB:
		if not (_gauntlet_modal != null and _gauntlet_modal.visible):
			if _controls_modal != null:
				_toggle_controls_modal(!_controls_modal.visible)


# --- 1. Background & Atmosphere ----------------------------------------------

func _build_background() -> void:
	_bg_texture_rect = TextureRect.new()
	_bg_texture_rect.texture = ARENA_BG
	_bg_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_texture_rect.size = Vector2(1152, 648)
	_bg_texture_rect.pivot_offset = Vector2(576, 324)
	add_child(_bg_texture_rect)

	# Deep base tint
	var tint := ColorRect.new()
	tint.size = Vector2(1152, 648)
	tint.color = Color(0.04, 0.05, 0.09, 0.70)
	add_child(tint)

	# Subtle ambient zoom on arena backdrop
	var tween := create_tween().set_loops()
	tween.tween_property(_bg_texture_rect, "scale", Vector2(1.025, 1.025), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_bg_texture_rect, "scale", Vector2(1.0, 1.0), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_particles() -> void:
	var embers := CPUParticles2D.new()
	embers.name = "MenuEmbers"
	embers.amount = 28
	embers.lifetime = 4.5
	embers.preprocess = 2.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(576, 10)
	embers.position = Vector2(576, 640)
	embers.direction = Vector2(0, -1)
	embers.spread = 30.0
	embers.gravity = Vector2(0, -16)
	embers.initial_velocity_min = 18.0
	embers.initial_velocity_max = 50.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 4.0
	embers.color = Color(0.75, 0.45, 1.0, 0.5)
	add_child(embers)


# --- 2. Large Character Key Art ----------------------------------------------

func _build_key_art() -> void:
	var art_stage := Control.new()
	art_stage.name = "KeyArtStage"
	art_stage.size = Vector2(1152, 648)
	art_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art_stage)

	# KAAL (Left-center of art stage, facing right toward Nex)
	_kaal_art = TextureRect.new()
	_kaal_art.texture = KAAL_PORTRAIT
	_kaal_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_kaal_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_kaal_art.position = Vector2(490, 85)
	_kaal_art.size = Vector2(410, 550)
	_kaal_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kaal_art.modulate = Color(0.92, 0.94, 1.0, 0.95)
	art_stage.add_child(_kaal_art)

	# NEX (Right of art stage, facing left toward Kaal)
	_nex_art = TextureRect.new()
	_nex_art.texture = NEX_PORTRAIT
	_nex_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_nex_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_nex_art.flip_h = true
	_nex_art.position = Vector2(740, 95)
	_nex_art.size = Vector2(420, 540)
	_nex_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nex_art.modulate = Color(0.95, 0.98, 1.0, 0.95)
	art_stage.add_child(_nex_art)


func _start_key_art_breathing() -> void:
	# Subtle, alternating breathing/floating bob
	if _kaal_art != null:
		var tw_kaal := create_tween().set_loops()
		tw_kaal.tween_property(_kaal_art, "position:y", 77.0, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_kaal.tween_property(_kaal_art, "position:y", 85.0, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if _nex_art != null:
		var tw_nex := create_tween().set_loops()
		tw_nex.tween_property(_nex_art, "position:y", 103.0, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_nex.tween_property(_nex_art, "position:y", 95.0, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- 3. Left-Side Readability Scrim (Horizontal Gradient) ---------------------

func _build_scrim() -> void:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.03, 0.04, 0.07, 0.96),
		Color(0.03, 0.04, 0.07, 0.92),
		Color(0.03, 0.04, 0.07, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.40, 0.70])

	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.width = 1152
	grad_tex.height = 648
	grad_tex.fill_from = Vector2(0.0, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)

	var scrim := TextureRect.new()
	scrim.texture = grad_tex
	scrim.size = Vector2(1152, 648)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


# --- 4. Left-Aligned Text Menu & Wordmark ------------------------------------

func _build_left_menu() -> void:
	# Main Title Wordmark (Top-Left)
	_title_label = Label.new()
	_title_label.text = "MYSTIK COMBAT"
	_title_label.position = Vector2(72, 60)
	_title_label.size = Vector2(450, 52)
	_title_label.add_theme_font_size_override("font_size", 44)
	_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.45, 0.1, 0.75, 0.7))
	_title_label.add_theme_constant_override("shadow_offset_x", 0)
	_title_label.add_theme_constant_override("shadow_offset_y", 4)
	_title_label.add_theme_constant_override("shadow_outline_size", 8)
	add_child(_title_label)

	# Navigation Container
	var menu_vbox := VBoxContainer.new()
	menu_vbox.position = Vector2(72, 172)
	menu_vbox.custom_minimum_size = Vector2(360, 360)
	menu_vbox.add_theme_constant_override("separation", 18)
	add_child(menu_vbox)

	# 1. ARCADE
	var arcade_btn := _create_text_nav_button("ARCADE")
	arcade_btn.pressed.connect(func(): _toggle_gauntlet_modal(true))
	menu_vbox.add_child(arcade_btn)
	_buttons.append(arcade_btn)

	# 2. VERSUS (2-PLAYER)
	var versus_btn := _create_text_nav_button("VERSUS (2-PLAYER)")
	versus_btn.pressed.connect(func(): _start_versus(false))
	menu_vbox.add_child(versus_btn)
	_buttons.append(versus_btn)

	# 3. VS CPU
	var cpu_btn := _create_text_nav_button("VS CPU (AI)")
	cpu_btn.pressed.connect(func(): _start_versus(true))
	menu_vbox.add_child(cpu_btn)
	_buttons.append(cpu_btn)

	# 4. HALL OF FAME
	var records_btn := _create_text_nav_button("HALL OF FAME")
	records_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://ui/HighScoreScreen.tscn")
	)
	menu_vbox.add_child(records_btn)
	_buttons.append(records_btn)

	# 5. HOW TO PLAY
	var controls_btn := _create_text_nav_button("HOW TO PLAY")
	controls_btn.pressed.connect(func(): _toggle_controls_modal(true))
	menu_vbox.add_child(controls_btn)
	_buttons.append(controls_btn)

	# 6. QUIT
	var quit_btn := _create_text_nav_button("QUIT")
	quit_btn.pressed.connect(_on_quit_pressed)
	menu_vbox.add_child(quit_btn)
	_buttons.append(quit_btn)


func _create_text_nav_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = "   " + label_text
	btn.custom_minimum_size = Vector2(320, 44)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 30)

	# Default empty styles (text-only, no boxes or colored rectangles)
	var empty_box := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_box)
	btn.add_theme_stylebox_override("hover", empty_box)
	btn.add_theme_stylebox_override("pressed", empty_box)
	btn.add_theme_stylebox_override("focus", empty_box)

	var dim_color := Color(0.68, 0.72, 0.82, 0.75)
	var active_color := Color(1.0, 0.86, 0.28) # Electric gold accent

	btn.add_theme_color_override("font_color", dim_color)
	btn.add_theme_color_override("font_hover_color", active_color)
	btn.add_theme_color_override("font_focus_color", active_color)

	# Slide and pointer arrow on hover/focus
	var on_focus = func():
		btn.text = "▸  " + label_text
		btn.add_theme_color_override("font_color", active_color)
		btn.add_theme_color_override("font_shadow_color", Color(1.0, 0.6, 0.1, 0.5))
		btn.add_theme_constant_override("shadow_offset_y", 2)
		btn.add_theme_constant_override("shadow_outline_size", 4)
		_slide_button(btn, 16.0)

	var on_unfocus = func():
		btn.text = "   " + label_text
		btn.add_theme_color_override("font_color", dim_color)
		btn.remove_theme_color_override("font_shadow_color")
		_slide_button(btn, 0.0)

	btn.focus_entered.connect(on_focus)
	btn.mouse_entered.connect(on_focus)
	btn.focus_exited.connect(on_unfocus)
	btn.mouse_exited.connect(on_unfocus)

	return btn


func _slide_button(btn: Button, target_x: float) -> void:
	var tw = _button_tweens.get(btn)
	if tw != null and tw.is_valid():
		tw.kill()
	tw = create_tween()
	tw.tween_property(btn, "position:x", target_x, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_button_tweens[btn] = tw


# --- 5. Clean Keycap Footer --------------------------------------------------

func _build_footer() -> void:
	var footer := HBoxContainer.new()
	footer.position = Vector2(72, 595)
	footer.size = Vector2(1008, 26)

	var controls_lbl := Label.new()
	controls_lbl.text = "[W / S / ↑ / ↓] Navigate  •  [ENTER / SPACE] Select  •  [C] Controls  •  [ESC] Quit"
	controls_lbl.add_theme_font_size_override("font_size", 13)
	controls_lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.82, 0.75))
	footer.add_child(controls_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(sp)

	var ver := Label.new()
	ver.text = "v1.2.0"
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(0.65, 0.70, 0.82, 0.65))
	footer.add_child(ver)

	add_child(footer)


# --- 6. The Gauntlet Setup Modal ---------------------------------------------

func _build_gauntlet_modal() -> void:
	_gauntlet_modal = Control.new()
	_gauntlet_modal.size = Vector2(1152, 648)
	_gauntlet_modal.visible = false
	_gauntlet_modal.z_index = 25
	add_child(_gauntlet_modal)

	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1152, 648)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.90)
	_gauntlet_modal.add_child(backdrop)

	var dialog := PanelContainer.new()
	dialog.custom_minimum_size = Vector2(720, 460)
	dialog.size = Vector2(720, 460)
	dialog.position = Vector2(216, 94)

	var d_style := StyleBoxFlat.new()
	d_style.bg_color = Color(0.08, 0.09, 0.15, 0.98)
	d_style.border_width_left = 2
	d_style.border_width_top = 2
	d_style.border_width_right = 2
	d_style.border_width_bottom = 2
	d_style.border_color = Color(1.0, 0.8, 0.25, 0.9)
	d_style.set_corner_radius_all(12)
	d_style.shadow_color = Color(1.0, 0.6, 0.1, 0.25)
	d_style.shadow_size = 18
	dialog.add_theme_stylebox_override("panel", d_style)
	_gauntlet_modal.add_child(dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Header
	var h_title := Label.new()
	h_title.text = "THE GAUNTLET — ARCADE LADDER"
	h_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_title.add_theme_font_size_override("font_size", 22)
	h_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(h_title)

	var h_sub := Label.new()
	h_sub.text = "4 Consecutive Trials culminating in a Formidable Final Boss encounter."
	h_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_sub.add_theme_font_size_override("font_size", 12)
	h_sub.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.8))
	vbox.add_child(h_sub)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(1.0, 0.8, 0.2, 0.3)
	vbox.add_child(div)

	# 1. Champion Selection
	var c_title := Label.new()
	c_title.text = "CHOOSE YOUR FIGHTER:"
	c_title.add_theme_font_size_override("font_size", 13)
	c_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(c_title)

	var char_row := HBoxContainer.new()
	char_row.add_theme_constant_override("separation", 16)
	vbox.add_child(char_row)

	var kaal_btn := Button.new()
	kaal_btn.text = "KAAL [BRAWLER]"
	kaal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kaal_btn.custom_minimum_size = Vector2(0, 40)
	char_row.add_child(kaal_btn)

	var nex_btn := Button.new()
	nex_btn.text = "NEX [SPEEDSTER]"
	nex_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nex_btn.custom_minimum_size = Vector2(0, 40)
	char_row.add_child(nex_btn)

	var update_char_btns = func():
		_style_select_button(kaal_btn, _selected_gauntlet_char == "KAAL", Color(1.0, 0.6, 0.2))
		_style_select_button(nex_btn, _selected_gauntlet_char == "NEX", Color(0.2, 0.85, 1.0))

	kaal_btn.pressed.connect(func():
		_selected_gauntlet_char = "KAAL"
		update_char_btns.call()
	)
	nex_btn.pressed.connect(func():
		_selected_gauntlet_char = "NEX"
		update_char_btns.call()
	)
	update_char_btns.call()

	# 2. Difficulty Selection
	var d_title := Label.new()
	d_title.text = "SELECT DIFFICULTY:"
	d_title.add_theme_font_size_override("font_size", 13)
	d_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(d_title)

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 12)
	vbox.add_child(diff_row)

	var novice_btn := Button.new()
	novice_btn.text = "NOVICE (1.0x)"
	novice_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	novice_btn.custom_minimum_size = Vector2(0, 40)
	diff_row.add_child(novice_btn)

	var warrior_btn := Button.new()
	warrior_btn.text = "WARRIOR (1.5x)"
	warrior_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warrior_btn.custom_minimum_size = Vector2(0, 40)
	diff_row.add_child(warrior_btn)

	var master_btn := Button.new()
	master_btn.text = "MASTER (2.5x)"
	master_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_btn.custom_minimum_size = Vector2(0, 40)
	diff_row.add_child(master_btn)

	var desc_label := Label.new()
	desc_label.custom_minimum_size = Vector2(0, 32)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	vbox.add_child(desc_label)

	var update_diff_btns = func():
		_style_select_button(novice_btn, _selected_gauntlet_diff == "NOVICE", Color(0.3, 0.85, 0.4))
		_style_select_button(warrior_btn, _selected_gauntlet_diff == "WARRIOR", Color(1.0, 0.8, 0.2))
		_style_select_button(master_btn, _selected_gauntlet_diff == "MASTER", Color(1.0, 0.3, 0.3))

		match _selected_gauntlet_diff:
			"NOVICE":
				desc_label.text = "• Forgiving AI reaction times • 15% player damage reduction • Base score"
			"WARRIOR":
				desc_label.text = "• Adaptive behavior-tree AI • Standard competitive rules • 1.5x Score Multiplier"
			"MASTER":
				desc_label.text = "• Hyper-reactive AI Punish counters • High aggression • 2.5x Score Multiplier"

	novice_btn.pressed.connect(func():
		_selected_gauntlet_diff = "NOVICE"
		update_diff_btns.call()
	)
	warrior_btn.pressed.connect(func():
		_selected_gauntlet_diff = "WARRIOR"
		update_diff_btns.call()
	)
	master_btn.pressed.connect(func():
		_selected_gauntlet_diff = "MASTER"
		update_diff_btns.call()
	)
	update_diff_btns.call()

	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sp)

	# Action Row
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 16)
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(act_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL [ESC]"
	cancel_btn.custom_minimum_size = Vector2(160, 42)
	cancel_btn.pressed.connect(func(): _toggle_gauntlet_modal(false))
	_style_select_button(cancel_btn, false, Color(0.6, 0.65, 0.75))
	act_row.add_child(cancel_btn)

	var start_btn := Button.new()
	start_btn.text = "START GAUNTLET"
	start_btn.custom_minimum_size = Vector2(240, 42)
	_style_select_button(start_btn, true, Color(1.0, 0.85, 0.25))
	start_btn.pressed.connect(_on_start_gauntlet)
	act_row.add_child(start_btn)


func _style_select_button(btn: Button, is_active: bool, accent: Color) -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(6)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	if is_active:
		box.bg_color = Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25, 0.95)
		box.border_color = accent
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		box.bg_color = Color(0.08, 0.1, 0.16, 0.85)
		box.border_color = Color(accent.r, accent.g, accent.b, 0.3)
		btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	btn.add_theme_stylebox_override("normal", box)
	var h_box := box.duplicate()
	h_box.bg_color = box.bg_color * Color(1.25, 1.25, 1.25, 1.0)
	btn.add_theme_stylebox_override("hover", h_box)
	btn.add_theme_stylebox_override("focus", h_box)


func _toggle_gauntlet_modal(show_modal: bool) -> void:
	if _gauntlet_modal == null:
		return
	_gauntlet_modal.visible = show_modal
	if show_modal:
		_gauntlet_modal.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(_gauntlet_modal, "modulate", Color(1, 1, 1, 1), 0.15)
	else:
		if _buttons.size() > 0:
			_buttons[0].grab_focus()


func _on_start_gauntlet() -> void:
	if has_node("/root/ArcadeManager"):
		var am = get_node("/root/ArcadeManager")
		am.start_arcade(_selected_gauntlet_diff, _selected_gauntlet_char)
	get_tree().change_scene_to_file("res://ui/ArcadeLadder.tscn")


# --- 7. Controls Modal -------------------------------------------------------

func _build_controls_modal() -> void:
	_controls_modal = Control.new()
	_controls_modal.size = Vector2(1152, 648)
	_controls_modal.visible = false
	_controls_modal.z_index = 20
	add_child(_controls_modal)

	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1152, 648)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.88)
	_controls_modal.add_child(backdrop)

	var dialog := PanelContainer.new()
	dialog.custom_minimum_size = Vector2(800, 500)
	dialog.size = Vector2(800, 500)
	dialog.position = Vector2(176, 74)

	var d_style := StyleBoxFlat.new()
	d_style.bg_color = Color(0.08, 0.09, 0.14, 0.98)
	d_style.border_width_left = 2
	d_style.border_width_top = 2
	d_style.border_width_right = 2
	d_style.border_width_bottom = 2
	d_style.border_color = Color(0.3, 0.75, 1.0, 0.85)
	d_style.set_corner_radius_all(12)
	d_style.shadow_color = Color(0.1, 0.5, 0.9, 0.25)
	d_style.shadow_size = 18
	dialog.add_theme_stylebox_override("panel", d_style)
	_controls_modal.add_child(dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	var h_title := Label.new()
	h_title.text = "HOW TO PLAY — CONTROLS GUIDE"
	h_title.add_theme_font_size_override("font_size", 20)
	h_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	header.add_child(h_title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)

	var close_btn := Button.new()
	close_btn.text = "CLOSE [ESC]"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(func(): _toggle_controls_modal(false))
	header.add_child(close_btn)
	vbox.add_child(header)

	var h_div := ColorRect.new()
	h_div.custom_minimum_size = Vector2(0, 1)
	h_div.color = Color(0.3, 0.7, 1.0, 0.3)
	vbox.add_child(h_div)

	# Columns
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(cols)

	var p1_box := _build_player_control_column(
		"PLAYER 1",
		Color(1.0, 0.8, 0.25),
		[
			{"action": "Movement", "keys": "W (Jump)  •  A (Left)  •  D (Right)"},
			{"action": "Defense", "keys": "S (Block - 65% Dmg Reduction)"},
			{"action": "Light Attack", "keys": "F (Fast Combo Opener)"},
			{"action": "Heavy Attack", "keys": "G (Heavy Knockback)"},
			{"action": "Mystic Special", "keys": "Q (Requires 40 Ki)"},
			{"action": "Cinematic Ultimate", "keys": "E (Requires 100 Ki)"},
			{"action": "Gamepad", "keys": "Left Stick / D-Pad + Face Buttons"},
		]
	)
	p1_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(p1_box)

	var p2_box := _build_player_control_column(
		"PLAYER 2",
		Color(0.25, 0.85, 1.0),
		[
			{"action": "Movement", "keys": "↑ or Num 8 (Jump)  •  ← / →"},
			{"action": "Defense", "keys": "↓ or Num 2 (Block)"},
			{"action": "Light Attack", "keys": "/ or Num 1"},
			{"action": "Heavy Attack", "keys": ". or Num 3"},
			{"action": "Mystic Special", "keys": "Right Shift or Num 7 (40 Ki)"},
			{"action": "Cinematic Ultimate", "keys": "Enter or Num 9 (100 Ki)"},
			{"action": "Gamepad", "keys": "Full Native Gamepad 2 Support"},
		]
	)
	p2_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(p2_box)


func _build_player_control_column(title: String, accent_color: Color, bindings: Array[Dictionary]) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)

	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", accent_color)
	col.add_child(heading)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = accent_color * Color(1, 1, 1, 0.3)
	col.add_child(div)

	for item in bindings:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var a_lbl := Label.new()
		a_lbl.text = item["action"].to_upper()
		a_lbl.add_theme_font_size_override("font_size", 10)
		a_lbl.add_theme_color_override("font_color", accent_color * Color(1, 1, 1, 0.85))
		row.add_child(a_lbl)

		var k_lbl := Label.new()
		k_lbl.text = item["keys"]
		k_lbl.add_theme_font_size_override("font_size", 11)
		k_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
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
		tw.tween_property(_controls_modal, "modulate", Color(1, 1, 1, 1), 0.15)
	else:
		if _buttons.size() > 0:
			_buttons[0].grab_focus()


# --- 8. Scene Transitions ----------------------------------------------------

func _start_versus(is_ai: bool) -> void:
	if has_node("/root/ArcadeManager"):
		get_node("/root/ArcadeManager").end_arcade()
	if has_node("/root/GameSettings"):
		get_node("/root/GameSettings").vs_ai = is_ai
	get_tree().change_scene_to_file("res://ui/character_select/character_select.tscn")


func _on_play_pressed() -> void:
	_start_versus(false)


func _on_quit_pressed() -> void:
	get_tree().quit()
