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


# --- Saving between chapters and the roster -----------------------------------------
# The prompt is decided by advance_state (offer_save), so it's testable here.


func test_moving_on_to_another_chapter_offers_a_save() -> void:
	_flow.step = Step.BATTLE
	_flow.advance_state(true)  # -> one's outro
	assert_false(_flow.offer_save, "still in chapter one")
	_flow.advance_state()  # -> two (no intro): its battle
	_assert_at(1, Step.BATTLE)
	assert_true(_flow.offer_save)


func test_a_chapter_without_an_outro_still_offers_a_save() -> void:
	var campaign := Campaign.new()
	campaign.chapters.append(_chapter(&"one", &"", &""))
	campaign.chapters.append(_chapter(&"two", &"two_intro", &""))
	_flow.campaign = campaign
	_flow.step = Step.BATTLE
	_flow.advance_state(true)
	_assert_at(1, Step.INTRO)
	assert_true(_flow.offer_save)


func test_a_loss_or_the_last_chapter_offers_no_save() -> void:
	_flow.step = Step.BATTLE
	_flow.advance_state(false)
	assert_false(_flow.offer_save, "a retry")
	_flow.chapter_index = 1
	_flow.step = Step.BATTLE
	_flow.advance_state(true)
	assert_eq(_flow.step, Step.DONE)
	assert_false(_flow.offer_save, "nothing comes after the last chapter")


func test_a_saved_chapter_is_found_by_id_then_by_index() -> void:
	assert_eq(_flow.saved_chapter_index({"chapter_id": "two", "chapter_index": 0}), 1, "the id wins")
	assert_eq(_flow.saved_chapter_index({"chapter_id": "gone", "chapter_index": 1}), 1, "else the index")
	assert_eq(_flow.saved_chapter_index({"chapter_id": "gone", "chapter_index": 9}), 0, "else the start")


func test_a_win_keeps_the_armys_progress() -> void:
	var level := Level.new()
	level.level_path = "res://resources/levels/test_level.json"
	add_child_autofree(level)
	level.level_state.level_units["lyn"].unit.level = 4
	_flow.keep_progress(level)
	assert_eq(int(_flow.roster["lyn"]["level"]), 4)


func test_a_new_game_clears_the_roster() -> void:
	_flow.roster = {"lyn": {"level": 9}}
	_flow.reset_progress()
	assert_eq(_flow.roster, {})
