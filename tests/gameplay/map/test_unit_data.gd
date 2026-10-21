extends GutTest

const ClassDataTest := preload("res://tests/gameplay/map/test_class_data.gd")


func _class() -> ClassData:
	var c := ClassData.new()
	c.id = &"knight"
	c.base_stats = ClassDataTest.stats([17, 5, 0, 2, 0, 0, 9, 0, 13, 4])
	c.growths = ClassDataTest.stats([80, 40, 0, 30, 15, 25, 28, 20, 0, 0])
	c.caps = ClassDataTest.stats([60, 20, 20, 20, 20, 30, 20, 20, 20, 15])
	c.usable_weapon_types = [Enums.WeaponType.LANCE]
	return c


func _valid_unit() -> UnitData:
	var u := UnitData.new()
	u.id = &"oswin"
	u.display_name = "Oswin"
	u.class_data = _class()
	u.level = 9
	return u


## A real item from resources/weapons, so its id is known to GameData.
func _known_item() -> ItemData:
	return GameData.get_item(&"iron_lance")


func test_valid_unit_passes() -> void:
	assert_eq(_valid_unit().validate(), PackedStringArray())


func test_defaults() -> void:
	var u := UnitData.new()
	assert_eq(u.level, 1)
	assert_null(u.starting_stats)
	assert_null(u.growths)


func test_missing_id_fails() -> void:
	var u := _valid_unit()
	u.id = &""
	assert_gt(u.validate().size(), 0)


func test_missing_class_fails() -> void:
	var u := _valid_unit()
	u.class_data = null
	assert_gt(u.validate().size(), 0)


func test_level_out_of_range_fails() -> void:
	for level in [0, 21]:
		var u := _valid_unit()
		u.level = level
		assert_gt(u.validate().size(), 0, "level %d" % level)


func test_too_many_starting_items_fails() -> void:
	var u := _valid_unit()
	for i in Inventory.DEFAULT_CAPACITY + 1:
		u.starting_items.append(_known_item())
	assert_gt(u.validate().size(), 0)


func test_starting_items_at_capacity_pass() -> void:
	var u := _valid_unit()
	for i in Inventory.DEFAULT_CAPACITY:
		u.starting_items.append(_known_item())
	assert_eq(u.validate(), PackedStringArray())


func test_starting_item_with_a_known_id_passes() -> void:
	var u := _valid_unit()
	u.starting_items.append(_known_item())
	assert_eq(u.validate(), PackedStringArray())


func test_starting_item_with_an_unknown_id_fails() -> void:
	# Saves store items by id, so an item GameData doesn't know couldn't be loaded back.
	var u := _valid_unit()
	var w := WeaponData.new()
	w.id = &"spoon"
	u.starting_items.append(w)
	assert_gt(u.validate().size(), 0)
	assert_string_contains("
".join(u.validate()), "spoon")


func test_null_starting_item_fails() -> void:
	var u := _valid_unit()
	u.starting_items.append(null)
	assert_gt(u.validate().size(), 0)


func test_starting_stats_totals_pass_even_when_large() -> void:
	# Oswin joins at level 9 with 28 HP: 11 more than the Knight base.
	var u := _valid_unit()
	u.starting_stats = ClassDataTest.stats([28, 13, 0, 9, 5, 3, 13, 3, 14, 0])
	assert_eq(u.validate(), PackedStringArray())


func test_starting_stats_with_zero_hp_fails() -> void:
	var u := _valid_unit()
	u.starting_stats = ClassDataTest.stats([0, 13, 0, 9, 5, 3, 13, 3, 14, 0])
	assert_gt(u.validate().size(), 0)


func test_starting_stats_with_zero_constitution_fails() -> void:
	var u := _valid_unit()
	u.starting_stats = ClassDataTest.stats([28, 13, 0, 9, 5, 3, 13, 3, 0, 0])
	assert_gt(u.validate().size(), 0)
