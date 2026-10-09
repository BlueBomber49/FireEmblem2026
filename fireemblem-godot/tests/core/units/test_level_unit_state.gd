extends GutTest


func _ref(id: String, hp: int, cell: Vector2i) -> UnitReference:
	var ref := UnitReference.new()
	ref.id = id
	ref.stats[&"hp"] = hp
	ref.start_cell = cell
	ref.facing = Vector2i.LEFT
	return ref


func test_from_reference_seeds_fresh_state() -> void:
	var state := LevelUnitState.from_reference(_ref("a", 20, Vector2i(3, 1)))
	assert_eq(state.unit_id, "a")
	assert_eq(state.cell, Vector2i(3, 1))
	assert_eq(state.current_hp, 20)
	assert_eq(state.facing, Vector2i.LEFT)
	assert_false(state.has_moved)
	assert_false(state.has_acted)
	assert_true(state.is_alive())


func test_round_trip() -> void:
	var state := LevelUnitState.from_reference(_ref("a", 20, Vector2i(3, 1)))
	state.cell = Vector2i(5, 5)
	state.current_hp = 7
	state.has_moved = true
	var again := LevelUnitState.fromJson("a", state.toJson())
	assert_eq(again.unit_id, "a")
	assert_eq(again.toJson(), state.toJson())
	assert_eq(again.cell, Vector2i(5, 5))
	assert_eq(again.current_hp, 7)
	assert_true(again.has_moved)
	assert_false(again.has_acted)


func test_build_all_fresh_when_nothing_saved() -> void:
	var units := {"a": _ref("a", 20, Vector2i(1, 1)), "b": _ref("b", 30, Vector2i(2, 2))}
	var states := LevelUnitState.build_all(units, {})
	assert_eq(states.size(), 2)
	assert_eq(states["a"].current_hp, 20)
	assert_eq(states["b"].cell, Vector2i(2, 2))


func test_build_all_restores_saved_and_fills_the_rest() -> void:
	var units := {"a": _ref("a", 20, Vector2i(1, 1)), "b": _ref("b", 30, Vector2i(2, 2))}
	var saved := {"a": {"cell": [9.0, 9.0], "current_hp": 4.0, "has_moved": true, "facing": [0.0, 1.0]}}
	var states := LevelUnitState.build_all(units, saved)
	assert_eq(states["a"].cell, Vector2i(9, 9))
	assert_eq(states["a"].current_hp, 4)
	assert_true(states["a"].has_moved)
	assert_eq(states["b"].cell, Vector2i(2, 2), "b was not saved, so it is fresh")
	assert_eq(states["b"].current_hp, 30)


func test_dead_and_reset_turn() -> void:
	var state := LevelUnitState.new()
	state.current_hp = 0
	assert_false(state.is_alive())
	state.has_moved = true
	state.has_acted = true
	state.reset_turn()
	assert_false(state.has_moved)
	assert_false(state.has_acted)
