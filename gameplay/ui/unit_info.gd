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
	## Weapon stats, for the item menu's stats panel. Zero for consumables.
	var weapon_type: String = ""
	var might := 0
	var hit := 0
	var crit := 0
	var weight := 0
	var min_range := 0
	var max_range := 0
	## HP a consumable restores, or ConsumableData.FULL_HEAL. Zero for weapons.
	var heal_amount := 0

	## "1", or "1-2" for a weapon that reaches more than one distance.
	func range_text() -> String:
		if min_range == max_range:
			return str(min_range)
		return "%d-%d" % [min_range, max_range]

	## What a consumable does, e.g. "Restores 10 HP".
	func effect_text() -> String:
		if heal_amount == ConsumableData.FULL_HEAL:
			return "Restores all HP"
		return "Restores %d HP" % heal_amount


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
			var weapon_data := entry.data as WeaponData
			item.usable = unit.class_data().can_wield(weapon_data)
			item.weapon_type = Enums.weapon_type_name(weapon_data.weapon_type).capitalize()
			item.might = weapon_data.might
			item.hit = weapon_data.hit
			item.crit = weapon_data.crit
			item.weight = weapon_data.weight
			item.min_range = weapon_data.min_range
			item.max_range = weapon_data.max_range
		else:
			var consumable := entry.data as ConsumableData
			item.uses_left = entry.uses_left
			item.max_uses = consumable.max_uses
			item.heal_amount = consumable.heal_amount
			item.usable = unit.current_hp < unit.max_hp()
		info.items.append(item)
	return info
