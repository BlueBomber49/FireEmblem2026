extends GutTest
## GameFlow's order of steps, checked with advance_state() so no scenes are
## swapped. The campaign is built here: "one" has both cutscenes, "two" has
## neither, so skipping empty steps is covered too.

const GameFlowScript := preload("res://gameplay/flow/game_flow.gd")
const Step := GameFlowScript.Step

var _flow: Node


func before_each() -> void:
	_flow = autofree(GameFlowScript.new())
	var campaign := Campaign.new()
	campaign.chapters.append(_chapter(&"one", &"one_intro", &"one_outro"))
	campaign.chapters.append(_chapter(&"two", &"", &""))
	_flow.campaign = campaign
	_flow.chapter_index = 0
	_flow.step = Step.INTRO


func _chapter(id: StringName, intro: StringName, outro: StringName) -> Campaign.Chapter:
	var chapter := Campaign.Chapter.new()
	chapter.id = id
	chapter.intro = intro
	chapter.outro = outro
	chapter.level = id
	return chapter


func _assert_at(chapter_index: int, step: int) -> void:
	assert_eq(_flow.chapter_index, chapter_index, "chapter")
	assert_eq(_flow.step, step, "step %s" % Step.keys()[_flow.step])


func test_intro_leads_to_the_battle() -> void:
	_flow.advance_state()
	_assert_at(0, Step.BATTLE)


func test_won_battle_leads_to_the_outro() -> void:
	_flow.step = Step.BATTLE
	_flow.advance_state(true)
	_assert_at(0, Step.OUTRO)


func test_lost_battle_retries_the_battle() -> void:
	_flow.step = Step.BATTLE
	_flow.advance_state(false)
	_assert_at(0, Step.BATTLE)


func test_outro_leads_to_the_next_chapter_skipping_its_missing_intro() -> void:
	_flow.step = Step.OUTRO
	_flow.advance_state()
	_assert_at(1, Step.BATTLE)


func test_last_battle_without_an_outro_finishes_the_campaign() -> void:
	_flow.chapter_index = 1
	_flow.step = Step.BATTLE
	_flow.advance_state(true)
	assert_eq(_flow.step, Step.DONE)


func test_done_stays_done() -> void:
	_flow.step = Step.DONE
	_flow.advance_state()
	assert_eq(_flow.step, Step.DONE)
