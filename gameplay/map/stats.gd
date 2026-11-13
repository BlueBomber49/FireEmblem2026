class_name Stats
extends Resource
## A block of the ten unit stats.
##
## Used for a class's base stats, growth rates (as percentages) and stat caps,
## for a character's starting stats, and for a unit's current stats.
## Every method returns a new Stats; none of them change this one, because
## loaded resources are shared by every unit that uses them.

## The stat names, in display order.
const FIELDS: Array[StringName] = [
	&"hp", &"strength", &"magic", &"skill", &"speed",
	&"luck", &"defense", &"resistance", &"constitution", &"movement",
]

## Maximum HP.
@export var hp := 0
@export var strength := 0
@export var magic := 0
@export var skill := 0
@export var speed := 0
@export var luck := 0
@export var defense := 0
@export var resistance := 0
@export var constitution := 0
@export var movement := 0


## Field-by-field sum. A null `other` counts as all zeros.
func plus(other: Stats) -> Stats:
	var result := copy()
	if other == null:
		return result
	for field in FIELDS:
		result.set(field, int(get(field)) + int(other.get(field)))
	return result


## Each field limited to 0 through the matching field of `caps`.
## A null `caps` only raises negative values to 0.
func clamped(caps: Stats) -> Stats:
	var result := Stats.new()
	for field in FIELDS:
		var value: int = maxi(int(get(field)), 0)
		if caps != null:
			value = mini(value, int(caps.get(field)))
		result.set(field, value)
	return result


func copy() -> Stats:
	var result := Stats.new()
	for field in FIELDS:
		result.set(field, get(field))
	return result


## {"hp": 17, "strength": 5, ...} for saving.
func to_dict() -> Dictionary:
	var d := {}
	for field in FIELDS:
		d[String(field)] = get(field)
	return d


## Stats read from save data. Each missing or non-numeric stat, or the whole block
## when `d` isn't a Dictionary, uses `fallback`'s value. Unknown keys are ignored.
static func from_dict(d: Variant, fallback: Stats) -> Stats:
	var result := fallback.copy()
	if not d is Dictionary:
		push_warning("Save data: stats aren't a dictionary; using defaults.")
		return result
	for field in FIELDS:
		result.set(field, SaveUtil.read_int(d, String(field), int(fallback.get(field))))
	return result


func equals(other: Stats) -> bool:
	if other == null:
		return false
	for field in FIELDS:
		if get(field) != other.get(field):
			return false
	return true
