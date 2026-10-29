extends Node2D

const KiBarClass = preload("res://ui/ki_bar.gd")
const KAAL_DATA: CharacterData = preload("res://data/characters/kaal.tres")
const NEX_DATA: CharacterData = preload("res://data/characters/nex.tres")
const ARENA_TEXTURE: Texture2D = preload("res://assets/arena/arena_backdrop.jpg")

var fighter1: CharacterBody2D
var fighter2: CharacterBody2D

var health_bar1: ProgressBar
var health_bar2: ProgressBar
var name_label1: Label
var name_label2: Label
var hp_label1: Label
var hp_label2: Label

var ki_bar1: Control
var ki_bar2: Control
var status_label: Label
var combo_label1: Label
var combo_label2: Label
var round_dots1: Label
var round_dots2: Label

# Cinematic and Camera
var camera: Camera2D
var shake_intensity: float = 0.0
var default_camera_pos := Vector2(576, 324)
var ultimate_overlay: Control
var ultimate_banner_label: Label
var ultimate_sub_label: Label
var is_cinematic_active: bool = false

# Frame data & AI Brain overlays
var frame_data_inspector: FrameDataInspector
var ai_debug_overlay: AIDebugOverlay

# Pause & Menu System
var pause_layer: CanvasLayer = null
var pause_modal: Control = null
var pause_controls_modal: Control = null
var pause_subtitle: Label = null
var pause_buttons: Array[Button] = []

var round_number: int = 1
var round_wins: Array[int] = [0, 0]
var round_over: bool = false
var match_over: bool = false
var round_timer: float = 99.0

# Arcade mode tracking
var arcade_stage_time: float = 0.0
var p1_max_combo: int = 0
var trial_banner: Label = null

var phase: String = "countdown"
var phase_time: float = 0.0
var countdown_number: int = 3


func _get_game_settings() -> Node:
	if has_node("/root/GameSettings"):
		return get_node("/root/GameSettings")
	return null


func get_character_data(id: String) -> CharacterData:
	if id.to_upper() == "NEX":
		return NEX_DATA
	return KAAL_DATA


func apply_character_selection() -> void:
	if has_node("/root/ArcadeManager") and get_node("/root/ArcadeManager").is_arcade_active:
		var am = get_node("/root/ArcadeManager")
		var stage_data: Dictionary = am.get_current_stage_data()
		var p1_name: String = am.player_character
		var p2_name: String = String(stage_data.get("opponent_character", "NEX"))

		fighter1.setup_from_data(get_character_data(p1_name))
		fighter2.setup_from_data(get_character_data(p2_name))

		fighter2.enable_ai(float(stage_data.get("ai_difficulty", 0.75)))
		if bool(stage_data.get("is_boss", false)):
			fighter2.setup_boss(
				float(stage_data.get("opponent_hp", 160.0)),
				float(stage_data.get("opponent_dmg_mult", 1.25)),
				String(stage_data.get("opponent_title", "OVERDRIVE"))
			)
		else:
			fighter2.max_health = float(stage_data.get("opponent_hp", 100.0))
			fighter2.health = fighter2.max_health
			fighter2.damage_multiplier = float(stage_data.get("opponent_dmg_mult", 1.0))

		fighter1.damage_taken_multiplier = float(stage_data.get("player_dmg_taken_mult", 1.0))
	else:
		var gs := _get_game_settings()
		var p1_name: String = gs.player1_character if gs != null else "KAAL"
		var p2_name: String = gs.player2_character if gs != null else "NEX"
		var p1_data := get_character_data(p1_name)
		var p2_data := get_character_data(p2_name)
		fighter1.setup_from_data(p1_data)
		fighter2.setup_from_data(p2_data)


