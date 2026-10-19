extends GutTest
## Drives the Battle state machine through its public commands on test_level:
## lyn (player) at (6, 5), wil (ally) at (6, 7), bandit (enemy) at (10, 5).

const BattleScene: PackedScene = preload("res://gameplay/battle.tscn")
const LEVEL_PATH := "res://resources/levels/test_level.json"
const LYN_CELL := Vector2i(6, 5)

var battle: Battle
var lyn: LevelUnitState
var bandit: LevelUnitState


func before_each() -> void:
	battle = BattleScene.instantiate()
	(battle.get_node("Level") as Level).level_path = LEVEL_PATH
	add_child_autofree(battle)
	lyn = battle.level.level_state.level_units["lyn"]
	bandit = battle.level.level_state.level_units["bandit"]


func _select_lyn() -> void:
	battle.cursor.set_cell(LYN_CELL)
	battle.confirm()


# --- Free cursor -----------------------------------------------------------


func test_starts_free_on_the_first_player_unit() -> void:
	assert_eq(battle.state, Battle.State.FREE)
	assert_eq(battle.cursor.cell, LYN_CELL)
	assert_true(battle.terrain_panel.visible)
	assert_false(battle.map_menu.visible)


func test_cursor_moves_and_stays_inside_the_map() -> void:
	battle.move_cursor(Vector2i.RIGHT)
	assert_eq(battle.cursor.cell, LYN_CELL + Vector2i.RIGHT)
	for i in 50:
		battle.move_cursor(Vector2i.LEFT)
	assert_eq(battle.cursor.cell.x, battle.level.level_state.map_data.bounds().position.x)


func test_terrain_info_names_the_top_layer() -> void:
	assert_eq(battle.terrain_info_at(LYN_CELL).terrain_name, "Grass")
	assert_eq(battle.terrain_info_at(LYN_CELL).move_cost, 1)
	var outside := battle.terrain_info_at(Vector2i(30, 30))
	assert_eq(outside.terrain_name, "None")
	assert_eq(outside.move_cost, TerrainInfo.IMPASSABLE)


func test_confirm_on_empty_ground_opens_the_map_menu() -> void:
	battle.cursor.set_cell(LYN_CELL + Vector2i.RIGHT)
	battle.confirm()
	assert_eq(battle.state, Battle.State.MAP_MENU)
	assert_true(battle.map_menu.visible)
	assert_false(battle.terrain_panel.visible, "panel hides behind menus")
	battle.cancel()
	assert_eq(battle.state, Battle.State.FREE)
	assert_true(battle.terrain_panel.visible)


func test_confirm_on_an_enemy_opens_the_map_menu() -> void:
	battle.cursor.set_cell(bandit.cell)
	battle.confirm()
	assert_eq(battle.state, Battle.State.MAP_MENU)
	assert_null(battle.level.selected)


# --- Selecting and moving --------------------------------------------------


func test_confirm_on_a_player_unit_selects_it_and_shows_its_range() -> void:
	_select_lyn()
	assert_eq(battle.state, Battle.State.UNIT_SELECTED)
	assert_eq(battle.level.selected.reference.id, "lyn")
	assert_true(battle.reachable.has(Vector2i(9, 5)), "three steps, mov is 5")
	assert_false(battle.reachable.has(bandit.cell), "can't stop on the enemy")
	assert_false(battle.reachable.has(Vector2i(1, 1)), "too far")


func test_arrow_follows_the_route_to_the_cursor() -> void:
	_select_lyn()
	assert_true(battle.arrow.path.is_empty(), "no arrow on the unit's own cell")
	battle.cursor.set_cell(Vector2i(8, 5))
	assert_eq(battle.arrow.path, battle.level.pathfinding.find_path(lyn, Vector2i(8, 5)),
			"a jump in range takes the shortest route")
	assert_eq(battle.arrow.path.size(), 3)
	battle.cursor.set_cell(LYN_CELL)
	assert_true(battle.arrow.path.is_empty(), "back on the unit")


