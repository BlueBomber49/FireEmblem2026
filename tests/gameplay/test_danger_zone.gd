extends GutTest
## Which cells the danger zone covers: every enemy's threat when it's on, marked
## enemies always, never players or allies. test_level: lyn (player), wil (ally),
## bandit (enemy, Iron Axe).

const LEVEL_PATH := "res://resources/levels/test_level.json"

var state: LevelState
var pathfinding: Pathfinding
var zone: DangerZone
var bandit: LevelUnitState
var wil: LevelUnitState


func before_each() -> void:
	state = LevelState.load_file(LEVEL_PATH)
	pathfinding = Pathfinding.new(state)
	zone = DangerZone.new()
	bandit = state.level_units["bandit"]
	wil = state.level_units["wil"]


func _never_stays_put(_id: String) -> bool:
	return false


func _recompute(stays_put: Callable = _never_stays_put) -> void:
	zone.recompute(state, pathfinding, stays_put)


func _threat(unit: LevelUnitState, stays_put := false) -> Dictionary:
	return UnitRanges.compute(pathfinding, unit, state.map_data.bounds(), stays_put).threat_cells


func test_off_with_no_marks_shows_nothing() -> void:
	_recompute()
	assert_true(zone.normal_cells.is_empty())
	assert_true(zone.marked_cells.is_empty())


func test_on_shows_every_enemys_threat() -> void:
	zone.toggle()
	_recompute()
	assert_true(zone.enabled)
	assert_eq(zone.normal_cells, _threat(bandit))
	assert_true(zone.marked_cells.is_empty())


func test_players_and_allies_are_never_included() -> void:
	zone.toggle()
	_recompute()
	for cell: Vector2i in _threat(wil):
		if not _threat(bandit).has(cell):
			assert_false(zone.normal_cells.has(cell), "%s is only the ally's reach" % cell)


func test_a_marked_enemy_shows_even_when_off() -> void:
	zone.toggle_mark("bandit")
	_recompute()
	assert_true(zone.is_marked("bandit"))
	assert_eq(zone.marked_cells, _threat(bandit))
	assert_true(zone.normal_cells.is_empty())


func test_a_marked_enemy_stays_marked_when_on() -> void:
	zone.toggle()
	zone.toggle_mark("bandit")
	_recompute()
	assert_eq(zone.marked_cells, _threat(bandit))
	assert_true(zone.normal_cells.is_empty(), "the bandit's cells are drawn marked, not twice")


func test_a_cell_both_normal_and_marked_counts_as_marked() -> void:
	wil.unit_ref.faction = UnitReference.Faction.ENEMY
	zone.toggle()
	zone.toggle_mark("bandit")
	_recompute()
	assert_eq(zone.marked_cells, _threat(bandit))
	for cell: Vector2i in _threat(wil):
		assert_true(zone.normal_cells.has(cell) or zone.marked_cells.has(cell))
	for cell: Vector2i in zone.normal_cells:
		assert_false(zone.marked_cells.has(cell), "%s is drawn once, as marked" % cell)


func test_toggling_a_mark_twice_clears_it() -> void:
	zone.toggle_mark("bandit")
	zone.toggle_mark("bandit")
	_recompute()
	assert_false(zone.is_marked("bandit"))
	assert_true(zone.marked_cells.is_empty())


func test_a_dead_enemys_mark_is_dropped() -> void:
	zone.toggle_mark("bandit")
	bandit.current_hp = 0
	_recompute()
	assert_false(zone.is_marked("bandit"))
	assert_true(zone.marked_cells.is_empty())


func test_drop_dead_marks_works_without_a_recompute() -> void:
	zone.toggle_mark("bandit")
	bandit.current_hp = 0
	zone.drop_dead_marks(state)
	assert_false(zone.is_marked("bandit"))


func test_an_enemy_that_stays_put_threatens_from_where_it_stands() -> void:
	zone.toggle()
	_recompute(func(id: String) -> bool: return id == "bandit")
	assert_eq(zone.normal_cells, _threat(bandit, true))
	assert_eq(zone.normal_cells.size(), 4, "the Iron Axe's four neighbours")