func _setup_arena() -> void:
	var arena_root := Node2D.new()
	arena_root.name = "AtmosphericArena"
	arena_root.z_index = -20
	add_child(arena_root)

	# Full-stage textured backdrop
	var bg := Sprite2D.new()
	bg.texture = ARENA_TEXTURE
	bg.position = Vector2(576, 324)
	# Scaled to generously cover the viewport during screen shakes and camera zooms
	bg.scale = Vector2(0.96, 0.96)
	arena_root.add_child(bg)

	# Atmospheric floor styling
	var floor_node := get_node_or_null("ArenaFloor")
	if floor_node != null:
		var old_rect = floor_node.get_node_or_null("ColorRect")
		if old_rect != null:
			old_rect.visible = false

		# Dark obsidian stone foundation slab
		var stage_slab := ColorRect.new()
		stage_slab.position = Vector2(-576, -20)
		stage_slab.size = Vector2(1152, 98)
		stage_slab.color = Color(0.07, 0.08, 0.13, 0.96)
		floor_node.add_child(stage_slab)

		# Neon energy surface line (cyber/mystic border)
		var glow_line := ColorRect.new()
		glow_line.position = Vector2(-576, -20)
		glow_line.size = Vector2(1152, 4)
		glow_line.color = Color(0.75, 0.35, 1.0, 0.95)
		floor_node.add_child(glow_line)

		# Inner cyan pulse stripe
		var cyan_strip := ColorRect.new()
		cyan_strip.position = Vector2(-380, -18)
		cyan_strip.size = Vector2(760, 2)
		cyan_strip.color = Color(0.25, 0.95, 1.0, 0.75)
		floor_node.add_child(cyan_strip)

	# Arena Boundary Markers (Pillars of Power at arena borders - hidden by default, toggled with F3)
	var left_pillar := ColorRect.new()
	left_pillar.name = "LeftPillar"
	left_pillar.position = Vector2(12, 180)
	left_pillar.size = Vector2(6, 390)
	left_pillar.color = Color(0.9, 0.25, 0.35, 0.4)
	left_pillar.visible = false
	arena_root.add_child(left_pillar)

	var right_pillar := ColorRect.new()
	right_pillar.name = "RightPillar"
	right_pillar.position = Vector2(1134, 180)
	right_pillar.size = Vector2(6, 390)
	right_pillar.color = Color(0.25, 0.75, 1.0, 0.4)
	right_pillar.visible = false
	arena_root.add_child(right_pillar)

	# Ambient Particles: Floor Embers & Dimensional Motes
	var floor_embers := CPUParticles2D.new()
	floor_embers.name = "FloorEmbers"
	floor_embers.amount = 40
	floor_embers.lifetime = 3.2
	floor_embers.preprocess = 2.0
	floor_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	floor_embers.emission_rect_extents = Vector2(560, 15)
	floor_embers.position = Vector2(576, 560)
	floor_embers.direction = Vector2(0, -1)
	floor_embers.spread = 30.0
	floor_embers.gravity = Vector2(0, -18)
	floor_embers.initial_velocity_min = 25.0
	floor_embers.initial_velocity_max = 65.0
	floor_embers.scale_amount_min = 2.5
	floor_embers.scale_amount_max = 5.0
	floor_embers.color = Color(0.85, 0.45, 1.0, 0.65)
	arena_root.add_child(floor_embers)

	var sky_motes := CPUParticles2D.new()
	sky_motes.name = "RiftMotes"
	sky_motes.amount = 25
	sky_motes.lifetime = 4.0
	sky_motes.preprocess = 2.0
	sky_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sky_motes.emission_rect_extents = Vector2(400, 120)
	sky_motes.position = Vector2(576, 160)
	sky_motes.direction = Vector2(0, 1)
	sky_motes.spread = 50.0
	sky_motes.gravity = Vector2(0, 10)
	sky_motes.initial_velocity_min = 12.0
	sky_motes.initial_velocity_max = 35.0
	sky_motes.scale_amount_min = 2.0
	sky_motes.scale_amount_max = 4.0
	sky_motes.color = Color(0.35, 0.85, 1.0, 0.55)
	arena_root.add_child(sky_motes)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	fighter1 = get_node("Fighter1")
	fighter2 = get_node("Fighter2")
	fighter1.process_mode = Node.PROCESS_MODE_PAUSABLE
	fighter2.process_mode = Node.PROCESS_MODE_PAUSABLE

	apply_character_selection()
	_setup_arena()

	var gs := _get_game_settings()
	if gs != null and gs.has_method("play_battle_music"):
		gs.play_battle_music()


	# Camera setup for screen shake & dramatic zoom
	camera = Camera2D.new()
	camera.position = default_camera_pos
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	add_child(camera)
	
	fighter1.health_changed.connect(_on_health_changed)
	fighter2.health_changed.connect(_on_health_changed)
	fighter1.ki_changed.connect(_on_ki_changed)
	fighter2.ki_changed.connect(_on_ki_changed)
	fighter1.knocked_out.connect(_on_knocked_out)
	fighter2.knocked_out.connect(_on_knocked_out)

	fighter1.combat_component.ultimate_requested.connect(_on_ultimate_requested)
	fighter2.combat_component.ultimate_requested.connect(_on_ultimate_requested)
	fighter1.combat_component.attack_started.connect(_on_attack_started)
	fighter2.combat_component.attack_started.connect(_on_attack_started)

	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var p1_data := get_character_data(fighter1.character_name)
	var p2_data := get_character_data(fighter2.character_name)

	# Fighter 1 Name and Archetype Tag
	name_label1 = Label.new()
	name_label1.position = Vector2(30, 2)
	name_label1.size = Vector2(240, 22)
	name_label1.add_theme_font_size_override("font_size", 16)
	name_label1.text = "%s [%s]" % [p1_data.display_name, p1_data.archetype.to_upper()]
	name_label1.add_theme_color_override("font_color", p1_data.accent_color)
	hud.add_child(name_label1)

	hp_label1 = Label.new()
	hp_label1.position = Vector2(240, 2)
	hp_label1.size = Vector2(160, 22)
	hp_label1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_label1.add_theme_font_size_override("font_size", 15)
	hp_label1.text = "%d / %d HP" % [int(fighter1.health), int(fighter1.max_health)]
	hp_label1.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	hud.add_child(hp_label1)

	# Fighter 2 Name and Archetype Tag
	name_label2 = Label.new()
	name_label2.position = Vector2(742, 2)
	name_label2.size = Vector2(240, 22)
	name_label2.add_theme_font_size_override("font_size", 16)
	if has_node("/root/ArcadeManager") and get_node("/root/ArcadeManager").is_arcade_active:
		var stage_data: Dictionary = get_node("/root/ArcadeManager").get_current_stage_data()
		name_label2.text = String(stage_data.get("opponent_title", p2_data.display_name))
		if bool(stage_data.get("is_boss", false)):
			name_label2.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
		else:
			name_label2.add_theme_color_override("font_color", p2_data.accent_color)
	else:
		name_label2.text = "%s [%s]" % [p2_data.display_name, p2_data.archetype.to_upper()]
		name_label2.add_theme_color_override("font_color", p2_data.accent_color)
	hud.add_child(name_label2)

	# Optional Arcade Trial Banner at top-center of screen
	if has_node("/root/ArcadeManager") and get_node("/root/ArcadeManager").is_arcade_active:
		var s_data: Dictionary = get_node("/root/ArcadeManager").get_current_stage_data()
		trial_banner = Label.new()
		trial_banner.position = Vector2(380, 2)
		trial_banner.size = Vector2(392, 20)
		trial_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trial_banner.add_theme_font_size_override("font_size", 12)
		if bool(s_data.get("is_boss", false)):
			trial_banner.text = "⚠️ FINAL TRIAL: CLASH OF TITANS ⚠️"
			trial_banner.add_theme_color_override("font_color", Color(1.0, 0.35, 0.2))
		else:
			trial_banner.text = "TRIAL %d / %d: %s" % [
				int(s_data.get("stage", 1)),
				int(s_data.get("total_stages", 4)),
				String(s_data.get("name", "")).to_upper()
			]
			trial_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))
		hud.add_child(trial_banner)

	hp_label2 = Label.new()
	hp_label2.position = Vector2(952, 2)
	hp_label2.size = Vector2(160, 22)
	hp_label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_label2.add_theme_font_size_override("font_size", 15)
	hp_label2.text = "%d / %d HP" % [int(fighter2.health), int(fighter2.max_health)]
	hp_label2.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	hud.add_child(hp_label2)

	# Health Bars
	health_bar1 = make_health_bar(Vector2(30, 26), Color.CRIMSON)
	health_bar2 = make_health_bar(Vector2(742, 26), Color.CRIMSON)
	hud.add_child(health_bar1)
	hud.add_child(health_bar2)

	# Ki Bars beneath each player's health bar
	ki_bar1 = KiBarClass.new()
	ki_bar1.player_number = 1
	ki_bar1.character_name = fighter1.character_name
	ki_bar1.position = Vector2(30, 58)
	ki_bar1.mirrored = false
	hud.add_child(ki_bar1)

	ki_bar2 = KiBarClass.new()
	ki_bar2.player_number = 2
	ki_bar2.character_name = fighter2.character_name
	ki_bar2.position = Vector2(742, 58)
	ki_bar2.mirrored = true
	hud.add_child(ki_bar2)

	# Round dots positioned neatly below Ki bars
	round_dots1 = Label.new()
	round_dots1.position = Vector2(30, 84)
	round_dots1.add_theme_font_size_override("font_size", 20)
	round_dots1.add_theme_color_override("font_color", Color.YELLOW)
	hud.add_child(round_dots1)

	round_dots2 = Label.new()
	round_dots2.position = Vector2(742, 84)
	round_dots2.add_theme_font_size_override("font_size", 20)
	round_dots2.add_theme_color_override("font_color", Color.YELLOW)
	hud.add_child(round_dots2)

	combo_label1 = Label.new()
	combo_label1.position = Vector2(30, 112)
	combo_label1.add_theme_font_size_override("font_size", 22)
	hud.add_child(combo_label1)

	combo_label2 = Label.new()
	combo_label2.position = Vector2(900, 112)
	combo_label2.add_theme_font_size_override("font_size", 22)
	hud.add_child(combo_label2)

	fighter1.combo_component.combo_changed.connect(_on_combo_changed)
	fighter2.combo_component.combo_changed.connect(_on_combo_changed)

	status_label = Label.new()
	status_label.position = Vector2(450, 20)
	status_label.size = Vector2(252, 50)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 28)
	hud.add_child(status_label)

	var controls_hint := Label.new()
	controls_hint.position = Vector2(0, 624)
	controls_hint.size = Vector2(1152, 22)
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint.add_theme_font_size_override("font_size", 12)
	controls_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
	var p2_ctrl_hint: String = "AI (Adaptive)" if (fighter2 and fighter2.is_ai) else "Arrows/IJKL • / Light • . Heavy"
	controls_hint.text = "P1: WASD Move • F Light • G Heavy • Q Spcl • E Ult  |  P2: %s  |  [F1] Frames  [F2] AI Brain  [F3] Hitboxes  [F5] Reload" % p2_ctrl_hint
	hud.add_child(controls_hint)

	# Frame Data Inspector & Adaptive AI Overlay
	frame_data_inspector = FrameDataInspector.new()
	frame_data_inspector.name = "FrameDataInspector"
	add_child(frame_data_inspector)
	frame_data_inspector.set_fighters(fighter1, fighter2)

	ai_debug_overlay = AIDebugOverlay.new()
	ai_debug_overlay.name = "AIDebugOverlay"
	add_child(ai_debug_overlay)
	if fighter2.ai_controller != null:
		ai_debug_overlay.set_ai_controller(fighter2.ai_controller)

	# Cinematic Ultimate Overlay
	_setup_ultimate_overlay(hud)

	# In-Match Pause & Controls Modal
	_build_pause_modal()

	# Start the first round
	prepare_round()




