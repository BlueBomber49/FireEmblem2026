extends GutTest
## Drives Battle's player controls on test_level. Wil is made a player unit in
## this fixture so one completed Lyn action doesn't immediately start a phase.

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
	battle.level.level_state.level_units["wil"].unit_ref.faction = UnitReference.Faction.PLAYER
	battle.turn_loop.enemy_controller.set_strategy(&"bandit", EnemyAI.Strategy.STATIONARY)


# Menus queue_free their old buttons, which only happens at the end of a frame.
# Let one pass so GUT doesn't report them as orphans.
func after_each() -> void:
	await get_tree().process_frame


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


func test_terrain_info_shows_the_rules_terrain() -> void:
	var plains := battle.terrain_info_at(LYN_CELL)
	assert_eq(plains.terrain_name, "Plains", "grass tiles follow the plains rules")
	assert_eq(plains.move_cost, 1)
	assert_eq(plains.defense, 0)
	assert_eq(plains.avoid, 0)
	var sea := battle.terrain_info_at(Vector2i(3, 5))
	assert_eq(sea.terrain_name, "Sea")
	assert_eq(sea.avoid, 10)
	assert_eq(sea.move_cost, TerrainInfo.IMPASSABLE, "foot units can't enter")
	var outside := battle.terrain_info_at(Vector2i(30, 30))
	assert_eq(outside.terrain_name, "None")
	assert_eq(outside.move_cost, TerrainInfo.IMPASSABLE)


func test_terrain_info_move_cost_is_for_the_selected_unit() -> void:
	var wil: LevelUnitState = battle.level.level_state.level_units["wil"]
	wil.unit_ref.faction = UnitReference.Faction.PLAYER
	# Turn Wil into a flier for this check: fliers can cross the sea.
	wil.unit.data = UnitReference.fromJson("p", {"class": "pegasus_knight", "items": ["iron_lance"]}).build_unit_data()
	battle.cursor.set_cell(wil.cell)
	battle.confirm()
	assert_eq(battle.terrain_info_at(Vector2i(3, 5)).move_cost, 1)


func test_confirm_on_empty_ground_opens_the_map_menu() -> void:
	battle.cursor.set_cell(LYN_CELL + Vector2i.RIGHT)
	battle.confirm()
	assert_eq(battle.state, Battle.State.MAP_MENU)
	assert_true(battle.map_menu.visible)
	assert_false(battle.terrain_panel.visible, "panel hides behind menus")
	battle.cancel()
	assert_eq(battle.state, Battle.State.FREE)
	assert_true(battle.terrain_panel.visible)


func test_confirm_on_an_enemy_marks_its_danger_zone() -> void:
	battle.cursor.set_cell(bandit.cell)
	battle.confirm()
	assert_eq(battle.state, Battle.State.FREE, "no map menu on an enemy")
	assert_false(battle.map_menu.visible)
	assert_null(battle.level.selected)
	assert_true(battle.danger_zone.is_marked("bandit"))
	assert_false(battle.range_overlay.marked_threat_cells.is_empty())
	battle.confirm()
	assert_false(battle.danger_zone.is_marked("bandit"), "confirm again unmarks it")
	assert_true(battle.range_overlay.marked_threat_cells.is_empty())


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


