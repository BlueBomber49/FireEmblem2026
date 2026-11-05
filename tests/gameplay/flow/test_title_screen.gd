extends GutTest
## TitleScreen: "Press Start" first, then the menu; cancel goes back; each
## option reports its own signal.

const TitleScene: PackedScene = preload("res://gameplay/flow/title_screen.tscn")

var _title: TitleScreen
var _menu: ActionMenu


func before_each() -> void:
	_title = TitleScene.instantiate()
	add_child_autofree(_title)
	_menu = _title.get_node("%Menu")
	watch_signals(_title)


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _press_option(option_id: StringName) -> void:
	var options: Node = _menu.get_node("%Options")
	for button: Button in options.get_children():
		if button.text == String(option_id).capitalize():
			button.pressed.emit()
			return
	fail_test("no button for %s" % option_id)


func test_starts_on_press_start_with_the_menu_hidden() -> void:
	assert_eq(_title.stage, TitleScreen.Stage.PRESS_START)
	assert_true(_title.get_node("%PressStart").visible)
	assert_false(_menu.visible)


func test_confirm_opens_the_menu() -> void:
	_title._unhandled_input(_action(&"confirm"))
	assert_eq(_title.stage, TitleScreen.Stage.MENU)
	assert_false(_title.get_node("%PressStart").visible)
	assert_true(_menu.visible)


func test_cancel_on_press_start_does_nothing() -> void:
	_title._unhandled_input(_action(&"cancel"))
	assert_eq(_title.stage, TitleScreen.Stage.PRESS_START)


func test_cancel_in_the_menu_goes_back_to_press_start() -> void:
	_title._unhandled_input(_action(&"confirm"))
	_menu._unhandled_input(_action(&"cancel"))
	assert_eq(_title.stage, TitleScreen.Stage.PRESS_START)
	assert_true(_title.get_node("%PressStart").visible)
	assert_false(_menu.visible)


func test_new_game_reports_new_game_only() -> void:
	_title._unhandled_input(_action(&"confirm"))
	_press_option(&"new_game")
	assert_signal_emit_count(_title, "new_game_chosen", 1)
	assert_signal_not_emitted(_title, "quit_chosen")


func test_quit_reports_quit_only() -> void:
	_title._unhandled_input(_action(&"confirm"))
	_press_option(&"quit")
	assert_signal_emit_count(_title, "quit_chosen", 1)
	assert_signal_not_emitted(_title, "new_game_chosen")
