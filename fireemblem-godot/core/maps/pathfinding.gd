class_name Pathfinding
extends RefCounted
## Grid queries over a LevelState: which cells can be stood on and how to get
## between them. Works in tile cells only; pixels are Level's business.

var level_state: LevelState
var astar := AStarGrid2D.new()


func _init(p_level_state: LevelState) -> void:
	level_state = p_level_state
	rebuild()


## Re-reads the map's layers. Call after the drawn cells change; unit
## positions are read fresh on every find_path, so those need no rebuild.
func rebuild() -> void:
	astar = AStarGrid2D.new()
	astar.region = level_state.map_data.layerData.bounds()
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	# Manhattan gives long straight runs; the default (Euclidean) staircases
	# along the diagonal, which makes the unit turn on almost every tile.
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	# Any cell some layer draws on is walkable; everything else is not.
	var drawn := level_state.map_data.layerData.drawn_cells()
	for x in range(astar.region.position.x, astar.region.end.x):
		for y in range(astar.region.position.y, astar.region.end.y):
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, not drawn.has(cell))


func is_walkable(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell)


## Shortest route for `unit` to `target`, starting with the cell it stands on.
## Empty when there is no route.
func find_path(unit: LevelUnitState, target: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var marked: Array[Vector2i] = []
	# If the target has a unit in it, no path is available
	for level_unit_state in level_state.level_units.values():
		if level_unit_state.is_alive() and level_unit_state.cell == target:
			return path
	var current_unit_reference: UnitReference = unit.unit_ref
		
	for unit_on_map in level_state.level_units.values():
		if unit_on_map == unit:
			continue
		var unit_on_map_reference: UnitReference = unit_on_map.unit_ref
		if unit_on_map.is_alive() and UnitReference.are_hostile(current_unit_reference, unit_on_map_reference):
			astar.set_point_solid(unit_on_map.cell)
			marked.append(unit_on_map.cell)
		
	path = astar.get_id_path(unit.cell, target)
		
	for cell in marked:
		astar.set_point_solid(cell, false)
	return path
