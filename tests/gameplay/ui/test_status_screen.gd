extends GutTest

const StatusScreenScene: PackedScene = preload("res://gameplay/ui/status_screen.tscn")

var _screen: StatusScreen


func before_each() -> void:
	_screen = StatusScreenScene.instantiate() as StatusScreen
	add_child_autofree(_screen)


func _lyn_info() -> UnitInfo:
	var unit := Unit.new(GameData.get_character(&"lyn"))
	unit.experience = 42
	return UnitInfo.from_unit(unit)


func _label(unique_name: String) -> Label:
	return _screen.get_node("%" + unique_name) as Label


func _stat(field: String) -> Label:
	return _screen.get_node("%StatGrid").get_node(field.to_pascal_case()) as Label


func _item_label(row: int, label_name: String) -> Label:
	return _screen.get_node("%ItemRows").get_child(row).get_node(label_name) as Label


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_screen._unhandled_input(event)


func test_starts_hidden() -> void:
	assert_false(_screen.visible)


func test_header_and_stats() -> void:
	var info := _lyn_info()
	_screen.open(info, true)
	assert_true(_screen.visible)
	assert_eq(_label("UnitName").text, "Lyn")
	assert_eq(_label("ClassName").text, "Myrmidon")
	assert_eq(_label("Level").text, "1")
	assert_eq(_label("Experience").text, "42")
	assert_eq(_label("Hp").text, "16/16")
	assert_eq(_label("Movement").text, str(info.stats["movement"]))
	assert_eq(_label("Constitution").text, str(info.stats["constitution"]))
	assert_eq(_stat("speed").text, str(info.stats["speed"]))
	assert_eq(_stat("resistance").text, str(info.stats["resistance"]))


func test_inventory_rows() -> void:
	_screen.open(_lyn_info(), true)
	assert_eq(_screen.get_node("%ItemRows").get_child_count(), StatusScreen.ITEM_ROWS)
	assert_eq(_item_label(0, "Equipped").text, "E")
	assert_eq(_item_label(0, "ItemName").text, "Iron Sword")
	assert_eq(_item_label(0, "Uses").text, "--")
	assert_eq(_item_label(1, "Equipped").text, "")
	assert_eq(_item_label(1, "ItemName").text, "Vulnerary")
	assert_eq(_item_label(1, "Uses").text, "3/3")
	assert_eq(_item_label(1, "ItemName").get_theme_color(&"font_color"), StatusScreen.UNUSABLE_COLOR,
			"a Vulnerary at full HP is greyed out")
	assert_eq(_item_label(2, "ItemName").text, "", "empty slots stay blank")


func test_switching_units_keeps_one_size() -> void:
	_screen.open(_lyn_info(), true)
	var panel := _screen.get_node("Center/Panel") as Control
	var full := panel.size
	var empty := UnitInfo.new()
	empty.unit_name = "Nobody"
	_screen.show_unit(empty)
	assert_eq(panel.size, full)


func test_cancel_closes() -> void:
	_screen.open(_lyn_info(), true)
	watch_signals(_screen)
	_press(&"cancel")
	assert_false(_screen.visible)
	assert_signal_emitted(_screen, "closed")


func test_up_and_down_ask_for_other_units() -> void:
	_screen.open(_lyn_info(), true)
	watch_signals(_screen)
	_press(&"ui_up")
	assert_signal_emitted_with_parameters(_screen, "cycle_requested", [-1])
	_press(&"ui_down")
	assert_signal_emitted_with_parameters(_screen, "cycle_requested", [1])


func test_no_cycling_when_opened_without_it() -> void:
	_screen.open(_lyn_info(), false)
	watch_signals(_screen)
	_press(&"ui_down")
	assert_signal_not_emitted(_screen, "cycle_requested")
	assert_true(_screen.visible)
