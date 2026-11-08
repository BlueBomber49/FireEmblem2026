class_name Experience
extends RefCounted
## FE7 experience and level-ups (docs/fe7-reference.md, "Experience and levels").
## Static helpers: Battle decides who gains EXP after a fight and shows it.

const PER_LEVEL := 100
## A single fight never gives more than a level's worth.
const MAX_GAIN := 100
const KILL_BONUS := 20
const BOSS_BONUS := 40
const THIEF_BONUS := 20
## Classes with this tag give the thief bonus when killed.
const THIEF_TAG := &"thief"


## EXP `me` earns from one fight with `enemy`. `dealt_damage`: one of `me`'s
## strikes hit for more than 0. `killed`: `enemy` fell. `enemy_is_boss`: the
## level's commander.
static func for_fight(me: Unit, enemy: Unit, dealt_damage: bool, killed: bool,
		enemy_is_boss := false, enemy_is_thief := false) -> int:
	if not dealt_damage:
		return 1
	var damage_exp := maxi(1, (31 + enemy.level + _bonus_a(enemy) - me.level - _bonus_a(me))
			/ me.class_data().class_power)
	if not killed:
		return damage_exp
	var kill_base := (enemy.level * enemy.class_data().class_power + _bonus_b(enemy)) \
			- (me.level * me.class_data().class_power + _bonus_b(me))
	var bonus := kill_base + KILL_BONUS \
			+ (BOSS_BONUS if enemy_is_boss else 0) + (THIEF_BONUS if enemy_is_thief else 0)
	return mini(MAX_GAIN, damage_exp + maxi(0, bonus))


static func is_thief(klass: ClassData) -> bool:
	return klass != null and klass.has_tag(THIEF_TAG)


## Adds `amount` EXP to `unit`, levelling up at each 100. Returns one Dictionary
## per level gained (stat -> 1 for each stat that rose), for a level-up display.
## `roll` returns 0-99; a stat rises when it's below the growth rate. At level 20
## EXP stays at 0 and nothing is gained.
static func gain(unit: Unit, amount: int, roll: Callable) -> Array[Dictionary]:
	var gains: Array[Dictionary] = []
	if unit.level >= UnitData.MAX_LEVEL:
		unit.experience = 0
		return gains
	unit.experience += amount
	while unit.experience >= PER_LEVEL and unit.level < UnitData.MAX_LEVEL:
		unit.experience -= PER_LEVEL
		unit.level += 1
		gains.append(_level_up(unit, roll))
	if unit.level >= UnitData.MAX_LEVEL:
		unit.experience = 0
	return gains


## Bonus A and B: what promoted units add to the formulas.
static func _bonus_a(unit: Unit) -> int:
	return 20 if unit.class_data().promoted else 0


static func _bonus_b(unit: Unit) -> int:
	return 60 if unit.class_data().promoted else 0


## Rolls each growing stat once. Movement and constitution don't grow, and no stat
## passes the class cap. An HP rise raises max HP only; current HP stays as it
## was, even for a unit at full HP (20/20 becomes 20/21).
static func _level_up(unit: Unit, roll: Callable) -> Dictionary:
	var up := {}
	var growths := unit.growths()
	var caps := unit.class_data().caps
	for field: StringName in Stats.FIELDS:
		if field == &"movement" or field == &"constitution":
			continue
		var value: int = unit.stats.get(field)
		if roll.call() < int(growths.get(field)) and value < int(caps.get(field)):
			unit.stats.set(field, value + 1)
			up[field] = 1
	return up
