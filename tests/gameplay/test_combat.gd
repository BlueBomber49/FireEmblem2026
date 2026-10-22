extends GutTest
## Combat with real weapons, checked by hand against docs/fe7-reference.md.
##
## test_level, both on grass (plains: no terrain bonus):
## lyn    Myrmidon, Iron Sword (Mt 5 Hit 90 Crt 0 Wt 5): Str 5 Skl 7 Spd 9 Lck 2 Def 2 Con 5
## bandit Fighter,  Iron Axe   (Mt 8 Hit 75 Crt 0 Wt 10): Str 7 Skl 3 Spd 4 Lck 1 Def 4 Con 9
## Sword beats axe: lyn +1 damage +15 hit, bandit -1 / -15.
## AS: lyn 9 - max(0, 5-5) = 9; bandit 4 - max(0, 10-9) = 3.
## lyn:    damage 5 + (5+1) - 4 = 7;  hit 90+14+1+15 - (6+1) = 113 -> 100;  crit 0+3 - 1 = 2
## bandit: damage 7 + (8-1) - 2 = 12; hit 75+6+0-15 - (18+2) = 46;           crit 0+1 - 2 -> 0
## lyn doubles (9 - 3 >= 4).

const LEVEL_PATH := "res://resources/levels/test_level.json"

var state: LevelState
var lyn: LevelUnitState
var bandit: LevelUnitState


func before_each() -> void:
	state = LevelState.load_file(LEVEL_PATH)
	lyn = state.level_units["lyn"]
	bandit = state.level_units["bandit"]
	bandit.cell = lyn.cell + Vector2i.RIGHT


## A unit of `class_id` holding `items`, added to `level_state` at `cell`.
static func add_unit(level_state: LevelState, id: String, class_id: String, items: Array,
		faction: String, cell: Vector2i) -> LevelUnitState:
	var ref := UnitReference.fromJson(id, {"class": class_id, "items": items, "faction": faction,
		"start_cell": [cell.x, cell.y]})
	level_state.map_data.units[id] = ref
	var unit_state := LevelUnitState.from_reference(ref)
	level_state.level_units[id] = unit_state
	return unit_state


# --- Formulas ------------------------------------------------------------------


func test_attack_speed_subtracts_weight_over_con() -> void:
	assert_eq(Combat.attack_speed(lyn.unit), 9, "weight 5 vs con 5: no penalty")
	assert_eq(Combat.attack_speed(bandit.unit), 3, "weight 10 vs con 9: -1")


func test_weapon_triangle() -> void:
	var w := func(id: StringName) -> WeaponData: return GameData.get_item(id)
	assert_eq(Combat.triangle(w.call(&"iron_sword"), w.call(&"iron_axe")), 1, "sword beats axe")
	assert_eq(Combat.triangle(w.call(&"iron_axe"), w.call(&"iron_lance")), 1, "axe beats lance")
	assert_eq(Combat.triangle(w.call(&"iron_lance"), w.call(&"iron_sword")), 1, "lance beats sword")
	assert_eq(Combat.triangle(w.call(&"iron_axe"), w.call(&"iron_sword")), -1)
	assert_eq(Combat.triangle(w.call(&"iron_sword"), w.call(&"steel_sword")), 0, "same type")
	assert_eq(Combat.triangle(w.call(&"iron_bow"), w.call(&"iron_sword")), 0, "bows sit outside the triangle")
	assert_eq(Combat.triangle(w.call(&"fire"), w.call(&"iron_sword")), 0, "magic vs physical")
	assert_eq(Combat.triangle(null, w.call(&"iron_sword")), 0)


func test_magic_triangle() -> void:
	var anima := WeaponData.new()
	anima.weapon_type = Enums.WeaponType.ANIMA
	var light := WeaponData.new()
	light.weapon_type = Enums.WeaponType.LIGHT
	var dark := WeaponData.new()
	dark.weapon_type = Enums.WeaponType.DARK
	assert_eq(Combat.triangle(anima, light), 1)
	assert_eq(Combat.triangle(light, dark), 1)
	assert_eq(Combat.triangle(dark, anima), 1)
	assert_eq(Combat.triangle(light, anima), -1)


# --- Forecast ------------------------------------------------------------------


func test_forecast_numbers() -> void:
	var sides := Combat.forecast(lyn, bandit, state)
	assert_eq(sides[0].damage, 7)
	assert_eq(sides[1].damage, 12)
	assert_eq(sides[0].hit, 100, "113 clamps to 100")
	assert_eq(sides[1].hit, 46)
	assert_eq(sides[0].crit, 2)
	assert_eq(sides[1].crit, 0, "clamped at zero")
	assert_eq(sides[0].attack_count, 2, "AS 9 vs 3")
	assert_eq(sides[1].attack_count, 1)


