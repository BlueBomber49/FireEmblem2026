# Enemy AI: implementation and integration guide

This document describes the current rules-only enemy AI, the tests that cover it, and the game systems still needed to use it in a complete battle turn.

## Files added

### `core/ai/enemy_ai.gd`

Defines one AI controller per enemy. Its strategy is runtime state; board position remains outside `Unit`.

- `Strategy`: `STATIONARY`, `DEFENSIVE`, and `AGGRESSIVE` strategy values.
- `_init(p_strategy, p_defensive_team_id)`: initializes the strategy and optional defensive-team ID. Strategy defaults to aggressive.
- `begin_enemy_turn(team_members, player_units, context)`: checks defensive teams before their turn. `team_members` is an array of dictionaries containing `{"ai": EnemyAI, "unit": Unit}`. If any living member can attack a player, all living defensive members with that non-empty team ID switch to aggressive. The caller must invoke this once at the start of the enemy phase.
- `take_turn(unit, position, player_units, context, allied_units)`: returns an `EnemyAIAction`. Healing is considered first for every strategy. Stationary enemies can only attack from their current position. Defensive enemies otherwise wait. Aggressive enemies attack if possible, or ask the helper to select a destination. `allied_units` should contain living allies that have not acted yet so the helper can avoid blocking their only attack cells.

### `core/ai/enemy_ai_helpers.gd`

Contains shared decision calculations. These methods choose actions but do not move units, use items, or apply combat.

- `check_heal(unit)`: reports whether HP is at or below 40% of maximum and the unit has a usable healing consumable.
- `HEAL_THRESHOLD`: the 0.40 health fraction used by `check_heal()`.
- `healing_item_index(unit)`: returns the first usable healing-item inventory index, or `-1` if the unit should not heal.
- `can_attack(unit, origin, player_units, context, allow_movement)`: checks whether any living player can be attacked from the current cell or a reachable cell. Set `allow_movement` to false for stationary enemies.
- `attack_best_target(unit, origin, player_units, context, allow_movement, allied_units)`: evaluates possible attacks and returns an attack plan for the best target and destination. Ranking is one-shot first, then hit chance among one-shot choices, expected damage dealt, lowest expected counter damage, and finally ally-cell preservation. Remaining equal options are chosen randomly.
- `find_best_target(unit, origin, player_units, context, allied_units)`: uses an attack plan if one is available; otherwise chooses a reachable, unoccupied cell closest to the nearest living player. Equal-distance options preserve allied attack cells, then prefer terrain, then use a random tie-break. Returns `WAIT` if there are no living players or legal destinations.
- `_attack_options(...)`: gathers every valid target/destination pair and asks the context for its combat result.
- `_same_rank(...)`: compares the combat-ranking values used to retain tied attack options.
- `_blocked_ally_attack_count(...)`: counts attacks that would be lost if the moving enemy occupied a cell that an ally can reach and that is the ally's only cell for attacking a living player.
- `_distance(first, second)`: returns Manhattan distance between two grid coordinates.

### `core/ai/enemy_ai_action.gd`

Represents a planned action for another system to execute.

- `Type`: `WAIT`, `HEAL`, `MOVE`, or `ATTACK`.
- `type`: action kind; defaults to `WAIT`.
- `destination`: destination for a move or attack. For an attack this can be the current cell or a cell to move to before attacking.
- `target`: the player unit to attack, when the action is `ATTACK`.
- `inventory_index`: healing item slot, when the action is `HEAL`.
- `wait()`, `heal(item_index)`, `move(to)`, `attack(to, victim)`: factory methods that create an action with the corresponding fields set.

### `core/ai/enemy_ai_combat_result.gd`

Carries combat estimates that the AI uses to rank an attack. Damage values are per hit; attack counts represent the number of strikes.

- `damage_per_hit`, `hit_chance`, `attack_count`: the enemy's attack forecast.
- `can_counter`, `counter_damage_per_hit`, `counter_hit_chance`, `counter_attack_count`: the player's counterattack forecast.
- `effective_damage_dealt()`: expected enemy damage, calculated as damage per hit × strike count × hit chance.
- `effective_damage_taken()`: expected counter damage, or zero if the target cannot counter.
- `can_one_shot(target)`: true when the enemy's forecast damage across its strikes is at least the target's current HP and hit chance is at least 50%.

