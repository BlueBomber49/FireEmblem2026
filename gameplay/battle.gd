class_name Battle
extends Node2D
## The playable map: a Level plus the cursor, menus, forecast and terrain
## panel, and the rules for what confirm, cancel, the unit key and the arrows
## do in each state. Level only draws; this node decides.
##
## Keyboard: arrows move the cursor, confirm (Z / Enter / Space) selects and
## commits, cancel (X / Esc) backs out, unit (A) acts without moving.
## Mouse: hovering moves the cursor, left click confirms, right click cancels.

enum State { FREE, UNIT_SELECTED, MOVING, UNIT_MENU, TARGETING, COMBAT, MAP_MENU }

const CURSOR_DIRECTIONS := {
	&"ui_left": Vector2i.LEFT,
	&"ui_right": Vector2i.RIGHT,
	&"ui_up": Vector2i.UP,
	&"ui_down": Vector2i.DOWN,
}
## Left / up go to the previous target, right / down to the next.
const TARGET_STEPS := {
	&"ui_left": -1,
	&"ui_up": -1,
	&"ui_right": 1,
	&"ui_down": 1,
}
## Cells away from the attacker that the stand-in weapon reaches.
const ATTACK_RANGE := 1

@onready var level: Level = $Level
@onready var range_overlay: RangeOverlay = $Range
@onready var arrow: PathArrow = $Arrow
@onready var cursor: MapCursor = $Cursor
@onready var map_menu: ActionMenu = %MapMenu
@onready var unit_menu: ActionMenu = %UnitMenu
@onready var forecast: CombatForecast = %Forecast
@onready var terrain_panel: TerrainPanel = %TerrainPanel

var state := State.FREE
## cell -> true; where the selected unit may move. Empty when nothing is selected.
var reachable: Dictionary = {}
## cell -> true; the selected unit's attack range while picking a target.
var attack_cells: Dictionary = {}
## Where the selected unit stood before moving, so cancel can put it back.
var move_origin := Vector2i.ZERO
var origin_has_moved := false
## Hostile units next to the selected unit while picking an attack target.
var targets: Array[LevelUnitState] = []
var target_index := 0
## 0-99 for Combat.resolve; replace it to script a fight.
var roll: Callable = _random_roll
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	map_menu.option_selected.connect(_on_map_menu_option)
	map_menu.cancelled.connect(_on_map_menu_cancelled)
	unit_menu.option_selected.connect(_on_unit_menu_option)
	unit_menu.cancelled.connect(_on_unit_menu_cancelled)
	forecast.confirmed.connect(_on_forecast_confirmed)
	forecast.cancelled.connect(_on_forecast_cancelled)
	cursor.moved.connect(_on_cursor_moved)
	if level.level_state != null:
		start()


## Resets the cursor and UI for the level currently built in `level`.
func start() -> void:
	var bounds := level.level_state.map_data.bounds()
	cursor.bounds = bounds
	cursor.tile_size = level.tile_size
	# Same z as the units, but earlier in the tree, so they show under the units.
	range_overlay.z_index = level.units_root.z_index
	range_overlay.tile_size = level.tile_size
	arrow.z_index = level.units_root.z_index
	arrow.tile_size = level.tile_size
	_deselect()
	state = State.FREE
	var first := _first_player_unit()
	cursor.set_cell(first.state.cell if first != null else bounds.get_center())
	cursor.queue_redraw()
	_update_panels()


# --- Input -------------------------------------------------------------------
# Menus and the forecast are descendants, so they see confirm and cancel first
# while open. Everything here is also guarded by `state`.


func _unhandled_input(event: InputEvent) -> void:
	if state == State.MOVING or state == State.COMBAT:
		return

	if event is InputEventMouseMotion:
		if _cursor_is_free():
			cursor.set_cell(level.cell_at(get_global_mouse_position()))
		return

	var click := event as InputEventMouseButton
	if click != null:
		if not click.pressed:
			return
		if click.button_index == MOUSE_BUTTON_LEFT and _cursor_is_free():
			get_viewport().set_input_as_handled()
			cursor.set_cell(level.cell_at(get_global_mouse_position()))
			confirm()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			cancel()
		return

	if state == State.TARGETING:
		for action: StringName in TARGET_STEPS:
			if event.is_action_pressed(action):
				get_viewport().set_input_as_handled()
				_cycle_target(TARGET_STEPS[action])
				return
		return

	if not _cursor_is_free():
		return
	if event.is_action_pressed(&"confirm"):
		get_viewport().set_input_as_handled()
		confirm()
	elif event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed(&"unit"):
		get_viewport().set_input_as_handled()
		act_in_place()
	else:
		for action: StringName in CURSOR_DIRECTIONS:
			# allow_echo so holding an arrow keeps the cursor moving.
			if event.is_action_pressed(action, true):
				get_viewport().set_input_as_handled()
				move_cursor(CURSOR_DIRECTIONS[action])
				return


func _cursor_is_free() -> bool:
	return state == State.FREE or state == State.UNIT_SELECTED


# --- Commands ----------------------------------------------------------------


