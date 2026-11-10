extends GutTest

const LEVEL_PATH := "res://resources/levels/test_level.json"


func _loaded_level() -> Level:
	var level := Level.new()
	add_child_autofree(level)
	level.level_state = LevelState.load_file(LEVEL_PATH)
	assert_not_null(level.level_state)
	return level


func test_ready_loads_and_builds_level_path() -> void:
	var level := Level.new()
	level.level_path = LEVEL_PATH
	add_child_autofree(level)
	assert_not_null(level.level_state)
	assert_eq(level.unit_nodes.size(), 3)


func test_ready_keeps_a_state_assigned_beforehand() -> void:
	var state := LevelState.fromJson({})
	var level := Level.new()
	level.level_state = state
	level.level_path = LEVEL_PATH
	add_child_autofree(level)
	assert_same(level.level_state, state)


func test_fresh_load_builds_states_from_map_units() -> void:
	var level := _loaded_level()
	assert_eq(level.level_state.level_units.size(), level.level_state.map_data.units.size())
	var lyn: LevelUnitState = level.level_state.level_units["lyn"]
	assert_eq(lyn.cell, level.level_state.map_data.units["lyn"].start_cell)
	assert_eq(lyn.current_hp, lyn.unit.max_hp())
	assert_eq(lyn.unit.max_hp(), 16, "Lyn's own stats from resources/characters/lyn.json")


func test_rebuild_builds_layers_units_and_pathfinding() -> void:
	var level := _loaded_level()
	level.rebuild()
	assert_eq(level.layers_root.get_child_count(), 2)
	assert_eq(level.layers_root.get_child(0).name, "water", "lowest z first")
	assert_eq(level.layers_root.get_child(1).name, "grass")
	var grass: TileMapLayer = level.layers_root.get_child(1)
	assert_eq(grass.get_used_cells().size(), level.level_state.map_data.layers["grass"].cell_masks().size())
	assert_eq(grass.get_cell_atlas_coords(Vector2i(6, 5)), Vector2i(1, 1), "fill tile inside the blob")
	assert_eq(grass.get_cell_atlas_coords(Vector2i(12, 9)), Vector2i(4, 2), "diagonal tile")

	assert_eq(level.unit_nodes.size(), 3)
	assert_eq(level.unit_at(Vector2i(6, 5)).reference.id, "lyn")
	assert_almost_eq(level.unit_nodes["lyn"].global_position, Vector2(104, 88), Vector2(0.01, 0.01))

	assert_true(level.pathfinding.is_walkable(Vector2i(1, 1)), "water is terrain (who can enter it is per unit)")
	assert_false(level.pathfinding.is_walkable(Vector2i(0, 0)), "a mostly-blank corner cell")
	assert_false(level.pathfinding.is_walkable(Vector2i(30, 30)), "outside every layer")
	assert_eq(level.pathfinding.find_path(level.level_state.level_units["lyn"], Vector2i(8, 5)).size(), 3)


## A cell well inside test_level's grass blob.
const INNER_GRASS := Vector2i(6, 5)


func test_rebuild_refreshes_rules_terrain() -> void:
	var level := _loaded_level()
	level.rebuild()
	assert_eq(level.level_state.map_data.rules_terrain_at(INNER_GRASS), "grass")
	level.level_state.map_data.layers.erase("grass")
	level.rebuild()
	assert_eq(level.level_state.map_data.rules_terrain_at(INNER_GRASS), "water")


func test_repainting_a_layer_refreshes_rules_terrain() -> void:
	var level := _loaded_level()
	level.rebuild()
	assert_eq(level.level_state.map_data.rules_terrain_at(INNER_GRASS), "grass")
	# Erase the grass from the cell's four corners, as an eraser stroke would.
	var corners := [INNER_GRASS, INNER_GRASS + Vector2i(1, 0), INNER_GRASS + Vector2i(0, 1), INNER_GRASS + Vector2i(1, 1)]
	var grass: MapLayer = level.level_state.map_data.layers["grass"]
	var kept: Array[Vector2i] = []
	for v in grass.verts:
		if v not in corners:
			kept.append(v)
	grass.verts = kept
	level.repaint_layer("grass")
	assert_eq(level.level_state.map_data.rules_terrain_at(INNER_GRASS), "water", "a brush stroke erased it")


func test_rebuild_is_idempotent() -> void:
	var level := _loaded_level()
	level.rebuild()
	level.rebuild()
	assert_eq(level.get_child_count(), 3, "Layers, Units, Camera")
	assert_eq(level.unit_nodes.size(), 3)


func test_save_and_reload_restores_unit_state() -> void:
	var level := _loaded_level()
	level.rebuild()
	level.level_state.level_units["lyn"].cell = Vector2i(7, 7)
	level.level_state.level_units["lyn"].current_hp = 3
	var saved := level.level_state.toJson()
	assert_eq(saved["version"], LevelState.SAVE_VERSION)
	assert_eq(saved["level_units"]["lyn"]["cell"], [7, 7])

	var reloaded := Level.new()
	add_child_autofree(reloaded)
	reloaded.level_state = LevelState.fromJson(saved)
	reloaded.rebuild()
	assert_eq(reloaded.level_state.level_units["lyn"].cell, Vector2i(7, 7))
	assert_eq(reloaded.level_state.level_units["lyn"].current_hp, 3)
	assert_eq(reloaded.unit_at(Vector2i(7, 7)).reference.id, "lyn")
	assert_eq(reloaded.level_state.level_units["wil"].current_hp, 20, "untouched unit is unchanged")



# --- Acted tint: only the side whose phase it is ---------------------------


