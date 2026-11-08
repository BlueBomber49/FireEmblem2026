extends GutTest

const PopupScene: PackedScene = preload("res://gameplay/ui/exp_popup.tscn")

var popup: ExpPopup


func before_each() -> void:
	popup = PopupScene.instantiate()
	add_child_autofree(popup)
	popup.fill_time = 0.01
	popup.hold_time = 0.0
	popup.level_up_time = 0.0


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


func test_a_skip_stops_the_fill_and_ends_it_at_once() -> void:
	popup.fill_time = 5.0
	popup.hold_time = 5.0
	popup.play("Lyn", 10, 20, [] as Array[Dictionary], 30)  # not awaited: skipped below
	await get_tree().process_frame
	var confirm := InputEventAction.new()
	confirm.action = &"confirm"
	confirm.pressed = true
	popup._unhandled_input(confirm)
	await wait_until(func() -> bool: return not popup.visible, 1.0)
	assert_false(popup.visible, "skipping didn't wait out the 5s fill or hold")
	assert_eq(popup.get_node("%Bar").value, 30.0, "the bar ends where it should")
	assert_null(popup._tween, "no fill left running")


func test_reaching_level_twenty_ends_the_bar_at_zero() -> void:
	# Level 19 at 80 EXP gaining 50: level 20, where EXP is 0 (not 30).
	await popup.play("Lyn", 80, 50, [{&"hp": 1}] as Array[Dictionary], 0)
	assert_eq(popup.get_node("%Bar").value, 0.0)
