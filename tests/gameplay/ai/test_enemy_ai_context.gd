extends GutTest
## Integration coverage for EnemyAIContext against the real level, pathfinding
## and combat implementations.

const LEVEL_PATH := "res://resources/levels/test_level.json"

var _level_state: LevelState
var _pathfinding: Pathfinding
var _context: EnemyAIContext
var _attacker: LevelUnitState
var _target: LevelUnitState
var _ally: LevelUnitState


func before_each() -> void:
	_level_state = LevelState.load_file(LEVEL_PATH)
	_pathfinding = Pathfinding.new(_level_state)
	_context = EnemyAIContext.new(_level_state, _pathfinding)
	_attacker = _level_state.level_units["lyn"]
	_target = _level_state.level_units["bandit"]
	_ally = _level_state.level_units["wil"]
	_target.cell = _attacker.cell + Vector2i.RIGHT


func test_constructor_uses_supplied_pathfinding_instance() -> void:
	assert_eq(_context.level_state, _level_state)
	assert_eq(_context.pathfinding, _pathfinding)


func test_constructor_creates_pathfinding_when_one_is_not_supplied() -> void:
	var context := EnemyAIContext.new(_level_state)
	assert_not_null(context.pathfinding)
	assert_eq(context.pathfinding.level_state, _level_state)


func test_unit_position_returns_the_level_unit_cell() -> void:
	assert_eq(_context.unit_position(_attacker.unit), _attacker.cell)


func test_unit_position_reports_an_unregistered_unit() -> void:
	var outside_unit := Unit.new(_attacker.unit.data)
	assert_eq(_context.unit_position(outside_unit), Vector2i.ZERO)
	assert_push_error("unit is not in this level state")


func test_reachable_positions_match_real_pathfinding_and_exclude_occupied_cells() -> void:
	var reachable := _as_cell_set(_context.reachable_positions(_attacker.unit, _attacker.cell))
	var expected := _pathfinding.reachable_cells(_attacker, _attacker.unit.stats.movement)

	assert_eq(reachable, expected)
	assert_true(reachable.has(_attacker.cell), "the current cell is included")
	assert_false(reachable.has(_target.cell), "a hostile unit blocks its cell")
	assert_false(reachable.has(_ally.cell), "an ally cannot be a move destination")
	assert_false(reachable.has(Vector2i(3, 5)), "foot units cannot enter sea")


func test_reachable_positions_from_a_projected_origin_do_not_move_the_live_unit() -> void:
	var original_cell := _attacker.cell
	var projected_origin := Vector2i(8, 5)
	var reachable := _as_cell_set(_context.reachable_positions(_attacker.unit, projected_origin))

	assert_true(reachable.has(projected_origin))
	assert_true(reachable.has(projected_origin + Vector2i.RIGHT))
	assert_eq(_attacker.cell, original_cell, "planning must not mutate the live state")
	assert_eq(_context.unit_position(_attacker.unit), original_cell)


func test_reachable_positions_does_not_return_a_hostile_blocker() -> void:
	var blocker_cell := _attacker.cell + Vector2i.RIGHT
	_target.cell = blocker_cell
	var reachable := _context.reachable_positions(_attacker.unit, _attacker.cell)
	assert_false(reachable.has(blocker_cell))


func test_can_attack_from_obeys_a_melee_weapons_range() -> void:
	assert_true(_context.can_attack_from(_attacker.unit, _attacker.cell,
			_target.unit, _target.cell))
	assert_false(_context.can_attack_from(_attacker.unit, _attacker.cell,
			_target.unit, _attacker.cell + Vector2i(3, 0)), "iron sword cannot reach three tiles")


func test_can_attack_from_obeys_a_bows_minimum_and_maximum_range() -> void:
	var one_tile := _attacker.cell + Vector2i.RIGHT
	var two_tiles := _attacker.cell + Vector2i(2, 0)
	var three_tiles := _attacker.cell + Vector2i(3, 0)
	assert_false(_context.can_attack_from(_ally.unit, _attacker.cell, _target.unit, one_tile),
			"a bow cannot attack at range one")
	assert_true(_context.can_attack_from(_ally.unit, _attacker.cell, _target.unit, two_tiles))
	assert_false(_context.can_attack_from(_ally.unit, _attacker.cell, _target.unit, three_tiles),
			"a bow cannot attack beyond range two")


func test_can_attack_from_rejects_allies_and_unregistered_units() -> void:
	assert_false(_context.can_attack_from(_attacker.unit, _attacker.cell,
			_ally.unit, _attacker.cell + Vector2i.DOWN), "player and ally factions are not hostile")
	var outside_unit := Unit.new(_attacker.unit.data)
	assert_false(_context.can_attack_from(outside_unit, _attacker.cell,
			_target.unit, _target.cell))
	assert_false(_context.can_attack_from(_attacker.unit, _attacker.cell,
			outside_unit, _target.cell))


