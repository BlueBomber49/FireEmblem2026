extends GutTest

const ActionMenuScene: PackedScene = preload("res://gameplay/action_menu.tscn")

var _menu: ActionMenu


func before_each() -> void:
	_menu = ActionMenuScene.instantiate() as ActionMenu
	_menu.options = [&"attack", &"item", &"wait"]
	add_child_autofree(_menu)


func _buttons() -> Array[Node]:
	return _menu.get_node("%Options").get_children()


func test_starts_hidden() -> void:
	assert_false(_menu.visible)


func test_open_shows_one_button_per_option() -> void:
	_menu.open()
	assert_true(_menu.visible)
	var labels: Array[String] = []
	for button: Node in _buttons():
		labels.append((button as Button).text)
	assert_eq(labels, ["Attack", "Item", "Wait"] as Array[String])


func test_open_focuses_first_option() -> void:
	_menu.open()
	assert_true((_buttons()[0] as Button).has_focus())


func test_open_with_new_options_replaces_old_ones() -> void:
	_menu.open()
	_menu.open([&"end"])
	assert_eq(_buttons().size(), 1)
	assert_eq((_buttons()[0] as Button).text, "End")


func test_cursor_wraps_between_first_and_last() -> void:
	_menu.open()
	var first := _buttons()[0] as Button
	var last := _buttons()[2] as Button
	assert_eq(first.get_node(first.focus_neighbor_top), last)
	assert_eq(last.get_node(last.focus_neighbor_bottom), first)


func test_pressing_option_emits_its_id_and_closes() -> void:
	watch_signals(_menu)
	_menu.open()
	(_buttons()[1] as Button).pressed.emit()
	assert_signal_emitted_with_parameters(_menu, "option_selected", [&"item"])
	assert_false(_menu.visible)


func test_cancel_closes_and_emits_cancelled() -> void:
	watch_signals(_menu)
	_menu.open()
	var event := InputEventAction.new()
	event.action = &"cancel"
	event.pressed = true
	_menu._unhandled_input(event)
	assert_signal_emitted(_menu, "cancelled")
	assert_false(_menu.visible)
