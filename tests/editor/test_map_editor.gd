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


# --- Objective mode ---------------------------------------------------------------
# simple_level has no objective in its file: the default rout, plus the built-in
# wipe loss. Units: lyn, wil, kent (players), bandit, brigand (enemies).
# Each condition is a row with its settings inline and its own remove button.


const SAVE_PATH := "user://test_map_editor_objective.json"


func after_each() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _objective() -> Objective:
	return editor.level.level_state.objective


func _objective_mode() -> void:
	editor._set_mode(MapEditor.Mode.OBJECTIVE)


## Adds `type_name` to `side` and returns its index in that list.
func _add(side: StringName, type_name: String) -> int:
	editor._add_condition(side, type_name)
	return editor._conditions(side).size() - 1


func _menu_item(menu: MenuButton, title: String) -> int:
	var popup := menu.get_popup()
	for i in popup.item_count:
		if popup.get_item_text(i) == title:
			return i
	return -1


func test_objective_mode_shows_its_panel() -> void:
	_objective_mode()
	assert_true(editor.objective_box.visible)
	assert_false(editor.units_box.visible)
	assert_false(editor.terrain_box.visible)


func test_each_condition_is_a_row() -> void:
	_objective_mode()
	assert_eq(editor.win_rows.get_child_count(), 1)
	assert_string_contains(editor.row_text(Objective.WIN, 0), "Rout the enemy")
	assert_not_null(editor.row_control(Objective.WIN, 0, &"remove"))


func test_the_built_in_loss_is_a_fixed_row() -> void:
	_objective_mode()
	assert_eq(editor.lose_rows.get_child_count(), 1, "just the built-in row")
	assert_string_contains(editor.fixed_loss_text(), "Your army is defeated")


func test_the_add_menus_offer_each_type_once() -> void:
	_objective_mode()
	var win_popup := editor.win_add_menu.get_popup()
	assert_eq(win_popup.item_count, Objective.types_for(Objective.WIN).size())
	assert_true(win_popup.is_item_disabled(_menu_item(editor.win_add_menu, "Rout the enemy")), "already in the list")
	assert_false(win_popup.is_item_disabled(_menu_item(editor.win_add_menu, "Seize")))
	assert_eq(editor.lose_add_menu.get_popup().item_count, Objective.types_for(Objective.LOSE).size())
	_add(Objective.WIN, "seize")
	assert_true(win_popup.is_item_disabled(_menu_item(editor.win_add_menu, "Seize")), "once per list")


func test_picking_from_the_add_menu_adds_the_row() -> void:
	_objective_mode()
	var popup := editor.win_add_menu.get_popup()
	popup.id_pressed.emit(popup.get_item_id(_menu_item(editor.win_add_menu, "Survive N turns")))
	assert_eq(_objective().win.size(), 2)
	assert_eq(_objective().win[1].type, "survive")
	assert_eq(editor.win_rows.get_child_count(), 2)


func test_a_type_already_in_the_list_isnt_added_twice() -> void:
	_objective_mode()
	_add(Objective.WIN, "seize")
	editor._add_condition(Objective.WIN, "seize")
	assert_eq(_objective().win.size(), 2, "rout + one seize")


func test_the_remove_button_removes_that_row() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "survive")
	(editor.row_control(Objective.WIN, i, &"remove") as Button).pressed.emit()
	assert_eq(_objective().win.size(), 1)
	assert_eq(_objective().win[0].type, "faction_defeated")
	assert_eq(editor.win_rows.get_child_count(), 1)


func test_turns_are_set_inline() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "survive")
	var spin := editor.row_control(Objective.WIN, i, &"turns") as SpinBox
	assert_not_null(spin)
	spin.value = 3
	assert_eq((_objective().win[i] as Objective.Survive).turns, 3)
	assert_same(editor.row_control(Objective.WIN, i, &"turns"), spin, "editing doesn't rebuild the row (keeps focus)")


func test_objective_edits_can_be_undone() -> void:
	_objective_mode()
	_add(Objective.LOSE, "turns_pass")
	assert_eq(editor.lose_rows.get_child_count(), 2)
	editor.undo()
	assert_eq(editor.level.level_state.objective.lose.size(), 0)
	assert_eq(editor.lose_rows.get_child_count(), 1, "the panel follows the undo")