### `core/ai/enemy_ai_context.gd`

Defines the adapter interface between AI rules and the future map/combat implementation. Its default methods report errors (except `terrain_advantage`, which defaults to zero); the gameplay project needs a concrete subclass.

- `unit_position(unit)`: returns the unit's current board coordinate.
- `reachable_positions(unit, from)`: returns legal move destinations, including the current cell.
- `can_attack_from(attacker, attacker_position, target, target_position)`: checks attack range and map-specific restrictions.
- `evaluate_combat(attacker, attacker_position, target, target_position)`: returns an `EnemyAICombatResult`, or `null` if combat cannot be evaluated.
- `is_occupied(position, except_unit)`: reports whether another living unit occupies a cell.
- `terrain_advantage(unit, position)`: returns a numeric terrain preference; higher values are preferred when movement choices are otherwise tied.

Godot also maintains `.gd.uid` sidecar files for scripts. They store editor resource identifiers; they do not contain AI behavior and should normally be left to Godot to generate or maintain.

### `tests/core/ai/test_enemy_ai.gd`

Contains 24 GUT tests. Its nested `FakeContext` implements the AI context with a small grid, Manhattan movement and weapon range, occupancy checks, and test-supplied combat forecasts.

`FakeContext` methods:

- `unit_position(unit)`: reads a unit's test coordinate from the positions dictionary.
- `reachable_positions(unit, from)`: creates unoccupied cells inside the unit's Manhattan movement allowance and the fake board bounds.
- `can_attack_from(...)`: checks the equipped weapon's min/max range using Manhattan distance.
- `evaluate_combat(...)`: returns a forecast registered for the target, or a simple default forecast.
- `is_occupied(position, except_unit)`: checks other living placed units.
- `terrain_advantage(...)`: returns zero so terrain does not affect movement tests.
- `_distance(a, b)`: shared Manhattan distance calculation for the fake context.

Test-file setup/helper methods:

- `before_each()`: gives each test a fresh fake context.
- `_stats(hp, movement)`: creates the small stats resources used in the test units.
- `_weapon(min_range, max_range)`: creates a sword resource with configurable range.
- `_vulnerary()`: creates a test healing consumable.
- `_unit(...)`: builds a unit with a fresh class and optional weapon/healing item.
- `_place(unit, position)`: records a unit's fake board position.
- `_player_at(unit_id, position)`: creates and places a player unit.
- `_result(damage, hit, counter_damage, counter_hit)`: creates a combat forecast for target ranking.
- `_attack(unit, players, origin, allies)`: calls `EnemyAIHelpers.attack_best_target()` with the fake context and no movement.
- `_four_adjacent_players()`: creates four players around an attacker for target-ranking cases.
- `STRATEGIES`: the three strategies used by the parameterized decision checks.

## Tests added and what they cover

### Creation and healing

- `test_enemy_ai_is_created_with_the_requested_strategy`: checks that each of the three strategies is stored on creation.
- `test_enemy_ai_retains_its_defensive_team_id`: checks the optional team ID.
- `test_low_hp_unit_with_healing_item_plans_to_heal_for_each_strategy`: checks the healing action and item slot at 1/10 HP for all strategies.
- `test_low_hp_unit_without_healing_item_does_not_plan_to_heal_for_each_strategy`: no healing action at 1/10 HP without an item.
- `test_full_hp_unit_with_healing_item_does_not_plan_to_heal_for_each_strategy`: no healing action at full HP with an item.
- `test_full_hp_unit_without_healing_item_does_not_plan_to_heal_for_each_strategy`: no healing action at full HP without an item.

### Strategy decisions and movement

