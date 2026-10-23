extends GutTest
## A placement on a map: a named character, or a generic unit defined right here.

const SHEETS := "res://assets/battle_pack/Sprite Sheets/"


func _lyn_placement() -> UnitReference:
	return UnitReference.fromJson("lyn", {
		"character": "lyn", "faction": "ally",
		"sprite_sheet": "res://sheet.png", "start_cell": [3.0, 4.0], "facing": [0.0, -1.0],
	})


func _bandit_placement() -> UnitReference:
	return UnitReference.fromJson("bandit", {
		"class": "fighter", "name": "Bandit", "faction": "enemy", "level": 2.0,
		"items": ["iron_axe"], "stats": {"hp": 24.0, "strength": 7.0, "defense": 4.0},
		"start_cell": [10.0, 5.0],
	})


# --- Reading and writing -------------------------------------------------------


func test_character_placement_fields() -> void:
	var ref := _lyn_placement()
	assert_eq(ref.id, "lyn")
	assert_true(ref.is_character())
	assert_eq(ref.character_id, "lyn")
	assert_eq(ref.faction, UnitReference.Faction.ALLY)
	assert_eq(ref.sprite_sheet, "res://sheet.png")
	assert_eq(ref.start_cell, Vector2i(3, 4))
	assert_eq(ref.facing, Vector2i.UP)


func test_generic_placement_fields() -> void:
	var ref := _bandit_placement()
	assert_false(ref.is_character())
	assert_eq(ref.class_id, "fighter")
	assert_eq(ref.name, "Bandit")
	assert_eq(ref.level, 2)
	assert_typeof(ref.level, TYPE_INT)
	assert_eq(ref.items, ["iron_axe"] as Array[String])
	assert_eq(ref.stat_overrides, {"hp": 24, "strength": 7, "defense": 4})
	assert_eq(ref.facing, Vector2i.DOWN, "facing defaults to down")


func test_round_trips() -> void:
	for ref in [_lyn_placement(), _bandit_placement()]:
		var again := UnitReference.fromJson(ref.id, ref.toJson())
		assert_eq(again.toJson(), ref.toJson())


func test_character_placement_writes_no_generic_fields() -> void:
	var saved := _lyn_placement().toJson()
	assert_eq(saved["character"], "lyn")
	for key in ["class", "name", "level", "items", "stats"]:
		assert_false(saved.has(key), key)


func test_unknown_keys_survive_a_round_trip() -> void:
	var d := _bandit_placement().toJson()
	d["notes"] = "boss of the fort"
	assert_eq(UnitReference.fromJson("bandit", d).toJson()["notes"], "boss of the fort")


func test_unknown_faction_defaults_to_player() -> void:
	assert_eq(UnitReference.faction_from_string("enemy"), UnitReference.Faction.ENEMY)
	assert_eq(UnitReference.faction_from_string("nope"), UnitReference.Faction.PLAYER)
	assert_push_warning("Unknown faction 'nope'")


func test_are_hostile_only_across_the_enemy_line() -> void:
	var by_faction := {}
	for faction in UnitReference.Faction.values():
		var ref := UnitReference.new()
		ref.faction = faction
		by_faction[faction] = ref
	var player: UnitReference = by_faction[UnitReference.Faction.PLAYER]
	var enemy: UnitReference = by_faction[UnitReference.Faction.ENEMY]
	var ally: UnitReference = by_faction[UnitReference.Faction.ALLY]
	assert_true(UnitReference.are_hostile(player, enemy))
	assert_true(UnitReference.are_hostile(enemy, player), "order doesn't matter")
	assert_true(UnitReference.are_hostile(ally, enemy))
	assert_false(UnitReference.are_hostile(player, ally), "green units are on the player's side")
	assert_false(UnitReference.are_hostile(player, player))
	assert_false(UnitReference.are_hostile(enemy, enemy))


# --- Building the unit definition ---------------------------------------------------


func test_character_builds_from_its_file() -> void:
	var data := _lyn_placement().build_unit_data()
	assert_not_null(data)
	assert_eq(data, GameData.get_character(&"lyn"))
	assert_eq(data.display_name, "Lyn")
	assert_eq(data.class_data.id, &"myrmidon")


