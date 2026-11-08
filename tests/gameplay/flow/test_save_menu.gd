extends GutTest
## SaveMenu (placeholder): save mode asks first, then lists the files; load mode
## lists them. Uses a test save folder.

const MenuScene: PackedScene = preload("res://gameplay/flow/save_menu.tscn")
const TEST_DIR := "user://test_save_menu"

var _real_dir: String
var _menu: SaveMenu


func before_each() -> void:
	_real_dir = SaveSlots.dir
	SaveSlots.dir = TEST_DIR
	_clear()


func after_each() -> void:
	await get_tree().process_frame
	_clear()
	DirAccess.remove_absolute(TEST_DIR)
	SaveSlots.dir = _real_dir


func _clear() -> void:
	for slot in SaveSlots.COUNT:
		if FileAccess.file_exists(SaveSlots.path(slot)):
			DirAccess.remove_absolute(SaveSlots.path(slot))


func _open(loading: bool) -> void:
	_menu = MenuScene.instantiate()
	_menu.loading = loading
	_menu.chapter_id = &"chapter_2"
	_menu.chapter_index = 1
	_menu.roster = {"lyn": {"level": 3}}
	add_child_autofree(_menu)
	watch_signals(_menu)


func _choose(option_id: StringName) -> void:
	_menu.menu.option_selected.emit(option_id)


func _cancel() -> void:
	_menu.menu.cancelled.emit()


func test_save_mode_asks_first() -> void:
	_open(false)
	assert_eq(_menu.menu.options, [&"save", &"continue"] as Array[StringName])
	assert_string_contains(_menu.title_text(), "Save your progress")


func test_continue_finishes_without_saving() -> void:
	_open(false)
	_choose(&"continue")
	assert_signal_emit_count(_menu, "finished", 1)
	assert_false(SaveSlots.has_any())


func test_saving_to_an_empty_file() -> void:
	_open(false)
	_choose(&"save")
	assert_eq(_menu.menu.options.size(), SaveSlots.COUNT)
	assert_eq(_menu.menu.labels[&"slot_0"], "File 1   (empty)")
	_choose(&"slot_0")
	assert_signal_emit_count(_menu, "finished", 1)
	var saved := SaveSlots.read(0)
	assert_eq(saved["chapter_id"], "chapter_2")
	assert_eq(int(saved["roster"]["lyn"]["level"]), 3)


func test_a_used_file_asks_before_overwriting() -> void:
	SaveSlots.write(1, &"prologue", 0, {})
	_open(false)
	_choose(&"save")
	assert_string_contains(_menu.menu.labels[&"slot_1"], "prologue")
	_choose(&"slot_1")
	assert_string_contains(_menu.title_text(), "Overwrite File 2")
	_choose(&"no")
	assert_signal_not_emitted(_menu, "finished")
	assert_eq(SaveSlots.read(1)["chapter_id"], "prologue", "untouched")
	_choose(&"slot_1")
	_choose(&"yes")
	assert_signal_emit_count(_menu, "finished", 1)
	assert_eq(SaveSlots.read(1)["chapter_id"], "chapter_2")


func test_cancel_in_the_file_list_goes_back_to_the_question() -> void:
	_open(false)
	_choose(&"save")
	_cancel()
	assert_eq(_menu.menu.options, [&"save", &"continue"] as Array[StringName])
	_cancel()
	assert_true(_menu.menu.visible, "nothing to back out to: the question stays")
	assert_signal_not_emitted(_menu, "finished")


func test_load_mode_lists_the_files_and_loads_a_used_one() -> void:
	SaveSlots.write(2, &"prologue", 0, {})
	_open(true)
	assert_eq(_menu.menu.options.size(), SaveSlots.COUNT)
	_choose(&"slot_0")
	assert_signal_not_emitted(_menu, "slot_loaded", "an empty file does nothing")
	_choose(&"slot_2")
	assert_signal_emitted_with_parameters(_menu, "slot_loaded", [2])


func test_cancel_in_load_mode_goes_back() -> void:
	_open(true)
	_cancel()
	assert_signal_emit_count(_menu, "back", 1)


func test_a_failed_save_says_so_and_stays() -> void:
	# A file where the save folder should be: the folder can't be made.
	var blocker := FileAccess.open("user://test_save_menu_blocked", FileAccess.WRITE)
	blocker.close()
	SaveSlots.dir = "user://test_save_menu_blocked"
	_open(false)
	_choose(&"save")
	_choose(&"slot_0")
	assert_signal_not_emitted(_menu, "finished")
	assert_string_contains(_menu.title_text(), "Couldn't save to File 1")
	assert_eq(_menu.stage, SaveMenu.Stage.FILES, "another file can be picked")
	assert_push_error("can't write")
	SaveSlots.dir = TEST_DIR
	DirAccess.remove_absolute("user://test_save_menu_blocked")
