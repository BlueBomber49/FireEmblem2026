class_name DangerZone
extends RefCounted
## Which enemy threat the map shows: every enemy's when the danger zone is on,
## and marked enemies' always (drawn a deeper red). Only enemies count; players
## and allies never do. Battle owns one, recomputes it whenever units move or
## die, and draws normal_cells and marked_cells.

## The global danger-zone toggle.
var enabled := false
## unit id -> true for each marked enemy.
var marked: Dictionary = {}
## cell -> true: threat of unmarked enemies, while enabled.
var normal_cells: Dictionary = {}
## cell -> true: threat of marked enemies. A cell in both sets is only here.
var marked_cells: Dictionary = {}


func toggle() -> void:
	enabled = not enabled


func toggle_mark(unit_id: String) -> void:
	if marked.has(unit_id):
		marked.erase(unit_id)
	else:
		marked[unit_id] = true


func is_marked(unit_id: String) -> bool:
	return marked.has(unit_id)


## Forgets marks on enemies that have died or left the level.
func drop_dead_marks(level_state: LevelState) -> void:
	for unit_id: String in marked.keys():
		var state: LevelUnitState = level_state.level_units.get(unit_id)
		if state == null or not state.is_alive():
			marked.erase(unit_id)


## Rebuilds both cell sets from where everyone stands now. `stays_put` is called
## with each enemy's id and says whether it only attacks from its own cell.
func recompute(level_state: LevelState, pathfinding: Pathfinding, stays_put: Callable) -> void:
	drop_dead_marks(level_state)
	normal_cells = {}
	marked_cells = {}
	var bounds := level_state.map_data.bounds()
	for state: LevelUnitState in level_state.level_units.values():
		if not state.is_alive() or state.unit_ref.faction != UnitReference.Faction.ENEMY:
			continue
		var unit_id := state.unit_ref.id
		var is_marked_enemy := marked.has(unit_id)
		if not enabled and not is_marked_enemy:
			continue
		var threat := UnitRanges.compute(pathfinding, state, bounds, stays_put.call(unit_id)).threat_cells
		if is_marked_enemy:
			marked_cells.merge(threat)
		else:
			normal_cells.merge(threat)
	for cell: Vector2i in marked_cells:
		normal_cells.erase(cell)
