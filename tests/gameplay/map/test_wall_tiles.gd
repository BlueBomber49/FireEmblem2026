extends GutTest
## Which tile of which sheet each wall, door and fort cell draws.

const CENTER := Vector2i(5, 5)


## The tile drawn at CENTER with walls on the given sides of it.
func _center_tile(neighbours: Array[Vector2i]) -> Vector2i:
	var walls: Array[Vector2i] = [CENTER]
	for offset in neighbours:
		walls.append(CENTER + offset)
	return WallTiles.cell_tiles(walls, [] as Array[Vector2i])[CENTER]


func test_wall_below_draws_the_top() -> void:
	assert_eq(_center_tile([Vector2i.DOWN]), Vector2i(0, 1), "1 wide")
	assert_eq(_center_tile([Vector2i.DOWN, Vector2i.RIGHT]), Vector2i(0, 0), "left end")
	assert_eq(_center_tile([Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]), Vector2i(1, 0), "middle")
	assert_eq(_center_tile([Vector2i.DOWN, Vector2i.LEFT]), Vector2i(2, 0), "right end")


func test_no_wall_below_draws_the_face() -> void:
	assert_eq(_center_tile([]), Vector2i(2, 1), "1 wide")
	assert_eq(_center_tile([Vector2i.RIGHT]), Vector2i(0, 2), "left end")
	assert_eq(_center_tile([Vector2i.LEFT, Vector2i.RIGHT]), Vector2i(1, 2), "middle")
	assert_eq(_center_tile([Vector2i.LEFT]), Vector2i(2, 2), "right end")


func test_wall_above_does_not_change_the_tile() -> void:
	assert_eq(_center_tile([Vector2i.UP]), _center_tile([]))
	assert_eq(_center_tile([Vector2i.UP, Vector2i.DOWN]), _center_tile([Vector2i.DOWN]))


func test_door_connects_its_neighbours_and_draws_from_the_door_sheet() -> void:
	var walls: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, -1)]
	var doors: Array[Vector2i] = [Vector2i(1, 0)]
	var tiles := WallTiles.cell_tiles(walls, doors)
	assert_false(tiles.has(Vector2i(1, 0)), "the door isn't on the wall sheet")
	assert_eq(tiles[Vector2i(0, 0)], Vector2i(0, 2), "door on the right: left end")
	assert_eq(tiles[Vector2i(2, 0)], Vector2i(2, 2), "door on the left: right end")
	assert_eq(tiles[Vector2i(1, -1)], Vector2i(0, 1), "door below: draws the top")


func test_cell_in_both_lists_is_a_door() -> void:
	var cell: Array[Vector2i] = [CENTER]
	assert_false(WallTiles.cell_tiles(cell, cell).has(CENTER))
	assert_true(WallTiles.door_tiles(cell, cell, [] as Array[Vector2i]).has(CENTER))


## The door-sheet tile at CENTER with walls on the given sides, open or closed.
func _door_tile(neighbours: Array[Vector2i], is_open := false) -> Variant:
	var walls: Array[Vector2i] = []
	for offset in neighbours:
		walls.append(CENTER + offset)
	var doors: Array[Vector2i] = [CENTER]
	var opened: Array[Vector2i] = []
	if is_open:
		opened.append(CENTER)
	return WallTiles.door_tiles(walls, doors, opened).get(CENTER)


func test_door_in_a_horizontal_wall() -> void:
	assert_eq(_door_tile([Vector2i.LEFT, Vector2i.RIGHT]), WallTiles.DOOR_CLOSED_HORIZONTAL)
	assert_eq(_door_tile([Vector2i.LEFT]), WallTiles.DOOR_CLOSED_HORIZONTAL, "one side is enough")
	assert_eq(_door_tile([Vector2i.LEFT, Vector2i.RIGHT], true), WallTiles.DOOR_OPEN_HORIZONTAL)


func test_door_in_a_vertical_wall() -> void:
	assert_eq(_door_tile([Vector2i.UP, Vector2i.DOWN]), WallTiles.DOOR_CLOSED_VERTICAL)
	assert_eq(_door_tile([Vector2i.UP]), WallTiles.DOOR_CLOSED_VERTICAL, "one side is enough")
	assert_null(_door_tile([Vector2i.UP, Vector2i.DOWN], true), "an open vertical door is gone")


func test_lone_or_cornered_door_is_horizontal() -> void:
	assert_eq(_door_tile([]), WallTiles.DOOR_CLOSED_HORIZONTAL, "no walls")
	assert_eq(_door_tile([Vector2i.UP, Vector2i.RIGHT]), WallTiles.DOOR_CLOSED_HORIZONTAL, "a corner")


func test_fort_looks() -> void:
	assert_eq(WallTiles.fort_coords(0), Vector2i(0, 0))
	assert_eq(WallTiles.fort_coords(1), Vector2i(1, 0))
	assert_eq(WallTiles.fort_coords(99), Vector2i(WallTiles.FORT_VARIANTS - 1, 0), "out of range clamps")
	assert_eq(WallTiles.all_fort_atlas_coords().size(), WallTiles.FORT_VARIANTS)


func test_every_wall_tile_is_registered() -> void:
	var coords := WallTiles.all_atlas_coords()
	assert_eq(coords.size(), 8, "the 3x3 sheet but its unused middle")
	for x in 3:
		for y in 3:
			if Vector2i(x, y) != Vector2i(1, 1):
				assert_true(coords.has(Vector2i(x, y)), "%d,%d" % [x, y])
