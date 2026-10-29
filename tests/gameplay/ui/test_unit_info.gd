extends GutTest
## UnitInfo: what an item menu or unit roster shows about a unit. Mechanics fill it
## in; the UI only reads it.


func _lyn() -> Unit:
	return Unit.new(GameData.get_character(&"lyn"))


func test_basic_fields() -> void:
	var unit := _lyn()
	unit.take_damage(4)
	var info := UnitInfo.from_unit(unit)
	assert_eq(info.unit_name, "Lyn")
	assert_eq(info.class_name_text, "Myrmidon")
	assert_eq(info.level, 1)
	assert_eq(info.hp, 12)
	assert_eq(info.max_hp, 16, "max HP is separate from current HP")
	assert_eq(info.weapon_name, "Iron Sword")


func test_stats_by_name() -> void:
	var info := UnitInfo.from_unit(_lyn())
	assert_eq(info.stats["speed"], 9)
	assert_eq(info.stats["movement"], 5)
	assert_eq(info.stats.size(), Stats.FIELDS.size())


func test_items_in_inventory_order() -> void:
	var info := UnitInfo.from_unit(_lyn())
	assert_eq(info.items.size(), 2)
	var sword: UnitInfo.ItemInfo = info.items[0]
	assert_eq(sword.item_name, "Iron Sword")
	assert_true(sword.is_weapon)
	assert_true(sword.equipped)
	assert_true(sword.usable, "Lyn can wield swords")
	assert_eq(sword.uses_left, -1, "weapons don't track uses yet")
	var vulnerary: UnitInfo.ItemInfo = info.items[1]
	assert_eq(vulnerary.item_name, "Vulnerary")
	assert_false(vulnerary.is_weapon)
	assert_false(vulnerary.equipped)
	assert_eq(vulnerary.uses_left, 3)
	assert_eq(vulnerary.max_uses, 3)


func test_healing_item_is_usable_only_when_hurt() -> void:
	var unit := _lyn()
	assert_false(UnitInfo.from_unit(unit).items[1].usable, "full HP")
	unit.take_damage(1)
	assert_true(UnitInfo.from_unit(unit).items[1].usable)


func test_weapon_the_class_cant_use_is_not_usable() -> void:
	var unit := _lyn()
	unit.inventory.add(GameData.get_item(&"iron_lance"))
	var lance: UnitInfo.ItemInfo = UnitInfo.from_unit(unit).items[2]
	assert_false(lance.usable)
	assert_false(lance.equipped)


func test_unit_without_a_weapon() -> void:
	var unit := _lyn()
	unit.inventory.remove_at(0)
	assert_eq(UnitInfo.from_unit(unit).weapon_name, "--")


func test_weapon_stats_for_the_item_menu() -> void:
	var sword: UnitInfo.ItemInfo = UnitInfo.from_unit(_lyn()).items[0]
	var data := GameData.get_item(&"iron_sword") as WeaponData
	assert_eq(sword.weapon_type, "Sword")
	assert_eq(sword.might, data.might)
	assert_eq(sword.hit, data.hit)
	assert_eq(sword.crit, data.crit)
	assert_eq(sword.weight, data.weight)
	assert_eq(sword.range_text(), "1")


func test_range_text_for_ranged_weapons() -> void:
	var unit := _lyn()
	unit.inventory.add(GameData.get_item(&"iron_bow"))
	unit.inventory.add(GameData.get_item(&"hand_axe"))
	var info := UnitInfo.from_unit(unit)
	assert_eq(info.items[2].range_text(), "2", "a bow only reaches 2")
	assert_eq(info.items[3].range_text(), "1-2")


func test_consumable_effect_text() -> void:
	var unit := _lyn()
	unit.inventory.add(GameData.get_item(&"elixir"))
	var info := UnitInfo.from_unit(unit)
	assert_eq(info.items[1].effect_text(), "Restores 10 HP")
	assert_eq(info.items[2].effect_text(), "Restores all HP")
	assert_eq(info.items[1].might, 0, "consumables have no weapon stats")