func _setup_ultimate_overlay(hud: CanvasLayer) -> void:
	ultimate_overlay = Control.new()
	ultimate_overlay.custom_minimum_size = Vector2(1152, 648)
	ultimate_overlay.size = Vector2(1152, 648)
	ultimate_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_overlay.modulate = Color(1, 1, 1, 0)
	hud.add_child(ultimate_overlay)

	# Dark vignette background
	var bg := ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0, 0, 0, 0.45)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_overlay.add_child(bg)

	# Top/bottom letterbox bars
	var bar_top := ColorRect.new()
	bar_top.size = Vector2(1152, 40)
	bar_top.color = Color(0.04, 0.04, 0.06, 0.95)
	ultimate_overlay.add_child(bar_top)

	var bar_bot := ColorRect.new()
	bar_bot.position = Vector2(0, 608)
	bar_bot.size = Vector2(1152, 40)
	bar_bot.color = Color(0.04, 0.04, 0.06, 0.95)
	ultimate_overlay.add_child(bar_bot)

	ultimate_banner_label = Label.new()
	ultimate_banner_label.position = Vector2(0, 240)
	ultimate_banner_label.size = Vector2(1152, 50)
	ultimate_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_banner_label.add_theme_font_size_override("font_size", 38)
	ultimate_overlay.add_child(ultimate_banner_label)

	ultimate_sub_label = Label.new()
	ultimate_sub_label.position = Vector2(0, 295)
	ultimate_sub_label.size = Vector2(1152, 35)
	ultimate_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_sub_label.add_theme_font_size_override("font_size", 22)
	ultimate_overlay.add_child(ultimate_sub_label)


