extends "res://tests/save_data_test.gd"
## Saving and loading units. Uses res://tests/fixtures/fixture_knight.tres:
## a level 3 Knight carrying an Iron Lance and a Vulnerary.

const FIXTURE_PATH := "res://tests/fixtures/fixture_knight.tres"
const LANCE_PATH := "res://data/items/weapons/iron_lance.tres"
const VULNERARY_PATH := "res://data/items/consumables/vulnerary.tres"


func _fixture() -> UnitData:
	return load(FIXTURE_PATH)


func _fresh() -> Unit:
	return Unit.new(_fixture())


## Saves through real JSON text, the way a save file would.
func _through_json(d: Dictionary) -> Variant:
	return JSON.parse_string(JSON.stringify(d))


func _saved_fresh() -> Dictionary:
	return _through_json(_fresh().to_dict())


# --- Round trip -------------------------------------------------------------

func test_round_trip_keeps_all_state() -> void:
	var unit := _fresh()
	unit.level = 5
	unit.experience = 42
	unit.stats.strength = 8
	unit.take_damage(12)
	assert_true(unit.use_item(1))  # Vulnerary: heals 10, 2 uses left

	var loaded := Unit.from_dict(_through_json(unit.to_dict()))
	assert_not_null(loaded)
	assert_eq(loaded.data, _fixture())
	assert_eq(loaded.level, 5)
	assert_eq(loaded.experience, 42)
	assert_true(loaded.stats.equals(unit.stats))
	assert_eq(loaded.current_hp, unit.current_hp)
	assert_eq(loaded.inventory.size(), 2)
	assert_eq(loaded.inventory.get_item(0).data, load(LANCE_PATH))
	assert_eq(loaded.inventory.get_item(1).data, load(VULNERARY_PATH))
	assert_eq(loaded.inventory.get_item(1).uses_left, 2)
	assert_eq(loaded.equipped_weapon(), load(LANCE_PATH))
	assert_no_save_warnings()


func test_saved_values_are_json_safe() -> void:
	var d := _fresh().to_dict()
	assert_eq(d.get("version"), 1)
	assert_true(d.get("unit_data") is Dictionary)
	assert_true(d.get("stats") is Dictionary)
	assert_true(d.get("inventory") is Array)
	assert_ne(JSON.stringify(d), "", "serializes to JSON")
	assert_no_save_warnings()


func test_weapons_dont_save_uses() -> void:
	var entries: Array = _fresh().to_dict().get("inventory")
	assert_false((entries[0] as Dictionary).has("uses_left"))
	assert_eq((entries[1] as Dictionary).get("uses_left"), 3)
	assert_no_save_warnings()


func test_loaded_unit_doesnt_share_stats_with_definition() -> void:
	var loaded := Unit.from_dict(_saved_fresh())
	loaded.stats.defense = 19
	assert_eq(_fixture().class_data.base_stats.defense, 9)
	assert_eq(Unit.from_dict(_saved_fresh()).stats.defense, 9)
	assert_no_save_warnings()


func test_empty_inventory_saves_and_loads() -> void:
	var unit := _fresh()
	unit.inventory.remove_at(0)
	unit.inventory.remove_at(0)
	assert_eq(unit.inventory.to_array(), [])
	var d := unit.to_dict()
	assert_ne(d, {})
	assert_eq(Unit.from_dict(_through_json(d)).inventory.size(), 0)
	assert_no_save_warnings()


# --- Saves that can't be written --------------------------------------------


func test_unit_without_a_definition_file_cant_be_saved() -> void:
	var data := UnitData.new()
	data.id = &"made_in_code"
	data.class_data = load("res://data/units/classes/knight.tres")
	assert_eq(Unit.new(data).to_dict(), {})
	assert_push_error(1)
	allow_save_warnings()


func test_unit_whose_only_item_has_no_file_cant_be_saved() -> void:
	var unit := _fresh()
	unit.inventory.remove_at(0)
	unit.inventory.remove_at(0)
	var loose := WeaponData.new()
	loose.id = &"loose"
	unit.inventory.add(loose)
	assert_eq(unit.to_dict(), {})
	assert_push_error(1)
	allow_save_warnings()


