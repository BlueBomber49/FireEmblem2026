class_name RangeOverlay
extends Node2D
## Draws the cells a selected or hovered unit can move to (blue) and attack
## (red), cycling through the battle pack's shimmer strips, and under them the
## enemy danger zone: a flat red fill with an outline, deeper red for marked
## enemies. It only draws; Battle decides which cells.

## 224x16 strips: 14 frames of 16 px, drawn in order as a loop.
const MOVE_SHEET := preload("res://assets/battle_pack/UI Elements/RangerFinderTile_Blue_50%Opacity.png")
const ATTACK_SHEET := preload("res://assets/battle_pack/UI Elements/RangerFinderTile_Red_50%Opacity.png")
const FRAME_SIZE := Vector2(16, 16)
const FRAME_COUNT := 14
const FPS := 10.0
## Danger zone colours: a flat fill plus an outline around each zone's edge.
## The outline is a soft edge in the fill's own colour, only a little stronger;
## set DRAW_OUTLINES to false to try the zones with no outline at all.
const THREAT_FILL := Color(0.9, 0.1, 0.1, 0.25)
const THREAT_OUTLINE := Color(0.9, 0.1, 0.1, 0.4)
const MARKED_FILL := Color(0.7, 0.0, 0.05, 0.45)
const MARKED_OUTLINE := Color(0.6, 0.0, 0.05, 0.6)
const OUTLINE_WIDTH := 1.0
## Seize cells: the green shimmer under everything, plus an outline that can sit
## on top of every other layer so the cell stays obvious under blue or red. Tune
## these by eye; the 50% green tile was nearly invisible on grass.
const SEIZE_SHEET := preload("res://assets/battle_pack/UI Elements/RangerFinderTile_Green_Solid.png")
const SEIZE_OUTLINE := Color(0.35, 1.0, 0.45, 1.0)
const SEIZE_OUTLINE_WIDTH := 2.0
const SEIZE_OUTLINE_ON_TOP := true
## Escape cells: a flat gold fill under the ranges (tinting a pack tile only
## darkened it), plus a gold outline drawn with seize's.
const ESCAPE_FILL := Color(1.0, 0.8, 0.15, 0.55)
const ESCAPE_OUTLINE := Color(1.0, 0.85, 0.2, 1.0)
const DRAW_OUTLINES := true

## cell -> true for each set. Both may be shown at once.
var move_cells: Dictionary = {}
var attack_cells: Dictionary = {}
## cell -> true: enemy threat, and the part of it from marked enemies.
var threat_cells: Dictionary = {}
var marked_threat_cells: Dictionary = {}
## cell -> true: where the Seize command wins the level.
var seize_cells: Dictionary = {}
## cell -> true: where the Escape command wins the level.
var escape_cells: Dictionary = {}
var tile_size := Vector2i(16, 16)
var frame := 0

var _time := 0.0


func set_cells(new_move_cells: Dictionary, new_attack_cells: Dictionary) -> void:
	move_cells = new_move_cells
	attack_cells = new_attack_cells
	queue_redraw()


## The danger zone, drawn under the move and attack shimmer. A cell in both sets
## should only be in `new_marked`.
func set_threat(new_normal: Dictionary, new_marked: Dictionary) -> void:
	threat_cells = new_normal
	marked_threat_cells = new_marked
	queue_redraw()


## The objective's seize cells (Objective.seize_cells), or none to hide them.
func set_seize_cells(cells: Array[Vector2i]) -> void:
	seize_cells = {}
	for cell in cells:
		seize_cells[cell] = true
	queue_redraw()


## The objective's escape cells (Objective.escape_cells), or none to hide them.
func set_escape_cells(cells: Array[Vector2i]) -> void:
	escape_cells = {}
	for cell in cells:
		escape_cells[cell] = true
	queue_redraw()


func _process(delta: float) -> void:
	if move_cells.is_empty() and attack_cells.is_empty() and seize_cells.is_empty():
		return
	_time += delta
	var next_frame := int(_time * FPS) % FRAME_COUNT
	if next_frame != frame:
		frame = next_frame
		queue_redraw()


func _draw() -> void:
	var seize_region := Rect2(Vector2(frame * FRAME_SIZE.x, 0), FRAME_SIZE)
	for cell in seize_cells:
		draw_texture_rect_region(SEIZE_SHEET, _cell_rect(cell), seize_region)
	for cell in escape_cells:
		draw_rect(_cell_rect(cell), ESCAPE_FILL)
	if not SEIZE_OUTLINE_ON_TOP:
		_draw_seize_outline()
	_draw_threat(threat_cells, THREAT_FILL, THREAT_OUTLINE)
	_draw_threat(marked_threat_cells, MARKED_FILL, MARKED_OUTLINE)
	var region := Rect2(Vector2(frame * FRAME_SIZE.x, 0), FRAME_SIZE)
	for cell in move_cells:
		draw_texture_rect_region(MOVE_SHEET, _cell_rect(cell), region)
	for cell in attack_cells:
		draw_texture_rect_region(ATTACK_SHEET, _cell_rect(cell), region)
	if SEIZE_OUTLINE_ON_TOP:
		_draw_seize_outline()


func _draw_seize_outline() -> void:
	var cell_scale := Vector2(tile_size)
	for edge: Array in outline_edges(seize_cells):
		draw_line(Vector2(edge[0]) * cell_scale, Vector2(edge[1]) * cell_scale, SEIZE_OUTLINE, SEIZE_OUTLINE_WIDTH)
	for edge: Array in outline_edges(escape_cells):
		draw_line(Vector2(edge[0]) * cell_scale, Vector2(edge[1]) * cell_scale, ESCAPE_OUTLINE, SEIZE_OUTLINE_WIDTH)


func _draw_threat(cells: Dictionary, fill: Color, outline: Color) -> void:
	for cell: Vector2i in cells:
		draw_rect(_cell_rect(cell), fill)
	if not DRAW_OUTLINES:
		return
	var cell_scale := Vector2(tile_size)
	for edge: Array in outline_edges(cells):
		draw_line(Vector2(edge[0]) * cell_scale, Vector2(edge[1]) * cell_scale, outline, OUTLINE_WIDTH)


## The outline of a set of cells: each side of a cell whose neighbour across it
## isn't in the set, as [from, to] in cell-corner coordinates (cell (x, y) spans
## corners (x, y) to (x + 1, y + 1)).
static func outline_edges(cells: Dictionary) -> Array:
	var edges := []
	for cell: Vector2i in cells:
		if not cells.has(cell + Vector2i.UP):
			edges.append([cell, cell + Vector2i.RIGHT])
		if not cells.has(cell + Vector2i.DOWN):
			edges.append([cell + Vector2i.DOWN, cell + Vector2i.ONE])
		if not cells.has(cell + Vector2i.LEFT):
			edges.append([cell, cell + Vector2i.DOWN])
		if not cells.has(cell + Vector2i.RIGHT):
			edges.append([cell + Vector2i.RIGHT, cell + Vector2i.ONE])
	return edges


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell * tile_size), Vector2(tile_size))
