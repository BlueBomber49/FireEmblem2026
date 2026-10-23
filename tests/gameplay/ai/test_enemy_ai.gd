extends GutTest


class FakeContext extends EnemyAIContext:
	var positions: Dictionary = {}
	var combat_results: Dictionary = {}
	var width := 20
	var height := 20


	func unit_position(unit: Unit) -> Vector2i:
		return positions.get(unit, Vector2i.ZERO)


	func reachable_positions(unit: Unit, from: Vector2i) -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		var movement := unit.stats.movement
		for x in range(maxi(0, from.x - movement), mini(width, from.x + movement + 1)):
			for y in range(maxi(0, from.y - movement), mini(height, from.y + movement + 1)):
				var cell := Vector2i(x, y)
				if _distance(from, cell) <= movement and not is_occupied(cell, unit):
					result.append(cell)
		return result


	func can_attack_from(attacker: Unit, attacker_position: Vector2i,
			target: Unit, target_position: Vector2i) -> bool:
		var weapon := attacker.equipped_weapon()
		return weapon != null and weapon.in_range(_distance(attacker_position, target_position))


	func evaluate_combat(_attacker: Unit, _attacker_position: Vector2i,
			target: Unit, _target_position: Vector2i) -> EnemyAICombatResult:
		if combat_results.has(target):
			return combat_results[target]
		var result := EnemyAICombatResult.new()
		result.damage_per_hit = 1
		result.hit_chance = 100
		result.can_counter = false
		return result


	func is_occupied(position: Vector2i, except_unit: Unit) -> bool:
		for unit: Unit in positions:
			if unit != except_unit and unit.is_alive() and positions[unit] == position:
				return true
		return false


	func terrain_advantage(_unit: Unit, _position: Vector2i) -> int:
		return 0


	static func _distance(a: Vector2i, b: Vector2i) -> int:
		return absi(a.x - b.x) + absi(a.y - b.y)


const STRATEGIES: Array[EnemyAI.Strategy] = [
	EnemyAI.Strategy.STATIONARY,
	EnemyAI.Strategy.DEFENSIVE,
	EnemyAI.Strategy.AGGRESSIVE,
]

var _context: FakeContext


func before_each() -> void:
	_context = FakeContext.new()
	_context.width = 20
	_context.height = 20


func _stats(hp: int, movement: int) -> Stats:
	var stats := Stats.new()
	stats.hp = hp
	stats.movement = movement
	return stats


func _weapon(min_range: int = 1, max_range: int = 1) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.id = &"test_sword"
	weapon.display_name = "Test Sword"
	weapon.weapon_type = Enums.WeaponType.SWORD
	weapon.min_range = min_range
	weapon.max_range = max_range
	return weapon


func _vulnerary() -> ConsumableData:
	var item := ConsumableData.new()
	item.id = &"test_vulnerary"
	item.display_name = "Test Vulnerary"
	item.max_uses = 3
	item.heal_amount = 10
	return item


func _unit(unit_id: StringName, movement: int = 4,
		with_weapon: bool = true, with_healing_item: bool = false,
		weapon_min_range: int = 1, weapon_max_range: int = 1) -> Unit:
	var class_data := ClassData.new()
	class_data.id = StringName("class_%s" % unit_id)
	class_data.base_stats = _stats(10, movement)
	class_data.growths = Stats.new()
	class_data.caps = _stats(99, 15)
	class_data.usable_weapon_types = [Enums.WeaponType.SWORD]

	var data := UnitData.new()
	data.id = unit_id
	data.display_name = String(unit_id)
	data.class_data = class_data
	data.starting_stats = _stats(10, movement)
	if with_weapon:
		data.starting_items.append(_weapon(weapon_min_range, weapon_max_range))
	if with_healing_item:
		data.starting_items.append(_vulnerary())
	return Unit.new(data)


func _place(unit: Unit, position: Vector2i) -> void:
	_context.positions[unit] = position


func _player_at(unit_id: StringName, position: Vector2i) -> Unit:
	var player := _unit(unit_id, 0)
	_place(player, position)
	return player


func _result(damage: int, hit: int, counter_damage: int = 0,
		counter_hit: int = 0) -> EnemyAICombatResult:
	var result := EnemyAICombatResult.new()
	result.damage_per_hit = damage
	result.hit_chance = hit
	result.can_counter = counter_hit > 0
	result.counter_damage_per_hit = counter_damage
	result.counter_hit_chance = counter_hit
	return result


func _attack(unit: Unit, players: Array[Unit], origin: Vector2i,
		allies: Array[Unit] = []) -> EnemyAIAction:
	return EnemyAIHelpers.attack_best_target(unit, origin, players, _context, false, allies)


