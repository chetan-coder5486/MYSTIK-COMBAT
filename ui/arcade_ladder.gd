class_name ArcadeLadder
extends Control

const ARENA_BG: Texture2D = preload("res://assets/arena/arena_backdrop.jpg")
const KAAL_PORTRAIT: Texture2D = preload("res://assets/characters/kaal/kaal_portrait.png")
const NEX_PORTRAIT: Texture2D = preload("res://assets/characters/nex/nex_portrait.png")

var proceed_button: Button = null
var quit_button: Button = null

func _ready() -> void:
	if has_node("/root/GameSettings"):
		var gs = get_node("/root/GameSettings")
		if gs.has_method("play_menu_music"):
			gs.play_menu_music()

	_build_ui()
	if proceed_button != null:
		proceed_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		_on_give_up()
	elif event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER:
		if proceed_button != null and proceed_button.is_inside_tree():
			proceed_button.emit_signal("pressed")


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
	tint.color = Color(0.04, 0.05, 0.09, 0.88)
	add_child(tint)

	# Main layout container
	var main_vbox := VBoxContainer.new()
	main_vbox.position = Vector2(48, 24)
	main_vbox.size = Vector2(1056, 600)
	main_vbox.add_theme_constant_override("separation", 14)
	add_child(main_vbox)

	# Title Banner
	var title_lbl := Label.new()
	title_lbl.text = "⚔  THE GAUNTLET: ARCADE LADDER  ⚔"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	main_vbox.add_child(title_lbl)

	var diff_str: String = "WARRIOR"
	var score_val: int = 0
	var cur_stage: int = 1
	var total_st: int = 4
	var p_char: String = "KAAL"

	if has_node("/root/ArcadeManager"):
		var am = get_node("/root/ArcadeManager")
		diff_str = am.difficulty_tier
		score_val = am.total_score
		cur_stage = am.current_stage
		total_st = am.total_stages
		p_char = am.player_character

	var sub_lbl := Label.new()
	sub_lbl.text = "DIFFICULTY: %s  •  TOTAL SCORE: %s PTS  •  FIGHTER: %s" % [
		diff_str, _format_number(score_val), p_char
	]
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))
	main_vbox.add_child(sub_lbl)

	# Divider line
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(1056, 2)
	div.color = Color(0.3, 0.6, 1.0, 0.4)
	main_vbox.add_child(div)

	# Center Horizontal Row: Ladder Stages (Left 65%) + Last Stage Score Breakdown (Right 35%)
	var center_row := HBoxContainer.new()
	center_row.add_theme_constant_override("separation", 24)
	center_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(center_row)

	# Stages Column
	var stages_vbox := VBoxContainer.new()
	stages_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stages_vbox.add_theme_constant_override("separation", 10)
	stages_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_row.add_child(stages_vbox)

	var opp_char: String = "NEX" if p_char == "KAAL" else "KAAL"
	var templates: Array = []
	if has_node("/root/ArcadeManager"):
		templates = get_node("/root/ArcadeManager").STAGE_TEMPLATES
	else:
		templates = [
			{"stage": 1, "name": "TRIAL I: THE INITIATE", "is_boss": false},
			{"stage": 2, "name": "TRIAL II: THE VETERAN", "is_boss": false},
			{"stage": 3, "name": "TRIAL III: THE ASCENDANT", "is_boss": false},
			{"stage": 4, "name": "FINAL TRIAL: APEX OF POWER", "is_boss": true}
		]

	for t_idx in range(templates.size()):
		var t_data: Dictionary = templates[t_idx]
		var stage_num: int = int(t_data.get("stage", t_idx + 1))
		var is_boss: bool = bool(t_data.get("is_boss", false))
		var card := _create_stage_card(stage_num, cur_stage, t_data, opp_char, is_boss)
		stages_vbox.add_child(card)

	# Right Side: Last Stage Performance Panel
	var side_panel := _create_performance_panel()
	side_panel.custom_minimum_size = Vector2(360, 0)
	center_row.add_child(side_panel)

	# Bottom Actions
	var bottom_box := HBoxContainer.new()
	bottom_box.add_theme_constant_override("separation", 20)
	bottom_box.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(bottom_box)

	quit_button = Button.new()
	quit_button.text = "✕  ABANDON GAUNTLET"
	quit_button.custom_minimum_size = Vector2(240, 48)
	quit_button.add_theme_font_size_override("font_size", 15)
	_style_btn(quit_button, Color(0.8, 0.25, 0.25), Color(0.4, 0.1, 0.1))
	quit_button.pressed.connect(_on_give_up)
	bottom_box.add_child(quit_button)

	proceed_button = Button.new()
	var all_cleared: bool = (cur_stage > total_st)
	if all_cleared:
		proceed_button.text = "★  PROCEED TO HALL OF FAME [SPACE]  ★"
	else:
		proceed_button.text = "⚔  ENGAGE TRIAL %d [SPACE]  ⚔" % cur_stage
	proceed_button.custom_minimum_size = Vector2(400, 48)
	proceed_button.add_theme_font_size_override("font_size", 16)
	_style_btn(proceed_button, Color(0.2, 0.85, 1.0) if not all_cleared else Color(1.0, 0.8, 0.2), Color(0.1, 0.4, 0.8))
	proceed_button.pressed.connect(_on_proceed)
	bottom_box.add_child(proceed_button)


