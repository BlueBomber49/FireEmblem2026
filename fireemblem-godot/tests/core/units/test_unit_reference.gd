extends GutTest


func _lyn() -> UnitReference:
	return UnitReference.fromJson("lyn", {
		"name": "Lyn", "unit_class": "SwordFighter", "faction": "ally", "level": 3.0,
		"stats": {"hp": 16.0, "str": 5.0, "mag": 0.0, "skl": 7.0, "spd": 9.0,
				  "lck": 2.0, "def": 2.0, "res": 0.0, "con": 5.0, "mov": 5.0},
		"sprite_sheet": "res://sheet.png", "start_cell": [3.0, 4.0], "facing": [0.0, -1.0],
	})


func test_from_json_reads_every_field() -> void:
	var ref := _lyn()
	assert_eq(ref.id, "lyn")
	assert_eq(ref.name, "Lyn")
	assert_eq(ref.unit_class, "SwordFighter")
	assert_eq(ref.faction, UnitReference.Faction.ALLY)
	assert_eq(ref.level, 3)
	assert_typeof(ref.level, TYPE_INT)
	assert_eq(ref.stat(&"spd"), 9)
	assert_typeof(ref.stat(&"spd"), TYPE_INT)
	assert_eq(ref.sprite_sheet, "res://sheet.png")
	assert_eq(ref.start_cell, Vector2i(3, 4))
	assert_eq(ref.facing, Vector2i.UP)


func test_round_trip() -> void:
	var ref := _lyn()
	var again := UnitReference.fromJson(ref.id, ref.toJson())
	assert_eq(again.toJson(), ref.toJson())
	assert_eq(again.toJson()["faction"], "ally")


func test_missing_stat_is_zero() -> void:
	var ref := UnitReference.fromJson("x", {})
	assert_eq(ref.stat(&"mov"), 0)
	assert_eq(ref.name, "x", "name falls back to id")
	assert_eq(ref.level, 1)


func test_unknown_faction_defaults_to_player() -> void:
	assert_eq(UnitReference.faction_from_string("enemy"), UnitReference.Faction.ENEMY)
	assert_eq(UnitReference.faction_from_string("nope"), UnitReference.Faction.PLAYER)
	assert_engine_error("Unknown faction 'nope'")
