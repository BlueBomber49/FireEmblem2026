extends "res://tests/save_data_test.gd"
## A unit's saved state: what changes during play (level, EXP, stats, HP, items).
## The map supplies who the unit is, so only the state is saved, with items by id.
## Uses Lyn from resources/characters/lyn.json: a Myrmidon with an Iron Sword and a
## Vulnerary (HP 16, Str 5, Skl 7, Spd 9, Lck 2, Def 2, Res 0, Con 5).


func _lyn() -> Unit:
	return Unit.new(GameData.get_character(&"lyn"))


## Saves through real JSON text, the way a save file would.
func _through_json(d: Dictionary) -> Variant:
	return JSON.parse_string(JSON.stringify(d))


func _saved_fresh() -> Dictionary:
	return _through_json(_lyn().save_state())


func _loaded(d: Variant) -> Unit:
	var unit := _lyn()
	unit.apply_saved_state(d)
	return unit


# --- Round trip -------------------------------------------------------------


func test_round_trip_keeps_all_state() -> void:
	var unit := _lyn()
	unit.level = 5
	unit.experience = 42
	unit.stats.strength = 8
	unit.take_damage(12)
	assert_true(unit.use_item(1))  # Vulnerary: heals 10, 2 uses left

	var loaded := _loaded(_through_json(unit.save_state()))
	assert_eq(loaded.level, 5)
	assert_eq(loaded.experience, 42)
	assert_true(loaded.stats.equals(unit.stats))
	assert_eq(loaded.current_hp, unit.current_hp)
	assert_eq(loaded.inventory.size(), 2)
	assert_eq(loaded.inventory.get_item(0).data, GameData.get_item(&"iron_sword"))
	assert_eq(loaded.inventory.get_item(1).data, GameData.get_item(&"vulnerary"))
	assert_eq(loaded.inventory.get_item(1).uses_left, 2)
	assert_eq(loaded.equipped_weapon(), GameData.get_item(&"iron_sword"))
	assert_no_save_warnings()


func test_saved_values_are_json_safe_and_use_item_ids() -> void:
	var d := _lyn().save_state()
	assert_true(d.get("stats") is Dictionary)
	assert_eq(d.get("inventory"), [{"item": "iron_sword"}, {"item": "vulnerary", "uses_left": 3}])
	assert_ne(JSON.stringify(d), "")
	assert_no_save_warnings()


func test_weapons_dont_save_uses() -> void:
	var entries: Array = _lyn().save_state().get("inventory")
	assert_false((entries[0] as Dictionary).has("uses_left"))
	assert_eq((entries[1] as Dictionary).get("uses_left"), 3)


func test_loaded_unit_doesnt_share_stats_with_definition() -> void:
	var loaded := _loaded(_saved_fresh())
	loaded.stats.defense = 19
	assert_eq(GameData.get_character(&"lyn").starting_stats.defense, 2)
	assert_eq(_loaded(_saved_fresh()).stats.defense, 2)


func test_empty_inventory_saves_and_loads() -> void:
	var unit := _lyn()
	unit.inventory.remove_at(0)
	unit.inventory.remove_at(0)
	assert_eq(unit.inventory.to_array(), [])
	assert_eq(_loaded(_through_json(unit.save_state())).inventory.size(), 0)
	assert_no_save_warnings()


# --- Tolerance: missing or out of range ----------------------------------------


func test_missing_stats_block_uses_definition() -> void:
	var d := _saved_fresh()
	d.erase("stats")
	assert_true(_loaded(d).stats.equals(_lyn().stats))
	assert_save_warning()


func test_missing_single_stat_uses_definition() -> void:
	var d := _saved_fresh()
	d["stats"]["strength"] = 8
	(d["stats"] as Dictionary).erase("skill")
	var loaded := _loaded(d)
	assert_eq(loaded.stats.strength, 8)
	assert_eq(loaded.stats.skill, 7)
	assert_save_warning()


func test_unknown_keys_are_ignored() -> void:
	var d := _saved_fresh()
	d["favorite_color"] = "blue"
	d["stats"]["charisma"] = 99
	assert_eq(_loaded(d).stats.hp, 16)
	assert_no_save_warnings()


func test_current_hp_is_clamped_and_defaults_to_full() -> void:
	var d := _saved_fresh()
	d["current_hp"] = 999
	assert_eq(_loaded(d).current_hp, 16)
	d["current_hp"] = -4
	assert_eq(_loaded(d).current_hp, 0)
	d.erase("current_hp")
	assert_eq(_loaded(d).current_hp, 16)
	assert_save_warning()


