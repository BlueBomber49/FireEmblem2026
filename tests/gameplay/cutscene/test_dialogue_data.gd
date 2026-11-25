extends GutTest
## DialogueData: the real dialogue files load cleanly, and hand-editing mistakes
## are reported (naming the file and line) instead of crashing.

const FIXTURES := "res://tests/fixtures/dialogue"


func test_every_real_dialogue_file_loads_without_errors() -> void:
	# The dev levels' dialogue is in a subfolder (dev/); check it too.
	var dirs := [DialogueData.DEFAULT_DIR]
	for sub in DirAccess.get_directories_at(DialogueData.DEFAULT_DIR):
		dirs.append(DialogueData.DEFAULT_DIR.path_join(sub))
	var checked := 0
	for dir: String in dirs:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".json"):
				continue
			var d := DialogueData.read(dir.path_join(file))
			assert_eq(d.errors, PackedStringArray(), dir.path_join(file))
			assert_gt(d.lines.size(), 0, dir.path_join(file))
			checked += 1
	assert_gt(checked, 0)


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


func test_a_line_background_with_no_image_drops_only_that_line() -> void:
	var d := DialogueData.read(FIXTURES.path_join("bad_line_background.json"))
	assert_eq(d.errors.size(), 1)
	assert_string_contains(d.errors[0], "lines[0]")
	assert_eq(d.lines.size(), 1, "'none' isn't an image, so it isn't checked for one")
	assert_eq(d.lines[0].background, DialogueData.NO_BACKGROUND)


# --- Speakers without a character file ---------------------------------------------


func test_a_line_can_name_its_own_portrait_and_name() -> void:
	var d := DialogueData.read(FIXTURES.path_join("inline_speaker.json"))
	assert_eq(d.errors, PackedStringArray())
	var bandit := d.lines[0]
	assert_eq(bandit.display_name(), "Bandit")
	assert_eq(bandit.portrait_id(), "bandit")
	assert_false(bandit.is_narration())
	assert_true(d.lines[1].display_name() != "", "a character line still works")
	assert_eq(d.lines[1].portrait_id(), "adelard")
	var voice := d.lines[2]
	assert_false(voice.is_narration(), "a name alone is a speaker too")
	assert_eq(voice.display_name(), "Voice")


func test_a_portrait_with_no_image_drops_only_that_line() -> void:
	var d := DialogueData.read(FIXTURES.path_join("bad_portrait.json"))
	assert_eq(d.errors.size(), 1)
	assert_string_contains(d.errors[0], "nobody_here")
	assert_eq(d.lines.size(), 1)
	assert_eq(d.lines[0].speaker, &"adelard")