func test_units_fall_ticks_player_and_ally_units_only() -> void:
	_objective_mode()
	var i := _add(Objective.LOSE, "units_fall")
	for id in ["lyn", "wil", "kent"]:
		assert_not_null(editor.unit_checkbox(Objective.LOSE, i, id), "%s can be picked" % id)
	for id in ["bandit", "brigand"]:
		assert_null(editor.unit_checkbox(Objective.LOSE, i, id), "no enemies")
	editor.unit_checkbox(Objective.LOSE, i, "lyn").button_pressed = true
	editor.unit_checkbox(Objective.LOSE, i, "kent").button_pressed = true
	assert_eq((_objective().lose[i] as Objective.UnitsFall).units, ["lyn", "kent"] as Array[String])
	assert_eq(_objective().lose_lines(editor.level.level_state)[1], "Lyn or Kent falls")
	editor.unit_checkbox(Objective.LOSE, i, "lyn").button_pressed = false
	assert_eq((_objective().lose[i] as Objective.UnitsFall).units, ["kent"] as Array[String])


func test_the_loss_section_says_loss() -> void:
	_objective_mode()
	assert_string_contains(editor.lose_header.text, "LOSS")
	assert_eq(editor.lose_add_menu.text, "+ Add loss condition")


func test_clicking_the_map_without_choosing_explains_how() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "seize")
	editor._objective_click(FREE_CELL)
	assert_true((_objective().win[i] as Objective.Seize).cells.is_empty())
	assert_string_contains(editor.status.text, "Choose cell")


func test_a_seize_cell_is_chosen_clicked_then_confirmed() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "seize")
	var seize := _objective().win[i] as Objective.Seize
	(editor.row_control(Objective.WIN, i, &"choose") as Button).pressed.emit()
	assert_true(editor.is_picking())
	editor._objective_click(FREE_CELL)
	assert_true(seize.cells.is_empty(), "not set until confirmed")
	assert_eq(editor.pending_cell(), FREE_CELL)
	(editor.row_control(Objective.WIN, i, &"confirm") as Button).pressed.emit()
	assert_eq(seize.cells, [FREE_CELL] as Array[Vector2i])
	assert_false(editor.is_picking(), "done after confirming")
	assert_not_null(editor.cell_chip(Objective.WIN, i, FREE_CELL), "the chosen cell is listed")


func test_a_second_seize_cell_can_be_added() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "seize")
	for cell in [FREE_CELL, FREE_CELL + Vector2i.RIGHT]:
		(editor.row_control(Objective.WIN, i, &"choose") as Button).pressed.emit()
		editor._objective_click(cell)
		(editor.row_control(Objective.WIN, i, &"confirm") as Button).pressed.emit()
	assert_eq((_objective().win[i] as Objective.Seize).cells.size(), 2)


func test_a_chosen_seize_cell_can_be_removed() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "seize")
	(editor.row_control(Objective.WIN, i, &"choose") as Button).pressed.emit()
	editor._objective_click(FREE_CELL)
	(editor.row_control(Objective.WIN, i, &"confirm") as Button).pressed.emit()
	editor.cell_chip(Objective.WIN, i, FREE_CELL).pressed.emit()
	assert_true((_objective().win[i] as Objective.Seize).cells.is_empty())


func test_cancelling_a_pick_changes_nothing() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "seize")
	(editor.row_control(Objective.WIN, i, &"choose") as Button).pressed.emit()
	editor._objective_click(FREE_CELL)
	(editor.row_control(Objective.WIN, i, &"cancel") as Button).pressed.emit()
	assert_false(editor.is_picking())
	assert_true((_objective().win[i] as Objective.Seize).cells.is_empty())


func test_escape_cancels_a_pick() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "seize")
	(editor.row_control(Objective.WIN, i, &"choose") as Button).pressed.emit()
	_press_key(KEY_ESCAPE)
	assert_false(editor.is_picking())


func test_the_seize_name_is_typed_inline() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "seize")
	var name_edit := editor.row_control(Objective.WIN, i, &"name") as LineEdit
	name_edit.text = "the gate"
	name_edit.text_changed.emit("the gate")
	assert_eq((_objective().win[i] as Objective.Seize).name, "the gate")
	assert_same(editor.row_control(Objective.WIN, i, &"name"), name_edit, "typing doesn't rebuild the row")


