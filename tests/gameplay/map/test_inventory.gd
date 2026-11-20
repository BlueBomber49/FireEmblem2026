extends GutTest


func _weapon(id: StringName, type := Enums.WeaponType.SWORD) -> WeaponData:
	var w := WeaponData.new()
	w.id = id
	w.weapon_type = type
	return w


func _vulnerary() -> ConsumableData:
	var c := ConsumableData.new()
	c.id = &"vulnerary"
	c.max_uses = 3
	c.heal_amount = 10
	return c


func _swordfighter() -> ClassData:
	var c := ClassData.new()
	c.id = &"myrmidon"
	c.usable_weapon_types = [Enums.WeaponType.SWORD]
	return c


func test_default_capacity_is_five() -> void:
	assert_eq(Inventory.DEFAULT_CAPACITY, 5)
	assert_eq(Inventory.new().capacity, 5)


func test_add_until_full_then_reject() -> void:
	var inv := Inventory.new()
	for i in 5:
		assert_true(inv.add(_weapon(StringName("w%d" % i))))
	assert_true(inv.is_full())
	assert_false(inv.add(_weapon(&"sixth")))
	assert_eq(inv.size(), 5)


func test_custom_capacity() -> void:
	var inv := Inventory.new(2)
	assert_true(inv.add(_weapon(&"a")))
	assert_true(inv.add(_weapon(&"b")))
	assert_false(inv.add(_weapon(&"c")))


func test_add_null_is_rejected() -> void:
	var inv := Inventory.new()
	assert_false(inv.add(null))
	assert_eq(inv.size(), 0)


func test_consumable_starts_with_max_uses() -> void:
	var inv := Inventory.new()
	inv.add(_vulnerary())
	assert_eq(inv.get_item(0).uses_left, 3)


func test_two_consumables_track_uses_separately() -> void:
	var inv := Inventory.new()
	var vuln := _vulnerary()
	inv.add(vuln)
	inv.add(vuln)
	inv.get_item(0).uses_left = 1
	assert_eq(inv.get_item(1).uses_left, 3)


func test_remove_at() -> void:
	var inv := Inventory.new()
	inv.add(_weapon(&"a"))
	inv.add(_weapon(&"b"))
	inv.remove_at(0)
	assert_eq(inv.size(), 1)
	assert_eq(inv.get_item(0).data.id, &"b")


func test_get_item_out_of_range_is_null() -> void:
	var inv := Inventory.new()
	assert_null(inv.get_item(0))
	assert_null(inv.get_item(-1))


func test_move_to_front() -> void:
	var inv := Inventory.new()
	inv.add(_weapon(&"a"))
	inv.add(_weapon(&"b"))
	inv.add(_weapon(&"c"))
	inv.move_to_front(2)
	assert_eq(inv.get_item(0).data.id, &"c")
	assert_eq(inv.get_item(1).data.id, &"a")
	assert_eq(inv.get_item(2).data.id, &"b")


func test_first_usable_weapon_index_skips_consumables_and_wrong_types() -> void:
	var inv := Inventory.new()
	inv.add(_vulnerary())
	inv.add(_weapon(&"iron_lance", Enums.WeaponType.LANCE))
	inv.add(_weapon(&"iron_sword", Enums.WeaponType.SWORD))
	assert_eq(inv.first_usable_weapon_index(_swordfighter()), 2)


func test_first_usable_weapon_index_is_minus_one_when_none() -> void:
	var inv := Inventory.new()
	inv.add(_vulnerary())
	assert_eq(inv.first_usable_weapon_index(_swordfighter()), -1)


# --- Trading ---------------------------------------------------------------------


func _ids(inventory: Inventory) -> Array[StringName]:
	var ids: Array[StringName] = []
	for i in inventory.size():
		ids.append(inventory.get_item(i).data.id)
	return ids


func _holding(ids: Array[StringName]) -> Inventory:
	var inventory := Inventory.new()
	for id in ids:
		inventory.add(_weapon(id))
	return inventory


func test_swap_with_exchanges_two_items_in_place() -> void:
	var a := _holding([&"sword", &"lance"])
	var b := _holding([&"axe", &"bow"])
	assert_true(a.swap_with(1, b, 0))
	assert_eq(_ids(a), [&"sword", &"axe"] as Array[StringName])
	assert_eq(_ids(b), [&"lance", &"bow"] as Array[StringName])


func test_swap_with_an_empty_slot_moves_the_item_across() -> void:
	var a := _holding([&"sword", &"lance"])
	var b := _holding([&"axe"])
	assert_true(a.swap_with(0, b, 3), "any slot past the end is empty")
	assert_eq(_ids(a), [&"lance"] as Array[StringName])
	assert_eq(_ids(b), [&"axe", &"sword"] as Array[StringName], "it goes to the end")
	assert_true(a.swap_with(4, b, 0), "the other way round too")
	assert_eq(_ids(a), [&"lance", &"axe"] as Array[StringName])
	assert_eq(_ids(b), [&"sword"] as Array[StringName])


func test_swap_with_keeps_the_entry_and_its_uses() -> void:
	var a := Inventory.new()
	a.add(_vulnerary())
	a.get_item(0).uses_left = 1
	var b := Inventory.new()
	a.swap_with(0, b, 0)
	assert_eq(b.get_item(0).uses_left, 1)


func test_swap_with_onto_a_full_side_or_two_empty_slots_does_nothing() -> void:
	var full := _holding([&"a", &"b", &"c", &"d", &"e"])
	var a := _holding([&"sword"])
	assert_false(a.swap_with(0, full, 5), "full: nowhere to put it")
	assert_false(full.swap_with(5, a, 3), "both empty")
	assert_eq(_ids(a), [&"sword"] as Array[StringName])
	assert_eq(full.size(), 5)
	assert_true(a.swap_with(0, full, 2), "a swap with a full side still works")