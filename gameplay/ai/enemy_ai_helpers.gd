class_name EnemyAIHelpers
extends RefCounted
## Shared enemy decision calculations. These methods return action plans and do
## not move units, consume items, or apply combat themselves.

const HEAL_THRESHOLD := 0.40


## True when HP is at or below 40% and the unit owns a healing consumable with
## uses remaining.
static func check_heal(unit: Unit) -> bool:
	return healing_item_index(unit) >= 0


## Inventory slot of the first usable healing consumable, or -1 when the unit
## should not heal. The turn planner uses the slot in its HEAL action.
static func healing_item_index(unit: Unit) -> int:
	if unit == null or unit.max_hp() <= 0:
		return -1
	if float(unit.current_hp) / float(unit.max_hp()) > HEAL_THRESHOLD:
		return -1
	for index in unit.inventory.size():
		var entry := unit.inventory.get_item(index)
		if entry != null and entry.is_consumable() and entry.uses_left > 0:
			var consumable := entry.data as ConsumableData
			if consumable.heal_amount == ConsumableData.FULL_HEAL or consumable.heal_amount > 0:
				return index
	return -1


## True if any living player can be attacked from a legal destination this turn.
static func can_attack(unit: Unit, origin: Vector2i, player_units: Array[Unit],
		context: EnemyAIContext, allow_movement: bool = true) -> bool:
	return not _attack_options(unit, origin, player_units, context, allow_movement).is_empty()


## Select the best attack the unit can make now, including a move to an attack
## cell when allowed. Ranking order: likely one-shot (best hit chance), highest
## expected damage dealt, lowest expected counter damage, then random tie-break.
static func attack_best_target(unit: Unit, origin: Vector2i,
		player_units: Array[Unit], context: EnemyAIContext,
		allow_movement: bool = true, allied_units: Array[Unit] = []) -> EnemyAIAction:
	var options := _attack_options(unit, origin, player_units, context, allow_movement)
	if options.is_empty():
		return EnemyAIAction.wait()

	var best_options: Array[Dictionary] = []
	var best_lethal := false
	var best_hit := -1
	var best_dealt := -1.0
	var best_taken := INF
	var best_blocked_attacks := 2147483647

	for option: Dictionary in options:
		var target: Unit = option["target"]
		var result: EnemyAICombatResult = option["result"]
		var lethal := result.can_one_shot(target)
		var dealt := result.effective_damage_dealt()
		var taken := result.effective_damage_taken()
		var blocked_attacks := _blocked_ally_attack_count(unit, option["position"],
				allied_units, player_units, context)
		var is_better := false
		if lethal != best_lethal:
			is_better = lethal
		elif lethal and result.hit_chance != best_hit:
			is_better = result.hit_chance > best_hit
		elif not is_equal_approx(dealt, best_dealt):
			is_better = dealt > best_dealt
		elif not is_equal_approx(taken, best_taken):
			is_better = taken < best_taken
		elif blocked_attacks != best_blocked_attacks:
			is_better = blocked_attacks < best_blocked_attacks

		if is_better:
			best_options.clear()
			best_options.append(option)
			best_lethal = lethal
			best_hit = result.hit_chance
			best_dealt = dealt
			best_taken = taken
			best_blocked_attacks = blocked_attacks
		elif _same_rank(lethal, result.hit_chance, dealt, taken,
				best_lethal, best_hit, best_dealt, best_taken) \
				and blocked_attacks == best_blocked_attacks:
			best_options.append(option)

	var chosen: Dictionary = best_options[randi_range(0, best_options.size() - 1)]
	return EnemyAIAction.attack(chosen["position"], chosen["target"])


