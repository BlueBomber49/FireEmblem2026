extends "res://tests/save_data_test.gd"

const KNIGHT_PATH := "res://data/units/classes/knight.tres"
const LANCE_PATH := "res://data/items/weapons/iron_lance.tres"


func _knight_uid() -> String:
	return ResourceUID.id_to_text(ResourceLoader.get_resource_uid(KNIGHT_PATH))


# --- to_dict ----------------------------------------------------------------

func test_to_dict_records_uid_and_path() -> void:
	var ref := ResourceRef.to_dict(load(KNIGHT_PATH))
	assert_eq(ref.get("path"), KNIGHT_PATH)
	assert_eq(ref.get("uid"), _knight_uid())
	assert_true(String(ref.get("uid")).begins_with("uid://"))


func test_to_dict_refuses_resource_created_in_code() -> void:
	var ref := ResourceRef.to_dict(WeaponData.new())
	assert_eq(ref, {})
	assert_push_error(1)


func test_to_dict_refuses_embedded_resource() -> void:
	var w := WeaponData.new()
	w.resource_path = "res://tests/not_a_real_unit.tres::WeaponData_1"
	assert_eq(ResourceRef.to_dict(w), {})
	assert_push_error(1)


func test_to_dict_refuses_null() -> void:
	assert_eq(ResourceRef.to_dict(null), {})
	assert_push_error(1)


# --- load_from --------------------------------------------------------------

func test_load_by_uid_only() -> void:
	assert_eq(ResourceRef.load_from({"uid": _knight_uid()}, ClassData), load(KNIGHT_PATH))
	assert_no_save_warnings()


func test_load_by_path_only() -> void:
	assert_eq(ResourceRef.load_from({"path": KNIGHT_PATH}, ClassData), load(KNIGHT_PATH))
	assert_no_save_warnings()


func test_load_with_both() -> void:
	assert_eq(ResourceRef.load_from({"uid": _knight_uid(), "path": KNIGHT_PATH}, ClassData), load(KNIGHT_PATH))
	assert_no_save_warnings()


func test_unknown_uid_falls_back_to_path() -> void:
	assert_eq(ResourceRef.load_from({"uid": "uid://aaaaaaaaaaaa", "path": KNIGHT_PATH}, ClassData), load(KNIGHT_PATH))
	assert_no_save_warnings()


func test_malformed_uid_falls_back_to_path() -> void:
	assert_eq(ResourceRef.load_from({"uid": "not a uid", "path": KNIGHT_PATH}, ClassData), load(KNIGHT_PATH))
	assert_no_save_warnings()


func test_missing_file_returns_null() -> void:
	assert_null(ResourceRef.load_from({"path": "res://data/nope.tres"}, ClassData))
	assert_save_warning()


func test_neither_returns_null() -> void:
	assert_null(ResourceRef.load_from({}, ClassData))
	assert_save_warning()


func test_user_path_is_rejected() -> void:
	assert_null(ResourceRef.load_from({"path": "user://smoke.tres"}, Stats))
	assert_save_warning()


func test_absolute_path_is_rejected() -> void:
	assert_null(ResourceRef.load_from({"path": "C:/Windows/evil.tres"}, ClassData))
	assert_save_warning()


func test_embedded_path_is_rejected() -> void:
	assert_null(ResourceRef.load_from({"path": KNIGHT_PATH + "::Resource_1"}, Stats))
	assert_save_warning()


func test_wrong_type_returns_null() -> void:
	assert_null(ResourceRef.load_from({"path": KNIGHT_PATH}, ItemData))
	assert_save_warning()
	assert_null(ResourceRef.load_from({"uid": _knight_uid()}, ItemData))
	assert_save_warning()


func test_subclass_counts_as_expected_type() -> void:
	assert_eq(ResourceRef.load_from({"path": LANCE_PATH}, ItemData), load(LANCE_PATH))
	assert_no_save_warnings()


func test_wrong_type_fields_return_null() -> void:
	for bad in [null, "res://x.tres", 5, [KNIGHT_PATH], {"uid": 5, "path": []}]:
		assert_null(ResourceRef.load_from(bad, ClassData), "value %s" % [bad])
		assert_save_warning()
