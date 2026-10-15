extends GutTest

const ClassDataTest := preload("res://tests/core/units/test_class_data.gd")


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


var _next_fake_path := 0


## An item that looks saved as its own file. Each gets a unique path that no real file
## uses, because Godot allows only one resource per path.
func _file_item() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"iron_lance"
	_next_fake_path += 1
	w.resource_path = "res://tests/not_a_real_file_%d.tres" % _next_fake_path
	return w


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
		u.starting_items.append(_file_item())
	assert_gt(u.validate().size(), 0)


func test_starting_items_at_capacity_pass() -> void:
	var u := _valid_unit()
	for i in Inventory.DEFAULT_CAPACITY:
		u.starting_items.append(_file_item())
	assert_eq(u.validate(), PackedStringArray())


func test_starting_item_created_in_code_fails() -> void:
	var u := _valid_unit()
	var w := WeaponData.new()
	w.id = &"loose"
	u.starting_items.append(w)
	assert_gt(u.validate().size(), 0)


func test_starting_item_embedded_in_another_file_fails() -> void:
	var u := _valid_unit()
	var w := WeaponData.new()
	w.id = &"embedded"
	w.resource_path = "res://data/units/oswin.tres::WeaponData_abc"
	u.starting_items.append(w)
	assert_gt(u.validate().size(), 0)


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
