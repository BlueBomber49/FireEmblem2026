extends GutTest
## The map editor reads and writes the placement format: named characters by id, and
## generic units by class with optional stat overrides. Loads simple_level.

const EditorScene: PackedScene = preload("res://editor/map_editor.tscn")
const FREE_CELL := Vector2i(3, 3)

var editor: MapEditor


func before_each() -> void:
	editor = EditorScene.instantiate()
	editor.level_path = "res://resources/levels/simple_level.json"
	add_child_autofree(editor)


func _map_units() -> Dictionary:
	return editor.level.level_state.map_data.units


func _select_class(class_id: StringName) -> void:
	editor.class_option.selected = editor.unit_classes.find(class_id)


func test_loads_character_and_generic_placements() -> void:
	assert_true(_map_units()["lyn"].is_character())
	assert_eq(_map_units()["bandit"].class_id, "fighter")
	assert_eq(editor.level.unit_nodes.size(), _map_units().size(), "every placement shows")


func test_class_picker_lists_game_classes() -> void:
	assert_eq(editor.unit_classes, GameData.all_class_ids())


func test_placing_a_unit_writes_a_generic_placement() -> void:
	_select_class(&"knight")
	editor.faction_option.selected = UnitReference.Faction.ENEMY
	editor._place_unit(FREE_CELL)
	var ref: UnitReference = _map_units()[editor.selected_unit_id]
	var saved := ref.toJson()
	assert_eq(saved["class"], "knight")
	assert_eq(saved["faction"], "enemy")
	assert_false(saved.has("unit_class"), "no old sprite-name class")
	assert_eq(saved.get("stats", {}), {}, "no overrides until a stat is changed")
	assert_eq(saved["items"], ["iron_lance"], "a usable starting weapon")
	assert_string_contains(ref.resolved_sprite(), "LanceKnight_Red")


func test_editing_a_stat_writes_only_that_override() -> void:
	_select_class(&"fighter")
	editor._place_unit(FREE_CELL)
	editor.override_check.button_pressed = true
	editor.stat_spins[&"hp"].value = 30
	var ref: UnitReference = _map_units()[editor.selected_unit_id]
	assert_eq(ref.stat_overrides, {"hp": 30})


func test_character_placements_round_trip_unchanged() -> void:
	var before: Dictionary = _map_units()["lyn"].toJson()
	editor._select_unit("lyn")
	editor._apply_inspector()
	assert_eq(_map_units()["lyn"].toJson(), before)


func _select_character(character_id: String) -> void:
	editor.character_option.selected = editor.character_ids.find(StringName(character_id)) + 1  # 0 is "None"


func test_character_picker_lists_none_then_every_character() -> void:
	assert_eq(editor.character_option.get_item_text(0), "None")
	assert_eq(editor.character_ids, GameData.all_character_ids())
	assert_eq(editor.character_option.item_count, GameData.all_character_ids().size() + 1)


func test_placing_with_a_character_picked_places_that_character() -> void:
	_remove_from_map("kent")  # a character can be placed only once
	_select_character("kent")
	editor.faction_option.selected = UnitReference.Faction.PLAYER
	editor._place_unit(FREE_CELL)
	var ref: UnitReference = _map_units()[editor.selected_unit_id]
	assert_true(ref.is_character())
	assert_eq(ref.character_id, "kent")
	assert_eq(ref.toJson()["character"], "kent")
	assert_false(ref.toJson().has("stats"))
	assert_string_contains(ref.resolved_sprite(), "LanceCavalier")
	assert_string_contains(ref.resolved_sprite(), "Blue")


func test_character_fields_are_read_only() -> void:
	editor._select_unit("lyn")
	assert_eq(editor.character_option.selected, editor.character_ids.find(&"lyn") + 1)
	assert_false(editor.unit_name_edit.editable)
	assert_false(editor.items_edit.editable)
	assert_true(editor.override_check.disabled)
	assert_eq(editor.unit_name_edit.text, "Lyn")
	assert_eq(editor.items_edit.text, "iron_sword, vulnerary")


func test_switching_a_generic_unit_to_a_character_and_back() -> void:
	_remove_from_map("wil")
	editor._select_unit("bandit")
	_select_character("wil")
	editor._apply_inspector()
	var ref: UnitReference = _map_units()["bandit"]
	assert_eq(ref.character_id, "wil")
	editor.character_option.selected = 0
	editor._apply_inspector()
	assert_false(ref.is_character())
	assert_eq(ref.class_id, "archer", "keeps the class it had as Wil")


