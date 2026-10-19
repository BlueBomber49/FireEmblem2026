extends GutTest


func test_default_layout_covers_all_fifteen_masks() -> void:
	assert_eq(TerrainType.DEFAULT_LAYOUT.size(), 15)
	for mask in range(1, 16):
		assert_true(TerrainType.DEFAULT_LAYOUT.has(mask), "mask %d" % mask)
	var seen := {}
	for offset in TerrainType.DEFAULT_LAYOUT.values():
		assert_true(offset.x >= 0 and offset.x < 5 and offset.y >= 0 and offset.y < 3, str(offset))
		seen[offset] = true
	assert_eq(seen.size(), 15, "offsets are distinct")


func test_grass_layout_matches_art() -> void:
	var t := TerrainType.new()
	assert_eq(t.atlas_coords(CornerMask.FILL), Vector2i(1, 1))
	assert_eq(t.atlas_coords(CornerMask.BR), Vector2i(0, 0), "top-left corner tile")
	assert_eq(t.atlas_coords(CornerMask.TL), Vector2i(2, 2), "bottom-right corner tile")
	assert_eq(t.atlas_coords(CornerMask.TR | CornerMask.BL), Vector2i(3, 2))
	assert_eq(t.atlas_coords(CornerMask.TL | CornerMask.BR), Vector2i(4, 2))


func test_atlas_origin_offsets_every_tile() -> void:
	var t := TerrainType.new()
	t.atlas_origin = Vector2i(10, 20)
	assert_eq(t.atlas_coords(CornerMask.FILL), Vector2i(11, 21))
	assert_eq(t.all_atlas_coords().size(), 15)


func test_single_tile_wins() -> void:
	var t := TerrainType.new()
	t.single_tile = Vector2i(0, 13)
	assert_eq(t.atlas_coords(CornerMask.FILL), Vector2i(0, 13))
	assert_eq(t.atlas_coords(CornerMask.TL), Vector2i(0, 13))
	assert_eq(t.all_atlas_coords(), [Vector2i(0, 13)])


func test_overrides_replace_default() -> void:
	var t := TerrainType.new()
	t.overrides = {CornerMask.FILL: Vector2i(7, 7)}
	assert_eq(t.atlas_coords(CornerMask.FILL), Vector2i(7, 7))
	assert_eq(t.atlas_coords(CornerMask.TL), Vector2i(2, 2))
	assert_true(t.all_atlas_coords().has(Vector2i(7, 7)))
