class_name EnemyAIAction
extends RefCounted
## A requested enemy action. A battle controller executes the plan and updates
## the board; the AI itself only chooses what it wants to do.

enum Type { WAIT, HEAL, MOVE, ATTACK }

var type: Type = Type.WAIT
## Destination for MOVE and ATTACK. ATTACK may use the unit's current cell.
var destination: Vector2i = Vector2i.ZERO
var target: Unit
## Inventory slot for HEAL. The controller should call Unit.use_item on it.
var inventory_index: int = -1


static func wait() -> EnemyAIAction:
	return EnemyAIAction.new()


static func heal(item_index: int) -> EnemyAIAction:
	var action := EnemyAIAction.new()
	action.type = Type.HEAL
	action.inventory_index = item_index
	return action


static func move(to: Vector2i) -> EnemyAIAction:
	var action := EnemyAIAction.new()
	action.type = Type.MOVE
	action.destination = to
	return action


static func attack(to: Vector2i, victim: Unit) -> EnemyAIAction:
	var action := EnemyAIAction.new()
	action.type = Type.ATTACK
	action.destination = to
	action.target = victim
	return action
