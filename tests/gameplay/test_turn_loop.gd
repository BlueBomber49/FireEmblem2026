extends GutTest
## Turn-cycle tests use the playable scene on simple_level: Lyn, Wil and Kent
## against the bandit and brigand. The level is set here rather than taken from
## battle.tscn, so changing the level the game opens with doesn't break them.

const BattleScene: PackedScene = preload("res://gameplay/battle.tscn")
const LEVEL_PATH := "res://resources/levels/simple_level.json"

var _battle: Battle
var _loop: TurnLoop


func before_each() -> void:
	_battle = BattleScene.instantiate()
	(_battle.get_node("Level") as Level).level_path = LEVEL_PATH
	_battle.show_banners = false
	add_child_autofree(_battle)
	_loop = _battle.turn_loop
	# Keep enemy actions instantaneous and predictable in phase-transition tests.
	_loop.enemy_controller.set_strategy(&"bandit", EnemyAI.Strategy.STATIONARY)
	_loop.enemy_controller.set_strategy(&"brigand", EnemyAI.Strategy.STATIONARY)


func test_setup_starts_on_the_player_phase() -> void:
	assert_eq(_loop.phase, TurnLoop.Phase.PLAYER)
	assert_true(_loop.is_player_turn())
	for id in ["lyn", "wil", "kent"]:
		var unit: LevelUnitState = _battle.level.level_state.level_units[id]
		assert_false(unit.has_moved)
		assert_false(unit.has_acted)


func test_player_action_does_not_end_phase_while_another_living_player_can_act() -> void:
	var lyn: LevelUnitState = _battle.level.level_state.level_units["lyn"]
	lyn.has_acted = true
	await _loop.on_player_action_completed()

	assert_eq(_loop.phase, TurnLoop.Phase.PLAYER)
	assert_true(_loop.is_player_turn())


func test_all_player_actions_run_enemy_phase_then_reset_player_flags() -> void:
	for id in ["lyn", "wil", "kent"]:
		var unit: LevelUnitState = _battle.level.level_state.level_units[id]
		unit.has_acted = true
		unit.has_moved = true

	await _loop.on_player_action_completed()

	assert_eq(_loop.phase, TurnLoop.Phase.PLAYER, "enemy phase completes and returns control")
	assert_true(_loop.is_player_turn())
	for id in ["lyn", "wil", "kent"]:
		var unit: LevelUnitState = _battle.level.level_state.level_units[id]
		assert_false(unit.has_moved, "player movement flags reset for the new phase")
		assert_false(unit.has_acted, "player action flags reset for the new phase")
	for id in ["bandit", "brigand"]:
		var enemy: LevelUnitState = _battle.level.level_state.level_units[id]
		assert_true(enemy.has_acted, "each enemy completes exactly one action")


func test_end_player_turn_can_start_enemy_phase_early() -> void:
	var lyn: LevelUnitState = _battle.level.level_state.level_units["lyn"]
	assert_false(lyn.has_acted)
	await _loop.end_player_turn()

	assert_eq(_loop.phase, TurnLoop.Phase.PLAYER)
	assert_true(_loop.is_player_turn())
	assert_false(lyn.has_acted, "ending the phase does not mark an unused unit as acted")
	assert_true((_battle.level.level_state.level_units["bandit"] as LevelUnitState).has_acted)


func test_defeating_last_enemy_completes_game_with_win_state() -> void:
	(_battle.level.level_state.level_units["bandit"] as LevelUnitState).current_hp = 0
	(_battle.level.level_state.level_units["brigand"] as LevelUnitState).current_hp = 0
	watch_signals(_loop)

	await _loop.on_player_action_completed()

	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_false(_loop.is_player_turn())
	assert_signal_emitted_with_parameters(_loop, "finished", [true])


func test_enemy_phase_completes_with_defeat_when_all_players_are_dead() -> void:
	for id in ["lyn", "wil", "kent"]:
		(_battle.level.level_state.level_units[id] as LevelUnitState).current_hp = 0
	watch_signals(_loop)

	await _loop.end_player_turn()

	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_false(_loop.is_player_turn())
	assert_signal_emitted_with_parameters(_loop, "finished", [false])