func test_arrow_never_steps_onto_water() -> void:
	_select_lyn()
	_trace([Vector2i(5, 5), Vector2i(4, 5), Vector2i(3, 5)])
	assert_eq(battle.arrow.path, [LYN_CELL, Vector2i(5, 5), Vector2i(4, 5)] as Array[Vector2i],
			"the sea cell isn't added")
	assert_false(battle.reachable.has(Vector2i(3, 5)))
	battle.confirm()
	assert_eq(battle.state, Battle.State.UNIT_SELECTED, "confirming on the water does nothing")


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
	assert_eq(battle.unit_menu.options, [&"item", &"status", &"wait"] as Array[StringName], "no enemy next to (8, 5)")
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
	assert_eq(battle.unit_menu.options, [&"attack", &"item", &"status", &"wait"] as Array[StringName])


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
	# A roll of 10 hits both sides: lyn's Iron Sword (7 damage, doubles) and the
	# bandit's Iron Axe (12 damage); see test_combat.gd for the numbers.
	battle.roll = _always(10)
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
	assert_eq(lyn.current_hp, 4, "bandit's counter landed: 16 - 12")
	assert_eq(bandit.current_hp, 10, "lyn hit twice: 24 - 7 - 7")
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
	battle.roll = _always(10)
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	battle.forecast.confirmed.emit()
	await wait_seconds(FIGHT_TIME)
	assert_false(lyn.is_alive())
	assert_false(battle.level.unit_nodes.has("lyn"))
	assert_null(battle.level.selected)
	assert_eq(battle.state, Battle.State.FREE)
	assert_eq(bandit.current_hp, 17, "24 - 7 before the counter")


func test_diagonal_ranged_attack_faces_a_straight_direction() -> void:
	var wil: LevelUnitState = battle.level.level_state.level_units["wil"]
	wil.unit_ref.faction = UnitReference.Faction.PLAYER
	bandit.cell = wil.cell + Vector2i(-1, 1)  # down-left, 2 tiles away
	battle.roll = _always(10)
	battle.cursor.set_cell(wil.cell)
	battle.act_in_place()
	battle.unit_menu.option_selected.emit(&"attack")
	battle.forecast.close()
	battle.forecast.confirmed.emit()
	await wait_seconds(FIGHT_TIME)
	assert_eq(wil.facing, Vector2i.LEFT, "faces the target's side, not a diagonal")
	assert_true(battle.level.unit_nodes["wil"].flip_h, "the side view is mirrored to face left")


func test_strike_direction_prefers_the_horizontal() -> void:
	assert_eq(Battle.strike_direction(Vector2i(-1, 1)), Vector2i.LEFT)
	assert_eq(Battle.strike_direction(Vector2i(2, -1)), Vector2i.RIGHT)
	assert_eq(Battle.strike_direction(Vector2i(0, -2)), Vector2i.UP)
	assert_eq(Battle.strike_direction(Vector2i(0, 1)), Vector2i.DOWN)


func test_an_archer_attacks_from_two_tiles() -> void:
	var wil: LevelUnitState = battle.level.level_state.level_units["wil"]
	wil.unit_ref.faction = UnitReference.Faction.PLAYER
	bandit.cell = wil.cell + Vector2i(2, 0)
	battle.cursor.set_cell(wil.cell)
	battle.act_in_place()
	assert_eq(battle.unit_menu.options, [&"attack", &"item", &"status", &"wait"] as Array[StringName])
	battle.unit_menu.option_selected.emit(&"attack")
	assert_eq(battle.cursor.cell, bandit.cell)
	assert_true(battle.attack_cells.has(wil.cell + Vector2i(2, 0)))
	assert_false(battle.attack_cells.has(wil.cell + Vector2i(1, 0)), "a bow can't reach the next cell")


func test_no_attack_option_when_the_weapon_cant_reach() -> void:
	var wil: LevelUnitState = battle.level.level_state.level_units["wil"]
	wil.unit_ref.faction = UnitReference.Faction.PLAYER
	bandit.cell = wil.cell + Vector2i(1, 0)
	battle.cursor.set_cell(wil.cell)
	battle.act_in_place()
	assert_eq(battle.unit_menu.options, [&"item", &"status", &"wait"] as Array[StringName], "too close for the bow")


# --- Item hooks (for the Item menu Spencer will build) --------------------------
# Lyn carries an Iron Sword (slot 0) and a Vulnerary (slot 1).


func _lyn_in_unit_menu() -> void:
	battle.cursor.set_cell(LYN_CELL)
	battle.act_in_place()
	assert_eq(battle.state, Battle.State.UNIT_MENU)


