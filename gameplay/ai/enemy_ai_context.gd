class_name EnemyAIContext
extends RefCounted
## Adapter between the rules-only enemy AI and the current level/map systems.
## Construct it with a LevelState and, optionally, the Level's existing
## Pathfinding instance:
##     var context := EnemyAIContext.new(level.level_state, level.pathfinding)

var level_state: LevelState
var pathfinding: Pathfinding


func _init(p_level_state: LevelState = null,
		p_pathfinding: Pathfinding = null) -> void:
	level_state = p_level_state
	pathfinding = p_pathfinding
	if pathfinding == null and level_state != null:
		pathfinding = Pathfinding.new(level_state)


## Current board location for a unit. Unit deliberately does not store position.
func unit_position(unit: Unit) -> Vector2i:
	var state := _find_unit_state(unit)
	if state == null:
		push_error("EnemyAIContext.unit_position: unit is not in this level state.")
		return Vector2i.ZERO
	return state.cell


## Legal cells the unit can end its move on, including its current cell.
## Pathfinding handles terrain costs, hostile blockers and occupied destinations.
func reachable_positions(unit: Unit, from: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var state := _find_unit_state(unit)
	if state == null:
		push_error("EnemyAIContext.reachable_positions: unit is not in this level state.")
		return positions

	var cells: Dictionary
	if from == state.cell:
		var finder := _get_pathfinding()
		if finder == null:
			return positions
		cells = finder.reachable_cells(state, maxi(0, unit.stats.movement))
	else:
		# Pathfinding reads the origin from LevelUnitState.cell. Make a shallow
		# board snapshot with this unit at the requested origin, leaving the live
		# battle state untouched.
		var projected := _projected_board(state, from)
		var projected_board := projected["board"] as LevelState
		var projected_state := projected["unit_state"] as LevelUnitState
		var finder := Pathfinding.new(projected_board)
		cells = finder.reachable_cells(projected_state, maxi(0, unit.stats.movement))

	for cell: Vector2i in cells:
		positions.append(cell)
	return positions


## Whether the attacker's equipped weapon reaches the target from these cells.
## The current combat system has no line-of-sight rules, so weapon range is the
## complete attack-range rule for now.
func can_attack_from(attacker: Unit, attacker_position: Vector2i,
		target: Unit, target_position: Vector2i) -> bool:
	if attacker == null or target == null or level_state == null:
		return false
	var attacker_state := _find_unit_state(attacker)
	var target_state := _find_unit_state(target)
	if attacker_state == null or target_state == null:
		return false
	if not UnitReference.are_hostile(attacker_state.unit_ref, target_state.unit_ref):
		return false
	var difference := attacker_position - target_position
	var distance := absi(difference.x) + absi(difference.y)
	return Combat.can_strike(attacker, distance)


## Combat forecast for the proposed positions, using the same formulas as battle.
## Temporary LevelUnitState wrappers let Combat.forecast read each Unit and the
## terrain under the proposed cells without moving either live unit.
func evaluate_combat(attacker: Unit, attacker_position: Vector2i,
		target: Unit, target_position: Vector2i) -> EnemyAICombatResult:
	if attacker == null or target == null or level_state == null:
		return null
	var attacker_state := _find_unit_state(attacker)
	var target_state := _find_unit_state(target)
	if attacker_state == null or target_state == null:
		return null
	if not UnitReference.are_hostile(attacker_state.unit_ref, target_state.unit_ref):
		return null

	var projected_attacker := _unit_state_at(attacker_state, attacker_position)
	var projected_target := _unit_state_at(target_state, target_position)
	var sides := Combat.forecast(projected_attacker, projected_target, level_state)
	if sides.size() != 2:
		return null

	var attack: ForecastSide = sides[0]
	var counter: ForecastSide = sides[1]
	var result := EnemyAICombatResult.new()
	result.damage_per_hit = attack.damage
	result.hit_chance = attack.hit
	result.attack_count = attack.attack_count
	result.can_counter = counter.can_counter
	result.counter_damage_per_hit = counter.damage
	result.counter_hit_chance = counter.hit
	result.counter_attack_count = counter.attack_count
	return result


## True if another living unit occupies this cell. The moving unit is excluded.
func is_occupied(position: Vector2i, except_unit: Unit) -> bool:
	if level_state == null:
		return false
	for value: Variant in level_state.level_units.values():
		var state := value as LevelUnitState
		if state != null and state.unit != except_unit and state.is_alive() \
				and state.cell == position:
			return true
	return false


## A simple terrain score used to break equally close pursuit-cell ties.
## Defense and avoid stack; FE7 grants neither to flying classes.
func terrain_advantage(unit: Unit, position: Vector2i) -> int:
	if level_state == null or unit == null or unit.class_data() == null:
		return 0
	if unit.class_data().movement_type == Enums.MovementType.FLIER:
		return 0
	var terrain := GameData.terrain_for_tile(level_state.map_data.rules_terrain_at(position))
	if terrain == null:
		return 0
	return terrain.defense + terrain.avoid


func _get_pathfinding() -> Pathfinding:
	if pathfinding == null and level_state != null:
		pathfinding = Pathfinding.new(level_state)
	return pathfinding


func _find_unit_state(unit: Unit) -> LevelUnitState:
	if unit == null or level_state == null:
		return null
	for value: Variant in level_state.level_units.values():
		var state := value as LevelUnitState
		if state != null and state.unit == unit:
			return state
	return null


func _unit_state_at(source: LevelUnitState, position: Vector2i) -> LevelUnitState:
	var projected := LevelUnitState.new()
	projected.unit_ref = source.unit_ref
	projected.unit = source.unit
	projected.cell = position
	projected.has_moved = source.has_moved
	projected.has_acted = source.has_acted
	projected.facing = source.facing
	return projected


func _projected_board(source: LevelUnitState, position: Vector2i) -> Dictionary:
	var board := LevelState.new()
	board.map_data = level_state.map_data
	board.events = level_state.events
	board.level_units = level_state.level_units.duplicate()
	var projected_unit := _unit_state_at(source, position)
	for unit_id: Variant in board.level_units:
		if board.level_units[unit_id] == source:
			board.level_units[unit_id] = projected_unit
			break
	return {"board": board, "unit_state": projected_unit}
