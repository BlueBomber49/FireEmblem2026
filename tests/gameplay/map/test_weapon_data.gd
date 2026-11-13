extends GutTest


func _weapon(type: Enums.WeaponType, min_range: int, max_range: int) -> WeaponData:
	var w := WeaponData.new()
	w.id = &"test_weapon"
	w.weapon_type = type
	w.min_range = min_range
	w.max_range = max_range
	return w


func test_javelin_reaches_one_and_two() -> void:
	var javelin := _weapon(Enums.WeaponType.LANCE, 1, 2)
	assert_false(javelin.in_range(0))
	assert_true(javelin.in_range(1))
	assert_true(javelin.in_range(2))
	assert_false(javelin.in_range(3))


func test_bow_only_reaches_two() -> void:
	var bow := _weapon(Enums.WeaponType.BOW, 2, 2)
	assert_false(bow.in_range(1))
	assert_true(bow.in_range(2))
	assert_false(bow.in_range(3))


func test_is_magic_follows_weapon_type() -> void:
	assert_true(_weapon(Enums.WeaponType.ANIMA, 1, 2).is_magic())
	assert_false(_weapon(Enums.WeaponType.SWORD, 1, 1).is_magic())


func test_is_effective_against_matches_tags() -> void:
	var bow := _weapon(Enums.WeaponType.BOW, 2, 2)
	bow.effective_against = [&"flier"]
	assert_true(bow.is_effective_against([&"flier"]))
	assert_true(bow.is_effective_against([&"mounted", &"flier"]))
	assert_false(bow.is_effective_against([&"mounted"]))
	assert_false(bow.is_effective_against([]))
