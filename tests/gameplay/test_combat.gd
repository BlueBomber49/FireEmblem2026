extends GutTest
## Numbers checked by hand against docs/fe7-reference.md with the placeholder
## Iron Sword (might 5, hit 90, crit 0, weight 5).
##
## lyn:    str 5  skl 7  spd 9  lck 2  def 2  con 5  -> AS 9
## bandit: str 7  skl 3  spd 4  lck 1  def 4  con 9  -> AS 4

const LEVEL_PATH := "res://resources/levels/test_level.json"

var state: LevelState
var lyn: LevelUnitState
var bandit: LevelUnitState


func before_each() -> void:
	state = LevelState.load_file(LEVEL_PATH)
	lyn = state.level_units["lyn"]
	bandit = state.level_units["bandit"]


func test_attack_speed_subtracts_weight_over_con() -> void:
	assert_eq(Combat.attack_speed(lyn), 9, "weight 5 vs con 5: no penalty")
	assert_eq(Combat.attack_speed(bandit), 4)


func test_damage_is_str_plus_might_minus_def() -> void:
	var sides := Combat.forecast(lyn, bandit, true)
	assert_eq(sides[0].damage, 6, "5 + 5 - 4")
	assert_eq(sides[1].damage, 10, "7 + 5 - 2")


func test_hit_is_accuracy_minus_avoid() -> void:
	var sides := Combat.forecast(lyn, bandit, true)
	assert_eq(sides[0].hit, 96, "90 + 14 + 1 - (8 + 1)")
	assert_eq(sides[1].hit, 76, "90 + 6 + 0 - (18 + 2)")


func test_crit_is_clamped_at_zero() -> void:
	var sides := Combat.forecast(lyn, bandit, true)
	assert_eq(sides[0].crit, 2, "0 + 3 - 1")
	assert_eq(sides[1].crit, 0, "0 + 1 - 2 clamps to 0")


func test_faster_unit_doubles() -> void:
	var sides := Combat.forecast(lyn, bandit, true)
	assert_eq(sides[0].attack_count, 2, "AS 9 vs 4")
	assert_eq(sides[1].attack_count, 1)


func test_sides_carry_name_hp_and_placeholder_weapon() -> void:
	var sides := Combat.forecast(lyn, bandit, true)
	assert_eq(sides[0].unit_name, "Lyn")
	assert_eq(sides[0].hp, 16)
	assert_eq(sides[0].weapon_name, "--")
	assert_eq(sides[0].advantage, 0)
	assert_true(sides[1].can_counter)


func test_defender_that_cant_counter() -> void:
	var sides := Combat.forecast(lyn, bandit, false)
	assert_true(sides[0].can_counter)
	assert_false(sides[1].can_counter)


func test_damage_never_goes_negative() -> void:
	bandit.unit_ref.stats[&"def"] = 50
	assert_eq(Combat.forecast(lyn, bandit, true)[0].damage, 0)


func test_adjacent_hostiles_needs_a_neighbouring_enemy() -> void:
	assert_eq(Combat.adjacent_hostiles(lyn, state).size(), 0, "bandit is four cells away")
	bandit.cell = lyn.cell + Vector2i.UP
	assert_eq(Combat.adjacent_hostiles(lyn, state), [bandit] as Array[LevelUnitState])


func test_adjacent_hostiles_ignores_allies_and_the_dead() -> void:
	state.level_units["wil"].cell = lyn.cell + Vector2i.LEFT
	bandit.cell = lyn.cell + Vector2i.RIGHT
	bandit.current_hp = 0
	assert_eq(Combat.adjacent_hostiles(lyn, state).size(), 0)


func test_adjacent_hostiles_are_listed_clockwise_from_above() -> void:
	var brigand := LevelUnitState.from_reference(bandit.unit_ref)
	state.level_units["brigand"] = brigand
	brigand.cell = lyn.cell + Vector2i.LEFT
	bandit.cell = lyn.cell + Vector2i.UP
	assert_eq(Combat.adjacent_hostiles(lyn, state), [bandit, brigand] as Array[LevelUnitState])


# --- Resolution ------------------------------------------------------------
# A roll that always returns 50 hits whenever the displayed hit is above 50
# (lyn 96, bandit 76) and never crits (lyn 2, bandit 0).


func _always(value: int) -> Callable:
	return func() -> int: return value


func _rolls(values: Array) -> Callable:
	var queue := values.duplicate()
	return func() -> int: return queue.pop_front()


func test_true_hit_averages_two_rolls() -> void:
	assert_true(Combat.true_hit(50, _rolls([49, 50])), "49.5 < 50")
	assert_false(Combat.true_hit(50, _rolls([50, 50])), "50 is not below 50")
	assert_true(Combat.true_hit(100, _always(99)), "100 always hits")
	assert_false(Combat.true_hit(0, _always(0)), "0 never hits")


func test_fe_order_attacker_counter_then_the_doubler() -> void:
	var strikes := Combat.resolve(lyn, bandit, true, _always(50))
	assert_eq(strikes.size(), 3)
	assert_eq(strikes[0].attacker, lyn)
	assert_eq(strikes[1].attacker, bandit)
	assert_eq(strikes[2].attacker, lyn, "lyn doubles")
	assert_eq(strikes[0].hp_after, 18, "24 - 6")
	assert_eq(strikes[1].hp_after, 6, "16 - 10")
	assert_eq(strikes[2].hp_after, 12)
	assert_true(strikes[0].hit and strikes[1].hit and strikes[2].hit)
	assert_false(strikes[0].crit)


func test_resolve_does_not_touch_the_units() -> void:
	Combat.resolve(lyn, bandit, true, _always(50))
	assert_eq(lyn.current_hp, 16)
	assert_eq(bandit.current_hp, 24)


func test_fight_stops_when_a_side_falls() -> void:
	bandit.current_hp = 5
	var strikes := Combat.resolve(lyn, bandit, true, _always(50))
	assert_eq(strikes.size(), 1)
	assert_eq(strikes[0].hp_after, 0)


func test_defender_that_cant_counter_never_strikes() -> void:
	var strikes := Combat.resolve(lyn, bandit, false, _always(50))
	assert_eq(strikes.size(), 2)
	assert_eq(strikes[0].attacker, lyn)
	assert_eq(strikes[1].attacker, lyn)


func test_defender_doubles_when_it_is_the_faster_one() -> void:
	var strikes := Combat.resolve(bandit, lyn, true, _always(50))
	assert_eq(strikes.size(), 3)
	assert_eq(strikes[0].attacker, bandit)
	assert_eq(strikes[1].attacker, lyn)
	assert_eq(strikes[2].attacker, lyn, "the defender doubles")


func test_crit_triples_damage() -> void:
	var strikes := Combat.resolve(lyn, bandit, true, _always(0))
	assert_true(strikes[0].crit, "roll 0 is below lyn's crit of 2")
	assert_eq(strikes[0].damage, 18)
	assert_eq(strikes[0].hp_after, 6)
	assert_false(strikes[1].crit, "bandit's crit is 0, so a roll of 0 can't crit")


func test_miss_deals_nothing() -> void:
	var strikes := Combat.resolve(lyn, bandit, true, _always(99))
	assert_eq(strikes.size(), 3)
	for strike in strikes:
		assert_false(strike.hit)
		assert_eq(strike.damage, 0)
	assert_eq(strikes[2].hp_after, 24)
