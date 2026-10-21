class_name Combat
extends RefCounted
## Combat rules from the FE7 formulas in docs/fe7-reference.md: the forecast
## numbers and the strike-by-strike result of a fight, using each unit's equipped
## weapon. Nothing here changes a unit; Battle applies and shows the strikes.
##
## Each formula is its own small function, so a rule can be tuned or swapped
## without touching the rest.

## A unit strikes twice when its attack speed beats the enemy's by this much.
const DOUBLE_THRESHOLD := 4
const CRIT_MULTIPLIER := 3
## Might is multiplied by this against a target the weapon is effective against.
const EFFECTIVE_MULTIPLIER := 2
## Weapon triangle: damage and hit bonus with advantage (the reverse at disadvantage).
const TRIANGLE_DAMAGE := 1
const TRIANGLE_HIT := 15
## Who beats whom: physical swords > axes > lances > swords; magic anima > light > dark > anima.
const TRIANGLE_BEATS := {
	Enums.WeaponType.SWORD: Enums.WeaponType.AXE,
	Enums.WeaponType.AXE: Enums.WeaponType.LANCE,
	Enums.WeaponType.LANCE: Enums.WeaponType.SWORD,
	Enums.WeaponType.ANIMA: Enums.WeaponType.LIGHT,
	Enums.WeaponType.LIGHT: Enums.WeaponType.DARK,
	Enums.WeaponType.DARK: Enums.WeaponType.ANIMA,
}


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


# --- Fights ----------------------------------------------------------------------


## [attacker side, defender side] for the CombatForecast. The defender's
## can_counter says whether its weapon reaches the attacker.
static func forecast(attacker: LevelUnitState, defender: LevelUnitState,
		level_state: LevelState) -> Array[ForecastSide]:
	var gap := distance(attacker, defender)
	var attacker_side := _side(attacker, defender, level_state)
	var defender_side := _side(defender, attacker, level_state)
	defender_side.can_counter = can_strike(defender.unit, gap)
	return [attacker_side, defender_side]


## The strikes of a fight in FE order: attacker, then the defender's counter if
## its weapon reaches, then the second strike of whichever side doubles. Stops
## when a side reaches 0 HP. `roll` returns an int in 0-99; pass a seeded or
## scripted one. Unit states are read, never written.
static func resolve(attacker: LevelUnitState, defender: LevelUnitState,
		level_state: LevelState, roll: Callable) -> Array[Strike]:
	var strikes: Array[Strike] = []
	if attacker.unit.equipped_weapon() == null:
		return strikes
	var sides := forecast(attacker, defender, level_state)
	var counters := sides[1].can_counter
	var order: Array = [[attacker, defender, sides[0]]]
	if counters:
		order.append([defender, attacker, sides[1]])
	if sides[0].attack_count > 1:
		order.append([attacker, defender, sides[0]])
	elif counters and sides[1].attack_count > 1:
		order.append([defender, attacker, sides[1]])

	var hp := {attacker: attacker.current_hp, defender: defender.current_hp}
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


# --- Range -----------------------------------------------------------------------


## Alive units hostile to `unit` that its equipped weapon reaches from where it
## stands: nearest first, then clockwise from above. Empty without a weapon.
static func hostiles_in_range(unit: LevelUnitState, level_state: LevelState) -> Array[LevelUnitState]:
	var found: Array[LevelUnitState] = []
	if unit.unit.equipped_weapon() == null:
		return found
	for other: LevelUnitState in level_state.level_units.values():
		if other != unit and other.is_alive() \
				and UnitReference.are_hostile(unit.unit_ref, other.unit_ref) \
				and can_strike(unit.unit, distance(unit, other)):
			found.append(other)
	found.sort_custom(func(a: LevelUnitState, b: LevelUnitState) -> bool:
		var da := distance(unit, a)
		var db := distance(unit, b)
		if da != db:
			return da < db
		return _clockwise_from_above(a.cell - unit.cell) < _clockwise_from_above(b.cell - unit.cell))
	return found


## Whether `unit`'s equipped weapon reaches `gap` tiles.
static func can_strike(unit: Unit, gap: int) -> bool:
	var weapon := unit.equipped_weapon()
	return weapon != null and weapon.in_range(gap)


## Grid (Manhattan) distance between two units.
static func distance(a: LevelUnitState, b: LevelUnitState) -> int:
	var d := (a.cell - b.cell).abs()
	return d.x + d.y