func test_dead_players_do_not_prevent_the_remaining_players_from_ending_the_phase() -> void:
	var lyn: LevelUnitState = _battle.level.level_state.level_units["lyn"]
	var wil: LevelUnitState = _battle.level.level_state.level_units["wil"]
	var kent: LevelUnitState = _battle.level.level_state.level_units["kent"]
	lyn.has_acted = true
	wil.has_acted = true
	kent.current_hp = 0

	await _loop.on_player_action_completed()

	assert_eq(_loop.phase, TurnLoop.Phase.PLAYER)
	assert_false(lyn.has_acted, "new player phase resets living units")
	assert_false(wil.has_acted)
	assert_true(kent.current_hp == 0)


func test_completed_game_ignores_later_end_turn_requests() -> void:
	(_battle.level.level_state.level_units["bandit"] as LevelUnitState).current_hp = 0
	(_battle.level.level_state.level_units["brigand"] as LevelUnitState).current_hp = 0
	await _loop.on_player_action_completed()
	await _loop.end_player_turn()

	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)


func test_lord_falling_ends_the_level_in_defeat_with_others_alive() -> void:
	_loop.set_objective(Objective.fromJson({"lose": [{"type": "units_fall", "units": ["lyn"]}]}))
	watch_signals(_loop)
	(_battle.level.level_state.level_units["lyn"] as LevelUnitState).current_hp = 0
	await _loop.on_player_action_completed()

	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_signal_emitted_with_parameters(_loop, "finished", [false])


func test_setup_without_an_objective_is_a_rout() -> void:
	var loop := TurnLoop.new()
	add_child_autofree(loop)
	loop.setup(null, null)
	assert_eq(loop.objective.win.size(), 1)
	assert_eq(loop.objective.lose.size(), 0, "the full-wipe loss is built in, not listed")


# --- Turn counter ---------------------------------------------------------------


func test_the_turn_counter_goes_up_after_each_enemy_phase() -> void:
	watch_signals(_loop)
	assert_eq(_loop.turn(), 1)
	await _loop.end_player_turn()
	assert_eq(_loop.turn(), 2)
	assert_signal_emitted_with_parameters(_loop, "turn_changed", [2])
	await _loop.end_player_turn()
	assert_eq(_loop.turn(), 3)
	assert_signal_emit_count(_loop, "turn_changed", 2)


# --- Objectives that count turns ---------------------------------------------------


func _objective(d: Dictionary) -> Objective:
	return Objective.fromJson(d)


func test_survive_wins_after_that_many_enemy_phases() -> void:
	_loop.set_objective(_objective({"win": [{"type": "survive", "turns": 2}]}))
	watch_signals(_loop)
	await _loop.end_player_turn()
	assert_eq(_loop.phase, TurnLoop.Phase.PLAYER, "one enemy phase isn't enough")
	await _loop.end_player_turn()
	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_signal_emitted_with_parameters(_loop, "finished", [true])


func test_turns_pass_loses_after_that_many_enemy_phases() -> void:
	_loop.set_objective(_objective({"lose": [{"type": "turns_pass", "turns": 1}]}))
	watch_signals(_loop)
	await _loop.end_player_turn()
	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_signal_emitted_with_parameters(_loop, "finished", [false])


# --- Changing the objective ---------------------------------------------------------


func test_set_objective_announces_the_change() -> void:
	watch_signals(_loop)
	var objective := _objective({"win": [{"type": "survive", "turns": 5}]})
	_loop.set_objective(objective)
	assert_same(_loop.objective, objective)
	assert_same(_battle.level.level_state.objective, objective, "the level's objective is the one checked")
	assert_signal_emitted_with_parameters(_loop, "objective_changed", [objective])
	assert_eq(_loop.phase, TurnLoop.Phase.PLAYER)


