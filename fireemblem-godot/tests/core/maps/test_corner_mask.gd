extends GutTest


func _verts(cells: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(c)
	return out


func test_empty_verts_draw_nothing() -> void:
	assert_eq(CornerMask.cell_masks(_verts([])), {})


func test_single_vert_touches_four_cells() -> void:
	var masks := CornerMask.cell_masks(_verts([Vector2i(5, 5)]))
	assert_eq(masks.size(), 4)
	# The vertex is the BR corner of the cell up-left of it, and so on.
	assert_eq(masks[Vector2i(4, 4)], CornerMask.BR)
	assert_eq(masks[Vector2i(5, 4)], CornerMask.BL)
	assert_eq(masks[Vector2i(4, 5)], CornerMask.TR)
	assert_eq(masks[Vector2i(5, 5)], CornerMask.TL)


func test_two_by_two_block_has_fill_edges_and_corners() -> void:
	var masks := CornerMask.cell_masks(_verts([
		Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(1, 2), Vector2i(2, 2),
	]))
	assert_eq(masks.size(), 9)
	assert_eq(masks[Vector2i(1, 1)], CornerMask.FILL)
	assert_eq(masks[Vector2i(1, 0)], CornerMask.BL | CornerMask.BR, "top edge")
	assert_eq(masks[Vector2i(1, 2)], CornerMask.TL | CornerMask.TR, "bottom edge")
	assert_eq(masks[Vector2i(0, 1)], CornerMask.TR | CornerMask.BR, "left edge")
	assert_eq(masks[Vector2i(2, 1)], CornerMask.TL | CornerMask.BL, "right edge")
	assert_eq(masks[Vector2i(0, 0)], CornerMask.BR, "top-left corner")
	assert_eq(masks[Vector2i(2, 0)], CornerMask.BL, "top-right corner")
	assert_eq(masks[Vector2i(0, 2)], CornerMask.TR, "bottom-left corner")
	assert_eq(masks[Vector2i(2, 2)], CornerMask.TL, "bottom-right corner")


func test_diagonal_pair() -> void:
	var masks := CornerMask.cell_masks(_verts([Vector2i(1, 0), Vector2i(0, 1)]))
	assert_eq(masks[Vector2i(0, 0)], CornerMask.TR | CornerMask.BL)
	var masks2 := CornerMask.cell_masks(_verts([Vector2i(0, 0), Vector2i(1, 1)]))
	assert_eq(masks2[Vector2i(0, 0)], CornerMask.TL | CornerMask.BR)


func test_three_corners_is_inner_corner() -> void:
	var masks := CornerMask.cell_masks(_verts([Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]))
	assert_eq(masks[Vector2i(0, 0)], CornerMask.TR | CornerMask.BL | CornerMask.BR)


func test_never_contains_mask_zero() -> void:
	var masks := CornerMask.cell_masks(_verts([Vector2i(0, 0), Vector2i(3, 3)]))
	for cell in masks:
		assert_ne(masks[cell], 0)


func test_duplicate_verts_are_harmless() -> void:
	var a := CornerMask.cell_masks(_verts([Vector2i(2, 2)]))
	var b := CornerMask.cell_masks(_verts([Vector2i(2, 2), Vector2i(2, 2)]))
	assert_eq(a, b)
