class_name InventoryItem
extends RefCounted
## One item in a unit's inventory.
##
## Tracks remaining uses separately from the shared ItemData, so two
## Vulneraries can have different uses left. Weapons ignore uses for now.

var data: ItemData
var uses_left := 0


func _init(item: ItemData, uses: int = -1) -> void:
	data = item
	if item is ConsumableData:
		uses_left = (item as ConsumableData).max_uses if uses < 0 else uses


func is_weapon() -> bool:
	return data is WeaponData


func is_consumable() -> bool:
	return data is ConsumableData