func test_an_objective_already_met_ends_the_level_at_once() -> void:
	watch_signals(_loop)
	_battle.level.level_state.seized = true
	_loop.set_objective(_objective({"win": [{"type": "seize", "cells": [[0, 0]]}]}))
	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_signal_emitted_with_parameters(_loop, "finished", [true])


## The bandit (made Aggressive) starts 3 cells from lyn: it walks over, then would
## attack (Kent, as it happens).
func _bandit_walks_toward_lyn() -> LevelUnitState:
	var bandit: LevelUnitState = _battle.level.level_state.level_units["bandit"]
	var lyn: LevelUnitState = _battle.level.level_state.level_units["lyn"]
	_loop.enemy_controller.set_strategy(&"bandit", EnemyAI.Strategy.AGGRESSIVE)
	_battle.level.place_unit(_battle.level.unit_nodes["bandit"], lyn.cell + Vector2i(3, 0))
	return bandit


func _player_hp() -> Dictionary:
	var hp := {}
	for id in ["lyn", "wil", "kent"]:
		hp[id] = (_battle.level.level_state.level_units[id] as LevelUnitState).current_hp
	return hp


func test_the_level_ends_only_once_when_won_mid_enemy_phase() -> void:
	_bandit_walks_toward_lyn()
	_battle.roll = func() -> int: return 0  # every strike hits: an attack would show
	var hp := _player_hp()
	watch_signals(_loop)
	_loop.end_player_turn()  # not awaited: the bandit is now walking
	await wait_process_frames(2)
	assert_eq(_loop.phase, TurnLoop.Phase.ENEMY)
	_battle.level.level_state.seized = true
	_loop.set_objective(_objective({"win": [{"type": "seize", "cells": [[0, 0]]}]}))
	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	await wait_seconds(Level.STEP_TIME * 4 + 3.0)  # the walk, and any fight, would be over
	assert_signal_emit_count(_loop, "finished", 1)
	assert_eq(_player_hp(), hp, "the bandit doesn't attack once the level is over")


func test_no_enemy_acts_when_the_level_ends_during_the_enemy_banner() -> void:
	_bandit_walks_toward_lyn()
	var bandit_cell: Vector2i = _battle.level.level_state.level_units["bandit"].cell
	var hp := _player_hp()
	_battle.show_banners = true
	watch_signals(_loop)
	_loop.end_player_turn()  # not awaited: the Enemy Phase banner is now playing
	await wait_process_frames(2)
	assert_true(_battle.phase_banner.is_playing())
	_battle.level.level_state.seized = true
	_loop.set_objective(_objective({"win": [{"type": "seize", "cells": [[0, 0]]}]}))
	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	await wait_seconds(_battle.phase_banner.slide_time * 2 + _battle.phase_banner.hold_time + 0.5)
	assert_false(_battle.phase_banner.is_playing())
	assert_signal_emit_count(_loop, "finished", 1)
	assert_eq(_battle.level.level_state.level_units["bandit"].cell, bandit_cell, "the bandit stays put")
	assert_eq(_player_hp(), hp)


func test_seize_wins_through_the_normal_action_check() -> void:
	_loop.set_objective(_objective({"win": [{"type": "seize", "cells": [[0, 0]]}]}))
	watch_signals(_loop)
	_loop.mark_seized()
	assert_eq(_loop.phase, TurnLoop.Phase.PLAYER, "marking alone doesn't end it")
	await _loop.on_player_action_completed()
	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_signal_emitted_with_parameters(_loop, "finished", [true])


# --- Enemy strategies from the level file -----------------------------------------
# simple_level's bandit (16, 5) and brigand (17, 11) start far from the players.

const STRATEGY_LEVEL := "user://test_turn_loop_strategies.json"


