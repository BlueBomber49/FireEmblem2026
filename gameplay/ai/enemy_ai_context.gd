class_name EnemyAIContext
extends RefCounted
## Adapter between rules-only enemy AI and the battle/map systems.
## Extend this in the battle layer once board movement and combat APIs exist.


## Current board location for a unit. Unit deliberately does not store position.
func unit_position(_unit: Unit) -> Vector2i:
	push_error("EnemyAIContext.unit_position must be implemented by the battle layer.")
	return Vector2i.ZERO


## Legal cells the unit can end its move on, including its current cell.
## A stationary strategy ignores all returned cells except the current one.
func reachable_positions(_unit: Unit, _from: Vector2i) -> Array[Vector2i]:
	push_error("EnemyAIContext.reachable_positions must be implemented by the battle layer.")
	return []


## Whether the attacker can attack this target from the given cells. This should
## enforce weapon range and any map rules that block an attack.
func can_attack_from(_attacker: Unit, _attacker_position: Vector2i,
		_target: Unit, _target_position: Vector2i) -> bool:
	push_error("EnemyAIContext.can_attack_from must be implemented by the battle layer.")
	return false


## Combat forecast for these units at the proposed positions. Return null when
## combat cannot be evaluated. Implement using the same formulas as real combat.
func evaluate_combat(_attacker: Unit, _attacker_position: Vector2i,
		_target: Unit, _target_position: Vector2i) -> EnemyAICombatResult:
	push_error("EnemyAIContext.evaluate_combat must be implemented by the battle layer.")
	return null


## True if another living unit occupies this cell. The moving unit is excluded.
func is_occupied(_position: Vector2i, _except_unit: Unit) -> bool:
	push_error("EnemyAIContext.is_occupied must be implemented by the battle layer.")
	return false


## Numeric terrain preference used only after equally close pursuit cells are
## found. Higher is better; a typical implementation can combine defense/avoid.
func terrain_advantage(_unit: Unit, _position: Vector2i) -> int:
	return 0
