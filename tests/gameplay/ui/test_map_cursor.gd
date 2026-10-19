extends GutTest

var cursor: MapCursor


func before_each() -> void:
	cursor = MapCursor.new()
	cursor.bounds = Rect2i(0, 0, 5, 5)
	add_child_autofree(cursor)
	watch_signals(cursor)


func test_move_steps_one_cell_and_emits() -> void:
	cursor.move(Vector2i.RIGHT)
	assert_eq(cursor.cell, Vector2i(1, 0))
	assert_signal_emitted_with_parameters(cursor, "moved", [Vector2i(1, 0)])


func test_move_is_clamped_to_bounds() -> void:
	cursor.move(Vector2i.LEFT)
	assert_eq(cursor.cell, Vector2i.ZERO, "can't leave the top-left")
	assert_signal_not_emitted(cursor, "moved", "nothing changed")
	cursor.set_cell(Vector2i(9, 9))
	assert_eq(cursor.cell, Vector2i(4, 4), "clamped to the last cell")


func test_set_cell_to_the_same_cell_is_silent() -> void:
	cursor.set_cell(Vector2i(2, 2))
	cursor.set_cell(Vector2i(2, 2))
	assert_signal_emit_count(cursor, "moved", 1)


func test_without_bounds_anything_goes() -> void:
	cursor.bounds = Rect2i()
	cursor.set_cell(Vector2i(-3, 40))
	assert_eq(cursor.cell, Vector2i(-3, 40))


func test_pulse_alternates_between_the_two_frames() -> void:
	assert_eq(cursor.frame, 0)
	cursor._process(1.0 / MapCursor.PULSE_FPS)
	assert_eq(cursor.frame, 1)
	cursor._process(1.0 / MapCursor.PULSE_FPS)
	assert_eq(cursor.frame, 0, "wraps back to the first frame")
