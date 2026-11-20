extends GutTest
## Every chapter in resources/campaign.json can actually be played: its level
## loads, every unit on it can be built (a missing class file would leave a unit
## off the map, and could win a Rout at once), its events are valid, and every
## dialogue it uses (intro, outro, event steps, quotes) loads cleanly.


func _dialogue_problems(dialogue_id: String, where: String) -> PackedStringArray:
	var path := DialogueData.path_for(StringName(dialogue_id))
	if not FileAccess.file_exists(path):
		return PackedStringArray(["%s: dialogue '%s' doesn't exist." % [where, dialogue_id]])
	var data := DialogueData.read(path)
	var problems := PackedStringArray()
	for error in data.errors:
		problems.append("%s: %s" % [where, error])
	if data.lines.is_empty():
		problems.append("%s: dialogue '%s' has no lines." % [where, dialogue_id])
	return problems


func _chapter_problems(chapter: Campaign.Chapter) -> PackedStringArray:
	var problems := PackedStringArray()
	for dialogue_id in [chapter.intro, chapter.outro]:
		if not String(dialogue_id).is_empty():
			problems.append_array(_dialogue_problems(dialogue_id, "chapter '%s'" % chapter.id))
	var state := LevelState.load_file(chapter.level_path())
	if state == null:
		problems.append("chapter '%s': level %s doesn't load." % [chapter.id, chapter.level_path()])
		return problems
	for ref: UnitReference in state.map_data.units.values():
		var problem := ref.build_problem()
		if not problem.is_empty():
			problems.append("level '%s': %s" % [chapter.level, problem])
		for quote in ref.quotes:
			problems.append_array(_dialogue_problems(quote["dialogue"], "level '%s' unit '%s'" % [chapter.level, ref.id]))
		if not ref.death_quote.is_empty():
			problems.append_array(_dialogue_problems(ref.death_quote, "level '%s' unit '%s'" % [chapter.level, ref.id]))
	for event_id: String in state.events:
		var event: Variant = state.events[event_id]
		var problem := LevelState.event_problem(event)
		if not problem.is_empty():
			problems.append("level '%s' event '%s': %s" % [chapter.level, event_id, problem])
			continue
		for action: Dictionary in (event as Dictionary).get("actions", []):
			if action["type"] == "dialogue":
				problems.append_array(_dialogue_problems(action["dialogue"],
						"level '%s' event '%s'" % [chapter.level, event_id]))
	return problems


func test_the_campaign_reads_cleanly() -> void:
	var campaign := Campaign.read()
	assert_eq(campaign.errors, PackedStringArray())
	assert_gt(campaign.chapters.size(), 0)


func test_every_chapter_can_be_played() -> void:
	for chapter in Campaign.read().chapters:
		assert_eq(_chapter_problems(chapter), PackedStringArray(), "chapter '%s'" % chapter.id)
