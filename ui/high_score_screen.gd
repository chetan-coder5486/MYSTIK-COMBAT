class_name HighScoreScreen
extends Control

const ARENA_BG: Texture2D = preload("res://assets/arena/arena_backdrop.jpg")

var entry_box: VBoxContainer = null
var initials_input: LineEdit = null
var submit_btn: Button = null
var table_vbox: VBoxContainer = null
var menu_btn: Button = null
var play_again_btn: Button = null

var is_submitting: bool = false
var pending_score: int = 0
var pending_time: float = 0.0
var pending_char: String = "KAAL"
var pending_diff: String = "WARRIOR"


func _ready() -> void:
	if has_node("/root/GameSettings"):
		var gs = get_node("/root/GameSettings")
		if gs.has_method("play_menu_music"):
			gs.play_menu_music()

	_check_pending_arcade_score()
	_build_ui()


func _check_pending_arcade_score() -> void:
	if has_node("/root/ArcadeManager") and has_node("/root/HighScoreManager"):
		var am = get_node("/root/ArcadeManager")
		var hsm = get_node("/root/HighScoreManager")
		if am.is_arcade_active and am.total_score > 0 and hsm.is_high_score(am.total_score):
			is_submitting = true
			pending_score = am.total_score
			pending_time = am.total_time
			pending_char = am.player_character
			pending_diff = am.difficulty_tier


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		_on_main_menu()
	elif event.physical_keycode == KEY_ENTER:
		if is_submitting and submit_btn != null and submit_btn.is_inside_tree():
			_on_submit_score()


func _build_ui() -> void:
	# Background
	var bg := TextureRect.new()
	bg.texture = ARENA_BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(1152, 648)
	add_child(bg)

	var tint := ColorRect.new()
	tint.size = Vector2(1152, 648)
	tint.color = Color(0.04, 0.05, 0.09, 0.90)
	add_child(tint)

	var main_vbox := VBoxContainer.new()
	main_vbox.position = Vector2(64, 24)
	main_vbox.size = Vector2(1024, 600)
	main_vbox.add_theme_constant_override("separation", 14)
	add_child(main_vbox)

	# Header Title
	var title := Label.new()
	title.text = "🏆  HALL OF FAME: GAUNTLET CHAMPIONS  🏆"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	main_vbox.add_child(title)

	var sub_lbl := Label.new()
	sub_lbl.text = "ETERNAL WARRIORS RECORDED IN THE CODEX"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.8))
	main_vbox.add_child(sub_lbl)

	# High Score Submission Form (if active)
	if is_submitting:
		entry_box = _build_submission_form()
		main_vbox.add_child(entry_box)

	# Table Panel
	var table_panel := PanelContainer.new()
	table_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = Color(0.07, 0.08, 0.14, 0.9)
	panel_box.border_color = Color(0.3, 0.6, 1.0, 0.5)
	panel_box.border_width_left = 2
	panel_box.border_width_top = 2
	panel_box.border_width_right = 2
	panel_box.border_width_bottom = 2
	panel_box.set_corner_radius_all(10)
	table_panel.add_theme_stylebox_override("panel", panel_box)
	main_vbox.add_child(table_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 14)
	table_panel.add_child(margin)

	table_vbox = VBoxContainer.new()
	table_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(table_vbox)

	_populate_table()

	# Bottom Navigation Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 24)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(btn_row)

	menu_btn = Button.new()
	menu_btn.text = "✕  MAIN MENU [ESC]"
	menu_btn.custom_minimum_size = Vector2(240, 46)
	menu_btn.add_theme_font_size_override("font_size", 15)
	_style_btn(menu_btn, Color(0.5, 0.6, 0.8), Color(0.1, 0.14, 0.22))
	menu_btn.pressed.connect(_on_main_menu)
	btn_row.add_child(menu_btn)

	play_again_btn = Button.new()
	play_again_btn.text = "⚔  ENTER GAUNTLET  ⚔"
	play_again_btn.custom_minimum_size = Vector2(320, 46)
	play_again_btn.add_theme_font_size_override("font_size", 16)
	_style_btn(play_again_btn, Color(0.2, 0.85, 1.0), Color(0.1, 0.35, 0.7))
	play_again_btn.pressed.connect(_on_play_again)
	btn_row.add_child(play_again_btn)

	if not is_submitting and play_again_btn != null:
		play_again_btn.grab_focus()


func _build_submission_form() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var banner := Label.new()
	banner.text = "★ NEW HIGH SCORE: %s PTS! ENTER YOUR CALLSIGN: ★" % _format_number(pending_score)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 16)
	banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	box.add_child(banner)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	initials_input = LineEdit.new()
	initials_input.placeholder_text = "PLAYER"
	initials_input.max_length = 8
	initials_input.custom_minimum_size = Vector2(180, 40)
	initials_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials_input.add_theme_font_size_override("font_size", 18)
	row.add_child(initials_input)

	submit_btn = Button.new()
	submit_btn.text = "SUBMIT [ENTER]"
	submit_btn.custom_minimum_size = Vector2(160, 40)
	_style_btn(submit_btn, Color(1.0, 0.85, 0.2), Color(0.5, 0.3, 0.05))
	submit_btn.pressed.connect(_on_submit_score)
	row.add_child(submit_btn)

	# Auto focus input
	initials_input.grab_focus()

	return box