func _create_stage_card(stage_num: int, current_stage: int, t_data: Dictionary, opp_char: String, is_boss: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 72)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var is_cleared: bool = (stage_num < current_stage)
	var is_current: bool = (stage_num == current_stage)
	var is_locked: bool = (stage_num > current_stage)

	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(8)
	box.border_width_left = 3
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1

	if is_current:
		box.bg_color = Color(0.12, 0.15, 0.26, 0.95)
		box.border_color = Color(1.0, 0.8, 0.2) if not is_boss else Color(1.0, 0.25, 0.25)
		box.shadow_size = 8
		box.shadow_color = Color(1.0, 0.8, 0.2, 0.35) if not is_boss else Color(1.0, 0.2, 0.2, 0.5)
	elif is_cleared:
		box.bg_color = Color(0.06, 0.12, 0.08, 0.85)
		box.border_color = Color(0.2, 0.85, 0.35, 0.8)
	else:
		box.bg_color = Color(0.05, 0.06, 0.09, 0.6)
		box.border_color = Color(0.25, 0.3, 0.4, 0.4)

	panel.add_theme_stylebox_override("panel", box)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	# Left icon / status badge
	var status_lbl := Label.new()
	status_lbl.custom_minimum_size = Vector2(90, 0)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 16)
	if is_cleared:
		status_lbl.text = "✓ CLEARED"
		status_lbl.add_theme_color_override("font_color", Color(0.25, 0.95, 0.4))
	elif is_current:
		status_lbl.text = "▶ ACTIVE"
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		status_lbl.text = "🔒 LOCKED"
		status_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	hbox.add_child(status_lbl)

	# Stage info text
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_lbl := Label.new()
	name_lbl.text = String(t_data.get("name", "TRIAL"))
	name_lbl.add_theme_font_size_override("font_size", 15)
	if is_boss:
		name_lbl.text += "  [BOSS]"
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2) if is_current else Color(0.9, 0.4, 0.4))
	elif is_current:
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	elif is_cleared:
		name_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	text_vbox.add_child(name_lbl)

	var sub_lbl := Label.new()
	var opp_title: String = ("OVERDRIVE " + opp_char) if is_boss else (String(t_data.get("title_prefix", "Opponent")) + " " + opp_char)
	sub_lbl.text = "Target: %s  •  %s" % [opp_title, String(t_data.get("subtitle", ""))]
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.8) if not is_locked else Color(0.4, 0.45, 0.5, 0.6))
	text_vbox.add_child(sub_lbl)
	hbox.add_child(text_vbox)

	# Right portrait preview
	var p_rect := TextureRect.new()
	p_rect.custom_minimum_size = Vector2(56, 56)
	p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p_rect.texture = NEX_PORTRAIT if opp_char == "NEX" else KAAL_PORTRAIT
	if is_locked:
		p_rect.modulate = Color(0.2, 0.2, 0.3, 0.5)
	elif is_cleared:
		p_rect.modulate = Color(0.7, 1.0, 0.7, 0.8)
	hbox.add_child(p_rect)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(sp)

	return panel