func test_arrow_freezes_outside_the_range() -> void:
	_select_lyn()
	battle.cursor.set_cell(Vector2i(8, 5))
	battle.cursor.set_cell(Vector2i(1, 1))
	assert_eq(battle.arrow.path.size(), 3, "kept while the cursor is outside")
	battle.cursor.set_cell(Vector2i(8, 5))
	assert_eq(battle.arrow.path.size(), 3, "back on the arrow's end continues it")


func _trace(cells: Array) -> void:
	for cell in cells:
		battle.cursor.set_cell(cell)


func test_arrow_traces_the_cursor_step_by_step() -> void:
	_select_lyn()
	_trace([Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(8, 5)])
	assert_eq(battle.arrow.path, [LYN_CELL, Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(8, 5)] as Array[Vector2i],
			"the detour, not the three-cell shortest route")


func test_stepping_back_onto_the_arrow_cuts_it() -> void:
	_select_lyn()
	_trace([Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4)])
	battle.cursor.set_cell(Vector2i(6, 4))
	assert_eq(battle.arrow.path, [LYN_CELL, Vector2i(6, 4)] as Array[Vector2i])


func test_trace_over_the_budget_falls_back_to_the_shortest_route() -> void:
	_select_lyn()
	_trace([Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6)])
	assert_eq(battle.arrow.path.size(), 6, "five steps, the whole budget")
	battle.cursor.set_cell(Vector2i(7, 6))
	assert_eq(battle.arrow.path, battle.level.pathfinding.find_path(lyn, Vector2i(7, 6)),
			"a sixth step won't fit, so the arrow is rebuilt")


func test_trace_may_pass_an_ally_but_not_stop_on_it() -> void:
	var wil_cell := Vector2i(6, 7)
	_select_lyn()
	_trace([Vector2i(6, 6), wil_cell])
	assert_eq(battle.arrow.path.size(), 3, "allies can be walked through")
	battle.confirm()
	assert_eq(battle.state, Battle.State.UNIT_SELECTED, "but not stopped on")
	battle.cursor.set_cell(Vector2i(6, 8))
	assert_eq(battle.arrow.path.size(), 4)


func test_trace_cannot_enter_an_enemy_cell() -> void:
	bandit.cell = Vector2i(7, 5)
	_select_lyn()
	battle.cursor.set_cell(Vector2i(7, 5))
	assert_true(battle.arrow.path.is_empty(), "no route ends on an enemy")


func test_confirm_walks_the_traced_route() -> void:
	_select_lyn()
	_trace([Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(8, 5)])
	battle.confirm()
	assert_eq(battle.state, Battle.State.MOVING)
	await wait_seconds(Level.STEP_TIME * 4 + 0.3)
	assert_eq(battle.state, Battle.State.UNIT_MENU)
	assert_eq(lyn.cell, Vector2i(8, 5))
	assert_eq(lyn.facing, Vector2i.DOWN, "the last step of the detour came down from (8, 4)")


func test_arrow_clears_on_cancel_and_on_move() -> void:
	_select_lyn()
	battle.cursor.set_cell(Vector2i(8, 5))
	battle.cancel()
	assert_true(battle.arrow.path.is_empty(), "cancel")
	_select_lyn()
	battle.cursor.set_cell(Vector2i(8, 5))
	assert_eq(battle.arrow.path.size(), 3)
	battle.confirm()
	assert_true(battle.arrow.path.is_empty(), "gone as soon as the move starts")
	await wait_seconds(Level.STEP_TIME * 2 + 0.2)
	assert_eq(battle.state, Battle.State.UNIT_MENU)
	assert_true(battle.arrow.path.is_empty(), "still gone in the unit menu")


func test_cancel_deselects() -> void:
	_select_lyn()
	battle.cancel()
	assert_eq(battle.state, Battle.State.FREE)
	assert_null(battle.level.selected)
	assert_true(battle.reachable.is_empty())


func test_confirm_outside_the_range_does_nothing() -> void:
	_select_lyn()
	battle.cursor.set_cell(Vector2i(1, 1))
	battle.confirm()
	assert_eq(battle.state, Battle.State.UNIT_SELECTED)
	assert_eq(lyn.cell, LYN_CELL)


