class_name Battle
extends Node2D
## The playable map: a Level plus the cursor, menus, forecast and terrain
## panel, and the rules for what confirm, cancel, the unit key and the arrows
## do in each state. Level only draws; this node decides.
##
## Keyboard: arrows move the cursor, confirm (Z / Enter / Space) selects and
## commits, cancel (X / Esc) backs out, unit (A) acts without moving, status
## (R / pad Y) opens the status screen of the unit under the cursor.
## Mouse: hovering moves the cursor (or picks the target in the forecast), left
## click confirms (anywhere, in the forecast), right click cancels, or opens the
## status screen of a unit when nothing is selected.

enum State { FREE, UNIT_SELECTED, MOVING, UNIT_MENU, ITEM_MENU, TARGETING, COMBAT, MAP_MENU, STATUS }

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
@onready var level: Level = $Level
@onready var range_overlay: RangeOverlay = $Range
@onready var arrow: PathArrow = $Arrow
@onready var cursor: MapCursor = $Cursor
@onready var map_menu: ActionMenu = %MapMenu
@onready var unit_menu: ActionMenu = %UnitMenu
@onready var item_menu: ItemMenu = %ItemMenu
@onready var forecast: CombatForecast = %Forecast
@onready var terrain_panel: TerrainPanel = %TerrainPanel
@onready var unit_panel: UnitPanel = %UnitPanel
@onready var status_screen: StatusScreen = %StatusScreen
@onready var turn_loop: TurnLoop = $TurnLoop
@onready var music: AudioStreamPlayer = $Music

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
## The state to go back to when the status screen closes.
var status_return_state := State.FREE
## The unit the status screen shows.
var status_unit: LevelUnit
## The last unit the free cursor was on; the unit panel keeps showing it.
var last_hovered: LevelUnit
## 0-99 for Combat.resolve; replace it to script a fight.
var roll: Callable = _random_roll
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	map_menu.option_selected.connect(_on_map_menu_option)
	map_menu.cancelled.connect(_on_map_menu_cancelled)
	unit_menu.option_selected.connect(_on_unit_menu_option)
	unit_menu.cancelled.connect(_on_unit_menu_cancelled)
	item_menu.action_chosen.connect(_on_item_action)
	item_menu.cancelled.connect(_on_item_menu_cancelled)
	forecast.confirmed.connect(_on_forecast_confirmed)
	forecast.cancelled.connect(_on_forecast_cancelled)
	status_screen.cycle_requested.connect(_on_status_cycle)
	status_screen.closed.connect(_on_status_closed)
	cursor.moved.connect(_on_cursor_moved)
	turn_loop.phase_changed.connect(_on_phase_changed)
	if level.level_state != null:
		start()
		turn_loop.setup(self, level)


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
	if turn_loop != null and not turn_loop.is_player_turn():
		return
	if state == State.MOVING or state == State.COMBAT or state == State.STATUS:
		return

	if event is InputEventMouseMotion:
		if _cursor_is_free():
			cursor.set_cell(level.cell_at(get_global_mouse_position()))
		elif state == State.TARGETING:
			point_at_target(level.cell_at(get_global_mouse_position()))
		return

	var click := event as InputEventMouseButton
	if click != null:
		if not click.pressed:
			return
		if click.button_index == MOUSE_BUTTON_LEFT and _cursor_is_free():
			get_viewport().set_input_as_handled()
			cursor.set_cell(level.cell_at(get_global_mouse_position()))
			confirm()
		elif click.button_index == MOUSE_BUTTON_LEFT and state == State.TARGETING:
			# Anywhere on screen attacks the target the forecast shows.
			get_viewport().set_input_as_handled()
			forecast.close()
			_on_forecast_confirmed()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			right_click(level.cell_at(get_global_mouse_position()))
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
	elif event.is_action_pressed(&"status"):
		get_viewport().set_input_as_handled()
		var unit := level.unit_at(cursor.cell)
		if unit != null:
			open_status(unit, true)
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
	if _cursor_is_free() and (turn_loop == null or turn_loop.is_player_turn()):
		cursor.move(direction)


## Confirm on the cursor's cell: select a unit, pick a destination, or open the map menu.
func confirm() -> void:
	if turn_loop != null and not turn_loop.is_player_turn():
		return
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