func move_cursor(direction: Vector2i) -> void:
	if _cursor_is_free():
		cursor.move(direction)


## Confirm on the cursor's cell: select a unit, pick a destination, or open the map menu.
func confirm() -> void:
	match state:
		State.FREE:
			var unit := level.unit_at(cursor.cell)
			if _is_commandable(unit):
				_select(unit)
			else:
				_open_map_menu()
		State.UNIT_SELECTED:
			if not reachable.has(cursor.cell):
				return
			if cursor.cell == level.selected.state.cell:
				_open_unit_menu()
				return
			# Walk the route the player traced, or the shortest one if the arrow isn't on this cell.
			var path := arrow.path
			if path.is_empty() or path[-1] != cursor.cell:
				path = level.pathfinding.find_path(level.selected.state, cursor.cell)
			if not path.is_empty():
				_move_along(path)


## Backs out one step: deselect, undo a move, leave the forecast, or close the map menu.
func cancel() -> void:
	match state:
		State.UNIT_SELECTED:
			_deselect()
			state = State.FREE
			_update_panels()
		State.UNIT_MENU:
			unit_menu.close()
			_on_unit_menu_cancelled()
		State.TARGETING:
			forecast.close()
			_on_forecast_cancelled()
		State.MAP_MENU:
			map_menu.close()
			_on_map_menu_cancelled()


## The unit key: open the unit menu for the unit under the cursor without moving it.
func act_in_place() -> void:
	if state != State.FREE:
		return
	var unit := level.unit_at(cursor.cell)
	if _is_commandable(unit):
		_select(unit)
		_open_unit_menu()


# --- Selection and movement --------------------------------------------------


func _is_commandable(unit: LevelUnit) -> bool:
	return unit != null \
			and unit.reference.faction == UnitReference.Faction.PLAYER \
			and not unit.state.has_acted


func _select(unit: LevelUnit) -> void:
	level.select(unit)
	move_origin = unit.state.cell
	origin_has_moved = unit.state.has_moved
	reachable = level.pathfinding.reachable_cells(unit.state, unit.reference.stat(&"mov"))
	range_overlay.set_cells(reachable, attack_cells)
	state = State.UNIT_SELECTED
	_update_arrow()
	_update_panels()


func _deselect() -> void:
	level.select(null)
	reachable = {}
	attack_cells = {}
	targets = []
	range_overlay.set_cells(reachable, attack_cells)
	arrow.set_path([])


func _move_along(path: Array[Vector2i]) -> void:
	state = State.MOVING
	reachable = {}
	range_overlay.set_cells(reachable, attack_cells)
	arrow.set_path([])
	_update_panels()
	await level.walk(level.selected, path)
	_open_unit_menu()


## The selected unit is done: it keeps its cell and can't be commanded again this turn.
func _finish_action() -> void:
	level.selected.state.has_moved = true
	level.selected.state.has_acted = true
	_deselect()
	state = State.FREE
	_update_panels()


# --- Unit menu ---------------------------------------------------------------


func _open_unit_menu() -> void:
	state = State.UNIT_MENU
	targets = Combat.adjacent_hostiles(level.selected.state, level.level_state)
	var options: Array[StringName] = [&"wait"]
	if not targets.is_empty():
		options.push_front(&"attack")
	cursor.set_cell(level.selected.state.cell)
	attack_cells = {}
	range_overlay.set_cells(reachable, attack_cells)
	arrow.set_path([])
	unit_menu.open(options)
	_update_panels()


func _on_unit_menu_option(option_id: StringName) -> void:
	match option_id:
		&"attack":
			state = State.TARGETING
			target_index = 0
			attack_cells = _cells_in_attack_range(level.selected.state.cell)
			range_overlay.set_cells(reachable, attack_cells)
			_show_forecast()
		&"wait":
			_finish_action()


## Cancel in the unit menu undoes the move and goes back to choosing a destination.
func _on_unit_menu_cancelled() -> void:
	var unit := level.selected
	if unit.state.cell != move_origin:
		level.place_unit(unit, move_origin)
	unit.state.has_moved = origin_has_moved
	reachable = level.pathfinding.reachable_cells(unit.state, unit.reference.stat(&"mov"))
	range_overlay.set_cells(reachable, attack_cells)
	cursor.set_cell(move_origin)
	state = State.UNIT_SELECTED
	_update_panels()


# --- Attack forecast ---------------------------------------------------------


func _show_forecast() -> void:
	var target := targets[target_index]
	cursor.set_cell(target.cell)
	var sides := Combat.forecast(level.selected.state, target, true)
	forecast.open(sides[0], sides[1])
	forecast.set_side(CombatForecast.ScreenSide.RIGHT if _is_left_half(target.cell)
			else CombatForecast.ScreenSide.LEFT)
	_update_panels()


func _cycle_target(step: int) -> void:
	target_index = wrapi(target_index + step, 0, targets.size())
	_show_forecast()


func _on_forecast_confirmed() -> void:
	_fight(targets[target_index])


