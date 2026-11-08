class_name Objective
extends RefCounted
## How a level ends: lists of win and lose conditions, read from the level
## file's "objective". The level is won when any win condition holds and lost
## when any lose condition holds; losing is checked first, so a lord falling in
## the same fight as the last enemy is still a defeat.
##
## Losing every player unit always loses, whatever the lose list says, so a
## level can never leave the player with an empty army and no way to end. It's
## built in rather than stored, so `lose` holds only a level's extra conditions.
##
## Left out of the file, the win list is the classic rout. See docs/data-format.md.
##
## Adding a condition type: write a Condition subclass below, then add one entry
## to CONDITION_TYPES. The map editor builds its fields from the entry's
## "settings", so it needs no change unless a new kind of setting appears.

enum Outcome { NONE, WON, LOST }

## The lists a condition can sit in (CONDITION_TYPES "sides").
const WIN := &"win"
const LOSE := &"lose"
## The built-in wipe loss, shown first among the lose lines.
const ARMY_DEFEATED_TEXT := "Your army is defeated"


## One thing that can end a level. Subclasses read only what they need.
class Condition:
	extends RefCounted
	## The CONDITION_TYPES key it was built from.
	var type := ""

	func is_met(_state: LevelState) -> bool:
		return false

	## The line shown to the player, e.g. "Seize the gate".
	func describe(_state: LevelState) -> String:
		return ""

	## Problems with this condition in `state` (e.g. a unit id that isn't there).
	func validate(_state: LevelState) -> PackedStringArray:
		return PackedStringArray()

	func toJson() -> Dictionary:
		return {"type": type}


## Every unit of one faction is defeated. As a win, "Rout the enemy".
class FactionDefeated:
	extends Condition
	var faction: UnitReference.Faction

	func _init(p_faction := UnitReference.Faction.ENEMY) -> void:
		faction = p_faction

	## Null for a missing or unknown faction. Not faction_from_string: that falls
	## back to player, which would quietly turn a typo'd win into a loss.
	static func from_json(d: Dictionary) -> Condition:
		for f in UnitReference.FACTION_NAMES:
			if UnitReference.FACTION_NAMES[f] == d.get("faction"):
				return FactionDefeated.new(f)
		return null

	func is_met(state: LevelState) -> bool:
		for value: Variant in state.level_units.values():
			var unit := value as LevelUnitState
			if unit != null and unit.unit_ref.faction == faction and unit.is_alive():
				return false
		return true

	func describe(_state: LevelState) -> String:
		if faction == UnitReference.Faction.ENEMY:
			return "Rout the enemy"
		return "Defeat every %s unit" % UnitReference.FACTION_NAMES[faction]

	func toJson() -> Dictionary:
		return {"type": type, "faction": UnitReference.FACTION_NAMES[faction]}


## The enemy marked as commander (LevelState.commander_id) is defeated.
class DefeatCommander:
	extends Condition

	static func from_json(_d: Dictionary) -> Condition:
		return DefeatCommander.new()

	## Never met without a commander on the map: a level missing one must not be
	## won the moment it starts.
	func is_met(state: LevelState) -> bool:
		var unit := state.level_units.get(state.commander_id()) as LevelUnitState
		return unit != null and not unit.is_alive()

	func describe(_state: LevelState) -> String:
		return "Defeat the enemy commander"

	func validate(state: LevelState) -> PackedStringArray:
		if state.commander_id().is_empty():
			return PackedStringArray(["defeat_commander: no enemy is marked as the commander."])
		return PackedStringArray()


