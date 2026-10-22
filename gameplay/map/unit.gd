class_name Unit
extends RefCounted
## A unit during play: its current level, stats, HP and items.
##
## Built from a UnitData definition. Board state (position, team, turn flags)
## lives with whoever owns the board, not here.

const MAX_EXPERIENCE := 99

var data: UnitData
var level := 1
var experience := 0
## Current permanent stats. Always this unit's own copy, never shared with
## the class or the definition.
var stats: Stats
var current_hp := 0
var inventory: Inventory


## A unit can't be built without a definition, a class, and the class's base stats
## and caps. Given broken data, the constructor reports an error and produces an
## empty unit with 0 HP rather than crashing.
func _init(unit_data: UnitData) -> void:
	data = unit_data
	stats = Stats.new()
	inventory = Inventory.new()
	var problem := build_problem(unit_data)
	if not problem.is_empty():
		push_error("Can't build unit: %s" % problem)
		return
	level = clampi(unit_data.level, UnitData.MIN_LEVEL, UnitData.MAX_LEVEL)
	stats = _starting_stats(unit_data)
	current_hp = stats.hp
	for item in unit_data.starting_items:
		inventory.add(item)


## Why a unit can't be built from `unit_data`, or "" when it can.
static func build_problem(unit_data: UnitData) -> String:
	if unit_data == null:
		return "no unit definition."
	if unit_data.class_data == null:
		return "'%s' has no class." % unit_data.id
	if unit_data.class_data.base_stats == null or unit_data.class_data.caps == null:
		return "class '%s' is missing base stats or caps." % unit_data.class_data.id
	return ""


func class_data() -> ClassData:
	return data.class_data if data != null else null


func max_hp() -> int:
	return stats.hp


func is_alive() -> bool:
	return current_hp > 0


func take_damage(amount: int) -> void:
	current_hp = clampi(current_hp - maxi(amount, 0), 0, max_hp())


func heal(amount: int) -> void:
	current_hp = clampi(current_hp + maxi(amount, 0), 0, max_hp())


## Personal growth rates if the definition has them, otherwise the class's.
## Returns a copy: the originals are shared by every unit with that definition or class.
func growths() -> Stats:
	if data == null:
		return Stats.new()
	var source := data.growths
	if source == null and data.class_data != null:
		source = data.class_data.growths
	return source.copy() if source != null else Stats.new()


## The first weapon in the inventory this unit's class can use, or null.
func equipped_weapon() -> WeaponData:
	var index := inventory.first_usable_weapon_index(class_data())
	return null if index < 0 else inventory.get_item(index).data as WeaponData


## Moves the weapon at `index` to the front so it becomes equipped.
## Returns false, changing nothing, for a consumable or a weapon the class can't use.
func equip(index: int) -> bool:
	var entry := inventory.get_item(index)
	if entry == null or not entry.is_weapon() or not class_data().can_wield(entry.data as WeaponData):
		return false
	inventory.move_to_front(index)
	return true


## Uses the consumable at `index`. Returns false, changing nothing, for a weapon,
## an empty slot, or a healing item while HP is full.
func use_item(index: int) -> bool:
	var entry := inventory.get_item(index)
	if entry == null or not entry.is_consumable():
		return false
	var item := entry.data as ConsumableData
	if item.heal_amount != 0 and current_hp >= max_hp():
		return false
	if item.heal_amount == ConsumableData.FULL_HEAL:
		heal(max_hp())
	else:
		heal(item.heal_amount)
	entry.uses_left -= 1
	if entry.uses_left <= 0:
		inventory.remove_at(index)
	return true


## What changes about this unit during play, as JSON-safe data: level, EXP, stats,
## current HP, and items by id (with uses left for consumables). Who the unit is
## isn't saved: the map's placement supplies that when the level loads.
func save_state() -> Dictionary:
	return {
		"level": level,
		"experience": experience,
		"stats": stats.to_dict(),
		"current_hp": current_hp,
		"inventory": inventory.to_array(),
	}


## Restores what save_state() wrote. Tolerant of hand-edited or corrupted saves:
## missing and wrong-type fields fall back (with a "Save data:" warning) to this
## unit's fresh values, and out-of-range numbers are clamped silently. Loaded stats
## follow the creation rules: movement from the class, clamped to the class caps,
## HP at least 1. Anything but a Dictionary leaves the unit as it was.
func apply_saved_state(d: Variant) -> void:
	if not d is Dictionary:
		push_warning("Save data: unit state isn't a dictionary; keeping the fresh unit.")
		return
	level = clampi(SaveUtil.read_int(d, "level", level), UnitData.MIN_LEVEL, UnitData.MAX_LEVEL)
	experience = clampi(SaveUtil.read_int(d, "experience", 0), 0, MAX_EXPERIENCE)

	var klass := class_data()
	var loaded := Stats.from_dict(d.get("stats"), stats)
	loaded.movement = klass.base_stats.movement
	stats = loaded.clamped(klass.caps)
	stats.hp = maxi(stats.hp, 1)

	current_hp = clampi(SaveUtil.read_int(d, "current_hp", max_hp()), 0, max_hp())
	inventory = Inventory.from_array(d.get("inventory"))


## Starting stats for a new unit: the definition's totals, or the class bases for
## generic units. Movement always comes from the class. Clamped to the class caps.
static func _starting_stats(unit_data: UnitData) -> Stats:
	var klass := unit_data.class_data
	var source := unit_data.starting_stats if unit_data.starting_stats != null else klass.base_stats
	var result := source.copy()
	result.movement = klass.base_stats.movement
	return result.clamped(klass.caps)
