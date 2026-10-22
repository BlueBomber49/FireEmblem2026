extends GutTest
## GameData: every JSON file under res://resources loads and validates, FE7 values
## land in the right fields, and bad files are reported without crashing.
##
## Fixture tests point GameData at tests/fixtures/game_data. GameData is static, so
## after_each always switches back to the real data, and the last test in this file
## checks that it did.

const FIXTURES := "res://tests/fixtures/game_data"
const COLORS := ["Blue", "Red", "Green"]


func after_each() -> void:
	GameData.load_all()


func after_all() -> void:
	GameData.load_all()


## Marks GameData's own warnings (all start with "Game data:") as expected.
func _allow_game_data_warnings() -> int:
	var count := 0
	for err in get_errors():
		if err.is_push_warning() and err.contains_text("Game data:") and not err.handled:
			err.handled = true
			count += 1
	return count


static func _json_files(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".json"):
			found.append(file.get_basename())
	return found


# --- Real data -----------------------------------------------------------------


func test_real_data_has_no_load_errors() -> void:
	GameData.load_all()
	assert_eq(GameData.load_errors(), PackedStringArray())


func test_every_file_is_loaded_under_its_file_name() -> void:
	for id in _json_files("res://resources/classes"):
		assert_not_null(GameData.get_class_data(StringName(id)), "class " + id)
	for id in _json_files("res://resources/weapons"):
		assert_true(GameData.get_item(StringName(id)) is WeaponData, "weapon " + id)
	for id in _json_files("res://resources/consumables"):
		assert_true(GameData.get_item(StringName(id)) is ConsumableData, "consumable " + id)
	for id in _json_files("res://resources/terrain_data"):
		assert_not_null(GameData.get_terrain(StringName(id)), "terrain " + id)


func test_counts() -> void:
	assert_eq(GameData.all_class_ids().size(), 11)
	assert_eq(GameData.all_item_ids().size(), 14 + 2, "14 weapons, 2 consumables")
	assert_eq(GameData.all_terrain_ids().size(), 11)
	assert_eq(GameData.all_character_ids(), [&"kent", &"lyn", &"wil"] as Array[StringName])


func test_every_character_file_is_loaded() -> void:
	for id in _json_files("res://resources/characters"):
		assert_not_null(GameData.get_character(StringName(id)), "character " + id)


func test_lyn_has_her_own_stats_class_and_items() -> void:
	var lyn := GameData.get_character(&"lyn")
	assert_eq(lyn.display_name, "Lyn")
	assert_eq(lyn.class_data, GameData.get_class_data(&"myrmidon"))
	assert_eq(lyn.level, 1)
	assert_eq(lyn.starting_stats.hp, 16)
	assert_eq(lyn.starting_stats.speed, 9)
	assert_eq(lyn.starting_stats.luck, 2, "her own luck, not the class's 0")
	assert_null(lyn.growths, "no personal growths: uses the class's")
	assert_eq(lyn.starting_items, [GameData.get_item(&"iron_sword"), GameData.get_item(&"vulnerary")] as Array[ItemData])


func test_wil_and_kent() -> void:
	var wil := GameData.get_character(&"wil")
	assert_eq(wil.class_data.id, &"archer")
	assert_eq(wil.starting_items, [GameData.get_item(&"iron_bow")] as Array[ItemData])
	var kent := GameData.get_character(&"kent")
	assert_eq(kent.class_data.id, &"cavalier")
	assert_eq(kent.starting_stats.hp, 22)
	assert_eq(kent.starting_items.size(), 2)


func test_every_character_validates() -> void:
	for id in GameData.all_character_ids():
		assert_eq(GameData.get_character(id).validate(), PackedStringArray(), String(id))


## Regression: the first call after startup used to return an empty list, because
## the table was read before loading replaced it. after_each reloads the data.
func test_id_lists_work_as_the_very_first_call() -> void:
	_forget_loaded_data()
	assert_false(GameData.all_character_ids().is_empty(), "characters, first call after startup")
	_forget_loaded_data()
	assert_false(GameData.all_class_ids().is_empty(), "classes, first call after startup")
	_forget_loaded_data()
	assert_false(GameData.all_item_ids().is_empty(), "items, first call after startup")
	_forget_loaded_data()
	assert_false(GameData.all_terrain_ids().is_empty(), "terrain, first call after startup")


