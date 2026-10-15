class_name Unit
extends RefCounted
## A unit during play: its current level, stats, HP and items.
##
## Built from a UnitData definition. Board state (position, team, turn flags)
## lives with whoever owns the board, not here.

const MAX_EXPERIENCE := 99
## Bump when the save format changes, and handle older versions in from_dict.
const SAVE_VERSION := 1

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


## This unit's state as JSON-safe save data. Definitions (the UnitData and items)
## are saved as references, and stats as copies. Returns {} (with an error already
## reported) if anything can't be referenced, rather than a save that would lose
## the unit or an item when loaded.
func to_dict() -> Dictionary:
	var unit_ref := ResourceRef.to_dict(data)
	if unit_ref.is_empty():
		return {}
	var items: Variant = inventory.to_array()
	if items == null:
		return {}
	return {
		"version": SAVE_VERSION,
		"unit_data": unit_ref,
		"level": level,
		"experience": experience,
		"stats": stats.to_dict(),
		"current_hp": current_hp,
		"inventory": items,
	}


## A unit rebuilt from save data. Missing and wrong-type fields fall back with a
## warning. Out-of-range numbers are clamped without one, since lowering a class
## cap is ordinary tuning, not a broken save. Returns null (with an error) only when
## there's no definition to build from: `d` isn't a Dictionary, or its unit_data
## reference doesn't load as a UnitData. Loaded stats follow the creation rules:
## movement from the class, clamped to the class caps, HP at least 1.
static func from_dict(d: Variant) -> Unit:
	if not d is Dictionary:
		push_error("Can't load unit: save data isn't a dictionary.")
		return null
	var version := SaveUtil.read_int(d, "version", SAVE_VERSION)
	if version != SAVE_VERSION:
		push_warning("Save data: unknown unit save version %d; reading as version %d." % [version, SAVE_VERSION])
	var unit_data := ResourceRef.load_from(d.get("unit_data"), UnitData) as UnitData
	if unit_data == null:
		push_error("Can't load unit: its unit_data reference doesn't load as a UnitData.")
		return null
	var problem := build_problem(unit_data)
	if not problem.is_empty():
		push_error("Can't load unit: %s" % problem)
		return null

	var unit := Unit.new(unit_data)
	unit.level = clampi(SaveUtil.read_int(d, "level", unit_data.level), UnitData.MIN_LEVEL, UnitData.MAX_LEVEL)
	unit.experience = clampi(SaveUtil.read_int(d, "experience", 0), 0, MAX_EXPERIENCE)

	var klass := unit_data.class_data
	var loaded := Stats.from_dict(d.get("stats"), unit.stats)
	loaded.movement = klass.base_stats.movement
	unit.stats = loaded.clamped(klass.caps)
	unit.stats.hp = maxi(unit.stats.hp, 1)

	unit.current_hp = clampi(SaveUtil.read_int(d, "current_hp", unit.max_hp()), 0, unit.max_hp())
	unit.inventory = Inventory.from_array(d.get("inventory"))
	return unit


## Starting stats for a new unit: the definition's totals, or the class bases for
## generic units. Movement always comes from the class. Clamped to the class caps.
static func _starting_stats(unit_data: UnitData) -> Stats:
	var klass := unit_data.class_data
	var source := unit_data.starting_stats if unit_data.starting_stats != null else klass.base_stats
	var result := source.copy()
	result.movement = klass.base_stats.movement
	return result.clamped(klass.caps)
