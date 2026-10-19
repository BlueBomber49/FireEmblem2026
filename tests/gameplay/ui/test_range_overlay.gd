extends GutTest

var overlay: RangeOverlay


func before_each() -> void:
	overlay = RangeOverlay.new()
	add_child_autofree(overlay)


func test_set_cells_stores_both_sets() -> void:
	overlay.set_cells({Vector2i(1, 1): true}, {Vector2i(2, 2): true})
	assert_eq(overlay.move_cells.size(), 1)
	assert_eq(overlay.attack_cells.size(), 1)


func test_frames_advance_and_wrap() -> void:
	overlay.set_cells({Vector2i(1, 1): true}, {})
	assert_eq(overlay.frame, 0)
	overlay._process(1.0 / RangeOverlay.FPS)
	assert_eq(overlay.frame, 1)
	for i in RangeOverlay.FRAME_COUNT - 1:
		overlay._process(1.0 / RangeOverlay.FPS)
	assert_eq(overlay.frame, 0, "wraps after the last frame")


func test_empty_overlay_does_not_animate() -> void:
	overlay._process(1.0)
	assert_eq(overlay.frame, 0)
