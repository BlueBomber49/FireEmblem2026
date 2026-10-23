extends GutTest
## Movement over terrain. test_level is grass (plains) from x 4-11, y 3-8, ringed
## by water (sea); lyn (Myrmidon, foot) stands on (6, 5).

const LEVEL_PATH := "res://resources/levels/test_level.json"

var state: LevelState
var pathfinding: Pathfinding


func before_each() -> void:
	state = LevelState.load_file(LEVEL_PATH)
	pathfinding = Pathfinding.new(state)


func test_cells_with_terrain_are_walkable_cells() -> void:
	assert_true(pathfinding.is_walkable(Vector2i(6, 5)), "grass")
	assert_true(pathfinding.is_walkable(Vector2i(1, 1)), "water is still terrain; who can enter it is per unit")
	assert_false(pathfinding.is_walkable(Vector2i(0, 0)), "a mostly-blank corner cell")
	assert_false(pathfinding.is_walkable(Vector2i(30, 30)), "outside every layer")


func test_path_starts_on_the_unit_and_ends_on_the_target() -> void:
	var lyn: LevelUnitState = state.level_units["lyn"]
	var path := pathfinding.find_path(lyn, Vector2i(8, 5))
	assert_eq(path.size(), 3)
	assert_eq(path[0], lyn.cell)
	assert_eq(path[-1], Vector2i(8, 5))


func test_find_path_is_deterministic() -> void:
	var lyn: LevelUnitState = state.level_units["lyn"]
	assert_eq(pathfinding.find_path(lyn, Vector2i(9, 7)), pathfinding.find_path(lyn, Vector2i(9, 7)))


# --- Other units -----------------------------------------------------------
# lyn walks from (6, 5) to (8, 5); the straight route crosses (7, 5), where
# each test parks another unit.

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


# --- Terrain ---------------------------------------------------------------------


func test_water_stops_foot_units() -> void:
	var lyn: LevelUnitState = state.level_units["lyn"]
	var cells := pathfinding.reachable_cells(lyn, 50)
	assert_false(cells.has(Vector2i(3, 5)), "the sea next to the grass")
	assert_true(cells.has(Vector2i(4, 5)), "the last grass cell")
	assert_eq(pathfinding.move_cost(lyn, Vector2i(3, 5)), TerrainData.IMPASSABLE)
	assert_false(pathfinding.is_passable(lyn, Vector2i(3, 5)))


func test_starting_cells_are_passable_in_both_levels() -> void:
	for path in [LEVEL_PATH, "res://resources/levels/simple_level.json"]:
		var level_state := LevelState.load_file(path)
		var finder := Pathfinding.new(level_state)
		for id in level_state.level_units:
			var unit: LevelUnitState = level_state.level_units[id]
			assert_ne(finder.move_cost(unit, unit.cell), TerrainData.IMPASSABLE, "%s: %s" % [path.get_file(), id])


## A strip: grass everywhere (x 0-9, y 0-5), a tree patch on cell (3, 1), and a
## water column on cells (5, 1)-(5, 3) with grass rows above and below it.
## Forest = (3, 1) plus the half-tree edges around it: (2, 1), (4, 1), (3, 0), (3, 2).
## The diagonal corners (2, 0), (4, 0), (2, 2), (4, 2) only show a nub: plains.
func _strip() -> LevelState:
	var grass := []
	for x in 11:
		for y in 7:
			grass.append([x, y])
	var water := []
	for x in [5, 6]:
		for y in [1, 2, 3, 4]:
			water.append([x, y])
	return LevelState.fromJson({"map_data": {"layers": {
		"grass": {"z": 0, "terrain": "grass", "verts": grass},
		"trees": {"z": 1, "terrain": "trees", "verts": [[3, 1], [4, 1], [3, 2], [4, 2]]},
		"water": {"z": 2, "terrain": "water", "verts": water},
	}}})


func _put(level_state: LevelState, class_id: String, cell: Vector2i) -> LevelUnitState:
	var ref := UnitReference.fromJson(class_id, {"class": class_id, "faction": "player",
		"start_cell": [cell.x, cell.y]})
	level_state.map_data.units[class_id] = ref
	var unit := LevelUnitState.from_reference(ref)
	level_state.level_units[class_id] = unit
	return unit


func test_half_tree_edge_is_forest_and_corner_nub_is_plains() -> void:
	var level_state := _strip()
	var fighter := _put(level_state, "fighter", Vector2i(0, 4))
	var finder := Pathfinding.new(level_state)
	assert_eq(finder.move_cost(fighter, Vector2i(2, 1)), 2, "half-tree edge: forest")
	assert_eq(finder.move_cost(fighter, Vector2i(2, 2)), 1, "corner nub: plains")


