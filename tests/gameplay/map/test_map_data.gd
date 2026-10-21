extends GutTest

const SAMPLE := {
	"layers": {
		"water": {"z": 0.0, "terrain": "water", "verts": [[1.0, 1.0], [2.0, 1.0], [1.0, 2.0], [2.0, 2.0]]},
		"grass": {"z": 1.0, "terrain": "grass", "verts": [[2.0, 2.0]]},
	},
	"structures": {"houses": []},
	"units": {
		"lyn": {
			"character": "lyn", "faction": "player",
			"sprite_sheet": "res://x.png", "start_cell": [2.0, 2.0], "facing": [1.0, 0.0],
		},
		"bandit": {"class": "fighter", "name": "Bandit", "faction": "enemy", "stats": {"hp": 20.0}, "start_cell": [4.0, 4.0]},
	},
}


func test_layers_round_trip() -> void:
	var data := MapData.fromJson(SAMPLE)
	assert_eq(data.layers.size(), 2)
	var grass: MapLayer = data.layers["grass"]
	assert_eq(grass.name, "grass")
	assert_eq(grass.z, 1)
	assert_eq(grass.terrain, "grass")
	assert_eq(grass.verts, [Vector2i(2, 2)] as Array[Vector2i])
	assert_typeof(grass.z, TYPE_INT)

	var again := MapData.fromJson(data.toJson())
	assert_eq(again.toJson(), data.toJson())
	assert_eq(again.structures, {"houses": []})


func test_sorted_layers_by_z() -> void:
	var data := MapData.fromJson(SAMPLE)
	var names := []
	for layer in data.sorted_layers():
		names.append(layer.name)
	assert_eq(names, ["water", "grass"])


func test_drawn_cells_is_union() -> void:
	var data := MapData.fromJson(SAMPLE)
	var cells := data.drawn_cells()
	# The 2x2 water block draws a 3x3 ring of cells from (0,0) to (2,2).
	assert_eq(cells.size(), 9)
	assert_true(data.is_drawn(Vector2i(0, 0)))
	assert_true(data.is_drawn(Vector2i(2, 2)))
	assert_false(data.is_drawn(Vector2i(3, 3)))
	assert_false(data.is_drawn(Vector2i(-1, -1)))


func test_bounds() -> void:
	var data := MapData.fromJson(SAMPLE)
	assert_eq(data.bounds(), Rect2i(0, 0, 3, 3))
	assert_eq(MapData.new().bounds(), Rect2i())


# --- Rules terrain (majority rule) -------------------------------------------
# Cell (1, 1) has corners (1,1) (2,1) (1,2) (2,2).


