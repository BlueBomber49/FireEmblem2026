class_name Enums
## Enums shared by rules code and data.
##
## .tres files store enum values as ints, so only ever append new values.
## Reordering or inserting would silently change saved data.

enum WeaponType { SWORD, LANCE, AXE, BOW, ANIMA, LIGHT, DARK, STAFF }

## Units in the same group pay the same terrain movement costs.
enum MovementType { FOOT, ARMORED, MOUNTED, FLIER, MAGE }


## True for weapons whose attacks target Resistance instead of Defense.
## Staves aren't magic here: they don't attack, and staff accuracy has its own formula.
static func is_magic(weapon_type: WeaponType) -> bool:
	return weapon_type in [WeaponType.ANIMA, WeaponType.LIGHT, WeaponType.DARK]
