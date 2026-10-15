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


func test_enum_values_stay_in_saved_order() -> void:
	# .tres files store these as ints. Only ever append new values.
	assert_eq(Enums.WeaponType.SWORD, 0)
	assert_eq(Enums.WeaponType.STAFF, 7)
	assert_eq(Enums.MovementType.FOOT, 0)
	assert_eq(Enums.MovementType.MAGE, 4)
