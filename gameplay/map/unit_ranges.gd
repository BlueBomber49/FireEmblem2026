class_name UnitRanges
extends RefCounted
## Where a unit can move this turn and what it could attack after moving, with
## any weapon it carries that its class can use (not just the equipped one).
## Used for the hover ranges and the enemy danger zone. Healing and staff ranges
## aren't included yet.

## cell -> true: where the unit can end a move (blue).
var move_cells: Dictionary = {}
## cell -> true: every cell it could attack, from any move cell (the danger zone).
var threat_cells: Dictionary = {}
## cell -> true: threat_cells outside move_cells (the red fringe around the blue).
var attack_cells: Dictionary = {}


## Builds the ranges for `state` on its current board. Hostile units block its
## movement, so the result depends on where everyone stands. With `stays_put`,
## the unit only attacks from its own cell (an enemy the AI never moves).
## Threat outside `bounds` is dropped.
static func compute(pathfinding: Pathfinding, state: LevelUnitState, bounds: Rect2i,
		stays_put := false) -> UnitRanges:
	var ranges := UnitRanges.new()
	if stays_put:
		ranges.move_cells = {state.cell: true}
	else:
		ranges.move_cells = pathfinding.reachable_cells(state, state.unit.stats.movement)
	var offsets := _offsets(attack_distances(state.unit))
	for cell: Vector2i in ranges.move_cells:
		for offset in offsets:
			var target: Vector2i = cell + offset
			if bounds.has_point(target):
				ranges.threat_cells[target] = true
	for cell: Vector2i in ranges.threat_cells:
		if not ranges.move_cells.has(cell):
			ranges.attack_cells[cell] = true
	return ranges


## Every distance `unit` can attack at, smallest first: the union of the ranges of
## the weapons it carries that its class can use. Empty without one.
static func attack_distances(unit: Unit) -> Array[int]:
	var distances: Array[int] = []
	for i in unit.inventory.size():
		var weapon := unit.inventory.get_item(i).data as WeaponData
		if weapon == null or not unit.class_data().can_wield(weapon):
			continue
		for distance in range(weapon.min_range, weapon.max_range + 1):
			if not distances.has(distance):
				distances.append(distance)
	distances.sort()
	return distances


## The cell offsets at exactly each of `distances` (Manhattan).
static func _offsets(distances: Array[int]) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for distance in distances:
		for dx in range(-distance, distance + 1):
			var dy := distance - absi(dx)
			offsets.append(Vector2i(dx, dy))
			if dy != 0:
				offsets.append(Vector2i(dx, -dy))
	return offsets
