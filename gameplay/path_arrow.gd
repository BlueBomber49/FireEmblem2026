class_name PathArrow
extends Node2D
## Draws the route a selected unit would take to the cursor, Fire Emblem
## style: a tail on the unit's cell, straights and corners along the way, and
## a head on the cursor's cell. It only draws; Battle decides the path.

## 96x192: three 64 px colour blocks (blue, red, green), each a 6x4 grid of
## 16 px tiles. Only the blue block and its first four columns are used.
const SHEET := preload("res://assets/battle_pack/UI Elements/MovementArrows.png")
const TILE := 16

const LEFT_BIT := 1
const RIGHT_BIT := 2
const UP_BIT := 4
const DOWN_BIT := 8
const SIDE_BITS := {
	Vector2i.LEFT: LEFT_BIT,
	Vector2i.RIGHT: RIGHT_BIT,
	Vector2i.UP: UP_BIT,
	Vector2i.DOWN: DOWN_BIT,
}

## The unit's cell, keyed by the direction the path leaves in.
const TAILS := {
	Vector2i.RIGHT: Vector2i(0, 0),
	Vector2i.DOWN: Vector2i(1, 0),
	Vector2i.UP: Vector2i(2, 0),
	Vector2i.LEFT: Vector2i(3, 0),
}
## The cursor's cell, keyed by the direction the path arrives in.
const HEADS := {
	Vector2i.RIGHT: Vector2i(0, 2),
	Vector2i.DOWN: Vector2i(1, 2),
	Vector2i.LEFT: Vector2i(0, 3),
	Vector2i.UP: Vector2i(1, 3),
}
## Cells in between, keyed by the two sides the arrow passes through.
const SEGMENTS := {
	LEFT_BIT | RIGHT_BIT: Vector2i(0, 1),
	UP_BIT | DOWN_BIT: Vector2i(1, 1),
	RIGHT_BIT | DOWN_BIT: Vector2i(2, 1),
	LEFT_BIT | DOWN_BIT: Vector2i(3, 1),
	UP_BIT | RIGHT_BIT: Vector2i(2, 2),
	UP_BIT | LEFT_BIT: Vector2i(3, 2),
}

## Cells from the unit to the cursor. Fewer than two cells draws nothing.
var path: Array[Vector2i] = []
var tile_size := Vector2i(16, 16)


func set_path(new_path: Array[Vector2i]) -> void:
	path = new_path
	queue_redraw()


## Sheet tile (column, row) for cell `i` of `path`, from its neighbours.
static func tile_at(path_cells: Array[Vector2i], i: int) -> Vector2i:
	if i == 0:
		return TAILS[path_cells[1] - path_cells[0]]
	if i == path_cells.size() - 1:
		return HEADS[path_cells[i] - path_cells[i - 1]]
	var came_from: Vector2i = path_cells[i - 1] - path_cells[i]
	var goes_to: Vector2i = path_cells[i + 1] - path_cells[i]
	return SEGMENTS[SIDE_BITS[came_from] | SIDE_BITS[goes_to]]


func _draw() -> void:
	if path.size() < 2:
		return
	for i in path.size():
		var rect := Rect2(Vector2(path[i] * tile_size), Vector2(tile_size))
		var region := Rect2(Vector2(tile_at(path, i) * TILE), Vector2(TILE, TILE))
		draw_texture_rect_region(SHEET, rect, region)
