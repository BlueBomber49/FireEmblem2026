class_name MapCursor
extends Node2D
## The square cursor the player steers over a Level's cells. It only knows
## where it is and where it may go; Battle decides what confirm means there.

signal moved(cell: Vector2i)

## Two 32x32 frames of corner brackets, drawn centred on a 16 px cell so the
## brackets straddle its corners. The second frame sits a pixel further out.
const SHEET := preload("res://assets/battle_pack/UI Elements/SelectionCursor.png")
const FRAME_SIZE := Vector2(32, 32)
const FRAME_COUNT := 2
## Frames per second of the breathing pulse.
const PULSE_FPS := 3.0

var cell := Vector2i.ZERO
## Cells the cursor may rest on. An empty rect means unlimited.
var bounds := Rect2i()
var tile_size := Vector2i(16, 16)
var frame := 0

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	var next_frame := int(_time * PULSE_FPS) % FRAME_COUNT
	if next_frame != frame:
		frame = next_frame
		queue_redraw()


func move(direction: Vector2i) -> void:
	set_cell(cell + direction)


## Moves to `new_cell` (clamped to `bounds`) and emits `moved` if that changed anything.
func set_cell(new_cell: Vector2i) -> void:
	var target := new_cell
	if bounds.has_area():
		target = target.clamp(bounds.position, bounds.end - Vector2i.ONE)
	if target == cell:
		return
	cell = target
	queue_redraw()
	moved.emit(cell)


func _draw() -> void:
	var centre := Vector2(cell * tile_size) + Vector2(tile_size) / 2.0
	var rect := Rect2(centre - FRAME_SIZE / 2.0, FRAME_SIZE)
	var region := Rect2(Vector2(frame * FRAME_SIZE.x, 0), FRAME_SIZE)
	draw_texture_rect_region(SHEET, rect, region)
