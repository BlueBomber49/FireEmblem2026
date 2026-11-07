extends GutTest
## Objective: default rout, a lord whose defeat loses the level, losing taking
## precedence over winning, and bad conditions being dropped, not crashing.

const UNITS := {
	"lyn": {"character": "lyn", "faction": "player", "start_cell": [0, 0]},
	"kent": {"character": "kent", "faction": "player", "start_cell": [1, 0]},
	"bandit": {"class": "fighter", "faction": "enemy", "start_cell": [5, 0]},
}
const LORD_OBJECTIVE := {"lose": [
	{"type": "faction_defeated", "faction": "player"},
	{"type": "unit_defeated", "unit": "lyn"},
]}


func _level(objective: Variant = null) -> LevelState:
	var d := {"map_data": {"units": UNITS}}
	if objective != null:
		d["objective"] = objective
	return LevelState.fromJson(d)


func _defeat(state: LevelState, id: String) -> void:
	state.level_units[id].current_hp = 0


func test_default_is_a_rout() -> void:
	var state := _level()
	assert_eq(state.objective.outcome(state), Objective.Outcome.NONE)
	_defeat(state, "bandit")
	assert_eq(state.objective.outcome(state), Objective.Outcome.WON)


func test_default_loses_only_when_every_player_unit_falls() -> void:
	var state := _level()
	_defeat(state, "lyn")
	assert_eq(state.objective.outcome(state), Objective.Outcome.NONE)
	_defeat(state, "kent")
	assert_eq(state.objective.outcome(state), Objective.Outcome.LOST)


func test_lord_falling_loses_even_with_others_alive() -> void:
	var state := _level(LORD_OBJECTIVE)
	_defeat(state, "lyn")
	assert_eq(state.objective.outcome(state), Objective.Outcome.LOST)


func test_win_list_left_out_keeps_the_default_rout() -> void:
	var state := _level(LORD_OBJECTIVE)
	_defeat(state, "bandit")
	assert_eq(state.objective.outcome(state), Objective.Outcome.WON)


func test_losing_beats_winning_in_the_same_moment() -> void:
	var state := _level(LORD_OBJECTIVE)
	_defeat(state, "bandit")
	_defeat(state, "lyn")
	assert_eq(state.objective.outcome(state), Objective.Outcome.LOST)


func test_bad_conditions_are_dropped() -> void:
	# Seize is a real type now, but only on the win side, so it's still dropped here.
	var state := _level({"lose": [
		{"type": "unit_defeated"},
		{"type": "faction_defeated", "faction": "enemi"},
		{"type": "seize"},
		"not an object",
		{"type": 5},
		{"type": null},
		{"no type": "at all"},
		{"type": "unit_defeated", "unit": "lyn"},
	]})
	assert_eq(state.objective.lose.size(), 1)


func test_unit_missing_from_the_level_never_counts_as_defeated() -> void:
	var state := _level({"lose": [{"type": "unit_defeated", "unit": "eliwood"}]})
	assert_eq(state.objective.validate(state).size(), 1)
	assert_eq(state.objective.outcome(state), Objective.Outcome.NONE)


func test_round_trips_through_json() -> void:
	var state := _level(LORD_OBJECTIVE)
	var again := LevelState.fromJson(state.toJson(false))
	assert_eq(JSON.stringify(again.objective.toJson()), JSON.stringify(state.objective.toJson()))
	assert_eq(again.objective.lose.size(), 1, "the wipe loss is built in, so only the lord's line is stored")


# --- The built-in wipe loss ---------------------------------------------------


func test_a_full_wipe_always_loses_whatever_the_lose_list() -> void:
	var state := _level({"lose": [{"type": "turns_pass", "turns": 10}]})
	_defeat(state, "lyn")
	_defeat(state, "kent")
	assert_eq(state.objective.outcome(state), Objective.Outcome.LOST)


func test_a_full_wipe_loses_even_with_an_empty_lose_list() -> void:
	var state := _level({"lose": []})
	_defeat(state, "lyn")
	_defeat(state, "kent")
	assert_eq(state.objective.outcome(state), Objective.Outcome.LOST)


