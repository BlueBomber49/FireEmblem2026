extends GutTest

const UnitPanelScene: PackedScene = preload("res://gameplay/ui/unit_panel.tscn")

var _panel: UnitPanel


func before_each() -> void:
	_panel = UnitPanelScene.instantiate() as UnitPanel
	add_child_autofree(_panel)


func _info(unit_name := "Lyn", hp := 16, max_hp := 16) -> UnitInfo:
	var info := UnitInfo.new()
	info.unit_name = unit_name
	info.class_name_text = "Myrmidon"
	info.level = 3
	info.hp = hp
	info.max_hp = max_hp
	return info


func _label(unique_name: String) -> Label:
	return _panel.get_node("%" + unique_name) as Label


func _bar() -> ProgressBar:
	return _panel.get_node("%HpBar") as ProgressBar


func test_set_unit_fills_the_labels() -> void:
	_panel.set_unit(_info("Lyn", 12, 16))
	assert_eq(_label("UnitName").text, "Lyn")
	assert_eq(_label("ClassName").text, "Myrmidon")
	assert_eq(_label("Level").text, "Lv 3")
	assert_eq(_label("Hp").text, "12/16")
	assert_eq(_bar().value, 12.0)
	assert_eq(_bar().max_value, 16.0)


func test_bar_color_follows_hp() -> void:
	_panel.set_unit(_info("Lyn", 3, 16))
	var fill := _bar().get_theme_stylebox(&"fill") as StyleBoxFlat
	assert_eq(fill.bg_color, UnitInfo.HP_RED)
	_panel.set_unit(_info("Lyn", 16, 16))
	fill = _bar().get_theme_stylebox(&"fill") as StyleBoxFlat
	assert_eq(fill.bg_color, UnitInfo.HP_GREEN)


func test_panel_is_tinted_by_faction() -> void:
	var info := _info()
	info.faction = UnitReference.Faction.ALLY
	_panel.set_unit(info)
	assert_eq(_panel.theme_type_variation, &"UnitPanelAlly")


func test_size_does_not_change_with_the_name() -> void:
	_panel.set_unit(_info("Lyn"))
	var short_size := _panel.size
	_panel.set_unit(_info("Brigand Captain Of The Northern Hills"))
	assert_eq(_panel.size, short_size)


func test_pinned_top_left_and_lets_the_mouse_through() -> void:
	_panel.set_unit(_info())
	assert_eq(_panel.anchor_left, 0.0)
	assert_eq(_panel.anchor_top, 0.0)
	assert_eq(_panel.position, Vector2(UnitPanel.MARGIN, UnitPanel.MARGIN))
	assert_eq(_panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)
