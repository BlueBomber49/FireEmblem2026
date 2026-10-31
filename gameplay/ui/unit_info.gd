class_name UnitInfo
extends RefCounted
## What the item menu, unit panel and status screen show about one unit.
## Mechanics fill this in (from_unit, from_level_unit); the UI only reads it,
## like ForecastSide and TerrainInfo.

const HP_GREEN := Color(0.45, 0.8, 0.35)
const HP_YELLOW := Color(0.95, 0.8, 0.25)
const HP_RED := Color(0.9, 0.3, 0.25)
## Portrait art for a named character, by character id.
const PORTRAIT_PATH := "res://assets/portraits/%s.png"


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
var experience: int = 0
var hp: int = 0
var max_hp: int = 0
## The equipped weapon's name, or "--" without one.
var weapon_name: String = "--"
## Stats.FIELDS name -> value, e.g. {"hp": 16, "strength": 5, ...}.
var stats: Dictionary = {}
## Inventory slots in order (Array of ItemInfo).
var items: Array[ItemInfo] = []
## Whose side the unit is on; panels are tinted by it.
var faction := UnitReference.Faction.PLAYER
## The character's portrait art (see portrait_for), or the map sprite's first
## idle frame when there isn't any. Null for a unit that isn't on a map.
var portrait: Texture2D = null


## Green above half HP, yellow down to a quarter, red below that.
static func hp_color(current: int, maximum: int) -> Color:
	if maximum <= 0 or current * 2 > maximum:
		return HP_GREEN
	if current * 4 >= maximum:
		return HP_YELLOW
	return HP_RED


## from_unit plus what only the map knows: the unit's faction and sprite.
static func from_level_unit(node: LevelUnit) -> UnitInfo:
	var info := from_unit(node.state.unit)
	info.faction = node.reference.faction
	if node.reference.is_character():
		info.portrait = portrait_for(node.reference.character_id)
	if info.portrait == null and node.sprite_frames != null \
			and node.sprite_frames.has_animation(&"idle_down"):
		info.portrait = node.sprite_frames.get_frame_texture(&"idle_down", 0)
	return info


## A character's portrait art at PORTRAIT_PATH (keyed by character id, e.g.
## "rowland" -> rowland.png), or null when there's none. Uses ResourceLoader
## rather than FileAccess so it still finds imported images in exported builds.
static func portrait_for(character_id: String) -> Texture2D:
	var path := PORTRAIT_PATH % character_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func from_unit(unit: Unit) -> UnitInfo:
	var info := UnitInfo.new()
	info.unit_name = unit.data.display_name
	info.class_name_text = unit.class_data().display_name
	info.level = unit.level
	info.experience = unit.experience
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