func test_the_default_lose_list_is_empty() -> void:
	assert_eq(Objective.new().lose.size(), 0, "the wipe loss isn't stored")


func test_a_listed_wipe_loss_is_dropped_on_load_and_shown_once() -> void:
	var state := _level({"lose": [{"type": "faction_defeated", "faction": "player"}]})
	assert_eq(state.objective.lose.size(), 0)
	assert_eq(state.objective.toJson()["lose"], [])
	assert_eq(state.objective.lose_lines(state), PackedStringArray(["Your army is defeated"]))


# --- Condition types ----------------------------------------------------------


func _commander_level(objective: Dictionary, commander := "bandit") -> LevelState:
	var units: Dictionary = UNITS.duplicate(true)
	if not commander.is_empty():
		units[commander]["commander"] = true
	var d := {"map_data": {"units": units}, "objective": objective}
	return LevelState.fromJson(d)


func test_defeat_the_enemy_commander() -> void:
	var state := _commander_level({"win": [{"type": "defeat_commander"}]})
	assert_eq(state.commander_id(), "bandit")
	assert_eq(state.objective.outcome(state), Objective.Outcome.NONE)
	_defeat(state, "bandit")
	assert_eq(state.objective.outcome(state), Objective.Outcome.WON)
	assert_eq(state.objective.win_lines(state), PackedStringArray(["Defeat the enemy commander"]))


func test_a_missing_commander_never_counts_as_defeated() -> void:
	var state := _commander_level({"win": [{"type": "defeat_commander"}]}, "")
	assert_eq(state.commander_id(), "")
	assert_eq(state.objective.outcome(state), Objective.Outcome.NONE, "not won just because no one is marked")
	assert_eq(state.objective.validate(state).size(), 1)


func test_commander_problems_are_reported() -> void:
	var state := _commander_level({"win": [{"type": "faction_defeated", "faction": "enemy"}]}, "lyn")
	assert_eq(state.objective.validate(state).size(), 1, "a player can't be the commander")
	var two := _commander_level({}, "bandit")
	two.map_data.units["kent"].commander = true
	assert_eq(two.objective.validate(two).size(), 2, "kent is a player and a second commander")
	var none_needed := _commander_level({}, "")
	assert_eq(none_needed.objective.validate(none_needed).size(), 0, "a rout needs no commander")


func test_seize_wins_once_seized() -> void:
	var state := _level({"win": [{"type": "seize", "cells": [[2, 3], [3, 3]], "name": "the gate"}]})
	assert_eq(state.objective.seize_cells(), [Vector2i(2, 3), Vector2i(3, 3)] as Array[Vector2i])
	assert_eq(state.objective.outcome(state), Objective.Outcome.NONE)
	state.seized = true
	assert_eq(state.objective.outcome(state), Objective.Outcome.WON)
	assert_eq(state.objective.win_lines(state), PackedStringArray(["Seize the gate"]))


func test_seize_without_a_name_points_at_the_marked_cell() -> void:
	var state := _level({"win": [{"type": "seize", "cells": [[2, 3]]}]})
	assert_eq(state.objective.win_lines(state), PackedStringArray(["Seize the marked cell"]))


func test_seize_with_no_cells_is_a_problem() -> void:
	var state := _level({"win": [{"type": "seize", "cells": []}]})
	assert_eq(state.objective.validate(state).size(), 1)


func test_survive_wins_once_that_many_enemy_phases_are_over() -> void:
	var state := _level({"win": [{"type": "survive", "turns": 2}]})
	state.turn = 2
	assert_eq(state.objective.outcome(state), Objective.Outcome.NONE, "one enemy phase done")
	state.turn = 3
	assert_eq(state.objective.outcome(state), Objective.Outcome.WON)
	assert_eq(state.objective.win_lines(state), PackedStringArray(["Survive 2 turns"]))


func test_turns_pass_loses_after_that_many_enemy_phases() -> void:
	var state := _level({"lose": [{"type": "turns_pass", "turns": 1}]})
	assert_eq(state.objective.outcome(state), Objective.Outcome.NONE)
	state.turn = 2
	assert_eq(state.objective.outcome(state), Objective.Outcome.LOST)
	assert_eq(state.objective.lose_lines(state), PackedStringArray(["Your army is defeated", "1 turn passes"]))


