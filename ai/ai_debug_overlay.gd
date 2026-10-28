class_name AIDebugOverlay
extends CanvasLayer

## Live visualization of the AI's pattern-learning and habit counter system.
## Toggle with F2.

var root_panel: PanelContainer
var habit_label: Label
var strategy_label: Label
var predictability_bar: ProgressBar
var light_freq_label: Label
var heavy_freq_label: Label
var special_freq_label: Label
var ult_freq_label: Label
var confidence_label: Label

var ai_controller: AIController

func _ready() -> void:
	layer = 101
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			toggle()

func toggle() -> void:
	visible = not visible

func set_ai_controller(controller: AIController) -> void:
	ai_controller = controller

func _build_ui() -> void:
	root_panel = PanelContainer.new()
	root_panel.offset_left = 24.0
	root_panel.offset_top = 150.0
	root_panel.offset_right = 320.0
	root_panel.offset_bottom = 430.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.92)
	style.border_color = Color(0.65, 0.35, 1.0, 0.85) # Mystik purple border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	root_panel.add_theme_stylebox_override("panel", style)
	add_child(root_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(vbox)

	# Title
	var title_box := HBoxContainer.new()
	var title := Label.new()
	title.text = "🧠 ADAPTIVE AI BRAIN"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.85, 0.5, 1.0))
	title_box.add_child(title)

	var hint := Label.new()
	hint.text = "[F2]"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_box.add_child(hint)
	vbox.add_child(title_box)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	# Current Strategy
	var strat_title := Label.new()
	strat_title.text = "Active Counter Strategy:"
	strat_title.add_theme_font_size_override("font_size", 11)
	strat_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(strat_title)

	strategy_label = Label.new()
	strategy_label.text = "OBSERVING HABITS..."
	strategy_label.add_theme_font_size_override("font_size", 12)
	strategy_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5))
	vbox.add_child(strategy_label)

	# Predictability
	var pred_title := Label.new()
	pred_title.text = "Player Habit Predictability:"
	pred_title.add_theme_font_size_override("font_size", 11)
	pred_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(pred_title)

	predictability_bar = ProgressBar.new()
	predictability_bar.custom_minimum_size = Vector2(0, 16)
	predictability_bar.min_value = 0.0
	predictability_bar.max_value = 100.0
	predictability_bar.value = 0.0
	predictability_bar.show_percentage = true
	vbox.add_child(predictability_bar)

	# Dominant Habit
	habit_label = Label.new()
	habit_label.text = "Dominant Habit: Gathering data..."
	habit_label.add_theme_font_size_override("font_size", 11)
	habit_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(habit_label)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Frequency stats
	var freq_title := Label.new()
	freq_title.text = "Observed Attack Distribution:"
	freq_title.add_theme_font_size_override("font_size", 11)
	freq_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(freq_title)

	light_freq_label = _create_stat_label("Light Attacks:", "0 (0%)")
	heavy_freq_label = _create_stat_label("Heavy Attacks:", "0 (0%)")
	special_freq_label = _create_stat_label("Special Ki:", "0 (0%)")
	ult_freq_label = _create_stat_label("Ultimate Ki:", "0 (0%)")
	vbox.add_child(light_freq_label)
	vbox.add_child(heavy_freq_label)
	vbox.add_child(special_freq_label)
	vbox.add_child(ult_freq_label)

	var sep3 := HSeparator.new()
	vbox.add_child(sep3)

	confidence_label = Label.new()
	confidence_label.text = "AI Confidence: LOW (Gathering data)"
	confidence_label.add_theme_font_size_override("font_size", 11)
	confidence_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	vbox.add_child(confidence_label)

func _create_stat_label(prefix: String, initial_val: String) -> Label:
	var lbl := Label.new()
	lbl.text = "%s %s" % [prefix, initial_val]
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	return lbl

func _process(_delta: float) -> void:
	if not visible:
		return

	if ai_controller == null or not is_instance_valid(ai_controller):
		return

	var tracker: PatternTracker = ai_controller.pattern_tracker
	if tracker == null:
		return

	var summary: Dictionary = tracker.get_habit_summary()
	var freqs: Dictionary = summary.get("frequencies", {})
	var total: int = summary.get("total_attacks", 0)

	strategy_label.text = ai_controller.current_strategy
	var pred_val: float = summary.get("predictability", 0.0) * 100.0
	predictability_bar.value = pred_val

	# Dynamic bar tint based on predictability
	if pred_val >= 60.0:
		predictability_bar.modulate = Color(1.0, 0.3, 0.3) # High predictability = easily countered
	elif pred_val >= 35.0:
		predictability_bar.modulate = Color(1.0, 0.8, 0.2)
	else:
		predictability_bar.modulate = Color(0.4, 0.8, 1.0)

	var dom_atk: String = summary.get("dominant", "None")
	if total > 0:
		var dom_count: int = freqs.get(dom_atk, 0)
		var dom_pct: int = int((float(dom_count) / float(total)) * 100.0)
		habit_label.text = "Dominant: %s (%d%% of attacks)" % [dom_atk.to_upper(), dom_pct]
	else:
		habit_label.text = "Dominant: Waiting for first strike..."

	_update_freq_label(light_freq_label, "Light Attacks:", freqs.get("light", 0), total)
	_update_freq_label(heavy_freq_label, "Heavy Attacks:", freqs.get("heavy", 0), total)
	_update_freq_label(special_freq_label, "Special Ki:", freqs.get("special", 0), total)
	_update_freq_label(ult_freq_label, "Ultimate Ki:", freqs.get("ultimate", 0), total)

	if total < 4:
		confidence_label.text = "Confidence: LOW (Observing patterns)"
		confidence_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	elif pred_val >= 60.0:
		confidence_label.text = "Confidence: HIGH (Habit Read Locked)"
		confidence_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		confidence_label.text = "Confidence: ADAPTING (Balanced Player)"
		confidence_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))

func _update_freq_label(lbl: Label, prefix: String, count: int, total: int) -> void:
	var pct: int = 0
	if total > 0:
		pct = int((float(count) / float(total)) * 100.0)
	lbl.text = "%-16s %2d (%2d%%)" % [prefix, count, pct]

