class_name LevelTileSet
extends RefCounted
## One TileSet shared by every layer of a Level, with an atlas source per
## texture. Built from TerrainTypes at runtime.

var tile_set := TileSet.new()
## texture_path -> source id
var _source_ids: Dictionary = {}


func _init(tile_size := Vector2i(16, 16)) -> void:
	tile_set.tile_size = tile_size


func add_terrain(terrain: TerrainType) -> void:
	add_tiles(terrain.texture_path, terrain.tile_size, terrain.all_atlas_coords())


## Registers tiles from a texture and returns its source id.
func add_tiles(texture_path: String, region_size: Vector2i, coords: Array[Vector2i]) -> int:
	var source := _source_for(texture_path, region_size)
	# set_cell silently draws nothing for atlas coords without a tile.
	for c in coords:
		if not source.has_tile(c):
			source.create_tile(c)
	return _source_ids[texture_path]


func source_id_for(terrain: TerrainType) -> int:
	return _source_ids.get(terrain.texture_path, -1)


func _source_for(texture_path: String, region_size: Vector2i) -> TileSetAtlasSource:
	if _source_ids.has(texture_path):
		return tile_set.get_source(_source_ids[texture_path])
	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path)
	source.texture_region_size = region_size
	var id := tile_set.add_source(source)
	_source_ids[texture_path] = id
	return source