func test_sides_carry_name_hp_weapon_and_advantage() -> void:
	var sides := Combat.forecast(lyn, bandit, state)
	assert_eq(sides[0].unit_name, "Lyn")
	assert_eq(sides[0].hp, 16)
	assert_eq(sides[0].weapon_name, "Iron Sword")
	assert_eq(sides[1].weapon_name, "Iron Axe")
	assert_eq(sides[0].advantage, 1)
	assert_eq(sides[1].advantage, -1)
	assert_true(sides[1].can_counter, "the axe reaches 1 tile")


func test_damage_never_goes_negative() -> void:
	bandit.unit.stats.defense = 50
	assert_eq(Combat.forecast(lyn, bandit, state)[0].damage, 0)


func test_magic_uses_magic_against_resistance() -> void:
	var mage := add_unit(state, "mage", "mage", ["fire"], "player", bandit.cell + Vector2i.UP)
	# Mage Mag 1 + Fire Mt 5 - bandit Res 0 = 6; Str doesn't matter.
	mage.unit.stats.strength = 15
	assert_eq(Combat.forecast(mage, bandit, state)[0].damage, 6)
	bandit.unit.stats.resistance = 4
	assert_eq(Combat.forecast(mage, bandit, state)[0].damage, 2)


func test_bows_are_effective_against_fliers() -> void:
	var archer := add_unit(state, "archer", "archer", ["iron_bow"], "player", Vector2i(6, 5))
	var pegasus := add_unit(state, "pegasus", "pegasus_knight", ["iron_lance"], "enemy", Vector2i(8, 5))
	# Archer Str 4 + Iron Bow Mt 6 x2 (effective) - Pegasus Def 3 = 13
	assert_eq(Combat.forecast(archer, pegasus, state)[0].damage, 13)
	# Not effective against a foot unit: 4 + 6 - 4 = 6
	bandit.cell = Vector2i(6, 7)
	assert_eq(Combat.forecast(archer, bandit, state)[0].damage, 6)


func test_class_crit_bonus_counts() -> void:
	lyn.unit.data.class_data.crit_bonus = 15
	assert_eq(Combat.forecast(lyn, bandit, state)[0].crit, 17)
	lyn.unit.data.class_data.crit_bonus = 0


# --- Range and counters --------------------------------------------------------


func test_bow_can_attack_at_two_but_not_one() -> void:
	var archer := add_unit(state, "archer", "archer", ["iron_bow"], "player", Vector2i(6, 7))
	bandit.cell = archer.cell + Vector2i(2, 0)
	assert_eq(Combat.hostiles_in_range(archer, state), [bandit] as Array[LevelUnitState])
	bandit.cell = archer.cell + Vector2i(1, 0)
	assert_eq(Combat.hostiles_in_range(archer, state).size(), 0, "too close for a bow")


func test_melee_defender_cant_counter_a_bow_at_two() -> void:
	var archer := add_unit(state, "archer", "archer", ["iron_bow"], "player", Vector2i(6, 7))
	bandit.cell = archer.cell + Vector2i(2, 0)
	var sides := Combat.forecast(archer, bandit, state)
	assert_false(sides[1].can_counter)


func test_bow_cant_counter_at_one() -> void:
	var archer := add_unit(state, "archer", "archer", ["iron_bow"], "enemy", lyn.cell + Vector2i.DOWN)
	var sides := Combat.forecast(lyn, archer, state)
	assert_false(sides[1].can_counter)


func test_javelin_counters_at_two() -> void:
	var soldier := add_unit(state, "soldier", "soldier", ["javelin"], "enemy", Vector2i(6, 7))
	var archer := add_unit(state, "archer", "archer", ["iron_bow"], "player", Vector2i(6, 9))
	assert_true(Combat.forecast(archer, soldier, state)[1].can_counter)


func test_no_weapon_means_no_targets_and_no_counter() -> void:
	var unarmed := add_unit(state, "unarmed", "myrmidon", [], "enemy", lyn.cell + Vector2i.UP)
	assert_eq(Combat.hostiles_in_range(unarmed, state).size(), 0)
	var sides := Combat.forecast(lyn, unarmed, state)
	assert_false(sides[1].can_counter)
	assert_eq(sides[1].weapon_name, "--")


func test_hostiles_in_range_ignores_allies_and_the_dead() -> void:
	state.level_units["wil"].cell = lyn.cell + Vector2i.LEFT
	bandit.current_hp = 0
	assert_eq(Combat.hostiles_in_range(lyn, state).size(), 0)


func test_hostiles_are_listed_nearest_first_then_clockwise_from_above() -> void:
	var brigand := add_unit(state, "brigand", "fighter", ["hand_axe"], "enemy", lyn.cell + Vector2i.LEFT)
	bandit.cell = lyn.cell + Vector2i.UP
	assert_eq(Combat.hostiles_in_range(lyn, state), [bandit, brigand] as Array[LevelUnitState])


# --- Terrain ---------------------------------------------------------------------
# A strip of plains with a tree patch on cell (2, 1). Forest is (2, 1) plus its
# half-tree edges (1, 1), (3, 1), (2, 0), (2, 2); row 3 and below is all plains.