func _acted_level() -> Level:
	var level := Level.new()
	level.level_path = LEVEL_PATH
	add_child_autofree(level)
	for id in ["lyn", "bandit"]:
		(level.level_state.level_units[id] as LevelUnitState).has_acted = true
	return level


func test_acted_player_units_are_gray_in_the_player_phase() -> void:
	var level := _acted_level()
	level.update_tints()
	assert_eq(level.unit_nodes["lyn"].modulate, Level.ACTED_TINT)
	assert_eq(level.unit_nodes["bandit"].modulate, Color.WHITE, "enemies aren't grayed on your turn")


func test_acted_enemies_are_gray_in_the_enemy_phase() -> void:
	var level := _acted_level()
	level.acting_faction = UnitReference.Faction.ENEMY
	level.update_tints()
	assert_eq(level.unit_nodes["bandit"].modulate, Level.ACTED_TINT)
	assert_eq(level.unit_nodes["lyn"].modulate, Color.WHITE, "your units look normal while enemies act")


# --- The commander's crown ------------------------------------------------------------


func test_only_the_commander_wears_the_crown() -> void:
	var state := LevelState.load_file(LEVEL_PATH)
	state.map_data.units["bandit"].commander = true
	var level := Level.new()
	level.level_state = state
	add_child_autofree(level)
	assert_not_null(level.unit_nodes["bandit"].get_node_or_null(NodePath(LevelUnit.COMMANDER_ICON_NAME)))
	assert_null(level.unit_nodes["lyn"].get_node_or_null(NodePath(LevelUnit.COMMANDER_ICON_NAME)))


# --- The roster: characters carried between chapters --------------------------------


func _level_with_roster(roster: Dictionary) -> Level:
	var level := Level.new()
	level.level_path = LEVEL_PATH
	level.roster = roster
	add_child_autofree(level)
	return level


func test_the_roster_carries_a_character_in_healed() -> void:
	var first := _level_with_roster({})
	var lyn: Unit = first.level_state.level_units["lyn"].unit
	lyn.level = 5
	lyn.experience = 30
	lyn.stats.speed += 2
	lyn.current_hp = 3
	var next := _level_with_roster(first.collect_roster())
	var carried: Unit = next.level_state.level_units["lyn"].unit
	assert_eq(carried.level, 5)
	assert_eq(carried.experience, 30)
	assert_eq(carried.stats.speed, lyn.stats.speed)
	assert_eq(carried.current_hp, carried.max_hp(), "healed for the new chapter")


func test_the_roster_holds_player_characters_only() -> void:
	var level := _level_with_roster({})
	var roster := level.collect_roster()
	assert_true(roster.has("lyn"))
	assert_false(roster.has("bandit"), "a generic enemy")
	assert_false(roster.has("wil"), "an ally")


func test_a_fallen_character_returns_with_its_progress() -> void:
	var level := _level_with_roster({})
	var lyn: LevelUnitState = level.level_state.level_units["lyn"]
	lyn.unit.level = 3
	lyn.current_hp = 0
	var roster := level.collect_roster()
	assert_true(roster.has("lyn"), "casual: the fallen come back")
	var next := _level_with_roster(roster)
	var back: LevelUnitState = next.level_state.level_units["lyn"]
	assert_true(back.is_alive())
	assert_eq(back.unit.level, 3)


func test_the_roster_skips_a_unit_of_another_faction() -> void:
	var level := _level_with_roster({"wil": {"level": 9}})
	assert_ne(level.level_state.level_units["wil"].unit.level, 9, "wil is an ally here")



func test_a_level_holds_reinforcements_back_only_when_set() -> void:
	var state := LevelState.load_file(LEVEL_PATH)
	state.map_data.units["bandit"].event = "wave_1"
	state.events = {"wave_1": {"trigger": {"type": "turn_start", "turn": 2, "phase": "enemy"},
			"actions": [{"type": "spawn"}]}}
	var editor_level := Level.new()
	editor_level.level_state = LevelState.fromJson(state.toJson(false))
	add_child_autofree(editor_level)
	assert_true(editor_level.unit_nodes.has("bandit"), "the editor shows every placement")
	var play_level := Level.new()
	play_level.holds_reinforcements = true
	play_level.level_state = LevelState.fromJson(state.toJson(false))
	add_child_autofree(play_level)
	assert_false(play_level.unit_nodes.has("bandit"), "in play it waits")
	assert_eq(play_level.arrive("bandit"), Vector2i(10, 5))
	assert_true(play_level.unit_nodes.has("bandit"))


func test_arrive_finds_no_cell_on_a_full_map() -> void:
	# One grass cell, and lyn is standing on it.
	var level := Level.new()
	level.holds_reinforcements = true
	level.level_state = LevelState.fromJson({
		"map_data": {
			"layers": {"grass": {"z": 0, "terrain": "grass", "verts": [[0, 0]]}},
			"units": {
				"lyn": {"character": "lyn", "faction": "player", "start_cell": [0, 0]},
				"wave": {"class": "fighter", "items": ["iron_axe"], "faction": "enemy",
						"start_cell": [0, 0], "event": "wave_1"},
			},
		},
		"events": {"wave_1": {"trigger": {"type": "turn_start", "turn": 2, "phase": "enemy"},
				"actions": [{"type": "spawn"}]}},
	})
	add_child_autofree(level)
	assert_true(level.level_state.pending_units.has("wave"))
	assert_eq(level.arrive("wave"), Vector2i(-1, -1))
	assert_true(level.level_state.pending_units.has("wave"), "it keeps waiting")
	assert_push_warning("wave")