func make_health_bar(pos: Vector2, bar_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = Vector2(370, 28)
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	bar.modulate = bar_color
	return bar


func update_round_dots() -> void:
	round_dots1.text = ("●" if round_wins[0] >= 1 else "○") + "  " + ("●" if round_wins[0] >= 2 else "○")
	round_dots2.text = ("●" if round_wins[1] >= 1 else "○") + "  " + ("●" if round_wins[1] >= 2 else "○")


func _on_combo_changed(fighter: CharacterBody2D, count: int) -> void:
	var label: Label = combo_label1 if fighter == fighter1 else combo_label2
	label.text = "%d HIT COMBO!" % count if count >= 2 else ""
	if fighter == fighter1:
		p1_max_combo = maxi(p1_max_combo, count)


func apply_shake(intensity: float) -> void:
	shake_intensity = maxf(shake_intensity, intensity)


func _on_attack_started(kind: String) -> void:
	if kind == "special":
		shake_intensity = maxf(shake_intensity, 5.0)


func _on_ultimate_requested(attacker: CharacterBody2D) -> void:
	trigger_ultimate_cinematic(attacker)


func trigger_ultimate_cinematic(attacker: CharacterBody2D) -> void:
	if is_cinematic_active:
		return
	is_cinematic_active = true

	var is_kaal: bool = (attacker.character_name.to_upper() == "KAAL")
	var opponent: CharacterBody2D = attacker.find_opponent()

	# Banner configuration
	if is_kaal:
		ultimate_banner_label.text = "★ ULTIMATE INCANTATION ★"
		ultimate_banner_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		ultimate_sub_label.text = "KAAL — DRAGON EMBERS DESCENT"
		ultimate_sub_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.15))
	else:
		ultimate_banner_label.text = "★ ULTIMATE INCANTATION ★"
		ultimate_banner_label.add_theme_color_override("font_color", Color(0.25, 0.95, 1.0))
		ultimate_sub_label.text = "NEX — CYBER TEMPEST SURGE"
		ultimate_sub_label.add_theme_color_override("font_color", Color(0.35, 0.65, 1.0))

	# Focus target between fighters
	var focal_x: float = (attacker.global_position.x + (opponent.global_position.x if opponent else attacker.global_position.x)) * 0.5
	focal_x = clampf(focal_x, 350.0, 802.0)
	var focal_target := Vector2(focal_x, 324.0)

	# 1. Brief pause and cinematic overlay fade-in
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ultimate_overlay, "modulate:a", 1.0, 0.12)
	tween.tween_property(camera, "position", focal_target, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "zoom", Vector2(1.32, 1.32), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Screen shake trigger
	shake_intensity = 18.0

	# Sequence recovery after dramatic pause
	var reset_tween := create_tween()
	reset_tween.tween_interval(0.45)
	
	var return_tween := reset_tween.chain().set_parallel(true)
	return_tween.tween_property(ultimate_overlay, "modulate:a", 0.0, 0.25)
	return_tween.tween_property(camera, "position", default_camera_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(camera, "zoom", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	reset_tween.chain().tween_callback(func(): is_cinematic_active = false)


func _process(delta: float) -> void:
	if get_tree().paused:
		return

	# Screen shake update
	if shake_intensity > 0.0:
		shake_intensity = maxf(0.0, shake_intensity - delta * 30.0)
		camera.offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
	else:
		camera.offset = Vector2.ZERO

	if match_over:
		return

	if phase == "fight":
		round_timer = maxf(0.0, round_timer - delta)
		arcade_stage_time += delta
		status_label.text = "ROUND %d  |  %02d" % [
			round_number, int(ceil(round_timer))
		]

		if round_timer <= 0.0:
			if fighter1.health > fighter2.health:
				end_round(fighter1)
			elif fighter2.health > fighter1.health:
				end_round(fighter2)
			else:
				end_draw_round()
		return

	phase_time -= delta
	if phase_time > 0.0:
		return

	match phase:
		"countdown":
			countdown_number -= 1
			if countdown_number > 0:
				status_label.text = str(countdown_number)
				phase_time = 1.0
			else:
				phase = "fight_call"
				status_label.text = "FIGHT!"
				phase_time = 0.7

		"fight_call":
			phase = "fight"
			round_over = false
			fighter1.set_physics_process(true)
			fighter2.set_physics_process(true)
			status_label.text = "ROUND %d  |  99" % round_number

		"round_result":
			start_next_round()

		"match_result":
			match_over = true
			if has_node("/root/ArcadeManager") and get_node("/root/ArcadeManager").is_arcade_active:
				var am = get_node("/root/ArcadeManager")
				if round_wins[0] >= 2:
					var has_next: bool = am.advance_stage()
					if has_next:
						get_tree().change_scene_to_file("res://ui/ArcadeLadder.tscn")
					else:
						get_tree().change_scene_to_file("res://ui/HighScoreScreen.tscn")
				else:
					get_tree().change_scene_to_file("res://ui/HighScoreScreen.tscn")
			else:
				get_tree().change_scene_to_file("res://Results.tscn")


func _on_health_changed(
	fighter: CharacterBody2D,
	current: float,
	maximum: float
) -> void:
	if maximum <= 0.0:
		return

	if fighter == fighter1:
		health_bar1.value = current / maximum * 100.0
		if hp_label1:
			hp_label1.text = "%d / %d HP" % [int(ceil(current)), int(ceil(maximum))]
	else:
		health_bar2.value = current / maximum * 100.0
		if hp_label2:
			hp_label2.text = "%d / %d HP" % [int(ceil(current)), int(ceil(maximum))]


func _on_ki_changed(
	fighter: CharacterBody2D,
	current: float,
	maximum: float
) -> void:
	if fighter == fighter1:
		ki_bar1.set_ki(current, maximum)
	else:
		ki_bar2.set_ki(current, maximum)


func _on_knocked_out(fighter: CharacterBody2D) -> void:
	if phase != "fight" or round_over or match_over:
		return

	end_round(fighter2 if fighter == fighter1 else fighter1)


func end_round(winner: CharacterBody2D) -> void:
	if round_over or match_over or phase != "fight":
		return

	round_over = true
	var winner_index: int = 0 if winner == fighter1 else 1
	round_wins[winner_index] += 1

	var gs := _get_game_settings()
	if gs != null:
		gs.player1_round_wins = round_wins[0]
		gs.player2_round_wins = round_wins[1]

	update_round_dots()

	# Stop attacker action, and let the loser play out their KO animation and fall
	winner.combat_component.cancel_attack()
	winner.velocity.x = 0.0

	# Dramatic impact feedback on KO
	shake_intensity = 12.0
	status_label.text = "K.O.!"
	status_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.12))

	if round_wins[winner_index] >= 2:
		phase = "match_result"
		phase_time = 2.5 # Show full KO animation, landing, and victory call before changing scene

		var is_arcade: bool = has_node("/root/ArcadeManager") and get_node("/root/ArcadeManager").is_arcade_active
		if is_arcade and winner_index == 0:
			var am = get_node("/root/ArcadeManager")
			am.record_stage_victory(fighter1.health, arcade_stage_time, p1_max_combo)

		var victor_name: String = winner.character_name
		if gs != null:
			gs.winner_character = victor_name
		get_tree().create_timer(1.1).timeout.connect(func():
			if is_instance_valid(status_label):
				if is_arcade:
					if winner_index == 0:
						status_label.text = "TRIAL CLEARED!"
						status_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
					else:
						status_label.text = "GAUNTLET FAILED!"
						status_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
				else:
					status_label.text = "%s WINS!" % victor_name
					status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		)
		return

	# Regular round transition: let KO animation complete
	phase = "round_result"
	phase_time = 2.2
	get_tree().create_timer(1.1).timeout.connect(func():
		if is_instance_valid(status_label) and not match_over:
			status_label.text = "PLAYER %d WINS ROUND %d" % [
				winner_index + 1, round_number
			]
			status_label.add_theme_color_override("font_color", Color.YELLOW)
	)


func end_draw_round() -> void:
	if round_over or match_over or phase != "fight":
		return

	round_over = true
	phase = "round_result"

	fighter1.set_physics_process(false)
	fighter2.set_physics_process(false)
	fighter1.velocity = Vector2.ZERO
	fighter2.velocity = Vector2.ZERO

	status_label.text = "DRAW ROUND"
	phase_time = 1.8


func prepare_round() -> void:
	round_over = true
	phase = "countdown"
	countdown_number = 3
	phase_time = 1.0
	round_timer = 99.0

	if round_number == 1:
		arcade_stage_time = 0.0
		p1_max_combo = 0

	fighter1.set_physics_process(false)
	fighter2.set_physics_process(false)

	# Reset both fighters: health, Ki, states
	for fighter in [fighter1, fighter2]:
		fighter.health = fighter.max_health
		fighter.ki = 0.0
		fighter.defeated = false
		fighter.blocking = false
		fighter.stun_time = 0.0
		fighter.hit_stop_time = 0.0
		fighter.hit_flash_time = 0.0
		fighter.hit_reaction_time = 0.0
		fighter.velocity = Vector2.ZERO
		fighter.combat_component.cancel_attack()
		fighter.combo_component.reset()

	if fighter2.ai_controller != null:
		fighter2.ai_controller.reset()

	fighter1.global_position = Vector2(250, 470)
	fighter2.global_position = Vector2(900, 470)

	fighter1.facing = 1.0
	fighter2.facing = -1.0
	
	if fighter1.animated_sprite:
		fighter1.animated_sprite.flip_h = fighter1.facing < 0.0
		fighter1.animated_sprite.play("idle")

	if fighter2.animated_sprite:
		fighter2.animated_sprite.flip_h = fighter2.facing < 0.0
		fighter2.animated_sprite.play("idle")

	fighter1.health_changed.emit(
		fighter1, fighter1.health, fighter1.max_health
	)
	fighter2.health_changed.emit(
		fighter2, fighter2.health, fighter2.max_health
	)

	fighter1.ki_changed.emit(fighter1, 0.0, 100.0)
	fighter2.ki_changed.emit(fighter2, 0.0, 100.0)

	# Reset camera and overlays
	if camera:
		camera.position = default_camera_pos
		camera.zoom = Vector2(1.0, 1.0)
		camera.offset = Vector2.ZERO
	if ultimate_overlay:
		ultimate_overlay.modulate = Color(1, 1, 1, 0)
	is_cinematic_active = false
	shake_intensity = 0.0

	combo_label1.text = ""
	combo_label2.text = ""
	update_round_dots()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "3"


func start_next_round() -> void:
	round_number += 1
	prepare_round()


func restart_match() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if pause_modal != null:
		pause_modal.visible = false
	if pause_controls_modal != null:
		pause_controls_modal.visible = false

	round_wins = [0, 0]
	round_number = 1
	match_over = false
	prepare_round()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			var show_debug: bool = not fighter1.show_hitboxes
			fighter1.show_hitboxes = show_debug
			fighter2.show_hitboxes = show_debug
			fighter1.queue_redraw()
			fighter2.queue_redraw()

			var lp = get_node_or_null("AtmosphericArena/LeftPillar")
			if lp: lp.visible = show_debug
			var rp = get_node_or_null("AtmosphericArena/RightPillar")
			if rp: rp.visible = show_debug
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_ESCAPE:
			if pause_controls_modal != null and pause_controls_modal.visible:
				_toggle_pause_controls(false)
			else:
				_toggle_pause()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_R and match_over:
			restart_match()
			get_viewport().set_input_as_handled()
			return

	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_BACK:
			if pause_controls_modal != null and pause_controls_modal.visible:
				_toggle_pause_controls(false)
			else:
				_toggle_pause()
			get_viewport().set_input_as_handled()
			return


# --- In-Match Pause & Controls System ----------------------------------------

func _build_pause_modal() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 30
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)

	var PauseMenuScript = preload("res://ui/pause_menu.gd")
	var p_menu: PauseMenu = PauseMenuScript.new()
	p_menu.name = "PauseModal"
	p_menu.custom_minimum_size = Vector2(1152, 648)
	p_menu.size = Vector2(1152, 648)
	p_menu.visible = false
	pause_modal = p_menu
	pause_layer.add_child(pause_modal)

	p_menu.resume_requested.connect(func(): _toggle_pause(false))
	p_menu.restart_requested.connect(_on_restart_from_pause)
	p_menu.quit_requested.connect(_on_quit_to_main_menu)

	# 1. Dark Translucent Backdrop
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1152, 648)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.82)
	pause_modal.add_child(backdrop)

	# 2. Centered Dialog Card
	var dialog := PanelContainer.new()
	dialog.custom_minimum_size = Vector2(440, 420)
	dialog.size = Vector2(440, 420)
	dialog.position = Vector2(356, 114)

	var d_style := StyleBoxFlat.new()
	d_style.bg_color = Color(0.08, 0.09, 0.14, 0.98)
	d_style.border_width_left = 2
	d_style.border_width_top = 2
	d_style.border_width_right = 2
	d_style.border_width_bottom = 2
	d_style.border_color = Color(0.3, 0.75, 1.0, 0.85)
	d_style.set_corner_radius_all(10)
	d_style.shadow_color = Color(0.1, 0.5, 0.9, 0.25)
	d_style.shadow_size = 20
	dialog.add_theme_stylebox_override("panel", d_style)
	pause_modal.add_child(dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Header Title
	var title_lbl := Label.new()
	title_lbl.text = "PAUSED"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 34)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.3, 0.7, 1.0, 0.6))
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.add_theme_constant_override("shadow_outline_size", 6)
	vbox.add_child(title_lbl)

	pause_subtitle = Label.new()
	pause_subtitle.text = "MATCH IN PROGRESS"
	pause_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_subtitle.add_theme_font_size_override("font_size", 13)
	pause_subtitle.add_theme_color_override("font_color", Color(0.7, 0.82, 0.95, 0.8))
	vbox.add_child(pause_subtitle)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 2)
	div.color = Color(0.3, 0.75, 1.0, 0.4)
	vbox.add_child(div)

	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_vbox)

	# Action Buttons
	var resume_btn := _create_pause_button("RESUME")
	resume_btn.pressed.connect(func(): _toggle_pause(false))
	btn_vbox.add_child(resume_btn)
	pause_buttons.append(resume_btn)

	var restart_btn := _create_pause_button("RESTART MATCH")
	restart_btn.pressed.connect(_on_restart_from_pause)
	btn_vbox.add_child(restart_btn)
	pause_buttons.append(restart_btn)

	var controls_btn := _create_pause_button("HOW TO PLAY / CONTROLS")
	controls_btn.pressed.connect(func(): _toggle_pause_controls(true))
	btn_vbox.add_child(controls_btn)
	pause_buttons.append(controls_btn)

	var quit_btn := _create_pause_button("QUIT TO MAIN MENU")
	quit_btn.pressed.connect(_on_quit_to_main_menu)
	btn_vbox.add_child(quit_btn)
	pause_buttons.append(quit_btn)

	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sp)

	var footer := Label.new()
	footer.text = "[W / S / ↑ / ↓] Navigate  •  [ENTER / SPACE] Select  •  [ESC] Resume"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85, 0.6))
	vbox.add_child(footer)

	_build_pause_controls_modal()
	p_menu.controls_modal = pause_controls_modal
	p_menu.buttons = pause_buttons