func test_the_commander_can_be_chosen_on_the_map() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "defeat_commander")
	(editor.row_control(Objective.WIN, i, &"choose") as Button).pressed.emit()
	editor._objective_click(_map_units()["lyn"].start_cell)
	assert_false(editor.has_pending(), "lyn isn't an enemy")
	assert_string_contains(editor.status.text, "enemy")
	editor._objective_click(_map_units()["bandit"].start_cell)
	assert_true(editor.has_pending())
	assert_false(_map_units()["bandit"].commander, "not until confirmed")
	(editor.row_control(Objective.WIN, i, &"confirm") as Button).pressed.emit()
	assert_true(_map_units()["bandit"].commander)
	assert_true(editor.objective_problems().is_empty())


func test_clicking_the_map_releases_a_number_box() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "survive")
	var spin := editor.row_control(Objective.WIN, i, &"turns") as SpinBox
	spin.get_line_edit().grab_focus()
	assert_eq(editor.get_viewport().gui_get_focus_owner(), spin.get_line_edit())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	editor._unhandled_input(click)
	assert_null(editor.get_viewport().gui_get_focus_owner(), "the box lets go, so its outline goes away")


func test_enter_releases_a_number_box() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "survive")
	var line := (editor.row_control(Objective.WIN, i, &"turns") as SpinBox).get_line_edit()
	line.grab_focus()
	line.text_submitted.emit("4")
	assert_null(editor.get_viewport().gui_get_focus_owner())


func test_the_commander_is_chosen_in_its_row() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "defeat_commander")
	var pick := editor.row_control(Objective.WIN, i, &"commander") as OptionButton
	var ids: Array = []
	for k in pick.item_count:
		ids.append(pick.get_item_metadata(k))
	assert_true(ids.has("bandit") and ids.has("brigand"))
	assert_false(ids.has("lyn"), "only enemies")
	for k in pick.item_count:
		if pick.get_item_metadata(k) == "brigand":
			pick.select(k)
			pick.item_selected.emit(k)
	assert_true(_map_units()["brigand"].commander)
	assert_true(editor.objective_problems().is_empty())
	assert_not_null(editor.level.unit_nodes["brigand"].get_node_or_null(NodePath(LevelUnit.COMMANDER_ICON_NAME)), "badge")
	editor._select_unit("brigand")
	assert_true(editor.commander_check.button_pressed, "same mark as the Units mode checkbox")


# --- Problems ------------------------------------------------------------------------


func test_a_row_with_a_problem_says_so_and_saving_is_refused() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "defeat_commander")
	var problem := editor.row_control(Objective.WIN, i, &"problem") as Label
	assert_true(problem.visible)
	assert_false(problem.text.is_empty())
	assert_false(editor.problems_label.text.is_empty(), "summary at the top")
	editor.path_edit.text = SAVE_PATH
	editor._save()
	assert_false(FileAccess.file_exists(SAVE_PATH), "refused")
	assert_string_contains(editor.status.text, "commander")


func test_a_seize_with_no_cells_cant_be_saved() -> void:
	_objective_mode()
	_add(Objective.WIN, "seize")
	editor.path_edit.text = SAVE_PATH
	editor._save()
	assert_false(FileAccess.file_exists(SAVE_PATH))


func test_fixing_the_problem_lets_it_save() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "defeat_commander")
	editor._select_unit("bandit")
	editor.commander_check.button_pressed = true
	assert_true(editor.objective_problems().is_empty())
	assert_false((editor.row_control(Objective.WIN, i, &"problem") as Label).visible, "the row's warning clears")
	editor.path_edit.text = SAVE_PATH
	editor._save()
	assert_true(FileAccess.file_exists(SAVE_PATH))
	var reloaded := LevelState.load_file(SAVE_PATH)
	assert_eq(reloaded.commander_id(), "bandit")
	assert_true(reloaded.objective.has_type("defeat_commander"))


func test_a_level_with_no_win_condition_gets_a_note_but_still_saves() -> void:
	_objective_mode()
	(editor.row_control(Objective.WIN, 0, &"remove") as Button).pressed.emit()
	assert_eq(_objective().win.size(), 0)
	assert_string_contains(editor.problems_label.text, "No win condition")
	assert_true(editor.objective_problems().is_empty(), "a note, not a problem")
	editor.path_edit.text = SAVE_PATH
	editor._save()
	assert_true(FileAccess.file_exists(SAVE_PATH))


# --- The commander checkbox (Units mode) ------------------------------------------------


func test_only_enemies_can_be_marked_commander() -> void:
	editor._select_unit("lyn")
	assert_true(editor.commander_check.disabled)
	editor._select_unit("bandit")
	assert_false(editor.commander_check.disabled)
	editor._select_unit("")
	assert_true(editor.commander_check.disabled, "nothing selected")


