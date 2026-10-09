class_name CornerMask
extends RefCounted
## Turns a layer's set of terrain vertices into the tiles that must be drawn.
##
## A drawn tile at cell (x, y) has four corner vertices. Which of those are
## in the layer's vertex set forms a 4-bit mask; each of the 15 non-empty masks
## picks one tile of a 15-tile "area" tileset (see TerrainType.DEFAULT_LAYOUT).

const TL := 1
const TR := 2
const BL := 4
const BR := 8
const FILL := TL | TR | BL | BR

## Offset from a cell to each of its corner vertices, paired with that corner's bit.
const CORNERS := [
	[Vector2i(0, 0), TL],
	[Vector2i(1, 0), TR],
	[Vector2i(0, 1), BL],
	[Vector2i(1, 1), BR],
]


## Mask for `cell` given a set of vertices (a Dictionary used as a set).
static func mask_at(cell: Vector2i, vert_set: Dictionary) -> int:
	var mask := 0
	for corner in CORNERS:
		if vert_set.has(cell + corner[0]):
			mask |= corner[1]
	return mask


## Every cell touched by `verts`, mapped to its mask. Cells with mask 0 are left out.
static func cell_masks(verts: Array[Vector2i]) -> Dictionary:
	var vert_set := {}
	for v in verts:
		vert_set[v] = true

	var masks := {}
	for v in verts:
		# A vertex is a corner of the four cells around it.
		for corner in CORNERS:
			var cell: Vector2i = v - corner[0]
			if masks.has(cell):
				continue
			var mask := mask_at(cell, vert_set)
			if mask != 0:
				masks[cell] = mask
	return masks
