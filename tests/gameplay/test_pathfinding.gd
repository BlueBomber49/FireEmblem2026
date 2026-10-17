extends GutTest

const LEVEL_PATH := "res://resources/levels/test_level.json"

var state: LevelState
var pathfinding: Pathfinding


func before_each() -> void:
	state = LevelState.load_file(LEVEL_PATH)
	pathfinding = Pathfinding.new(state)


func test_drawn_cells_are_walkable() -> void:
	assert_true(pathfinding.is_walkable(Vector2i(0, 0)), "water edge is drawn, so walkable for now")
	assert_false(pathfinding.is_walkable(Vector2i(30, 30)), "outside every layer")


func test_path_starts_on_the_unit_and_ends_on_the_target() -> void:
	var lyn: LevelUnitState = state.level_units["lyn"]
	var path := pathfinding.find_path(lyn, Vector2i(8, 5))
	assert_eq(path.size(), 3)
	assert_eq(path[0], lyn.cell)
	assert_eq(path[-1], Vector2i(8, 5))


func test_find_path_leaves_the_grid_as_it_found_it() -> void:
	var wil: LevelUnitState = state.level_units["wil"]
	pathfinding.find_path(state.level_units["lyn"], Vector2i(8, 5))
	assert_true(pathfinding.is_walkable(wil.cell), "another unit's cell is still a walkable cell")


# --- Other units -----------------------------------------------------------
# lyn (player) stands on (6, 5) and walks to (8, 5); the straight route is
# three cells long and crosses (7, 5), where each test parks another unit.

const MIDDLE := Vector2i(7, 5)
const TARGET := Vector2i(8, 5)


func test_hostile_unit_in_the_way_forces_a_detour() -> void:
	state.level_units["bandit"].cell = MIDDLE
	var path := pathfinding.find_path(state.level_units["lyn"], TARGET)
	assert_false(path.has(MIDDLE), "can't walk through an enemy")
	assert_eq(path.size(), 5, "one row over, along, and back")
	assert_eq(path[-1], TARGET)


func test_friendly_unit_in_the_way_does_not_block() -> void:
	state.level_units["wil"].cell = MIDDLE
	var path := pathfinding.find_path(state.level_units["lyn"], TARGET)
	assert_eq(path.size(), 3)
	assert_true(path.has(MIDDLE), "an ally is walked straight through")


func test_hostility_is_judged_from_the_moving_unit() -> void:
	var bandit: LevelUnitState = state.level_units["bandit"]
	bandit.cell = Vector2i(6, 5)
	state.level_units["lyn"].cell = MIDDLE
	var path := pathfinding.find_path(bandit, TARGET)
	assert_false(path.has(MIDDLE), "a player unit blocks an enemy just the same")
	assert_eq(path.size(), 5)


func test_dead_hostile_unit_does_not_block() -> void:
	var bandit: LevelUnitState = state.level_units["bandit"]
	bandit.cell = MIDDLE
	bandit.current_hp = 0
	assert_eq(pathfinding.find_path(state.level_units["lyn"], TARGET).size(), 3)


func test_occupied_target_has_no_path() -> void:
	var lyn: LevelUnitState = state.level_units["lyn"]
	state.level_units["wil"].cell = TARGET
	assert_eq(pathfinding.find_path(lyn, TARGET).size(), 0, "can't stop on an ally")
	state.level_units["wil"].cell = Vector2i(6, 7)
	state.level_units["bandit"].cell = TARGET
	assert_eq(pathfinding.find_path(lyn, TARGET).size(), 0, "nor on an enemy")


func test_dead_unit_does_not_occupy_its_cell() -> void:
	var wil: LevelUnitState = state.level_units["wil"]
	wil.cell = TARGET
	wil.current_hp = 0
	assert_eq(pathfinding.find_path(state.level_units["lyn"], TARGET).size(), 3)


func test_hostile_cells_are_walkable_again_afterwards() -> void:
	state.level_units["bandit"].cell = MIDDLE
	pathfinding.find_path(state.level_units["lyn"], TARGET)
	assert_true(pathfinding.is_walkable(MIDDLE), "the block lasts for one find_path only")


# --- Reachable cells -------------------------------------------------------


func test_reachable_cells_within_one_step() -> void:
	var lyn: LevelUnitState = state.level_units["lyn"]
	var cells := pathfinding.reachable_cells(lyn, 1)
	assert_eq(cells.size(), 5, "own cell plus four neighbours")
	assert_true(cells.has(lyn.cell), "the unit can stay where it is")
	assert_true(cells.has(Vector2i(7, 5)))
	assert_false(cells.has(Vector2i(8, 5)), "two steps away")


func test_reachable_cells_stop_at_the_map_edge() -> void:
	var lyn: LevelUnitState = state.level_units["lyn"]
	assert_false(pathfinding.reachable_cells(lyn, 50).has(Vector2i(30, 30)))


func test_hostile_unit_blocks_reach() -> void:
	state.level_units["bandit"].cell = MIDDLE
	var cells := pathfinding.reachable_cells(state.level_units["lyn"], 1)
	assert_false(cells.has(MIDDLE))
	assert_eq(cells.size(), 4)


func test_ally_can_be_passed_but_not_stopped_on() -> void:
	state.level_units["wil"].cell = MIDDLE
	var cells := pathfinding.reachable_cells(state.level_units["lyn"], 2)
	assert_false(cells.has(MIDDLE), "can't end on an ally")
	assert_true(cells.has(TARGET), "but can walk through one")


func test_reachable_cells_leave_the_grid_as_they_found_it() -> void:
	state.level_units["bandit"].cell = MIDDLE
	pathfinding.reachable_cells(state.level_units["lyn"], 3)
	assert_true(pathfinding.is_walkable(MIDDLE))


# --- Passability -------------------------------------------------------------


func test_is_passable_blocks_terrain_and_enemies_but_not_allies() -> void:
	var lyn: LevelUnitState = state.level_units["lyn"]
	assert_true(pathfinding.is_passable(lyn, Vector2i(7, 5)))
	assert_false(pathfinding.is_passable(lyn, Vector2i(30, 30)), "off the map")
	assert_true(pathfinding.is_passable(lyn, state.level_units["wil"].cell), "an ally")
	assert_false(pathfinding.is_passable(lyn, state.level_units["bandit"].cell), "an enemy")
	state.level_units["bandit"].current_hp = 0
	assert_true(pathfinding.is_passable(lyn, state.level_units["bandit"].cell), "a dead enemy")
