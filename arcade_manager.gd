## ArcadeManager — Controls The Gauntlet Arcade Ladder flow, stages, scoring, and boss encounter.
## Autoload singleton registered as "ArcadeManager" in project.godot.
extends Node

signal stage_completed(stage_info: Dictionary)
signal arcade_cleared(total_score: int, total_time: float)
signal arcade_failed(stage_reached: int)

enum Difficulty { NOVICE, WARRIOR, MASTER }

var is_arcade_active: bool = false
var difficulty_tier: String = "WARRIOR" # "NOVICE", "WARRIOR", "MASTER"
var current_stage: int = 1 # 1 to 4
var total_stages: int = 4
var player_character: String = "KAAL"
var opponent_character: String = "NEX"

var total_score: int = 0
var total_time: float = 0.0
var stage_results: Array[Dictionary] = []

# Difficulty modifiers
const DIFFICULTY_CONFIGS: Dictionary = {
	"NOVICE": {
		"ai_diff_mult": 0.70,
		"score_mult": 1.0,
		"player_dmg_taken_mult": 0.85,
		"label": "Novice",
		"desc": "Forgiving AI reaction speeds, reduced incoming damage."
	},
	"WARRIOR": {
		"ai_diff_mult": 1.0,
		"score_mult": 1.5,
		"player_dmg_taken_mult": 1.0,
		"label": "Warrior",
		"desc": "Standard competitive fight mechanics and adaptive reaction."
	},
	"MASTER": {
		"ai_diff_mult": 1.25,
		"score_mult": 2.5,
		"player_dmg_taken_mult": 1.15,
		"label": "Master",
		"desc": "Hyper-reactive AI, ruthless punish counters, maximum score."
	}
}

# 4 Trials definitions
const STAGE_TEMPLATES: Array[Dictionary] = [
	{
		"stage": 1,
		"name": "TRIAL I: THE INITIATE",
		"subtitle": "Warmup Sparring Match",
		"base_ai_diff": 0.35,
		"hp": 100.0,
		"dmg_mult": 0.90,
		"is_boss": false,
		"title_prefix": "Apprentice"
	},
	{
		"stage": 2,
		"name": "TRIAL II: THE VETERAN",
		"subtitle": "Tactical Combatant",
		"base_ai_diff": 0.65,
		"hp": 100.0,
		"dmg_mult": 1.0,
		"is_boss": false,
		"title_prefix": "Veteran"
	},
	{
		"stage": 3,
		"name": "TRIAL III: THE ASCENDANT",
		"subtitle": "Master of Dimensional Energy",
		"base_ai_diff": 0.85,
		"hp": 115.0,
		"dmg_mult": 1.10,
		"is_boss": false,
		"title_prefix": "Ascendant"
	},
	{
		"stage": 4,
		"name": "FINAL TRIAL: APEX OF POWER",
		"subtitle": "FORMIDABLE BOSS ENCOUNTER",
		"base_ai_diff": 0.95,
		"hp": 160.0,
		"dmg_mult": 1.25,
		"is_boss": true,
		"title_prefix": "OVERDRIVE"
	}
]


func start_arcade(diff: String, p_char: String) -> void:
	is_arcade_active = true
	difficulty_tier = diff.to_upper()
	if not DIFFICULTY_CONFIGS.has(difficulty_tier):
		difficulty_tier = "WARRIOR"

	player_character = p_char.to_upper()
	# Opponent is the other character (or mirror in boss)
	opponent_character = "NEX" if player_character == "KAAL" else "KAAL"

	current_stage = 1
	total_score = 0
	total_time = 0.0
	stage_results.clear()


func get_current_stage_data() -> Dictionary:
	var idx: int = clamp(current_stage - 1, 0, STAGE_TEMPLATES.size() - 1)
	var template: Dictionary = STAGE_TEMPLATES[idx].duplicate()
	
	var diff_cfg: Dictionary = DIFFICULTY_CONFIGS.get(difficulty_tier, DIFFICULTY_CONFIGS["WARRIOR"])
	var diff_mult: float = float(diff_cfg.get("ai_diff_mult", 1.0))
	
	var ai_diff: float = clampf(float(template["base_ai_diff"]) * diff_mult, 0.15, 0.99)
	var is_boss: bool = bool(template["is_boss"])
	
	var opp_name: String = opponent_character
	var display_title: String = ""
	if is_boss:
		display_title = "OVERDRIVE " + opp_name if opp_name == "KAAL" else "VOID " + opp_name
	else:
		display_title = String(template["title_prefix"]) + " " + opp_name

	return {
		"stage": current_stage,
		"total_stages": total_stages,
		"name": String(template["name"]),
		"subtitle": String(template["subtitle"]),
		"opponent_character": opp_name,
		"opponent_title": display_title,
		"ai_difficulty": ai_diff,
		"opponent_hp": float(template["hp"]),
		"opponent_dmg_mult": float(template["dmg_mult"]),
		"is_boss": is_boss,
		"player_dmg_taken_mult": float(diff_cfg.get("player_dmg_taken_mult", 1.0)),
		"score_mult": float(diff_cfg.get("score_mult", 1.0))
	}


func record_stage_victory(remaining_hp: float, stage_time_sec: float, max_combo: int) -> Dictionary:
	var diff_cfg: Dictionary = DIFFICULTY_CONFIGS.get(difficulty_tier, DIFFICULTY_CONFIGS["WARRIOR"])
	var mult: float = float(diff_cfg.get("score_mult", 1.0))

	var base_clear: int = 10000
	var hp_bonus: int = int(clampf(remaining_hp, 0.0, 100.0) * 100.0)
	var time_bonus: int = int(maxf(0.0, (90.0 - stage_time_sec)) * 150.0)
	var combo_bonus: int = max_combo * 500
	var perfect_bonus: int = 25000 if remaining_hp >= 99.5 else 0

	var raw_score: int = base_clear + hp_bonus + time_bonus + combo_bonus + perfect_bonus
	var final_stage_score: int = int(float(raw_score) * mult)

	total_score += final_stage_score
	total_time += stage_time_sec

	var result: Dictionary = {
		"stage": current_stage,
		"remaining_hp": remaining_hp,
		"time": stage_time_sec,
		"max_combo": max_combo,
		"perfect": remaining_hp >= 99.5,
		"base_clear": base_clear,
		"hp_bonus": hp_bonus,
		"time_bonus": time_bonus,
		"combo_bonus": combo_bonus,
		"perfect_bonus": perfect_bonus,
		"multiplier": mult,
		"stage_score": final_stage_score,
		"total_score": total_score
	}

	stage_results.append(result)
	stage_completed.emit(result)
	return result


func advance_stage() -> bool:
	if current_stage < total_stages:
		current_stage += 1
		return true
	else:
		arcade_cleared.emit(total_score, total_time)
		return false


func end_arcade() -> void:
	is_arcade_active = false

