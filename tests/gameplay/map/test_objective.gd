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
	var state := _level({"lose": [
		{"type": "unit_defeated"},
		{"type": "faction_defeated", "faction": "enemi"},
		{"type": "seize"},
		"not an object",
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
	assert_eq(again.objective.lose.size(), 2)
