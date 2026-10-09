class_name LevelUnitState
extends RefCounted
## The mutable, saveable half of a unit on the field (the model behind LevelUnit).

## Key in Level.level_units and MapData.units.
var unit_id: String
var cell := Vector2i.ZERO
var current_hp: int = 0
var has_moved := false
var has_acted := false
var facing := Vector2i.DOWN


func is_alive() -> bool:
	return current_hp > 0


func reset_turn() -> void:
	has_moved = false
	has_acted = false


## State for a unit that has not been touched yet (starting a level fresh).
static func from_reference(ref: UnitReference) -> LevelUnitState:
	var state := LevelUnitState.new()
	state.unit_id = ref.id
	state.cell = ref.start_cell
	state.current_hp = ref.stat(&"hp")
	state.facing = ref.facing
	return state


## States for every unit in `units` (id -> UnitReference): restored from
## `saved` (id -> JSON dict) when present there, otherwise fresh.
static func build_all(units: Dictionary, saved: Dictionary) -> Dictionary:
	var states := {}
	for id in units:
		if saved.has(id):
			states[id] = fromJson(id, saved[id])
		else:
			states[id] = from_reference(units[id])
	return states


static func fromJson(p_unit_id: String, d: Dictionary) -> LevelUnitState:
	var state := LevelUnitState.new()
	state.unit_id = p_unit_id
	state.cell = JsonUtil.vec2i_from_json(d.get("cell"))
	state.current_hp = JsonUtil.to_int(d.get("current_hp"))
	state.has_moved = bool(d.get("has_moved", false))
	state.has_acted = bool(d.get("has_acted", false))
	state.facing = JsonUtil.vec2i_from_json(d.get("facing"), Vector2i.DOWN)
	return state


func toJson() -> Dictionary:
	return {
		"cell": JsonUtil.vec2i_to_json(cell),
		"current_hp": current_hp,
		"has_moved": has_moved,
		"has_acted": has_acted,
		"facing": JsonUtil.vec2i_to_json(facing),
	}