## A unit used the Seize command on one of `cells` (LevelState.seized).
class Seize:
	extends Condition
	var cells: Array[Vector2i] = []
	## What the cells are called in the objective text, e.g. "the gate".
	var name := ""

	static func from_json(d: Dictionary) -> Condition:
		if not d.get("cells") is Array:
			return null
		var seize := Seize.new()
		for raw: Variant in d["cells"]:
			seize.cells.append(JsonUtil.vec2i_from_json(raw))
		seize.name = str(d.get("name", ""))
		return seize

	func is_met(state: LevelState) -> bool:
		return state.seized

	func describe(_state: LevelState) -> String:
		return "Seize %s" % (name if not name.is_empty() else "the marked cell")

	func validate(_state: LevelState) -> PackedStringArray:
		if cells.is_empty():
			return PackedStringArray(["seize: no cell to seize."])
		return PackedStringArray()

	func toJson() -> Dictionary:
		var d := {"type": type, "cells": cells.map(func(c: Vector2i) -> Array: return JsonUtil.vec2i_to_json(c))}
		if not name.is_empty():
			d["name"] = name
		return d


## Like Seize (cells, an optional name, a unit-menu command on those cells), but
## won by the Escape command, with its own flag and text.
class Escape:
	extends Seize

	## Its own builder: the loader calls the registry class's from_json, and a
	## subclass that doesn't override a static function runs the parent's (which
	## would build a Seize).
	static func from_json(d: Dictionary) -> Condition:
		if not d.get("cells") is Array:
			return null
		var escape := Escape.new()
		for raw: Variant in d["cells"]:
			escape.cells.append(JsonUtil.vec2i_from_json(raw))
		escape.name = str(d.get("name", ""))
		return escape

	func is_met(state: LevelState) -> bool:
		return state.escaped

	func describe(_state: LevelState) -> String:
		return "Escape" if name.is_empty() else "Escape to %s" % name

	func validate(_state: LevelState) -> PackedStringArray:
		if cells.is_empty():
			return PackedStringArray(["escape: no cell to escape from."])
		return PackedStringArray()


## Base for conditions that count turns: met once `turns` enemy phases are over
## (the turn counter has gone past it).
class TurnCount:
	extends Condition
	var turns := 1

	func is_met(state: LevelState) -> bool:
		return state.turn > turns

	func validate(_state: LevelState) -> PackedStringArray:
		if turns < 1:
			return PackedStringArray(["%s: turns must be at least 1." % type])
		return PackedStringArray()

	func toJson() -> Dictionary:
		return {"type": type, "turns": turns}

	func _read_turns(d: Dictionary) -> bool:
		if not (d.get("turns") is float or d.get("turns") is int):
			return false
		turns = int(d["turns"])
		return true


## Win by getting through `turns` enemy phases.
class Survive:
	extends TurnCount

	static func from_json(d: Dictionary) -> Condition:
		var survive := Survive.new()
		return survive if survive._read_turns(d) else null

	func describe(_state: LevelState) -> String:
		return "Survive %d turn%s" % [turns, "" if turns == 1 else "s"]


## Lose once `turns` enemy phases are over without a win.
class TurnsPass:
	extends TurnCount

	static func from_json(d: Dictionary) -> Condition:
		var turns_pass := TurnsPass.new()
		return turns_pass if turns_pass._read_turns(d) else null

	func describe(_state: LevelState) -> String:
		return "%d turn%s" % [turns, " passes" if turns == 1 else "s pass"]


