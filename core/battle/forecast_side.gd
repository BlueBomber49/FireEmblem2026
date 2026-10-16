class_name ForecastSide
extends RefCounted
## One side of a combat forecast. Combat logic fills this in; the UI only reads it.
##
## [CombatForecast] takes one of these for the player and one for the enemy.

var unit_name: String = ""
var weapon_name: String = ""
var hp: int = 0
## False when this side can't fight back (out of range, no weapon). Damage, hit
## and crit then show "--".
var can_counter: bool = true
## Damage per hit.
var damage: int = 0
## Hit chance, in percent.
var hit: int = 0
## Crit chance, in percent.
var crit: int = 0
## Hits per combat: 2 when doubling, 4 for a doubling brave weapon.
var attack_count: int = 1
## Weapon triangle: 1 advantage, 0 neutral, -1 disadvantage.
var advantage: int = 0


## A side with the parts that come straight from [param unit]: name, weapon and
## current HP. Combat logic still fills in damage, hit, crit, attack count and
## advantage. A unit with no usable weapon can't counter.
static func from_unit(unit: Unit) -> ForecastSide:
	var side := ForecastSide.new()
	side.unit_name = unit.data.display_name
	side.hp = unit.current_hp
	var weapon := unit.equipped_weapon()
	if weapon == null:
		side.weapon_name = "--"
		side.can_counter = false
	else:
		side.weapon_name = weapon.display_name
	return side
