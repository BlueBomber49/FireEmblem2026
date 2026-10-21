class_name UnitInfo
extends RefCounted
## What an item menu or unit roster shows about one unit. Mechanics fill this in
## (from_unit); the UI only reads it, like ForecastSide and TerrainInfo.


## One inventory slot.
class ItemInfo:
	extends RefCounted
	var item_name: String = ""
	var is_weapon := false
	## The weapon attacks use: the first one this unit's class can wield.
	var equipped := false
	## Whether it can be used right now: a weapon the class can wield, or a healing
	## item while the unit is hurt.
	var usable := false
	## Uses left for consumables; -1 for items that don't track uses (weapons, for now).
	var uses_left: int = -1
	## 0 for items that don't track uses.
	var max_uses: int = 0


var unit_name: String = ""
## The class's display name ("class_name" is a GDScript keyword).
var class_name_text: String = ""
var level: int = 1
var hp: int = 0
var max_hp: int = 0
## The equipped weapon's name, or "--" without one.
var weapon_name: String = "--"
## Stats.FIELDS name -> value, e.g. {"hp": 16, "strength": 5, ...}.
var stats: Dictionary = {}
## Inventory slots in order (Array of ItemInfo).
var items: Array[ItemInfo] = []


static func from_unit(unit: Unit) -> UnitInfo:
	var info := UnitInfo.new()
	info.unit_name = unit.data.display_name
	info.class_name_text = unit.class_data().display_name
	info.level = unit.level
	info.hp = unit.current_hp
	info.max_hp = unit.max_hp()
	info.stats = unit.stats.to_dict()
	var weapon := unit.equipped_weapon()
	if weapon != null:
		info.weapon_name = weapon.display_name
	var equipped_index := unit.inventory.first_usable_weapon_index(unit.class_data())
	for i in unit.inventory.size():
		var entry := unit.inventory.get_item(i)
		var item := ItemInfo.new()
		item.item_name = entry.data.display_name
		item.is_weapon = entry.is_weapon()
		item.equipped = i == equipped_index
		if entry.is_weapon():
			item.usable = unit.class_data().can_wield(entry.data as WeaponData)
		else:
			var consumable := entry.data as ConsumableData
			item.uses_left = entry.uses_left
			item.max_uses = consumable.max_uses
			item.usable = unit.current_hp < unit.max_hp()
		info.items.append(item)
	return info
