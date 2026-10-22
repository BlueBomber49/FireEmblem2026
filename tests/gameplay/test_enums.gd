extends GutTest


func test_anima_light_and_dark_are_magic() -> void:
	assert_true(Enums.is_magic(Enums.WeaponType.ANIMA))
	assert_true(Enums.is_magic(Enums.WeaponType.LIGHT))
	assert_true(Enums.is_magic(Enums.WeaponType.DARK))


func test_physical_types_are_not_magic() -> void:
	for type in [Enums.WeaponType.SWORD, Enums.WeaponType.LANCE, Enums.WeaponType.AXE, Enums.WeaponType.BOW]:
		assert_false(Enums.is_magic(type), "type %d" % type)


func test_staff_is_not_magic() -> void:
	# Staves don't attack, so they never target Resistance.
	assert_false(Enums.is_magic(Enums.WeaponType.STAFF))


func test_enum_values_stay_in_order() -> void:
	# Data files store enum *names* ("sword"), so reordering wouldn't break them, but
	# code and saves may still hold the ints. Only ever append new values.
	assert_eq(Enums.WeaponType.SWORD, 0)
	assert_eq(Enums.WeaponType.STAFF, 7)
	assert_eq(Enums.MovementType.FOOT, 0)
	assert_eq(Enums.MovementType.MAGE, 4)


func test_weapon_type_names_round_trip() -> void:
	assert_eq(Enums.weapon_type_name(Enums.WeaponType.SWORD), "sword")
	assert_eq(Enums.weapon_type_name(Enums.WeaponType.ANIMA), "anima")
	for type in Enums.WeaponType.values():
		assert_eq(Enums.weapon_type_from_name(Enums.weapon_type_name(type)), type)


func test_movement_type_names_round_trip() -> void:
	assert_eq(Enums.movement_type_name(Enums.MovementType.ARMORED), "armored")
	for type in Enums.MovementType.values():
		assert_eq(Enums.movement_type_from_name(Enums.movement_type_name(type)), type)


func test_unknown_names_are_minus_one() -> void:
	assert_eq(Enums.weapon_type_from_name("spoon"), -1)
	assert_eq(Enums.weapon_type_from_name("Sword"), -1, "names are lowercase")
	assert_eq(Enums.movement_type_from_name(""), -1)