- `test_stationary_unit_waits_when_no_player_is_in_its_weapon_range`: waits when no player is in its weapon's 1–2 tile range.
- `test_stationary_unit_attacks_a_player_one_tile_away_without_moving`: attacks at range 1 and keeps its current destination.
- `test_stationary_unit_attacks_a_player_two_tiles_away_without_moving`: attacks at range 2 and keeps its current destination.
- `test_defensive_unit_waits_when_no_player_is_in_range`: returns `WAIT` while still defensive.
- `test_single_defensive_unit_stays_defensive_when_no_player_is_in_range`: a team with no target stays defensive.
- `test_defensive_team_stays_defensive_when_no_player_is_in_either_range`: neither member activates without a target.
- `test_one_defender_in_range_activates_its_whole_team`: one member's attack opportunity switches the whole team to aggressive.
- `test_two_defenders_in_range_activate_their_team`: verifies team activation when both members can attack.
- `test_aggressive_unit_moves_four_tiles_toward_distant_player`: moves from `(8, 0)` to `(4, 0)` toward a distant target.
- `test_aggressive_unit_moves_to_attack_when_player_is_close`: moves into range and returns an attack against the nearby player.
- `test_aggressive_attack_avoids_an_allys_only_attack_cell`: preserves the farther ally's only attack tile when the acting enemy has another equal attack position.

### Attack target ranking

- `test_attack_ranking_prefers_the_only_target_it_can_one_shot`: selects the only lethal target even when another target has higher expected damage.
- `test_attack_ranking_prefers_higher_hit_chance_between_one_shots`: selects the more reliable of two lethal attacks.
- `test_attack_ranking_uses_lowest_counter_damage_after_one_shot_hit_tie`: after lethal chance and hit chance tie, prefers the lower expected counter damage.
- `test_attack_ranking_randomly_selects_between_exact_one_shot_ties`: calls the selector four times and verifies only the equally ranked best targets are selected.
- `test_attack_ranking_prefers_highest_effective_damage_when_no_target_is_lethal`: selects the highest expected damage when no target can be defeated in one attack.
- `test_attack_ranking_uses_lowest_counter_damage_after_effective_damage_tie`: prefers lower expected counter damage after expected damage dealt ties.

### Five-player/five-enemy scenario

- `test_five_enemy_turns_heal_kill_focus_and_advance_toward_targets`: sets up five players and five enemies. It checks that Enemy 1 heals, Enemy 2 attacks and kills Player 3 using the supplied guaranteed-hit forecast, Enemies 3 and 4 both attack Player 2 without killing them, and Enemy 5 moves to `(14, 18)` toward Player 5 but remains outside attack range. The test manually applies healing, damage, and attack movement to model the battle controller between AI decisions.

The full suite was run with Godot 4.6.3 and GUT after these tests were added: **215 tests passed, zero failed**.

## Work needed to use the AI in a gameplay loop

The AI returns decisions. It does not own the board or execute its actions. These systems are still needed.

### 1. Board state and terrain rules

Add a rules-side board model, for example `core/maps/battle_board.gd`, to store each living unit's grid coordinate and answer occupancy/terrain queries. `Unit` intentionally has no position field.

Methods this board or a related map-rules class will need:

- `unit_position(unit)` and `set_unit_position(unit, cell)`.
- `unit_at(cell)` / `is_occupied(cell, except_unit)`.
- `terrain_at(cell)` returning `TerrainInfo` or a richer terrain resource.
- A way to enumerate player and enemy units that are alive and currently on the map.

Add map content and movement rules as needed. `TerrainInfo` currently contains display values such as defense, avoid, healing percentage, and a movement cost, but there is no authored battle map or terrain lookup system yet. Movement should use each unit class's `movement_type`, its movement allowance, terrain costs, impassable cells, and other occupied cells.

### 2. Reachability and attack-range queries

Add movement/pathfinding logic, for example `core/maps/movement_rules.gd`, to calculate legal destinations. It should provide the concrete logic used by `EnemyAIContext.reachable_positions()` and avoid treating Manhattan distance alone as pathfinding when terrain costs or walls matter.

The context implementation must also provide:

- `unit_position()` from board state.
- `reachable_positions()` from movement rules and current occupancy.
- `is_occupied()` from the board.
- `can_attack_from()` using the equipped usable weapon, its `min_range`/`max_range`, and any map rules such as line of sight.
- `terrain_advantage()` using the destination terrain's defensive/avoid values or another agreed score.

A concrete context can live in the map/battle layer, such as `scenes/maps/enemy_ai_context.gd`, if it has to talk to active scene nodes. Keep rule calculations in `core/` where possible, following the repository's architecture rule.

### 3. Combat forecasting and resolution

Add a combat calculator, for example `core/battle/combat_calculator.gd`, and use it both for the AI forecast and actual combat. The calculator must return damage, hit chance, strike count, counter ability, counter damage, and counter hit chance in `EnemyAICombatResult` format. It should account for weapons, unit stats, weapon triangle, class bonuses, terrain, and any other combat rules the game adopts.