func _create_performance_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.08, 0.14, 0.92)
	box.border_color = Color(0.25, 0.55, 0.95, 0.6)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "📊 TRIAL BREAKDOWN"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vbox.add_child(header)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.3, 0.6, 1.0, 0.3)
	vbox.add_child(div)

	var last_res: Dictionary = {}
	if has_node("/root/ArcadeManager"):
		var am = get_node("/root/ArcadeManager")
		if am.stage_results.size() > 0:
			last_res = am.stage_results[-1]

	if last_res.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "No trials completed yet.\nEnter Trial 1 to initiate your run!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.7))
		vbox.add_child(empty_lbl)
		return panel

	# Metrics rows
	vbox.add_child(_make_metric_row("Base Clear:", "%s PTS" % _format_number(int(last_res.get("base_clear", 10000)))))
	vbox.add_child(_make_metric_row("HP Bonus (Remaining):", "+%s PTS" % _format_number(int(last_res.get("hp_bonus", 0)))))
	vbox.add_child(_make_metric_row("Time Bonus:", "+%s PTS" % _format_number(int(last_res.get("time_bonus", 0)))))
	vbox.add_child(_make_metric_row("Max Combo Bonus:", "+%s PTS (%d Hits)" % [
		_format_number(int(last_res.get("combo_bonus", 0))),
		int(last_res.get("max_combo", 0))
	]))

	if bool(last_res.get("perfect", false)):
		var perf := Label.new()
		perf.text = "★ PERFECT ROUND BONUS: +25,000 PTS! ★"
		perf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		perf.add_theme_font_size_override("font_size", 12)
		perf.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		vbox.add_child(perf)

	var div2 := ColorRect.new()
	div2.custom_minimum_size = Vector2(0, 1)
	div2.color = Color(0.3, 0.6, 1.0, 0.3)
	vbox.add_child(div2)

	var mult: float = float(last_res.get("multiplier", 1.0))
	vbox.add_child(_make_metric_row("Difficulty Multiplier:", "%.1fx" % mult))
	vbox.add_child(_make_metric_row("Trial %d Score:" % int(last_res.get("stage", 1)), "%s PTS" % _format_number(int(last_res.get("stage_score", 0))), Color(1.0, 0.85, 0.3)))

	return panel


func _make_metric_row(key: String, val: String, val_col: Color = Color(0.85, 0.9, 1.0)) -> HBoxContainer:
	var row := HBoxContainer.new()
	var k_lbl := Label.new()
	k_lbl.text = key
	k_lbl.add_theme_font_size_override("font_size", 12)
	k_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
	row.add_child(k_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)

	var v_lbl := Label.new()
	v_lbl.text = val
	v_lbl.add_theme_font_size_override("font_size", 12)
	v_lbl.add_theme_color_override("font_color", val_col)
	row.add_child(v_lbl)
	return row


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


func _on_give_up() -> void:
	if has_node("/root/ArcadeManager"):
		get_node("/root/ArcadeManager").end_arcade()
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _on_proceed() -> void:
	if not has_node("/root/ArcadeManager"):
		get_tree().change_scene_to_file("res://Main.tscn")
		return

	var am = get_node("/root/ArcadeManager")
	if am.current_stage > am.total_stages:
		# Run cleared! Go to High Score screen
		get_tree().change_scene_to_file("res://ui/HighScoreScreen.tscn")
	else:
		# Start next stage fight
		get_tree().change_scene_to_file("res://Main.tscn")


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

