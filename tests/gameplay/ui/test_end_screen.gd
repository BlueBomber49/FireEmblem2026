extends GutTest

const EndScreenScene: PackedScene = preload("res://gameplay/ui/end_screen.tscn")

var _screen: EndScreen


func before_each() -> void:
	_screen = EndScreenScene.instantiate() as EndScreen
	add_child_autofree(_screen)


func _title() -> TextureRect:
	return _screen.get_node("%Title") as TextureRect


func _band() -> PanelContainer:
	return _screen.get_node("%Band") as PanelContainer


func _confirm() -> void:
	var event := InputEventAction.new()
	event.action = &"confirm"
	event.pressed = true
	_screen._unhandled_input(event)


func test_starts_hidden() -> void:
	assert_false(_screen.visible)


func test_a_win_shows_stage_clear_in_gold() -> void:
	_screen.show_result(true)
	assert_true(_screen.visible)
	assert_eq(_title().texture, EndScreen.CLEAR_ART)
	assert_eq(_band().theme_type_variation, &"EndBannerClear")


func test_a_loss_shows_defeat_in_red() -> void:
	_screen.show_result(false)
	assert_eq(_title().texture, EndScreen.DEFEAT_ART)
	assert_eq(_band().theme_type_variation, &"EndBannerDefeat")


func test_confirm_asks_for_a_restart() -> void:
	watch_signals(_screen)
	_screen.show_result(true)
	_confirm()
	assert_signal_emitted(_screen, "restart_requested")


func test_confirm_does_nothing_while_hidden() -> void:
	watch_signals(_screen)
	_confirm()
	assert_signal_not_emitted(_screen, "restart_requested")


func test_a_click_asks_for_a_restart() -> void:
	watch_signals(_screen)
	_screen.show_result(false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_screen._gui_input(click)
	assert_signal_emitted(_screen, "restart_requested")