func _terrain_level() -> LevelState:
	var grass := []
	for x in 7:
		for y in 4:
			grass.append([x, y])
	return LevelState.fromJson({"map_data": {"layers": {
		"grass": {"z": 0, "terrain": "grass", "verts": grass},
		"trees": {"z": 1, "terrain": "trees", "verts": [[2, 1], [3, 1], [2, 2], [3, 2]]},
	}}})


func test_defender_in_forest_gets_defense_and_avoid() -> void:
	var level_state := _terrain_level()
	var attacker := add_unit(level_state, "a", "fighter", ["iron_axe"], "enemy", Vector2i(1, 1))
	var defender := add_unit(level_state, "d", "myrmidon", ["iron_sword"], "player", Vector2i(2, 1))
	var open := add_unit(level_state, "o", "myrmidon", ["iron_sword"], "player", Vector2i(1, 3))
	var in_forest := Combat.forecast(attacker, defender, level_state)[0]
	var in_open := Combat.forecast(attacker, open, level_state)[0]
	assert_eq(in_open.damage - in_forest.damage, 1, "forest: +1 defense")
	assert_eq(in_open.hit - in_forest.hit, 20, "forest: +20 avoid")


func test_countered_attacker_uses_its_own_cell() -> void:
	var level_state := _terrain_level()
	var attacker := add_unit(level_state, "a", "myrmidon", ["iron_sword"], "player", Vector2i(2, 1))
	var defender := add_unit(level_state, "d", "fighter", ["iron_axe"], "enemy", Vector2i(3, 1))
	var counter_in_forest := Combat.forecast(attacker, defender, level_state)[1]
	attacker.cell = Vector2i(2, 3)
	defender.cell = Vector2i(3, 3)
	var counter_in_open := Combat.forecast(attacker, defender, level_state)[1]
	assert_eq(counter_in_open.hit - counter_in_forest.hit, 20, "the attacker's forest avoid applies to the counter")


func test_fliers_get_no_terrain_bonus() -> void:
	var level_state := _terrain_level()
	var attacker := add_unit(level_state, "a", "fighter", ["iron_axe"], "enemy", Vector2i(1, 1))
	var flier := add_unit(level_state, "f", "pegasus_knight", ["iron_lance"], "player", Vector2i(2, 1))
	var in_forest := Combat.forecast(attacker, flier, level_state)[0]
	flier.cell = Vector2i(1, 3)
	var in_open := Combat.forecast(attacker, flier, level_state)[0]
	assert_eq(in_forest.damage, in_open.damage)
	assert_eq(in_forest.hit, in_open.hit)


# --- Resolution ------------------------------------------------------------------
# A roll of 50 hits lyn's 100 but misses the bandit's 46; a roll of 10 hits both.
# Neither crits (lyn 2, bandit 0) unless a roll is below 2.


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
	var strikes := Combat.resolve(lyn, bandit, state, _always(10))
	assert_eq(strikes.size(), 3)
	assert_eq(strikes[0].attacker, lyn)
	assert_eq(strikes[1].attacker, bandit)
	assert_eq(strikes[2].attacker, lyn, "lyn doubles")
	assert_eq(strikes[0].hp_after, 17, "24 - 7")
	assert_eq(strikes[1].hp_after, 4, "16 - 12")
	assert_eq(strikes[2].hp_after, 10)
	assert_true(strikes[0].hit and strikes[1].hit and strikes[2].hit)
	assert_false(strikes[0].crit)


func test_a_miss_does_no_damage() -> void:
	var strikes := Combat.resolve(lyn, bandit, state, _always(50))
	assert_false(strikes[1].hit, "46 hit misses a roll of 50")
	assert_eq(strikes[1].damage, 0)
	assert_eq(strikes[1].hp_after, 16)


func test_crit_triples_damage() -> void:
	# Lyn's crit is 2: hit rolls 10, 10, then a crit roll of 1.
	var strikes := Combat.resolve(lyn, bandit, state, _rolls([10, 10, 1, 50, 50, 10, 10, 50]))
	assert_true(strikes[0].crit)
	assert_eq(strikes[0].damage, 21)


func test_resolve_does_not_touch_the_units() -> void:
	Combat.resolve(lyn, bandit, state, _always(10))
	assert_eq(lyn.current_hp, 16)
	assert_eq(bandit.current_hp, 24)


func test_fight_stops_when_a_side_falls() -> void:
	bandit.current_hp = 5
	var strikes := Combat.resolve(lyn, bandit, state, _always(10))
	assert_eq(strikes.size(), 1)
	assert_eq(strikes[0].hp_after, 0)


func test_defender_that_cant_counter_never_strikes() -> void:
	var archer := add_unit(state, "archer", "archer", ["iron_bow"], "player", Vector2i(6, 7))
	bandit.cell = archer.cell + Vector2i(2, 0)
	var strikes := Combat.resolve(archer, bandit, state, _always(10))
	for strike in strikes:
		assert_eq(strike.attacker, archer)
