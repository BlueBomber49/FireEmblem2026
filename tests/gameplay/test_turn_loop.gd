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

	await _loop.on_player_action_completed()

	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_false(_loop.is_player_turn())


func test_enemy_phase_completes_with_defeat_when_all_players_are_dead() -> void:
	for id in ["lyn", "wil", "kent"]:
		(_battle.level.level_state.level_units[id] as LevelUnitState).current_hp = 0

	await _loop.end_player_turn()

	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_false(_loop.is_player_turn())


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
	watch_signals(_battle)
	(_battle.level.level_state.level_units["lyn"] as LevelUnitState).current_hp = 0
	await _loop.on_player_action_completed()

	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_signal_emitted_with_parameters(_battle, "ended", [false])


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
	watch_signals(_battle)
	await _loop.end_player_turn()
	assert_eq(_loop.phase, TurnLoop.Phase.PLAYER, "one enemy phase isn't enough")
	await _loop.end_player_turn()
	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_signal_emitted_with_parameters(_battle, "ended", [true])


func test_turns_pass_loses_after_that_many_enemy_phases() -> void:
	_loop.set_objective(_objective({"lose": [{"type": "turns_pass", "turns": 1}]}))
	watch_signals(_battle)
	await _loop.end_player_turn()
	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_signal_emitted_with_parameters(_battle, "ended", [false])


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
	watch_signals(_battle)
	_battle.level.level_state.seized = true
	_loop.set_objective(_objective({"win": [{"type": "seize", "cells": [[0, 0]]}]}))
	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_signal_emitted_with_parameters(_battle, "ended", [true])


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


func test_seize_wins_through_the_normal_action_check() -> void:
	_loop.set_objective(_objective({"win": [{"type": "seize", "cells": [[0, 0]]}]}))
	watch_signals(_battle)
	_loop.mark_seized()
	assert_eq(_loop.phase, TurnLoop.Phase.PLAYER, "marking alone doesn't end it")
	await _loop.on_player_action_completed()
	assert_eq(_loop.phase, TurnLoop.Phase.COMPLETE)
	assert_signal_emitted_with_parameters(_battle, "ended", [true])