func test_enemy_ai_is_created_with_the_requested_strategy() -> void:
	for strategy: EnemyAI.Strategy in STRATEGIES:
		var ai := EnemyAI.new(strategy)
		assert_eq(ai.strategy, strategy)


func test_enemy_ai_retains_its_defensive_team_id() -> void:
	var ai := EnemyAI.new(EnemyAI.Strategy.DEFENSIVE, &"left_flank")
	assert_eq(ai.strategy, EnemyAI.Strategy.DEFENSIVE)
	assert_eq(ai.defensive_team_id, &"left_flank")


func test_low_hp_unit_with_healing_item_plans_to_heal_for_each_strategy() -> void:
	for strategy: EnemyAI.Strategy in STRATEGIES:
		var unit := _unit(&"low_hp_healer", 4, true, true)
		unit.take_damage(9)
		_place(unit, Vector2i(5, 5))
		var action := EnemyAI.new(strategy).take_turn(unit, Vector2i(5, 5), [], _context)
		assert_eq(action.type, EnemyAIAction.Type.HEAL)
		assert_eq(action.inventory_index, 1)


func test_low_hp_unit_without_healing_item_does_not_plan_to_heal_for_each_strategy() -> void:
	for strategy: EnemyAI.Strategy in STRATEGIES:
		var unit := _unit(&"low_hp_no_item")
		unit.take_damage(9)
		_place(unit, Vector2i(5, 5))
		var action := EnemyAI.new(strategy).take_turn(unit, Vector2i(5, 5), [], _context)
		assert_ne(action.type, EnemyAIAction.Type.HEAL)


func test_full_hp_unit_with_healing_item_does_not_plan_to_heal_for_each_strategy() -> void:
	for strategy: EnemyAI.Strategy in STRATEGIES:
		var unit := _unit(&"full_hp_healer", 4, true, true)
		_place(unit, Vector2i(5, 5))
		var action := EnemyAI.new(strategy).take_turn(unit, Vector2i(5, 5), [], _context)
		assert_ne(action.type, EnemyAIAction.Type.HEAL)


func test_full_hp_unit_without_healing_item_does_not_plan_to_heal_for_each_strategy() -> void:
	for strategy: EnemyAI.Strategy in STRATEGIES:
		var unit := _unit(&"full_hp_no_item")
		_place(unit, Vector2i(5, 5))
		var action := EnemyAI.new(strategy).take_turn(unit, Vector2i(5, 5), [], _context)
		assert_ne(action.type, EnemyAIAction.Type.HEAL)


func test_stationary_unit_waits_when_no_player_is_in_its_weapon_range() -> void:
	var enemy := _unit(&"stationary", 4, true, false, 1, 2)
	var player := _player_at(&"distant_player", Vector2i(3, 0))
	_place(enemy, Vector2i.ZERO)
	var action := EnemyAI.new(EnemyAI.Strategy.STATIONARY).take_turn(
			enemy, Vector2i.ZERO, [player], _context)
	assert_eq(action.type, EnemyAIAction.Type.WAIT)


func test_stationary_unit_attacks_a_player_one_tile_away_without_moving() -> void:
	var enemy := _unit(&"stationary", 4)
	var player := _player_at(&"near_player", Vector2i(1, 0))
	_place(enemy, Vector2i.ZERO)
	var action := EnemyAI.new(EnemyAI.Strategy.STATIONARY).take_turn(
			enemy, Vector2i.ZERO, [player], _context)
	assert_eq(action.type, EnemyAIAction.Type.ATTACK)
	assert_eq(action.target, player)
	assert_eq(action.destination, Vector2i.ZERO)


func test_stationary_unit_attacks_a_player_two_tiles_away_without_moving() -> void:
	var enemy := _unit(&"stationary", 4, true, false, 1, 2)
	var player := _player_at(&"far_player", Vector2i(2, 0))
	_place(enemy, Vector2i.ZERO)
	var action := EnemyAI.new(EnemyAI.Strategy.STATIONARY).take_turn(
			enemy, Vector2i.ZERO, [player], _context)
	assert_eq(action.type, EnemyAIAction.Type.ATTACK)
	assert_eq(action.target, player)
	assert_eq(action.destination, Vector2i.ZERO)


func test_defensive_unit_waits_when_no_player_is_in_range() -> void:
	var enemy := _unit(&"defender", 4)
	var player := _player_at(&"distant_player", Vector2i(8, 8))
	_place(enemy, Vector2i.ZERO)
	var action := EnemyAI.new(EnemyAI.Strategy.DEFENSIVE).take_turn(
			enemy, Vector2i.ZERO, [player], _context)
	assert_eq(action.type, EnemyAIAction.Type.WAIT)