func test_level_and_experience_are_clamped() -> void:
	var d := _saved_fresh()
	d["level"] = 50
	d["experience"] = 500
	var loaded := _loaded(d)
	assert_eq(loaded.level, 20)
	assert_eq(loaded.experience, 99)
	d["level"] = 0
	d["experience"] = -1
	loaded = _loaded(d)
	assert_eq(loaded.level, 1)
	assert_eq(loaded.experience, 0)
	assert_no_save_warnings("clamping is silent")


func test_stats_are_clamped_to_caps_and_hp_is_at_least_one() -> void:
	var d := _saved_fresh()
	d["stats"]["strength"] = 99
	d["stats"]["defense"] = -3
	d["stats"]["hp"] = 0
	var loaded := _loaded(d)
	assert_eq(loaded.stats.strength, 20)
	assert_eq(loaded.stats.defense, 0)
	assert_eq(loaded.stats.hp, 1)
	assert_eq(loaded.current_hp, 1, "current_hp clamped to the new max")
	assert_no_save_warnings("clamping is silent")


func test_saved_movement_is_ignored() -> void:
	var d := _saved_fresh()
	d["stats"]["movement"] = 9
	assert_eq(_loaded(d).stats.movement, 5)
	assert_no_save_warnings("movement always comes from the class")


func test_unknown_item_is_skipped_and_the_rest_survive() -> void:
	var d := _saved_fresh()
	(d["inventory"] as Array).insert(0, {"item": "spoon"})
	var loaded := _loaded(d)
	assert_eq(loaded.inventory.size(), 2)
	assert_eq(loaded.inventory.get_item(0).data, GameData.get_item(&"iron_sword"))
	assert_save_warning()


func test_too_many_items_are_cut_to_capacity() -> void:
	var d := _saved_fresh()
	var entries: Array = d["inventory"]
	for i in 5:
		entries.append(entries[0].duplicate(true))
	assert_eq(_loaded(d).inventory.size(), Inventory.DEFAULT_CAPACITY)
	assert_save_warning()


# --- Tolerance: wrong types ------------------------------------------------------


func test_non_dictionary_state_keeps_the_fresh_unit() -> void:
	for bad in [null, [1, 2], "lyn"]:
		var loaded := _loaded(bad)
		assert_eq(loaded.current_hp, 16, "state %s" % [bad])
		assert_eq(loaded.inventory.size(), 2)
	assert_save_warning()


func test_wrong_type_level_falls_back_to_definition() -> void:
	for bad in ["abc", null, [5]]:
		var d := _saved_fresh()
		d["level"] = bad
		assert_eq(_loaded(d).level, 1, "level %s" % [bad])
	assert_save_warning()


func test_array_where_stats_belong_uses_definition() -> void:
	var d := _saved_fresh()
	d["stats"] = [1, 2, 3]
	assert_true(_loaded(d).stats.equals(_lyn().stats))
	assert_save_warning()


func test_wrong_type_single_stat_uses_definition() -> void:
	var d := _saved_fresh()
	d["stats"]["speed"] = "fast"
	assert_eq(_loaded(d).stats.speed, 9)
	assert_save_warning()


func test_dictionary_where_inventory_belongs_gives_empty_inventory() -> void:
	var d := _saved_fresh()
	d["inventory"] = {"item": "x"}
	assert_eq(_loaded(d).inventory.size(), 0)
	assert_save_warning()


func test_bad_inventory_entries_are_skipped() -> void:
	var d := _saved_fresh()
	(d["inventory"] as Array).append(42)
	(d["inventory"] as Array).append({"item": 7})
	(d["inventory"] as Array).append({"no_item": true})
	assert_eq(_loaded(d).inventory.size(), 2)
	assert_save_warning()


func test_bad_uses_left_defaults_to_max_uses() -> void:
	for bad in ["x", null, [2]]:
		var d := _saved_fresh()
		d["inventory"][1]["uses_left"] = bad
		assert_eq(_loaded(d).inventory.get_item(1).uses_left, 3, "uses_left %s" % [bad])
	var missing := _saved_fresh()
	(missing["inventory"][1] as Dictionary).erase("uses_left")
	assert_eq(_loaded(missing).inventory.get_item(1).uses_left, 3)
	assert_save_warning()


func test_out_of_range_uses_left_is_clamped() -> void:
	var d := _saved_fresh()
	d["inventory"][1]["uses_left"] = 0
	assert_eq(_loaded(d).inventory.get_item(1).uses_left, 1)
	d["inventory"][1]["uses_left"] = 99
	assert_eq(_loaded(d).inventory.get_item(1).uses_left, 3)
	assert_no_save_warnings("clamping is silent")
