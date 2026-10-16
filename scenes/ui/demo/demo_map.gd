class_name DemoMap
extends Node2D
## Stand-in for the real map and cursor until teammates build them. Draws a
## colored grid and a square cursor, and reports the terrain under it.

signal cursor_moved(cell: Vector2i)

const CELL_SIZE := 48
const CURSOR_COLOR := Color(1, 1, 1)

## One character per cell: . plains, F forest, M mountain, T fort, ~ sea.
const LAYOUT: Array[String] = [
	"~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~......FFF.......MMM~~~",
	"~.......FFFF.....MMMM..~",
	"~..T.....FF.......MM...~",
	"~......................~",
	"~.....MM.......FF......~",
	"~....MMM......FFFF..T..~",
	"~.....M........FF......~",
	"~......................~",
	"~FF.......T.......FFF..~",
	"~FFF.............FFFF..~",
	"~TFF..............FF...~",
	"~~~~~~~~~~~~~~~~~~~~~~~~",
]

const COLORS := {
	".": Color(0.55, 0.75, 0.35),
	"F": Color(0.15, 0.45, 0.2),
	"M": Color(0.55, 0.45, 0.35),
	"T": Color(0.6, 0.6, 0.65),
	"~": Color(0.2, 0.4, 0.8),
}

var cursor_cell := Vector2i(4, 4)

var _terrain := {}


func _ready() -> void:
	_terrain = {
		".": _make_terrain("Plains", 0, 0, 0, 1),
		"F": _make_terrain("Forest", 1, 20, 0, 2),
		"M": _make_terrain("Mountain", 2, 30, 0, 4),
		"T": _make_terrain("Fort", 2, 20, 20, 2),
		"~": _make_terrain("Sea", 0, 0, 0, TerrainInfo.IMPASSABLE),
	}


func grid_size() -> Vector2i:
	return Vector2i(LAYOUT[0].length(), LAYOUT.size())


func terrain_at(cell: Vector2i) -> TerrainInfo:
	return _terrain[LAYOUT[cell.y][cell.x]]


func is_left_half(cell: Vector2i) -> bool:
	return cell.x < grid_size().x / 2


func move_cursor(direction: Vector2i) -> void:
	var size := grid_size()
	var target := (cursor_cell + direction).clamp(Vector2i.ZERO, size - Vector2i.ONE)
	if target == cursor_cell:
		return
	cursor_cell = target
	queue_redraw()
	cursor_moved.emit(cursor_cell)


func _draw() -> void:
	for y in LAYOUT.size():
		for x in LAYOUT[y].length():
			var cell_rect := Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			draw_rect(cell_rect, COLORS[LAYOUT[y][x]])
			draw_rect(cell_rect, Color(0, 0, 0, 0.15), false, 1.0)
	var cursor_rect := Rect2(cursor_cell * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
	draw_rect(cursor_rect.grow(-2), CURSOR_COLOR, false, 4.0)


func _make_terrain(terrain_name: String, defense: int, avoid: int,
		heal_percent: int, move_cost: int) -> TerrainInfo:
	var info := TerrainInfo.new()
	info.terrain_name = terrain_name
	info.defense = defense
	info.avoid = avoid
	info.heal_percent = heal_percent
	info.move_cost = move_cost
	return info