func test_marking_a_commander_clears_the_previous_one() -> void:
	editor._select_unit("bandit")
	editor.commander_check.button_pressed = true
	assert_true(_map_units()["bandit"].commander)
	editor._select_unit("brigand")
	assert_false(editor.commander_check.button_pressed)
	editor.commander_check.button_pressed = true
	assert_true(_map_units()["brigand"].commander)
	assert_false(_map_units()["bandit"].commander, "one commander per level")


func test_the_commander_wears_the_badge_in_the_editor() -> void:
	editor._select_unit("bandit")
	editor.commander_check.button_pressed = true
	var node: LevelUnit = editor.level.unit_nodes["bandit"]
	assert_not_null(node.get_node_or_null(NodePath(LevelUnit.COMMANDER_ICON_NAME)))


func test_a_unit_that_stops_being_an_enemy_loses_the_mark() -> void:
	editor._select_unit("bandit")
	editor.commander_check.button_pressed = true
	editor.faction_option.selected = UnitReference.Faction.PLAYER
	editor._apply_inspector(true)
	assert_false(_map_units()["bandit"].commander)


func test_unmarking_and_undo() -> void:
	editor._select_unit("bandit")
	editor.commander_check.button_pressed = true
	editor.undo()
	assert_false(editor.level.level_state.map_data.units["bandit"].commander)


func test_leaving_objective_mode_stops_a_pick() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "seize")
	(editor.row_control(Objective.WIN, i, &"choose") as Button).pressed.emit()
	editor._set_mode(MapEditor.Mode.UNITS)
	assert_false(editor.is_picking(), "a pick you can't see is dropped")
	editor._select_unit("bandit")
	_press_key(KEY_ESCAPE)
	assert_eq(editor.selected_unit_id, "", "Esc deselects, as usual in Units mode")


func test_a_seize_cell_must_be_on_the_map() -> void:
	_objective_mode()
	var i := _add(Objective.WIN, "seize")
	(editor.row_control(Objective.WIN, i, &"choose") as Button).pressed.emit()
	var outside := editor.level.level_state.map_data.bounds().end + Vector2i(5, 5)
	editor._objective_click(outside)
	assert_false(editor.has_pending(), "off the map")
	assert_string_contains(editor.status.text, "map")
	editor._objective_click(FREE_CELL)
	assert_true(editor.has_pending(), "a cell on the map is fine")


# --- Enemy AI (Units mode) -----------------------------------------------------------


func _pick_strategy(strategy: String) -> void:
	var i := MapEditor.STRATEGIES.find(strategy)
	editor.strategy_option.select(i)
	editor.strategy_option.item_selected.emit(i)


func test_only_enemies_have_an_ai_setting() -> void:
	editor._select_unit("lyn")
	assert_true(editor.strategy_option.disabled)
	assert_false(editor.team_edit.editable)
	editor._select_unit("bandit")
	assert_false(editor.strategy_option.disabled)
	assert_eq(editor.strategy_option.selected, MapEditor.STRATEGIES.find("aggressive"))


func test_the_team_box_is_only_for_defensive() -> void:
	editor._select_unit("bandit")
	assert_false(editor.team_edit.editable)
	_pick_strategy("defensive")
	assert_eq(_map_units()["bandit"].strategy, "defensive")
	assert_true(editor.team_edit.editable)
	editor.team_edit.text = "camp"
	editor.team_edit.text_submitted.emit("camp")
	assert_eq(_map_units()["bandit"].team, "camp")
	_pick_strategy("stationary")
	assert_eq(_map_units()["bandit"].team, "", "a team only means something for Defensive")
	assert_false(editor.team_edit.editable)


func test_ai_edits_can_be_undone() -> void:
	editor._select_unit("bandit")
	_pick_strategy("stationary")
	editor.undo()
	assert_eq(_map_units()["bandit"].strategy, "aggressive")


func test_a_unit_that_stops_being_an_enemy_loses_its_ai() -> void:
	editor._select_unit("bandit")
	_pick_strategy("defensive")
	editor.team_edit.text = "camp"
	editor.team_edit.text_submitted.emit("camp")
	editor.faction_option.selected = UnitReference.Faction.PLAYER
	editor._apply_inspector(true)
	assert_eq(_map_units()["bandit"].strategy, "aggressive")
	assert_eq(_map_units()["bandit"].team, "")
