class_name Pathfinding
extends RefCounted
## Grid queries over a LevelState: which cells can be stood on and how to get
## between them. Works in tile cells only; pixels are Level's business.

const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var level_state: LevelState
var astar := AStarGrid2D.new()


func _init(p_level_state: LevelState) -> void:
	level_state = p_level_state
	rebuild()


## Re-reads the map's layers. Call after the drawn cells change; unit
## positions are read fresh on every find_path, so those need no rebuild.
func rebuild() -> void:
	astar = AStarGrid2D.new()
	astar.region = level_state.map_data.bounds()
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	# Manhattan gives long straight runs; the default (Euclidean) staircases
	# along the diagonal, which makes the unit turn on almost every tile.
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	# Any cell some layer draws on is walkable; everything else is not.
	var drawn := level_state.map_data.drawn_cells()
	for x in range(astar.region.position.x, astar.region.end.x):
		for y in range(astar.region.position.y, astar.region.end.y):
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, not drawn.has(cell))


func is_walkable(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell)


## Whether `unit` can walk through `cell`: drawn terrain with no live enemy on it.
## Allies can be passed, so this says nothing about stopping there.
func is_passable(unit: LevelUnitState, cell: Vector2i) -> bool:
	if not is_walkable(cell):
		return false
	for other: LevelUnitState in level_state.level_units.values():
		if other != unit and other.is_alive() and other.cell == cell \
				and UnitReference.are_hostile(unit.unit_ref, other.unit_ref):
			return false
	return true


## Shortest route for `unit` to `target`, starting with the cell it stands on.
## Empty when there is no route or another unit stands on `target`.
func find_path(unit: LevelUnitState, target: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	for other: LevelUnitState in level_state.level_units.values():
		if other.is_alive() and other.cell == target:
			return path
	var blocked := _block_hostiles(unit)
	path = astar.get_id_path(unit.cell, target)
	_unblock(blocked)
	return path


## Every cell `unit` can end a move on within `max_cost` steps (cell -> true).
## Each step costs 1 until terrain data exists. Hostile units block, allies
## can be walked through but not stopped on, and the unit's own cell counts.
func reachable_cells(unit: LevelUnitState, max_cost: int) -> Dictionary:
	var occupied := {}
	for other: LevelUnitState in level_state.level_units.values():
		if other != unit and other.is_alive():
			occupied[other.cell] = true

	var blocked := _block_hostiles(unit)
	var cost := {unit.cell: 0}
	var frontier: Array[Vector2i] = [unit.cell]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		var next_cost: int = cost[cell] + 1
		if next_cost > max_cost:
			continue
		for offset in NEIGHBOURS:
			var next := cell + offset
			if cost.has(next) or not is_walkable(next):
				continue
			cost[next] = next_cost
			frontier.append(next)
	_unblock(blocked)

	var reachable := {}
	for cell in cost:
		if not occupied.has(cell):
			reachable[cell] = true
	return reachable


## Marks the cells of alive units hostile to `unit` solid; returns them for _unblock.
func _block_hostiles(unit: LevelUnitState) -> Array[Vector2i]:
	var marked: Array[Vector2i] = []
	for other: LevelUnitState in level_state.level_units.values():
		if other == unit or not other.is_alive():
			continue
		if UnitReference.are_hostile(unit.unit_ref, other.unit_ref):
			astar.set_point_solid(other.cell)
			marked.append(other.cell)
	return marked


func _unblock(cells: Array[Vector2i]) -> void:
	for cell in cells:
		astar.set_point_solid(cell, false)
