extends GutTest
## FE7 experience and level-ups, checked by hand against docs/fe7-reference.md.
##
## test_level: lyn is a level 1 Myrmidon, the bandit a level 2 Fighter; both
## classes are unpromoted with class power 3.
## Damage: (31 + 2 - 1) / 3 = 10. Kill base: 2*3 - 1*3 = 3, so a kill is
## 10 + 3 + 20 = 33, and a boss (commander) kill 33 + 40 = 73.

const LEVEL_PATH := "res://resources/levels/test_level.json"

var state: LevelState
var lyn: Unit
var bandit: Unit


func before_each() -> void:
	state = LevelState.load_file(LEVEL_PATH)
	lyn = state.level_units["lyn"].unit
	bandit = state.level_units["bandit"].unit


func _always(value: int) -> Callable:
	return func() -> int: return value


# --- EXP for a fight -------------------------------------------------------------


func test_no_damage_gives_one() -> void:
	assert_eq(Experience.for_fight(lyn, bandit, false, false), 1)


func test_damage_follows_the_level_gap() -> void:
	assert_eq(Experience.for_fight(lyn, bandit, true, false), 10)


func test_a_kill_adds_the_kill_bonus() -> void:
	assert_eq(Experience.for_fight(lyn, bandit, true, true), 33)


func test_a_boss_kill_adds_forty() -> void:
	assert_eq(Experience.for_fight(lyn, bandit, true, true, true), 73)


func test_a_thief_kill_adds_twenty() -> void:
	assert_eq(Experience.for_fight(lyn, bandit, true, true, false, true), 53)


func test_damage_exp_is_at_least_one() -> void:
	# A promoted level 20 unit against a level 1: (31 + 1 - 20 - 20) / 3 < 1. The
	# bandit is generic, so its definition is its own (characters share theirs).
	bandit.data.class_data = bandit.class_data().duplicate()  # don't touch the shared class
	bandit.class_data().promoted = true
	bandit.level = 20
	lyn.level = 1
	assert_eq(Experience.for_fight(bandit, lyn, true, false), 1)


func test_a_kill_below_the_units_level_never_takes_exp_away() -> void:
	lyn.level = 15
	bandit.level = 1
	# Damage (31 + 1 - 15) / 3 = 5; kill base 3 - 45 = -42, so +20 still leaves
	# the bonus below 0: it counts as 0.
	assert_eq(Experience.for_fight(lyn, bandit, true, true), 5)


func test_a_thief_class_is_found_by_its_tag() -> void:
	assert_true(Experience.is_thief(GameData.get_class_data(&"thief")))
	assert_false(Experience.is_thief(GameData.get_class_data(&"fighter")))


# --- Level-ups ---------------------------------------------------------------------


func test_gaining_exp_below_a_level_just_adds() -> void:
	assert_true(Experience.gain(lyn, 40, _always(0)).is_empty())
	assert_eq(lyn.experience, 40)
	assert_eq(lyn.level, 1)


func test_reaching_100_levels_up_and_keeps_the_rest() -> void:
	lyn.experience = 80
	var ups := Experience.gain(lyn, 33, _always(0))
	assert_eq(ups.size(), 1)
	assert_eq(lyn.level, 2)
	assert_eq(lyn.experience, 13)


func test_a_level_up_raises_each_stat_its_growth_allows() -> void:
	var before := lyn.stats.copy()
	var growths := lyn.growths()
	var ups := Experience.gain(lyn, 100, _always(0))[0]
	for field: StringName in [&"hp", &"strength", &"skill", &"speed", &"defense"]:
		if growths.get(field) > 0:
			assert_eq(lyn.stats.get(field), before.get(field) + 1, String(field))
			assert_eq(ups.get(field), 1)
	assert_eq(lyn.stats.movement, before.movement, "movement never grows")
	assert_eq(lyn.stats.constitution, before.constitution, "nor constitution")
	if growths.magic == 0:
		assert_eq(lyn.stats.magic, before.magic, "a 0% growth never rises")


func test_a_failed_roll_raises_nothing() -> void:
	var before := lyn.stats.copy()
	var ups := Experience.gain(lyn, 100, _always(99))
	assert_eq(ups, [{}] as Array[Dictionary], "a level, but no stats")
	assert_eq(lyn.stats.to_dict(), before.to_dict())


func test_stats_stop_at_the_class_cap() -> void:
	lyn.stats.speed = lyn.class_data().caps.speed
	Experience.gain(lyn, 100, _always(0))
	assert_eq(lyn.stats.speed, lyn.class_data().caps.speed)


func test_hp_growth_raises_current_hp_too() -> void:
	lyn.current_hp = lyn.max_hp()
	Experience.gain(lyn, 100, _always(0))
	assert_eq(lyn.current_hp, lyn.max_hp(), "a full unit stays full")


func test_level_twenty_gains_nothing() -> void:
	lyn.level = 20
	assert_true(Experience.gain(lyn, 50, _always(0)).is_empty())
	assert_eq(lyn.experience, 0)


func test_reaching_level_twenty_clears_the_exp() -> void:
	lyn.level = 19
	lyn.experience = 90
	Experience.gain(lyn, 30, _always(99))
	assert_eq(lyn.level, 20)
	assert_eq(lyn.experience, 0)
