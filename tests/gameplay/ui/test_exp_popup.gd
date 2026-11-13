extends GutTest

const PopupScene: PackedScene = preload("res://gameplay/ui/exp_popup.tscn")

var popup: ExpPopup


func before_each() -> void:
	popup = PopupScene.instantiate()
	add_child_autofree(popup)
	popup.fill_time = 0.01
	popup.wait_for_player = false
	popup.hold_time = 0.0


func test_starts_hidden() -> void:
	assert_false(popup.visible)


func test_play_shows_the_gain_then_hides() -> void:
	await popup.play("Lyn", 20, 33, [] as Array[Dictionary], 53)
	assert_false(popup.visible)
	assert_eq(popup.get_node("%Bar").value, 53.0)
	assert_string_contains(popup.get_node("%Title").text, "EXP +33")


func test_a_level_up_shows_the_stats() -> void:
	await popup.play("Lyn", 80, 33, [{&"hp": 1, &"speed": 1}] as Array[Dictionary], 13)
	assert_string_contains(popup.get_node("%Title").text, "LEVEL UP!")
	assert_eq(popup.get_node("%Gains").text, "HP +1  Spd +1")


func test_gains_text_with_nothing_rising() -> void:
	assert_eq(ExpPopup.gains_text({}), "No stats rose")


func test_gains_wrap_four_to_a_line() -> void:
	var up := {&"hp": 1, &"strength": 1, &"skill": 1, &"speed": 1, &"luck": 1}
	assert_eq(ExpPopup.gains_text(up), "HP +1  Str +1  Skl +1  Spd +1\nLck +1")


func test_after_a_level_up_the_bar_shows_the_leftover() -> void:
	await popup.play("Lyn", 80, 50, [{&"hp": 1}] as Array[Dictionary], 30)
	assert_eq(popup.get_node("%Bar").value, 30.0)


func _confirm() -> void:
	var event := InputEventAction.new()
	event.action = &"confirm"
	event.pressed = true
	popup._unhandled_input(event)


func test_each_screen_waits_for_the_player() -> void:
	popup.wait_for_player = true
	popup.play("Lyn", 80, 50, [{&"hp": 1}] as Array[Dictionary], 30)  # not awaited
	await wait_seconds(0.3)
	assert_true(popup.visible, "the EXP screen waits")
	_confirm()
	await wait_seconds(0.3)
	assert_true(popup.visible, "now the level-up screen waits")
	assert_string_contains(popup.get_node("%Title").text, "LEVEL UP!")
	_confirm()
	await wait_until(func() -> bool: return not popup.visible, 1.0)
	assert_false(popup.visible)


func test_a_press_during_the_fill_finishes_it_and_the_next_moves_on() -> void:
	popup.wait_for_player = true
	popup.fill_time = 5.0
	popup.play("Lyn", 10, 20, [] as Array[Dictionary], 30)  # not awaited
	await get_tree().process_frame
	_confirm()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(popup.get_node("%Bar").value, 30.0, "the fill jumps to its end")
	assert_null(popup._tween, "no fill left running")
	assert_true(popup.visible, "and the screen still waits")
	_confirm()
	await wait_until(func() -> bool: return not popup.visible, 1.0)
	assert_false(popup.visible)

func test_reaching_level_twenty_ends_the_bar_at_zero() -> void:
	# Level 19 at 80 EXP gaining 50: level 20, where EXP is 0 (not 30).
	await popup.play("Lyn", 80, 50, [{&"hp": 1}] as Array[Dictionary], 0)
	assert_eq(popup.get_node("%Bar").value, 0.0)
