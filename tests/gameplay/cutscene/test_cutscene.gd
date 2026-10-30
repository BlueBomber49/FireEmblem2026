extends GutTest
## Cutscene: what confirm and cancel do while a line types, after it's shown,
## and on the last line.

const CutsceneScene: PackedScene = preload("res://gameplay/cutscene/cutscene.tscn")

var _cutscene: Cutscene


func before_each() -> void:
	var data := DialogueData.new()
	for speaker: StringName in [&"adelard", &"rowland", &""]:
		var line := DialogueData.Line.new()
		line.speaker = speaker
		line.side = &"right" if speaker == &"rowland" else &"left"
		line.text = "A line long enough to still be typing when the test checks."
		data.lines.append(line)
	_cutscene = CutsceneScene.instantiate()
	_cutscene.play(data)
	add_child_autofree(_cutscene)
	watch_signals(_cutscene)


func test_starts_typing_the_first_line() -> void:
	assert_eq(_cutscene.line_index, 0)
	assert_true(_cutscene.is_typing())


func test_advance_while_typing_shows_the_whole_line() -> void:
	_cutscene.advance()
	assert_eq(_cutscene.line_index, 0)
	assert_false(_cutscene.is_typing())
	assert_eq(_cutscene.get_node("%Text").visible_ratio, 1.0)


func test_advance_after_typing_goes_to_the_next_line() -> void:
	_cutscene.advance()
	_cutscene.advance()
	assert_eq(_cutscene.line_index, 1)
	assert_true(_cutscene.is_typing())


func test_advance_past_the_last_line_finishes_once() -> void:
	for i in 6:
		_cutscene.advance()
	assert_signal_emit_count(_cutscene, "finished", 1)
	_cutscene.advance()
	assert_signal_emit_count(_cutscene, "finished", 1)


func test_skip_finishes_from_anywhere() -> void:
	_cutscene.skip()
	assert_signal_emitted(_cutscene, "finished")


func test_speaker_is_lit_and_the_other_side_dimmed() -> void:
	var left: TextureRect = _cutscene.get_node("%LeftPortrait")
	var right: TextureRect = _cutscene.get_node("%RightPortrait")
	assert_eq(left.modulate, Color.WHITE)
	assert_eq(right.modulate, Cutscene.DIM_TINT)
	_cutscene.advance()
	_cutscene.advance()
	assert_eq(left.modulate, Cutscene.DIM_TINT)
	assert_eq(right.modulate, Color.WHITE)


func test_narration_hides_the_name_and_keeps_portraits() -> void:
	for i in 4:
		_cutscene.advance()
	assert_eq(_cutscene.line_index, 2)
	assert_false(_cutscene.get_node("%NameLabel").visible)
	assert_not_null((_cutscene.get_node("%LeftPortrait") as TextureRect).texture)