func test_single_defensive_unit_stays_defensive_when_no_player_is_in_range() -> void:
	var enemy := _unit(&"defender")
	var ai := EnemyAI.new(EnemyAI.Strategy.DEFENSIVE, &"guard")
	_place(enemy, Vector2i.ZERO)
	EnemyAI.begin_enemy_turn([{"ai": ai, "unit": enemy}], [], _context)
	assert_eq(ai.strategy, EnemyAI.Strategy.DEFENSIVE)


func test_defensive_team_stays_defensive_when_no_player_is_in_either_range() -> void:
	var first := _unit(&"first_defender")
	var second := _unit(&"second_defender")
	var first_ai := EnemyAI.new(EnemyAI.Strategy.DEFENSIVE, &"guard")
	var second_ai := EnemyAI.new(EnemyAI.Strategy.DEFENSIVE, &"guard")
	_place(first, Vector2i.ZERO)
	_place(second, Vector2i(10, 10))
	EnemyAI.begin_enemy_turn([
		{"ai": first_ai, "unit": first},
		{"ai": second_ai, "unit": second},
	], [], _context)
	assert_eq(first_ai.strategy, EnemyAI.Strategy.DEFENSIVE)
	assert_eq(second_ai.strategy, EnemyAI.Strategy.DEFENSIVE)


func test_one_defender_in_range_activates_its_whole_team() -> void:
	var first := _unit(&"first_defender")
	var second := _unit(&"second_defender")
	var first_ai := EnemyAI.new(EnemyAI.Strategy.DEFENSIVE, &"guard")
	var second_ai := EnemyAI.new(EnemyAI.Strategy.DEFENSIVE, &"guard")
	var player := _player_at(&"player", Vector2i(1, 0))
	_place(first, Vector2i.ZERO)
	_place(second, Vector2i(10, 10))
	EnemyAI.begin_enemy_turn([
		{"ai": first_ai, "unit": first},
		{"ai": second_ai, "unit": second},
	], [player], _context)
	assert_eq(first_ai.strategy, EnemyAI.Strategy.AGGRESSIVE)
	assert_eq(second_ai.strategy, EnemyAI.Strategy.AGGRESSIVE)


func test_two_defenders_in_range_activate_their_team() -> void:
	var first := _unit(&"first_defender")
	var second := _unit(&"second_defender")
	var first_ai := EnemyAI.new(EnemyAI.Strategy.DEFENSIVE, &"guard")
	var second_ai := EnemyAI.new(EnemyAI.Strategy.DEFENSIVE, &"guard")
	var first_player := _player_at(&"first_player", Vector2i(1, 0))
	var second_player := _player_at(&"second_player", Vector2i(9, 10))
	_place(first, Vector2i.ZERO)
	_place(second, Vector2i(10, 10))
	EnemyAI.begin_enemy_turn([
		{"ai": first_ai, "unit": first},
		{"ai": second_ai, "unit": second},
	], [first_player, second_player], _context)
	assert_eq(first_ai.strategy, EnemyAI.Strategy.AGGRESSIVE)
	assert_eq(second_ai.strategy, EnemyAI.Strategy.AGGRESSIVE)


func test_aggressive_unit_moves_four_tiles_toward_distant_player() -> void:
	var enemy := _unit(&"aggressive", 4)
	var player := _player_at(&"player", Vector2i.ZERO)
	_place(enemy, Vector2i(8, 0))
	var action := EnemyAI.new(EnemyAI.Strategy.AGGRESSIVE).take_turn(
			enemy, Vector2i(8, 0), [player], _context)
	assert_eq(action.type, EnemyAIAction.Type.MOVE)
	assert_eq(action.destination, Vector2i(4, 0))


func test_aggressive_unit_moves_to_attack_when_player_is_close() -> void:
	var enemy := _unit(&"aggressive", 4)
	var player := _player_at(&"player", Vector2i.ZERO)
	_place(enemy, Vector2i(3, 0))
	var action := EnemyAI.new(EnemyAI.Strategy.AGGRESSIVE).take_turn(
			enemy, Vector2i(3, 0), [player], _context)
	assert_eq(action.type, EnemyAIAction.Type.ATTACK)
	assert_eq(action.target, player)
	assert_true(action.destination in [Vector2i(1, 0), Vector2i(0, 1)])


