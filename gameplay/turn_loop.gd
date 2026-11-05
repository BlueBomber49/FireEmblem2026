class_name TurnLoop
extends Node
## Coordinates player and enemy phases for one loaded Level.

enum Phase { PLAYER, ENEMY, COMPLETE }

signal phase_changed(phase: Phase)
## The level is over: [param won] is true when every enemy fell.
signal finished(won: bool)

var phase := Phase.COMPLETE
var battle: Battle
var level: Level
var enemy_controller: EnemyController
## What ends the level; checked after every action.
var objective: Objective


## Connected by Battle after its Level has loaded and built its unit nodes.
## Without [param p_objective], the level is a rout (Objective's defaults).
func setup(p_battle: Battle, p_level: Level, p_objective: Objective = null) -> void:
	battle = p_battle
	level = p_level
	objective = p_objective if p_objective != null else Objective.new()
	if level == null or level.level_state == null:
		return
	enemy_controller = EnemyController.new(level.level_state, level.pathfinding)
	_begin_player_phase()
	_check_end()


func is_player_turn() -> bool:
	return phase == Phase.PLAYER


## Called after a player attack, item use, or wait action has resolved.
func on_player_action_completed() -> void:
	if phase != Phase.PLAYER or _is_complete():
		return
	if _check_end():
		return
	if _all_units_acted(UnitReference.Faction.PLAYER):
		await _run_enemy_phase()


## The map menu's End command can finish the player phase early.
func end_player_turn() -> void:
	if phase == Phase.PLAYER and not _is_complete():
		await _run_enemy_phase()


func _run_enemy_phase() -> void:
	if phase != Phase.PLAYER or _is_complete():
		return
	_start_enemy_phase()

	while true:
		var enemy := enemy_controller.next_enemy()
		if enemy == null:
			break
		# The plan is intentionally calculated here, after the previous enemy's
		# action has changed the board and possibly defeated a player unit.
		var action := enemy_controller.plan_action(enemy)
		await _execute_enemy_action(enemy, action)
		enemy.has_acted = true
		if not enemy.has_moved:
			enemy.has_moved = true
		level.update_tints()

		if _check_end():
			return

	_begin_player_phase()


## Switches to the enemy phase: enemies' turn flags reset, then the tints redraw
## for the enemy side. Tinting after the reset matters: until then every enemy
## still carries has_acted from its last phase and would show as gray.
func _start_enemy_phase() -> void:
	phase = Phase.ENEMY
	level.acting_faction = UnitReference.Faction.ENEMY
	phase_changed.emit(phase)
	enemy_controller.begin_turn()
	level.update_tints()


func _execute_enemy_action(enemy: LevelUnitState, action: EnemyAIAction) -> void:
	if enemy == null or not enemy.is_alive() or action == null:
		return
	var node := level.unit_nodes.get(enemy.unit_ref.id) as LevelUnit
	if node == null:
		return

	match action.type:
		EnemyAIAction.Type.HEAL:
			enemy.unit.use_item(action.inventory_index)
		EnemyAIAction.Type.MOVE:
			await _move_enemy(enemy, node, action.destination)
		EnemyAIAction.Type.ATTACK:
			await _move_enemy(enemy, node, action.destination)
			var target := enemy_controller.state_for(action.target)
			if target != null and target.is_alive() \
					and Combat.can_strike(enemy.unit, Combat.distance(enemy, target)):
				await battle.execute_enemy_attack(enemy, target)
		EnemyAIAction.Type.WAIT:
			pass


func _move_enemy(enemy: LevelUnitState, node: LevelUnit, destination: Vector2i) -> void:
	if destination == enemy.cell:
		return
	var path := level.pathfinding.find_path(enemy, destination)
	if path.size() > 1:
		await level.walk(node, path)


func _begin_player_phase() -> void:
	for value: Variant in level.level_state.level_units.values():
		var state := value as LevelUnitState
		if state != null and state.unit_ref.faction == UnitReference.Faction.PLAYER:
			state.reset_turn()
	phase = Phase.PLAYER
	level.acting_faction = UnitReference.Faction.PLAYER
	phase_changed.emit(phase)
	level.update_tints()


## Finishes the level if the objective says it's over. True when it did.
func _check_end() -> bool:
	match objective.outcome(level.level_state):
		Objective.Outcome.WON:
			_finish(true)
			return true
		Objective.Outcome.LOST:
			_finish(false)
			return true
	return false


func _all_units_acted(faction: int) -> bool:
	for value: Variant in level.level_state.level_units.values():
		var state := value as LevelUnitState
		if state != null and state.unit_ref.faction == faction and state.is_alive() \
				and not state.has_acted:
			return false
	return true


func _is_complete() -> bool:
	return phase == Phase.COMPLETE


func _finish(won: bool) -> void:
	phase = Phase.COMPLETE
	phase_changed.emit(phase)
	finished.emit(won)
