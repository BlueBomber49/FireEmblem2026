class_name TurnLoop
extends Node
## Coordinates player and enemy phases for one loaded Level.

enum Phase { PLAYER, ENEMY, COMPLETE }

signal phase_changed(phase: Phase)

var phase := Phase.COMPLETE
var battle: Battle
var level: Level
var enemy_controller: EnemyController


## Connected by Battle after its Level has loaded and built its unit nodes.
func setup(p_battle: Battle, p_level: Level) -> void:
	battle = p_battle
	level = p_level
	if level == null or level.level_state == null:
		return
	enemy_controller = EnemyController.new(level.level_state, level.pathfinding)
	_begin_player_phase()
	_check_initial_end_condition()


func is_player_turn() -> bool:
	return phase == Phase.PLAYER


## Called after a player attack, item use, or wait action has resolved.
func on_player_action_completed() -> void:
	if phase != Phase.PLAYER or _is_complete():
		return
	if _all_units_defeated(UnitReference.Faction.ENEMY):
		_finish("win")
		return
	if _all_units_defeated(UnitReference.Faction.PLAYER):
		_finish("defeat")
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
	phase = Phase.ENEMY
	phase_changed.emit(phase)
	enemy_controller.begin_turn()

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

		if _all_units_defeated(UnitReference.Faction.PLAYER):
			_finish("defeat")
			return
		if _all_units_defeated(UnitReference.Faction.ENEMY):
			_finish("win")
			return

	_begin_player_phase()


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
	phase_changed.emit(phase)
	level.update_tints()


func _check_initial_end_condition() -> void:
	if _all_units_defeated(UnitReference.Faction.ENEMY):
		_finish("win")
	elif _all_units_defeated(UnitReference.Faction.PLAYER):
		_finish("defeat")


func _all_units_defeated(faction: int) -> bool:
	for value: Variant in level.level_state.level_units.values():
		var state := value as LevelUnitState
		if state != null and state.unit_ref.faction == faction and state.is_alive():
			return false
	return true


func _all_units_acted(faction: int) -> bool:
	for value: Variant in level.level_state.level_units.values():
		var state := value as LevelUnitState
		if state != null and state.unit_ref.faction == faction and state.is_alive() \
				and not state.has_acted:
			return false
	return true


func _is_complete() -> bool:
	return phase == Phase.COMPLETE


func _finish(message: String) -> void:
	phase = Phase.COMPLETE
	phase_changed.emit(phase)
	print(message)
