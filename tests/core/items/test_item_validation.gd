extends GutTest


func _valid_weapon() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"iron_sword"
	w.weapon_type = Enums.WeaponType.SWORD
	w.might = 5
	w.hit = 90
	w.weight = 5
	w.min_range = 1
	w.max_range = 1
	return w


func _valid_consumable() -> ConsumableData:
	var c := ConsumableData.new()
	c.id = &"vulnerary"
	c.max_uses = 3
	c.heal_amount = 10
	return c


func test_valid_weapon_passes() -> void:
	assert_eq(_valid_weapon().validate(), PackedStringArray())


func test_item_without_id_fails() -> void:
	var w := _valid_weapon()
	w.id = &""
	assert_gt(w.validate().size(), 0)


func test_weapon_min_range_above_max_fails() -> void:
	var w := _valid_weapon()
	w.min_range = 2
	w.max_range = 1
	assert_gt(w.validate().size(), 0)


func test_weapon_zero_min_range_fails() -> void:
	var w := _valid_weapon()
	w.min_range = 0
	assert_gt(w.validate().size(), 0)


func test_weapon_negative_stats_fail() -> void:
	for field in [&"might", &"hit", &"crit", &"weight"]:
		var w := _valid_weapon()
		w.set(field, -1)
		assert_gt(w.validate().size(), 0, "negative %s" % field)


func test_valid_consumable_passes() -> void:
	assert_eq(_valid_consumable().validate(), PackedStringArray())


func test_full_heal_consumable_passes() -> void:
	var c := _valid_consumable()
	c.heal_amount = ConsumableData.FULL_HEAL
	assert_eq(c.validate(), PackedStringArray())


func test_consumable_with_no_uses_fails() -> void:
	var c := _valid_consumable()
	c.max_uses = 0
	assert_gt(c.validate().size(), 0)


func test_consumable_with_zero_heal_fails() -> void:
	var c := _valid_consumable()
	c.heal_amount = 0
	assert_gt(c.validate().size(), 0)