Add or extend a combat resolver to roll hit/critical outcomes, apply damage through `Unit.take_damage()`, handle counterattacks and defeat, and return a combat result to the battle controller. Using the same calculation rules for forecast and resolution avoids the AI ranking attacks using numbers different from the fight itself.

### 4. Enemy turn controller and action execution

Add a battle controller, for example `scenes/battle/enemy_turn_controller.gd`, that:

1. Collects active enemy AIs, their units, and player units.
2. Calls `EnemyAI.begin_enemy_turn()` once before enemies act, passing defensive-team records as `{"ai": ai, "unit": unit}`.
3. Chooses an order for enemies and calls `take_turn()` for each living enemy.
4. Passes the living allies that have not acted yet into `take_turn()` so ally-aware tile selection can work.
5. Executes the returned `EnemyAIAction` and updates the board before planning the next enemy.
6. Ends each unit's action and the enemy phase using the battle's turn-state system.

Action execution needs a defined behavior for each action type:

- `WAIT`: mark the enemy as finished for this turn.
- `HEAL`: validate the inventory slot, call `Unit.use_item(inventory_index)`, and mark the enemy as finished.
- `MOVE`: validate/recheck the destination, update board occupancy and unit position, play movement animation if desired, and mark the enemy as finished.
- `ATTACK`: move to `destination` if needed, resolve combat against `target`, update board state if either unit is defeated, and mark the enemy as finished.

If movement and animation are asynchronous, the controller should wait for movement to finish before resolving an attack or planning the next unit. If the action can become invalid because the board changed, execution should handle that case safely.

### 5. Enemy configuration and visual actors

Each enemy placed in a chapter needs an `EnemyAI` instance initialized with its strategy and, for defensive enemies, a shared non-empty team ID. At present, strategy is not a field on `UnitData`; decide whether to add an AI configuration resource/field to spawn data or construct each AI in the chapter setup code.

The project also needs a scene-side representation for map units, likely under `scenes/units/`, to display each `Unit` at the board coordinate and animate movement/attacks. Keep that visual actor synchronized with the rules-side board state rather than making it the only source of game position.

## What still needs testing

The current tests validate the AI against a deliberately simple fake context. They don't validate an actual map, movement rules, terrain costs, combat formulas, animations, or a live enemy phase. Add tests as those systems are implemented.

### AI behavior edge cases

- Healing exactly at 40%, no heal above 40%, depleted healing items, and choosing among multiple healing items.
- Invalid/dead enemy input and behavior when there are no living players.
- Defensive enemies without a team ID, separate teams, mixed strategies in a team, dead team members, and whether activation should persist across later phases.
- Attack range boundaries, units blocked by occupancy, no reachable attack cells, and no usable weapon.
- One-shot hit chance exactly 50%, multiple strikes, no-counter targets, weapon ranges greater than one, and ties at each ranking tier.
- Ally-cell preservation when an ally has alternate attack cells, when the candidate is not reachable to the ally, when several allies depend on the same cell, and when the ally has already acted.
- Terrain tie-breaking, equal random movement choices, and move selection when no progress is possible.
- The existing exact-tie test checks that selected targets belong to the tied best set; a separate seeded-random test could verify reproducible tie behavior if deterministic randomness is desired.

### Tests for future gameplay files

- `battle_board.gd`: position changes, occupancy, defeat removal, and terrain lookup.
- `movement_rules.gd`: movement allowance, weighted terrain, impassable cells, occupied cells, and reachability around obstacles.
- Concrete `EnemyAIContext`: position, attack range, combat forecast integration, and terrain preference.
- `combat_calculator.gd` / combat resolver: forecast and resolved damage agreement, hit/miss, criticals, counterattacks, and defeats.
- Enemy turn controller: team activation runs once at phase start; every enemy acts at most once; each action type is executed; positions and HP are updated before the next AI decision; invalidated plans are handled; and the phase ends when all enemies finish.
- Unit/map actor scenes: visual positions match board positions after a move, attack move, defeat, and turn transition.

## Running the tests

From the project root, after Godot has imported the project, the full GUT command is:

```sh
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

The project README describes the import step for a fresh clone or after adding scripts with a new `class_name`.
