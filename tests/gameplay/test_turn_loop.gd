extends GutTest
## Turn-cycle tests use the playable scene and its authored simple level.

const BattleScene: PackedScene = preload("res://gameplay/battle.tscn")

var _battle: Battle
var _loop: TurnLoop


func before_each() -> void:
	_battle = BattleScene.instantiate()
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