func test_evaluate_combat_matches_the_real_combat_forecast() -> void:
	var expected := Combat.forecast(_attacker, _target, _level_state)
	var result := _context.evaluate_combat(_attacker.unit, _attacker.cell,
			_target.unit, _target.cell)

	assert_not_null(result)
	assert_eq(result.damage_per_hit, expected[0].damage)
	assert_eq(result.hit_chance, expected[0].hit)
	assert_eq(result.attack_count, expected[0].attack_count)
	assert_eq(result.can_counter, expected[1].can_counter)
	assert_eq(result.counter_damage_per_hit, expected[1].damage)
	assert_eq(result.counter_hit_chance, expected[1].hit)
	assert_eq(result.counter_attack_count, expected[1].attack_count)
	assert_eq(result.damage_per_hit, 7)
	assert_eq(result.hit_chance, 100)
	assert_eq(result.attack_count, 2)
	assert_eq(result.counter_damage_per_hit, 12)
	assert_eq(result.counter_hit_chance, 46)


func test_evaluate_combat_uses_both_proposed_positions_for_terrain() -> void:
	var plains_target_result := _context.evaluate_combat(_attacker.unit, _attacker.cell,
			_target.unit, Vector2i(7, 5))
	var plains_attacker_result := _context.evaluate_combat(_attacker.unit, Vector2i(7, 5),
			_target.unit, Vector2i(8, 5))
	_add_forest_cell(Vector2i(7, 5))
	var forest_target_result := _context.evaluate_combat(_attacker.unit, _attacker.cell,
			_target.unit, Vector2i(7, 5))
	var forest_attacker_result := _context.evaluate_combat(_attacker.unit, Vector2i(7, 5),
			_target.unit, Vector2i(8, 5))

	assert_eq(forest_target_result.damage_per_hit, plains_target_result.damage_per_hit - 1,
			"forest defense reduces damage to its occupant")
	assert_eq(forest_target_result.hit_chance, 93,
			"forest avoid applies before the hit chance is clamped")
	assert_eq(forest_attacker_result.counter_hit_chance,
			plains_attacker_result.counter_hit_chance - 20,
			"the counter forecast reads terrain under the proposed attacker cell")
	assert_eq(_attacker.cell, Vector2i(6, 5))
	assert_eq(_target.cell, Vector2i(7, 5), "forecasting must not move live units")


func test_evaluate_combat_returns_null_for_unregistered_or_friendly_units() -> void:
	var outside_unit := Unit.new(_attacker.unit.data)
	assert_null(_context.evaluate_combat(outside_unit, _attacker.cell,
			_target.unit, _target.cell))
	assert_null(_context.evaluate_combat(_attacker.unit, _attacker.cell,
			_ally.unit, _ally.cell))


func test_evaluate_combat_handles_an_unarmed_attacker() -> void:
	var unarmed := _add_unit("unarmed", "fighter", [], "enemy", Vector2i(8, 5))
	var result := _context.evaluate_combat(unarmed.unit, unarmed.cell,
			_attacker.unit, _attacker.cell)

	assert_not_null(result)
	assert_eq(result.damage_per_hit, 0)
	assert_eq(result.attack_count, 0)
	assert_false(result.can_counter, "the defender's sword cannot reach from three tiles")


func test_is_occupied_excludes_the_moving_unit_and_empty_cells() -> void:
	assert_false(_context.is_occupied(_attacker.cell, _attacker.unit))
	assert_false(_context.is_occupied(Vector2i(9, 7), _attacker.unit))
	assert_true(_context.is_occupied(_target.cell, _attacker.unit))
	assert_true(_context.is_occupied(_ally.cell, _attacker.unit))


func test_is_occupied_ignores_dead_units() -> void:
	var cell := _target.cell
	_target.current_hp = 0
	assert_false(_context.is_occupied(cell, _attacker.unit))


func test_terrain_advantage_scores_plains_forest_sea_and_empty_ground() -> void:
	_add_forest_cell(Vector2i(7, 5))
	assert_eq(_context.terrain_advantage(_attacker.unit, Vector2i(9, 5)), 0, "plains")
	assert_eq(_context.terrain_advantage(_attacker.unit, Vector2i(7, 5)), 21, "forest defense + avoid")
	assert_eq(_context.terrain_advantage(_attacker.unit, Vector2i(3, 5)), 10, "sea avoid")
	assert_eq(_context.terrain_advantage(_attacker.unit, Vector2i(0, 0)), 0, "no terrain")


func test_fliers_receive_no_terrain_advantage() -> void:
	_add_forest_cell(Vector2i(7, 5))
	var flier := _add_unit("flier", "pegasus_knight", ["iron_lance"],
			"player", Vector2i(5, 5))
	assert_eq(_context.terrain_advantage(flier.unit, Vector2i(7, 5)), 0)


func _add_unit(id: String, class_id: String, items: Array,
		faction: String, cell: Vector2i) -> LevelUnitState:
	var ref := UnitReference.fromJson(id, {
		"class": class_id,
		"items": items,
		"faction": faction,
		"start_cell": [cell.x, cell.y],
	})
	_level_state.map_data.units[id] = ref
	var state := LevelUnitState.from_reference(ref)
	_level_state.level_units[id] = state
	return state


func _add_forest_cell(cell: Vector2i) -> void:
	var vertices: Array = [
		[cell.x, cell.y],
		[cell.x + 1, cell.y],
		[cell.x, cell.y + 1],
		[cell.x + 1, cell.y + 1],
	]
	_level_state.map_data.layers["test_forest"] = MapLayer.fromJson("test_forest", {
		"z": 1,
		"terrain": "trees",
		"verts": vertices,
	})
	_level_state.map_data.invalidate_terrain_cache()


func _as_cell_set(cells: Array[Vector2i]) -> Dictionary:
	var result := {}
	for cell in cells:
		result[cell] = true
	return result
