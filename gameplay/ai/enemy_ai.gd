class_name EnemyAI
extends RefCounted
## Per-enemy strategy and turn planner. A battle controller should execute the
## returned EnemyAIAction and mark the unit as finished for the turn.

enum Strategy { STATIONARY, DEFENSIVE, AGGRESSIVE }

var strategy: Strategy = Strategy.AGGRESSIVE
## Defensive enemies with the same non-empty team id become aggressive together
## when any one of them can attack at the start of the enemy turn.
var defensive_team_id: StringName = &""


func _init(p_strategy: Strategy = Strategy.AGGRESSIVE,
		p_defensive_team_id: StringName = &"") -> void:
	strategy = p_strategy
	defensive_team_id = p_defensive_team_id


## Start-of-turn team activation. `team_members` is an array of dictionaries,
## each containing `{"ai": EnemyAI, "unit": Unit}`. Only defensive enemies
## sharing a non-empty team id are grouped. One eligible attack activates the
## whole team. The board context supplies each unit's current position.
static func begin_enemy_turn(team_members: Array[Dictionary],
		player_units: Array[Unit], context: EnemyAIContext) -> void:
	var teams: Dictionary = {}
	for member: Dictionary in team_members:
		var ai := member.get("ai") as EnemyAI
		var unit := member.get("unit") as Unit
		if ai == null or ai.strategy != Strategy.DEFENSIVE or ai.defensive_team_id.is_empty():
			continue
		if unit == null or not unit.is_alive():
			continue
		if not teams.has(ai.defensive_team_id):
			teams[ai.defensive_team_id] = []
		(teams[ai.defensive_team_id] as Array).append({"ai": ai, "unit": unit})

	for team_id: StringName in teams:
		var team: Array = teams[team_id]
		var team_can_attack := false
		for member: Dictionary in team:
			var ai := member["ai"] as EnemyAI
			var unit := member["unit"] as Unit
			var position := context.unit_position(unit)
			if EnemyAIHelpers.can_attack(unit, position, player_units, context, true):
				team_can_attack = true
				break
		if team_can_attack:
			for member: Dictionary in team:
				var ai := member["ai"] as EnemyAI
				ai.strategy = Strategy.AGGRESSIVE


## Plans this enemy's action for the turn. Supply its current position separately:
## board position and team membership intentionally live outside Unit. Pass the
## living allied units that have not acted yet so this unit can avoid blocking
## their only available attack cells.
func take_turn(unit: Unit, position: Vector2i, player_units: Array[Unit],
		context: EnemyAIContext, allied_units: Array[Unit] = []) -> EnemyAIAction:
	if unit == null or not unit.is_alive():
		return EnemyAIAction.wait()

	if EnemyAIHelpers.check_heal(unit):
		var heal_index := EnemyAIHelpers.healing_item_index(unit)
		return EnemyAIAction.heal(heal_index)

	match strategy:
		Strategy.STATIONARY:
			if EnemyAIHelpers.can_attack(unit, position, player_units, context, false):
				return EnemyAIHelpers.attack_best_target(unit, position, player_units,
						context, false, allied_units)
			return EnemyAIAction.wait()
		Strategy.DEFENSIVE:
			return EnemyAIAction.wait()
		Strategy.AGGRESSIVE:
			if EnemyAIHelpers.can_attack(unit, position, player_units, context, true):
				return EnemyAIHelpers.attack_best_target(unit, position, player_units,
						context, true, allied_units)
			return EnemyAIHelpers.find_best_target(unit, position, player_units,
					context, allied_units)
	return EnemyAIAction.wait()
