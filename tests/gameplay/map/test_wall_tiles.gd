extends GutTest
## Which tile of the wall sheet each wall and door cell draws.

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


func test_door_draws_the_door_tile_and_connects_its_neighbours() -> void:
	var walls: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, -1)]
	var doors: Array[Vector2i] = [Vector2i(1, 0)]
	var tiles := WallTiles.cell_tiles(walls, doors)
	assert_eq(tiles[Vector2i(1, 0)], WallTiles.DOOR_COORDS)
	assert_eq(tiles[Vector2i(0, 0)], Vector2i(0, 2), "door on the right: left end")
	assert_eq(tiles[Vector2i(2, 0)], Vector2i(2, 2), "door on the left: right end")
	assert_eq(tiles[Vector2i(1, -1)], Vector2i(0, 1), "door below: draws the top")


func test_cell_in_both_lists_is_a_door() -> void:
	var cell: Array[Vector2i] = [CENTER]
	assert_eq(WallTiles.cell_tiles(cell, cell)[CENTER], WallTiles.DOOR_COORDS)


func test_every_tile_is_registered() -> void:
	var coords := WallTiles.all_atlas_coords()
	assert_eq(coords.size(), 9, "the whole 3x3 sheet")
	for x in 3:
		for y in 3:
			assert_true(coords.has(Vector2i(x, y)), "%d,%d" % [x, y])