## Backs out one step: deselect, undo a move, leave the item menu or the forecast,
## or close the map menu or the status screen.
func cancel() -> void:
	match state:
		State.UNIT_SELECTED:
			_deselect()
			state = State.FREE
			_update_panels()
		State.UNIT_MENU:
			unit_menu.close()
			_on_unit_menu_cancelled()
		State.ITEM_MENU:
			item_menu.back()
		State.TARGETING:
			forecast.close()
			_on_forecast_cancelled()
		State.MAP_MENU:
			map_menu.close()
			_on_map_menu_cancelled()
		State.STATUS:
			status_screen.close()
			_on_status_closed()


## Right click on `cell`: the status screen of a unit there while nothing is
## selected (cancel does nothing then anyway), otherwise cancel.
func right_click(cell: Vector2i) -> void:
	var unit := level.unit_at(cell)
	if state == State.FREE and unit != null:
		open_status(unit, true)
	else:
		cancel()


## The unit key: open the unit menu for the unit under the cursor without moving it.
func act_in_place() -> void:
	if state != State.FREE or (turn_loop != null and not turn_loop.is_player_turn()):
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
	reachable = level.pathfinding.reachable_cells(unit.state, unit.state.unit.stats.movement)
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
	turn_loop.on_player_action_completed()


# --- Unit menu ---------------------------------------------------------------


func _open_unit_menu() -> void:
	state = State.UNIT_MENU
	targets = Combat.hostiles_in_range(level.selected.state, level.level_state)
	var options: Array[StringName] = [&"status", &"wait"]
	if level.selected.state.unit.inventory.size() > 0:
		options.push_front(&"item")
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
			attack_cells = _cells_in_attack_range(level.selected.state)
			range_overlay.set_cells(reachable, attack_cells)
			_show_forecast()
		&"item":
			state = State.ITEM_MENU
			item_menu.open(selected_unit_items())
			_update_panels()
		&"status":
			open_status(level.selected, false)
		&"wait":
			_finish_action()


## Cancel in the unit menu undoes the move and goes back to choosing a destination.
func _on_unit_menu_cancelled() -> void:
	var unit := level.selected
	if unit.state.cell != move_origin:
		level.place_unit(unit, move_origin)
	unit.state.has_moved = origin_has_moved
	reachable = level.pathfinding.reachable_cells(unit.state, unit.state.unit.stats.movement)
	range_overlay.set_cells(reachable, attack_cells)
	cursor.set_cell(move_origin)
	state = State.UNIT_SELECTED
	_update_panels()


# --- Item menu -----------------------------------------------------------------
# The unit menu's Item command opens item_menu with selected_unit_items(); its
# Equip and Use call equip_item / use_item with a slot index. They act on the
# unit whose unit or item menu is open, like Attack and Wait.


func _on_item_action(action_id: StringName, index: int) -> void:
	var done := false
	match action_id:
		&"equip":
			done = equip_item(index)
		&"use":
			done = use_item(index)
	if not done:
		item_menu.refresh(selected_unit_items(), index)


## Cancel in the item menu goes back to the unit menu, with targets for
## whatever weapon is now equipped. The move isn't undone.
func _on_item_menu_cancelled() -> void:
	_open_unit_menu()


func _can_command_items() -> bool:
	return (state == State.UNIT_MENU or state == State.ITEM_MENU) \
			and level.selected != null \
			and (turn_loop == null or turn_loop.is_player_turn())


## What's in the selected unit's inventory, or null when no unit is selected.
func selected_unit_items() -> UnitInfo:
	if level.selected == null:
		return null
	return UnitInfo.from_unit(level.selected.state.unit)


## Uses the consumable in `index` (e.g. a Vulnerary). Like FE, this ends the
## unit's action. Returns false, changing nothing, for a weapon, an empty slot,
## a healing item at full HP, or when no unit or item menu is open.
func use_item(index: int) -> bool:
	if not _can_command_items():
		return false
	if not level.selected.state.unit.use_item(index):
		return false
	unit_menu.close()
	item_menu.close()
	_finish_action()
	return true


## Equips the weapon in `index` (moves it to the front). Doesn't end the action.
## From the item menu, the list redraws with the weapon on top; from the unit
## menu, it reopens with targets for the new weapon's range. Returns false,
## changing nothing, for a consumable, a weapon the class can't use, or when no
## unit or item menu is open.
func equip_item(index: int) -> bool:
	if not _can_command_items():
		return false
	if not level.selected.state.unit.equip(index):
		return false
	if state == State.ITEM_MENU:
		item_menu.refresh(selected_unit_items())
	else:
		_open_unit_menu()
	return true


# --- Attack forecast ---------------------------------------------------------