func test_turn_counts_below_one_are_problems() -> void:
	var state := _level({"win": [{"type": "survive", "turns": 0}], "lose": [{"type": "turns_pass", "turns": -1}]})
	assert_eq(state.objective.validate(state).size(), 2)


func test_units_fall_names_every_listed_unit() -> void:
	var one := _level({"lose": [{"type": "units_fall", "units": ["lyn"]}]})
	assert_eq(one.objective.lose_lines(one)[1], "Lyn falls")
	var two := _level({"lose": [{"type": "units_fall", "units": ["lyn", "kent"]}]})
	assert_eq(two.objective.lose_lines(two)[1], "Lyn or Kent falls")
	var three := _level({"lose": [{"type": "units_fall", "units": ["lyn", "kent", "bandit"]}]})
	assert_eq(three.objective.lose_lines(three)[1], "Lyn, Kent, or Fighter falls")
	_defeat(two, "kent")
	assert_eq(two.objective.outcome(two), Objective.Outcome.LOST, "any listed unit falling loses")


func test_the_old_unit_defeated_form_reads_as_units_fall() -> void:
	var state := _level({"lose": [{"type": "unit_defeated", "unit": "lyn"}]})
	assert_eq(state.objective.lose.size(), 1)
	assert_eq(state.objective.lose[0].type, "units_fall")
	assert_eq(state.objective.toJson()["lose"], [{"type": "units_fall", "units": ["lyn"]}])


func test_conditions_on_the_wrong_side_are_dropped() -> void:
	var state := _level({
		"win": [{"type": "turns_pass", "turns": 3}, {"type": "units_fall", "units": ["lyn"]}],
		"lose": [{"type": "survive", "turns": 3}, {"type": "defeat_commander"}],
	})
	assert_eq(state.objective.win.size(), 0)
	assert_eq(state.objective.lose.size(), 0)


func test_every_type_round_trips() -> void:
	var objective := {
		"win": [
			{"type": "faction_defeated", "faction": "enemy"},
			{"type": "defeat_commander"},
			{"type": "seize", "cells": [[1, 2]], "name": "the throne"},
			{"type": "survive", "turns": 4},
		],
		"lose": [{"type": "units_fall", "units": ["lyn", "kent"]}, {"type": "turns_pass", "turns": 9}],
	}
	var state := _commander_level(objective)
	assert_eq(JSON.stringify(state.objective.toJson()), JSON.stringify(objective))


# --- The registry and editor helpers -------------------------------------------


func test_the_registry_lists_types_by_side() -> void:
	assert_eq(Objective.types_for(Objective.WIN), ["faction_defeated", "defeat_commander", "seize", "survive"] as Array[String])
	assert_eq(Objective.types_for(Objective.LOSE), ["units_fall", "turns_pass"] as Array[String])
	assert_eq(Objective.title_of("seize"), "Seize")
	assert_eq(Objective.settings_of("seize"), [&"cells", &"name"] as Array[StringName])
	assert_eq(Objective.settings_of("defeat_commander"), [&"commander"] as Array[StringName], "the editor offers a commander pick")
	assert_eq(Objective.settings_of("faction_defeated"), [] as Array[StringName])


func test_create_makes_a_condition_with_defaults() -> void:
	var condition := Objective.create("survive")
	assert_eq(condition.type, "survive")
	assert_eq(condition.toJson(), {"type": "survive", "turns": 1})
	var rout := Objective.create("faction_defeated")
	assert_eq(rout.toJson(), {"type": "faction_defeated", "faction": "enemy"})


func test_has_type() -> void:
	var state := _level({"win": [{"type": "seize", "cells": [[2, 3]]}]})
	assert_true(state.objective.has_type("seize"))
	assert_false(state.objective.has_type("survive"))


func test_units_fall_with_no_units_yet_still_describes_itself() -> void:
	var fall := Objective.create("units_fall")
	assert_eq(fall.describe(_level()), "Units fall (none chosen yet)")