func test_items_field_sets_the_items_in_order() -> void:
	_select_class(&"fighter")
	editor._place_unit(FREE_CELL)
	editor.items_edit.text = "hand_axe, vulnerary"
	editor._apply_inspector()
	var ref: UnitReference = _map_units()[editor.selected_unit_id]
	assert_eq(ref.items, ["hand_axe", "vulnerary"] as Array[String])


func test_unknown_item_ids_are_dropped_and_reported() -> void:
	_select_class(&"fighter")
	editor._place_unit(FREE_CELL)
	editor.items_edit.text = "iron_axe, spoon"
	editor._apply_inspector()
	var ref: UnitReference = _map_units()[editor.selected_unit_id]
	assert_eq(ref.items, ["iron_axe"] as Array[String])
	assert_string_contains(editor.status.text, "spoon")


func test_override_checkbox_controls_the_stats() -> void:
	_select_class(&"fighter")
	editor._place_unit(FREE_CELL)
	assert_false(editor.override_check.button_pressed, "a new unit uses class stats")
	assert_false(editor.stat_spins[&"hp"].editable)
	editor.override_check.button_pressed = true
	assert_true(editor.stat_spins[&"hp"].editable)
	assert_false(editor.stat_spins[&"movement"].editable, "movement always comes from the class")
	editor.stat_spins[&"hp"].value = 33
	var ref: UnitReference = _map_units()[editor.selected_unit_id]
	assert_eq(ref.stat_overrides, {"hp": 33})
	editor.override_check.button_pressed = false
	assert_eq(ref.stat_overrides, {}, "unchecking goes back to the class's stats")
	assert_eq(int(editor.stat_spins[&"hp"].value), 20)


func test_a_unit_with_overrides_loads_with_the_box_checked() -> void:
	editor._select_unit("bandit")
	assert_true(editor.override_check.button_pressed)
	assert_eq(int(editor.stat_spins[&"hp"].value), 24)


func test_broken_placements_are_reported() -> void:
	_map_units()["typo"] = UnitReference.fromJson("typo", {"character": "lynn", "start_cell": [3, 4]})
	assert_eq(editor.broken_placements().size(), 1)
	assert_string_contains(editor.broken_placements()[0], "lynn")


# --- Named characters: one per map, class follows the character -------------------
# simple_level already places Lyn, Wil and Kent.


func _remove_from_map(unit_id: String) -> void:
	_map_units().erase(unit_id)
	editor._rebuild_units()
	editor._select_unit("")


func _clear_map_units() -> void:
	_map_units().clear()
	editor._rebuild_units()
	editor._select_unit("")


func test_picking_a_character_grays_out_the_class_before_placing() -> void:
	_remove_from_map("kent")
	_select_character("kent")
	editor._on_character_picked(editor.character_option.selected)
	assert_true(editor.class_option.disabled, "the character's file decides the class")
	assert_eq(editor.unit_classes[editor.class_option.selected], &"cavalier", "shows Kent's class")
	assert_eq(editor.unit_name_edit.text, "Kent")
	editor.character_option.selected = 0
	editor._on_character_picked(0)
	assert_false(editor.class_option.disabled, "None: pick any class")


func test_a_character_already_on_the_map_cant_be_placed_again() -> void:
	var before := _map_units().size()
	_select_character("lyn")
	editor._place_unit(FREE_CELL)
	assert_eq(_map_units().size(), before, "no second Lyn")
	assert_string_contains(editor.status.text, "Lyn")


func test_characters_already_on_the_map_are_grayed_out_in_the_picker() -> void:
	editor._select_unit("")
	var lyn_index := editor.character_ids.find(&"lyn") + 1
	assert_true(editor.character_option.is_item_disabled(lyn_index))
	_remove_from_map("lyn")
	assert_false(editor.character_option.is_item_disabled(lyn_index), "pickable again once removed")
	_map_units()["lyn"] = UnitReference.fromJson("lyn", {"character": "lyn", "start_cell": [1, 1]})
	editor._rebuild_units()
	editor._select_unit("lyn")
	assert_false(editor.character_option.is_item_disabled(lyn_index), "Lyn's own placement keeps her entry")


func test_a_character_can_be_placed_once_the_map_has_none() -> void:
	_clear_map_units()
	_select_character("lyn")
	editor._place_unit(FREE_CELL)
	assert_true(_map_units().has("lyn"))
	_select_character("lyn")
	editor._place_unit(FREE_CELL + Vector2i.RIGHT)
	assert_eq(_map_units().size(), 1, "still only one Lyn")


