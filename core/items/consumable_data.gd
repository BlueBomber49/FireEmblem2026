class_name ConsumableData
extends ItemData
## A usable item with limited uses, such as a Vulnerary.

## Use for `heal_amount` to restore all HP.
const FULL_HEAL := -1

@export var max_uses := 1
## HP restored per use, or FULL_HEAL.
@export var heal_amount := 0


func validate() -> PackedStringArray:
	var errors := super()
	if max_uses <= 0:
		errors.append("%s: max_uses must be at least 1." % id)
	if heal_amount <= 0 and heal_amount != FULL_HEAL:
		errors.append("%s: heal_amount must be positive or FULL_HEAL." % id)
	return errors
