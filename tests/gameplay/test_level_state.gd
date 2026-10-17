extends GutTest

const SAMPLE := {
	"map_data": {
		"layers": {"grass": {"z": 0, "terrain": "grass", "verts": [[0, 0], [1, 0]]}},
		"units": {
			"lyn": {"faction": "player", "stats": {"hp": 16}, "start_cell": [2, 3]},
			"wil": {"faction": "ally", "stats": {"hp": 20}, "start_cell": [4, 3]},
		},
	},
	"events": {"on_start": ["hello"]},
}


func test_empty_dict_is_a_valid_empty_level() -> void:
	var state := LevelState.fromJson({})
	assert_not_null(state.map_data)
	assert_eq(state.map_data.units.size(), 0)
	assert_eq(state.level_units.size(), 0)
	assert_eq(state.events, {})


func test_authored_level_starts_every_unit_fresh() -> void:
	var state := LevelState.fromJson(SAMPLE)
	assert_eq(state.level_units.size(), 2)
	assert_eq(state.level_units["lyn"].cell, Vector2i(2, 3))
	assert_eq(state.level_units["lyn"].current_hp, 16)


func test_to_json_without_state_omits_level_units() -> void:
	var state := LevelState.fromJson(SAMPLE)
	var authored := state.toJson(false)
	assert_false(authored.has("level_units"))
	assert_eq(authored["version"], LevelState.SAVE_VERSION)
	assert_eq(authored["events"], SAMPLE["events"])


func test_save_round_trip_restores_unit_state() -> void:
	var state := LevelState.fromJson(SAMPLE)
	state.level_units["lyn"].cell = Vector2i(7, 7)
	state.level_units["lyn"].current_hp = 3

	var again := LevelState.fromJson(state.toJson())
	assert_eq(again.level_units["lyn"].cell, Vector2i(7, 7))
	assert_eq(again.level_units["lyn"].current_hp, 3)
	assert_eq(again.level_units["wil"].current_hp, 20, "untouched unit is unchanged")
	assert_eq(again.toJson(), state.toJson())


func test_events_are_copied_not_shared() -> void:
	var state := LevelState.fromJson(SAMPLE)
	state.events["on_start"].append("changed")
	assert_eq(SAMPLE["events"]["on_start"].size(), 1)


func test_file_round_trip() -> void:
	var state := LevelState.fromJson(SAMPLE)
	state.level_units["lyn"].current_hp = 3
	var path := "user://test_level_state.json"
	assert_eq(state.save_file(path), OK)
	var again := LevelState.load_file(path)
	assert_not_null(again)
	assert_eq(again.toJson(), state.toJson())
	DirAccess.remove_absolute(path)


func test_load_file_returns_null_for_a_missing_file() -> void:
	assert_null(LevelState.load_file("user://no_such_level.json"))
	assert_push_error("Could not open level")


func test_load_file_returns_null_when_not_a_json_object() -> void:
	var path := "user://test_level_state_bad.json"
	FileAccess.open(path, FileAccess.WRITE).store_string("[1, 2, 3]")
	assert_null(LevelState.load_file(path))
	assert_push_error("is not a JSON object")
	DirAccess.remove_absolute(path)
