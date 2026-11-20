extends GutTest

const TradeMenuScene: PackedScene = preload("res://gameplay/ui/trade_menu.tscn")

var menu: TradeMenu
var lyn: Unit
var kent: Unit


func before_each() -> void:
	menu = TradeMenuScene.instantiate()
	add_child_autofree(menu)
	lyn = Unit.new(GameData.get_character(&"lyn"))  # Iron Sword, Vulnerary
	kent = Unit.new(GameData.get_character(&"kent"))  # Iron Lance, Iron Sword
	menu.open(lyn, "Lyn", null, kent, "Kent", UnitInfo.portrait_for("adelard"))


# Old rows are queue_freed, so let a frame pass before GUT counts orphans.
func after_each() -> void:
	await get_tree().process_frame


func _ids(unit: Unit) -> Array[StringName]:
	var ids: Array[StringName] = []
	for i in unit.inventory.size():
		ids.append(unit.inventory.get_item(i).data.id)
	return ids


func _cancel() -> void:
	var event := InputEventAction.new()
	event.action = &"cancel"
	event.pressed = true
	menu._unhandled_input(event)


func test_opens_with_both_names_portraits_and_five_slots_each() -> void:
	assert_true(menu.visible)
	assert_eq((menu.get_node("%Left/Name") as Label).text, "Lyn")
	assert_eq((menu.get_node("%Right/Name") as Label).text, "Kent")
	assert_null((menu.get_node("%Left/Portrait") as TextureRect).texture, "no portrait: an empty frame")
	assert_not_null((menu.get_node("%Right/Portrait") as TextureRect).texture)
	assert_true((menu.get_node("%Right/Portrait") as TextureRect).flip_h, "faces inward")
	assert_eq(menu.get_node("%Left/Rows").get_child_count(), 5)
	assert_string_contains(menu.row(TradeMenu.LEFT, 0).text, "E Iron Sword")
	assert_string_contains(menu.row(TradeMenu.LEFT, 1).text, "Vulnerary")
	assert_string_contains(menu.row(TradeMenu.LEFT, 2).text, "-")
	assert_true(menu.row(TradeMenu.LEFT, 0).has_focus())


func test_picking_then_choosing_the_other_side_swaps() -> void:
	menu.choose(TradeMenu.LEFT, 1)  # Vulnerary
	assert_eq(menu.picked, [TradeMenu.LEFT, 1])
	assert_true(menu.row(TradeMenu.RIGHT, 1).has_focus(), "the cursor jumps across")
	menu.choose(TradeMenu.RIGHT, 0)  # Iron Lance
	assert_eq(_ids(lyn), [&"iron_sword", &"iron_lance"] as Array[StringName])
	assert_eq(_ids(kent), [&"vulnerary", &"iron_sword"] as Array[StringName])
	assert_true(menu.traded)
	assert_true(menu.picked.is_empty())
	assert_string_contains(menu.row(TradeMenu.LEFT, 1).text, "Iron Lance", "the rows redraw")


func test_choosing_an_empty_slot_gives_the_item() -> void:
	menu.choose(TradeMenu.RIGHT, 0)
	menu.choose(TradeMenu.LEFT, 4)
	assert_eq(_ids(lyn), [&"iron_sword", &"vulnerary", &"iron_lance"] as Array[StringName])
	assert_eq(_ids(kent), [&"iron_sword"] as Array[StringName])


func test_an_empty_slot_cant_be_picked_first() -> void:
	menu.choose(TradeMenu.LEFT, 3)
	assert_true(menu.picked.is_empty())


func test_choosing_on_the_same_side_picks_that_item_instead() -> void:
	menu.choose(TradeMenu.LEFT, 0)
	menu.choose(TradeMenu.LEFT, 1)
	assert_eq(menu.picked, [TradeMenu.LEFT, 1])
	assert_false(menu.traded)


func test_cancel_drops_the_pick_then_closes() -> void:
	watch_signals(menu)
	menu.choose(TradeMenu.LEFT, 0)
	_cancel()
	assert_true(menu.picked.is_empty())
	assert_true(menu.visible)
	_cancel()
	assert_false(menu.visible)
	assert_signal_emitted_with_parameters(menu, "closed", [false])


func test_closing_after_a_swap_reports_it() -> void:
	watch_signals(menu)
	menu.choose(TradeMenu.LEFT, 0)
	menu.choose(TradeMenu.RIGHT, 0)
	_cancel()
	assert_signal_emitted_with_parameters(menu, "closed", [true])


func test_the_stats_line_follows_the_highlighted_item() -> void:
	menu.row(TradeMenu.RIGHT, 0).grab_focus()
	var stats := (menu.get_node("%Stats") as Label).text
	assert_string_contains(stats, "Lance")
	assert_string_contains(stats, "Mt 7")
	menu.row(TradeMenu.LEFT, 1).grab_focus()
	assert_string_contains((menu.get_node("%Stats") as Label).text, "10")
	menu.row(TradeMenu.LEFT, 4).grab_focus()
	assert_eq((menu.get_node("%Stats") as Label).text.strip_edges(), "", "empty slot: nothing")
