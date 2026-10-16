extends Node2D
## Dev-only showcase for the UI components; run it with F6. Delete this folder
## once the real map controller drives the menus, forecast and terrain panel.
##
## Stand-in for a battle map until real maps exist. Arrows move the cursor and
## the terrain panel follows it. Press confirm (Z / Enter / Space / gamepad A) to open
## the map menu, cancel (X / Esc / gamepad B) to close it. A opens the unit
## menu; picking Attack shows the combat forecast, and left / right moves the
## forecast between corners.

const CURSOR_DIRECTIONS := {
	&"ui_left": Vector2i.LEFT,
	&"ui_right": Vector2i.RIGHT,
	&"ui_up": Vector2i.UP,
	&"ui_down": Vector2i.DOWN,
}

@onready var _map_menu: ActionMenu = %MapMenu
@onready var _unit_menu: ActionMenu = %UnitMenu
@onready var _forecast: CombatForecast = %Forecast
@onready var _demo_map: DemoMap = %DemoMap
@onready var _terrain_panel: TerrainPanel = %TerrainPanel

var _player_unit := _make_unit("Eirika", preload("res://data/units/classes/myrmidon.tres"),
		preload("res://data/items/weapons/iron_sword.tres"))
var _enemy_unit := _make_unit("Bandit", preload("res://data/units/classes/fighter.tres"),
		preload("res://data/items/weapons/iron_axe.tres"))


func _ready() -> void:
	_map_menu.option_selected.connect(_on_menu_option_selected)
	_map_menu.cancelled.connect(_on_menu_cancelled)
	_unit_menu.option_selected.connect(_on_menu_option_selected)
	_unit_menu.cancelled.connect(_on_menu_cancelled)
	_forecast.confirmed.connect(_on_forecast_confirmed)
	_forecast.cancelled.connect(_on_forecast_cancelled)
	_demo_map.cursor_moved.connect(_on_cursor_moved)
	_on_cursor_moved(_demo_map.cursor_cell)


func _unhandled_input(event: InputEvent) -> void:
	if _forecast.visible:
		if event.is_action_pressed(&"ui_left"):
			_forecast.set_side(CombatForecast.ScreenSide.LEFT)
		elif event.is_action_pressed(&"ui_right"):
			_forecast.set_side(CombatForecast.ScreenSide.RIGHT)
		return

	# While a menu is open its own keys belong to it, so don't open another.
	if _map_menu.visible or _unit_menu.visible:
		return

	if event.is_action_pressed(&"confirm"):
		get_viewport().set_input_as_handled()
		_map_menu.open()
		_update_terrain_panel_visibility()
	elif event.is_action_pressed(&"unit"):
		get_viewport().set_input_as_handled()
		_unit_menu.open()
		_update_terrain_panel_visibility()
	else:
		for action: StringName in CURSOR_DIRECTIONS:
			# allow_echo so holding an arrow keeps the cursor moving.
			if event.is_action_pressed(action, true):
				get_viewport().set_input_as_handled()
				_demo_map.move_cursor(CURSOR_DIRECTIONS[action])
				return


func _on_menu_option_selected(option_id: StringName) -> void:
	print("Menu selected: ", option_id)
	if option_id == &"attack":
		_show_sample_forecast()
	_update_terrain_panel_visibility()


func _on_menu_cancelled() -> void:
	print("Menu cancelled")
	_update_terrain_panel_visibility()


func _on_forecast_confirmed() -> void:
	print("Forecast confirmed")
	_update_terrain_panel_visibility()


func _on_forecast_cancelled() -> void:
	print("Forecast cancelled")
	_update_terrain_panel_visibility()


func _on_cursor_moved(cell: Vector2i) -> void:
	_terrain_panel.set_terrain(_demo_map.terrain_at(cell))
	# Keep the panel on the half of the screen away from the cursor.
	if _demo_map.is_left_half(cell):
		_terrain_panel.set_side(TerrainPanel.ScreenSide.RIGHT)
	else:
		_terrain_panel.set_side(TerrainPanel.ScreenSide.LEFT)


## The terrain panel is only for free-cursor play; the real map controller will
## do this from its states.
func _update_terrain_panel_visibility() -> void:
	_terrain_panel.visible = not (_map_menu.visible or _unit_menu.visible or _forecast.visible)


## Real units for name, weapon and HP. Damage, hit and crit are fake numbers
## until combat logic exists.
func _show_sample_forecast() -> void:
	var player := ForecastSide.from_unit(_player_unit)
	# TODO: replace with the combat calculator's numbers.
	player.damage = 7
	player.hit = 85
	player.crit = 5
	player.attack_count = 2
	player.advantage = 1

	var enemy := ForecastSide.from_unit(_enemy_unit)
	enemy.damage = 4
	enemy.hit = 62
	enemy.crit = 0
	enemy.advantage = -1

	_forecast.open(player, enemy)


## A unit built in code, since there are no character files yet.
static func _make_unit(unit_name: String, class_data: ClassData, weapon: WeaponData) -> Unit:
	var unit_data := UnitData.new()
	unit_data.id = StringName(unit_name.to_snake_case())
	unit_data.display_name = unit_name
	unit_data.class_data = class_data
	unit_data.starting_items = [weapon]
	return Unit.new(unit_data)
