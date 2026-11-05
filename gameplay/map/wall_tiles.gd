class_name WallTiles
extends RefCounted
## Picks the tile each wall and door cell draws from the wall sheet. Unlike terrain
## (see CornerMask) walls live on cells, and a wall's tile depends on which of its
## neighbouring cells are also wall. Doors count as wall for their neighbours, so a
## door in a run keeps the wall on both sides connected.
##
## The sheet is a 3x3 block:
##   top, left end   top, middle   top, right end
##   top, 1 wide     door          face, 1 wide
##   face, left end  face, middle  face, right end
## A wall with wall below it draws its flat top; otherwise its brick front face.

const TEXTURE_PATH := "res://assets/tilesets/wall_tileset.png"
const TILE_SIZE := Vector2i(16, 16)
const DOOR_COORDS := Vector2i(1, 1)
## Neighbour bits that pick a wall's tile. Walls above don't change it.
const LEFT := 1
const RIGHT := 2
const BELOW := 4

## Neighbour bits -> atlas coords.
const WALL_COORDS := {
	BELOW: Vector2i(0, 1),
	BELOW | RIGHT: Vector2i(0, 0),
	BELOW | LEFT | RIGHT: Vector2i(1, 0),
	BELOW | LEFT: Vector2i(2, 0),
	0: Vector2i(2, 1),
	RIGHT: Vector2i(0, 2),
	LEFT | RIGHT: Vector2i(1, 2),
	LEFT: Vector2i(2, 2),
}


## Every atlas coordinate walls and doors can draw; the TileSet needs a tile for each.
static func all_atlas_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = [DOOR_COORDS]
	for wall_coords: Vector2i in WALL_COORDS.values():
		coords.append(wall_coords)
	return coords


## cell -> atlas coords for every wall and door. A cell in both lists is a door.
static func cell_tiles(walls: Array[Vector2i], doors: Array[Vector2i]) -> Dictionary:
	var solid := {}
	for cell in walls:
		solid[cell] = true
	for cell in doors:
		solid[cell] = true

	var tiles := {}
	for cell in walls:
		tiles[cell] = WALL_COORDS[_neighbour_bits(cell, solid)]
	for cell in doors:
		tiles[cell] = DOOR_COORDS
	return tiles


static func _neighbour_bits(cell: Vector2i, solid: Dictionary) -> int:
	var bits := 0
	if solid.has(cell + Vector2i.LEFT):
		bits |= LEFT
	if solid.has(cell + Vector2i.RIGHT):
		bits |= RIGHT
	if solid.has(cell + Vector2i.DOWN):
		bits |= BELOW
	return bits