func test_confirm_in_range_walks_then_opens_the_unit_menu() -> void:
	_select_lyn()
	battle.cursor.set_cell(Vector2i(8, 5))
	battle.confirm()
	assert_eq(battle.state, Battle.State.MOVING)
	await wait_seconds(Level.STEP_TIME * 2 + 0.2)
	assert_eq(battle.state, Battle.State.UNIT_MENU)
	assert_true(battle.unit_menu.visible)
	assert_eq(battle.unit_menu.options, [&"wait"] as Array[StringName], "no enemy next to (8, 5)")
	assert_eq(lyn.cell, Vector2i(8, 5))
	assert_true(lyn.has_moved)
	assert_eq(battle.cursor.cell, Vector2i(8, 5))


func test_cancel_in_the_unit_menu_undoes_the_move() -> void:
	_select_lyn()
	battle.cursor.set_cell(Vector2i(8, 5))
	battle.confirm()
	await wait_seconds(Level.STEP_TIME * 2 + 0.2)
	battle.cancel()
	assert_eq(battle.state, Battle.State.UNIT_SELECTED)
	assert_eq(lyn.cell, LYN_CELL)
	assert_false(lyn.has_moved)
	assert_almost_eq(battle.level.unit_nodes["lyn"].global_position,
			battle.level.cell_center(LYN_CELL), Vector2(0.01, 0.01))
	assert_eq(battle.cursor.cell, LYN_CELL)
	assert_true(battle.reachable.has(Vector2i(9, 5)), "range is back")


func test_confirm_on_own_cell_opens_the_unit_menu_without_moving() -> void:
	_select_lyn()
	battle.confirm()
	assert_eq(battle.state, Battle.State.UNIT_MENU)
	assert_eq(lyn.cell, LYN_CELL)


func test_unit_key_opens_the_unit_menu_in_place() -> void:
	battle.cursor.set_cell(LYN_CELL)
	battle.act_in_place()
	assert_eq(battle.state, Battle.State.UNIT_MENU)
	assert_eq(battle.level.selected.reference.id, "lyn")
	battle.cancel()
	assert_eq(battle.state, Battle.State.UNIT_SELECTED, "cancel backs out one step")
	battle.cancel()
	battle.cursor.set_cell(bandit.cell)
	battle.act_in_place()
	assert_eq(battle.state, Battle.State.FREE, "the unit key ignores enemies")


# --- Acting ----------------------------------------------------------------


func test_wait_spends_the_unit() -> void:
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"wait")
	assert_eq(battle.state, Battle.State.FREE)
	assert_true(lyn.has_acted)
	assert_eq(battle.level.unit_nodes["lyn"].modulate, Level.ACTED_TINT)
	_select_lyn()
	assert_eq(battle.state, Battle.State.MAP_MENU, "an acted unit can't be selected again")


func test_attack_is_offered_only_next_to_an_enemy() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	_select_lyn()
	battle.confirm()
	assert_eq(battle.unit_menu.options, [&"attack", &"wait"] as Array[StringName])


func test_attack_shows_the_forecast_on_the_target() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	assert_eq(battle.state, Battle.State.TARGETING)
	assert_true(battle.forecast.visible)
	assert_eq(battle.cursor.cell, bandit.cell)
	assert_false(battle.terrain_panel.visible)


## Attack animations are 4 frames at 10 fps per strike, plus a fade on a kill.
const FIGHT_TIME := 2.5


func _always(value: int) -> Callable:
	return func() -> int: return value


func test_confirming_the_forecast_plays_the_fight_and_spends_the_unit() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	battle.roll = _always(50)
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	# The panel closes itself before emitting; do the same here.
	battle.forecast.close()
	battle.forecast.confirmed.emit()
	assert_eq(battle.state, Battle.State.COMBAT)
	assert_true(battle.attack_cells.is_empty(), "red squares go away once the fight starts")
	await wait_seconds(FIGHT_TIME)
	assert_eq(battle.state, Battle.State.FREE)
	assert_true(lyn.has_acted)
	assert_eq(lyn.current_hp, 6, "bandit's counter landed")
	assert_eq(bandit.current_hp, 12, "lyn hit twice")
	assert_eq(battle.level.unit_nodes["lyn"].animation, &"idle_side")


