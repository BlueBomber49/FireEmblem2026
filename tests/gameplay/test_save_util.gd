extends "res://tests/save_data_test.gd"


func test_read_int_accepts_ints() -> void:
	assert_eq(SaveUtil.read_int({"a": 7}, "a", 0), 7)
	assert_no_save_warnings()


func test_read_int_accepts_floats_from_json() -> void:
	assert_eq(SaveUtil.read_int({"a": 7.0}, "a", 0), 7)
	assert_eq(SaveUtil.read_int(JSON.parse_string('{"a": 12}'), "a", 0), 12)


func test_read_int_falls_back_on_wrong_types() -> void:
	for bad in [null, "7", [7], {"x": 7}, true]:
		assert_eq(SaveUtil.read_int({"a": bad}, "a", -5), -5, "value %s" % [bad])
		assert_save_warning("value %s" % [bad])


func test_read_int_falls_back_on_missing_key() -> void:
	assert_eq(SaveUtil.read_int({}, "a", 3), 3)
	assert_save_warning()


func test_read_dict_returns_dict_or_empty() -> void:
	assert_eq(SaveUtil.read_dict({"a": {"x": 1}}, "a"), {"x": 1})
	assert_no_save_warnings()
	assert_eq(SaveUtil.read_dict({"a": [1, 2]}, "a"), {})
	assert_eq(SaveUtil.read_dict({}, "a"), {})
	assert_save_warning()


func test_read_array_returns_array_or_empty() -> void:
	assert_eq(SaveUtil.read_array({"a": [1, 2]}, "a"), [1, 2])
	assert_no_save_warnings()
	assert_eq(SaveUtil.read_array({"a": {"x": 1}}, "a"), [])
	assert_eq(SaveUtil.read_array({"a": null}, "a"), [])
	assert_save_warning()
