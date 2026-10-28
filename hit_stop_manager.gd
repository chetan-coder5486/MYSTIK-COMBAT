## Hit-Stop Manager — Freezes fighters on hit impact without pausing the engine,
## allowing background music, particles, and screen shake to continue uninterrupted.
##
## Autoload singleton registered as "HitStop" in project.godot.
extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree().paused:
		get_tree().paused = false


## Trigger a hit-stop freeze for the given number of frames (at 60 FPS).
## Freezes characters directly without touching get_tree().paused, keeping audio flawless.
func trigger(frames: int) -> void:
	if frames <= 0:
		return
	var duration: float = float(frames) / 60.0
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if fighter is CharacterBody2D and "hit_stop_time" in fighter and not fighter.defeated:
			fighter.hit_stop_time = maxf(fighter.hit_stop_time, duration)

