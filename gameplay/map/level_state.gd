class_name LevelState
extends RefCounted
## A level in play: the authored map plus the saveable state of every unit on
## it. Serialized with unit state it is a save; without, an authored level.

const SAVE_VERSION := 1

var map_data: MapData = MapData.new()
## id -> LevelUnitState; the saveable state of every unit.
var level_units: Dictionary = {}
## Event id -> event. Today's one kind brings reinforcements in:
## {"name": "...", "trigger": {"type": "turn_start", "turn": N, "phase": "enemy"},
##  "actions": [{"type": "spawn"}]}, where spawn brings in every placement whose
## "event" is that id. Carried through JSON as written.
var events: Dictionary = {}
## In play: id -> LevelUnitState for reinforcements not on the map yet (see
## hold_back_reinforcements). Empty in the editor.
var pending_units: Dictionary = {}
## Ids of the events that have fired this level.
var fired_events: Array[String] = []
## How the level is won or lost. Rout by default.
var objective := Objective.new()
## The turn number: 1 is the first player phase, and it goes up after each enemy
## phase. Saved only with play state, so an authored level starts on turn 1.
var turn := 1
## Whether a unit has used the Seize command (Objective's seize condition).
var seized := false
## Whether a unit has used the Escape command (Objective's escape condition).
var escaped := false


static func fromJson(d: Dictionary) -> LevelState:
	var state := LevelState.new()
	state.map_data = MapData.fromJson(d.get("map_data", {}))
	state.events = d.get("events", {}).duplicate(true)
	# A save carries level_units; an authored level doesn't, so units start fresh.
	state.level_units = LevelUnitState.build_all(state.map_data.units, d.get("level_units", {}))
	var objective_json: Variant = d.get("objective", {})
	state.objective = Objective.fromJson(objective_json if objective_json is Dictionary else {})
	for problem in state.objective.validate(state):
		push_warning("Objective: %s" % problem)
	state.turn = maxi(SaveUtil.read_int(d, "turn", 1), 1) if d.has("turn") else 1
	state.seized = d.get("seized", false) == true
	state.escaped = d.get("escaped", false) == true
	return state


## The event trigger types and phases that exist so far.
const TRIGGER_TYPES: Array[String] = ["turn_start"]
const EVENT_PHASES: Array[String] = ["enemy", "player"]


## Why `event` can't run, or "" when it's a valid event: a turn_start trigger
## with a turn of 1 or more and a known phase.
static func event_problem(event: Variant) -> String:
	if not event is Dictionary or not (event as Dictionary).get("trigger") is Dictionary:
		return "it has no trigger"
	var trigger: Dictionary = event["trigger"]
	if not str(trigger.get("type", "")) in TRIGGER_TYPES:
		return "unknown trigger '%s'" % str(trigger.get("type", ""))
	var turn: Variant = trigger.get("turn")
	if not (turn is int or turn is float) or int(turn) < 1:
		return "its turn must be 1 or more"
	if not str(trigger.get("phase", "")) in EVENT_PHASES:
		return "unknown phase '%s'" % str(trigger.get("phase", ""))
	return ""


## In play: moves each enemy placement tied to a valid event off the map, into
## pending_units, until that event brings it in. A unit whose event is missing or
## broken, or that isn't an enemy, is left on the map with a warning, so nothing
## is ever stranded.
func hold_back_reinforcements() -> void:
	for id: String in level_units.keys():
		var ref: UnitReference = map_data.units.get(id)
		if ref == null or ref.event.is_empty():
			continue
		if ref.faction != UnitReference.Faction.ENEMY:
			push_warning("Level: unit '%s' has event '%s', but only enemies arrive later; it starts on the map." % [id, ref.event])
			continue
		if not events.has(ref.event):
			push_warning("Level: unit '%s' arrives with event '%s', which doesn't exist; it starts on the map." % [id, ref.event])
			continue
		var problem := event_problem(events[ref.event])
		if not problem.is_empty():
			push_warning("Level: event '%s' can't run (%s); unit '%s' starts on the map." % [ref.event, problem, id])
			continue
		pending_units[id] = level_units[id]
		level_units.erase(id)


## The id of the unit marked as the enemy commander, or "" when none is.
func commander_id() -> String:
	for ref: UnitReference in map_data.units.values():
		if ref.commander:
			return ref.id
	return ""


## With `include_state` off this is an authored level (no level_units), so
## loading it starts every unit fresh.
func toJson(include_state := true) -> Dictionary:
	var d := {
		"version": SAVE_VERSION,
		"map_data": map_data.toJson(),
		"events": events.duplicate(true),
		"objective": objective.toJson(),
	}
	if include_state:
		var saved_units := {}
		for id in level_units:
			saved_units[id] = level_units[id].toJson()
		d["level_units"] = saved_units
		d["turn"] = turn
		d["seized"] = seized
		d["escaped"] = escaped
	return d


## Reads a level or save from a JSON file. Returns null (after push_error)
## when the file can't be opened or isn't a JSON object.
static func load_file(path: String) -> LevelState:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open level '%s': %s" % [path, error_string(FileAccess.get_open_error())])
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Level '%s' is not a JSON object" % path)
		return null
	return fromJson(parsed)


func save_file(path: String, include_state := true) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write level '%s': %s" % [path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(toJson(include_state), "\t"))
	return OK