func test_inventory_to_array_is_null_when_an_item_has_no_file() -> void:
	var inv := Inventory.new()
	inv.add(load(LANCE_PATH))
	inv.add(WeaponData.new())
	assert_null(inv.to_array())
	assert_push_error(1)
	allow_save_warnings()


# --- Tolerance: missing or out of range --------------------------------------


func test_missing_stats_block_uses_definition() -> void:
	var d := _saved_fresh()
	d.erase("stats")
	assert_true(Unit.from_dict(d).stats.equals(_fresh().stats))
	assert_save_warning()


func test_missing_single_stat_uses_definition() -> void:
	var d := _saved_fresh()
	d["stats"]["strength"] = 8
	(d["stats"] as Dictionary).erase("skill")
	var loaded := Unit.from_dict(d)
	assert_eq(loaded.stats.strength, 8)
	assert_eq(loaded.stats.skill, 2)
	assert_save_warning()


func test_unknown_keys_are_ignored() -> void:
	var d := _saved_fresh()
	d["favorite_color"] = "blue"
	d["stats"]["charisma"] = 99
	assert_not_null(Unit.from_dict(d))
	assert_no_save_warnings()


func test_current_hp_is_clamped_and_defaults_to_full() -> void:
	var d := _saved_fresh()
	d["current_hp"] = 999
	assert_eq(Unit.from_dict(d).current_hp, 17)
	d["current_hp"] = -4
	assert_eq(Unit.from_dict(d).current_hp, 0)
	d.erase("current_hp")
	assert_eq(Unit.from_dict(d).current_hp, 17)
	assert_save_warning()


func test_level_and_experience_are_clamped() -> void:
	var d := _saved_fresh()
	d["level"] = 50
	d["experience"] = 500
	var loaded := Unit.from_dict(d)
	assert_eq(loaded.level, 20)
	assert_eq(loaded.experience, 99)
	d["level"] = 0
	d["experience"] = -1
	loaded = Unit.from_dict(d)
	assert_eq(loaded.level, 1)
	assert_eq(loaded.experience, 0)
	assert_no_save_warnings("clamping is silent")


func test_stats_are_clamped_to_caps_and_hp_is_at_least_one() -> void:
	var d := _saved_fresh()
	d["stats"]["strength"] = 99
	d["stats"]["defense"] = -3
	d["stats"]["hp"] = 0
	var loaded := Unit.from_dict(d)
	assert_eq(loaded.stats.strength, 20)
	assert_eq(loaded.stats.defense, 0)
	assert_eq(loaded.stats.hp, 1)
	assert_eq(loaded.current_hp, 1, "current_hp clamped to the new max")
	assert_no_save_warnings("clamping is silent")


func test_saved_movement_is_ignored() -> void:
	var d := _saved_fresh()
	d["stats"]["movement"] = 9
	assert_eq(Unit.from_dict(d).stats.movement, 4)
	assert_no_save_warnings("movement always comes from the class")


func test_unloadable_item_is_skipped_and_the_rest_survive() -> void:
	var d := _saved_fresh()
	(d["inventory"] as Array).insert(0, {"item": {"path": "res://data/items/weapons/nope.tres"}})
	var loaded := Unit.from_dict(d)
	assert_eq(loaded.inventory.size(), 2)
	assert_eq(loaded.inventory.get_item(0).data, load(LANCE_PATH))
	assert_save_warning()


func test_wrong_type_item_is_skipped() -> void:
	var d := _saved_fresh()
	(d["inventory"] as Array).append({"item": {"path": "res://data/units/classes/knight.tres"}})
	assert_eq(Unit.from_dict(d).inventory.size(), 2)
	assert_save_warning()


func test_too_many_items_are_cut_to_capacity() -> void:
	var d := _saved_fresh()
	var entries: Array = d["inventory"]
	for i in 5:
		entries.append(entries[0].duplicate(true))
	assert_eq(Unit.from_dict(d).inventory.size(), Inventory.DEFAULT_CAPACITY)
	assert_save_warning()


