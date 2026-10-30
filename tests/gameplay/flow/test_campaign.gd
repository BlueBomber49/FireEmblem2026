extends GutTest
## The real campaign file: every chapter points at dialogue and level files that
## exist and load, so a typo shows up here instead of mid-playthrough.


func test_campaign_loads_without_errors() -> void:
	var campaign := Campaign.read()
	assert_eq(campaign.errors, PackedStringArray())
	assert_gt(campaign.chapters.size(), 0)


func test_every_chapter_cutscene_loads_without_errors() -> void:
	for chapter in Campaign.read().chapters:
		for dialogue_id: StringName in [chapter.intro, chapter.outro]:
			if dialogue_id.is_empty():
				continue
			var d := DialogueData.read(DialogueData.path_for(dialogue_id))
			assert_eq(d.errors, PackedStringArray(), "%s: %s" % [chapter.id, dialogue_id])


func test_every_chapter_level_loads() -> void:
	for chapter in Campaign.read().chapters:
		assert_not_null(LevelState.load_file(chapter.level_path()), String(chapter.id))