## Pick an attack cell if one is available. Otherwise move to a legal, unoccupied
## cell that minimizes Manhattan distance to the nearest living player; preserving
## allied attack cells breaks distance ties, then terrain and a random choice.
static func find_best_target(unit: Unit, origin: Vector2i,
		player_units: Array[Unit], context: EnemyAIContext,
		allied_units: Array[Unit] = []) -> EnemyAIAction:
	var attack_action := attack_best_target(unit, origin, player_units, context, true, allied_units)
	if attack_action.type == EnemyAIAction.Type.ATTACK:
		return attack_action

	var live_players: Array[Unit] = []
	for player: Unit in player_units:
		if player != null and player.is_alive():
			live_players.append(player)
	if live_players.is_empty():
		return EnemyAIAction.wait()

	var candidates: Array[Vector2i] = []
	var best_distance := 2147483647
	var best_blocked_attacks := 2147483647
	var best_terrain := -2147483647
	for cell: Vector2i in context.reachable_positions(unit, origin):
		if cell != origin and context.is_occupied(cell, unit):
			continue
		var nearest_distance := 2147483647
		for player: Unit in live_players:
			var player_position := context.unit_position(player)
			nearest_distance = mini(nearest_distance, _distance(cell, player_position))
		var blocked_attacks := _blocked_ally_attack_count(unit, cell,
				allied_units, live_players, context)
		var terrain := context.terrain_advantage(unit, cell)
		if nearest_distance < best_distance \
				or (nearest_distance == best_distance and blocked_attacks < best_blocked_attacks) \
				or (nearest_distance == best_distance and blocked_attacks == best_blocked_attacks \
				and terrain > best_terrain):
			candidates.clear()
			candidates.append(cell)
			best_distance = nearest_distance
			best_blocked_attacks = blocked_attacks
			best_terrain = terrain
		elif nearest_distance == best_distance \
				and blocked_attacks == best_blocked_attacks and terrain == best_terrain:
			candidates.append(cell)

	if candidates.is_empty():
		return EnemyAIAction.wait()
	var destination := candidates[randi_range(0, candidates.size() - 1)]
	if destination == origin:
		return EnemyAIAction.wait()
	return EnemyAIAction.move(destination)


static func _attack_options(unit: Unit, origin: Vector2i,
		player_units: Array[Unit], context: EnemyAIContext,
		allow_movement: bool) -> Array[Dictionary]:
	var positions: Array[Vector2i] = [origin]
	if allow_movement:
		positions = context.reachable_positions(unit, origin)
		if origin not in positions:
			positions.push_front(origin)
	var options: Array[Dictionary] = []
	for target: Unit in player_units:
		if target == null or not target.is_alive():
			continue
		var target_position := context.unit_position(target)
		for cell: Vector2i in positions:
			if cell != origin and context.is_occupied(cell, unit):
				continue
			if not context.can_attack_from(unit, cell, target, target_position):
				continue
			var result := context.evaluate_combat(unit, cell, target, target_position)
			if result == null:
				continue
			options.append({"target": target, "position": cell, "result": result})
	return options


static func _same_rank(lethal: bool, hit: int, dealt: float, taken: float,
		best_lethal: bool, best_hit: int, best_dealt: float, best_taken: float) -> bool:
	return lethal == best_lethal \
		and (not lethal or hit == best_hit) \
		and is_equal_approx(dealt, best_dealt) \
		and is_equal_approx(taken, best_taken)


## Count allied attacks this move would remove by occupying a cell that is the
## ally's only reachable attack position against a living player. An ally with
## another attack position (including its current cell) is not penalized.
static func _blocked_ally_attack_count(moving_unit: Unit, destination: Vector2i,
		allied_units: Array[Unit], player_units: Array[Unit],
		context: EnemyAIContext) -> int:
	var blocked_count := 0
	for ally: Unit in allied_units:
		if ally == null or ally == moving_unit or not ally.is_alive():
			continue
		var ally_origin := context.unit_position(ally)
		if ally_origin == destination:
			continue
		var ally_positions := context.reachable_positions(ally, ally_origin)
		if ally_origin not in ally_positions:
			ally_positions.push_front(ally_origin)
		if destination not in ally_positions:
			continue
		for player: Unit in player_units:
			if player == null or not player.is_alive():
				continue
			var player_position := context.unit_position(player)
			if not context.can_attack_from(ally, destination, player, player_position):
				continue
			var has_alternative := false
			for ally_position: Vector2i in ally_positions:
				if ally_position == destination:
					continue
				if context.can_attack_from(ally, ally_position, player, player_position):
					has_alternative = true
					break
			if not has_alternative:
				blocked_count += 1
	return blocked_count


static func _distance(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)
