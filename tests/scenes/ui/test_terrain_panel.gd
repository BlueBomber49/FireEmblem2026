extends GutTest

const TerrainPanelScene: PackedScene = preload("res://scenes/ui/terrain_panel.tscn")

var _panel: TerrainPanel


func before_each() -> void:
	_panel = TerrainPanelScene.instantiate() as TerrainPanel
	add_child_autofree(_panel)


func _terrain(terrain_name: String, heal_percent: int = 0) -> TerrainInfo:
	var info := TerrainInfo.new()
	info.terrain_name = terrain_name
	info.defense = 1
	info.avoid = 20
	info.move_cost = 2
	info.heal_percent = heal_percent
	return info


func _label(unique_name: String) -> Label:
	return _panel.get_node("%" + unique_name) as Label


func test_set_terrain_fills_stats() -> void:
	_panel.set_terrain(_terrain("Forest"))
	assert_eq(_label("TerrainName").text, "Forest")
	assert_eq(_label("Defense").text, "1")
	assert_eq(_label("Avoid").text, "20")
	assert_eq(_label("Move").text, "2")


func test_heal_row_hidden_without_healing() -> void:
	_panel.set_terrain(_terrain("Forest"))
	assert_false(_label("HealLabel").visible)
	assert_false(_label("Heal").visible)


func test_heal_row_shows_percent() -> void:
	_panel.set_terrain(_terrain("Fort", 20))
	assert_true(_label("HealLabel").visible)
	assert_true(_label("Heal").visible)
	assert_eq(_label("Heal").text, "20%")


func test_impassable_move_shows_dashes() -> void:
	var sea := _terrain("Sea")
	sea.move_cost = TerrainInfo.IMPASSABLE
	_panel.set_terrain(sea)
	assert_eq(_label("Move").text, "--")


func test_set_side_moves_between_bottom_corners() -> void:
	_panel.set_side(TerrainPanel.ScreenSide.RIGHT)
	assert_eq(_panel.anchor_left, 1.0)
	assert_eq(_panel.anchor_right, 1.0)
	assert_eq(_panel.anchor_bottom, 1.0)
	_panel.set_side(TerrainPanel.ScreenSide.LEFT)
	assert_eq(_panel.anchor_left, 0.0)
	assert_eq(_panel.anchor_bottom, 1.0)


func test_panel_shrinks_when_heal_row_hides() -> void:
	_panel.set_terrain(_terrain("Fort", 20))
	var fort_height := _panel.size.y
	_panel.set_terrain(_terrain("Plains"))
	assert_lt(_panel.size.y, fort_height)