func test_aggressive_attack_avoids_an_allys_only_attack_cell() -> void:
	var acting_enemy := _unit(&"near_enemy", 3)
	var later_enemy := _unit(&"far_enemy", 4)
	var player := _player_at(&"player", Vector2i.ZERO)
	_place(acting_enemy, Vector2i(0, 2))
	_place(later_enemy, Vector2i(0, 5))
	var action := EnemyAI.new(EnemyAI.Strategy.AGGRESSIVE).take_turn(
			acting_enemy, Vector2i(0, 2), [player], _context, [later_enemy])
	assert_eq(action.type, EnemyAIAction.Type.ATTACK)
	assert_eq(action.target, player)
	assert_eq(action.destination, Vector2i(1, 0))


func test_attack_ranking_prefers_the_only_target_it_can_one_shot() -> void:
	var enemy := _unit(&"attacker", 0)
	_place(enemy, Vector2i(5, 5))
	var players := _four_adjacent_players()
	for player: Unit in players:
		player.take_damage(5)
	_context.combat_results[players[0]] = _result(5, 70)
	_context.combat_results[players[1]] = _result(4, 100)
	_context.combat_results[players[2]] = _result(2, 100)
	_context.combat_results[players[3]] = _result(4, 100)
	var action := _attack(enemy, players, Vector2i(5, 5))
	assert_eq(action.target, players[0])


func test_attack_ranking_prefers_higher_hit_chance_between_one_shots() -> void:
	var enemy := _unit(&"attacker", 0)
	_place(enemy, Vector2i(5, 5))
	var players := _four_adjacent_players()
	for player: Unit in players:
		player.take_damage(5)
	_context.combat_results[players[0]] = _result(5, 70)
	_context.combat_results[players[1]] = _result(5, 90)
	_context.combat_results[players[2]] = _result(1, 100)
	_context.combat_results[players[3]] = _result(2, 100)
	assert_eq(_attack(enemy, players, Vector2i(5, 5)).target, players[1])


func test_attack_ranking_uses_lowest_counter_damage_after_one_shot_hit_tie() -> void:
	var enemy := _unit(&"attacker", 0)
	_place(enemy, Vector2i(5, 5))
	var players := _four_adjacent_players()
	for player: Unit in players:
		player.take_damage(5)
	_context.combat_results[players[0]] = _result(5, 80, 5, 100)
	_context.combat_results[players[1]] = _result(5, 80, 2, 100)
	_context.combat_results[players[2]] = _result(1, 100)
	_context.combat_results[players[3]] = _result(2, 100)
	assert_eq(_attack(enemy, players, Vector2i(5, 5)).target, players[1])


func test_attack_ranking_randomly_selects_between_exact_one_shot_ties() -> void:
	var enemy := _unit(&"attacker", 0)
	_place(enemy, Vector2i(5, 5))
	var players := _four_adjacent_players()
	for player: Unit in players:
		player.take_damage(5)
	_context.combat_results[players[0]] = _result(5, 80, 2, 100)
	_context.combat_results[players[1]] = _result(5, 80, 2, 100)
	_context.combat_results[players[2]] = _result(1, 100)
	_context.combat_results[players[3]] = _result(2, 100)
	for _attempt in 4:
		var target := _attack(enemy, players, Vector2i(5, 5)).target
		assert_true(target in [players[0], players[1]])


func test_attack_ranking_prefers_highest_effective_damage_when_no_target_is_lethal() -> void:
	var enemy := _unit(&"attacker", 0)
	_place(enemy, Vector2i(5, 5))
	var players := _four_adjacent_players()
	_context.combat_results[players[0]] = _result(3, 100)
	_context.combat_results[players[1]] = _result(4, 100)
	_context.combat_results[players[2]] = _result(5, 100)
	_context.combat_results[players[3]] = _result(2, 100)
	assert_eq(_attack(enemy, players, Vector2i(5, 5)).target, players[2])


func test_attack_ranking_uses_lowest_counter_damage_after_effective_damage_tie() -> void:
	var enemy := _unit(&"attacker", 0)
	_place(enemy, Vector2i(5, 5))
	var players := _four_adjacent_players()
	_context.combat_results[players[0]] = _result(5, 80, 4, 100)
	_context.combat_results[players[1]] = _result(4, 100, 1, 100)
	_context.combat_results[players[2]] = _result(3, 100, 0, 0)
	_context.combat_results[players[3]] = _result(2, 100, 0, 0)
	assert_eq(_attack(enemy, players, Vector2i(5, 5)).target, players[1])