func _verts(points: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in points:
		out.append(Vector2i(p[0], p[1]))
	return out


## Every vertex from (0, 0) to (4, 4): a full base layer under cell (1, 1).
func _full_block() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in 5:
		for y in 5:
			out.append(Vector2i(x, y))
	return out


func _map(layers: Array[MapLayer]) -> MapData:
	var data := MapData.new()
	for layer in layers:
		data.layers[layer.name] = layer
	return data


func test_rules_terrain_four_corners() -> void:
	var data := _map([
		MapLayer.new("water", 0, "water", _full_block()),
		MapLayer.new("grass", 1, "grass", _verts([[1, 1], [2, 1], [1, 2], [2, 2]])),
	])
	assert_eq(data.rules_terrain_at(Vector2i(1, 1)), "grass")


func test_rules_terrain_three_corners_is_enough() -> void:
	var data := _map([
		MapLayer.new("water", 0, "water", _full_block()),
		MapLayer.new("grass", 1, "grass", _verts([[1, 1], [2, 1], [1, 2]])),
	])
	assert_eq(data.rules_terrain_at(Vector2i(1, 1)), "grass")


func test_rules_terrain_one_grass_corner_on_water_is_water() -> void:
	var data := _map([
		MapLayer.new("water", 0, "water", _full_block()),
		MapLayer.new("grass", 1, "grass", _verts([[1, 1]])),
	])
	assert_eq(data.rules_terrain_at(Vector2i(1, 1)), "water", "a mostly-water shore cell")


func test_rules_terrain_split_without_majority_takes_most_corners() -> void:
	var data := _map([
		MapLayer.new("dirt", 0, "dirt", _verts([[2, 1], [1, 2]])),
		MapLayer.new("grass", 1, "grass", _verts([[1, 1]])),
	])
	assert_eq(data.rules_terrain_at(Vector2i(1, 1)), "dirt", "2 dirt corners beat 1 grass corner")


func test_rules_terrain_tie_goes_to_higher_layer() -> void:
	var data := _map([
		MapLayer.new("dirt", 0, "dirt", _verts([[1, 1], [2, 1]])),
		MapLayer.new("grass", 1, "grass", _verts([[1, 2], [2, 2]])),
	])
	assert_eq(data.rules_terrain_at(Vector2i(1, 1)), "grass")


func test_rules_terrain_mostly_blank_edge_cell_is_empty() -> void:
	var data := _map([MapLayer.new("grass", 0, "grass", _verts([[1, 1], [2, 1]]))])
	assert_eq(data.rules_terrain_at(Vector2i(1, 1)), "", "only 2 corners painted, nothing underneath")


func test_rules_terrain_undrawn_cell_is_empty() -> void:
	var data := _map([MapLayer.new("water", 0, "water", _full_block())])
	assert_eq(data.rules_terrain_at(Vector2i(20, 20)), "")


# Half-edges: a straight 2-corner edge counts for terrain whose rules say so (forest),
# because the art shows half a tile of it. Diagonal pairs and single nubs don't.


func test_half_edge_of_trees_counts_as_forest() -> void:
	var data := _map([
		MapLayer.new("grass", 0, "grass", _full_block()),
		MapLayer.new("trees", 1, "trees", _verts([[1, 1], [2, 1]])),
	])
	assert_eq(data.rules_terrain_at(Vector2i(1, 1)), "trees", "top half is trees")
	var side := _map([
		MapLayer.new("grass", 0, "grass", _full_block()),
		MapLayer.new("trees", 1, "trees", _verts([[2, 1], [2, 2]])),
	])
	assert_eq(side.rules_terrain_at(Vector2i(1, 1)), "trees", "right half is trees")


func test_diagonal_trees_dont_count() -> void:
	var data := _map([
		MapLayer.new("grass", 0, "grass", _full_block()),
		MapLayer.new("trees", 1, "trees", _verts([[1, 1], [2, 2]])),
	])
	assert_eq(data.rules_terrain_at(Vector2i(1, 1)), "grass", "two opposite nubs: mostly grass")


func test_single_tree_nub_doesnt_count() -> void:
	var data := _map([
		MapLayer.new("grass", 0, "grass", _full_block()),
		MapLayer.new("trees", 1, "trees", _verts([[1, 1]])),
	])
	assert_eq(data.rules_terrain_at(Vector2i(1, 1)), "grass")


func test_half_edge_of_grass_on_water_is_still_water() -> void:
	# Plains don't count half-edges, so shores keep the 3-corner rule.
	var data := _map([
		MapLayer.new("water", 0, "water", _full_block()),
		MapLayer.new("grass", 1, "grass", _verts([[1, 1], [2, 1]])),
	])
	assert_eq(data.rules_terrain_at(Vector2i(1, 1)), "water")


func test_rules_terrain_cache_refreshes_after_invalidate() -> void:
	var grass := MapLayer.new("grass", 1, "grass", _verts([[1, 1], [2, 1], [1, 2], [2, 2]]))
	var data := _map([MapLayer.new("water", 0, "water", _full_block()), grass])
	assert_eq(data.rules_terrain_at(Vector2i(1, 1)), "grass")
	grass.verts = _verts([[1, 1]])
	data.invalidate_terrain_cache()
	assert_eq(data.rules_terrain_at(Vector2i(1, 1)), "water")


func test_units_keyed_by_id() -> void:
	var data := MapData.fromJson(SAMPLE)
	assert_eq(data.units.size(), 2)
	var lyn: UnitReference = data.units["lyn"]
	assert_eq(lyn.id, "lyn")
	assert_eq(lyn.faction, UnitReference.Faction.PLAYER)
	assert_eq(lyn.character_id, "lyn")
	assert_eq(lyn.start_cell, Vector2i(2, 2))
	assert_eq(lyn.facing, Vector2i.RIGHT)
	var bandit: UnitReference = data.units["bandit"]
	assert_eq(bandit.faction, UnitReference.Faction.ENEMY)
	assert_eq(bandit.facing, Vector2i.DOWN, "facing defaults to down")

	var again := MapData.fromJson(data.toJson())
	assert_eq(again.units.keys(), data.units.keys())
	assert_eq(again.units["lyn"].toJson(), lyn.toJson())


func test_unknown_character_survives_a_save_and_is_only_skipped_in_play() -> void:
	var d := SAMPLE.duplicate(true)
	d["units"]["typo"] = {"character": "lynn", "faction": "player", "start_cell": [1.0, 1.0], "notes": "keep me"}
	var data := MapData.fromJson(d)
	assert_true(data.units.has("typo"), "kept in the map data")
	var again := MapData.fromJson(JSON.parse_string(JSON.stringify(data.toJson())))
	assert_eq(again.units["typo"].character_id, "lynn")
	assert_eq(again.units["typo"].toJson()["notes"], "keep me")
	var states := LevelUnitState.build_all(again.units, {})
	assert_false(states.has("typo"), "skipped only when building play states")
	assert_eq(states.size(), 2)
	assert_push_warning("typo")
