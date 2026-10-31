extends GutTest

const ItemMenuScene: PackedScene = preload("res://gameplay/ui/item_menu.tscn")

var _menu: ItemMenu


func before_each() -> void:
	_menu = ItemMenuScene.instantiate() as ItemMenu
	add_child_autofree(_menu)


# Old rows are queue_freed, so let a frame pass before GUT counts orphans.
func after_each() -> void:
	await get_tree().process_frame


## Iron Sword (equipped), Iron Lance (Lyn can't wield it), Vulnerary.
func _info(vulnerary_usable := true) -> UnitInfo:
	var info := UnitInfo.new()
	var sword := UnitInfo.ItemInfo.new()
	sword.item_name = "Iron Sword"
	sword.is_weapon = true
	sword.equipped = true
	sword.usable = true
	sword.weapon_type = "Sword"
	sword.might = 5
	sword.hit = 90
	sword.weight = 5
	sword.min_range = 1
	sword.max_range = 1
	var lance := UnitInfo.ItemInfo.new()
	lance.item_name = "Iron Lance"
	lance.is_weapon = true
	lance.weapon_type = "Lance"
	lance.might = 7
	lance.min_range = 1
	lance.max_range = 1
	var vulnerary := UnitInfo.ItemInfo.new()
	vulnerary.item_name = "Vulnerary"
	vulnerary.usable = vulnerary_usable
	vulnerary.uses_left = 2
	vulnerary.max_uses = 3
	vulnerary.heal_amount = 10
	info.items = [sword, lance, vulnerary] as Array[UnitInfo.ItemInfo]
	return info


func _rows() -> Array[Node]:
	return _menu.get_node("%Rows").get_children()


func _row_text(index: int, column: String) -> String:
	return (_rows()[index].get_node("Columns/" + column) as Label).text


func _submenu() -> ActionMenu:
	return _menu.get_node("%ActionSubmenu") as ActionMenu


func _cancel() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"cancel"
	event.pressed = true
	return event


func test_starts_hidden() -> void:
	assert_false(_menu.visible)


func test_one_row_per_item_in_order() -> void:
	_menu.open(_info())
	assert_true(_menu.visible)
	assert_eq(_rows().size(), 3)
	assert_eq(_row_text(0, "ItemName"), "Iron Sword")
	assert_eq(_row_text(2, "ItemName"), "Vulnerary")


func test_equipped_marker_and_uses() -> void:
	_menu.open(_info())
	assert_eq(_row_text(0, "Equipped"), "E")
	assert_eq(_row_text(1, "Equipped"), "")
	assert_eq(_row_text(0, "Uses"), "--", "weapons don't track uses")
	assert_eq(_row_text(2, "Uses"), "2/3")


func test_open_focuses_the_first_row() -> void:
	_menu.open(_info())
	assert_true((_rows()[0] as Button).has_focus())


func test_cursor_wraps_between_first_and_last() -> void:
	_menu.open(_info())
	var first := _rows()[0] as Button
	var last := _rows()[2] as Button
	assert_eq(first.get_node(first.focus_neighbor_top), last)
	assert_eq(last.get_node(last.focus_neighbor_bottom), first)


func test_unusable_rows_are_grey_but_focusable() -> void:
	_menu.open(_info())
	var lance := _rows()[1] as Button
	var name_label := lance.get_node("Columns/ItemName") as Label
	assert_eq(name_label.get_theme_color(&"font_color"), ItemMenu.UNUSABLE_COLOR)
	lance.grab_focus()
	assert_true(lance.has_focus(), "can still be highlighted to read its stats")


func test_pressing_an_unusable_row_opens_nothing() -> void:
	_menu.open(_info())
	(_rows()[1] as Button).pressed.emit()
	assert_false(_submenu().visible)


func test_weapon_row_offers_equip_and_consumable_offers_use() -> void:
	_menu.open(_info())
	(_rows()[0] as Button).pressed.emit()
	assert_true(_submenu().visible)
	assert_eq(_submenu().options, [&"equip"] as Array[StringName])
	_menu.back()
	(_rows()[2] as Button).pressed.emit()
	assert_eq(_submenu().options, [&"use"] as Array[StringName])


func test_picking_from_the_submenu_emits_the_action_and_slot() -> void:
	watch_signals(_menu)
	_menu.open(_info())
	(_rows()[2] as Button).pressed.emit()
	_submenu().option_selected.emit(&"use")
	assert_signal_emitted_with_parameters(_menu, "action_chosen", [&"use", 2])


func test_back_steps_from_submenu_to_list_then_out() -> void:
	watch_signals(_menu)
	_menu.open(_info())
	(_rows()[2] as Button).pressed.emit()
	_menu.back()
	assert_false(_submenu().visible)
	assert_true(_menu.visible)
	assert_true((_rows()[2] as Button).has_focus(), "back on the row it came from")
	assert_signal_not_emitted(_menu, "cancelled")
	_menu.back()
	assert_false(_menu.visible)
	assert_signal_emitted(_menu, "cancelled")


func test_cancel_key_closes_the_list() -> void:
	watch_signals(_menu)
	_menu.open(_info())
	_menu._unhandled_input(_cancel())
	assert_false(_menu.visible)
	assert_signal_emitted(_menu, "cancelled")


func test_cancel_key_is_left_to_an_open_submenu() -> void:
	watch_signals(_menu)
	_menu.open(_info())
	(_rows()[0] as Button).pressed.emit()
	_menu._unhandled_input(_cancel())
	assert_true(_menu.visible)
	assert_signal_not_emitted(_menu, "cancelled")


func test_stats_panel_shows_weapon_stats_or_effect_text() -> void:
	_menu.open(_info())
	assert_true((_menu.get_node("%WeaponStats") as Control).visible)
	assert_eq((_menu.get_node("%TypeLabel") as Label).text, "Sword")
	assert_eq((_menu.get_node("%Might") as Label).text, "5")
	assert_eq((_menu.get_node("%Hit") as Label).text, "90")
	assert_eq((_menu.get_node("%Range") as Label).text, "1")
	assert_false((_menu.get_node("%EffectLabel") as Label).visible)

	(_rows()[2] as Button).grab_focus()
	assert_false((_menu.get_node("%WeaponStats") as Control).visible)
	assert_true((_menu.get_node("%EffectLabel") as Label).visible)
	assert_eq((_menu.get_node("%EffectLabel") as Label).text, "Restores 10 HP")


func test_refresh_rebuilds_and_focuses_the_given_row() -> void:
	_menu.open(_info())
	var info := _info()
	info.items.remove_at(1)
	_menu.refresh(info, 1)
	await wait_process_frames(1)
	assert_eq(_rows().size(), 2)
	assert_eq(_row_text(1, "ItemName"), "Vulnerary")
	assert_true((_rows()[1] as Button).has_focus())


func test_refresh_keeps_the_list_the_same_height() -> void:
	_menu.open(_info())
	await wait_process_frames(2)
	var list := _menu.get_node("ListPanel") as Control
	var height := list.size.y
	_menu.refresh(_info())
	await wait_process_frames(2)
	assert_eq(list.size.y, height, "rows measured with the theme, not the default font")
