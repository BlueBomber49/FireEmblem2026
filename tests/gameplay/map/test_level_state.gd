extends GutTest

const SAMPLE := {
	"map_data": {
		"layers": {"grass": {"z": 0, "terrain": "grass", "verts": [[0, 0], [1, 0]]}},
		"units": {
			"lyn": {"character": "lyn", "faction": "player", "start_cell": [2, 3]},
			"wil": {"character": "wil", "faction": "ally", "start_cell": [4, 3]},
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
	assert_eq(JSON.stringify(again.toJson()), JSON.stringify(state.toJson()))


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
	assert_eq(JSON.stringify(again.toJson()), JSON.stringify(state.toJson()))
	DirAccess.remove_absolute(path)


func test_file_round_trip_keeps_full_unit_state() -> void:
	var state := LevelState.fromJson(SAMPLE)
	var lyn: LevelUnitState = state.level_units["lyn"]
	lyn.current_hp = 5
	assert_true(lyn.unit.use_item(1), "Lyn's Vulnerary: 5 -> 15, 2 uses left")
	lyn.cell = Vector2i(7, 5)
	lyn.has_acted = true
	var path := "user://test_level_state_units.json"
	assert_eq(state.save_file(path), OK)
	var again: LevelUnitState = LevelState.load_file(path).level_units["lyn"]
	assert_eq(again.current_hp, 15)
	assert_eq(again.unit.max_hp(), 16, "max HP stays separate")
	assert_eq(again.unit.inventory.get_item(1).uses_left, 2)
	assert_eq(again.unit.equipped_weapon(), GameData.get_item(&"iron_sword"))
	assert_eq(again.cell, Vector2i(7, 5))
	assert_true(again.has_acted)
	DirAccess.remove_absolute(path)


func test_authored_level_still_loads_fresh() -> void:
	var state := LevelState.fromJson(SAMPLE)
	assert_eq(state.level_units["lyn"].current_hp, 16)
	assert_eq(state.level_units["lyn"].unit.inventory.get_item(1).uses_left, 3)


func test_load_file_returns_null_for_a_missing_file() -> void:
	assert_null(LevelState.load_file("user://no_such_level.json"))
	assert_push_error("Could not open level")


func test_load_file_returns_null_when_not_a_json_object() -> void:
	var path := "user://test_level_state_bad.json"
	FileAccess.open(path, FileAccess.WRITE).store_string("[1, 2, 3]")
	assert_null(LevelState.load_file(path))
	assert_push_error("is not a JSON object")
	DirAccess.remove_absolute(path)


# --- Turn, seize and commander --------------------------------------------------


func test_an_authored_level_starts_on_turn_one_unseized() -> void:
	var state := LevelState.fromJson(SAMPLE)
	assert_eq(state.turn, 1)
	assert_false(state.seized)


func test_turn_and_seize_are_saved_only_with_state() -> void:
	var state := LevelState.fromJson(SAMPLE)
	state.turn = 4
	state.seized = true
	var authored := state.toJson(false)
	assert_false(authored.has("turn"), "an authored level always starts on turn 1")
	assert_false(authored.has("seized"))
	var again := LevelState.fromJson(state.toJson())
	assert_eq(again.turn, 4)
	assert_true(again.seized)
	assert_eq(LevelState.fromJson(authored).turn, 1)


func test_escaped_is_saved_only_with_state() -> void:
	var state := LevelState.fromJson(SAMPLE)
	assert_false(state.escaped)
	state.escaped = true
	assert_false(state.toJson(false).has("escaped"))
	assert_true(LevelState.fromJson(state.toJson()).escaped)


func test_commander_id_finds_the_marked_unit() -> void:
	var state := LevelState.fromJson(SAMPLE)
	assert_eq(state.commander_id(), "")
	var id: String = state.map_data.units.keys()[0]
	state.map_data.units[id].commander = true
	assert_eq(state.commander_id(), id)


# --- Reinforcements: placements tied to an event --------------------------------------


func _wave_level(event: Variant, faction := "enemy") -> LevelState:
	return LevelState.fromJson({
		"map_data": {
			"layers": {"grass": {"z": 0, "terrain": "grass", "verts": [[0, 0], [5, 0], [5, 5], [0, 5]]}},
			"units": {
				"lyn": {"character": "lyn", "faction": "player", "start_cell": [0, 0]},
				"bandit": {"class": "fighter", "items": ["iron_axe"], "faction": "enemy", "start_cell": [4, 4]},
				"wave": {"class": "fighter", "items": ["iron_axe"], "faction": faction, "start_cell": [3, 3],
						"event": "wave_1"},
			},
		},
		"events": {"wave_1": event},
	})


func _turn_event(turn: int, phase := "enemy") -> Dictionary:
	return {"trigger": {"type": "turn_start", "turn": turn, "phase": phase}, "actions": [{"type": "spawn"}]}


func test_a_placement_keeps_its_event() -> void:
	var state := _wave_level(_turn_event(2))
	assert_eq(state.map_data.units["wave"].event, "wave_1")
	assert_eq(state.map_data.units["wave"].toJson()["event"], "wave_1")
	assert_false(state.map_data.units["bandit"].toJson().has("event"), "written only when set")


func test_reinforcements_are_only_held_back_when_asked() -> void:
	var state := _wave_level(_turn_event(2))
	assert_true(state.level_units.has("wave"), "loading alone keeps every placement (the editor)")
	state.hold_back_reinforcements()
	assert_false(state.level_units.has("wave"))
	assert_true(state.pending_units.has("wave"))
	assert_true(state.level_units.has("bandit"))


func test_an_event_with_a_broken_trigger_places_its_units_at_the_start() -> void:
	var state := _wave_level({"trigger": {"type": "full_moon"}, "actions": [{"type": "spawn"}]})
	state.hold_back_reinforcements()
	assert_true(state.level_units.has("wave"), "never stuck off the map")
	assert_push_warning("wave_1")


func test_a_missing_event_places_the_unit_at_the_start() -> void:
	var state := _wave_level(_turn_event(2))
	state.events.erase("wave_1")
	state.hold_back_reinforcements()
	assert_true(state.level_units.has("wave"))
	assert_push_warning("wave_1")


func test_only_enemies_are_held_back() -> void:
	var state := _wave_level(_turn_event(2), "player")
	state.hold_back_reinforcements()
	assert_true(state.level_units.has("wave"), "reinforcements are enemies only")
	assert_push_warning("enemies")


func test_event_problems() -> void:
	assert_eq(LevelState.event_problem(_turn_event(2)), "")
	assert_ne(LevelState.event_problem(_turn_event(0)), "", "turn below 1")
	assert_ne(LevelState.event_problem(_turn_event(2, "dusk")), "", "unknown phase")
	assert_ne(LevelState.event_problem({"trigger": {"type": "full_moon"}}), "", "unknown trigger")
	assert_ne(LevelState.event_problem(["hello"]), "", "not an event at all")
