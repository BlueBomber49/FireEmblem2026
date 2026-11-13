class_name LevelUnitState
extends RefCounted
## The board half of a unit on the field (the model behind LevelUnit): where it
## stands, whether it has moved or acted, and which way it faces. Everything
## mechanical (stats, HP, items) is its Unit's.

## The authored placement. Always set; its `id` is the key in
## LevelState.level_units and MapData.units.
var unit_ref: UnitReference
## The mechanics model: stats, current and max HP, inventory.
var unit: Unit
var cell := Vector2i.ZERO
## Current HP lives on the Unit; this forwards to it so board code can use either.
var current_hp: int:
	get:
		return unit.current_hp if unit != null else 0
	set(value):
		if unit != null:
			unit.current_hp = value
var has_moved := false
var has_acted := false
var facing := Vector2i.DOWN


func is_alive() -> bool:
	return current_hp > 0


func reset_turn() -> void:
	has_moved = false
	has_acted = false


## State for a unit that has not been touched yet (starting a level fresh), or null
## when the placement can't be built (see UnitReference.build_problem).
static func from_reference(ref: UnitReference) -> LevelUnitState:
	var data := ref.build_unit_data()
	if data == null:
		return null
	var state := LevelUnitState.new()
	state.unit_ref = ref
	state.unit = Unit.new(data)
	state.cell = ref.start_cell
	state.facing = ref.facing
	return state


## States for every unit in `units` (id -> UnitReference): restored from
## `saved` (id -> JSON dict) when present there, otherwise fresh. A placement
## that can't be built is skipped with a warning; it stays in the map data.
static func build_all(units: Dictionary, saved: Dictionary) -> Dictionary:
	var states := {}
	for id in units:
		var ref: UnitReference = units[id]
		var state: LevelUnitState
		if saved.has(id) and saved[id] is Dictionary:
			state = fromJson(ref, saved[id])
		else:
			state = from_reference(ref)
		if state == null:
			push_warning("Level: skipping %s" % ref.build_problem())
			continue
		states[id] = state
	return states


## `ref` isn't in the JSON: a save stores only what changes during play. Returns
## null when the placement can't be built.
static func fromJson(ref: UnitReference, d: Dictionary) -> LevelUnitState:
	var state := from_reference(ref)
	if state == null:
		return null
	state.cell = JsonUtil.vec2i_from_json(d.get("cell"), ref.start_cell)
	state.has_moved = bool(d.get("has_moved", false))
	state.has_acted = bool(d.get("has_acted", false))
	state.facing = JsonUtil.vec2i_from_json(d.get("facing"), Vector2i.DOWN)
	if d.has("unit"):
		state.unit.apply_saved_state(d["unit"])
	elif d.has("current_hp"):
		# Saves from before units carried their own state stored HP up here.
		state.current_hp = clampi(JsonUtil.to_int(d["current_hp"]), 0, state.unit.max_hp())
	return state


func toJson() -> Dictionary:
	return {
		"cell": JsonUtil.vec2i_to_json(cell),
		"has_moved": has_moved,
		"has_acted": has_acted,
		"facing": JsonUtil.vec2i_to_json(facing),
		"unit": unit.save_state(),
	}