func test_a_generic_unit_cant_become_a_character_already_on_the_map() -> void:
	editor._select_unit("bandit")
	_select_character("lyn")
	editor._apply_inspector()
	assert_false(_map_units()["bandit"].is_character(), "Lyn is already placed")
	assert_string_contains(editor.status.text, "Lyn")


# --- Deselecting: back to the new-unit template -------------------------------------


func _press_key(keycode: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.pressed = true
	editor._unhandled_input(key)


func test_the_deselect_button_returns_to_the_template() -> void:
	editor._select_unit("lyn")
	assert_false(editor.deselect_button.disabled)
	editor.deselect_button.pressed.emit()
	assert_eq(editor.selected_unit_id, "")
	assert_eq(editor.unit_header.text, "New unit template")
	assert_true(editor.deselect_button.disabled, "nothing to deselect")


func test_the_game_cancel_keys_deselect() -> void:
	for keycode: Key in [KEY_X, KEY_ESCAPE]:
		editor._select_unit("lyn")
		_press_key(keycode)
		assert_eq(editor.selected_unit_id, "", "%s deselects" % OS.get_keycode_string(keycode))


func test_after_deselecting_a_character_a_generic_unit_can_be_placed() -> void:
	editor._select_unit("lyn")
	_press_key(KEY_ESCAPE)
	_select_class(&"knight")
	var before := _map_units().size()
	editor._place_unit(FREE_CELL)
	assert_eq(_map_units().size(), before + 1)
	assert_eq(_map_units()[editor.selected_unit_id].class_id, "knight")


func test_a_refused_placement_says_how_to_deselect() -> void:
	editor._select_unit("lyn")
	editor._place_unit(FREE_CELL)
	assert_string_contains(editor.status.text, "Deselect")


# --- Broken placements: never changed by accident ---------------------------------


func _add_broken() -> UnitReference:
	var ref := UnitReference.fromJson("brigand_typo", {"class": "brigandd", "faction": "enemy",
		"items": ["hand_axe", "steel_axx"], "stats": {"hp": 30}, "start_cell": [3, 4]})
	_map_units()["brigand_typo"] = ref
	editor._rebuild_units()
	return ref


func test_selecting_and_applying_a_broken_placement_leaves_it_unchanged() -> void:
	var ref := _add_broken()
	var before := ref.toJson()
	editor._select_unit("brigand_typo")
	editor._apply_inspector()  # leaving the id or items field does this
	editor.unit_name_edit.text = "Changed"
	editor._apply_inspector()
	assert_eq(_map_units()["brigand_typo"].toJson(), before)


func test_a_broken_placement_is_read_only_except_its_pickers() -> void:
	_add_broken()
	editor._select_unit("brigand_typo")
	assert_false(editor.unit_name_edit.editable)
	assert_false(editor.level_spin.editable)
	assert_false(editor.items_edit.editable)
	assert_true(editor.override_check.disabled)
	assert_false(editor.class_option.disabled, "picking a real class fixes it")
	assert_string_contains(editor.unit_header.text, "brigandd")


func test_picking_a_class_fixes_a_broken_placement_and_keeps_the_rest() -> void:
	var ref := _add_broken()
	editor._select_unit("brigand_typo")
	_select_class(&"fighter")
	editor._apply_inspector()
	assert_eq(ref.class_id, "fighter")
	assert_eq(ref.items, ["hand_axe", "steel_axx"] as Array[String], "items kept as written")
	assert_eq(ref.stat_overrides, {"hp": 30}, "overrides kept as written")
	assert_eq(ref.build_problem(), "")


func test_unknown_item_ids_survive_unrelated_edits() -> void:
	var bandit: UnitReference = _map_units()["bandit"]
	bandit.items.append("steel_axx")
	editor._select_unit("bandit")
	editor.unit_name_edit.text = "Bandit Chief"
	editor._apply_inspector()
	assert_eq(bandit.name, "Bandit Chief")
	assert_true(bandit.items.has("steel_axx"), "only editing the items field changes the items")


func test_saved_level_reloads() -> void:
	_select_class(&"mage")
	editor._place_unit(FREE_CELL)
	var path := "user://test_map_editor_level.json"
	editor.path_edit.text = path
	editor._save()
	var reloaded := LevelState.load_file(path)
	assert_not_null(reloaded)
	assert_eq(reloaded.level_units.size(), _map_units().size())
	DirAccess.remove_absolute(path)
