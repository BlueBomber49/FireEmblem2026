extends GutTest
## SaveSlots, in a test folder: never the game's real saves.

const TEST_DIR := "user://test_save_slots"

var _real_dir: String


func before_each() -> void:
	_real_dir = SaveSlots.dir
	SaveSlots.dir = TEST_DIR
	_clear()


func after_each() -> void:
	_clear()
	DirAccess.remove_absolute(TEST_DIR)
	SaveSlots.dir = _real_dir


func _clear() -> void:
	for slot in SaveSlots.COUNT:
		if FileAccess.file_exists(SaveSlots.path(slot)):
			DirAccess.remove_absolute(SaveSlots.path(slot))


func test_slots_start_empty() -> void:
	assert_eq(SaveSlots.read(0), {})
	assert_false(SaveSlots.has_any())
	assert_eq(SaveSlots.summaries(), [{}, {}, {}] as Array[Dictionary])


func test_a_slot_round_trips() -> void:
	var roster := {"lyn": {"level": 3, "experience": 40}}
	assert_eq(SaveSlots.write(1, &"chapter_2", 1, roster), OK)
	var d := SaveSlots.read(1)
	assert_eq(d["chapter_id"], "chapter_2")
	assert_eq(d["chapter_index"], 1, "read back as an int")
	assert_eq(int(d["roster"]["lyn"]["level"]), 3)
	assert_true(SaveSlots.has_any())


func test_summaries_show_used_slots_only() -> void:
	SaveSlots.write(2, &"prologue", 0, {})
	var summaries := SaveSlots.summaries()
	assert_true(summaries[0].is_empty())
	assert_eq(summaries[2]["chapter_id"], "prologue")
	assert_eq(summaries[2]["chapter_index"], 0)
	assert_false(String(summaries[2]["saved_at"]).is_empty())


func test_a_corrupt_slot_reads_as_empty() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file := FileAccess.open(SaveSlots.path(0), FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	assert_eq(SaveSlots.read(0), {})
	file = FileAccess.open(SaveSlots.path(1), FileAccess.WRITE)
	file.store_string("[1, 2]")
	file.close()
	assert_eq(SaveSlots.read(1), {}, "not an object")
	file = FileAccess.open(SaveSlots.path(2), FileAccess.WRITE)
	file.store_string("{\"version\": 1}")
	file.close()
	assert_eq(SaveSlots.read(2), {}, "missing its chapter and roster")
