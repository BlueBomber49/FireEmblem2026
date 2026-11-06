extends GutTest
## DialogueData: the real dialogue files load cleanly, and hand-editing mistakes
## are reported (naming the file and line) instead of crashing.

const FIXTURES := "res://tests/fixtures/dialogue"


func test_every_real_dialogue_file_loads_without_errors() -> void:
	var files := DirAccess.get_files_at(DialogueData.DEFAULT_DIR)
	assert_gt(files.size(), 0)
	for file in files:
		if not file.ends_with(".json"):
			continue
		var d := DialogueData.read(DialogueData.DEFAULT_DIR.path_join(file))
		assert_eq(d.errors, PackedStringArray(), file)
		assert_gt(d.lines.size(), 0, file)


func test_empty_speaker_is_narration() -> void:
	var d := DialogueData.read(DialogueData.path_for(&"prologue_intro"))
	var narration := d.lines.filter(func(l: DialogueData.Line) -> bool: return l.speaker.is_empty())
	for line: DialogueData.Line in narration:
		assert_eq(line.display_name(), "")


func test_speaker_name_comes_from_the_character_file() -> void:
	var line := DialogueData.Line.new()
	line.speaker = &"adelard"
	assert_eq(line.display_name(), GameData.get_character(&"adelard").display_name)


func test_unknown_key_drops_only_that_line() -> void:
	var d := DialogueData.read(FIXTURES.path_join("typo_key.json"))
	assert_eq(d.errors.size(), 1)
	assert_string_contains(d.errors[0], "lines[0]")
	assert_string_contains(d.errors[0], "speeker")
	assert_eq(d.lines.size(), 1)
	assert_eq(d.lines[0].speaker, &"rowland")


func test_unknown_speaker_is_reported() -> void:
	var d := DialogueData.read(FIXTURES.path_join("unknown_speaker.json"))
	assert_eq(d.errors.size(), 1)
	assert_string_contains(d.errors[0], "nobody")


func test_bad_side_is_reported() -> void:
	var d := DialogueData.read(FIXTURES.path_join("bad_side.json"))
	assert_eq(d.errors.size(), 1)
	assert_string_contains(d.errors[0], "middle")


func test_missing_file_is_reported() -> void:
	var d := DialogueData.read(FIXTURES.path_join("does_not_exist.json"))
	assert_eq(d.errors.size(), 1)
	assert_eq(d.lines.size(), 0)