func test_selected_unit_items_describes_the_selected_unit() -> void:
	assert_null(battle.selected_unit_items(), "nothing selected")
	_lyn_in_unit_menu()
	var info := battle.selected_unit_items()
	assert_eq(info.unit_name, "Lyn")
	assert_eq(info.items.size(), 2)


func test_using_a_vulnerary_heals_and_ends_the_action() -> void:
	lyn.current_hp = 5
	_lyn_in_unit_menu()
	assert_true(battle.use_item(1))
	assert_eq(lyn.current_hp, 15)
	assert_eq(lyn.unit.inventory.get_item(1).uses_left, 2)
	assert_true(lyn.has_acted, "using an item ends the unit's action, as in FE")
	assert_eq(battle.state, Battle.State.FREE)


func test_using_an_item_at_full_hp_is_refused() -> void:
	_lyn_in_unit_menu()
	assert_false(battle.use_item(1))
	assert_false(lyn.has_acted)
	assert_eq(battle.state, Battle.State.UNIT_MENU)


func test_using_a_weapon_is_refused() -> void:
	lyn.current_hp = 5
	_lyn_in_unit_menu()
	assert_false(battle.use_item(0))
	assert_false(lyn.has_acted)


func test_equipping_keeps_the_action_and_refreshes_targets() -> void:
	lyn.unit.inventory.add(GameData.get_item(&"steel_sword"))
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	_lyn_in_unit_menu()
	assert_true(battle.equip_item(2))
	assert_eq(lyn.unit.equipped_weapon(), GameData.get_item(&"steel_sword"))
	assert_false(lyn.has_acted, "equipping doesn't end the action")
	assert_eq(battle.state, Battle.State.UNIT_MENU)
	assert_eq(battle.unit_menu.options, [&"attack", &"item", &"status", &"wait"] as Array[StringName])


func test_equipping_a_consumable_is_refused() -> void:
	_lyn_in_unit_menu()
	assert_false(battle.equip_item(1))


func test_item_hooks_need_a_unit_in_the_unit_menu() -> void:
	lyn.current_hp = 5
	assert_false(battle.use_item(1), "nothing selected")
	assert_false(battle.equip_item(0))
	assert_eq(lyn.current_hp, 5)


# --- Item menu -----------------------------------------------------------------


func _lyn_in_item_menu() -> void:
	_lyn_in_unit_menu()
	_press_item()
	assert_eq(battle.state, Battle.State.ITEM_MENU)


## Presses the unit menu's Item button, which closes the unit menu as a real press does.
func _press_item() -> void:
	(battle.unit_menu.get_node("%Options/Item") as Button).pressed.emit()


func test_no_item_option_with_an_empty_inventory() -> void:
	lyn.unit.inventory.remove_at(1)
	lyn.unit.inventory.remove_at(0)
	_lyn_in_unit_menu()
	assert_eq(battle.unit_menu.options, [&"status", &"wait"] as Array[StringName])


func test_item_opens_the_item_menu() -> void:
	_lyn_in_item_menu()
	assert_true(battle.item_menu.visible)
	assert_false(battle.unit_menu.visible)
	assert_false(battle.terrain_panel.visible, "panel hides behind menus")


func test_cancel_in_the_item_menu_goes_back_to_the_unit_menu_without_undoing_the_move() -> void:
	_select_lyn()
	battle.cursor.set_cell(Vector2i(8, 5))
	battle.confirm()
	await wait_seconds(Level.STEP_TIME * 2 + 0.2)
	_press_item()
	battle.cancel()
	assert_eq(battle.state, Battle.State.UNIT_MENU)
	assert_false(battle.item_menu.visible)
	assert_true(battle.unit_menu.visible)
	assert_eq(lyn.cell, Vector2i(8, 5), "still where it moved")


