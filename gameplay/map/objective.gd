class_name Objective
extends RefCounted
## How a level ends: lists of win and lose conditions, read from the level
## file's "objective". The level is won when any win condition holds and lost
## when any lose condition holds; losing is checked first, so a lord falling in
## the same fight as the last enemy is still a defeat.
##
## Left out of the file, it's the classic rout: win when every enemy is
## defeated, lose when every player unit is. See docs/data-format.md.

enum Outcome { NONE, WON, LOST }


## One thing that can end a level. Built from {"type": ..., ...} by fromJson.
class Condition:
	extends RefCounted

	func is_met(_state: LevelState) -> bool:
		return false

	## Problems with this condition in `state` (e.g. a unit id that isn't there).
	func validate(_state: LevelState) -> PackedStringArray:
		return PackedStringArray()

	func toJson() -> Dictionary:
		return {}


## Every unit of one faction is defeated.
class FactionDefeated:
	extends Condition
	var faction: UnitReference.Faction

	func _init(p_faction: UnitReference.Faction) -> void:
		faction = p_faction

	func is_met(state: LevelState) -> bool:
		for value: Variant in state.level_units.values():
			var unit := value as LevelUnitState
			if unit != null and unit.unit_ref.faction == faction and unit.is_alive():
				return false
		return true

	func toJson() -> Dictionary:
		return {"type": "faction_defeated", "faction": UnitReference.FACTION_NAMES[faction]}


## One unit (a lord, a boss) is defeated.
class UnitDefeated:
	extends Condition
	var unit_id: String

	func _init(p_unit_id: String) -> void:
		unit_id = p_unit_id

	func is_met(state: LevelState) -> bool:
		var unit := state.level_units.get(unit_id) as LevelUnitState
		return unit != null and not unit.is_alive()

	func validate(state: LevelState) -> PackedStringArray:
		if not state.level_units.has(unit_id):
			return PackedStringArray(["unit_defeated: no unit '%s' in this level." % unit_id])
		return PackedStringArray()

	func toJson() -> Dictionary:
		return {"type": "unit_defeated", "unit": unit_id}


var win: Array[Condition] = [FactionDefeated.new(UnitReference.Faction.ENEMY)]
var lose: Array[Condition] = [FactionDefeated.new(UnitReference.Faction.PLAYER)]


## LOST if any lose condition holds, else WON if any win condition holds.
func outcome(state: LevelState) -> Outcome:
	for condition in lose:
		if condition.is_met(state):
			return Outcome.LOST
	for condition in win:
		if condition.is_met(state):
			return Outcome.WON
	return Outcome.NONE


## Unknown or malformed conditions are warned about and dropped. A list that's
## left out keeps its default; one given empty means "never" (e.g. no way to win
## by fighting in a level that ends some other way later).
static func fromJson(d: Dictionary) -> Objective:
	var o := Objective.new()
	if d.has("win"):
		o.win = _conditions_from_json(d["win"], "win")
	if d.has("lose"):
		o.lose = _conditions_from_json(d["lose"], "lose")
	return o


func toJson() -> Dictionary:
	return {
		"win": win.map(func(c: Condition) -> Dictionary: return c.toJson()),
		"lose": lose.map(func(c: Condition) -> Dictionary: return c.toJson()),
	}


## Problems that need the level's units to spot. LevelState warns about them.
func validate(state: LevelState) -> PackedStringArray:
	var problems := PackedStringArray()
	for condition in win + lose:
		problems.append_array(condition.validate(state))
	return problems


static func _conditions_from_json(value: Variant, list_name: String) -> Array[Condition]:
	var out: Array[Condition] = []
	if not value is Array:
		push_warning("Objective: '%s' must be a list; ignoring it." % list_name)
		return out
	for d: Variant in value:
		var condition := _condition_from_json(d)
		if condition == null:
			push_warning("Objective: skipping bad '%s' condition %s." % [list_name, JSON.stringify(d)])
		else:
			out.append(condition)
	return out


static func _condition_from_json(d: Variant) -> Condition:
	if not d is Dictionary:
		return null
	match d.get("type"):
		"faction_defeated":
			var faction_name: Variant = d.get("faction")
			# Not faction_from_string: that falls back to player, which would
			# quietly turn a typo'd win condition into a lose condition.
			for f in UnitReference.FACTION_NAMES:
				if UnitReference.FACTION_NAMES[f] == faction_name:
					return FactionDefeated.new(f)
		"unit_defeated":
			if d.get("unit") is String and not d["unit"].is_empty():
				return UnitDefeated.new(d["unit"])
	return null
