extends GutTest
## Quotes: which battle quote plays for a fight, once per unit and dialogue, and
## death quotes.

var played: Dictionary
var boss: UnitReference
var adelard: UnitReference
var leora: UnitReference


func before_each() -> void:
	played = {}
	boss = _ref("boss", "enemy", {"quotes": [{"dialogue": "boss_vs_adelard", "with": "adelard"},
			{"dialogue": "boss_any"}], "death_quote": "boss_falls"})
	adelard = _ref("adelard", "player", {"character": "adelard"})
	leora = _ref("leora", "player", {"character": "leora"})


func _ref(id: String, faction: String, extra := {}) -> UnitReference:
	var d := {"class": "fighter", "faction": faction}
	d.merge(extra, true)
	return UnitReference.fromJson(id, d)


func test_the_quote_for_that_character_beats_the_anyone_quote() -> void:
	assert_eq(Quotes.battle_quote(adelard, boss, played), "boss_vs_adelard")


func test_who_starts_the_fight_doesnt_matter() -> void:
	assert_eq(Quotes.battle_quote(boss, adelard, played), "boss_vs_adelard")


func test_a_played_quote_doesnt_fall_back_to_the_anyone_quote() -> void:
	Quotes.battle_quote(adelard, boss, played)
	assert_eq(Quotes.battle_quote(boss, adelard, played), "", "Adelard again: nothing")
	assert_eq(Quotes.battle_quote(leora, boss, played), "boss_any", "someone else still gets it")
	assert_eq(Quotes.battle_quote(leora, boss, played), "")


func test_a_generic_player_unit_gets_the_anyone_quote() -> void:
	assert_eq(Quotes.battle_quote(_ref("soldier", "player"), boss, played), "boss_any")


func test_two_enemies_sharing_a_file_each_say_it_once() -> void:
	var bandit_a := _ref("bandit_a", "enemy", {"quotes": [{"dialogue": "bandit_taunt"}]})
	var bandit_b := _ref("bandit_b", "enemy", {"quotes": [{"dialogue": "bandit_taunt"}]})
	assert_eq(Quotes.battle_quote(adelard, bandit_a, played), "bandit_taunt")
	assert_eq(Quotes.battle_quote(adelard, bandit_b, played), "bandit_taunt", "per unit, not per file")
	assert_eq(Quotes.battle_quote(leora, bandit_a, played), "")


func test_allies_never_trigger_quotes() -> void:
	var ally := _ref("ally", "ally", {"character": "adelard"})
	assert_eq(Quotes.battle_quote(ally, boss, played), "")
	assert_true(played.is_empty(), "and nothing is used up")


func test_an_enemy_without_quotes_says_nothing() -> void:
	assert_eq(Quotes.battle_quote(adelard, _ref("mook", "enemy"), played), "")


func test_death_quotes_play_once_for_any_killer() -> void:
	assert_eq(Quotes.death_quote(boss, played), "boss_falls")
	assert_eq(Quotes.death_quote(boss, played), "")
	var hero := _ref("hero", "player", {"character": "adelard", "death_quote": "adelard_falls"})
	assert_eq(Quotes.death_quote(hero, played), "adelard_falls", "player units have them too")
	assert_eq(Quotes.death_quote(adelard, played), "", "none set")


func test_allies_have_no_death_quote() -> void:
	assert_eq(Quotes.death_quote(_ref("ally", "ally", {"death_quote": "x"}), played), "")
