extends GutTest


static func stats(values: Array) -> Stats:
	var s := Stats.new()
	for i in Stats.FIELDS.size():
		s.set(Stats.FIELDS[i], values[i])
	return s


func _valid_class() -> ClassData:
	var c := ClassData.new()
	c.id = &"myrmidon"
	c.display_name = "Myrmidon"
	c.movement_type = Enums.MovementType.FOOT
	c.base_stats = stats([16, 4, 0, 9, 9, 0, 2, 0, 8, 5])
	c.growths = stats([70, 35, 0, 40, 40, 30, 15, 20, 0, 0])
	c.caps = stats([60, 20, 20, 20, 20, 30, 20, 20, 20, 15])
	c.usable_weapon_types = [Enums.WeaponType.SWORD]
	return c


func _weapon(type: Enums.WeaponType) -> WeaponData:
	var w := WeaponData.new()
	w.id = &"w"
	w.weapon_type = type
	return w


func test_can_wield_allowed_type() -> void:
	assert_true(_valid_class().can_wield(_weapon(Enums.WeaponType.SWORD)))


func test_cannot_wield_other_type() -> void:
	assert_false(_valid_class().can_wield(_weapon(Enums.WeaponType.LANCE)))


func test_cannot_wield_null() -> void:
	assert_false(_valid_class().can_wield(null))


func test_has_tag() -> void:
	var c := _valid_class()
	c.tags = [&"flier"]
	assert_true(c.has_tag(&"flier"))
	assert_false(c.has_tag(&"mounted"))


func test_defaults() -> void:
	var c := ClassData.new()
	assert_eq(c.class_power, 3)
	assert_false(c.promoted)
	assert_eq(c.crit_bonus, 0)


func test_valid_class_passes() -> void:
	assert_eq(_valid_class().validate(), PackedStringArray())


func test_missing_id_fails() -> void:
	var c := _valid_class()
	c.id = &""
	assert_gt(c.validate().size(), 0)


func test_missing_stat_blocks_fail() -> void:
	for field in [&"base_stats", &"growths", &"caps"]:
		var c := _valid_class()
		c.set(field, null)
		assert_gt(c.validate().size(), 0, "missing %s" % field)


func test_cap_below_base_fails() -> void:
	var c := _valid_class()
	c.caps = stats([10, 20, 20, 20, 20, 30, 20, 20, 20, 15])  # HP cap 10 < base 16
	assert_gt(c.validate().size(), 0)


func test_no_usable_weapons_fails() -> void:
	var c := _valid_class()
	c.usable_weapon_types = []
	assert_gt(c.validate().size(), 0)


func test_zero_movement_fails() -> void:
	var c := _valid_class()
	c.base_stats.movement = 0
	assert_gt(c.validate().size(), 0)