func test_equip_from_the_item_menu_stays_in_the_item_menu() -> void:
	lyn.unit.inventory.add(GameData.get_item(&"steel_sword"))
	_lyn_in_item_menu()
	battle.item_menu.action_chosen.emit(&"equip", 2)
	assert_eq(battle.state, Battle.State.ITEM_MENU)
	assert_true(battle.item_menu.visible)
	assert_eq(lyn.unit.equipped_weapon(), GameData.get_item(&"steel_sword"))
	var first_row := battle.item_menu.get_node("%Rows").get_child(0)
	assert_eq((first_row.get_node("Columns/ItemName") as Label).text, "Steel Sword", "new weapon on top")
	assert_false(lyn.has_acted)


func test_use_from_the_item_menu_ends_the_action() -> void:
	lyn.current_hp = 5
	_lyn_in_item_menu()
	battle.item_menu.action_chosen.emit(&"use", 1)
	assert_eq(lyn.current_hp, 15)
	assert_true(lyn.has_acted)
	assert_eq(battle.state, Battle.State.FREE)
	assert_false(battle.item_menu.visible)
	assert_false(battle.unit_menu.visible)


func test_a_refused_use_keeps_the_item_menu_open() -> void:
	_lyn_in_item_menu()
	battle.item_menu.action_chosen.emit(&"use", 1)
	assert_eq(battle.state, Battle.State.ITEM_MENU, "full HP: nothing happens")
	assert_true(battle.item_menu.visible)
	assert_false(lyn.has_acted)


func test_attack_marks_the_cells_in_range_red() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	_select_lyn()
	battle.confirm()
	assert_true(battle.attack_cells.is_empty(), "nothing marked until Attack is picked")
	battle.unit_menu.option_selected.emit(&"attack")
	assert_eq(battle.attack_cells.size(), 4, "the four neighbours")
	for offset in Pathfinding.NEIGHBOURS:
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


func test_hovering_another_target_switches_the_forecast() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	var brigand := LevelUnitState.from_reference(bandit.unit_ref)
	brigand.cell = LYN_CELL + Vector2i.DOWN
	battle.level.level_state.level_units["brigand"] = brigand
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	battle.point_at_target(brigand.cell)
	assert_eq(battle.cursor.cell, brigand.cell)
	assert_eq(battle.targets[battle.target_index], brigand)
	battle.point_at_target(LYN_CELL + Vector2i.UP)
	assert_eq(battle.cursor.cell, brigand.cell, "not a target: nothing changes")


func test_left_click_anywhere_confirms_the_forecast() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	battle.roll = _always(10)
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	battle._unhandled_input(click)
	assert_eq(battle.state, Battle.State.COMBAT)
	assert_false(battle.forecast.visible)
	await wait_seconds(FIGHT_TIME)
	assert_true(lyn.has_acted)


func test_the_forecast_stays_top_left() -> void:
	# The bandit is on the left half, which used to flip the panel right.
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	assert_eq(battle.forecast.anchor_left, 0.0)
	assert_eq(battle.forecast.anchor_right, 0.0)


func test_the_terrain_panel_stays_bottom_left() -> void:
	battle.cursor.set_cell(Vector2i(1, 1))
	assert_eq(battle.terrain_panel.anchor_left, 0.0, "cursor on the left half")
	assert_eq(battle.terrain_panel.anchor_top, 1.0)


# --- Unit panel and status screen ---------------------------------------------
# Wil (6, 7) is a player unit in this fixture, so the player side is Lyn and Wil.


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	battle._unhandled_input(event)


func test_the_unit_panel_shows_the_unit_under_the_cursor() -> void:
	battle.cursor.set_cell(LYN_CELL)
	assert_true(battle.unit_panel.visible)
	assert_eq((battle.unit_panel.get_node("%UnitName") as Label).text, "Lyn")
	assert_eq(battle.unit_panel.theme_type_variation, &"UnitPanelPlayer")
	battle.cursor.set_cell(bandit.cell)
	assert_eq(battle.unit_panel.theme_type_variation, &"UnitPanelEnemy", "enemies show too")
	battle.cursor.set_cell(LYN_CELL + Vector2i.UP)
	assert_true(battle.unit_panel.visible, "nobody there: keeps the last unit")
	assert_eq((battle.unit_panel.get_node("%UnitName") as Label).text, "Bandit")


