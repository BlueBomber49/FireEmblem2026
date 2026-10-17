class_name ClassData
extends Resource
## A unit class, such as Myrmidon or Knight.

@export var id: StringName
@export var display_name := ""
## Decides which terrain movement costs the class pays.
@export var movement_type: Enums.MovementType = Enums.MovementType.FOOT
## Starting stats for generic units of this class.
@export var base_stats: Stats
## Level-up chance per stat, in percent. Used by units without personal growths.
@export var growths: Stats
## Highest value each stat can reach.
@export var caps: Stats
@export var usable_weapon_types: Array[Enums.WeaponType] = []
## Added to critical rate (FE7: +15 for Swordmaster and Berserker).
@export var crit_bonus := 0
## Used by the FE7 EXP formulas (2 for Soldier and Thief, 3 for most classes).
@export var class_power := 3
@export var promoted := false
## Traits weapons can be effective against, such as &"flier", &"mounted" or &"armored".
@export var tags: Array[StringName] = []


func can_wield(weapon: WeaponData) -> bool:
	return weapon != null and weapon.weapon_type in usable_weapon_types


func has_tag(tag: StringName) -> bool:
	return tag in tags


## Returns a list of problems with this class; empty when it's valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Class has no id.")
	for field in [&"base_stats", &"growths", &"caps"]:
		if get(field) == null:
			errors.append("%s: %s is missing." % [id, field])
	if base_stats != null and caps != null:
		for field in Stats.FIELDS:
			if int(base_stats.get(field)) > int(caps.get(field)):
				errors.append("%s: base %s is above its cap." % [id, field])
	if base_stats != null and base_stats.movement <= 0:
		errors.append("%s: base movement must be at least 1." % id)
	if usable_weapon_types.is_empty():
		errors.append("%s: no usable weapon types." % id)
	return errors