## Puts GameData back in its state at startup: nothing loaded yet.
func _forget_loaded_data() -> void:
	GameData._loaded = false
	GameData._classes = {}
	GameData._items = {}
	GameData._terrain = {}
	GameData._characters = {}


func test_unknown_ids_are_null() -> void:
	assert_null(GameData.get_character(&"lynn"))
	assert_null(GameData.get_class_data(&"dragon"))
	assert_null(GameData.get_item(&"spoon"))
	assert_null(GameData.get_terrain(&"lava"))


func test_myrmidon_spot_check() -> void:
	var c := GameData.get_class_data(&"myrmidon")
	assert_eq(c.display_name, "Myrmidon")
	assert_eq(c.base_stats.speed, 9)
	assert_eq(c.base_stats.skill, 9)
	assert_eq(c.movement_type, Enums.MovementType.FOOT)
	assert_eq(c.usable_weapon_types, [Enums.WeaponType.SWORD] as Array[Enums.WeaponType])


func test_mage_uses_magic_not_strength() -> void:
	var c := GameData.get_class_data(&"mage")
	assert_eq(c.base_stats.magic, 1)
	assert_eq(c.base_stats.strength, 0)
	assert_eq(c.growths.magic, 55)
	assert_eq(c.growths.strength, 0)
	assert_eq(c.movement_type, Enums.MovementType.MAGE)


func test_knight_spot_check() -> void:
	var c := GameData.get_class_data(&"knight")
	assert_eq(c.base_stats.movement, 4)
	assert_eq(c.base_stats.defense, 9)
	assert_eq(c.base_stats.constitution, 13)
	assert_true(c.has_tag(&"armored"))
	assert_eq(c.movement_type, Enums.MovementType.ARMORED)


func test_pegasus_knight_is_a_flier() -> void:
	var c := GameData.get_class_data(&"pegasus_knight")
	assert_true(c.has_tag(&"flier"))
	assert_eq(c.movement_type, Enums.MovementType.FLIER)
	assert_eq(c.base_stats.resistance, 2)


func test_class_power() -> void:
	assert_eq(GameData.get_class_data(&"soldier").class_power, 2)
	assert_eq(GameData.get_class_data(&"thief").class_power, 2)
	assert_eq(GameData.get_class_data(&"fighter").class_power, 3)


func test_cavalier_wields_swords_and_lances() -> void:
	var c := GameData.get_class_data(&"cavalier")
	assert_true(Enums.WeaponType.SWORD in c.usable_weapon_types)
	assert_true(Enums.WeaponType.LANCE in c.usable_weapon_types)
	assert_true(c.has_tag(&"mounted"))


func test_caps_are_fe7_unpromoted() -> void:
	var c := GameData.get_class_data(&"fighter")
	assert_eq(c.caps.hp, 60)
	assert_eq(c.caps.luck, 30)
	assert_eq(c.caps.movement, 15)


func test_every_class_sprite_exists_in_every_color() -> void:
	for id in GameData.all_class_ids():
		var c := GameData.get_class_data(id)
		assert_true(c.sprite.contains("{color}"), "%s sprite has a {color} placeholder" % id)
		for color in COLORS:
			var path := c.sprite.replace("{color}", color)
			assert_true(ResourceLoader.exists(path), "%s: %s" % [id, path])


func test_iron_bow_is_effective_against_fliers() -> void:
	var w := GameData.get_item(&"iron_bow") as WeaponData
	assert_eq(w.min_range, 2)
	assert_eq(w.max_range, 2)
	assert_true(w.is_effective_against([&"flier"]))


func test_javelin_and_hand_axe_reach_two() -> void:
	for id in [&"javelin", &"hand_axe"]:
		var w := GameData.get_item(id) as WeaponData
		assert_eq(w.min_range, 1, id)
		assert_eq(w.max_range, 2, id)