func _show_forecast() -> void:
	var target := targets[target_index]
	cursor.set_cell(target.cell)
	var sides := Combat.forecast(level.selected.state, target, level.level_state)
	# Stays in its default top-left corner; set_side with _is_left_half(target.cell)
	# would flip it away from the target instead.
	forecast.open(sides[0], sides[1])
	_update_panels()


func _cycle_target(step: int) -> void:
	target_index = wrapi(target_index + step, 0, targets.size())
	_show_forecast()


## Mouse hover while picking a target: switch to the enemy on `cell`, if it's one
## of the targets in range.
func point_at_target(cell: Vector2i) -> void:
	if state != State.TARGETING:
		return
	for i in targets.size():
		if targets[i].cell == cell and i != target_index:
			target_index = i
			_show_forecast()
			return


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
	var strikes := Combat.resolve(attacker, target, level.level_state, roll)
	for strike in strikes:
		await _play_strike(strike)
	if attacker.is_alive():
		attacker.has_moved = true
		attacker.has_acted = true
	_deselect()
	state = State.FREE
	_update_panels()
	turn_loop.on_player_action_completed()


## Runs an enemy's already planned attack using the same combat and animation
## code as a player fight. The turn loop owns when this is called.
func execute_enemy_attack(attacker: LevelUnitState, target: LevelUnitState) -> void:
	state = State.COMBAT
	_update_panels()
	var strikes := Combat.resolve(attacker, target, level.level_state, roll)
	for strike in strikes:
		await _play_strike(strike)
	if attacker.is_alive():
		attacker.has_moved = true
		attacker.has_acted = true
	state = State.FREE
	_update_panels()


func _play_strike(strike: Combat.Strike) -> void:
	var striker: LevelUnit = level.unit_nodes[strike.attacker.unit_ref.id]
	var target: LevelUnit = level.unit_nodes[strike.defender.unit_ref.id]
	await striker.play_once("attack", strike_direction(strike.defender.cell - strike.attacker.cell))
	strike.defender.current_hp = strike.hp_after
	if not strike.defender.is_alive():
		await level.fade_out_unit(target)


## The straight direction to face for a strike along `offset`. A ranged strike can
## be diagonal (a bow at (-1, 1)), but sprites only face the four directions, so the
## horizontal side wins, as the side view is what shows an attack best.
static func strike_direction(offset: Vector2i) -> Vector2i:
	if offset.x != 0:
		return Vector2i(signi(offset.x), 0)
	return Vector2i(0, signi(offset.y))


func _random_roll() -> int:
	return rng.randi_range(0, 99)


func _on_forecast_cancelled() -> void:
	_open_unit_menu()


# --- Status screen -------------------------------------------------------------
# Opened on any unit from the free cursor (cycling through its faction), or on the
# acting unit from the unit menu (no cycling; closing goes back to that menu).


func open_status(unit: LevelUnit, can_cycle: bool) -> void:
	status_return_state = state
	status_unit = unit
	state = State.STATUS
	status_screen.open(UnitInfo.from_level_unit(unit), can_cycle)
	_update_panels()


## Steps to the previous (-1) or next (1) unit on the shown unit's side, wrapping.
func _on_status_cycle(step: int) -> void:
	var units := _faction_units(status_unit.reference.faction)
	var index := units.find(status_unit)
	status_unit = units[posmod(index + step, units.size())]
	status_screen.show_unit(UnitInfo.from_level_unit(status_unit))


func _on_status_closed() -> void:
	state = status_return_state
	if state == State.UNIT_MENU:
		_open_unit_menu()
		return
	# Leave the cursor on the last unit looked at, as Fire Emblem does.
	cursor.set_cell(status_unit.state.cell)
	_update_arrow()
	_update_panels()


## Units of `faction` still on the map, in map order.
func _faction_units(faction: UnitReference.Faction) -> Array[LevelUnit]:
	var units: Array[LevelUnit] = []
	for unit: LevelUnit in level.unit_nodes.values():
		if unit.reference.faction == faction:
			units.append(unit)
	return units


# --- Map menu ----------------------------------------------------------------


func _open_map_menu() -> void:
	state = State.MAP_MENU
	map_menu.open()
	_update_panels()


## Only End does anything so far; the other options just close the menu.
func _on_map_menu_option(option_id: StringName) -> void:
	if option_id == &"end":
		turn_loop.end_player_turn()
	state = State.FREE
	_update_panels()