func test_generic_uses_class_bases_plus_overrides() -> void:
	var data := _bandit_placement().build_unit_data()
	var fighter := GameData.get_class_data(&"fighter")
	assert_eq(data.class_data, fighter)
	assert_eq(data.display_name, "Bandit")
	assert_eq(data.level, 2)
	assert_eq(data.starting_stats.hp, 24, "override")
	assert_eq(data.starting_stats.strength, 7, "override")
	assert_eq(data.starting_stats.skill, fighter.base_stats.skill, "not overridden: class base")
	assert_eq(data.starting_items.size(), 1)
	assert_eq(data.starting_items[0], GameData.get_item(&"iron_axe"))


func test_generic_overrides_dont_touch_the_shared_class() -> void:
	_bandit_placement().build_unit_data()
	assert_eq(GameData.get_class_data(&"fighter").base_stats.hp, 20)


func test_generic_name_defaults_to_class_name() -> void:
	var ref := UnitReference.fromJson("f1", {"class": "fighter", "faction": "enemy"})
	assert_eq(ref.build_unit_data().display_name, "Fighter")
	assert_eq(ref.display_name(), "Fighter")


func test_unknown_character_or_class_cant_be_built() -> void:
	var typo := UnitReference.fromJson("lyn", {"character": "lynn"})
	assert_null(typo.build_unit_data())
	assert_string_contains(typo.build_problem(), "lynn")
	var no_class := UnitReference.fromJson("x", {"class": "dragon"})
	assert_null(no_class.build_unit_data())
	assert_string_contains(no_class.build_problem(), "dragon")
	var neither := UnitReference.fromJson("y", {"faction": "enemy"})
	assert_null(neither.build_unit_data())
	assert_ne(neither.build_problem(), "")


func test_zero_hp_or_con_override_cant_be_built() -> void:
	# Same rule as UnitData.validate(): a unit with 0 HP would spawn already dead.
	for bad in [{"hp": 0}, {"constitution": 0}, {"hp": -3}]:
		var ref := UnitReference.fromJson("b", {"class": "fighter", "stats": bad})
		assert_ne(ref.build_problem(), "", "stats %s" % [bad])
		assert_null(ref.build_unit_data())
		assert_null(LevelUnitState.from_reference(ref))


func test_unknown_item_is_skipped_with_a_warning() -> void:
	var ref := UnitReference.fromJson("b", {"class": "fighter", "items": ["iron_axe", "spoon"]})
	var data := ref.build_unit_data()
	assert_eq(data.starting_items.size(), 1)
	assert_push_warning("spoon")


# --- Sprites -----------------------------------------------------------------------


func test_sprite_for_fills_the_faction_color() -> void:
	var template := SHEETS + "LanceKnight/LanceKnight_{color}.png"
	assert_eq(UnitReference.sprite_for(template, UnitReference.Faction.PLAYER), SHEETS + "LanceKnight/LanceKnight_Blue.png")
	assert_eq(UnitReference.sprite_for(template, UnitReference.Faction.ENEMY), SHEETS + "LanceKnight/LanceKnight_Red.png")
	assert_eq(UnitReference.sprite_for(template, UnitReference.Faction.ALLY), SHEETS + "LanceKnight/LanceKnight_Green.png")


func test_explicit_sprite_sheet_wins() -> void:
	assert_eq(_lyn_placement().resolved_sprite(), "res://sheet.png")


func test_missing_sprite_uses_class_default_without_scanning_folders() -> void:
	var ref := UnitReference.fromJson("b", {"class": "fighter", "faction": "enemy"})
	assert_eq(ref.resolved_sprite(), SHEETS + "AxeFighter/AxeFighter_ShortHair_Red1.png")
	assert_true(ResourceLoader.exists(ref.resolved_sprite()))


func test_missing_sprite_uses_character_class_default() -> void:
	var ref := UnitReference.fromJson("wil", {"character": "wil", "faction": "player"})
	assert_eq(ref.resolved_sprite(), SHEETS + "Archer/Archer_Blue1.png")
