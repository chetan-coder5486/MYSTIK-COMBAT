class_name FrameDataInspector
extends CanvasLayer

## In-Game Frame Data Inspector Overlay
## Toggle with F1. Displays runtime loaded frame data from Grimoire
## along with real-time active state, frame progress, and frame advantage.

var root_panel: PanelContainer
var content_container: HBoxContainer
var is_visible: bool = false
var fighter1: CharacterBody2D
var fighter2: CharacterBody2D

var p1_move_labels: Dictionary = {}
var p2_move_labels: Dictionary = {}
var p1_active_label: Label
var p2_active_label: Label

func _ready() -> void:
	layer = 100
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle()
		elif event.keycode == KEY_F5 and visible:
			if has_node("/root/Grimoire"):
				get_node("/root/Grimoire").hot_reload()
				refresh_data()

func toggle() -> void:
	visible = not visible
	if visible:
		refresh_data()

func set_fighters(f1: CharacterBody2D, f2: CharacterBody2D) -> void:
	fighter1 = f1
	fighter2 = f2
	refresh_data()

func _build_ui() -> void:
	root_panel = PanelContainer.new()
	root_panel.anchor_left = 0.5
	root_panel.anchor_top = 0.5
	root_panel.anchor_right = 0.5
	root_panel.anchor_bottom = 0.5
	root_panel.offset_left = -460.0
	root_panel.offset_top = -260.0
	root_panel.offset_right = 460.0
	root_panel.offset_bottom = 260.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.94)
	style.border_color = Color(0.3, 0.7, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	root_panel.add_theme_stylebox_override("panel", style)
	add_child(root_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	root_panel.add_child(vbox)

	# Title bar
	var title_bar := HBoxContainer.new()
	var title := Label.new()
	title.text = "📜 GRIMOIRE FRAME DATA INSPECTOR"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_bar.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(spacer)

	var hint := Label.new()
	hint.text = "[F1] Close  |  [F5] Hot-Reload JSON"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	title_bar.add_child(hint)
	vbox.add_child(title_bar)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Columns container
	content_container = HBoxContainer.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 20)
	vbox.add_child(content_container)

func refresh_data() -> void:
	if not is_instance_valid(content_container):
		return

	for child in content_container.get_children():
		child.queue_free()

	p1_move_labels.clear()
	p2_move_labels.clear()

	var grimoire = get_node_or_null("/root/Grimoire")
	if grimoire == null:
		return

	var p1_name = fighter1.character_name if fighter1 else "KAAL"
	var p2_name = fighter2.character_name if fighter2 else "NEX"

	var p1_col = _create_fighter_column(p1_name, 1, p1_move_labels)
	content_container.add_child(p1_col)

	var vsep := VSeparator.new()
	content_container.add_child(vsep)

	var p2_col = _create_fighter_column(p2_name, 2, p2_move_labels)
	content_container.add_child(p2_col)

func _create_fighter_column(char_id: String, player_num: int, label_dict: Dictionary) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)

	var grimoire = get_node("/root/Grimoire")
	var moves: Dictionary = grimoire.get_all_moves(char_id)

	var header := Label.new()
	header.text = "PLAYER %d: %s" % [player_num, char_id.to_upper()]
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0) if player_num == 1 else Color(1.0, 0.4, 0.4))
	col.add_child(header)

	var active_status := Label.new()
	active_status.text = "State: IDLE"
	active_status.add_theme_font_size_override("font_size", 12)
	active_status.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	col.add_child(active_status)
	if player_num == 1:
		p1_active_label = active_status
	else:
		p2_active_label = active_status

	var moves_order = ["light", "heavy", "special", "ultimate"]
	for kind in moves_order:
		var move: Dictionary = moves.get(kind, grimoire.get_move(char_id, kind))
		var card := _create_move_card(kind, move)
		col.add_child(card)
		label_dict[kind] = card

	return col

func _create_move_card(kind: String, move: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.2, 0.8)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_top = 4
	style.content_margin_right = 8
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var top_row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "%s ATTACK" % kind.to_upper()
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	top_row.add_child(name_label)

	var tags_label := Label.new()
	var tags: Array = move.get("tags", [])
	tags_label.text = "[%s]" % ", ".join(tags) if tags.size() > 0 else ""
	tags_label.add_theme_font_size_override("font_size", 10)
	tags_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	top_row.add_child(tags_label)
	vbox.add_child(top_row)

	var data_label := Label.new()
	var s_frames: int = move.get("startup_frames", 0)
	var a_frames: int = move.get("active_frames", 0)
	var r_frames: int = move.get("recovery_frames", 0)
	var total_frames: int = s_frames + a_frames + r_frames
	var dmg: float = move.get("damage", 0.0)
	var ki_cost: float = move.get("ki_cost", 0.0)
	var hitstop: int = move.get("hit_stop_frames", 0)
	var reach: float = move.get("reach", 0.0)

	var ki_text := " | Ki Cost: %d" % int(ki_cost) if ki_cost > 0 else ""
	data_label.text = "Frames: %df (S:%d | A:%d | R:%d) | Dmg: %.0f%s\nHitStop: %df | Reach: %.0f | Stun: %.2fs" % [
		total_frames, s_frames, a_frames, r_frames, dmg, ki_text, hitstop, reach, move.get("stun_time", 0.0)
	]
	data_label.add_theme_font_size_override("font_size", 11)
	data_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	vbox.add_child(data_label)

	return panel

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_fighter_state(fighter1, p1_active_label, p1_move_labels)
	_update_fighter_state(fighter2, p2_active_label, p2_move_labels)

func _update_fighter_state(f: CharacterBody2D, active_lbl: Label, move_dict: Dictionary) -> void:
	if f == null or not is_instance_valid(f):
		return

	var cc = f.combat_component
	if active_lbl:
		if f.defeated:
			active_lbl.text = "State: K.O."
			active_lbl.add_theme_color_override("font_color", Color.RED)
		elif f.stun_time > 0.0:
			active_lbl.text = "State: STUNNED (%.2fs)" % f.stun_time
			active_lbl.add_theme_color_override("font_color", Color.ORANGE)
		elif f.blocking:
			active_lbl.text = "State: BLOCKING (80% Dmg Reduc)"
			active_lbl.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
		elif cc and cc.attack_kind != "":
			var phase: String = "Startup"
			var s: float = cc.get_startup_time(cc.attack_kind)
			var a: float = cc.get_active_time(cc.attack_kind)
			if cc.attack_time >= s + a:
				phase = "Recovery"
			elif cc.attack_time >= s:
				phase = "ACTIVE (HITBOX)"
			active_lbl.text = "State: ATTACK [%s - %s] (%.2fs)" % [cc.attack_kind.to_upper(), phase, cc.attack_time]
			active_lbl.add_theme_color_override("font_color", Color.YELLOW)
		else:
			active_lbl.text = "State: IDLE / READY"
			active_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))

	# Highlight active move panel
	if cc:
		for kind in move_dict:
			var card: PanelContainer = move_dict[kind]
			var style: StyleBoxFlat = card.get_theme_stylebox("panel")
			if kind == cc.attack_kind:
				style.bg_color = Color(0.35, 0.25, 0.05, 0.95)
				style.border_color = Color.GOLD
				style.set_border_width_all(2)
			else:
				style.bg_color = Color(0.1, 0.13, 0.2, 0.8)
				style.set_border_width_all(0)

