extends GutTest

const O := Vector2i(5, 5)


func _cells(offsets: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset in offsets:
		out.append(O + offset)
	return out


func test_tail_faces_the_way_the_path_leaves() -> void:
	assert_eq(PathArrow.tile_at(_cells([Vector2i.ZERO, Vector2i.RIGHT]), 0), Vector2i(0, 0))
	assert_eq(PathArrow.tile_at(_cells([Vector2i.ZERO, Vector2i.DOWN]), 0), Vector2i(1, 0))
	assert_eq(PathArrow.tile_at(_cells([Vector2i.ZERO, Vector2i.UP]), 0), Vector2i(2, 0))
	assert_eq(PathArrow.tile_at(_cells([Vector2i.ZERO, Vector2i.LEFT]), 0), Vector2i(3, 0))


func test_head_points_the_way_the_path_arrives() -> void:
	assert_eq(PathArrow.tile_at(_cells([Vector2i.ZERO, Vector2i.RIGHT]), 1), Vector2i(0, 2))
	assert_eq(PathArrow.tile_at(_cells([Vector2i.ZERO, Vector2i.DOWN]), 1), Vector2i(1, 2))
	assert_eq(PathArrow.tile_at(_cells([Vector2i.ZERO, Vector2i.LEFT]), 1), Vector2i(0, 3))
	assert_eq(PathArrow.tile_at(_cells([Vector2i.ZERO, Vector2i.UP]), 1), Vector2i(1, 3))


func test_straights() -> void:
	var across := _cells([Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0)])
	assert_eq(PathArrow.tile_at(across, 1), Vector2i(0, 1), "left-right")
	var down := _cells([Vector2i.ZERO, Vector2i.DOWN, Vector2i(0, 2)])
	assert_eq(PathArrow.tile_at(down, 1), Vector2i(1, 1), "up-down")
	var back := _cells([Vector2i(2, 0), Vector2i.RIGHT, Vector2i.ZERO])
	assert_eq(PathArrow.tile_at(back, 1), Vector2i(0, 1), "same tile going the other way")


func test_corners_are_keyed_by_the_two_sides_used() -> void:
	# Entering from the left side, leaving through the bottom: left+down.
	assert_eq(PathArrow.tile_at(_cells([Vector2i.LEFT, Vector2i.ZERO, Vector2i.DOWN]), 1), Vector2i(3, 1))
	assert_eq(PathArrow.tile_at(_cells([Vector2i.RIGHT, Vector2i.ZERO, Vector2i.DOWN]), 1), Vector2i(2, 1))
	assert_eq(PathArrow.tile_at(_cells([Vector2i.UP, Vector2i.ZERO, Vector2i.RIGHT]), 1), Vector2i(2, 2))
	assert_eq(PathArrow.tile_at(_cells([Vector2i.UP, Vector2i.ZERO, Vector2i.LEFT]), 1), Vector2i(3, 2))
	assert_eq(PathArrow.tile_at(_cells([Vector2i.DOWN, Vector2i.ZERO, Vector2i.LEFT]), 1), Vector2i(3, 1),
			"coming up and turning left uses the same sides as coming from the left and going down")


func test_set_path_redraws() -> void:
	var arrow := PathArrow.new()
	add_child_autofree(arrow)
	watch_signals(arrow)
	arrow.set_path(_cells([Vector2i.ZERO, Vector2i.RIGHT]))
	await wait_process_frames(2)
	assert_signal_emitted(arrow, "draw")
	assert_eq(arrow.path.size(), 2)