## Plays out the fight strike by strike, then spends the attacker's action.
func _fight(target: LevelUnitState) -> void:
	state = State.COMBAT
	attack_cells = {}
	range_overlay.set_cells(reachable, attack_cells)
	_update_panels()
	# Keep the state, not the node: a fallen attacker's node is gone by the end.
	var attacker := level.selected.state
	var strikes := Combat.resolve(attacker, target, true, roll)
	for strike in strikes:
		await _play_strike(strike)
	if attacker.is_alive():
		attacker.has_moved = true
		attacker.has_acted = true
	_deselect()
	state = State.FREE
	_update_panels()


func _play_strike(strike: Combat.Strike) -> void:
	var striker: LevelUnit = level.unit_nodes[strike.attacker.unit_ref.id]
	var target: LevelUnit = level.unit_nodes[strike.defender.unit_ref.id]
	await striker.play_once("attack", (strike.defender.cell - strike.attacker.cell).sign())
	strike.defender.current_hp = strike.hp_after
	if not strike.defender.is_alive():
		await level.fade_out_unit(target)


func _random_roll() -> int:
	return rng.randi_range(0, 99)


func _on_forecast_cancelled() -> void:
	_open_unit_menu()


# --- Map menu ----------------------------------------------------------------


func _open_map_menu() -> void:
	state = State.MAP_MENU
	map_menu.open()
	_update_panels()


## Only End does anything so far; the other options just close the menu.
func _on_map_menu_option(option_id: StringName) -> void:
	if option_id == &"end":
		level.reset_turn()
	state = State.FREE
	_update_panels()


func _on_map_menu_cancelled() -> void:
	state = State.FREE
	_update_panels()


# --- Panels and drawing ------------------------------------------------------


## What the terrain panel shows for `cell`. Terrain stats are separate data
## still to come, so only the name and walkability are real.
func terrain_info_at(cell: Vector2i) -> TerrainInfo:
	var info := TerrainInfo.new()
	var terrain := level.level_state.map_data.top_terrain_at(cell)
	info.terrain_name = terrain.capitalize() if not terrain.is_empty() else "None"
	info.move_cost = 1 if level.pathfinding.is_walkable(cell) else TerrainInfo.IMPASSABLE
	return info


func _on_cursor_moved(_cell: Vector2i) -> void:
	_update_arrow()
	_update_panels()


## While choosing a destination the arrow traces the cursor, Fire Emblem style,
## so the player picks the exact route. Stepping to a cell next to the arrow's
## end extends it (within the mov budget), stepping back onto the arrow cuts it
## there, a jump elsewhere in range rebuilds the shortest route, and leaving
## the range leaves the arrow as it was.
func _update_arrow() -> void:
	var unit := level.selected
	if state != State.UNIT_SELECTED or unit == null:
		arrow.set_path([])
		return
	var cell := cursor.cell
	if cell == unit.state.cell:
		arrow.set_path([])
		return

	var path := arrow.path
	var index := path.find(cell)
	if index >= 0:
		arrow.set_path(path.slice(0, index + 1))
		return

	var tail: Vector2i = path[-1] if not path.is_empty() else unit.state.cell
	var steps_after := maxi(path.size(), 1)
	var adjacent := (cell - tail).abs() == Vector2i(1, 0) or (cell - tail).abs() == Vector2i(0, 1)
	if adjacent and steps_after <= unit.reference.stat(&"mov") \
			and level.pathfinding.is_passable(unit.state, cell):
		var extended: Array[Vector2i] = path.duplicate()
		if extended.is_empty():
			extended.append(unit.state.cell)
		extended.append(cell)
		arrow.set_path(extended)
	elif reachable.has(cell):
		arrow.set_path(level.pathfinding.find_path(unit.state, cell))
	# Otherwise the cursor is outside the range: keep the arrow where it was.


## The terrain panel is only for free-cursor play, on the half away from the cursor.
func _update_panels() -> void:
	terrain_panel.visible = _cursor_is_free()
	if terrain_panel.visible:
		terrain_panel.set_terrain(terrain_info_at(cursor.cell))
		terrain_panel.set_side(TerrainPanel.ScreenSide.RIGHT if _is_left_half(cursor.cell)
				else TerrainPanel.ScreenSide.LEFT)


func _is_left_half(cell: Vector2i) -> bool:
	var bounds := level.level_state.map_data.bounds()
	return cell.x < bounds.position.x + bounds.size.x / 2.0


## Cells on the map within ATTACK_RANGE steps of `from`, not counting `from`.
func _cells_in_attack_range(from: Vector2i) -> Dictionary:
	var bounds := level.level_state.map_data.bounds()
	var cells := {}
	for dx in range(-ATTACK_RANGE, ATTACK_RANGE + 1):
		for dy in range(-ATTACK_RANGE, ATTACK_RANGE + 1):
			var distance := absi(dx) + absi(dy)
			var cell := from + Vector2i(dx, dy)
			if distance > 0 and distance <= ATTACK_RANGE and bounds.has_point(cell):
				cells[cell] = true
	return cells


func _first_player_unit() -> LevelUnit:
	for unit: LevelUnit in level.unit_nodes.values():
		if unit.reference.faction == UnitReference.Faction.PLAYER:
			return unit
	return null
