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
	var source := _source_for(terrain)
	# set_cell silently draws nothing for atlas coords without a tile.
	for coords in terrain.all_atlas_coords():
		if not source.has_tile(coords):
			source.create_tile(coords)


func source_id_for(terrain: TerrainType) -> int:
	return _source_ids.get(terrain.texture_path, -1)


func _source_for(terrain: TerrainType) -> TileSetAtlasSource:
	if _source_ids.has(terrain.texture_path):
		return tile_set.get_source(_source_ids[terrain.texture_path])
	var source := TileSetAtlasSource.new()
	source.texture = load(terrain.texture_path)
	source.texture_region_size = terrain.tile_size
	var id := tile_set.add_source(source)
	_source_ids[terrain.texture_path] = id
	return source
