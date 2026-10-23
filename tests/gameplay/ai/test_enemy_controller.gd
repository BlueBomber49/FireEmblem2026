extends GutTest
## Controller integration against the game's authored simple level.

const LEVEL_PATH := "res://resources/levels/simple_level.json"

var _level_state: LevelState
var _controller: EnemyController


func before_each() -> void:
	_level_state = LevelState.load_file(LEVEL_PATH)
	_controller = EnemyController.new(_level_state, Pathfinding.new(_level_state))


func test_begin_turn_collects_only_living_enemies_and_resets_their_flags() -> void:
	var lyn: LevelUnitState = _level_state.level_units["lyn"]
	var bandit: LevelUnitState = _level_state.level_units["bandit"]
	var brigand: LevelUnitState = _level_state.level_units["brigand"]
	lyn.has_acted = true
	bandit.has_moved = true
	bandit.has_acted = true
	brigand.has_moved = true
	brigand.has_acted = true
	bandit.current_hp = 0

	_controller.begin_turn()

	assert_true(lyn.has_acted, "player turn flags are not reset by the enemy controller")
	assert_false(brigand.has_moved)
	assert_false(brigand.has_acted)
	assert_eq(_controller.next_enemy(), brigand, "dead enemies are skipped")
	assert_null(_controller.next_enemy())


func test_next_enemy_returns_each_living_enemy_once_then_null() -> void:
	_controller.begin_turn()
	var first := _controller.next_enemy()
	var second := _controller.next_enemy()

	assert_not_null(first)
	assert_not_null(second)
	assert_ne(first, second)
	assert_eq({first.unit_ref.id: true, second.unit_ref.id: true},
		{"bandit": true, "brigand": true})
	assert_null(_controller.next_enemy(), "a completed queue stays empty")


func test_enemies_default_to_aggressive_and_can_be_assigned_stationary() -> void:
	var bandit: LevelUnitState = _level_state.level_units["bandit"]
	var brigand: LevelUnitState = _level_state.level_units["brigand"]
	_controller.set_strategy(&"bandit", EnemyAI.Strategy.STATIONARY)
	_controller.begin_turn()

	assert_eq(_controller.plan_action(bandit).type, EnemyAIAction.Type.WAIT,
		"the stationary enemy waits when nobody is in its current attack range")
	assert_eq(_controller.plan_action(brigand).type, EnemyAIAction.Type.MOVE,
		"an unconfigured enemy uses the default aggressive strategy")


func test_defensive_team_activates_when_one_member_can_attack() -> void:
	var lyn: LevelUnitState = _level_state.level_units["lyn"]
	var bandit: LevelUnitState = _level_state.level_units["bandit"]
	var brigand: LevelUnitState = _level_state.level_units["brigand"]
	bandit.cell = lyn.cell + Vector2i.RIGHT
	_controller.set_strategy(&"bandit", EnemyAI.Strategy.DEFENSIVE, &"guard")
	_controller.set_strategy(&"brigand", EnemyAI.Strategy.DEFENSIVE, &"guard")
	_controller.begin_turn()

	assert_eq(_controller.plan_action(bandit).type, EnemyAIAction.Type.ATTACK)
	assert_eq(_controller.plan_action(brigand).type, EnemyAIAction.Type.MOVE,
		"the other team member becomes aggressive too")


func test_defensive_team_stays_defensive_when_no_member_can_attack() -> void:
	var bandit: LevelUnitState = _level_state.level_units["bandit"]
	var brigand: LevelUnitState = _level_state.level_units["brigand"]
	_controller.set_strategy(&"bandit", EnemyAI.Strategy.DEFENSIVE, &"guard")
	_controller.set_strategy(&"brigand", EnemyAI.Strategy.DEFENSIVE, &"guard")
	_controller.begin_turn()

	assert_eq(_controller.plan_action(bandit).type, EnemyAIAction.Type.WAIT)
	assert_eq(_controller.plan_action(brigand).type, EnemyAIAction.Type.WAIT)


func test_plan_action_refreshes_living_targets_between_enemies() -> void:
	var lyn: LevelUnitState = _level_state.level_units["lyn"]
	var wil: LevelUnitState = _level_state.level_units["wil"]
	var kent: LevelUnitState = _level_state.level_units["kent"]
	var bandit: LevelUnitState = _level_state.level_units["bandit"]
	var brigand: LevelUnitState = _level_state.level_units["brigand"]
	lyn.cell = Vector2i(5, 10)
	wil.cell = Vector2i(4, 11)
	kent.cell = Vector2i(6, 11)
	lyn.current_hp = 1
	bandit.cell = Vector2i(5, 9)
	brigand.cell = Vector2i(5, 11)
	_controller.begin_turn()

	var first := _controller.next_enemy()
	var first_action := _controller.plan_action(first)
	assert_eq(first_action.type, EnemyAIAction.Type.ATTACK)
	assert_not_null(first_action.target)
	var defeated_target := _controller.state_for(first_action.target)
	assert_not_null(defeated_target)
	defeated_target.current_hp = 0
	first.has_acted = true
	var second := _controller.next_enemy()
	var second_action := _controller.plan_action(second)

	assert_eq(second_action.type, EnemyAIAction.Type.ATTACK)
	assert_ne(second_action.target, defeated_target.unit,
		"the next plan excludes a target defeated earlier")
	assert_true(second_action.target == lyn.unit or second_action.target == wil.unit \
		or second_action.target == kent.unit)


func test_state_for_returns_null_for_null_or_unregistered_units() -> void:
	var outside := Unit.new(_level_state.level_units["lyn"].unit.data)
	assert_null(_controller.state_for(null))
	assert_null(_controller.state_for(outside))
	assert_eq(_controller.state_for(_level_state.level_units["lyn"].unit),
		_level_state.level_units["lyn"])


func test_null_level_state_is_a_safe_empty_controller() -> void:
	var controller := EnemyController.new(null)
	controller.begin_turn()
	assert_null(controller.next_enemy())
	assert_eq(controller.plan_action(null).type, EnemyAIAction.Type.WAIT)
