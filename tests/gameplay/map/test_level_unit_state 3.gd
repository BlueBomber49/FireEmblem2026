extends "res://tests/save_data_test.gd"
## The board half of a unit (cell, turn flags, facing) holding the mechanics half (Unit).


func _ref(id: String, cell: Vector2i, extra := {}) -> UnitReference:
	var d := {"class": "fighter", "name": id.capitalize(), "faction": "enemy", "items": ["iron_axe"],
		"start_cell": [cell.x, cell.y], "facing": [-1, 0]}
	d.merge(extra, true)
	return UnitReference.fromJson(id, d)


func test_from_reference_builds_the_unit_and_seeds_fresh_state() -> void:
	var ref := _ref("a", Vector2i(3, 1), {"stats": {"hp": 26}})
	var state := LevelUnitState.from_reference(ref)
	assert_same(state.unit_ref, ref)
	assert_not_null(state.unit)
	assert_eq(state.unit.data.display_name, "A")
	assert_eq(state.cell, Vector2i(3, 1))
	assert_eq(state.current_hp, 26)
	assert_eq(state.unit.max_hp(), 26)
	assert_eq(state.facing, Vector2i.LEFT)
	assert_false(state.has_moved)
	assert_false(state.has_acted)
	assert_true(state.is_alive())


func test_current_hp_forwards_to_the_unit() -> void:
	var state := LevelUnitState.from_reference(_ref("a", Vector2i.ZERO))
	state.current_hp = 5
	assert_eq(state.unit.current_hp, 5)
	state.unit.take_damage(2)
	assert_eq(state.current_hp, 3)
	assert_eq(state.unit.max_hp(), 20, "max HP is separate from current HP")


func test_broken_placement_gives_null() -> void:
	assert_null(LevelUnitState.from_reference(UnitReference.fromJson("x", {"character": "nobody"})))


func test_round_trip_keeps_board_and_unit_state() -> void:
	var ref := _ref("a", Vector2i(3, 1))
	var state := LevelUnitState.from_reference(ref)
	state.cell = Vector2i(5, 5)
	state.current_hp = 7
	state.has_moved = true
	state.unit.stats.strength = 9
	var again := LevelUnitState.fromJson(ref, JSON.parse_string(JSON.stringify(state.toJson())))
	assert_same(again.unit_ref, ref)
	assert_eq(again.cell, Vector2i(5, 5))
	assert_eq(again.current_hp, 7)
	assert_eq(again.unit.stats.strength, 9)
	assert_true(again.has_moved)
	assert_false(again.has_acted)
	assert_no_save_warnings()


func test_hp_is_written_once_inside_unit() -> void:
	var saved := LevelUnitState.from_reference(_ref("a", Vector2i.ZERO)).toJson()
	assert_false(saved.has("current_hp"), "no top-level copy")
	assert_eq(saved["unit"]["current_hp"], 20)


func test_older_save_with_top_level_hp_still_loads() -> void:
	var ref := _ref("a", Vector2i.ZERO)
	var state := LevelUnitState.fromJson(ref, {"cell": [1, 1], "current_hp": 4.0})
	assert_eq(state.current_hp, 4)
	assert_eq(state.cell, Vector2i(1, 1))


func test_unit_block_wins_over_top_level_hp() -> void:
	var ref := _ref("a", Vector2i.ZERO)
	var d := LevelUnitState.from_reference(ref).toJson()
	d["unit"]["current_hp"] = 6
	d["current_hp"] = 15
	assert_eq(LevelUnitState.fromJson(ref, d).current_hp, 6)


func test_build_all_fresh_when_nothing_saved() -> void:
	var units := {"a": _ref("a", Vector2i(1, 1)), "b": _ref("b", Vector2i(2, 2), {"stats": {"hp": 30}})}
	var states := LevelUnitState.build_all(units, {})
	assert_eq(states.size(), 2)
	assert_eq(states["a"].current_hp, 20)
	assert_eq(states["b"].current_hp, 30)
	assert_eq(states["b"].cell, Vector2i(2, 2))


func test_build_all_restores_saved_and_fills_the_rest() -> void:
	var units := {"a": _ref("a", Vector2i(1, 1)), "b": _ref("b", Vector2i(2, 2))}
	var saved := {"a": {"cell": [9.0, 9.0], "has_moved": true, "facing": [0.0, 1.0],
		"unit": {"level": 1.0, "experience": 0.0, "current_hp": 4.0, "stats": units["a"].build_unit_data().starting_stats.to_dict(),
			"inventory": [{"item": "iron_axe"}]}}}
	var states := LevelUnitState.build_all(units, saved)
	assert_eq(states["a"].cell, Vector2i(9, 9))
	assert_same(states["a"].unit_ref, units["a"], "a restored state still gets its reference")
	assert_eq(states["a"].current_hp, 4)
	assert_true(states["a"].has_moved)
	assert_eq(states["b"].cell, Vector2i(2, 2), "b was not saved, so it is fresh")
	assert_eq(states["b"].current_hp, 20)


func test_build_all_skips_a_broken_placement_with_a_warning() -> void:
	var units := {"a": _ref("a", Vector2i(1, 1)), "typo": UnitReference.fromJson("typo", {"character": "lynn"})}
	var states := LevelUnitState.build_all(units, {})
	assert_eq(states.keys(), ["a"])
	assert_push_warning("typo")


func test_dead_and_reset_turn() -> void:
	var state := LevelUnitState.from_reference(_ref("a", Vector2i.ZERO))
	state.current_hp = 0
	assert_false(state.is_alive())
	state.has_moved = true
	state.has_acted = true
	state.reset_turn()
	assert_false(state.has_moved)
	assert_false(state.has_acted)