## A battle on simple_level with `edits` merged into its placements (new ids are
## added) and `events` as its events.
func _battle_with(edits: Dictionary, events := {}) -> Battle:
	var json := JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH)) as Dictionary
	var units: Dictionary = json["map_data"]["units"]
	for id: String in edits:
		if units.has(id):
			(units[id] as Dictionary).merge(edits[id], true)
		else:
			units[id] = edits[id]
	json["events"] = events
	var file := FileAccess.open(STRATEGY_LEVEL, FileAccess.WRITE)
	file.store_string(JSON.stringify(json))
	file.close()
	var battle: Battle = BattleScene.instantiate()
	(battle.get_node("Level") as Level).level_path = STRATEGY_LEVEL
	battle.show_banners = false
	add_child_autofree(battle)
	DirAccess.remove_absolute(STRATEGY_LEVEL)
	return battle


func _cell(battle: Battle, id: String) -> Vector2i:
	return battle.level.level_state.level_units[id].cell


func test_a_stationary_enemy_from_the_file_holds_its_cell() -> void:
	var battle := _battle_with({"bandit": {"strategy": "stationary"}})
	var bandit_start := _cell(battle, "bandit")
	var brigand_start := _cell(battle, "brigand")
	await battle.turn_loop.end_player_turn()
	assert_eq(_cell(battle, "bandit"), bandit_start)
	assert_ne(_cell(battle, "brigand"), brigand_start, "the brigand is aggressive by default")


func test_a_defensive_enemy_with_no_team_wakes_on_its_own() -> void:
	var battle := _battle_with({"bandit": {"strategy": "defensive"}, "brigand": {"strategy": "stationary"}})
	var start := _cell(battle, "bandit")
	await battle.turn_loop.end_player_turn()
	assert_eq(_cell(battle, "bandit"), start, "nobody in reach: it waits")
	battle.level.place_unit(battle.level.unit_nodes["lyn"], start + Vector2i(-3, 0))
	await battle.turn_loop.end_player_turn()
	assert_ne(_cell(battle, "bandit"), start, "a lone Defensive unit is its own team")
	# Let the fight's last signals finish before GUT frees the battle.
	await wait_process_frames(2)


func test_a_defensive_team_wakes_together() -> void:
	var battle := _battle_with({"bandit": {"strategy": "defensive", "team": "camp"},
			"brigand": {"strategy": "defensive", "team": "camp"}})
	var brigand_start := _cell(battle, "brigand")
	battle.level.place_unit(battle.level.unit_nodes["lyn"], _cell(battle, "bandit") + Vector2i(-3, 0))
	await battle.turn_loop.end_player_turn()
	assert_ne(_cell(battle, "brigand"), brigand_start, "the brigand wakes with the bandit")


# --- Reinforcements ------------------------------------------------------------------
# Two copies of the bandit tied to "wave_1", placed at (14, 5) and (14, 6).


func _battle_with_wave(turn: int, phase: String, extra := {}) -> Battle:
	var bandit: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH)) as Dictionary)[
			"map_data"]["units"]["bandit"]
	var edits := {}
	for i in [1, 2]:
		var unit: Dictionary = bandit.duplicate(true)
		unit["start_cell"] = [14, 4 + i]
		unit["event"] = "wave_1"
		edits["wave_%d" % i] = unit
	for id: String in extra:
		(edits[id] as Dictionary).merge(extra[id], true)
	return _battle_with(edits, {"wave_1": {"trigger": {"type": "turn_start", "turn": turn, "phase": phase},
			"actions": [{"type": "spawn"}]}})


func _on_map(battle: Battle, id: String) -> bool:
	return battle.level.level_state.level_units.has(id) and battle.level.unit_nodes.has(id)


func _hold_still(battle: Battle) -> void:
	battle.turn_loop.enemy_controller.set_strategy(&"bandit", EnemyAI.Strategy.STATIONARY)
	battle.turn_loop.enemy_controller.set_strategy(&"brigand", EnemyAI.Strategy.STATIONARY)


func test_a_wave_waits_then_arrives_and_acts_in_its_enemy_phase() -> void:
	var battle := _battle_with_wave(2, "enemy")
	_hold_still(battle)
	assert_false(_on_map(battle, "wave_1"), "off the map at the start")
	await battle.turn_loop.end_player_turn()  # turn 1's enemy phase
	assert_false(_on_map(battle, "wave_1"))
	await battle.turn_loop.end_player_turn()  # turn 2's: arrives, then moves
	assert_true(_on_map(battle, "wave_1"))
	assert_true(_on_map(battle, "wave_2"))
	assert_ne(_cell(battle, "wave_1"), Vector2i(14, 5), "it acted the phase it arrived")


