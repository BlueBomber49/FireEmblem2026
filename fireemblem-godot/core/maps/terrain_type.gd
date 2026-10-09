class_name TerrainType
extends Resource
## Describes where a terrain's 15 area tiles live in a texture atlas.
##
## The default layout is a 5x3 block (see assets/art/grass.png):
##   corner_tl  edge_top     corner_tr | inner(no TL) inner(no TR)
##   edge_left  fill         edge_right| inner(no BL) inner(no BR)
##   corner_bl  edge_bottom  corner_br | diag TR+BL   diag TL+BR
## Instances live in data/terrain/<id>.tres.

const TERRAIN_DIR := "res://data/terrain/"

## CornerMask -> atlas offset from `atlas_origin`.
const DEFAULT_LAYOUT := {
	CornerMask.BR: Vector2i(0, 0),
	CornerMask.BL | CornerMask.BR: Vector2i(1, 0),
	CornerMask.BL: Vector2i(2, 0),
	CornerMask.TR | CornerMask.BR: Vector2i(0, 1),
	CornerMask.FILL: Vector2i(1, 1),
	CornerMask.TL | CornerMask.BL: Vector2i(2, 1),
	CornerMask.TR: Vector2i(0, 2),
	CornerMask.TL | CornerMask.TR: Vector2i(1, 2),
	CornerMask.TL: Vector2i(2, 2),
	CornerMask.TR | CornerMask.BL | CornerMask.BR: Vector2i(3, 0),
	CornerMask.TL | CornerMask.BL | CornerMask.BR: Vector2i(4, 0),
	CornerMask.TL | CornerMask.TR | CornerMask.BR: Vector2i(3, 1),
	CornerMask.TL | CornerMask.TR | CornerMask.BL: Vector2i(4, 1),
	CornerMask.TR | CornerMask.BL: Vector2i(3, 2),
	CornerMask.TL | CornerMask.BR: Vector2i(4, 2),
}

@export var id: String
## Kept as a path rather than a Texture2D so core stays asset-free.
@export var texture_path: String
@export var tile_size := Vector2i(16, 16)
## Top-left tile of the 5x3 block within the atlas.
@export var atlas_origin := Vector2i.ZERO
## When set, every mask draws this one tile (base fills such as water).
@export var single_tile := Vector2i(-1, -1)
## mask -> absolute atlas coords, for atlases that don't follow DEFAULT_LAYOUT.
@export var overrides: Dictionary = {}


static func load_by_id(terrain_id: String) -> TerrainType:
	return load(TERRAIN_DIR + terrain_id + ".tres") as TerrainType


func has_single_tile() -> bool:
	return single_tile.x >= 0 and single_tile.y >= 0


func atlas_coords(mask: int) -> Vector2i:
	if has_single_tile():
		return single_tile
	if overrides.has(mask):
		return overrides[mask]
	return atlas_origin + DEFAULT_LAYOUT[mask]


## Every atlas coordinate this terrain can draw; the TileSet needs a tile for each.
func all_atlas_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if has_single_tile():
		coords.append(single_tile)
		return coords
	for mask in DEFAULT_LAYOUT:
		var c := atlas_coords(mask)
		if not coords.has(c):
			coords.append(c)
	return coords