## Angle of `offset` measured clockwise from straight up, in [0, TAU).
static func _clockwise_from_above(offset: Vector2i) -> float:
	return fposmod(atan2(offset.x, -offset.y), TAU)


# --- Formulas (FE7) ----------------------------------------------------------------


## Speed, minus how far the weapon's weight exceeds Con.
static func attack_speed(unit: Unit) -> int:
	var weapon := unit.equipped_weapon()
	var weight := weapon.weight if weapon != null else 0
	return unit.stats.speed - maxi(0, weight - unit.stats.constitution)


## +1 when `weapon` beats `other` in the triangle, -1 when it loses, else 0.
static func triangle(weapon: WeaponData, other: WeaponData) -> int:
	if weapon == null or other == null:
		return 0
	if TRIANGLE_BEATS.get(weapon.weapon_type, -1) == other.weapon_type:
		return 1
	if TRIANGLE_BEATS.get(other.weapon_type, -1) == weapon.weapon_type:
		return -1
	return 0


## Str (or Mag for magic) + (Might + triangle) x effectiveness.
static func attack_power(unit: Unit, target: Unit) -> int:
	var weapon := unit.equipped_weapon()
	var base := unit.stats.magic if weapon.is_magic() else unit.stats.strength
	var might := weapon.might + triangle(weapon, target.equipped_weapon()) * TRIANGLE_DAMAGE
	var effective := EFFECTIVE_MULTIPLIER if weapon.is_effective_against(target.class_data().tags) else 1
	return base + might * effective


## Def (or Res against magic) plus the terrain under the target.
static func defense(target: Unit, attacker_weapon: WeaponData, terrain: TerrainData) -> int:
	var base := target.stats.resistance if attacker_weapon.is_magic() else target.stats.defense
	return base + (terrain.defense if _gets_terrain_bonus(target, terrain) else 0)


## Weapon hit + 2 x Skl + Lck / 2 + triangle.
static func accuracy(unit: Unit, target: Unit) -> int:
	var weapon := unit.equipped_weapon()
	return weapon.hit + 2 * unit.stats.skill + floori(unit.stats.luck / 2.0) \
			+ triangle(weapon, target.equipped_weapon()) * TRIANGLE_HIT


## 2 x attack speed + Lck, plus the terrain the unit stands on.
static func avoid(unit: Unit, terrain: TerrainData) -> int:
	var terrain_avoid := terrain.avoid if _gets_terrain_bonus(unit, terrain) else 0
	return 2 * attack_speed(unit) + unit.stats.luck + terrain_avoid


## Weapon crit + Skl / 2 + the class's crit bonus.
static func crit_rate(unit: Unit) -> int:
	return unit.equipped_weapon().crit + floori(unit.stats.skill / 2.0) + unit.class_data().crit_bonus


static func crit_avoid(unit: Unit) -> int:
	return unit.stats.luck


## Fliers get no terrain defense or avoid (FE7).
static func _gets_terrain_bonus(unit: Unit, terrain: TerrainData) -> bool:
	return terrain != null and unit.class_data().movement_type != Enums.MovementType.FLIER


## The terrain rules for the cell `unit` stands on, or null for none.
static func terrain_under(unit: LevelUnitState, level_state: LevelState) -> TerrainData:
	return GameData.terrain_for_tile(level_state.map_data.rules_terrain_at(unit.cell))


## One side's numbers when `me` strikes `them`, each standing on its own cell.
static func _side(me: LevelUnitState, them: LevelUnitState, level_state: LevelState) -> ForecastSide:
	var side := ForecastSide.from_unit(me.unit)
	var weapon := me.unit.equipped_weapon()
	if weapon == null:
		side.attack_count = 0
		return side
	var their_terrain := terrain_under(them, level_state)
	side.damage = maxi(0, attack_power(me.unit, them.unit) - defense(them.unit, weapon, their_terrain))
	side.hit = clampi(accuracy(me.unit, them.unit) - avoid(them.unit, their_terrain), 0, 100)
	side.crit = clampi(crit_rate(me.unit) - crit_avoid(them.unit), 0, 100)
	side.attack_count = 2 if attack_speed(me.unit) - attack_speed(them.unit) >= DOUBLE_THRESHOLD else 1
	side.advantage = triangle(weapon, them.unit.equipped_weapon())
	return side
