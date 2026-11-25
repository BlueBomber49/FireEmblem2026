class_name WallTiles
extends RefCounted
## Picks the tile each wall, door and fort cell draws. Unlike terrain (see
## CornerMask) these live on cells, and a wall's or door's tile depends on which
## of its neighbouring cells are also wall. Doors count as wall for their
## neighbours, open or closed, so a door in a run keeps the wall on both sides
## connected.
##
## The wall sheet is a 3x3 block (its middle tile is unused):
##   top, left end   top, middle   top, right end
##   top, 1 wide     (unused)      face, 1 wide
##   face, left end  face, middle  face, right end
## A wall with wall below it draws its flat top; otherwise its brick front face.
##
## The door sheet is 2x2: closed on the left, open on the right; a door in a
## horizontal wall (wall to its left or right) on top, a door in a vertical wall
## (wall above or below) underneath. An open vertical door has no tile: it's gone.
##
## The fort sheet is a row of interchangeable looks; MapData.forts says which.

const TEXTURE_PATH := "res://assets/tilesets/wall_tileset.png"
const DOOR_TEXTURE_PATH := "res://assets/tilesets/door_tilesest.png"
const FORT_TEXTURE_PATH := "res://assets/tilesets/fort_tileset.png"
const TILE_SIZE := Vector2i(16, 16)
const DOOR_CLOSED_HORIZONTAL := Vector2i(0, 0)
const DOOR_OPEN_HORIZONTAL := Vector2i(1, 0)
const DOOR_CLOSED_VERTICAL := Vector2i(0, 1)
## How many fort looks the fort sheet has, left to right.
const FORT_VARIANTS := 2
## Neighbour bits that pick a wall's tile. Walls above don't change it.
const LEFT := 1
const RIGHT := 2
const BELOW := 4
## Only doors look at walls above them, to tell a vertical wall.
const ABOVE := 8

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


## Every atlas coordinate walls can draw; the TileSet needs a tile for each.
static func all_atlas_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for wall_coords: Vector2i in WALL_COORDS.values():
		coords.append(wall_coords)
	return coords


## Every atlas coordinate doors can draw.
static func all_door_atlas_coords() -> Array[Vector2i]:
	return [DOOR_CLOSED_HORIZONTAL, DOOR_OPEN_HORIZONTAL, DOOR_CLOSED_VERTICAL] as Array[Vector2i]


## Every atlas coordinate forts can draw.
static func all_fort_atlas_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for variant in FORT_VARIANTS:
		coords.append(fort_coords(variant))
	return coords


## Wall-sheet cell -> atlas coords for every wall. A cell that's also a door is
## left out: the door wins.
static func cell_tiles(walls: Array[Vector2i], doors: Array[Vector2i]) -> Dictionary:
	var solid := _solid(walls, doors)
	var tiles := {}
	for cell in walls:
		if not cell in doors:
			tiles[cell] = WALL_COORDS[_neighbour_bits(cell, solid) & ~ABOVE]
	return tiles


## Door-sheet cell -> atlas coords for every door, open or closed. Open vertical
## doors are left out (they draw nothing).
static func door_tiles(walls: Array[Vector2i], doors: Array[Vector2i], opened: Array[Vector2i]) -> Dictionary:
	var solid := _solid(walls, doors)
	var tiles := {}
	for cell in doors:
		var is_open := cell in opened
		if is_vertical_door(_neighbour_bits(cell, solid)):
			if not is_open:
				tiles[cell] = DOOR_CLOSED_VERTICAL
		else:
			tiles[cell] = DOOR_OPEN_HORIZONTAL if is_open else DOOR_CLOSED_HORIZONTAL
	return tiles


## Whether a door with these neighbour bits sits in a vertical wall: wall above
## or below it and none to its sides. Anything else (no walls at all, or walls on
## both axes) is horizontal.
static func is_vertical_door(bits: int) -> bool:
	return bits & (ABOVE | BELOW) != 0 and bits & (LEFT | RIGHT) == 0


## Fort-sheet atlas coords for fort look `variant` (out of range clamps).
static func fort_coords(variant: int) -> Vector2i:
	return Vector2i(clampi(variant, 0, FORT_VARIANTS - 1), 0)


static func _solid(walls: Array[Vector2i], doors: Array[Vector2i]) -> Dictionary:
	var solid := {}
	for cell in walls:
		solid[cell] = true
	for cell in doors:
		solid[cell] = true
	return solid


static func _neighbour_bits(cell: Vector2i, solid: Dictionary) -> int:
	var bits := 0
	if solid.has(cell + Vector2i.LEFT):
		bits |= LEFT
	if solid.has(cell + Vector2i.RIGHT):
		bits |= RIGHT
	if solid.has(cell + Vector2i.DOWN):
		bits |= BELOW
	if solid.has(cell + Vector2i.UP):
		bits |= ABOVE
	return bits
