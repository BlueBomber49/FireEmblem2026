extends GutTest

const ClassDataTest := preload("res://tests/gameplay/map/test_class_data.gd")


func _knight() -> ClassData:
	var c := ClassData.new()
	c.id = &"knight"
	c.movement_type = Enums.MovementType.ARMORED
	c.base_stats = ClassDataTest.stats([17, 5, 0, 2, 0, 0, 9, 0, 13, 4])
	c.growths = ClassDataTest.stats([80, 40, 0, 30, 15, 25, 28, 20, 0, 0])
	c.caps = ClassDataTest.stats([60, 20, 20, 20, 20, 30, 20, 20, 20, 15])
	c.usable_weapon_types = [Enums.WeaponType.LANCE]
	return c


func _weapon(id: StringName, type: Enums.WeaponType) -> WeaponData:
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


func _elixir() -> ConsumableData:
	var c := ConsumableData.new()
	c.id = &"elixir"
	c.max_uses = 3
	c.heal_amount = ConsumableData.FULL_HEAL
	return c


func _generic(items: Array[ItemData] = []) -> UnitData:
	var u := UnitData.new()
	u.id = &"enemy_knight"
	u.class_data = _knight()
	u.starting_items = items
	return u


# --- Creation ---------------------------------------------------------------

func test_generic_unit_uses_class_bases() -> void:
	var unit := Unit.new(_generic())
	assert_true(unit.stats.equals(_knight().base_stats))


func test_character_uses_starting_stats_totals() -> void:
	var data := _generic()
	data.starting_stats = ClassDataTest.stats([28, 13, 0, 9, 5, 3, 13, 3, 14, 0])
	var unit := Unit.new(data)
	assert_eq(unit.stats.hp, 28)
	assert_eq(unit.stats.strength, 13)
	assert_eq(unit.stats.constitution, 14)


func test_starting_stats_are_clamped_to_caps() -> void:
	var data := _generic()
	data.starting_stats = ClassDataTest.stats([70, 25, 0, 9, 5, 3, 13, 3, 14, 0])
	var unit := Unit.new(data)
	assert_eq(unit.stats.hp, 60)
	assert_eq(unit.stats.strength, 20)


func test_movement_comes_from_class_even_when_starting_stats_set_it() -> void:
	var data := _generic()
	data.starting_stats = ClassDataTest.stats([28, 13, 0, 9, 5, 3, 13, 3, 14, 9])
	assert_eq(Unit.new(data).stats.movement, 4)


func test_movement_comes_from_class_when_starting_stats_leave_it_zero() -> void:
	var data := _generic()
	data.starting_stats = ClassDataTest.stats([28, 13, 0, 9, 5, 3, 13, 3, 14, 0])
	assert_eq(Unit.new(data).stats.movement, 4)


func test_level_comes_from_definition_and_experience_starts_at_zero() -> void:
	var data := _generic()
	data.level = 9
	var unit := Unit.new(data)
	assert_eq(unit.level, 9)
	assert_eq(unit.experience, 0)


func test_hp_starts_full() -> void:
	var unit := Unit.new(_generic())
	assert_eq(unit.current_hp, 17)
	assert_eq(unit.max_hp(), 17)


func test_inventory_filled_from_starting_items() -> void:
	var unit := Unit.new(_generic([_weapon(&"iron_lance", Enums.WeaponType.LANCE), _vulnerary()]))
	assert_eq(unit.inventory.size(), 2)
	assert_eq(unit.inventory.get_item(1).uses_left, 3)


func test_definition_without_class_gives_empty_unit_instead_of_crashing() -> void:
	var data := _generic([_vulnerary()])
	data.class_data = null
	var unit := Unit.new(data)
	assert_push_error("has no class")
	assert_false(unit.is_alive())
	assert_eq(unit.inventory.size(), 0)
	assert_null(unit.equipped_weapon())
	assert_eq(unit.growths().hp, 0)


func test_class_without_base_stats_gives_empty_unit_instead_of_crashing() -> void:
	var data := _generic()
	data.class_data.base_stats = null
	var unit := Unit.new(data)
	assert_push_error("missing base stats or caps")
	assert_false(unit.is_alive())


func test_build_problem_is_empty_for_valid_definition() -> void:
	assert_eq(Unit.build_problem(_generic()), "")


# --- No shared stats ---------------------------------------------------------

func test_units_from_the_same_definition_dont_share_stats() -> void:
	var data := _generic()
	var a := Unit.new(data)
	var b := Unit.new(data)
	a.stats.strength = 19
	assert_eq(b.stats.strength, 5)
	assert_eq(data.class_data.base_stats.strength, 5)


func test_unit_stats_dont_alias_starting_stats() -> void:
	var data := _generic()
	data.starting_stats = ClassDataTest.stats([28, 13, 0, 9, 5, 3, 13, 3, 14, 0])
	var unit := Unit.new(data)
	unit.stats.hp = 40
	assert_eq(data.starting_stats.hp, 28)


