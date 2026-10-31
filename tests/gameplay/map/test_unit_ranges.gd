extends GutTest
## Where a unit can move and what it can attack after moving, with every weapon
## it carries. test_level is grass from x 4-11, y 3-8, ringed by water; lyn
## (Myrmidon, Mov 5) stands on (6, 5), wil (Archer, ally) on (6, 7) and the bandit
## (Fighter, Iron Axe) on (10, 5).

const LEVEL_PATH := "res://resources/levels/test_level.json"

var state: LevelState
var pathfinding: Pathfinding
var bounds: Rect2i
var lyn: LevelUnitState
var wil: LevelUnitState
var bandit: LevelUnitState


func before_each() -> void:
	state = LevelState.load_file(LEVEL_PATH)
	pathfinding = Pathfinding.new(state)
	bounds = state.map_data.bounds()
	lyn = state.level_units["lyn"]
	wil = state.level_units["wil"]
	bandit = state.level_units["bandit"]


## Replaces `unit`'s inventory with the given item ids.
func _arm(unit: LevelUnitState, item_ids: Array[StringName]) -> void:
	unit.unit.inventory = Inventory.new()
	for item_id in item_ids:
		unit.unit.inventory.add(GameData.get_item(item_id))


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## The smallest distance from `cell` to any cell in `cells`.
static func _nearest(cell: Vector2i, cells: Dictionary) -> int:
	var best := 1 << 30
	for other: Vector2i in cells:
		best = mini(best, _distance(cell, other))
	return best


func test_move_cells_are_the_reachable_cells() -> void:
	var ranges := UnitRanges.compute(pathfinding, lyn, bounds)
	assert_eq(ranges.move_cells, pathfinding.reachable_cells(lyn, lyn.unit.stats.movement))


func test_a_sword_threatens_one_cell_past_the_move_area() -> void:
	var ranges := UnitRanges.compute(pathfinding, lyn, bounds)
	assert_false(ranges.attack_cells.is_empty())
	for cell: Vector2i in ranges.attack_cells:
		assert_eq(_nearest(cell, ranges.move_cells), 1, "%s is one step past where lyn can stand" % cell)
	assert_true(ranges.attack_cells.has(bandit.cell), "she can walk next to the bandit and hit it")


func test_threat_is_the_move_area_plus_the_fringe() -> void:
	var ranges := UnitRanges.compute(pathfinding, lyn, bounds)
	for cell: Vector2i in ranges.attack_cells:
		assert_false(ranges.move_cells.has(cell), "the red fringe never overlaps the blue")
		assert_true(ranges.threat_cells.has(cell))
	for cell: Vector2i in ranges.move_cells:
		assert_true(ranges.threat_cells.has(cell), "she can attack anywhere she can move next to")


func test_a_bow_alone_threatens_at_two_only() -> void:
	var ranges := UnitRanges.compute(pathfinding, wil, bounds, true)
	assert_eq(UnitRanges.attack_distances(wil.unit), [2] as Array[int])
	assert_false(ranges.threat_cells.is_empty())
	for cell: Vector2i in ranges.threat_cells:
		assert_eq(_distance(cell, wil.cell), 2, "a bow skips the cells next to wil")


func test_every_carried_weapon_counts() -> void:
	_arm(bandit, [&"iron_axe", &"hand_axe"])
	assert_eq(UnitRanges.attack_distances(bandit.unit), [1, 2] as Array[int], "Iron Axe 1 plus Hand Axe 1-2")
	var ranges := UnitRanges.compute(pathfinding, bandit, bounds, true)
	assert_true(ranges.threat_cells.has(bandit.cell + Vector2i.LEFT))
	assert_true(ranges.threat_cells.has(bandit.cell + Vector2i.LEFT * 2), "the Hand Axe reaches 2 even unequipped")


func test_a_weapon_the_class_cant_use_is_ignored() -> void:
	_arm(lyn, [&"iron_bow"])  # myrmidons can't use bows
	assert_eq(UnitRanges.attack_distances(lyn.unit), [] as Array[int])
	assert_true(UnitRanges.compute(pathfinding, lyn, bounds).attack_cells.is_empty())


func test_no_weapon_means_no_attack_cells() -> void:
	_arm(lyn, [&"vulnerary"])
	var ranges := UnitRanges.compute(pathfinding, lyn, bounds)
	assert_false(ranges.move_cells.is_empty(), "she can still move")
	assert_true(ranges.attack_cells.is_empty())
	assert_true(ranges.threat_cells.is_empty())


func test_a_hostile_unit_blocks_movement_and_so_threat() -> void:
	bandit.unit.stats.movement = 1
	var open := UnitRanges.compute(pathfinding, bandit, bounds)
	assert_true(open.threat_cells.has(Vector2i(8, 5)), "step to (9, 5), then hit (8, 5)")
	lyn.cell = Vector2i(9, 5)  # stands in the bandit's way
	var blocked := UnitRanges.compute(pathfinding, bandit, bounds)
	assert_false(blocked.move_cells.has(Vector2i(9, 5)))
	assert_false(blocked.threat_cells.has(Vector2i(8, 5)), "can't get past lyn to reach it")
	assert_true(blocked.threat_cells.has(Vector2i(9, 5)), "but lyn herself is in reach")


func test_threat_stays_inside_the_map() -> void:
	for unit in [lyn, wil, bandit]:
		for cell: Vector2i in UnitRanges.compute(pathfinding, unit, bounds).threat_cells:
			assert_true(bounds.has_point(cell), "%s is on the map" % cell)


func test_a_unit_that_stays_put_threatens_from_its_own_cell() -> void:
	var ranges := UnitRanges.compute(pathfinding, lyn, bounds, true)
	assert_eq(ranges.move_cells, {lyn.cell: true})
	assert_eq(ranges.attack_cells.size(), 4, "a sword's four neighbours")
	for offset in Pathfinding.NEIGHBOURS:
		assert_true(ranges.attack_cells.has(lyn.cell + offset))
