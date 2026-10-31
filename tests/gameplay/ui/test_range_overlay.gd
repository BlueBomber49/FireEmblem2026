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


# --- Enemy threat (danger zone) ----------------------------------------------


func test_set_threat_stores_both_sets() -> void:
	overlay.set_threat({Vector2i(1, 1): true}, {Vector2i(2, 2): true, Vector2i(3, 2): true})
	assert_eq(overlay.threat_cells.size(), 1)
	assert_eq(overlay.marked_threat_cells.size(), 2)


func test_threat_and_own_ranges_are_independent() -> void:
	overlay.set_cells({Vector2i(1, 1): true}, {})
	overlay.set_threat({Vector2i(5, 5): true}, {})
	overlay.set_cells({}, {})
	assert_eq(overlay.threat_cells.size(), 1, "clearing the shimmer keeps the danger zone")


func test_a_single_cell_has_four_outline_edges() -> void:
	assert_eq(RangeOverlay.outline_edges({Vector2i(2, 3): true}).size(), 4)


func test_two_adjacent_cells_share_no_edge() -> void:
	var edges := RangeOverlay.outline_edges({Vector2i(2, 3): true, Vector2i(3, 3): true})
	assert_eq(edges.size(), 6, "the shared side isn't outlined")
	for edge: Array in edges:
		assert_false(edge[0] == Vector2i(3, 3) and edge[1] == Vector2i(3, 4), "no line between them")


func test_outline_edges_are_in_cell_corner_coordinates() -> void:
	var edges := RangeOverlay.outline_edges({Vector2i(0, 0): true})
	var corners := {}
	for edge: Array in edges:
		corners[edge[0]] = true
		corners[edge[1]] = true
	assert_eq(corners.size(), 4)
	for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		assert_true(corners.has(corner))