func test_unknown_version_loads_as_version_one() -> void:
	var d := _saved_fresh()
	d["version"] = 99
	assert_not_null(Unit.from_dict(d))
	assert_save_warning()


# --- Tolerance: wrong types --------------------------------------------------


func test_wrong_type_level_falls_back_to_definition() -> void:
	for bad in ["abc", null, [5]]:
		var d := _saved_fresh()
		d["level"] = bad
		assert_eq(Unit.from_dict(d).level, 3, "level %s" % [bad])
	assert_save_warning()


func test_array_where_stats_belong_uses_definition() -> void:
	var d := _saved_fresh()
	d["stats"] = [1, 2, 3]
	assert_true(Unit.from_dict(d).stats.equals(_fresh().stats))
	assert_save_warning()


func test_wrong_type_single_stat_uses_definition() -> void:
	var d := _saved_fresh()
	d["stats"]["speed"] = "fast"
	assert_eq(Unit.from_dict(d).stats.speed, 0)
	assert_save_warning()


func test_dictionary_where_inventory_belongs_gives_empty_inventory() -> void:
	var d := _saved_fresh()
	d["inventory"] = {"item": "x"}
	assert_eq(Unit.from_dict(d).inventory.size(), 0)
	assert_save_warning()


func test_non_dictionary_inventory_entry_is_skipped() -> void:
	var d := _saved_fresh()
	(d["inventory"] as Array).append(42)
	(d["inventory"] as Array).append("vulnerary")
	assert_eq(Unit.from_dict(d).inventory.size(), 2)
	assert_save_warning()


func test_bad_uses_left_defaults_to_max_uses() -> void:
	for bad in ["x", null, [2]]:
		var d := _saved_fresh()
		d["inventory"][1]["uses_left"] = bad
		assert_eq(Unit.from_dict(d).inventory.get_item(1).uses_left, 3, "uses_left %s" % [bad])
	var missing := _saved_fresh()
	(missing["inventory"][1] as Dictionary).erase("uses_left")
	assert_eq(Unit.from_dict(missing).inventory.get_item(1).uses_left, 3)
	assert_save_warning()


func test_out_of_range_uses_left_is_clamped() -> void:
	var d := _saved_fresh()
	d["inventory"][1]["uses_left"] = 0
	assert_eq(Unit.from_dict(d).inventory.get_item(1).uses_left, 1)
	d["inventory"][1]["uses_left"] = 99
	assert_eq(Unit.from_dict(d).inventory.get_item(1).uses_left, 3)
	assert_no_save_warnings("clamping is silent")


# --- Unrecoverable ----------------------------------------------------------


func test_missing_unit_data_returns_null() -> void:
	var d := _saved_fresh()
	d.erase("unit_data")
	assert_null(Unit.from_dict(d))
	assert_push_error(1)
	allow_save_warnings()


func test_unloadable_unit_data_returns_null() -> void:
	var d := _saved_fresh()
	d["unit_data"] = {"path": "res://tests/fixtures/nope.tres"}
	assert_null(Unit.from_dict(d))
	assert_push_error(1)
	allow_save_warnings()


func test_unit_data_pointing_at_an_item_returns_null() -> void:
	var d := _saved_fresh()
	d["unit_data"] = {"path": LANCE_PATH}
	assert_null(Unit.from_dict(d))
	assert_push_error(1)
	allow_save_warnings()


func test_unit_data_pointing_at_wrong_type_fixture_returns_null() -> void:
	var d := _saved_fresh()
	d["unit_data"] = {"path": "res://tests/fixtures/not_a_unit.tres"}
	assert_null(Unit.from_dict(d))
	assert_push_error(1)
	allow_save_warnings()


func test_unit_data_without_a_class_returns_null() -> void:
	var d := _saved_fresh()
	d["unit_data"] = {"path": "res://tests/fixtures/broken_no_class.tres"}
	assert_null(Unit.from_dict(d))
	assert_push_error("has no class")
	allow_save_warnings()


func test_non_dictionary_top_level_returns_null() -> void:
	assert_null(Unit.from_dict([1, 2]))
	assert_null(Unit.from_dict(null))
	assert_push_error(2)
	allow_save_warnings()