func test_five_enemy_turns_heal_kill_focus_and_advance_toward_targets() -> void:
	# Five players occupy separate positions on the test board.
	var players: Array[Unit] = [
		_player_at(&"player_1", Vector2i.ZERO),
		_player_at(&"player_2", Vector2i(4, 4)),
		_player_at(&"player_3", Vector2i(10, 10)),
		_player_at(&"player_4", Vector2i(12, 10)),
		_player_at(&"player_5", Vector2i(18, 18)),
	]

	# Four enemies can reach combat now; the fifth is too far from Player 5.
	var enemies: Array[Unit] = [
		_unit(&"enemy_1", 4, true, true),
		_unit(&"enemy_2", 4),
		_unit(&"enemy_3", 4),
		_unit(&"enemy_4", 4),
		_unit(&"enemy_5", 4),
	]
	var enemy_positions: Array[Vector2i] = [
		Vector2i(1, 1),
		Vector2i(9, 10),
		Vector2i(4, 3),
		Vector2i(3, 4),
		Vector2i(10, 18),
	]
	for index in enemies.size():
		_place(enemies[index], enemy_positions[index])

	# Enemy 1 starts at 1 HP; execute the returned heal action.
	enemies[0].take_damage(9)
	var enemy_ais: Array[EnemyAI] = []
	for _index in enemies.size():
		enemy_ais.append(EnemyAI.new(EnemyAI.Strategy.AGGRESSIVE))
	var heal_action := enemy_ais[0].take_turn(enemies[0], enemy_positions[0], players, _context)
	assert_eq(heal_action.type, EnemyAIAction.Type.HEAL)
	assert_true(enemies[0].use_item(heal_action.inventory_index))
	assert_eq(enemies[0].current_hp, enemies[0].max_hp())

	# Enemy 2 can one-shot Player 3. Apply the guaranteed-hit forecast to model
	# the result before asking the remaining enemies to choose their actions.
	_context.combat_results[players[2]] = _result(10, 100)
	var enemy_2_action := enemy_ais[1].take_turn(enemies[1], enemy_positions[1], players, _context)
	assert_eq(enemy_2_action.type, EnemyAIAction.Type.ATTACK)
	assert_eq(enemy_2_action.target, players[2])
	var enemy_2_result: EnemyAICombatResult = _context.combat_results[enemy_2_action.target]
	players[2].take_damage(enemy_2_result.damage_per_hit * enemy_2_result.attack_count)
	_context.positions[enemies[1]] = enemy_2_action.destination
	assert_false(players[2].is_alive())

	# Enemies 3 and 4 both attack Player 2. Their damage is deliberately
	# non-lethal so the second enemy can still choose the same target.
	_context.combat_results[players[1]] = _result(2, 100)
	var enemy_3_action := enemy_ais[2].take_turn(enemies[2], enemy_positions[2], players, _context)
	assert_eq(enemy_3_action.type, EnemyAIAction.Type.ATTACK)
	assert_eq(enemy_3_action.target, players[1])
	var enemy_3_result: EnemyAICombatResult = _context.combat_results[enemy_3_action.target]
	players[1].take_damage(enemy_3_result.damage_per_hit * enemy_3_result.attack_count)
	_context.positions[enemies[2]] = enemy_3_action.destination

	var enemy_4_action := enemy_ais[3].take_turn(enemies[3], enemy_positions[3], players, _context)
	assert_eq(enemy_4_action.type, EnemyAIAction.Type.ATTACK)
	assert_eq(enemy_4_action.target, players[1])
	var enemy_4_result: EnemyAICombatResult = _context.combat_results[enemy_4_action.target]
	players[1].take_damage(enemy_4_result.damage_per_hit * enemy_4_result.attack_count)
	_context.positions[enemies[3]] = enemy_4_action.destination
	assert_true(players[1].is_alive())

	# Enemy 5 is eight tiles away from Player 5 and can move only four. It moves
	# closer this turn, but cannot reach an attack position yet.
	var enemy_5_action := enemy_ais[4].take_turn(enemies[4], enemy_positions[4], players, _context)
	assert_eq(enemy_5_action.type, EnemyAIAction.Type.MOVE)
	assert_eq(enemy_5_action.destination, Vector2i(14, 18))
	assert_false(_context.can_attack_from(enemies[4], enemy_5_action.destination,
			players[4], _context.unit_position(players[4])))


func _four_adjacent_players() -> Array[Unit]:
	return [
		_player_at(&"player_0", Vector2i(4, 5)),
		_player_at(&"player_1", Vector2i(6, 5)),
		_player_at(&"player_2", Vector2i(5, 4)),
		_player_at(&"player_3", Vector2i(5, 6)),
	]