func test_the_unit_panel_hides_during_the_enemy_phase() -> void:
	battle.cursor.set_cell(LYN_CELL)
	battle.turn_loop.phase = TurnLoop.Phase.ENEMY
	battle.turn_loop.phase_changed.emit(TurnLoop.Phase.ENEMY)
	assert_false(battle.unit_panel.visible)
	battle.turn_loop.phase = TurnLoop.Phase.PLAYER
	battle.turn_loop.phase_changed.emit(TurnLoop.Phase.PLAYER)
	assert_true(battle.unit_panel.visible, "back for the player phase")


func test_the_unit_panel_forgets_a_unit_that_fell() -> void:
	battle.cursor.set_cell(bandit.cell)
	battle.level.remove_unit(battle.level.unit_nodes["bandit"])
	battle.cursor.set_cell(LYN_CELL + Vector2i.UP)
	assert_false(battle.unit_panel.visible)


func test_the_unit_panel_hides_behind_menus() -> void:
	_lyn_in_unit_menu()
	assert_false(battle.unit_panel.visible)


func test_the_unit_panel_shows_while_choosing_a_destination() -> void:
	_select_lyn()
	battle.cursor.set_cell(bandit.cell)
	assert_true(battle.unit_panel.visible)
	assert_eq((battle.unit_panel.get_node("%UnitName") as Label).text, "Bandit")


func test_the_status_key_opens_the_status_screen() -> void:
	battle.cursor.set_cell(bandit.cell)
	_press(&"status")
	assert_eq(battle.state, Battle.State.STATUS)
	assert_true(battle.status_screen.visible)
	assert_true(battle.status_screen.can_cycle)
	assert_false(battle.unit_panel.visible)
	assert_false(battle.terrain_panel.visible)


func test_the_status_key_on_empty_ground_does_nothing() -> void:
	battle.cursor.set_cell(LYN_CELL + Vector2i.UP)
	_press(&"status")
	assert_eq(battle.state, Battle.State.FREE)
	assert_false(battle.status_screen.visible)


func test_status_cycles_within_the_faction_and_closing_moves_the_cursor() -> void:
	var wil: LevelUnitState = battle.level.level_state.level_units["wil"]
	battle.cursor.set_cell(LYN_CELL)
	battle.open_status(battle.level.unit_nodes["lyn"], true)
	battle.status_screen.cycle_requested.emit(1)
	assert_eq(battle.status_unit.state, wil)
	battle.status_screen.cycle_requested.emit(1)
	assert_eq(battle.status_unit.state, lyn, "wraps around, skipping the bandit")
	battle.status_screen.cycle_requested.emit(-1)
	battle.cancel()
	assert_eq(battle.state, Battle.State.FREE)
	assert_false(battle.status_screen.visible)
	assert_eq(battle.cursor.cell, wil.cell)
	assert_true(battle.unit_panel.visible)


func test_right_click_on_a_unit_opens_status_when_nothing_is_selected() -> void:
	battle.cursor.set_cell(LYN_CELL)
	battle.right_click(bandit.cell)
	assert_eq(battle.state, Battle.State.STATUS)
	assert_eq(battle.status_unit.state, bandit)


func test_right_click_still_cancels_a_selection() -> void:
	_select_lyn()
	battle.right_click(LYN_CELL)
	assert_eq(battle.state, Battle.State.FREE)
	assert_false(battle.status_screen.visible)