func test_iron_sword_spot_check() -> void:
	var w := GameData.get_item(&"iron_sword") as WeaponData
	assert_eq(w.display_name, "Iron Sword")
	assert_eq(w.might, 5)
	assert_eq(w.hit, 90)
	assert_eq(w.weight, 5)
	assert_eq(w.crit, 0)


func test_fire_is_anima_magic() -> void:
	var w := GameData.get_item(&"fire") as WeaponData
	assert_eq(w.weapon_type, Enums.WeaponType.ANIMA)
	assert_true(w.is_magic())


func test_consumables() -> void:
	var v := GameData.get_item(&"vulnerary") as ConsumableData
	assert_eq(v.max_uses, 3)
	assert_eq(v.heal_amount, 10)
	var e := GameData.get_item(&"elixir") as ConsumableData
	assert_eq(e.max_uses, 3)
	assert_eq(e.heal_amount, ConsumableData.FULL_HEAL)


func test_forest_and_sea_spot_check() -> void:
	var forest := GameData.get_terrain(&"forest")
	assert_eq(forest.defense, 1)
	assert_eq(forest.avoid, 20)
	assert_eq(forest.move_cost(Enums.MovementType.MOUNTED), 3)
	var sea := GameData.get_terrain(&"sea")
	assert_false(sea.is_passable(Enums.MovementType.FOOT))
	assert_eq(sea.move_cost(Enums.MovementType.FLIER), 1)
	var fort := GameData.get_terrain(&"fort")
	assert_eq(fort.heal_percent, 20)


func test_only_forest_counts_half_edges() -> void:
	assert_true(GameData.get_terrain(&"forest").half_edge_counts)
	for id in GameData.all_terrain_ids():
		if id != &"forest":
			assert_false(GameData.get_terrain(id).half_edge_counts, String(id))


# --- Tiles to terrain rules -------------------------------------------------------


func test_game_tiles_map_to_fe7_terrain() -> void:
	assert_eq(GameData.terrain_for_tile("grass").id, &"plains")
	assert_eq(GameData.terrain_for_tile("trees").id, &"forest")
	assert_eq(GameData.terrain_for_tile("water").id, &"sea")


func test_empty_tile_has_no_terrain() -> void:
	assert_null(GameData.terrain_for_tile(""), "nothing drawn: impassable")


func test_unknown_tile_falls_back_to_plains_and_warns_once() -> void:
	assert_eq(GameData.terrain_for_tile("lava").id, &"plains")
	assert_eq(GameData.terrain_for_tile("lava").id, &"plains")
	assert_eq(GameData.terrain_for_tile("lava").id, &"plains")
	assert_eq(_allow_game_data_warnings(), 1, "one warning per unknown tile id, not per lookup")


# --- Bad files (fixture folder) ----------------------------------------------------


func test_fixture_good_file_loads() -> void:
	GameData.load_all(FIXTURES)
	_allow_game_data_warnings()
	var w := GameData.get_item(&"good_sword") as WeaponData
	assert_not_null(w)
	assert_eq(w.might, 5)


func test_fixture_bad_files_are_reported_and_skipped() -> void:
	GameData.load_all(FIXTURES)
	_allow_game_data_warnings()
	var errors := "\n".join(GameData.load_errors())
	for file in ["broken.json", "wrong_name.json", "typo_key.json", "zero_range.json", "bad_type.json", "half_number.json"]:
		assert_string_contains(errors, file)
	for id in [&"broken", &"some_other_id", &"wrong_name", &"typo_key", &"zero_range", &"bad_type", &"half_number"]:
		assert_null(GameData.get_item(id), "%s is skipped" % id)


func test_fixture_errors_explain_the_problem() -> void:
	GameData.load_all(FIXTURES)
	_allow_game_data_warnings()
	var errors := "\n".join(GameData.load_errors())
	assert_string_contains(errors, "mght", "names the unknown key")
	assert_string_contains(errors, "spoon", "names the bad weapon type")
	assert_string_contains(errors, "some_other_id", "names the mismatched id")


func test_zz_real_data_is_loaded_again() -> void:
	# Runs last in this file: the fixture tests above must not leak into later files.
	assert_not_null(GameData.get_class_data(&"knight"))
	assert_null(GameData.get_item(&"good_sword"))
