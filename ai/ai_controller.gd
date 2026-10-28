class_name AIController
extends Node

## Adaptive Behavior-Tree AI Controller
## Observes and counters predictable human attack habits using PatternTracker.

enum State {
	NEUTRAL,
	APPROACH,
	RETREAT,
	ATTACK,
	BLOCK,
	PUNISH,
	COUNTER
}

@export var difficulty: float = 0.85
@export var reaction_speed: float = 0.12 # Reaction latency in seconds

var fighter: CharacterBody2D
var opponent: CharacterBody2D
var pattern_tracker: PatternTracker

var current_state: State = State.NEUTRAL
var state_timer: float = 0.0
var decision_cooldown: float = 0.0

# Virtual inputs consumed by fighter.gd
var move_axis: float = 0.0
var want_jump: bool = false
var want_block: bool = false
var want_light: bool = false
var want_heavy: bool = false
var want_special: bool = false
var want_ultimate: bool = false

# Internal tracking
var _recorded_last_opponent_attack: String = ""
var predicted_move: String = "light"
var current_strategy: String = "Observing Habits"
var confidence_rating: float = 0.0

func _ready() -> void:
	fighter = get_parent() as CharacterBody2D
	pattern_tracker = PatternTracker.new()

func _physics_process(delta: float) -> void:
	if fighter == null or fighter.defeated:
		_clear_inputs()
		return

	if opponent == null or not is_instance_valid(opponent):
		opponent = fighter.find_opponent()
		if opponent == null:
			_clear_inputs()
			return

	decision_cooldown -= delta
	state_timer += delta

	_observe_opponent()

	if decision_cooldown <= 0.0:
		_make_decision()
		decision_cooldown = randf_range(reaction_speed * 0.8, reaction_speed * 1.3)

	_execute_state(delta)

func _observe_opponent() -> void:
	if opponent == null:
		return

	var opp_atk: String = opponent.combat_component.attack_kind
	if opp_atk != "":
		if _recorded_last_opponent_attack != opp_atk:
			var context: String = "neutral"
			var dist: float = absf(fighter.global_position.x - opponent.global_position.x)
			if dist < 85.0:
				context = "close_range"
			elif dist > 220.0:
				context = "long_range"
			elif fighter.blocking:
				context = "on_block"

			pattern_tracker.record_action(opp_atk, context)
			_recorded_last_opponent_attack = opp_atk
	else:
		_recorded_last_opponent_attack = ""

func _make_decision() -> void:
	var dist: float = absf(fighter.global_position.x - opponent.global_position.x)
	var context: String = "neutral"
	if dist < 85.0:
		context = "close_range"
	elif dist > 220.0:
		context = "long_range"

	predicted_move = pattern_tracker.predict_next_action(context)
	var summary := pattern_tracker.get_habit_summary()
	confidence_rating = summary.predictability

	# Priority 1: Punish stunned opponent
	if opponent.stun_time > 0.15:
		current_state = State.PUNISH
		current_strategy = "PUNISHING STUN"
		return

	# Priority 2: React to active incoming opponent attack
	if opponent.combat_component.attack_kind != "":
		var incoming: String = opponent.combat_component.attack_kind
		var opp_cc = opponent.combat_component
		var in_startup: bool = opp_cc.attack_time < opp_cc.get_startup_time(incoming)

		# If opponent is in startup of a slow move (heavy or ultimate) and we are close, jab to interrupt!
		if in_startup and (incoming == "heavy" or incoming == "ultimate") and dist <= 75.0:
			if randf() < difficulty:
				current_state = State.COUNTER
				current_strategy = "INTERRUPTING WITH JAB"
				return

		# Otherwise block
		if randf() < (0.65 + difficulty * 0.3):
			current_state = State.BLOCK
			current_strategy = "GUARDING INCOMING %s" % incoming.to_upper()
			return

	# Priority 3: Counter predictable patterns
	if summary.total_attacks >= 3 and summary.predictability >= 0.45:
		if randf() < difficulty:
			current_state = State.COUNTER
			current_strategy = "ADAPTING: COUNTERING %s SPAM" % predicted_move.to_upper()
			return

	# Priority 4: Distance-based tactics
	if dist > 260.0:
		# At range: if we have Ki, use Special wave; otherwise approach
		if fighter.ki >= 40.0 and randf() < 0.6:
			current_state = State.ATTACK
			current_strategy = "ZONING (SPECIAL PROJECTILE)"
		else:
			current_state = State.APPROACH
			current_strategy = "CLOSING DISTANCE"
	elif dist > 90.0:
		# Mid-range: footsies and spacing
		var roll: float = randf()
		if roll < 0.5:
			current_state = State.APPROACH
			current_strategy = "PRESSURING SPACE"
		elif roll < 0.8:
			current_state = State.ATTACK
			current_strategy = "POKING (HEAVY / SPECIAL)"
		else:
			current_state = State.RETREAT
			current_strategy = "BAITING WHIFF"
	else:
		# Close range: inside strike range
		if opponent.blocking:
			# Opponent is turtling: mix up with heavy attack or back off
			if randf() < 0.65:
				current_state = State.ATTACK
				current_strategy = "GUARD PRESSURE"
			else:
				current_state = State.RETREAT
				current_strategy = "RESETTING NEUTRAL"
		else:
			current_state = State.ATTACK
			current_strategy = "FAST MELEE STRIKE"