func _create_pause_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(360, 42)
	btn.add_theme_font_size_override("font_size", 15)

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.11, 0.13, 0.19, 0.90)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.28, 0.38, 0.58, 0.7)
	box.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", box)

	var h_box := box.duplicate()
	h_box.bg_color = Color(0.18, 0.22, 0.33, 0.98)
	h_box.border_color = Color(1.0, 0.85, 0.28, 0.95)
	btn.add_theme_stylebox_override("hover", h_box)
	btn.add_theme_stylebox_override("focus", h_box)

	var p_box := box.duplicate()
	p_box.bg_color = Color(0.07, 0.08, 0.13, 1.0)
	p_box.border_color = Color(1.0, 0.85, 0.28, 1.0)
	btn.add_theme_stylebox_override("pressed", p_box)

	btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.28))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.86, 0.28))

	return btn


func _build_pause_controls_modal() -> void:
	pause_controls_modal = Control.new()
	pause_controls_modal.size = Vector2(1152, 648)
	pause_controls_modal.visible = false
	pause_controls_modal.z_index = 10
	pause_layer.add_child(pause_controls_modal)

	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1152, 648)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.88)
	pause_controls_modal.add_child(backdrop)

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
	pause_controls_modal.add_child(dialog)

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
	close_btn.text = "BACK TO PAUSE [ESC]"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(func(): _toggle_pause_controls(false))
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


