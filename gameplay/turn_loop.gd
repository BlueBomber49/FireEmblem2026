class_name TurnLoop
extends Node
## Coordinates player and enemy phases for one loaded Level, counts turns, and
## ends the level when its objective says so.
##
## Hooks for UI and events: turn() and turn_changed for a turn display,
## objective and objective_changed for an objective display, set_objective() to
## change the goal mid-level, and mark_seized() for the Seize command.

enum Phase { PLAYER, ENEMY, COMPLETE }

signal phase_changed(phase: Phase)
## The level is over: [param won] is true for a win. Emitted at most once,
## after the last phase_changed (COMPLETE).
signal finished(won: bool)
## A new turn began (after an enemy phase); [param turn] starts at 1.
signal turn_changed(turn: int)
## Reinforcements came onto the map (Level.arrive), by unit id.
signal units_arrived(ids: Array[String])
## set_objective() replaced the level's objective.
signal objective_changed(objective: Objective)

var phase := Phase.COMPLETE
var battle: Battle
var level: Level
var enemy_controller: EnemyController
## What ends the level; checked after every action. It's the level's own
## objective (LevelState.objective), so a save and set_objective() agree.
var objective: Objective:
	get:
		return level.level_state.objective if _has_level() else _objective

## Only used before a level is set up (or without one).
var _objective := Objective.new()


## Connected by Battle after its Level has loaded and built its unit nodes.
## Without [param p_objective], the level is a rout (Objective's defaults).
func setup(p_battle: Battle, p_level: Level, p_objective: Objective = null) -> void:
	battle = p_battle
	level = p_level
	if p_objective != null:
		_store_objective(p_objective)
	if not _has_level():
		return
	enemy_controller = EnemyController.new(level.level_state, level.pathfinding)
	_apply_strategies()
	# Not awaited: setup runs from Battle._ready, so the opening banner plays on.
	_begin_player_phase()
	_check_end()


## Gives each enemy placement the strategy its level file sets (aggressive needs
## nothing: it's EnemyController's default). Covers every placement, so units
## that arrive later have theirs too. A Defensive enemy with no team is a team of
## one; otherwise it would never wake up.
func _apply_strategies() -> void:
	const IN_PLAY := {
		UnitReference.STRATEGY_STATIONARY: EnemyAI.Strategy.STATIONARY,
		UnitReference.STRATEGY_DEFENSIVE: EnemyAI.Strategy.DEFENSIVE,
	}
	for ref: UnitReference in level.level_state.map_data.units.values():
		if ref.faction != UnitReference.Faction.ENEMY or not IN_PLAY.has(ref.strategy):
			continue
		var team := ref.team if not ref.team.is_empty() else "solo:" + ref.id
		enemy_controller.set_strategy(StringName(ref.id), IN_PLAY[ref.strategy], StringName(team))


## Fires each event whose trigger is the start of this turn and `for_phase`, once.
## Its spawn action brings in the units placed with that event's id.
func run_events(for_phase: Phase) -> void:
	var state := level.level_state
	var phase_name := "enemy" if for_phase == Phase.ENEMY else "player"
	for event_id: String in state.events:
		if state.fired_events.has(event_id) or not LevelState.event_problem(state.events[event_id]).is_empty():
			continue
		var event: Dictionary = state.events[event_id]
		var trigger: Dictionary = event["trigger"]
		if int(trigger["turn"]) != state.turn or str(trigger["phase"]) != phase_name:
			continue
		state.fired_events.append(event_id)
		for action: Variant in event.get("actions", []):
			if not action is Dictionary or (action as Dictionary).get("type") != "spawn":
				push_warning("Level: event '%s': unknown action %s; skipped." % [event_id, action])
				continue
			var arrived: Array[String] = []
			for id: String in state.pending_units.keys():
				if state.map_data.units[id].event == event_id and level.arrive(id).x >= 0:
					arrived.append(id)
			if not arrived.is_empty():
				units_arrived.emit(arrived)


func is_player_turn() -> bool:
	return phase == Phase.PLAYER


## The current turn: 1 for the first player phase, +1 after each enemy phase.
func turn() -> int:
	return level.level_state.turn if _has_level() else 1


## Replaces the level's objective (an event changing the goal mid-level) and
## checks it at once, so an objective that's already met ends the level.
func set_objective(new_objective: Objective) -> void:
	_store_objective(new_objective)
	objective_changed.emit(new_objective)
	if phase == Phase.PLAYER or phase == Phase.ENEMY:
		_check_end()


## Records that a unit used Escape; like mark_seized, the action's normal
## completion check then ends the level if escaping wins it.
func mark_escaped() -> void:
	if _has_level():
		level.level_state.escaped = true


## Records that a unit used Seize. The action's normal completion check
## (on_player_action_completed) then ends the level if seizing wins it.
func mark_seized() -> void:
	if _has_level():
		level.level_state.seized = true


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
	await _start_enemy_phase()
	# The level may have ended while the banner played (set_objective from an event).
	if _is_complete():
		return

	while true:
		var enemy := enemy_controller.next_enemy()
		if enemy == null:
			break
		# The plan is intentionally calculated here, after the previous enemy's
		# action has changed the board and possibly defeated a player unit.
		var action := enemy_controller.plan_action(enemy)
		await _execute_enemy_action(enemy, action)
		# The level may have ended while this enemy acted (set_objective from an event).
		if _is_complete():
			return
		enemy.has_acted = true
		if not enemy.has_moved:
			enemy.has_moved = true
		level.update_tints()

		if _check_end():
			return

	# N enemy phases are over: survive and turn-limit conditions are met now,
	# before the next player phase (and its banner) starts.
	level.level_state.turn += 1
	turn_changed.emit(level.level_state.turn)
	if _check_end():
		return
	await _begin_player_phase()


## Switches to the enemy phase: enemies' turn flags reset, then the tints redraw
## for the enemy side. Tinting after the reset matters: until then every enemy
## still carries has_acted from its last phase and would show as gray. Returns
## once Battle's phase banner is gone, so no enemy moves under it.
func _start_enemy_phase() -> void:
	phase = Phase.ENEMY
	level.acting_faction = UnitReference.Faction.ENEMY
	phase_changed.emit(phase)
	# Before begin_turn, which gathers the phase's enemies: arrivals act this phase.
	run_events(phase)
	enemy_controller.begin_turn()
	level.update_tints()
	if battle != null:
		await battle.announce_phase(phase)


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
			if _is_complete():
				return  # the level ended during the walk
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
	# Before phase_changed, so Battle's refresh for the new phase includes arrivals.
	run_events(phase)
	phase_changed.emit(phase)
	level.update_tints()
	if battle != null:
		await battle.announce_phase(phase)


## Finishes the level if the objective says it's over. True when it did, or when
## the level was already over.
func _check_end() -> bool:
	if _is_complete():
		return true
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


## Ends the level, once: a second call (say, an objective met mid-enemy-phase
## and then checked again) does nothing, so GameFlow advances only once.
func _finish(won: bool) -> void:
	if _is_complete():
		return
	phase = Phase.COMPLETE
	phase_changed.emit(phase)
	finished.emit(won)


func _has_level() -> bool:
	return level != null and level.level_state != null


func _store_objective(new_objective: Objective) -> void:
	if _has_level():
		level.level_state.objective = new_objective
	else:
		_objective = new_objective
