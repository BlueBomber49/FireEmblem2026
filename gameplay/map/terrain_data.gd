class_name TerrainData
extends Resource
## The rules for one kind of terrain: movement costs and combat bonuses.
## Separate from TerrainType, which only says how the terrain is drawn.
## Instances come from resources/terrain_data/<id>.json through GameData.

## move_costs value for terrain a movement group can't enter.
const IMPASSABLE := -1

@export var id: StringName
@export var display_name := ""
@export var defense := 0
@export var avoid := 0
## Percent of max HP restored at the start of the owner's turn (forts). Stored
## for later: there's no turn phase yet.
@export var heal_percent := 0
## Enums.MovementType -> movement points to enter, or IMPASSABLE.
@export var move_costs: Dictionary = {}
## TerrainType ids (the drawn tiles) that follow these rules, e.g. "trees" for forest.
@export var tiles := PackedStringArray()
## Whether a map cell counts as this terrain when it's painted along one straight
## edge (2 corners side by side, half the tile drawn as this terrain). On for
## forest, so half-tree edge tiles play as forest; off for terrain like sea, where
## only a mostly-covered cell should count. See MapData.rules_terrain_at.
@export var half_edge_counts := false


## Movement points for a unit of `movement_type` to enter, or IMPASSABLE.
func move_cost(movement_type: Enums.MovementType) -> int:
	return move_costs.get(movement_type, IMPASSABLE)


func is_passable(movement_type: Enums.MovementType) -> bool:
	return move_cost(movement_type) != IMPASSABLE


## Returns a list of problems with this terrain; empty when it's valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Terrain has no id.")
	for field in [&"defense", &"avoid", &"heal_percent"]:
		if int(get(field)) < 0:
			errors.append("%s: %s can't be negative." % [id, field])
	for type in Enums.MovementType.values():
		if not move_costs.has(type):
			errors.append("%s: no move cost for %s." % [id, Enums.movement_type_name(type)])
			continue
		var cost: int = move_costs[type]
		if cost != IMPASSABLE and cost < 1:
			errors.append("%s: move cost for %s must be at least 1, or -1 for impassable." % [id, Enums.movement_type_name(type)])
	return errors
