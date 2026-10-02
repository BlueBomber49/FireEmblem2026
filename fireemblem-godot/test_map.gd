extends Node2D

const Unit := preload("res://unit.gd")

## Seconds a unit takes to cross one tile.
const STEP_TIME := 0.15
const SELECTED_TINT := Color(1.0, 1.0, 0.5)

@onready var ground: TileMapLayer = $Ground

var astar := AStarGrid2D.new()
var units: Array[Unit] = []
var selected: Unit = null
var moving := false


func _ready() -> void:
	# Any cell with a Ground tile is walkable; everything else (water) is not.
	astar.region = ground.get_used_rect()
	astar.cell_size = ground.tile_set.tile_size
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	# Manhattan gives long straight runs; the default (Euclidean) staircases
	# along the diagonal, which makes the unit turn on almost every tile.
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	for x in range(astar.region.position.x, astar.region.end.x):
		for y in range(astar.region.position.y, astar.region.end.y):
			var cell := Vector2i(x, y)
			if ground.get_cell_source_id(cell) == -1:
				astar.set_point_solid(cell)

	for child in get_children():
		if child is Unit:
			# Units are placed by hand in the editor, so snap them onto the grid.
			child.global_position = cell_center(cell_at(child.global_position))
			units.append(child)


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	if moving:
		return

	var clicked := cell_at(get_global_mouse_position())
	var clicked_unit := unit_at(clicked)

	if clicked_unit != null:
		# Clicking the selected unit deselects it; clicking another switches to it.
		select(null if clicked_unit == selected else clicked_unit)
	elif selected != null and is_walkable(clicked):
		var path := find_path(selected, clicked)
		if not path.is_empty():
			var unit := selected
			select(null)
			walk(unit, path)


## Shortest route for `unit` to `target`, going around water and other units.
func find_path(unit: Unit, target: Vector2i) -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	for other in units:
		if other != unit:
			blocked.append(cell_at(other.global_position))
	for cell in blocked:
		astar.set_point_solid(cell, true)
	var path := astar.get_id_path(cell_at(unit.global_position), target)
	for cell in blocked:
		astar.set_point_solid(cell, false)
	return path


func walk(unit: Unit, path: Array[Vector2i]) -> void:
	moving = true
	var tween := create_tween()
	# path[0] is the cell the unit is already standing on.
	for i in range(1, path.size()):
		tween.tween_callback(unit.play_animation.bind("walk", path[i] - path[i - 1]))
		tween.tween_property(unit, "global_position", cell_center(path[i]), STEP_TIME)
	await tween.finished
	unit.play_animation("idle")
	moving = false


func select(unit: Unit) -> void:
	if selected != null:
		selected.modulate = Color.WHITE
	selected = unit
	if selected != null:
		selected.modulate = SELECTED_TINT


func unit_at(cell: Vector2i) -> Unit:
	for unit in units:
		if cell_at(unit.global_position) == cell:
			return unit
	return null


func is_walkable(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell)


func cell_at(global_pos: Vector2) -> Vector2i:
	return ground.local_to_map(ground.to_local(global_pos))


func cell_center(cell: Vector2i) -> Vector2:
	return ground.to_global(ground.map_to_local(cell))
