class_name ChestTiles
extends RefCounted
## The chest sheet: two 16x16 frames, closed then open. Unlike walls, a chest's
## tile depends only on whether it has been opened.

const TEXTURE_PATH := "res://assets/tilesets/chest_tileset.png"
const TILE_SIZE := Vector2i(16, 16)
const CLOSED_COORDS := Vector2i(0, 0)
const OPEN_COORDS := Vector2i(1, 0)


static func all_atlas_coords() -> Array[Vector2i]:
	return [CLOSED_COORDS, OPEN_COORDS]


## cell -> atlas coords for every chest; those in `opened` draw open.
static func cell_tiles(chests: Dictionary, opened: Array[Vector2i]) -> Dictionary:
	var tiles := {}
	for cell: Vector2i in chests:
		tiles[cell] = OPEN_COORDS if cell in opened else CLOSED_COORDS
	return tiles
