class_name LevelState
extends RefCounted
## A level in play: the authored map plus the saveable state of every unit on
## it. Serialized with unit state it is a save; without, an authored level.

const SAVE_VERSION := 1

var map_data: MapData = MapData.new()
## id -> LevelUnitState; the saveable state of every unit.
var level_units: Dictionary = {}
## Unimplemented for now; carried through JSON untouched.
var events: Dictionary = {}
## How the level is won or lost. Rout by default.
var objective := Objective.new()


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
	return state


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