func test_status_from_the_unit_menu_returns_to_it() -> void:
	_select_lyn()
	battle.cursor.set_cell(Vector2i(8, 5))
	battle.confirm()
	await wait_seconds(Level.STEP_TIME * 2 + 0.2)
	battle.unit_menu.option_selected.emit(&"status")
	assert_eq(battle.state, Battle.State.STATUS)
	assert_false(battle.status_screen.can_cycle)
	battle.status_screen.closed.emit()
	assert_eq(battle.state, Battle.State.UNIT_MENU)
	assert_true(battle.unit_menu.visible)
	assert_eq(lyn.cell, Vector2i(8, 5), "the move is kept")


# --- Map menu --------------------------------------------------------------


func test_the_map_menu_is_top_left() -> void:
	assert_eq(battle.map_menu.anchor_left, 0.0)
	assert_eq(battle.map_menu.anchor_right, 0.0)
	assert_eq(battle.map_menu.position, battle.unit_menu.position, "same spot as the unit menu")


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


# --- Hover ranges ------------------------------------------------------------
# The fixture makes the bandit Stationary; tests that need it to move set it
# back to Aggressive.


func _overlay() -> RangeOverlay:
	return battle.range_overlay


func _ranges(unit: LevelUnitState, stays_put := false) -> UnitRanges:
	return UnitRanges.compute(battle.level.pathfinding, unit,
			battle.level.level_state.map_data.bounds(), stays_put)


func _make_bandit_aggressive() -> void:
	battle.turn_loop.enemy_controller.set_strategy(&"bandit", EnemyAI.Strategy.AGGRESSIVE)


func _ally_wil() -> LevelUnitState:
	var wil: LevelUnitState = battle.level.level_state.level_units["wil"]
	wil.unit_ref.faction = UnitReference.Faction.ALLY  # the fixture made it a player unit
	return wil


func test_hovering_an_aggressive_enemy_shows_its_move_and_attack_range() -> void:
	_make_bandit_aggressive()
	battle.cursor.set_cell(bandit.cell)
	var expected := _ranges(bandit)
	assert_true(_overlay().move_cells.size() > 1)
	assert_eq(_overlay().move_cells, expected.move_cells)
	assert_eq(_overlay().attack_cells, expected.attack_cells)


func test_hovering_a_stationary_enemy_shows_only_where_it_stands() -> void:
	battle.cursor.set_cell(bandit.cell)
	assert_eq(_overlay().move_cells, {bandit.cell: true}, "it never moves")
	assert_eq(_overlay().attack_cells.size(), 4, "just its Iron Axe's reach")


func test_the_cursor_starts_on_lyn_showing_her_range() -> void:
	assert_eq(_overlay().move_cells, _ranges(lyn).move_cells, "no cursor move needed")
	assert_eq(_overlay().attack_cells, _ranges(lyn).attack_cells)


func test_hovering_a_player_unit_that_can_act_shows_its_range() -> void:
	battle.cursor.set_cell(LYN_CELL + Vector2i.RIGHT)
	battle.cursor.set_cell(LYN_CELL)
	assert_eq(_overlay().move_cells, _ranges(lyn).move_cells)
	assert_eq(_overlay().attack_cells, _ranges(lyn).attack_cells)


func test_hovering_a_player_unit_that_has_acted_shows_nothing() -> void:
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"wait")
	assert_eq(battle.cursor.cell, LYN_CELL)
	assert_true(_overlay().move_cells.is_empty())
	assert_true(_overlay().attack_cells.is_empty())


func test_hovering_an_ally_shows_its_range() -> void:
	var wil := _ally_wil()
	battle.cursor.set_cell(wil.cell)
	assert_eq(_overlay().move_cells, _ranges(wil).move_cells)
	assert_false(_overlay().attack_cells.is_empty())


func test_hovering_empty_ground_clears_the_range() -> void:
	battle.cursor.set_cell(bandit.cell)
	battle.cursor.set_cell(LYN_CELL + Vector2i.DOWN)
	assert_true(_overlay().move_cells.is_empty())
	assert_true(_overlay().attack_cells.is_empty())


