## Grimoire Loader — Runtime JSON move-data parser with hot-reload support.
## Autoload singleton registered as "Grimoire" in project.godot.
##
## Reads all .json files from res://data/grimoire/ at startup and converts
## frame counts to seconds (at 60 FPS, the fighting-game standard).
## Call hot_reload() at runtime (F5) to re-read all files without restarting.
extends Node

const GRIMOIRE_DIR := "res://data/grimoire/"
const FPS := 60.0

signal grimoire_reloaded(character_id: String)

## character_id (upper-case) → { move_kind → Dictionary }
var _move_tables: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	_move_tables.clear()
	var dir := DirAccess.open(GRIMOIRE_DIR)
	if dir == null:
		push_warning("Grimoire: Cannot open %s" % GRIMOIRE_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_character_file(GRIMOIRE_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("[Grimoire] Loaded %d character grimoires" % _move_tables.size())


func _load_character_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Grimoire: Cannot read %s" % path)
		return
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Grimoire: Parse error in %s line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return

	var data: Dictionary = json.data
	var char_id: String = data.get("character_id", "UNKNOWN").to_upper()
	var moves_raw: Dictionary = data.get("moves", {})
	var move_table: Dictionary = {}
	for kind in moves_raw:
		move_table[kind] = _parse_move(moves_raw[kind])
	_move_tables[char_id] = move_table
	print("[Grimoire] Loaded grimoire for %s (%d moves)" % [char_id, move_table.size()])
	grimoire_reloaded.emit(char_id)


func _parse_move(d: Dictionary) -> Dictionary:
	var kb: Dictionary = d.get("knockback", {})
	var hb: Dictionary = d.get("hitbox", {})
	return {
		# Timing (convert frames → seconds)
		"startup":            float(d.get("startup_frames", 6)) / FPS,
		"active":             float(d.get("active_frames", 7)) / FPS,
		"recovery":           float(d.get("recovery_frames", 13)) / FPS,
		# Raw frame counts for inspector display
		"startup_frames":     int(d.get("startup_frames", 6)),
		"active_frames":      int(d.get("active_frames", 7)),
		"recovery_frames":    int(d.get("recovery_frames", 13)),
		# Damage and Ki
		"damage":             float(d.get("damage", 8.0)),
		"ki_cost":            float(d.get("ki_cost", 0.0)),
		"ki_gain_on_hit":     float(d.get("ki_gain_on_hit", 12.0)),
		"ki_gain_on_block":   float(d.get("ki_gain_on_block", 3.0)),
		# Hit reaction
		"stun_time":          float(d.get("stun_time", 0.22)),
		"knockback_x":        float(kb.get("x", 180.0)),
		"knockback_y":        float(kb.get("y", -60.0)),
		# Hitbox
		"reach":              float(hb.get("reach", 55.0)),
		"hit_height":         float(hb.get("height", 42.0)),
		# Juice
		"hit_stop_frames":    int(d.get("hit_stop_frames", 0)),
		"screen_shake":       float(d.get("screen_shake", 0.0)),
		# Block
		"block_damage_mult":  float(d.get("block_damage_mult", 0.20)),
		# Animation / behaviour flags
		"animation":          str(d.get("animation", "light_attack")),
		"projectile":         bool(d.get("projectile", false)),
		"cinematic":          bool(d.get("cinematic", false)),
		"tags":               d.get("tags", []),
	}


## Retrieve a single move dictionary.  Returns a fallback if not found.
func get_move(character_id: String, kind: String) -> Dictionary:
	var upper_id := character_id.to_upper()
	if _move_tables.has(upper_id) and _move_tables[upper_id].has(kind):
		return _move_tables[upper_id][kind]
	push_warning("Grimoire: No move '%s' for '%s', returning fallback" % [kind, upper_id])
	return _get_fallback(kind)


## Retrieve all moves for a character.
func get_all_moves(character_id: String) -> Dictionary:
	return _move_tables.get(character_id.to_upper(), {})


## Re-read every JSON file from disk.  Bind to F5 for live demo.
func hot_reload() -> void:
	print("[Grimoire] Hot-reloading all grimoires…")
	load_all()


## List all loaded character IDs.
func get_loaded_characters() -> Array:
	return _move_tables.keys()


func _get_fallback(kind: String) -> Dictionary:
	# Safe fallback that matches the original hardcoded constants so the game
	# never crashes even if the JSON files are missing.
	var base := {
		"startup": 0.10, "active": 0.12, "recovery": 0.22,
		"startup_frames": 6, "active_frames": 7, "recovery_frames": 13,
		"damage": 8.0, "ki_cost": 0.0,
		"ki_gain_on_hit": 12.0, "ki_gain_on_block": 3.0,
		"stun_time": 0.22,
		"knockback_x": 180.0, "knockback_y": -60.0,
		"reach": 55.0, "hit_height": 42.0,
		"hit_stop_frames": 2, "screen_shake": 0.0,
		"block_damage_mult": 0.20,
		"animation": "light_attack",
		"projectile": false, "cinematic": false, "tags": [],
	}
	match kind:
		"heavy":
			base.merge({
				"startup": 0.233, "active": 0.167, "recovery": 0.417,
				"startup_frames": 14, "active_frames": 10, "recovery_frames": 25,
				"damage": 16.0, "stun_time": 0.38,
				"knockback_x": 320.0, "knockback_y": -80.0,
				"reach": 72.0, "hit_height": 54.0,
				"hit_stop_frames": 4, "screen_shake": 3.0,
				"animation": "heavy_attack",
			}, true)
		"special":
			base.merge({
				"startup": 0.167, "active": 0.183, "recovery": 0.317,
				"startup_frames": 10, "active_frames": 11, "recovery_frames": 19,
				"damage": 24.0, "ki_cost": 40.0, "stun_time": 0.42,
				"knockback_x": 380.0, "knockback_y": -90.0,
				"reach": 76.0, "hit_height": 62.0,
				"hit_stop_frames": 4, "screen_shake": 5.0,
				"animation": "heavy_attack", "projectile": true,
			}, true)
		"ultimate":
			base.merge({
				"startup": 0.35, "active": 0.30, "recovery": 0.483,
				"startup_frames": 21, "active_frames": 18, "recovery_frames": 29,
				"damage": 48.0, "ki_cost": 100.0, "stun_time": 0.65,
				"knockback_x": 520.0, "knockback_y": -140.0,
				"reach": 90.0, "hit_height": 76.0,
				"hit_stop_frames": 8, "screen_shake": 18.0,
				"animation": "heavy_attack", "projectile": true, "cinematic": true,
			}, true)
	return base