# --- HP ---------------------------------------------------------------------

func test_take_damage_stops_at_zero() -> void:
	var unit := Unit.new(_generic())
	unit.take_damage(5)
	assert_eq(unit.current_hp, 12)
	assert_true(unit.is_alive())
	unit.take_damage(50)
	assert_eq(unit.current_hp, 0)
	assert_false(unit.is_alive())


func test_negative_damage_does_nothing() -> void:
	var unit := Unit.new(_generic())
	unit.take_damage(-5)
	assert_eq(unit.current_hp, 17)


func test_heal_stops_at_max() -> void:
	var unit := Unit.new(_generic())
	unit.take_damage(10)
	unit.heal(4)
	assert_eq(unit.current_hp, 11)
	unit.heal(100)
	assert_eq(unit.current_hp, 17)


# --- Growths ----------------------------------------------------------------

func test_growths_fall_back_to_class() -> void:
	var unit := Unit.new(_generic())
	assert_true(unit.growths().equals(_knight().growths))


func test_growths_returns_a_copy() -> void:
	var data := _generic()
	var unit := Unit.new(data)
	unit.growths().hp = 1
	assert_eq(data.class_data.growths.hp, 80)
	assert_eq(unit.growths().hp, 80)


func test_personal_growths_win() -> void:
	var data := _generic()
	data.growths = ClassDataTest.stats([90, 40, 0, 30, 30, 30, 40, 30, 0, 0])
	assert_eq(Unit.new(data).growths().hp, 90)


# --- Equipping --------------------------------------------------------------

func test_equipped_weapon_skips_weapons_the_class_cant_use() -> void:
	var sword := _weapon(&"iron_sword", Enums.WeaponType.SWORD)
	var lance := _weapon(&"iron_lance", Enums.WeaponType.LANCE)
	var unit := Unit.new(_generic([_vulnerary(), sword, lance]))
	assert_eq(unit.equipped_weapon(), lance)


func test_equipped_weapon_is_null_without_a_usable_weapon() -> void:
	var unit := Unit.new(_generic([_vulnerary()]))
	assert_null(unit.equipped_weapon())


func test_equip_moves_weapon_to_front() -> void:
	var lance := _weapon(&"iron_lance", Enums.WeaponType.LANCE)
	var javelin := _weapon(&"javelin", Enums.WeaponType.LANCE)
	var unit := Unit.new(_generic([lance, javelin]))
	assert_true(unit.equip(1))
	assert_eq(unit.inventory.get_item(0).data, javelin)
	assert_eq(unit.equipped_weapon(), javelin)


func test_equip_refuses_consumable() -> void:
	var lance := _weapon(&"iron_lance", Enums.WeaponType.LANCE)
	var unit := Unit.new(_generic([lance, _vulnerary()]))
	assert_false(unit.equip(1))
	assert_eq(unit.inventory.get_item(0).data, lance)


func test_equip_refuses_weapon_the_class_cant_use() -> void:
	var lance := _weapon(&"iron_lance", Enums.WeaponType.LANCE)
	var unit := Unit.new(_generic([lance, _weapon(&"iron_sword", Enums.WeaponType.SWORD)]))
	assert_false(unit.equip(1))
	assert_eq(unit.inventory.get_item(0).data, lance)


func test_equip_out_of_range_is_refused() -> void:
	var unit := Unit.new(_generic())
	assert_false(unit.equip(3))


# --- Using items ------------------------------------------------------------

func test_vulnerary_heals_ten_and_uses_one() -> void:
	var unit := Unit.new(_generic([_vulnerary()]))
	unit.take_damage(15)
	assert_true(unit.use_item(0))
	assert_eq(unit.current_hp, 12)
	assert_eq(unit.inventory.get_item(0).uses_left, 2)


func test_vulnerary_is_removed_at_zero_uses() -> void:
	var unit := Unit.new(_generic([_vulnerary()]))
	for i in 3:
		unit.take_damage(10)
		assert_true(unit.use_item(0))
	assert_eq(unit.inventory.size(), 0)


func test_elixir_fully_heals() -> void:
	var unit := Unit.new(_generic([_elixir()]))
	unit.take_damage(16)
	assert_true(unit.use_item(0))
	assert_eq(unit.current_hp, 17)


func test_healing_item_refused_at_full_hp() -> void:
	var unit := Unit.new(_generic([_vulnerary()]))
	assert_false(unit.use_item(0))
	assert_eq(unit.inventory.get_item(0).uses_left, 3)


func test_use_item_refuses_weapon() -> void:
	var unit := Unit.new(_generic([_weapon(&"iron_lance", Enums.WeaponType.LANCE)]))
	unit.take_damage(5)
	assert_false(unit.use_item(0))
	assert_eq(unit.inventory.size(), 1)


func test_use_item_out_of_range_is_refused() -> void:
	var unit := Unit.new(_generic())
	assert_false(unit.use_item(0))