func test_redrawing_the_selection_in_free_leaves_the_hover_alone() -> void:
	battle.cursor.set_cell(bandit.cell)
	battle._redraw_selection()
	assert_eq(_overlay().move_cells, {bandit.cell: true})


# --- Hover redraws and the selected unit's own range --------------------------


func test_moving_the_cursor_while_selected_keeps_the_selected_range() -> void:
	_select_lyn()
	battle.cursor.set_cell(bandit.cell)
	assert_eq(_overlay().move_cells, battle.reachable, "the bandit's hover doesn't replace lyn's blue")


func test_selecting_a_unit_shows_its_red_fringe() -> void:
	_select_lyn()
	assert_false(battle.selected_fringe.is_empty())
	assert_eq(battle.selected_fringe, _ranges(lyn).attack_cells)
	assert_eq(_overlay().attack_cells, battle.selected_fringe)
	assert_true(battle.attack_cells.is_empty(), "targeting cells only come with Attack")


func test_targeting_draws_the_attack_cells_after_the_cursor_moves() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	assert_eq(battle.cursor.cell, bandit.cell, "the forecast moved the cursor")
	assert_eq(_overlay().attack_cells, battle.attack_cells)


func test_after_a_move_the_unit_menu_shows_no_fringe() -> void:
	bandit.cell = Vector2i(9, 4)
	_select_lyn()
	battle.cursor.set_cell(Vector2i(8, 4))
	battle.confirm()
	await wait_seconds(Level.STEP_TIME * 3 + 0.3)
	assert_eq(battle.state, Battle.State.UNIT_MENU)
	assert_true(battle.selected_fringe.is_empty())
	assert_true(_overlay().attack_cells.is_empty(), "no red around the cell lyn left")
	battle.unit_menu.option_selected.emit(&"attack")
	assert_false(_overlay().attack_cells.is_empty())
	battle.forecast.close()
	battle.forecast.cancelled.emit()
	assert_eq(battle.state, Battle.State.UNIT_MENU)
	assert_true(_overlay().attack_cells.is_empty(), "back from the forecast: still no red")


func test_cancelling_a_selection_shows_the_hover_again() -> void:
	_select_lyn()
	battle.cancel()
	assert_eq(battle.state, Battle.State.FREE)
	assert_eq(battle.cursor.cell, LYN_CELL)
	assert_eq(_overlay().move_cells, _ranges(lyn).move_cells, "without moving the cursor")
	assert_eq(_overlay().attack_cells, _ranges(lyn).attack_cells)


func test_opening_the_map_menu_clears_the_hover() -> void:
	var wil := _ally_wil()
	battle.cursor.set_cell(wil.cell)
	assert_false(_overlay().move_cells.is_empty())
	battle.confirm()
	assert_eq(battle.state, Battle.State.MAP_MENU)
	assert_true(_overlay().move_cells.is_empty())
	assert_true(_overlay().attack_cells.is_empty())


func test_ending_the_turn_on_an_ally_shows_no_range_in_the_enemy_phase() -> void:
	var wil := _ally_wil()
	battle.cursor.set_cell(wil.cell)
	var seen := {"enemy_phase_cells": -1}
	battle.turn_loop.phase_changed.connect(func(phase: TurnLoop.Phase) -> void:
		if phase == TurnLoop.Phase.ENEMY:
			seen["enemy_phase_cells"] = _overlay().move_cells.size() + _overlay().attack_cells.size())
	battle.confirm()
	battle.map_menu.option_selected.emit(&"end")
	assert_eq(seen["enemy_phase_cells"], 0, "the ally's range is gone while enemies act")


# --- Danger zone ---------------------------------------------------------------


func test_the_danger_zone_starts_off() -> void:
	assert_false(battle.danger_zone.enabled)
	assert_true(_overlay().threat_cells.is_empty())


