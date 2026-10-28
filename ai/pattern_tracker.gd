class_name PatternTracker
extends RefCounted

## Tracks the human player's attack patterns, spacing tendencies, and habit sequences.
## Maintains a sliding-window frequency distribution to predict the opponent's next move.

const HISTORY_SIZE := 50
const SEQUENCE_WINDOW := 3

var action_history: Array[Dictionary] = [] # {action: String, context: String, timestamp: int}
var attack_frequency: Dictionary = {
	"light": 0,
	"heavy": 0,
	"special": 0,
	"ultimate": 0,
	"block": 0,
	"jump": 0
}
var sequence_counts: Dictionary = {} # "light,heavy" -> count
var context_patterns: Dictionary = {} # "wake_up" -> {"light": 4, "block": 1}

func record_action(action: String, context: String = "neutral") -> void:
	var entry: Dictionary = {
		"action": action,
		"context": context,
		"time": Time.get_ticks_msec()
	}
	action_history.append(entry)

	if action_history.size() > HISTORY_SIZE:
		var removed: Dictionary = action_history.pop_front()
		if attack_frequency.has(removed.action):
			attack_frequency[removed.action] = max(0, attack_frequency[removed.action] - 1)

	if attack_frequency.has(action):
		attack_frequency[action] += 1
	else:
		attack_frequency[action] = 1

	# Update 2-step sequence
	if action_history.size() >= 2:
		var prev_act: String = action_history[-2].action
		var seq_key := "%s->%s" % [prev_act, action]
		sequence_counts[seq_key] = sequence_counts.get(seq_key, 0) + 1

	# Update context pattern
	if not context_patterns.has(context):
		context_patterns[context] = {}
	var ctx_dict: Dictionary = context_patterns[context]
	ctx_dict[action] = ctx_dict.get(action, 0) + 1

func predict_next_action(current_context: String = "neutral") -> String:
	# 1. Check context-specific tendencies (e.g. what does player do after getting hit or close range)
	if context_patterns.has(current_context):
		var ctx_dict: Dictionary = context_patterns[current_context]
		var best_ctx_action := ""
		var max_ctx_count := 0
		for act in ctx_dict:
			if ctx_dict[act] > max_ctx_count:
				max_ctx_count = ctx_dict[act]
				best_ctx_action = act
		if max_ctx_count >= 3:
			return best_ctx_action

	# 2. Check Markov sequence prediction (what do they do after their last move?)
	if action_history.size() >= 1:
		var last_action: String = action_history[-1].action
		var prefix := "%s->" % last_action
		var best_seq_action := ""
		var max_seq_count := 0
		for seq in sequence_counts:
			if seq.begins_with(prefix):
				if sequence_counts[seq] > max_seq_count:
					max_seq_count = sequence_counts[seq]
					best_seq_action = seq.substr(prefix.length())
		if max_seq_count >= 2:
			return best_seq_action

	# 3. Frequency heuristic (dominant attack tendency)
	return get_most_frequent_attack()

func get_most_frequent_attack() -> String:
	var best_act := "light"
	var max_count := -1
	for act in ["light", "heavy", "special", "ultimate"]:
		var cnt: int = attack_frequency.get(act, 0)
		if cnt > max_count:
			max_count = cnt
			best_act = act
	return best_act

func get_habit_summary() -> Dictionary:
	var total_attacks := 0
	for act in ["light", "heavy", "special", "ultimate"]:
		total_attacks += attack_frequency.get(act, 0)

	var dominant := get_most_frequent_attack()
	var predictability: float = 0.0
	if total_attacks > 0:
		predictability = float(attack_frequency.get(dominant, 0)) / float(total_attacks)

	return {
		"dominant": dominant,
		"predictability": clampf(predictability, 0.0, 1.0),
		"total_actions": action_history.size(),
		"total_attacks": total_attacks,
		"frequencies": attack_frequency.duplicate()
	}

func reset() -> void:
	action_history.clear()
	for k in attack_frequency:
		attack_frequency[k] = 0
	sequence_counts.clear()
	context_patterns.clear()

