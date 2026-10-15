class_name WeaponData
extends ItemData
## A weapon. Combat stats only; uses and rank requirements aren't modeled yet.

@export var weapon_type: Enums.WeaponType = Enums.WeaponType.SWORD
@export var might := 0
@export var hit := 0
@export var crit := 0
@export var weight := 0
## Closest distance (in tiles) the weapon can attack at.
@export var min_range := 1
## Farthest distance (in tiles) the weapon can attack at.
@export var max_range := 1
## Class tags this weapon deals effective damage against, such as &"flier".
@export var effective_against: Array[StringName] = []


func is_magic() -> bool:
	return Enums.is_magic(weapon_type)


func in_range(distance: int) -> bool:
	return distance >= min_range and distance <= max_range


## True when any of `tags` (a class's tags) is one this weapon is effective against.
func is_effective_against(tags: Array[StringName]) -> bool:
	for tag in tags:
		if tag in effective_against:
			return true
	return false


func validate() -> PackedStringArray:
	var errors := super()
	if min_range < 1:
		errors.append("%s: min_range must be at least 1." % id)
	if min_range > max_range:
		errors.append("%s: min_range is greater than max_range." % id)
	for field in [&"might", &"hit", &"crit", &"weight"]:
		if int(get(field)) < 0:
			errors.append("%s: %s can't be negative." % [id, field])
	return errors
