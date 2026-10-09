extends GutTest

const SAMPLE := {
	"layers": {
		"water": {"z": 0.0, "terrain": "water", "verts": [[1.0, 1.0], [2.0, 1.0], [1.0, 2.0], [2.0, 2.0]]},
		"grass": {"z": 1.0, "terrain": "grass", "verts": [[2.0, 2.0]]},
	},
	"structures": {"houses": []},
	"units": {
		"lyn": {
			"name": "Lyn", "unit_class": "SwordFighter", "faction": "player", "level": 1.0,
			"stats": {"hp": 16.0, "str": 5.0, "mov": 5.0},
			"sprite_sheet": "res://x.png", "start_cell": [2.0, 2.0], "facing": [1.0, 0.0],
		},
		"bandit": {"name": "Bandit", "faction": "enemy", "stats": {"hp": 20.0}, "start_cell": [4.0, 4.0]},
	},
}


func test_layers_round_trip() -> void:
	var data := MapData.fromJson(SAMPLE)
	assert_eq(data.layerData.layers.size(), 2)
	var grass: MapLayer = data.layerData.layers["grass"]
	assert_eq(grass.name, "grass")
	assert_eq(grass.z, 1)
	assert_eq(grass.terrain, "grass")
	assert_eq(grass.verts, [Vector2i(2, 2)] as Array[Vector2i])
	assert_typeof(grass.z, TYPE_INT)

	var again := MapData.fromJson(data.toJson())
	assert_eq(again.toJson(), data.toJson())
	assert_eq(again.layerData.structures, {"houses": []})


func test_sorted_layers_by_z() -> void:
	var data := MapData.fromJson(SAMPLE)
	var names := []
	for layer in data.layerData.sorted_layers():
		names.append(layer.name)
	assert_eq(names, ["water", "grass"])


func test_drawn_cells_is_union() -> void:
	var data := MapData.fromJson(SAMPLE)
	var cells := data.layerData.drawn_cells()
	# The 2x2 water block draws a 3x3 ring of cells from (0,0) to (2,2).
	assert_eq(cells.size(), 9)
	assert_true(data.layerData.is_drawn(Vector2i(0, 0)))
	assert_true(data.layerData.is_drawn(Vector2i(2, 2)))
	assert_false(data.layerData.is_drawn(Vector2i(3, 3)))
	assert_false(data.layerData.is_drawn(Vector2i(-1, -1)))


func test_bounds() -> void:
	var data := MapData.fromJson(SAMPLE)
	assert_eq(data.layerData.bounds(), Rect2i(0, 0, 3, 3))
	assert_eq(MapLayersData.new().bounds(), Rect2i())


func test_units_keyed_by_id() -> void:
	var data := MapData.fromJson(SAMPLE)
	assert_eq(data.units.size(), 2)
	var lyn: UnitReference = data.units["lyn"]
	assert_eq(lyn.id, "lyn")
	assert_eq(lyn.faction, UnitReference.Faction.PLAYER)
	assert_eq(lyn.stat(&"hp"), 16)
	assert_eq(lyn.start_cell, Vector2i(2, 2))
	assert_eq(lyn.facing, Vector2i.RIGHT)
	var bandit: UnitReference = data.units["bandit"]
	assert_eq(bandit.faction, UnitReference.Faction.ENEMY)
	assert_eq(bandit.facing, Vector2i.DOWN, "facing defaults to down")

	var again := MapData.fromJson(data.toJson())
	assert_eq(again.units.keys(), data.units.keys())
	assert_eq(again.units["lyn"].toJson(), lyn.toJson())