func _populate_table() -> void:
	# Clear previous rows
	for child in table_vbox.get_children():
		child.queue_free()

	# Header Row
	var header := HBoxContainer.new()
	header.add_child(_make_col_label("RANK", 70, Color(0.5, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	header.add_child(_make_col_label("CALLSIGN", 180, Color(0.5, 0.8, 1.0), HORIZONTAL_ALIGNMENT_LEFT))
	header.add_child(_make_col_label("SCORE", 170, Color(0.5, 0.8, 1.0), HORIZONTAL_ALIGNMENT_RIGHT))
	header.add_child(_make_col_label("FIGHTER", 140, Color(0.5, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	header.add_child(_make_col_label("DIFFICULTY", 160, Color(0.5, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	header.add_child(_make_col_label("CLEAR TIME", 130, Color(0.5, 0.8, 1.0), HORIZONTAL_ALIGNMENT_RIGHT))
	header.add_child(_make_col_label("DATE", 130, Color(0.5, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	table_vbox.add_child(header)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.3, 0.6, 1.0, 0.4)
	table_vbox.add_child(div)

	var scores: Array[Dictionary] = []
	if has_node("/root/HighScoreManager"):
		scores = get_node("/root/HighScoreManager").get_scores()

	for i in range(scores.size()):
		var entry: Dictionary = scores[i]
		var rank: int = i + 1
		var is_top3: bool = (rank <= 3)

		var rank_color := Color(1.0, 0.85, 0.2) if rank == 1 else (Color(0.85, 0.9, 0.95) if rank == 2 else (Color(0.8, 0.5, 0.2) if rank == 3 else Color(0.65, 0.7, 0.8)))

		var row := HBoxContainer.new()
		var rank_str: String = "🥇 #1" if rank == 1 else ("🥈 #2" if rank == 2 else ("🥉 #3" if rank == 3 else "#%d" % rank))
		row.add_child(_make_col_label(rank_str, 70, rank_color, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(_make_col_label(String(entry.get("name", "WARRIOR")), 180, Color.WHITE if is_top3 else Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_LEFT))
		row.add_child(_make_col_label(_format_number(int(entry.get("score", 0))), 170, Color(1.0, 0.85, 0.3) if is_top3 else Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_RIGHT))
		
		var char_n: String = String(entry.get("character", "KAAL"))
		var char_col := Color(1.0, 0.5, 0.2) if char_n == "KAAL" else Color(0.2, 0.85, 1.0)
		row.add_child(_make_col_label(char_n, 140, char_col, HORIZONTAL_ALIGNMENT_CENTER))

		var diff_n: String = String(entry.get("difficulty", "WARRIOR"))
		var diff_col := Color(1.0, 0.3, 0.3) if diff_n == "MASTER" else (Color(1.0, 0.8, 0.2) if diff_n == "WARRIOR" else Color(0.4, 0.9, 0.5))
		row.add_child(_make_col_label(diff_n, 160, diff_col, HORIZONTAL_ALIGNMENT_CENTER))

		var t_sec: float = float(entry.get("time", 0.0))
		var time_str: String = "%d:%04.1f" % [int(t_sec / 60.0), fmod(t_sec, 60.0)]
		row.add_child(_make_col_label(time_str, 130, Color(0.75, 0.85, 0.95), HORIZONTAL_ALIGNMENT_RIGHT))

		row.add_child(_make_col_label(String(entry.get("date", "N/A")), 130, Color(0.55, 0.6, 0.7), HORIZONTAL_ALIGNMENT_CENTER))

		table_vbox.add_child(row)


func _make_col_label(text: String, width: int, color: Color, align: HorizontalAlignment) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(width, 24)
	lbl.horizontal_alignment = align
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _on_submit_score() -> void:
	if not is_submitting:
		return
	var entered_name: String = initials_input.text.strip_edges().to_upper()
	if entered_name.is_empty():
		entered_name = "CHAMPION"

	if has_node("/root/HighScoreManager"):
		get_node("/root/HighScoreManager").add_score(
			entered_name, pending_score, pending_time, pending_char, pending_diff
		)

	if has_node("/root/ArcadeManager"):
		get_node("/root/ArcadeManager").end_arcade()

	is_submitting = false
	if entry_box != null:
		entry_box.queue_free()

	_populate_table()
	if play_again_btn != null:
		play_again_btn.grab_focus()


func _on_main_menu() -> void:
	if has_node("/root/ArcadeManager"):
		get_node("/root/ArcadeManager").end_arcade()
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _on_play_again() -> void:
	if has_node("/root/ArcadeManager"):
		get_node("/root/ArcadeManager").end_arcade()
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _style_btn(btn: Button, border_c: Color, bg_c: Color) -> void:
	var n_box := StyleBoxFlat.new()
	n_box.bg_color = Color(bg_c.r, bg_c.g, bg_c.b, 0.9)
	n_box.border_color = border_c
	n_box.border_width_left = 2
	n_box.border_width_top = 2
	n_box.border_width_right = 2
	n_box.border_width_bottom = 2
	n_box.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", n_box)

	var h_box := n_box.duplicate()
	h_box.bg_color = bg_c * Color(1.3, 1.3, 1.3, 1.0)
	h_box.border_color = border_c * Color(1.3, 1.3, 1.3, 1.0)
	btn.add_theme_stylebox_override("hover", h_box)
	btn.add_theme_stylebox_override("focus", h_box)


func _format_number(n: int) -> String:
	var s: String = str(n)
	var res: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			res = "," + res
		res = s[i] + res
		count += 1
	return res

