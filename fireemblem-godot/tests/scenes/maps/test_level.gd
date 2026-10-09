extends GutTest

const LEVEL_PATH := "res://data/maps/test_level.json"


func _loaded_level() -> Level:
	var level := Level.new()
	add_child_autofree(level)
	assert_eq(level.load_file(LEVEL_PATH), OK)
	return level


func test_fresh_load_builds_states_from_map_units() -> void:
	var level := _loaded_level()
	assert_eq(level.level_units.size(), level.map_data.units.size())
	var lyn: LevelUnitState = level.level_units["lyn"]
	assert_eq(lyn.cell, level.map_data.units["lyn"].start_cell)
	assert_eq(lyn.current_hp, level.map_data.units["lyn"].stat(&"hp"))


func test_to_tscn_builds_layers_units_and_astar() -> void:
	var level := _loaded_level()
	level.toTscn()
	assert_eq(level.layers_root.get_child_count(), 2)
	assert_eq(level.layers_root.get_child(0).name, "water", "lowest z first")
	assert_eq(level.layers_root.get_child(1).name, "grass")
	var grass: TileMapLayer = level.layers_root.get_child(1)
	assert_eq(grass.get_used_cells().size(), level.map_data.layerData.layers["grass"].cell_masks().size())
	assert_eq(grass.get_cell_atlas_coords(Vector2i(6, 5)), Vector2i(1, 1), "fill tile inside the blob")
	assert_eq(grass.get_cell_atlas_coords(Vector2i(12, 9)), Vector2i(4, 2), "diagonal tile")

	assert_eq(level.unit_nodes.size(), 3)
	assert_eq(level.unit_at(Vector2i(6, 5)).reference.id, "lyn")
	assert_almost_eq(level.unit_nodes["lyn"].global_position, Vector2(104, 88), Vector2(0.01, 0.01))

	assert_true(level.is_walkable(Vector2i(0, 0)), "water edge is drawn, so walkable for now")
	assert_false(level.is_walkable(Vector2i(30, 30)), "outside every layer")
	assert_eq(level.find_path(level.unit_nodes["lyn"], Vector2i(8, 5)).size(), 3)


func test_to_tscn_is_idempotent() -> void:
	var level := _loaded_level()
	level.toTscn()
	level.toTscn()
	assert_eq(level.get_child_count(), 3, "Layers, Units, Camera")
	assert_eq(level.unit_nodes.size(), 3)


func test_to_tscn_writes_a_packed_scene() -> void:
	var level := _loaded_level()
	var path := "user://test_level_packed.tscn"
	var scene := level.toTscn(path)
	assert_not_null(scene)
	assert_true(FileAccess.file_exists(path))
	assert_eq(level.level_path, "", "level_path untouched when it was empty")

	var copy := scene.instantiate()
	add_child_autofree(copy)
	assert_eq(copy.get_child_count(), 3)
	assert_eq(copy.get_node("Layers").get_child_count(), 2)
	assert_eq(copy.get_node("Units").get_child_count(), 3)
	assert_eq(copy.get_node("Layers/grass").get_cell_atlas_coords(Vector2i(6, 5)), Vector2i(1, 1))
	DirAccess.remove_absolute(path)


func test_save_and_reload_restores_unit_state() -> void:
	var level := _loaded_level()
	level.toTscn()
	level.level_units["lyn"].cell = Vector2i(7, 7)
	level.level_units["lyn"].current_hp = 3
	var saved := level.toJson()
	assert_eq(saved["version"], Level.SAVE_VERSION)
	assert_eq(saved["level_units"]["lyn"]["cell"], [7, 7])

	var reloaded := Level.new()
	add_child_autofree(reloaded)
	reloaded.fromJson(saved)
	reloaded.toTscn()
	assert_eq(reloaded.level_units["lyn"].cell, Vector2i(7, 7))
	assert_eq(reloaded.level_units["lyn"].current_hp, 3)
	assert_eq(reloaded.unit_at(Vector2i(7, 7)).reference.id, "lyn")
	assert_eq(reloaded.level_units["wil"].current_hp, 20, "untouched unit is unchanged")


func test_json_file_round_trip() -> void:
	var level := _loaded_level()
	var path := "user://test_level_save.json"
	assert_eq(level.save_file(path), OK)
	var again := Level.new()
	add_child_autofree(again)
	assert_eq(again.load_file(path), OK)
	assert_eq(again.toJson(), level.toJson())
	DirAccess.remove_absolute(path)