func _on_map_menu_cancelled() -> void:
	state = State.FREE
	_update_panels()


# --- Panels and drawing ------------------------------------------------------


## What the terrain panel shows for `cell`: the terrain rules the game uses there
## (MapData.rules_terrain_at), with the move cost for the selected unit, or for a
## foot unit when nothing is selected.
func terrain_info_at(cell: Vector2i) -> TerrainInfo:
	var info := TerrainInfo.new()
	var terrain := level.pathfinding.terrain_at(cell)
	if terrain == null:
		info.terrain_name = "None"
		info.move_cost = TerrainInfo.IMPASSABLE
		return info
	info.terrain_name = terrain.display_name
	info.defense = terrain.defense
	info.avoid = terrain.avoid
	info.heal_percent = terrain.heal_percent
	var movement_type := Enums.MovementType.FOOT
	if level.selected != null:
		movement_type = level.selected.state.unit.class_data().movement_type
	info.move_cost = terrain.move_cost(movement_type)
	return info


func _on_cursor_moved(_cell: Vector2i) -> void:
	_update_arrow()
	_update_panels()


## While choosing a destination the arrow traces the cursor, Fire Emblem style,
## so the player picks the exact route. Stepping to a cell next to the arrow's
## end extends it (if the unit can enter it and the route's terrain cost stays
## within its movement), stepping back onto the arrow cuts it
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
	var adjacent := (cell - tail).abs() == Vector2i(1, 0) or (cell - tail).abs() == Vector2i(0, 1)
	var extended: Array[Vector2i] = path.duplicate()
	if extended.is_empty():
		extended.append(unit.state.cell)
	extended.append(cell)
	# The traced route must stay on terrain the unit can enter, within its movement.
	if adjacent and level.pathfinding.is_passable(unit.state, cell) \
			and level.pathfinding.path_cost(unit.state, extended) <= unit.state.unit.stats.movement:
		arrow.set_path(extended)
	elif reachable.has(cell):
		arrow.set_path(level.pathfinding.find_path(unit.state, cell))
	# Otherwise the cursor is outside the range: keep the arrow where it was.


## The terrain and unit panels are only for free-cursor play. The terrain panel
## stays in its default bottom-left corner; to flip it away from the cursor
## instead, call terrain_panel.set_side(RIGHT if _is_left_half(cursor.cell) else LEFT).
## The unit panel, top-left, keeps showing the last unit the cursor was on, and
## hides during the enemy phase.
func _update_panels() -> void:
	terrain_panel.visible = _cursor_is_free()
	if terrain_panel.visible:
		terrain_panel.set_terrain(terrain_info_at(cursor.cell))
	if _cursor_is_free():
		var hovered := level.unit_at(cursor.cell)
		if hovered != null:
			last_hovered = hovered
	# A unit that fell is freed, so drop it rather than show a dead reference.
	if not is_instance_valid(last_hovered):
		last_hovered = null
	var player_turn := turn_loop == null or turn_loop.is_player_turn()
	unit_panel.visible = _cursor_is_free() and player_turn and last_hovered != null
	if unit_panel.visible:
		unit_panel.set_unit(UnitInfo.from_level_unit(last_hovered))


## Unused while the panels stay on the left; kept for flipping them with set_side.
func _is_left_half(cell: Vector2i) -> bool:
	var bounds := level.level_state.map_data.bounds()
	return cell.x < bounds.position.x + bounds.size.x / 2.0


## Cells on the map that `unit`'s equipped weapon reaches from where it stands
## (its min-max range, so a bow skips the cells next to it). Empty without a weapon.
func _cells_in_attack_range(unit: LevelUnitState) -> Dictionary:
	var cells := {}
	var weapon := unit.unit.equipped_weapon()
	if weapon == null:
		return cells
	var bounds := level.level_state.map_data.bounds()
	var reach := weapon.max_range
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			var cell := unit.cell + Vector2i(dx, dy)
			if weapon.in_range(absi(dx) + absi(dy)) and bounds.has_point(cell):
				cells[cell] = true
	return cells


func _first_player_unit() -> LevelUnit:
	for unit: LevelUnit in level.unit_nodes.values():
		if unit.reference.faction == UnitReference.Faction.PLAYER:
			return unit
	return null
	
	
# --- Music -----------------------------------------------------------------
func _on_phase_changed(phase: TurnLoop.Phase) -> void:
	if phase == TurnLoop.Phase.PLAYER:
		music.play()
	else:
		music.stop()
	_update_panels()
