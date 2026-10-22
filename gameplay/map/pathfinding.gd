class_name Pathfinding
extends RefCounted
## Grid movement over a LevelState: which cells a unit can enter, what each step
## costs for its class's movement group, which cells it can reach, and the
## cheapest route between two cells. Works in tile cells only; pixels are Level's
## business.
##
## A cell's terrain is MapData.rules_terrain_at (the majority rule) looked up in
## GameData; its cost is that terrain's cost for the unit's movement group.
## Hostile units block, allies can be walked through but not stopped on.

const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## path_cost of a route through impassable terrain: never affordable.
const UNAFFORDABLE := 1 << 30

var level_state: LevelState


func _init(p_level_state: LevelState) -> void:
	level_state = p_level_state
	rebuild()


## Re-reads the map. Call after its layers change; unit positions are read fresh
## on every query, so those need no rebuild.
func rebuild() -> void:
	level_state.map_data.invalidate_terrain_cache()


## The terrain rules for `cell`, or null where nothing (or too little) is drawn.
func terrain_at(cell: Vector2i) -> TerrainData:
	return GameData.terrain_for_tile(level_state.map_data.rules_terrain_at(cell))


## Whether `cell` has terrain at all. Who can enter it depends on the unit; see
## move_cost and is_passable.
func is_walkable(cell: Vector2i) -> bool:
	return terrain_at(cell) != null


## Movement points for `unit` to step onto `cell`, or TerrainData.IMPASSABLE.
## Ignores other units.
func move_cost(unit: LevelUnitState, cell: Vector2i) -> int:
	var terrain := terrain_at(cell)
	if terrain == null:
		return TerrainData.IMPASSABLE
	return terrain.move_cost(unit.unit.class_data().movement_type)


## Whether `unit` can walk through `cell`: terrain it can enter, with no live enemy
## on it. Allies can be passed, so this says nothing about stopping there.
func is_passable(unit: LevelUnitState, cell: Vector2i) -> bool:
	return move_cost(unit, cell) != TerrainData.IMPASSABLE and not _hostile_cells(unit).has(cell)


## Total movement cost of walking `path` (which starts on the unit's cell), or
## UNAFFORDABLE if any step is impassable.
func path_cost(unit: LevelUnitState, path: Array[Vector2i]) -> int:
	var total := 0
	for i in range(1, path.size()):
		var cost := move_cost(unit, path[i])
		if cost == TerrainData.IMPASSABLE:
			return UNAFFORDABLE
		total += cost
	return total


## Every cell `unit` can end a move on within `max_cost` movement points
## (cell -> true), including its own cell. Cells other live units stand on are
## left out.
func reachable_cells(unit: LevelUnitState, max_cost: int) -> Dictionary:
	var occupied := _occupied_cells(unit)
	var reachable := {}
	for cell in _search(unit, max_cost).cost:
		if not occupied.has(cell):
			reachable[cell] = true
	return reachable


## The cheapest route for `unit` to `target`, starting with the cell it stands on.
## Empty when there's no route or another live unit stands on `target`. Equal-cost
## routes are broken the same way every time.
func find_path(unit: LevelUnitState, target: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if _occupied_cells(unit).has(target):
		return path
	var result := _search(unit, UNAFFORDABLE)
	if not result.cost.has(target):
		return path
	var cell := target
	while cell != unit.cell:
		path.push_front(cell)
		cell = result.previous[cell]
	path.push_front(unit.cell)
	return path


## Dijkstra from `unit`'s cell, out to `max_cost`. Returns {cost: cell -> int,
## previous: cell -> cell}. Movement costs are small whole numbers, so cells are
## processed in buckets of equal cost; within a bucket, first in is first out and
## neighbours go up, right, down, left, which makes ties deterministic.
func _search(unit: LevelUnitState, max_cost: int) -> Dictionary:
	var hostile := _hostile_cells(unit)
	var cost := {unit.cell: 0}
	var previous := {}
	var buckets := {0: [unit.cell]}
	var current := 0
	var largest := 0
	while current <= largest:
		var bucket: Array = buckets.get(current, [])
		var i := 0
		while i < bucket.size():
			var cell: Vector2i = bucket[i]
			i += 1
			if cost[cell] != current:
				continue  # reached more cheaply after being queued here
			for offset in NEIGHBOURS:
				var next := cell + offset
				if hostile.has(next):
					continue
				var step := move_cost(unit, next)
				if step == TerrainData.IMPASSABLE:
					continue
				var total := current + step
				if total > max_cost or (cost.has(next) and cost[next] <= total):
					continue
				cost[next] = total
				previous[next] = cell
				if not buckets.has(total):
					buckets[total] = []
				buckets[total].append(next)
				largest = maxi(largest, total)
		buckets.erase(current)
		current += 1
	return {"cost": cost, "previous": previous}


## Cells of live units hostile to `unit`.
func _hostile_cells(unit: LevelUnitState) -> Dictionary:
	var cells := {}
	for other: LevelUnitState in level_state.level_units.values():
		if other != unit and other.is_alive() and UnitReference.are_hostile(unit.unit_ref, other.unit_ref):
			cells[other.cell] = true
	return cells


## Cells of every other live unit (where `unit` can't stop).
func _occupied_cells(unit: LevelUnitState) -> Dictionary:
	var cells := {}
	for other: LevelUnitState in level_state.level_units.values():
		if other != unit and other.is_alive():
			cells[other.cell] = true
	return cells
