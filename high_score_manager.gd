## High Score Manager — Saves and loads local arcade leaderboard to user://
## Autoload singleton registered as "HighScoreManager" in project.godot.
extends Node

const SAVE_PATH := "user://mystik_highscores.json"
const MAX_SCORES := 8

var _scores: Array[Dictionary] = []

func _ready() -> void:
	load_scores()

func get_scores() -> Array[Dictionary]:
	return _scores.duplicate()

func is_high_score(score: int) -> bool:
	if _scores.size() < MAX_SCORES:
		return true
	return score > int(_scores[-1].get("score", 0))

func add_score(player_name: String, score: int, clear_time_sec: float, char_name: String, diff: String) -> void:
	var entry: Dictionary = {
		"name": player_name.to_upper().strip_edges().substr(0, 8),
		"score": score,
		"time": clear_time_sec,
		"character": char_name.to_upper(),
		"difficulty": diff.to_upper(),
		"date": Time.get_date_string_from_system()
	}
	_scores.append(entry)
	_scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	if _scores.size() > MAX_SCORES:
		_scores = _scores.slice(0, MAX_SCORES)
	save_scores()

func save_scores() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("HighScoreManager: Failed to write to %s" % SAVE_PATH)
		return
	var json_str := JSON.stringify(_scores, "\t")
	file.store_string(json_str)
	file.close()

func load_scores() -> void:
	_scores.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		_populate_default_lore_scores()
		save_scores()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_populate_default_lore_scores()
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK or not (json.data is Array):
		_populate_default_lore_scores()
		return

	for item in json.data:
		if item is Dictionary:
			_scores.append(item)

	if _scores.size() == 0:
		_populate_default_lore_scores()

func _populate_default_lore_scores() -> void:
	_scores = [
		{"name": "SHADOW", "score": 85000, "time": 95.4, "character": "KAAL", "difficulty": "MASTER", "date": "LEGEND"},
		{"name": "PHANTOM", "score": 68000, "time": 124.2, "character": "NEX", "difficulty": "MASTER", "date": "LEGEND"},
		{"name": "DRAGON", "score": 52000, "time": 145.8, "character": "KAAL", "difficulty": "WARRIOR", "date": "VETERAN"},
		{"name": "CYBER", "score": 41000, "time": 168.0, "character": "NEX", "difficulty": "WARRIOR", "date": "VETERAN"},
		{"name": "ROOKIE", "score": 25000, "time": 210.5, "character": "KAAL", "difficulty": "NOVICE", "date": "NOVICE"}
	]
