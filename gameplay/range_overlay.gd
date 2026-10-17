class_name RangeOverlay
extends Node2D
## Draws the cells a selected unit can move to (blue) and attack (red),
## cycling through the battle pack's shimmer strips. It only draws; Battle
## decides which cells.

## 224x16 strips: 14 frames of 16 px, drawn in order as a loop.
const MOVE_SHEET := preload("res://assets/battle_pack/UI Elements/RangerFinderTile_Blue_50%Opacity.png")
const ATTACK_SHEET := preload("res://assets/battle_pack/UI Elements/RangerFinderTile_Red_50%Opacity.png")
const FRAME_SIZE := Vector2(16, 16)
const FRAME_COUNT := 14
const FPS := 10.0

## cell -> true for each set. Both may be shown at once.
var move_cells: Dictionary = {}
var attack_cells: Dictionary = {}
var tile_size := Vector2i(16, 16)
var frame := 0

var _time := 0.0


func set_cells(new_move_cells: Dictionary, new_attack_cells: Dictionary) -> void:
	move_cells = new_move_cells
	attack_cells = new_attack_cells
	queue_redraw()


func _process(delta: float) -> void:
	if move_cells.is_empty() and attack_cells.is_empty():
		return
	_time += delta
	var next_frame := int(_time * FPS) % FRAME_COUNT
	if next_frame != frame:
		frame = next_frame
		queue_redraw()


func _draw() -> void:
	var region := Rect2(Vector2(frame * FRAME_SIZE.x, 0), FRAME_SIZE)
	for cell in move_cells:
		draw_texture_rect_region(MOVE_SHEET, _cell_rect(cell), region)
	for cell in attack_cells:
		draw_texture_rect_region(ATTACK_SHEET, _cell_rect(cell), region)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell * tile_size), Vector2(tile_size))