## Lose when any of `units` (a lord, an ally to protect) is defeated. Reads the
## older {"type": "unit_defeated", "unit": id} form too.
class UnitsFall:
	extends Condition
	var units: Array[String] = []

	static func from_json(d: Dictionary) -> Condition:
		var fall := UnitsFall.new()
		if d.get("units") is Array:
			for id: Variant in d["units"]:
				if id is String and not id.is_empty():
					fall.units.append(id)
		elif d.get("unit") is String and not d["unit"].is_empty():
			fall.units.append(d["unit"])
		return fall if not fall.units.is_empty() else null

	## A listed unit that isn't in the level never counts as defeated.
	func is_met(state: LevelState) -> bool:
		for id in units:
			var unit := state.level_units.get(id) as LevelUnitState
			if unit != null and not unit.is_alive():
				return true
		return false

	## "Lyn falls", "Lyn or Kent falls", "Lyn, Kent, or Wil falls".
	func describe(state: LevelState) -> String:
		if units.is_empty():
			return "Units fall (none chosen yet)"
		var names := PackedStringArray()
		for id in units:
			var ref: UnitReference = state.map_data.units.get(id)
			names.append(ref.display_name() if ref != null else id)
		var who := names[0] if names.size() == 1 \
				else "%s or %s" % [names[0], names[1]] if names.size() == 2 \
				else "%s, or %s" % [", ".join(names.slice(0, -1)), names[-1]]
		return "%s falls" % who

	func validate(state: LevelState) -> PackedStringArray:
		var problems := PackedStringArray()
		if units.is_empty():
			problems.append("units_fall: no units listed.")
		for id in units:
			if not state.level_units.has(id) and not state.map_data.units.has(id):
				problems.append("units_fall: no unit '%s' in this level." % id)
		return problems

	func toJson() -> Dictionary:
		return {"type": type, "units": units.duplicate()}


## Every condition type, by its JSON "type": the class, the editor's label, the
## lists it may sit in, and the settings the editor asks for (units, cells,
## turns, name, commander: which enemy is marked as the commander).
const CONDITION_TYPES := {
	"faction_defeated": {"class": FactionDefeated, "title": "Rout the enemy", "sides": [WIN], "settings": []},
	"defeat_commander": {"class": DefeatCommander, "title": "Defeat the enemy commander", "sides": [WIN], "settings": [&"commander"]},
	"seize": {"class": Seize, "title": "Seize", "sides": [WIN], "settings": [&"cells", &"name"]},
	"escape": {"class": Escape, "title": "Escape", "sides": [WIN], "settings": [&"cells", &"name"]},
	"survive": {"class": Survive, "title": "Survive N turns", "sides": [WIN], "settings": [&"turns"]},
	"units_fall": {"class": UnitsFall, "title": "Units fall", "sides": [LOSE], "settings": [&"units"]},
	"turns_pass": {"class": TurnsPass, "title": "N turns pass", "sides": [LOSE], "settings": [&"turns"]},
}
## Older type names still read, as the type they became.
const TYPE_ALIASES := {"unit_defeated": "units_fall"}


var win: Array[Condition] = [_rout()]
## Only a level's extra lose conditions; the full-wipe loss is always checked.
var lose: Array[Condition] = []


## LOST if every player unit is defeated or any lose condition holds, else WON
## if any win condition holds.
func outcome(state: LevelState) -> Outcome:
	if FactionDefeated.new(UnitReference.Faction.PLAYER).is_met(state):
		return Outcome.LOST
	for condition in lose:
		if condition.is_met(state):
			return Outcome.LOST
	for condition in win:
		if condition.is_met(state):
			return Outcome.WON
	return Outcome.NONE


## The objective as the player reads it, one line per win condition.
func win_lines(state: LevelState) -> PackedStringArray:
	var lines := PackedStringArray()
	for condition in win:
		lines.append(condition.describe(state))
	return lines


## One line per lose condition, starting with the built-in "Your army is defeated".
func lose_lines(state: LevelState) -> PackedStringArray:
	var lines := PackedStringArray([ARMY_DEFEATED_TEXT])
	for condition in lose:
		lines.append(condition.describe(state))
	return lines


## Every cell a seize condition lists, for highlighting and the Seize command.
## Escape extends Seize, so it's left out here; see escape_cells().
func seize_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for condition in win:
		if condition is Seize and not condition is Escape:
			cells.append_array((condition as Seize).cells)
	return cells


## Every cell an escape condition lists, for highlighting and the Escape command.
func escape_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for condition in win:
		if condition is Escape:
			cells.append_array((condition as Escape).cells)
	return cells