func test_forest_costs_two_for_foot_units() -> void:
	var level_state := _strip()
	var fighter := _put(level_state, "fighter", Vector2i(2, 1))
	var finder := Pathfinding.new(level_state)
	assert_eq(finder.move_cost(fighter, Vector2i(3, 1)), 2)
	assert_false(finder.reachable_cells(fighter, 1).has(Vector2i(3, 1)))
	assert_true(finder.reachable_cells(fighter, 2).has(Vector2i(3, 1)))


func test_forest_costs_three_for_cavalry_and_one_for_fliers() -> void:
	var level_state := _strip()
	var cavalier := _put(level_state, "cavalier", Vector2i(2, 1))
	var pegasus := _put(level_state, "pegasus_knight", Vector2i(2, 2))
	var finder := Pathfinding.new(level_state)
	assert_eq(finder.move_cost(cavalier, Vector2i(3, 1)), 3)
	assert_eq(finder.move_cost(pegasus, Vector2i(3, 1)), 1)


func test_fliers_cross_water_and_foot_units_go_around() -> void:
	var level_state := _strip()
	var fighter := _put(level_state, "fighter", Vector2i(4, 2))
	var pegasus := _put(level_state, "pegasus_knight", Vector2i(4, 3))
	var finder := Pathfinding.new(level_state)
	assert_false(finder.is_passable(fighter, Vector2i(5, 2)))
	assert_true(finder.is_passable(pegasus, Vector2i(5, 2)))
	var walk := finder.find_path(fighter, Vector2i(6, 2))
	for cell in walk:
		assert_ne(level_state.map_data.rules_terrain_at(cell), "water", "foot path avoids water")
	assert_eq(finder.find_path(pegasus, Vector2i(6, 3)).size(), 3, "the flier goes straight over")


## From (1, 2) to (3, 2), a forest edge cell. Straight along row 2: plains
## nub (2, 2) then forest (3, 2) = 1 + 2 = 3 for foot, 1 + 3 = 4 for cavalry. Any
## route through the forest above costs more.
func test_find_path_takes_the_cheapest_route() -> void:
	var foot_level := _strip()
	var fighter := _put(foot_level, "fighter", Vector2i(1, 2))
	var foot_finder := Pathfinding.new(foot_level)
	var foot := foot_finder.find_path(fighter, Vector2i(3, 2))
	assert_eq(foot, [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)] as Array[Vector2i])
	assert_eq(foot_finder.path_cost(fighter, foot), 3)

	var mounted_level := _strip()
	var cavalier := _put(mounted_level, "cavalier", Vector2i(1, 2))
	var mounted_finder := Pathfinding.new(mounted_level)
	var mounted := mounted_finder.find_path(cavalier, Vector2i(3, 2))
	assert_eq(mounted_finder.path_cost(cavalier, mounted), 4)


func test_path_cost_sums_terrain_and_rejects_impassable() -> void:
	var level_state := _strip()
	var fighter := _put(level_state, "fighter", Vector2i(2, 1))
	var finder := Pathfinding.new(level_state)
	var through_forest: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	assert_eq(finder.path_cost(fighter, through_forest), 4, "2 for the forest edge + 2 for the forest")
	var nub: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 2)]
	assert_eq(finder.path_cost(fighter, nub), 1, "a single tree nub is plains")
	var into_water: Array[Vector2i] = [Vector2i(4, 2), Vector2i(5, 2)]
	assert_gt(finder.path_cost(fighter, into_water), 1000, "impassable is never affordable")
	assert_eq(finder.path_cost(fighter, [Vector2i(2, 1)] as Array[Vector2i]), 0)


func test_undrawn_gap_is_impassable() -> void:
	var level_state := _strip()
	var fighter := _put(level_state, "fighter", Vector2i(2, 1))
	var finder := Pathfinding.new(level_state)
	assert_eq(finder.move_cost(fighter, Vector2i(20, 20)), TerrainData.IMPASSABLE)
	assert_false(finder.reachable_cells(fighter, 50).has(Vector2i(20, 20)))


func test_unknown_tile_counts_as_plains() -> void:
	var level_state := LevelState.fromJson({"map_data": {"layers": {
		"magma": {"z": 0, "terrain": "magma", "verts": [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1]]},
	}}})
	var fighter := _put(level_state, "fighter", Vector2i(0, 0))
	var finder := Pathfinding.new(level_state)
	assert_eq(finder.move_cost(fighter, Vector2i(1, 0)), 1)
	assert_true(finder.reachable_cells(fighter, 5).has(Vector2i(1, 0)))
	assert_push_warning("magma")