func _toggle_pause(forced_state: Variant = null) -> void:
	if pause_modal == null:
		return
	if match_over and forced_state == null:
		return

	var should_pause: bool
	if forced_state != null:
		should_pause = bool(forced_state)
	else:
		should_pause = not get_tree().paused

	get_tree().paused = should_pause
	pause_modal.visible = should_pause

	if should_pause:
		if pause_controls_modal != null:
			pause_controls_modal.visible = false
		_update_pause_subtitle()
		if pause_buttons.size() > 0:
			pause_buttons[0].grab_focus()


func _toggle_pause_controls(show_controls: bool) -> void:
	if pause_controls_modal != null:
		pause_controls_modal.visible = show_controls
	if not show_controls and pause_buttons.size() > 2:
		pause_buttons[2].grab_focus()


func _update_pause_subtitle() -> void:
	if pause_subtitle == null:
		return
	if has_node("/root/ArcadeManager") and get_node("/root/ArcadeManager").is_arcade_active:
		var s_data: Dictionary = get_node("/root/ArcadeManager").get_current_stage_data()
		pause_subtitle.text = "ARCADE — TRIAL %d / %d: %s" % [
			int(s_data.get("stage", 1)),
			int(s_data.get("total_stages", 4)),
			String(s_data.get("name", "THE GAUNTLET")).to_upper()
		]
	else:
		var vs_text := "VS CPU" if (fighter2 and fighter2.is_ai) else "LOCAL 2-PLAYER"
		pause_subtitle.text = "VERSUS — %s (ROUND %d)" % [vs_text, round_number]


func _on_restart_from_pause() -> void:
	_toggle_pause(false)
	restart_match()


func _on_quit_to_main_menu() -> void:
	_toggle_pause(false)
	if has_node("/root/ArcadeManager"):
		get_node("/root/ArcadeManager").end_arcade()
	get_tree().change_scene_to_file("res://MainMenu.tscn")
