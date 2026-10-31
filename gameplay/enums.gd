class_name Enums
## Enums shared by rules code and data.
##
## Data files store these by lowercase name ("sword", "armored"), so names must
## stay stable. Code and saves may still hold the int values, so only ever
## append new values.

enum WeaponType { SWORD, LANCE, AXE, BOW, ANIMA, LIGHT, DARK, STAFF, KNIFE }

## Units in the same group pay the same terrain movement costs.
enum MovementType { FOOT, ARMORED, MOUNTED, FLIER, MAGE }


## True for weapons whose attacks target Resistance instead of Defense.
## Staves aren't magic here: they don't attack, and staff accuracy has its own formula.
static func is_magic(weapon_type: WeaponType) -> bool:
	return weapon_type in [WeaponType.ANIMA, WeaponType.LIGHT, WeaponType.DARK]


## The name data files use for `type`, e.g. SWORD -> "sword".
static func weapon_type_name(type: WeaponType) -> String:
	return String(WeaponType.find_key(type)).to_lower()


## The WeaponType for a data-file name, or -1 when it isn't one.
static func weapon_type_from_name(type_name: String) -> int:
	return _value_for(WeaponType, type_name)


static func movement_type_name(type: MovementType) -> String:
	return String(MovementType.find_key(type)).to_lower()


## The MovementType for a data-file name, or -1 when it isn't one.
static func movement_type_from_name(type_name: String) -> int:
	return _value_for(MovementType, type_name)


static func _value_for(enum_dict: Dictionary, type_name: String) -> int:
	# Names are lowercase in data; "Sword" or "SWORD" isn't accepted, so typos stand out.
	if type_name != type_name.to_lower():
		return -1
	return enum_dict.get(type_name.to_upper(), -1)
