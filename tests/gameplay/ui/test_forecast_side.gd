extends GutTest

var Knight: ClassData
var IronLance: WeaponData
var IronSword: WeaponData


func before_each() -> void:
	Knight = GameData.get_class_data(&"knight")
	IronLance = GameData.get_item(&"iron_lance")
	IronSword = GameData.get_item(&"iron_sword")


func _unit(items: Array[ItemData]) -> Unit:
	var data := UnitData.new()
	data.id = &"oswin"
	data.display_name = "Oswin"
	data.class_data = Knight
	data.starting_items = items
	return Unit.new(data)


func test_from_unit_copies_name_weapon_and_hp() -> void:
	var unit := _unit([IronLance])
	unit.take_damage(5)
	var side := ForecastSide.from_unit(unit)
	assert_eq(side.unit_name, "Oswin")
	assert_eq(side.weapon_name, "Iron Lance")
	assert_eq(side.hp, unit.max_hp() - 5)
	assert_true(side.can_counter)


func test_from_unit_skips_weapons_the_class_cant_use() -> void:
	var side := ForecastSide.from_unit(_unit([IronSword, IronLance]))
	assert_eq(side.weapon_name, "Iron Lance")


func test_from_unit_without_usable_weapon_cant_counter() -> void:
	var side := ForecastSide.from_unit(_unit([IronSword]))
	assert_eq(side.weapon_name, "--")
	assert_false(side.can_counter)