func test_the_danger_zone_key_toggles_every_enemys_threat() -> void:
	_press(&"danger_zone")
	assert_true(battle.danger_zone.enabled)
	assert_eq(_overlay().threat_cells, _ranges(bandit, true).threat_cells, "the Stationary bandit's reach")
	_press(&"danger_zone")
	assert_false(battle.danger_zone.enabled)
	assert_true(_overlay().threat_cells.is_empty())


func test_the_map_menu_toggles_the_danger_zone() -> void:
	battle.cursor.set_cell(LYN_CELL + Vector2i.DOWN)
	battle.confirm()
	assert_true(battle.map_menu.options.has(&"danger_zone"))
	battle.map_menu.option_selected.emit(&"danger_zone")
	assert_eq(battle.state, Battle.State.FREE)
	assert_true(battle.danger_zone.enabled)
	assert_false(_overlay().threat_cells.is_empty())


func test_the_preview_follows_a_projected_move_and_cancel_reverts_it() -> void:
	_make_bandit_aggressive()
	bandit.unit.stats.movement = 1
	_press(&"danger_zone")
	assert_true(_overlay().threat_cells.has(Vector2i(8, 5)), "via (9, 5)")
	_select_lyn()
	battle.cursor.set_cell(Vector2i(9, 5))
	battle.confirm()
	await wait_seconds(Level.STEP_TIME * 3 + 0.3)
	assert_eq(battle.state, Battle.State.UNIT_MENU)
	assert_false(_overlay().threat_cells.has(Vector2i(8, 5)), "lyn on (9, 5) blocks the bandit")
	battle.cancel()
	assert_eq(lyn.cell, LYN_CELL)
	assert_true(_overlay().threat_cells.has(Vector2i(8, 5)), "cancel puts the zone back")


func test_waiting_makes_the_preview_final() -> void:
	_make_bandit_aggressive()
	bandit.unit.stats.movement = 1
	_press(&"danger_zone")
	_select_lyn()
	battle.cursor.set_cell(Vector2i(9, 5))
	battle.confirm()
	await wait_seconds(Level.STEP_TIME * 3 + 0.3)
	battle.unit_menu.option_selected.emit(&"wait")
	assert_eq(battle.state, Battle.State.FREE)
	assert_false(_overlay().threat_cells.has(Vector2i(8, 5)))


func test_the_danger_zone_hides_in_the_enemy_phase_and_comes_back() -> void:
	_press(&"danger_zone")
	battle.cursor.set_cell(bandit.cell)
	battle.confirm()  # marks the bandit
	assert_false(_overlay().marked_threat_cells.is_empty())
	# turn_loop.phase is left alone: the refresh must go by the phase it's given.
	battle.turn_loop.phase_changed.emit(TurnLoop.Phase.ENEMY)
	assert_true(_overlay().threat_cells.is_empty())
	assert_true(_overlay().marked_threat_cells.is_empty())
	assert_true(_overlay().move_cells.is_empty(), "no hover either")
	battle.turn_loop.phase_changed.emit(TurnLoop.Phase.PLAYER)
	assert_true(battle.danger_zone.enabled)
	assert_true(battle.danger_zone.is_marked("bandit"), "marks survive the enemy phase")
	assert_false(_overlay().marked_threat_cells.is_empty())


func test_a_killed_marked_enemy_loses_its_zone() -> void:
	bandit.cell = LYN_CELL + Vector2i.RIGHT
	bandit.current_hp = 1
	battle.roll = _always(10)
	battle.cursor.set_cell(bandit.cell)
	battle.confirm()  # marks the bandit
	assert_true(battle.danger_zone.is_marked("bandit"))
	_select_lyn()
	battle.confirm()
	battle.unit_menu.option_selected.emit(&"attack")
	battle.forecast.close()
	battle.forecast.confirmed.emit()
	await wait_seconds(FIGHT_TIME)
	assert_false(bandit.is_alive())
	assert_false(battle.danger_zone.is_marked("bandit"))
	assert_true(_overlay().marked_threat_cells.is_empty())