func test_a_player_phase_arrival_doesnt_move_first() -> void:
	var battle := _battle_with_wave(2, "player")
	_hold_still(battle)
	watch_signals(battle.turn_loop)
	await battle.turn_loop.end_player_turn()
	assert_eq(battle.turn_loop.turn(), 2)
	assert_true(_on_map(battle, "wave_1"))
	assert_eq(_cell(battle, "wave_1"), Vector2i(14, 5))
	assert_signal_emit_count(battle.turn_loop, "units_arrived", 1)


func test_turn_one_player_phase_arrivals_are_there_from_the_start() -> void:
	var battle := _battle_with_wave(1, "player")
	assert_true(_on_map(battle, "wave_1"))


func test_a_blocked_cell_uses_the_nearest_free_one() -> void:
	var battle := _battle_with_wave(2, "player")
	_hold_still(battle)
	battle.level.place_unit(battle.level.unit_nodes["lyn"], Vector2i(14, 5))
	await battle.turn_loop.end_player_turn()
	var cell := _cell(battle, "wave_1")
	assert_ne(cell, Vector2i(14, 5))
	assert_eq(absi(cell.x - 14) + absi(cell.y - 5), 1, "an adjacent free cell")
	assert_ne(cell, _cell(battle, "wave_2"), "two arrivals never share a cell")


func test_an_event_fires_once() -> void:
	var battle := _battle_with_wave(2, "enemy")
	_hold_still(battle)
	watch_signals(battle.turn_loop)
	for i in 3:
		await battle.turn_loop.end_player_turn()
	assert_signal_emit_count(battle.turn_loop, "units_arrived", 1)


func test_rout_wins_with_a_wave_still_pending() -> void:
	var battle := _battle_with_wave(5, "enemy")
	watch_signals(battle.turn_loop)
	for id in ["bandit", "brigand"]:
		battle.level.level_state.level_units[id].current_hp = 0
	await battle.turn_loop.on_player_action_completed()
	assert_signal_emitted_with_parameters(battle.turn_loop, "finished", [true])


func test_a_commander_who_hasnt_arrived_isnt_defeated() -> void:
	var battle := _battle_with_wave(3, "enemy")
	battle.level.level_state.map_data.units["wave_1"].commander = true
	battle.turn_loop.set_objective(Objective.fromJson({"win": [{"type": "defeat_commander"}]}))
	assert_eq(battle.turn_loop.phase, TurnLoop.Phase.PLAYER, "not won before it arrives")


func test_arrivals_take_their_strategy_from_the_file() -> void:
	var battle := _battle_with_wave(2, "player", {"wave_1": {"strategy": "stationary"}})
	assert_eq(battle.turn_loop.enemy_controller.strategy_for("wave_1"), EnemyAI.Strategy.STATIONARY)


func test_arrivals_show_in_the_danger_zone_at_once() -> void:
	var battle := _battle_with_wave(2, "player")
	_hold_still(battle)
	battle.toggle_danger_zone()
	var arrival_cell := Vector2i(14, 5)
	assert_false(battle.danger_zone.normal_cells.has(arrival_cell + Vector2i.LEFT), "nobody threatens it yet")
	await battle.turn_loop.end_player_turn()
	assert_true(battle.danger_zone.normal_cells.has(arrival_cell + Vector2i.LEFT), "the arrival's reach is drawn")


func test_an_unknown_event_action_is_skipped_with_a_warning() -> void:
	var battle := _battle_with({}, {"odd": {"trigger": {"type": "turn_start", "turn": 2, "phase": "player"},
			"actions": [{"type": "dance"}]}})
	_hold_still(battle)
	await battle.turn_loop.end_player_turn()
	assert_push_warning("dance")
	assert_true(battle.level.level_state.fired_events.has("odd"))