func has_type(type_name: String) -> bool:
	for condition in win + lose:
		if condition.type == type_name:
			return true
	return false


## Unknown, malformed or misplaced conditions are warned about and dropped. A
## win list that's left out keeps the default rout; one given empty means
## "never" (a level that ends some other way later). A listed full-wipe loss is
## dropped quietly, since it's built in.
static func fromJson(d: Dictionary) -> Objective:
	var o := Objective.new()
	if d.has("win"):
		o.win = _conditions_from_json(d["win"], WIN)
	if d.has("lose"):
		o.lose = _conditions_from_json(d["lose"], LOSE)
	return o


func toJson() -> Dictionary:
	return {
		"win": win.map(func(c: Condition) -> Dictionary: return c.toJson()),
		"lose": lose.map(func(c: Condition) -> Dictionary: return c.toJson()),
	}


## Problems that need the level's units to spot: each condition's own, plus the
## commander marks (at most one, and only on an enemy). LevelState warns about
## them when loading; the map editor won't save until they're fixed.
func validate(state: LevelState) -> PackedStringArray:
	var problems := PackedStringArray()
	for condition in win + lose:
		problems.append_array(condition.validate(state))
	var commanders := 0
	for ref: UnitReference in state.map_data.units.values():
		if not ref.commander:
			continue
		commanders += 1
		if ref.faction != UnitReference.Faction.ENEMY:
			problems.append("commander: '%s' isn't an enemy." % ref.id)
	if commanders > 1:
		problems.append("commander: %d units are marked; mark only one." % commanders)
	return problems


## A new condition of `type_name` with default settings (for the map editor).
static func create(type_name: String) -> Condition:
	var condition: Condition = CONDITION_TYPES[type_name]["class"].new()
	condition.type = type_name
	return condition


## The types that may sit in `side` (WIN or LOSE), in registry order.
static func types_for(side: StringName) -> Array[String]:
	var out: Array[String] = []
	for type_name: String in CONDITION_TYPES:
		if side in CONDITION_TYPES[type_name]["sides"]:
			out.append(type_name)
	return out


static func title_of(type_name: String) -> String:
	return CONDITION_TYPES[type_name]["title"]


static func settings_of(type_name: String) -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(CONDITION_TYPES[type_name]["settings"])
	return out


static func _rout() -> Condition:
	var rout := FactionDefeated.new(UnitReference.Faction.ENEMY)
	rout.type = "faction_defeated"
	return rout


static func _conditions_from_json(value: Variant, side: StringName) -> Array[Condition]:
	var out: Array[Condition] = []
	if not value is Array:
		push_warning("Objective: '%s' must be a list; ignoring it." % side)
		return out
	for d: Variant in value:
		if side == LOSE and _is_wipe_loss(d):
			continue  # built in
		var condition := _condition_from_json(d, side)
		if condition == null:
			push_warning("Objective: skipping bad '%s' condition %s." % [side, JSON.stringify(d)])
		else:
			out.append(condition)
	return out


## Null when `d` isn't a known type allowed on `side`, or its settings are malformed.
static func _condition_from_json(d: Variant, side: StringName) -> Condition:
	if not d is Dictionary or not d.get("type") is String:
		return null
	var type_name: String = TYPE_ALIASES.get(d["type"], d["type"])
	if not CONDITION_TYPES.has(type_name) or not side in CONDITION_TYPES[type_name]["sides"]:
		return null
	var condition: Condition = CONDITION_TYPES[type_name]["class"].from_json(d)
	if condition != null:
		condition.type = type_name
	return condition


static func _is_wipe_loss(d: Variant) -> bool:
	# `is String` first: comparing a number or null to text with == is an engine error.
	return d is Dictionary and d.get("type") is String and d["type"] == "faction_defeated" \
			and d.get("faction") is String \
			and d["faction"] == UnitReference.FACTION_NAMES[UnitReference.Faction.PLAYER]
