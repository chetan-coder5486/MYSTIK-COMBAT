class_name SelectionModel
extends RefCounted
## Pure selection state for a two-player character select. No nodes, no input.
##
## Keeping this separate from the screen means the rules (grid wrap-around,
## lock/unlock, mirror-match restriction) are testable without a scene tree,
## and the view only has to react to the two signals below.

signal cursor_moved(slot: int, index: int)
signal lock_changed(slot: int, locked: bool)

const SLOT_COUNT: int = 2

var roster_size: int
var columns: int
var allow_mirror: bool

var _cursor: Array[int] = []
var _locked: Array[bool] = []


func _init(
	p_roster_size: int,
	p_columns: int = 4,
	p_allow_mirror: bool = true,
	p_start_indices: Array[int] = [0, 1]
) -> void:
	assert(p_roster_size > 0, "SelectionModel needs at least one fighter.")
	roster_size = p_roster_size
	columns = clampi(p_columns, 1, p_roster_size)
	allow_mirror = p_allow_mirror
	for slot in SLOT_COUNT:
		var start: int = p_start_indices[slot] if slot < p_start_indices.size() else 0
		_cursor.append(clampi(start, 0, roster_size - 1))
		_locked.append(false)


func cursor(slot: int) -> int:
	return _cursor[slot]


func is_locked(slot: int) -> bool:
	return _locked[slot]


func any_locked() -> bool:
	return _locked.has(true)


func all_locked() -> bool:
	return not _locked.has(false)


## Moves a slot's cursor one step on the grid, wrapping at the edges.
## Ignored while that slot is locked in.
@warning_ignore("integer_division")
func move_cursor(slot: int, direction: Vector2i) -> void:
	if _locked[slot] or direction == Vector2i.ZERO:
		return
	var index: int = _cursor[slot]
	var row: int = index / columns
	var col: int = index % columns
	var row_count: int = ceili(float(roster_size) / columns)
	if direction.x != 0:
		var row_length: int = mini(columns, roster_size - row * columns)
		col = posmod(col + direction.x, row_length)
	else:
		row = posmod(row + direction.y, row_count)
		col = mini(col, mini(columns, roster_size - row * columns) - 1)
	_apply_cursor(slot, row * columns + col)


func set_cursor(slot: int, index: int) -> void:
	if _locked[slot]:
		return
	_apply_cursor(slot, clampi(index, 0, roster_size - 1))


## Returns false when the lock is refused (already locked, or a mirror match
## is disallowed and the other slot has locked this fighter).
func lock(slot: int) -> bool:
	if _locked[slot]:
		return false
	var other: int = 1 - slot
	if not allow_mirror and _locked[other] and _cursor[other] == _cursor[slot]:
		return false
	_locked[slot] = true
	lock_changed.emit(slot, true)
	return true


func unlock(slot: int) -> bool:
	if not _locked[slot]:
		return false
	_locked[slot] = false
	lock_changed.emit(slot, false)
	return true


func _apply_cursor(slot: int, index: int) -> void:
	if index == _cursor[slot]:
		return
	_cursor[slot] = index
	cursor_moved.emit(slot, index)