func _execute_state(_delta: float) -> void:
	_clear_inputs()
	if opponent == null:
		return

	var dx: float = opponent.global_position.x - fighter.global_position.x
	var toward_opponent: float = signf(dx)
	var away_from_opponent: float = -toward_opponent
	var dist: float = absf(dx)

	match current_state:
		State.APPROACH:
			move_axis = toward_opponent
			# Occasionally jump in if approaching from distance
			if dist > 180.0 and randf() < 0.04 and fighter.is_on_floor():
				want_jump = true

		State.RETREAT:
			move_axis = away_from_opponent

		State.BLOCK:
			want_block = true
			# Hold block facing opponent
			move_axis = 0.0

		State.ATTACK:
			_select_attack_by_distance(dist)

		State.PUNISH:
			# Stunned opponent: unload biggest available combo
			if fighter.ki >= 100.0:
				want_ultimate = true
			elif fighter.ki >= 40.0 and dist > 80.0:
				want_special = true
			elif dist <= 80.0:
				want_heavy = true
			else:
				move_axis = toward_opponent

		State.COUNTER:
			_execute_counter_habit(dist)

		State.NEUTRAL:
			move_axis = 0.0

func _select_attack_by_distance(dist: float) -> void:
	if fighter.ki >= 100.0 and randf() < 0.85:
		want_ultimate = true
		return

	if dist <= 65.0:
		# Close range: prefer light jab (fast) or heavy strike
		if randf() < 0.6:
			want_light = true
		else:
			want_heavy = true
	elif dist <= 110.0:
		# Mid strike reach
		if randf() < 0.7:
			want_heavy = true
		elif fighter.ki >= 40.0:
			want_special = true
		else:
			want_light = true
	else:
		# Long range
		if fighter.ki >= 40.0:
			want_special = true
		else:
			# Close in to hit
			move_axis = signf(opponent.global_position.x - fighter.global_position.x)

func _execute_counter_habit(dist: float) -> void:
	match predicted_move:
		"light":
			# Player spams light: block first hit to get frame advantage, or spacing heavy attack
			if dist <= 65.0:
				want_block = true
			else:
				want_heavy = true
		"heavy":
			# Player spams slow heavy: interrupt with fast light attack before startup finishes
			if dist <= 75.0:
				want_light = true
			else:
				want_block = true
		"special":
			# Player likes projectiles: jump over or block
			if dist > 120.0 and fighter.is_on_floor() and randf() < 0.6:
				want_jump = true
				move_axis = signf(opponent.global_position.x - fighter.global_position.x)
			else:
				want_block = true
		"ultimate":
			# Absolute priority: turtle block to reduce 80% damage
			want_block = true
		_:
			_select_attack_by_distance(dist)

func _clear_inputs() -> void:
	move_axis = 0.0
	want_jump = false
	want_block = false
	want_light = false
	want_heavy = false
	want_special = false
	want_ultimate = false

func reset() -> void:
	_clear_inputs()
	current_state = State.NEUTRAL
	state_timer = 0.0
	decision_cooldown = 0.0
	if pattern_tracker:
		pattern_tracker.reset()
