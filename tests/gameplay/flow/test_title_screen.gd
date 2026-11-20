extends GutTest
## TitleScreen: "Press Start" first, then the menu; cancel goes back; each
## option reports its own signal.

const TitleScene: PackedScene = preload("res://gameplay/flow/title_screen.tscn")

var _title: TitleScreen
var _menu: ActionMenu


const TEST_SAVES := "user://test_title_saves"

var _real_saves: String


func before_each() -> void:
	# A test folder, so the player's real saves can't change what the menu shows.
	_real_saves = SaveSlots.dir
	SaveSlots.dir = TEST_SAVES
	_title = TitleScene.instantiate()
	add_child_autofree(_title)
	_menu = _title.get_node("%Menu")
	watch_signals(_title)


func after_each() -> void:
	for slot in SaveSlots.COUNT:
		if FileAccess.file_exists(SaveSlots.path(slot)):
			DirAccess.remove_absolute(SaveSlots.path(slot))
	DirAccess.remove_absolute(TEST_SAVES)
	SaveSlots.dir = _real_saves


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
	# The title waits for the button-press sound before reporting.
	await wait_until(func() -> bool: return get_signal_emit_count(_title, "new_game_chosen") > 0, 2.0)
	assert_signal_emit_count(_title, "new_game_chosen", 1)
	assert_signal_not_emitted(_title, "quit_chosen")


func test_quit_reports_quit_only() -> void:
	_title._unhandled_input(_action(&"confirm"))
	_press_option(&"quit")
	assert_signal_emit_count(_title, "quit_chosen", 1)
	assert_signal_not_emitted(_title, "new_game_chosen")


func test_load_is_offered_only_with_a_save() -> void:
	_title._unhandled_input(_action(&"confirm"))
	assert_false(_menu.options.has(&"load"))
	_menu._unhandled_input(_action(&"cancel"))
	SaveSlots.write(0, &"prologue", 0, {})
	_title._unhandled_input(_action(&"confirm"))
	assert_eq(_menu.options[0], &"load", "first, when there's a save")
	_press_option(&"load")
	assert_signal_emit_count(_title, "load_chosen", 1)
	assert_signal_not_emitted(_title, "new_game_chosen")
