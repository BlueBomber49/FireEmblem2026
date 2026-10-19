class_name Combat
extends RefCounted
## Combat rules from the FE7 formulas in docs/fe7-reference.md: the forecast
## numbers and the strike-by-strike result of a fight. Nothing here changes a
## unit; Battle applies and shows the strikes.

## Stand-in for a weapon until level units carry items. Values are an Iron Sword.
const PLACEHOLDER_MIGHT := 5
const PLACEHOLDER_HIT := 90
const PLACEHOLDER_CRIT := 0
const PLACEHOLDER_WEIGHT := 5
## A unit strikes twice when its attack speed beats the enemy's by this much.
const DOUBLE_THRESHOLD := 4

const CRIT_MULTIPLIER := 3

const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


## One swing in a fight and what it did.
class Strike:
	extends RefCounted
	var attacker: LevelUnitState
	var defender: LevelUnitState
	var hit := false
	var crit := false
	## Damage dealt; 0 on a miss.
	var damage := 0
	## The defender's HP once this strike has landed.
	var hp_after := 0


## [attacker side, defender side] for the CombatForecast. No weapon triangle,
## effectiveness or terrain yet, so those terms are 0.
static func forecast(attacker: LevelUnitState, defender: LevelUnitState,
		defender_can_counter: bool) -> Array[ForecastSide]:
	var attacker_side := _side(attacker, defender)
	var defender_side := _side(defender, attacker)
	defender_side.can_counter = defender_can_counter
	return [attacker_side, defender_side]


## The strikes of a fight in FE order: attacker, then the defender's counter
## if it can, then the second strike of whichever side doubles. Stops when a
## side reaches 0 HP. `roll` returns an int in 0-99; pass a seeded or scripted
## one. Unit states are read, never written.
static func resolve(attacker: LevelUnitState, defender: LevelUnitState,
		defender_can_counter: bool, roll: Callable) -> Array[Strike]:
	var sides := forecast(attacker, defender, defender_can_counter)
	var order: Array = [[attacker, defender, sides[0]]]
	if defender_can_counter:
		order.append([defender, attacker, sides[1]])
	if sides[0].attack_count > 1:
		order.append([attacker, defender, sides[0]])
	elif defender_can_counter and sides[1].attack_count > 1:
		order.append([defender, attacker, sides[1]])

	var hp := {attacker: attacker.current_hp, defender: defender.current_hp}
	var strikes: Array[Strike] = []
	for entry in order:
		var strike := Strike.new()
		strike.attacker = entry[0]
		strike.defender = entry[1]
		var side: ForecastSide = entry[2]
		strike.hit = true_hit(side.hit, roll)
		if strike.hit:
			strike.crit = int(roll.call()) < side.crit
			strike.damage = side.damage * (CRIT_MULTIPLIER if strike.crit else 1)
		hp[strike.defender] = maxi(0, hp[strike.defender] - strike.damage)
		strike.hp_after = hp[strike.defender]
		strikes.append(strike)
		if strike.hp_after == 0:
			break
	return strikes


## FE7 "true hit": the average of two rolls must be below the displayed hit.
static func true_hit(displayed_hit: int, roll: Callable) -> bool:
	var average := (int(roll.call()) + int(roll.call())) / 2.0
	return average < displayed_hit


## Alive units in the four cells around `unit` that it is hostile to, clockwise from above.
static func adjacent_hostiles(unit: LevelUnitState, level_state: LevelState) -> Array[LevelUnitState]:
	var found: Array[LevelUnitState] = []
	for offset in NEIGHBOURS:
		var cell := unit.cell + offset
		for other: LevelUnitState in level_state.level_units.values():
			if other != unit and other.is_alive() and other.cell == cell \
					and UnitReference.are_hostile(unit.unit_ref, other.unit_ref):
				found.append(other)
	return found


static func attack_speed(unit: LevelUnitState) -> int:
	return unit.unit_ref.stat(&"spd") - maxi(0, PLACEHOLDER_WEIGHT - unit.unit_ref.stat(&"con"))


static func _side(unit: LevelUnitState, enemy: LevelUnitState) -> ForecastSide:
	var me := unit.unit_ref
	var them := enemy.unit_ref
	var my_speed := attack_speed(unit)
	var their_speed := attack_speed(enemy)

	var side := ForecastSide.new()
	side.unit_name = me.name
	side.weapon_name = "--"
	side.hp = unit.current_hp
	side.damage = maxi(0, me.stat(&"str") + PLACEHOLDER_MIGHT - them.stat(&"def"))
	var accuracy := PLACEHOLDER_HIT + 2 * me.stat(&"skl") + floori(me.stat(&"lck") / 2.0)
	var avoid := 2 * their_speed + them.stat(&"lck")
	side.hit = clampi(accuracy - avoid, 0, 100)
	var critical := PLACEHOLDER_CRIT + floori(me.stat(&"skl") / 2.0)
	side.crit = clampi(critical - them.stat(&"lck"), 0, 100)
	side.attack_count = 2 if my_speed - their_speed >= DOUBLE_THRESHOLD else 1
	side.advantage = 0
	return side