func test_a_unit_at_zero_hp_leaves_the_map() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	bandit.current_hp = 5
	battle.roll = _always(50)
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	battle.forecast.confirmed.emit()
	await wait_seconds(FIGHT_TIME)
	assert_false(bandit.is_alive())
	assert_false(battle.level.unit_nodes.has("bandit"))
	assert_null(battle.level.unit_at(bandit.cell))
	assert_eq(lyn.current_hp, 16, "the bandit fell before it could counter")
	assert_true(lyn.has_acted)


func test_the_attacker_can_fall_too() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	lyn.current_hp = 5
	battle.roll = _always(50)
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	battle.forecast.confirmed.emit()
	await wait_seconds(FIGHT_TIME)
	assert_false(lyn.is_alive())
	assert_false(battle.level.unit_nodes.has("lyn"))
	assert_null(battle.level.selected)
	assert_eq(battle.state, Battle.State.FREE)
	assert_eq(bandit.current_hp, 18)


func test_attack_marks_the_cells_in_range_red() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	_select_lyn()
	battle.confirm()
	assert_true(battle.attack_cells.is_empty(), "nothing marked until Attack is picked")
	battle.unit_menu.option_selected.emit(&"attack")
	assert_eq(battle.attack_cells.size(), 4, "the four neighbours")
	for offset in Combat.NEIGHBOURS:
		assert_true(battle.attack_cells.has(LYN_CELL + offset))
	assert_false(battle.attack_cells.has(LYN_CELL))
	battle.cancel()
	assert_true(battle.attack_cells.is_empty(), "cleared on the way back to the unit menu")


func test_attack_range_stops_at_the_map_edge() -> void:
	var bounds := battle.level.level_state.map_data.bounds()
	lyn.cell = bounds.position
	battle.level.place_unit(battle.level.unit_nodes["lyn"], bounds.position)
	bandit.cell = bounds.position + Vector2i.RIGHT
	battle.cursor.set_cell(bounds.position)
	battle.confirm()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	assert_eq(battle.attack_cells.size(), 2, "only right and down are on the map")


func test_cancelling_the_forecast_returns_to_the_unit_menu() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	battle.cancel()
	assert_eq(battle.state, Battle.State.UNIT_MENU)
	assert_true(battle.unit_menu.visible)
	assert_eq(battle.cursor.cell, LYN_CELL)


func test_arrows_cycle_between_targets() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	var brigand := LevelUnitState.from_reference(bandit.unit_ref)
	brigand.cell = LYN_CELL + Vector2i.DOWN
	battle.level.level_state.level_units["brigand"] = brigand
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	assert_eq(battle.cursor.cell, bandit.cell, "clockwise from above: right comes first")
	battle._cycle_target(1)
	assert_eq(battle.cursor.cell, brigand.cell)
	battle._cycle_target(1)
	assert_eq(battle.cursor.cell, bandit.cell, "wraps around")


# --- Map menu --------------------------------------------------------------


func test_end_turn_refreshes_every_unit() -> void:
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"wait")
	battle.cursor.set_cell(LYN_CELL + Vector2i.RIGHT)
	battle.confirm()
	battle.map_menu.option_selected.emit(&"end")
	assert_eq(battle.state, Battle.State.FREE)
	assert_false(lyn.has_acted)
	assert_false(lyn.has_moved)
	assert_eq(battle.level.unit_nodes["lyn"].modulate, Color.WHITE)


func test_other_map_menu_options_just_close() -> void:
	battle.cursor.set_cell(LYN_CELL + Vector2i.RIGHT)
	battle.confirm()
	battle.map_menu.option_selected.emit(&"status")
	assert_eq(battle.state, Battle.State.FREE)
	assert_false(lyn.has_acted)
