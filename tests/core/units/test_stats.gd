extends GutTest


func _make(values: Array[int]) -> Stats:
	var s := Stats.new()
	for i in Stats.FIELDS.size():
		s.set(Stats.FIELDS[i], values[i])
	return s


func test_fields_lists_all_ten_stats_in_order() -> void:
	assert_eq(Stats.FIELDS, [
		&"hp", &"strength", &"magic", &"skill", &"speed",
		&"luck", &"defense", &"resistance", &"constitution", &"movement",
	])


func test_new_stats_are_all_zero() -> void:
	var s := Stats.new()
	for field in Stats.FIELDS:
		assert_eq(s.get(field), 0, "field %s" % field)


func test_plus_adds_each_field() -> void:
	var a := _make([10, 1, 2, 3, 4, 5, 6, 7, 8, 5])
	var b := _make([1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
	var sum := a.plus(b)
	assert_eq(sum.hp, 11)
	assert_eq(sum.strength, 2)
	assert_eq(sum.constitution, 9)
	assert_eq(sum.movement, 6)


func test_plus_returns_a_new_object_and_leaves_inputs_unchanged() -> void:
	var a := _make([10, 1, 2, 3, 4, 5, 6, 7, 8, 5])
	var b := _make([1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
	var sum := a.plus(b)
	assert_ne(sum, a)
	assert_ne(sum, b)
	assert_eq(a.hp, 10)
	assert_eq(b.hp, 1)


func test_plus_null_returns_a_copy() -> void:
	var a := _make([10, 1, 2, 3, 4, 5, 6, 7, 8, 5])
	var result := a.plus(null)
	assert_ne(result, a)
	assert_true(result.equals(a))


func test_clamped_limits_each_field_to_the_cap() -> void:
	var s := _make([70, 25, 0, 3, 4, 5, 6, 7, 8, 5])
	var caps := _make([60, 20, 20, 20, 20, 30, 20, 20, 20, 15])
	var result := s.clamped(caps)
	assert_eq(result.hp, 60)
	assert_eq(result.strength, 20)
	assert_eq(result.skill, 3)


func test_clamped_raises_negative_values_to_zero() -> void:
	var s := _make([10, -3, 0, 0, 0, 0, -1, 0, 0, 5])
	var caps := _make([60, 20, 20, 20, 20, 30, 20, 20, 20, 15])
	var result := s.clamped(caps)
	assert_eq(result.strength, 0)
	assert_eq(result.defense, 0)


func test_clamped_returns_a_new_object() -> void:
	var s := _make([70, 25, 0, 3, 4, 5, 6, 7, 8, 5])
	var caps := _make([60, 20, 20, 20, 20, 30, 20, 20, 20, 15])
	var result := s.clamped(caps)
	assert_ne(result, s)
	assert_eq(s.hp, 70)


func test_clamped_with_null_caps_only_floors_at_zero() -> void:
	var s := _make([70, -2, 0, 3, 4, 5, 6, 7, 8, 5])
	var result := s.clamped(null)
	assert_eq(result.hp, 70)
	assert_eq(result.strength, 0)


func test_copy_is_independent() -> void:
	var s := _make([10, 1, 2, 3, 4, 5, 6, 7, 8, 5])
	var c := s.copy()
	c.hp = 99
	assert_eq(s.hp, 10)
	assert_true(_make([10, 1, 2, 3, 4, 5, 6, 7, 8, 5]).equals(s))


func test_equals_compares_every_field() -> void:
	var a := _make([10, 1, 2, 3, 4, 5, 6, 7, 8, 5])
	var b := _make([10, 1, 2, 3, 4, 5, 6, 7, 8, 5])
	assert_true(a.equals(b))
	b.movement = 6
	assert_false(a.equals(b))
	assert_false(a.equals(null))
