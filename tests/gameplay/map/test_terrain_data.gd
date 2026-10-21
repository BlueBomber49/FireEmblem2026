extends GutTest


func _forest() -> TerrainData:
	var t := TerrainData.new()
	t.id = &"forest"
	t.display_name = "Forest"
	t.defense = 1
	t.avoid = 20
	t.move_costs = {
		Enums.MovementType.FOOT: 2, Enums.MovementType.ARMORED: 2, Enums.MovementType.MOUNTED: 3,
		Enums.MovementType.FLIER: 1, Enums.MovementType.MAGE: 2,
	}
	t.tiles = PackedStringArray(["trees"])
	return t


func test_move_cost_per_group() -> void:
	var forest := _forest()
	assert_eq(forest.move_cost(Enums.MovementType.FOOT), 2)
	assert_eq(forest.move_cost(Enums.MovementType.MOUNTED), 3)
	assert_eq(forest.move_cost(Enums.MovementType.FLIER), 1)


func test_impassable_is_minus_one() -> void:
	var sea := _forest()
	sea.move_costs[Enums.MovementType.FOOT] = TerrainData.IMPASSABLE
	assert_eq(sea.move_cost(Enums.MovementType.FOOT), -1)
	assert_false(sea.is_passable(Enums.MovementType.FOOT))
	assert_true(sea.is_passable(Enums.MovementType.FLIER))


func test_valid_terrain_passes() -> void:
	assert_eq(_forest().validate(), PackedStringArray())


func test_missing_id_fails() -> void:
	var t := _forest()
	t.id = &""
	assert_gt(t.validate().size(), 0)


func test_missing_group_cost_fails() -> void:
	var t := _forest()
	t.move_costs.erase(Enums.MovementType.MAGE)
	assert_gt(t.validate().size(), 0)


func test_zero_or_below_minus_one_cost_fails() -> void:
	for bad in [0, -2]:
		var t := _forest()
		t.move_costs[Enums.MovementType.FOOT] = bad
		assert_gt(t.validate().size(), 0, "cost %d" % bad)


func test_negative_bonuses_fail() -> void:
	for field in [&"defense", &"avoid", &"heal_percent"]:
		var t := _forest()
		t.set(field, -1)
		assert_gt(t.validate().size(), 0, "negative %s" % field)
