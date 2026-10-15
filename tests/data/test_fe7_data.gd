extends GutTest
## Checks every .tres file under res://data/ and spot-checks FE7 values that are
## easy to put in the wrong field.


static func _tres_files(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(dir_path):
		# Exported builds list resources with a .remap suffix.
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			found.append(dir_path.path_join(name))
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_tres_files(dir_path.path_join(sub)))
	return found


func test_data_folder_has_the_expected_files() -> void:
	var files := _tres_files("res://data")
	assert_eq(files.size(), 11 + 14 + 2, "11 classes, 14 weapons, 2 consumables")


func test_every_data_file_loads_and_validates() -> void:
	for path in _tres_files("res://data"):
		var res := load(path)
		assert_not_null(res, path)
		if res == null:
			continue
		assert_true(res.has_method("validate"), "%s has validate()" % path)
		if res.has_method("validate"):
			assert_eq(res.validate(), PackedStringArray(), path)


func test_every_data_file_has_a_uid() -> void:
	for path in _tres_files("res://data"):
		assert_ne(ResourceLoader.get_resource_uid(path), ResourceUID.INVALID_ID, path)


func test_ids_are_unique_and_match_file_names() -> void:
	var seen := {}
	for path in _tres_files("res://data"):
		var res := load(path)
		var id: StringName = res.get("id")
		assert_eq(String(id), path.get_file().get_basename(), "id matches file name: %s" % path)
		assert_false(seen.has(id), "duplicate id %s" % id)
		seen[id] = true


func test_myrmidon_spot_check() -> void:
	var c: ClassData = load("res://data/units/classes/myrmidon.tres")
	assert_eq(c.base_stats.speed, 9)
	assert_eq(c.base_stats.skill, 9)
	assert_eq(c.movement_type, Enums.MovementType.FOOT)
	assert_eq(c.usable_weapon_types, [Enums.WeaponType.SWORD] as Array[Enums.WeaponType])


func test_mage_uses_magic_not_strength() -> void:
	var c: ClassData = load("res://data/units/classes/mage.tres")
	assert_eq(c.base_stats.magic, 1)
	assert_eq(c.base_stats.strength, 0)
	assert_eq(c.growths.magic, 55)
	assert_eq(c.growths.strength, 0)
	assert_eq(c.movement_type, Enums.MovementType.MAGE)


func test_knight_spot_check() -> void:
	var c: ClassData = load("res://data/units/classes/knight.tres")
	assert_eq(c.base_stats.movement, 4)
	assert_eq(c.base_stats.defense, 9)
	assert_eq(c.base_stats.constitution, 13)
	assert_true(c.has_tag(&"armored"))
	assert_eq(c.movement_type, Enums.MovementType.ARMORED)


func test_pegasus_knight_is_a_flier() -> void:
	var c: ClassData = load("res://data/units/classes/pegasus_knight.tres")
	assert_true(c.has_tag(&"flier"))
	assert_eq(c.movement_type, Enums.MovementType.FLIER)
	assert_eq(c.base_stats.resistance, 2)


func test_class_power() -> void:
	assert_eq((load("res://data/units/classes/soldier.tres") as ClassData).class_power, 2)
	assert_eq((load("res://data/units/classes/thief.tres") as ClassData).class_power, 2)
	assert_eq((load("res://data/units/classes/fighter.tres") as ClassData).class_power, 3)


func test_cavalier_wields_swords_and_lances() -> void:
	var c: ClassData = load("res://data/units/classes/cavalier.tres")
	assert_true(Enums.WeaponType.SWORD in c.usable_weapon_types)
	assert_true(Enums.WeaponType.LANCE in c.usable_weapon_types)
	assert_true(c.has_tag(&"mounted"))


func test_caps_are_fe7_unpromoted() -> void:
	var c: ClassData = load("res://data/units/classes/fighter.tres")
	assert_eq(c.caps.hp, 60)
	assert_eq(c.caps.luck, 30)
	assert_eq(c.caps.movement, 15)


func test_iron_bow_is_effective_against_fliers() -> void:
	var w: WeaponData = load("res://data/items/weapons/iron_bow.tres")
	assert_eq(w.min_range, 2)
	assert_eq(w.max_range, 2)
	assert_true(w.is_effective_against([&"flier"]))


func test_javelin_and_hand_axe_reach_two() -> void:
	for id in ["javelin", "hand_axe"]:
		var w: WeaponData = load("res://data/items/weapons/%s.tres" % id)
		assert_eq(w.min_range, 1, id)
		assert_eq(w.max_range, 2, id)


func test_iron_sword_spot_check() -> void:
	var w: WeaponData = load("res://data/items/weapons/iron_sword.tres")
	assert_eq(w.might, 5)
	assert_eq(w.hit, 90)
	assert_eq(w.weight, 5)
	assert_eq(w.crit, 0)


func test_fire_is_anima_magic() -> void:
	var w: WeaponData = load("res://data/items/weapons/fire.tres")
	assert_eq(w.weapon_type, Enums.WeaponType.ANIMA)
	assert_true(w.is_magic())


func test_consumables() -> void:
	var v: ConsumableData = load("res://data/items/consumables/vulnerary.tres")
	assert_eq(v.max_uses, 3)
	assert_eq(v.heal_amount, 10)
	var e: ConsumableData = load("res://data/items/consumables/elixir.tres")
	assert_eq(e.max_uses, 3)
	assert_eq(e.heal_amount, ConsumableData.FULL_HEAL)

