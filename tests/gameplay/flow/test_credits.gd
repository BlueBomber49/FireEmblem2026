extends GutTest
## Credits: what they show, how they roll, and how they end.

const CreditsScene: PackedScene = preload("res://gameplay/flow/credits.tscn")

var credits: Credits


func before_each() -> void:
	credits = CreditsScene.instantiate()
	add_child_autofree(credits)
	credits.set_process(false)  # the tests drive step() themselves
	credits.get_node("Music").stop()
	watch_signals(credits)
	await get_tree().process_frame  # let the column lay out


func _texts() -> Array[String]:
	var texts: Array[String] = []
	for label in credits.get_node("%Column").find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return texts


func _column_y() -> float:
	return (credits.get_node("%Column") as Control).position.y


func _action(action: StringName, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


func test_shows_the_title_the_team_and_a_closing_line() -> void:
	var texts := _texts()
	assert_eq(texts[0], "Flame Insignia")
	for person in ["Ethan Cox", "Aidan Stay", "Spencer Young", "Tony Johnson", "Tristan Weech"]:
		assert_has(texts, person)
	assert_has(texts, "Mechanics Engineer")
	assert_eq(texts[-1], "Thanks for playing!")


func test_starts_below_the_screen_and_rolls_up() -> void:
	var start := _column_y()
	assert_gte(start, credits.get_viewport_rect().size.y - 1.0)
	credits.step(1.0)
	assert_almost_eq(_column_y(), start - credits.speed, 0.01)


func test_holding_confirm_speeds_it_up() -> void:
	credits._unhandled_input(_action(&"confirm", true))
	var start := _column_y()
	credits.step(1.0)
	assert_almost_eq(_column_y(), start - credits.speed * credits.fast_multiplier, 0.01)
	credits._unhandled_input(_action(&"confirm", false))
	assert_false(credits.fast)


## Rolls until the closing line rests in the middle.
func _roll_to_the_end() -> void:
	for i in 1000:
		credits.step(0.1)
		if credits.resting:
			return


func test_it_rests_on_the_closing_line_with_the_rest_gone() -> void:
	_roll_to_the_end()
	assert_true(credits.resting, "reached the closing line")
	var column: Node = credits.get_node("%Column")
	var closing: Label = column.get_child(-1)
	assert_almost_eq(closing.get_global_rect().get_center().y, credits.get_viewport_rect().size.y / 2.0, 1.0,
			"rests in the middle")
	for i in column.get_child_count() - 2:  # everything before the gap and the closing line
		assert_lt((column.get_child(i) as Control).get_global_rect().end.y, 0.0,
				"%s has rolled off the top" % column.get_child(i).name)


func test_it_waits_for_the_player_at_the_end() -> void:
	_roll_to_the_end()
	credits.step(600.0)
	assert_signal_not_emitted(credits, "finished", "no time limit")
	credits._unhandled_input(_action(&"confirm", true))
	assert_signal_emit_count(credits, "finished", 1)


func test_a_click_ends_it_too() -> void:
	_roll_to_the_end()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	credits._unhandled_input(click)
	assert_signal_emit_count(credits, "finished", 1)


func test_holding_confirm_into_the_end_doesnt_skip_it() -> void:
	credits._unhandled_input(_action(&"confirm", true))
	_roll_to_the_end()
	assert_true(credits.resting)
	credits._unhandled_input(_action(&"confirm", true))  # the key repeating while held
	assert_signal_not_emitted(credits, "finished", "the press that sped it up doesn't also end it")
	credits._unhandled_input(_action(&"confirm", false))
	credits._unhandled_input(_action(&"confirm", true))
	assert_signal_emit_count(credits, "finished", 1)


func test_cancel_ends_it_once() -> void:
	credits._unhandled_input(_action(&"cancel", true))
	credits._unhandled_input(_action(&"cancel", true))
	assert_signal_emit_count(credits, "finished", 1)


func test_a_missing_file_shows_just_the_title() -> void:
	var data := Credits.read("res://no/such/credits.json")
	assert_eq(data["title"], "Flame Insignia")
	assert_eq(data["people"], [])
	assert_push_warning("can't read")