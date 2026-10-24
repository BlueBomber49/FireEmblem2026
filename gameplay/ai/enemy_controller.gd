class_name EnemyController
extends RefCounted
## Plans one enemy action at a time against the current board state.

var level_state: LevelState
var context: EnemyAIContext
var _enemy_states: Array[LevelUnitState] = []
var _ais: Dictionary = {}
var _next_index := 0


func _init(p_level_state: LevelState, p_pathfinding: Pathfinding = null) -> void:
	level_state = p_level_state
	context = EnemyAIContext.new(level_state, p_pathfinding)


## Assigns an enemy's strategy. Enemies without an explicit assignment are
## aggressive. Defensive enemies with the same non-empty team id activate
## together when begin_turn() finds an eligible attack.
func set_strategy(unit_id: StringName, strategy: int,
		defensive_team_id: StringName = &"") -> void:
	_ais[String(unit_id)] = EnemyAI.new(strategy, defensive_team_id)


## Starts a fresh enemy phase and activates defensive teams if needed.
func begin_turn() -> void:
	_enemy_states.clear()
	_next_index = 0
	if level_state == null:
		return

	for value: Variant in level_state.level_units.values():
		var state := value as LevelUnitState
		if state == null or not state.is_alive():
			continue
		if state.unit_ref.faction != UnitReference.Faction.ENEMY:
			continue
		state.reset_turn()
		_enemy_states.append(state)

	var members: Array[Dictionary] = []
	for state: LevelUnitState in _enemy_states:
		members.append({"ai": _ai_for(state), "unit": state.unit})
	EnemyAI.begin_enemy_turn(members, _living_player_units(), context)


## Returns the next living enemy that has not acted, or null when finished.
func next_enemy() -> LevelUnitState:
	while _next_index < _enemy_states.size():
		var state := _enemy_states[_next_index]
		_next_index += 1
		if state.is_alive() and not state.has_acted:
			return state
	return null


## Recalculates this enemy's action now, using the latest positions and HP.
## This is called immediately before execution so a defeated target is never
## included in a later enemy's stale plan.
func plan_action(state: LevelUnitState) -> EnemyAIAction:
	if state == null or not state.is_alive():
		return EnemyAIAction.wait()
	var allies: Array[Unit] = []
	for other: LevelUnitState in _enemy_states:
		if other != state and other.is_alive() and not other.has_acted:
			allies.append(other.unit)
	return _ai_for(state).take_turn(state.unit, state.cell,
		_living_player_units(), context, allies)


func state_for(unit: Unit) -> LevelUnitState:
	if unit == null or level_state == null:
		return null
	for value: Variant in level_state.level_units.values():
		var state := value as LevelUnitState
		if state != null and state.unit == unit:
			return state
	return null


func _ai_for(state: LevelUnitState) -> EnemyAI:
	var key := String(state.unit_ref.id)
	if not _ais.has(key):
		_ais[key] = EnemyAI.new(EnemyAI.Strategy.AGGRESSIVE)
	return _ais[key] as EnemyAI


func _living_player_units() -> Array[Unit]:
	var result: Array[Unit] = []
	if level_state == null:
		return result
	for value: Variant in level_state.level_units.values():
		var state := value as LevelUnitState
		if state != null and state.is_alive() \
				and state.unit_ref.faction == UnitReference.Faction.PLAYER:
			result.append(state.unit)
	return result
