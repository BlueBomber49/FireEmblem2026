class_name MapEditor
extends Node2D
## Paints terrain vertices onto a Level's layers, places units, and saves the
## result as a level JSON. Run this scene directly (not the main scene).
##
## Terrain mode: left mouse paints, right mouse erases.
## Units mode: left click places a unit, drag moves one, right click deletes.
## Objective mode: edit the win and loss conditions row by row; seize cells and
## the commander are set with Choose, a map click, then Confirm. Problems block
## saving.
## Both: middle-drag / arrows pan, wheel zooms, Ctrl+Z / Ctrl+Shift+Z undo / redo.

enum Mode { TERRAIN, UNITS, OBJECTIVE, EVENTS }
## Enemy AI strategies, in the AI dropdown's order.
const STRATEGIES := UnitReference.STRATEGIES
enum Brush { PAINT, ERASE }

const PAN_SPEED := 400.0
const MAX_UNDO := 200
const ZOOM_STEP := 1.25
const GRID_COLOR := Color(1, 1, 1, 0.12)
const VERT_COLOR := Color(1, 1, 1, 0.9)
const PAINT_COLOR := Color(1, 1, 0.3)
const ERASE_COLOR := Color(1, 0.3, 0.3)
const CELL_COLOR := Color(1, 1, 1, 0.5)
const SELECTED_TINT := Color(1.0, 1.0, 0.5)
const SEIZE_FILL := Color(0.2, 0.9, 0.3, 0.35)
const PROBLEM_COLOR := Color(1.0, 0.4, 0.35)
## Reinforcements are drawn this faded, so they read as "not here at the start".
const REINFORCEMENT_ALPHA := 0.45


@export_file("*.json") var level_path := "res://resources/levels/simple_level.json"

@onready var level: Level = $Level
@onready var camera: Camera2D = $Camera
@onready var overlay: Node2D = $Overlay
@onready var path_edit: LineEdit = %PathEdit
@onready var mode_option: OptionButton = %ModeOption
@onready var terrain_box: VBoxContainer = %TerrainBox
@onready var units_box: VBoxContainer = %UnitsBox
@onready var objective_box: VBoxContainer = %ObjectiveBox
@onready var events_box: VBoxContainer = %EventsBox
@onready var arrives_option: OptionButton = %ArrivesOption
@onready var preselect_row: HBoxContainer = %PreselectRow
@onready var preselect_label: Label = %PreselectLabel
@onready var preselect_clear_button: Button = %PreselectClearButton
@onready var commander_check: CheckBox = %CommanderCheck
@onready var strategy_option: OptionButton = %StrategyOption
@onready var team_edit: LineEdit = %TeamEdit
@onready var layer_list: ItemList = %LayerList
@onready var name_edit: LineEdit = %NameEdit
@onready var terrain_option: OptionButton = %TerrainOption
@onready var z_spin: SpinBox = %ZSpin
@onready var brush_option: OptionButton = %BrushOption
@onready var size_spin: SpinBox = %SizeSpin
@onready var unit_header: Label = %UnitHeader
@onready var class_option: OptionButton = %ClassOption
@onready var faction_option: OptionButton = %FactionOption
@onready var id_edit: LineEdit = %IdEdit
@onready var unit_name_edit: LineEdit = %UnitNameEdit
@onready var level_spin: SpinBox = %LevelSpin
@onready var character_option: OptionButton = %CharacterOption
@onready var deselect_button: Button = %DeselectButton
@onready var items_edit: LineEdit = %ItemsEdit
@onready var override_check: CheckBox = %OverrideCheck
@onready var stats_grid: GridContainer = %StatsGrid
@onready var status: Label = %Status

var mode: int = Mode.TERRAIN
var brush: int = Brush.PAINT
var brush_size := 1
var hover_vert := Vector2i.ZERO
var hover_cell := Vector2i.ZERO
## Brush being dragged, or -1 when the mouse is up.
var dragging := -1
var panning := false

## id of the unit shown in the inspector, or "".
var selected_unit_id := ""
## Unit being dragged to a new cell, or "".
var dragging_unit_id := ""
## Game class ids, in the order the class picker lists them.
var unit_classes: Array[StringName] = []
## Character ids, in the order the character picker lists them after "None".
var character_ids: Array[StringName] = []
## StringName -> SpinBox, built in _ready.
var stat_spins: Dictionary = {}
## True while the inspector is being filled from a unit, so edits don't echo back.
var _syncing := false
## What _fill_inspector last put in the pickers and the items field. Applying
## compares against these, so only a value the user actually changed is written:
## a broken placement shows a placeholder class, and the items field shows only
## known items, and neither should be saved back by accident.
var _shown_character_index := 0
var _shown_class_index := 0
var _shown_items_text := ""

## Objective panel, built in code by _build_objective_panel.
var win_rows: VBoxContainer
var lose_rows: VBoxContainer
var win_add_menu: MenuButton
var lose_add_menu: MenuButton
## Summary of problems and notes at the top of the panel.
var problems_label: Label
## Condition -> {key: control} for each row (see row_control).
var _rows: Dictionary = {}
var _fixed_loss_label: Label
var lose_header: Label
## A map pick in progress: the condition whose Choose button was pressed (a
## seize cell or the commander), or null. A map click sets the pending cell;
## Confirm applies it, Cancel or Esc drops it.
var _pick_condition: Objective.Condition
var _pending_cell := Vector2i.ZERO
var _has_pending := false

## Level snapshots (toJson(false)) to restore on undo / redo.
# Events mode: one row per event (event id -> its controls), built in code.
var event_rows: VBoxContainer
var add_event_button: Button
var events_problems_label: Label
var _event_rows: Dictionary = {}
## The event new placements join ("Place new units"), or "".
var preselected_event := ""
## The event whose Choose is in progress, or "", and the enemies clicked so far.
var _event_pick := ""
var _event_pending: Array[String] = []
## The event last worked on: its units are outlined in Events mode.
var _focused_event := ""

var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
## Tag of the last committed change; consecutive changes with the same tag merge.
var _last_change_tag := ""
## Snapshot taken when a brush stroke started, committed when it ends.
var _stroke_before: Dictionary = {}


func _ready() -> void:
	level.create_camera = false
	path_edit.text = level_path
	_fill_terrain_options()
	_fill_unit_options()
	_build_stats_grid()
	_build_objective_panel()
	_build_events_panel()
	overlay.draw.connect(_draw_overlay)

	%LoadButton.pressed.connect(_load)
	%SaveButton.pressed.connect(_save)
	%NewButton.pressed.connect(_new)
	mode_option.item_selected.connect(_set_mode)
	%AddLayerButton.pressed.connect(_add_layer)
	%RemoveLayerButton.pressed.connect(_remove_layer)
	layer_list.item_selected.connect(func(_i: int) -> void: overlay.queue_redraw())
	brush_option.item_selected.connect(func(i: int) -> void: brush = i)
	size_spin.value_changed.connect(func(v: float) -> void: brush_size = int(v))

	class_option.item_selected.connect(func(_i: int) -> void: _apply_inspector(true))
	faction_option.item_selected.connect(func(_i: int) -> void: _apply_inspector(true))
	id_edit.text_submitted.connect(func(_t: String) -> void: _apply_inspector())
	id_edit.focus_exited.connect(_apply_inspector)
	unit_name_edit.text_changed.connect(func(_t: String) -> void: _apply_inspector())
	level_spin.value_changed.connect(func(_v: float) -> void: _apply_inspector())
	character_option.item_selected.connect(_on_character_picked)
	items_edit.text_submitted.connect(func(_t: String) -> void: _apply_inspector())
	items_edit.focus_exited.connect(_apply_inspector)
	override_check.toggled.connect(_on_override_toggled)
	commander_check.toggled.connect(_on_commander_toggled)
	for strategy in STRATEGIES:
		strategy_option.add_item(strategy.capitalize())
	strategy_option.item_selected.connect(_on_strategy_picked)
	team_edit.text_submitted.connect(func(_text: String) -> void: _on_team_edited())
	team_edit.focus_exited.connect(_on_team_edited)
	arrives_option.item_selected.connect(_on_arrives_picked)
	preselect_clear_button.pressed.connect(_preselect_event.bind(""))
	%DeleteUnitButton.pressed.connect(_delete_selected_unit)
	deselect_button.pressed.connect(_select_unit.bind(""))
	%UndoButton.pressed.connect(undo)
	%RedoButton.pressed.connect(redo)

	_set_mode(Mode.TERRAIN)
	_load()


func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		camera.position += dir * PAN_SPEED * delta / camera.zoom.x
		overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if panning:
			camera.position -= motion.relative / camera.zoom.x
		_update_hover()
		if dragging != -1:
			_apply_brush(dragging)
		overlay.queue_redraw()
		_update_status()
		return

	var key := event as InputEventKey
	if key != null and key.pressed and key.is_command_or_control_pressed():
		if (key.keycode == KEY_Z and key.shift_pressed) or key.keycode == KEY_Y:
			redo()
		elif key.keycode == KEY_Z:
			undo()
		return

	# The game's cancel keys (X, Esc, gamepad B) deselect, back to the new-unit
	# template. Right-click stays delete here. Keys typed into a focused field
	# never reach this.
	if event.is_action_pressed(&"cancel") and not event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		if mode == Mode.OBJECTIVE and is_picking():
			_cancel_pick()
		elif mode == Mode.EVENTS and is_picking_event():
			_cancel_event_pick()
		elif mode == Mode.UNITS and not preselected_event.is_empty():
			_preselect_event("")
		else:
			_select_unit("")
		return

	var click := event as InputEventMouseButton
	if click == null:
		return
	# A click on the map lets go of any focused field (e.g. a turn count), so it
	# applies its value and drops its highlight.
	if click.pressed:
		get_viewport().gui_release_focus()
	match click.button_index:
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
			_update_hover()
			match mode:
				Mode.TERRAIN:
					_terrain_click(click)
				Mode.UNITS:
					_unit_click(click)
				Mode.OBJECTIVE:
					if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
						_objective_click(hover_cell)
				Mode.EVENTS:
					if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
						_events_click(hover_cell)
		MOUSE_BUTTON_MIDDLE:
			panning = click.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if click.pressed:
				_zoom(ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			if click.pressed:
				_zoom(1.0 / ZOOM_STEP)


func _update_hover() -> void:
	var mouse := get_global_mouse_position()
	hover_vert = vert_at(mouse)
	hover_cell = level.cell_at(mouse)


func _set_mode(new_mode: int) -> void:
	if new_mode != Mode.OBJECTIVE and is_picking():
		_stop_picking()  # a pick you can't see shouldn't linger
		_refresh_objective_panel()
	if new_mode != Mode.EVENTS and is_picking_event():
		_cancel_event_pick()
	if new_mode != Mode.UNITS and not preselected_event.is_empty():
		_preselect_event("")  # only while placing units
	mode = new_mode
	mode_option.selected = mode
	terrain_box.visible = mode == Mode.TERRAIN
	units_box.visible = mode == Mode.UNITS
	objective_box.visible = mode == Mode.OBJECTIVE
	events_box.visible = mode == Mode.EVENTS
	_end_stroke()
	overlay.queue_redraw()
	_update_status()


# --- Terrain painting -------------------------------------------------------


func _terrain_click(click: InputEventMouseButton) -> void:
	if click.pressed:
		if dragging == -1:
			_stroke_before = _snapshot()
		# Right mouse always erases so you don't have to switch brush.
		dragging = brush if click.button_index == MOUSE_BUTTON_LEFT else Brush.ERASE
		_apply_brush(dragging)
	else:
		_end_stroke()


## A whole press-to-release stroke is one undo step.
func _end_stroke() -> void:
	if dragging != -1:
		_commit(_stroke_before)
	dragging = -1
	dragging_unit_id = ""


func selected_layer() -> MapLayer:
	var items := layer_list.get_selected_items()
	if items.is_empty():
		return null
	return level.level_state.map_data.layers.get(layer_list.get_item_metadata(items[0]))


## Vertices the brush covers around `hover_vert`.
func brush_verts() -> Array[Vector2i]:
	var verts: Array[Vector2i] = []
	var start := hover_vert - Vector2i((brush_size - 1) / 2, (brush_size - 1) / 2)
	for dx in brush_size:
		for dy in brush_size:
			verts.append(start + Vector2i(dx, dy))
	return verts


func _apply_brush(brush_mode: int) -> void:
	var layer := selected_layer()
	if layer == null:
		return
	var changed := false
	for v in brush_verts():
		var has := layer.verts.has(v)
		if brush_mode == Brush.PAINT and not has:
			layer.verts.append(v)
			changed = true
		elif brush_mode == Brush.ERASE and has:
			layer.verts.erase(v)
			changed = true
	if changed:
		level.repaint_layer(layer.name)
		overlay.queue_redraw()


func vert_at(global_pos: Vector2) -> Vector2i:
	return Vector2i((level.to_local(global_pos) / Vector2(level.tile_size)).round())


func vert_position(v: Vector2i) -> Vector2:
	return level.to_global(Vector2(v) * Vector2(level.tile_size))


# --- Layers -----------------------------------------------------------------


func _refresh_layer_list(select_name := "") -> void:
	var previous := select_name
	if previous.is_empty() and selected_layer() != null:
		previous = selected_layer().name
	layer_list.clear()
	for layer in level.level_state.map_data.sorted_layers():
		var i := layer_list.add_item("%s   (%s, z=%d)" % [layer.name, layer.terrain, layer.z])
		layer_list.set_item_metadata(i, layer.name)
		if layer.name == previous:
			layer_list.select(i)
	if layer_list.get_selected_items().is_empty() and layer_list.item_count > 0:
		layer_list.select(layer_list.item_count - 1)
	z_spin.value = _next_z()
	overlay.queue_redraw()
	_update_status()


func _add_layer() -> void:
	var layer_name := name_edit.text.strip_edges()
	var terrain := terrain_option.get_item_text(terrain_option.selected) if terrain_option.selected >= 0 else ""
	if layer_name.is_empty():
		layer_name = terrain
	if layer_name.is_empty() or terrain.is_empty():
		status.text = "Pick a terrain and a layer name first."
		return
	if level.level_state.map_data.layers.has(layer_name):
		status.text = "A layer named '%s' already exists." % layer_name
		return
	var before := _snapshot()
	level.level_state.map_data.layers[layer_name] = MapLayer.new(layer_name, int(z_spin.value), terrain)
	_commit(before)
	name_edit.text = ""
	level.rebuild()
	_refresh_layer_list(layer_name)


func _remove_layer() -> void:
	var layer := selected_layer()
	if layer == null:
		return
	var before := _snapshot()
	level.level_state.map_data.layers.erase(layer.name)
	_commit(before)
	level.rebuild()
	_refresh_layer_list()


func _next_z() -> int:
	var z := 0
	for layer in level.level_state.map_data.layers.values():
		z = maxi(z, layer.z + 1)
	return z


func _fill_terrain_options() -> void:
	terrain_option.clear()
	var dir := DirAccess.open(TerrainType.TERRAIN_DIR)
	if dir == null:
		return
	var ids := []
	for file in dir.get_files():
		if file.ends_with(".tres"):
			ids.append(file.get_basename())
	ids.sort()
	for id in ids:
		terrain_option.add_item(id)


# --- Units ------------------------------------------------------------------


func _unit_click(click: InputEventMouseButton) -> void:
	var unit_here := _unit_id_at(hover_cell)
	if click.button_index == MOUSE_BUTTON_RIGHT:
		if click.pressed and not unit_here.is_empty():
			_delete_unit(unit_here)
		return

	if click.pressed:
		if unit_here.is_empty():
			_place_unit(hover_cell)
		else:
			_select_unit(unit_here)
			dragging_unit_id = unit_here
	else:
		# Dropping a dragged unit on a free cell moves it there.
		if not dragging_unit_id.is_empty() and unit_here.is_empty():
			var ref: UnitReference = level.level_state.map_data.units.get(dragging_unit_id)
			if ref != null and ref.start_cell != hover_cell:
				var before := _snapshot()
				ref.start_cell = hover_cell
				_commit(before)
				_rebuild_units()
		dragging_unit_id = ""


func _unit_id_at(cell: Vector2i) -> String:
	for id in level.level_state.map_data.units:
		if level.level_state.map_data.units[id].start_cell == cell:
			return id
	return ""


func _place_unit(cell: Vector2i) -> void:
	if unit_classes.is_empty():
		status.text = "No classes found in resources/classes."
		return
	var ref := UnitReference.new()
	ref.faction = faction_option.selected as UnitReference.Faction
	var character_id := _picked_character()
	if not character_id.is_empty():
		if _refuse_if_placed(character_id, ""):  # a new placement is never the selected one
			return
		ref.character_id = String(character_id)
		ref.id = _free_unit_id(ref.character_id)
	else:
		var class_id := unit_classes[maxi(class_option.selected, 0)]
		ref.class_id = String(class_id)
		ref.id = _free_unit_id(ref.class_id)
		ref.level = 1
		var weapon := default_weapon_for(GameData.get_class_data(class_id))
		if weapon != null:
			ref.items.append(String(weapon.id))
	ref.sprite_sheet = UnitReference.sprite_for(ref.default_sprite_template(), ref.faction)
	ref.start_cell = cell
	if not preselected_event.is_empty() and ref.faction == UnitReference.Faction.ENEMY:
		ref.event = preselected_event
	var before := _snapshot()
	level.level_state.map_data.units[ref.id] = ref
	_commit(before)
	_rebuild_units()
	_select_unit(ref.id)


## A starting weapon for a new unit of `klass`: an Iron weapon of a type it can use
## if there is one, otherwise the first usable weapon by id. Null if none.
static func default_weapon_for(klass: ClassData) -> WeaponData:
	var fallback: WeaponData = null
	for item_id in GameData.all_item_ids():
		var weapon := GameData.get_item(item_id) as WeaponData
		if weapon == null or not klass.can_wield(weapon):
			continue
		if String(item_id).begins_with("iron_"):
			return weapon
		if fallback == null:
			fallback = weapon
	return fallback


func _delete_unit(id: String) -> void:
	var before := _snapshot()
	level.level_state.map_data.units.erase(id)
	_commit(before)
	if selected_unit_id == id:
		selected_unit_id = ""
	_rebuild_units()
	_select_unit(selected_unit_id)


func _delete_selected_unit() -> void:
	if not selected_unit_id.is_empty():
		_delete_unit(selected_unit_id)


func _select_unit(id: String) -> void:
	selected_unit_id = id if level.level_state.map_data.units.has(id) else ""
	_tint_units()
	_fill_inspector()
	overlay.queue_redraw()
	_update_status()


## Units in the editor always show their authored start cells.
func _rebuild_units() -> void:
	level.level_state.level_units = LevelUnitState.build_all(level.level_state.map_data.units, {})
	level.respawn_units()
	_tint_units()
	_refresh_events_panel()


## The selected unit tinted, and reinforcements faded with their arrival turn: one
## place, so neither wipes out the other. The fade is self_modulate, so it leaves
## the badges (children) fully visible.
func _tint_units() -> void:
	for node_id: String in level.unit_nodes:
		var node: LevelUnit = level.unit_nodes[node_id]
		node.modulate = SELECTED_TINT if node_id == selected_unit_id else Color.WHITE
		var turn := arrival_turn(level.level_state.map_data.units.get(node_id))
		node.self_modulate = Color(1, 1, 1, REINFORCEMENT_ALPHA if turn > 0 else 1.0)
		node.set_arrival_turn(turn)


## Picking a character on a placed unit applies it; with no unit selected it
## previews the character in the template (its class, name, items and stats).
func _on_character_picked(_index: int) -> void:
	if selected_unit_id.is_empty():
		_fill_inspector()
	else:
		_apply_inspector(true)


## The id of the placement that is `character_id` on this map, or "" if none.
## A named character can be placed only once per map.
func _placement_of(character_id: StringName) -> String:
	var units: Dictionary = level.level_state.map_data.units
	for unit_id in units:
		if units[unit_id].character_id == String(character_id):
			return unit_id
	return ""


## True (with a status message) when `character_id` is already placed by a unit
## other than `own_unit_id` (the selected unit, which may keep its own character).
func _refuse_if_placed(character_id: StringName, own_unit_id: String) -> bool:
	var placed := _placement_of(character_id)
	if placed.is_empty() or placed == own_unit_id:
		return false
	status.text = "%s is already on this map (unit '%s'); a character can be placed only once." 			% [GameData.get_character(character_id).display_name, placed]
	if not selected_unit_id.is_empty():
		# New units copy the selected unit's pickers, so say how to get a fresh template.
		status.text += " Deselect (X / Esc) to place a different unit."
	return true


## Grays out characters already placed by another unit; the selected unit's own
## character stays pickable.
func _update_character_availability() -> void:
	for i in character_ids.size():
		var placed := _placement_of(character_ids[i])
		character_option.set_item_disabled(i + 1, not placed.is_empty() and placed != selected_unit_id)


## The character picked in the inspector, or &"" for None.
func _picked_character() -> StringName:
	var index := character_option.selected - 1
	return character_ids[index] if index >= 0 and index < character_ids.size() else &""


func _free_unit_id(class_id: String) -> String:
	var base := class_id.to_snake_case()
	if not level.level_state.map_data.units.has(base) and GameData.get_character(StringName(base)) != null:
		return base  # a character's first placement is just its id, e.g. "lyn"
	var n := 1
	while level.level_state.map_data.units.has("%s_%d" % [base, n]):
		n += 1
	return "%s_%d" % [base, n]


func _fill_inspector() -> void:
	_syncing = true
	var ref: UnitReference = level.level_state.map_data.units.get(selected_unit_id)
	var editing := ref != null
	# A placement that can't be built (unknown character or class, 0 HP) is shown
	# read-only: only the character or class picker can change it, to fix it.
	var broken := editing and not ref.build_problem().is_empty()
	# A named character's class, name, level, items and stats live in its own file.
	var generic := editing and not ref.is_character()
	var fields_editable := generic and not broken
	_update_character_availability()
	if not editing and character_option.is_item_disabled(character_option.selected):
		character_option.selected = 0  # already on the map; can't be placed again
	var template_character := GameData.get_character(_picked_character()) if not editing else null
	if not editing:
		unit_header.text = "New unit template"
	elif broken:
		unit_header.text = "BROKEN: %s Pick a character or class to fix it." % ref.build_problem()
	elif ref.is_character():
		unit_header.text = "Editing '%s' (character '%s')" % [selected_unit_id, ref.character_id]
	else:
		unit_header.text = "Editing '%s'" % selected_unit_id
	id_edit.editable = editing
	# A character's file decides its class, so the class picker is grayed out
	# whenever a character is picked, placed or not.
	class_option.disabled = (editing and not generic) or template_character != null
	unit_name_edit.editable = fields_editable
	level_spin.editable = fields_editable
	items_edit.editable = fields_editable
	%DeleteUnitButton.disabled = not editing
	# Only an enemy that can be built can be the commander.
	commander_check.disabled = not editing or broken or ref.faction != UnitReference.Faction.ENEMY
	commander_check.set_pressed_no_signal(editing and ref.commander)
	# Enemy AI: enemies only; the team only matters for Defensive.
	var enemy := editing and ref.faction == UnitReference.Faction.ENEMY
	strategy_option.disabled = not enemy
	strategy_option.selected = maxi(STRATEGIES.find(ref.strategy), 0) if enemy else 0
	team_edit.editable = enemy and ref.strategy == UnitReference.STRATEGY_DEFENSIVE
	team_edit.text = ref.team if enemy else ""
	# Arrives: at the start, or with an event. Enemies only.
	arrives_option.clear()
	arrives_option.add_item("At the start")
	var ids := level.level_state.events.keys()
	for event_id: String in ids:
		arrives_option.add_item(event_title(event_id))
	arrives_option.disabled = not enemy
	arrives_option.selected = ids.find(ref.event) + 1 if enemy else 0
	deselect_button.disabled = not editing
	if editing:
		var data := ref.build_unit_data()
		var class_id: StringName = data.class_data.id if data != null else StringName(ref.class_id)
		character_option.selected = character_ids.find(StringName(ref.character_id)) + 1 if ref.is_character() else 0
		class_option.selected = maxi(unit_classes.find(class_id), 0)
		faction_option.selected = ref.faction
		id_edit.text = ref.id
		unit_name_edit.text = data.display_name if data != null else ref.name
		level_spin.value = data.level if data != null else ref.level
		# Characters list their file's items; generic units list what the level file
		# says, including ids that don't load (so they're never dropped unseen).
		items_edit.text = ", ".join(_item_ids(data)) if ref.is_character() and data != null else ", ".join(ref.items)
		override_check.disabled = not fields_editable
		override_check.button_pressed = generic and not ref.stat_overrides.is_empty()
		var shown := _shown_stats(data)
		for key in stat_spins:
			stat_spins[key].value = shown.get(key)
	elif template_character != null:
		id_edit.text = ""
		class_option.selected = maxi(unit_classes.find(template_character.class_data.id), 0)
		unit_name_edit.text = template_character.display_name
		level_spin.value = template_character.level
		items_edit.text = ", ".join(_item_ids(template_character))
		override_check.disabled = true
		override_check.button_pressed = false
		var shown := _shown_stats(template_character)
		for key in stat_spins:
			stat_spins[key].value = shown.get(key)
	else:
		id_edit.text = ""
		unit_name_edit.text = ""
		level_spin.value = 1
		items_edit.text = ""
		override_check.disabled = true
		override_check.button_pressed = false
		var klass: ClassData = null
		if not unit_classes.is_empty():
			klass = GameData.get_class_data(unit_classes[maxi(class_option.selected, 0)])
		for key in stat_spins:
			stat_spins[key].value = klass.base_stats.get(key) if klass != null else 0
	_shown_character_index = character_option.selected
	_shown_class_index = class_option.selected
	_shown_items_text = items_edit.text
	_update_stat_editability()
	_syncing = false


## Stat spins are editable only for a generic unit with "Override class stats" on.
## Movement never is: it always comes from the class.
func _update_stat_editability() -> void:
	var ref: UnitReference = level.level_state.map_data.units.get(selected_unit_id)
	var editable := ref != null and not ref.is_character() and ref.build_problem().is_empty() \
			and override_check.button_pressed
	for key in stat_spins:
		stat_spins[key].editable = editable and key != &"movement"


static func _item_ids(data: UnitData) -> PackedStringArray:
	var ids := PackedStringArray()
	for item in data.starting_items:
		ids.append(String(item.id))
	return ids


## The stats a placement starts with (movement from the class), or zeros when it
## can't be built.
static func _shown_stats(data: UnitData) -> Stats:
	if data == null:
		return Stats.new()
	var source := data.starting_stats if data.starting_stats != null else data.class_data.base_stats
	var shown := source.copy()
	shown.movement = data.class_data.base_stats.movement
	return shown


func _apply_inspector(respawn := false) -> void:
	if _syncing:
		return
	var ref: UnitReference = level.level_state.map_data.units.get(selected_unit_id)
	if ref == null:
		return
	var before := _snapshot()
	var tag := "inspector:" + ref.id
	var new_id := id_edit.text.strip_edges()
	if not new_id.is_empty() and new_id != ref.id:
		if level.level_state.map_data.units.has(new_id):
			status.text = "A unit with id '%s' already exists." % new_id
			id_edit.text = ref.id
		else:
			level.level_state.map_data.units.erase(ref.id)
			ref.id = new_id
			level.level_state.map_data.units[new_id] = ref
			selected_unit_id = new_id
			respawn = true
	var picker_changed := character_option.selected != _shown_character_index \
			or class_option.selected != _shown_class_index
	if not ref.build_problem().is_empty():
		# Broken: keep everything as written, unless the user picked a character or
		# class to fix it. Then only that changes; items and overrides stay.
		if picker_changed:
			var fix := String(_picked_character())
			if not fix.is_empty() and _refuse_if_placed(StringName(fix), ref.id):
				character_option.selected = _shown_character_index
				return
			if not fix.is_empty():
				ref.character_id = fix
			elif class_option.selected != _shown_class_index:
				ref.character_id = ""
				ref.class_id = String(unit_classes[maxi(class_option.selected, 0)])
			_commit(before, tag)
			_rebuild_units_and_inspector()
			_update_status()
		elif respawn:
			_commit(before, tag)
			_rebuild_units()
		return

	var new_faction := faction_option.selected as UnitReference.Faction
	var appearance_changed := new_faction != ref.faction
	ref.faction = new_faction
	if new_faction != UnitReference.Faction.ENEMY:
		ref.commander = false  # only an enemy can command
		ref.strategy = UnitReference.STRATEGY_AGGRESSIVE  # or have an AI
		ref.team = ""
		ref.event = ""  # or arrive later

	var picked := String(_picked_character())
	if picked != ref.character_id and not picked.is_empty() and _refuse_if_placed(StringName(picked), ref.id):
		character_option.selected = _shown_character_index
		picked = ref.character_id
	if picked != ref.character_id:
		appearance_changed = true
		if not picked.is_empty():
			# Becomes a named character: its file supplies everything else.
			ref.character_id = picked
		else:
			# Back to a generic unit, keeping the class it had as that character.
			var was := GameData.get_character(StringName(ref.character_id))
			ref.character_id = ""
			ref.class_id = String(was.class_data.id) if was != null else String(unit_classes[0])
			ref.items = _known_items(_item_ids(was)) if was != null else []
			ref.stat_overrides = {}
		_commit(before, tag)
		_rebuild_units_and_inspector()
		return

	if not ref.is_character():
		var class_id := String(unit_classes[maxi(class_option.selected, 0)])
		if class_id != ref.class_id:
			ref.class_id = class_id
			ref.stat_overrides = {}
			appearance_changed = true
		ref.name = unit_name_edit.text
		ref.level = int(level_spin.value)
		# Only an edit to the items field changes the items.
		if items_edit.text != _shown_items_text:
			ref.items = _known_items(items_edit.text.split(",", false))
			_shown_items_text = items_edit.text
		if override_check.button_pressed:
			ref.stat_overrides = _overrides_from_spins(GameData.get_class_data(StringName(ref.class_id)))
		else:
			ref.stat_overrides = {}
	if appearance_changed:
		ref.sprite_sheet = UnitReference.sprite_for(ref.default_sprite_template(), ref.faction)
		respawn = true
	# Typing in a field produces many tiny edits; they merge into one undo step.
	_commit(before, tag)
	if respawn:
		_rebuild_units_and_inspector()


func _rebuild_units_and_inspector() -> void:
	var ref: UnitReference = level.level_state.map_data.units.get(selected_unit_id)
	if ref != null:
		ref.sprite_sheet = UnitReference.sprite_for(ref.default_sprite_template(), ref.faction)
	_rebuild_units()
	_fill_inspector()


## The ids in `ids` (trimmed) that GameData knows; reports any it doesn't.
func _known_items(ids: PackedStringArray) -> Array[String]:
	var known: Array[String] = []
	var unknown := PackedStringArray()
	for raw in ids:
		var item_id := raw.strip_edges()
		if item_id.is_empty():
			continue
		if GameData.get_item(StringName(item_id)) != null:
			known.append(item_id)
		else:
			unknown.append(item_id)
	if not unknown.is_empty():
		status.text = "Unknown item id(s), not added: %s" % ", ".join(unknown)
	return known


func _on_override_toggled(pressed: bool) -> void:
	if _syncing:
		return
	if not pressed:
		# Back to the class's stats.
		var ref: UnitReference = level.level_state.map_data.units.get(selected_unit_id)
		var klass := GameData.get_class_data(StringName(ref.class_id)) if ref != null else null
		if klass != null:
			_syncing = true
			for key in stat_spins:
				stat_spins[key].value = klass.base_stats.get(key)
			_syncing = false
	_update_stat_editability()
	_apply_inspector()


## Stat spins that differ from `klass`'s base stats, as overrides. Movement never
## overrides: it always comes from the class.
func _overrides_from_spins(klass: ClassData) -> Dictionary:
	var overrides := {}
	if klass == null:
		return overrides
	for key in stat_spins:
		if key == &"movement":
			continue
		var value := int(stat_spins[key].value)
		if value != int(klass.base_stats.get(key)):
			overrides[String(key)] = value
	return overrides


func _fill_unit_options() -> void:
	character_ids = GameData.all_character_ids()
	character_option.clear()
	character_option.add_item("None")
	for character_id in character_ids:
		character_option.add_item(GameData.get_character(character_id).display_name)
	unit_classes = GameData.all_class_ids()
	class_option.clear()
	for class_id in unit_classes:
		class_option.add_item(GameData.get_class_data(class_id).display_name)
	faction_option.clear()
	for f in UnitReference.Faction.values():
		faction_option.add_item(UnitReference.FACTION_NAMES[f].capitalize(), f)


func _build_stats_grid() -> void:
	for key in Stats.FIELDS:
		var label := Label.new()
		label.text = String(key)
		stats_grid.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 99
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(_v: float) -> void: _apply_inspector())
		stats_grid.add_child(spin)
		stat_spins[key] = spin


# --- Files ------------------------------------------------------------------


func _load() -> void:
	level_path = path_edit.text
	var loaded := LevelState.load_file(level_path)
	if loaded == null:
		status.text = "Could not load %s" % level_path
		return
	# A unit pointing at an event that isn't there starts on the map.
	for ref: UnitReference in loaded.map_data.units.values():
		if not ref.event.is_empty() and not loaded.events.has(ref.event):
			push_warning("Level: unit '%s' arrives with event '%s', which doesn't exist; it now starts on the map." % [ref.id, ref.event])
			ref.event = ""
	level.level_state = loaded
	level.rebuild()
	_frame_camera()
	_refresh_layer_list()
	_select_unit("")
	_stop_picking()
	_stop_event_pick()
	_refresh_objective_panel()
	_refresh_events_panel()
	_clear_history()
	status.text = "Loaded %s" % level_path


func _save() -> void:
	var problems := objective_problems()
	if not problems.is_empty():
		status.text = "Can't save until the objective is fixed: " + " ".join(problems)
		return
	var event_issues := event_problems()
	if not event_issues.is_empty():
		status.text = "Can't save until the events are fixed: " + " ".join(event_issues)
		return
	level_path = path_edit.text
	if level.level_state.save_file(level_path, false) == OK:
		status.text = "Saved %s" % level_path
	else:
		status.text = "Could not save %s" % level_path


func _new() -> void:
	level.level_state = LevelState.fromJson({})
	level.rebuild()
	_refresh_layer_list()
	_select_unit("")
	_stop_picking()
	_stop_event_pick()
	_refresh_objective_panel()
	_refresh_events_panel()
	_clear_history()
	status.text = "New empty map. Add a layer to start painting."


# --- Undo / redo ------------------------------------------------------------


func _snapshot() -> Dictionary:
	return level.level_state.toJson(false)


## Records `before` as an undo step if the level differs from it now. Changes
## with the same non-empty `tag` as the previous step are merged into it.
func _commit(before: Dictionary, tag := "") -> void:
	if before == _snapshot():
		return
	if tag.is_empty() or tag != _last_change_tag:
		undo_stack.append(before)
		if undo_stack.size() > MAX_UNDO:
			undo_stack.pop_front()
	_last_change_tag = tag
	redo_stack.clear()
	_update_history_buttons()


func undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(_snapshot())
	_restore(undo_stack.pop_back())
	status.text = "Undo (%d left)" % undo_stack.size()


func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(_snapshot())
	_restore(redo_stack.pop_back())
	status.text = "Redo (%d left)" % redo_stack.size()


func _restore(snapshot: Dictionary) -> void:
	_last_change_tag = ""
	level.level_state = LevelState.fromJson(snapshot)
	level.rebuild()
	_refresh_layer_list()
	_select_unit(selected_unit_id)
	_stop_picking()  # the old conditions are gone
	_stop_event_pick()
	if not level.level_state.events.has(preselected_event):
		_preselect_event("")
	_refresh_objective_panel()
	_refresh_events_panel()
	_update_history_buttons()


func _clear_history() -> void:
	undo_stack.clear()
	redo_stack.clear()
	_last_change_tag = ""
	_update_history_buttons()


func _update_history_buttons() -> void:
	%UndoButton.disabled = undo_stack.is_empty()
	%RedoButton.disabled = redo_stack.is_empty()


# --- View -------------------------------------------------------------------


func _zoom(factor: float) -> void:
	var before := get_global_mouse_position()
	camera.zoom = (camera.zoom * factor).clamp(Vector2(0.5, 0.5), Vector2(16, 16))
	# Keep the point under the cursor fixed while zooming.
	camera.position += before - get_global_mouse_position()
	overlay.queue_redraw()


func _frame_camera() -> void:
	var bounds := level.level_state.map_data.bounds()
	if bounds.has_area():
		camera.position = (Vector2(bounds.position) + Vector2(bounds.size) / 2.0) * Vector2(level.tile_size)
		# Keep the map clear of the side panel.
		camera.position.x -= %Panel.size.x / (2.0 * camera.zoom.x)


func _update_status() -> void:
	_update_problems()  # unit edits (a deleted or unmarked commander) can change them
	if mode == Mode.UNITS or mode == Mode.EVENTS:
		var here := _unit_id_at(hover_cell)
		status.text = "cell %s   |   %s" % [hover_cell, "unit: " + here if not here.is_empty() else "%d units" % level.level_state.map_data.units.size()]
		var broken := broken_placements()
		if not broken.is_empty():
			status.text += "   |   NOT SHOWN: " + "; ".join(broken)
		return
	var layer := selected_layer()
	var layer_text := "no layer selected" if layer == null else "%s: %d verts" % [layer.name, layer.verts.size()]
	status.text = "vert %s   |   %s" % [hover_vert, layer_text]


## Why each placement that can't be built is skipped (for example a mistyped
## character id). They stay in the level file; play and the editor can't show them.
func broken_placements() -> PackedStringArray:
	var problems := PackedStringArray()
	for ref: UnitReference in level.level_state.map_data.units.values():
		var problem := ref.build_problem()
		if not problem.is_empty():
			problems.append(problem)
	return problems


func _cell_rect(cell: Vector2i) -> Rect2:
	var ts := Vector2(level.tile_size)
	return Rect2(level.to_global(Vector2(cell) * ts), ts)


func _draw_overlay() -> void:
	var ts := Vector2(level.tile_size)
	# Grid over the visible part of the world.
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	var first := (view.position / ts).floor()
	var last := (view.end / ts).ceil()
	for x in range(int(first.x), int(last.x) + 1):
		overlay.draw_line(Vector2(x * ts.x, view.position.y), Vector2(x * ts.x, view.end.y), GRID_COLOR)
	for y in range(int(first.y), int(last.y) + 1):
		overlay.draw_line(Vector2(view.position.x, y * ts.y), Vector2(view.end.x, y * ts.y), GRID_COLOR)

	# Seize cells, in every mode, the same green as in play.
	var seize_cells: Array[Vector2i] = level.level_state.objective.seize_cells() if level.level_state != null else []
	for cell in seize_cells:
		overlay.draw_rect(_cell_rect(cell), SEIZE_FILL)
		overlay.draw_rect(_cell_rect(cell), RangeOverlay.SEIZE_OUTLINE, false, 1.0)
	# Escape cells too, in the same gold as in play.
	var escape_cells: Array[Vector2i] = level.level_state.objective.escape_cells() if level.level_state != null else []
	for cell in escape_cells:
		overlay.draw_rect(_cell_rect(cell), RangeOverlay.ESCAPE_FILL)
		overlay.draw_rect(_cell_rect(cell), RangeOverlay.ESCAPE_OUTLINE, false, 1.0)

	if mode == Mode.OBJECTIVE:
		overlay.draw_rect(_cell_rect(hover_cell), CELL_COLOR, false, 1.0)
		if is_picking() and _has_pending:
			overlay.draw_rect(_cell_rect(_pending_cell), PAINT_COLOR, false, 2.0)
		return

	if mode == Mode.EVENTS:
		overlay.draw_rect(_cell_rect(hover_cell), CELL_COLOR, false, 1.0)
		for id in event_units(outlined_event()):
			overlay.draw_rect(_cell_rect(level.level_state.map_data.units[id].start_cell), PAINT_COLOR, false, 1.0)
		for id in _event_pending:
			overlay.draw_rect(_cell_rect(level.level_state.map_data.units[id].start_cell), PAINT_COLOR, false, 2.0)
		return

	if mode == Mode.UNITS:
		overlay.draw_rect(_cell_rect(hover_cell), CELL_COLOR, false, 1.0)
		var ref: UnitReference = level.level_state.map_data.units.get(selected_unit_id)
		if ref != null:
			overlay.draw_rect(_cell_rect(ref.start_cell), PAINT_COLOR, false, 1.0)
		return

	var layer := selected_layer()
	if layer != null:
		for v in layer.verts:
			overlay.draw_rect(Rect2(vert_position(v) - Vector2(1.5, 1.5), Vector2(3, 3)), VERT_COLOR)

	var color := ERASE_COLOR if (dragging == Brush.ERASE or (dragging == -1 and brush == Brush.ERASE)) else PAINT_COLOR
	for v in brush_verts():
		overlay.draw_arc(vert_position(v), 3.5, 0, TAU, 12, color, 1.0)


# --- Commander -----------------------------------------------------------------


func _on_strategy_picked(index: int) -> void:
	var ref := _selected_enemy()
	if ref == null:
		return
	var before := _snapshot()
	ref.strategy = STRATEGIES[index]
	if ref.strategy != UnitReference.STRATEGY_DEFENSIVE:
		ref.team = ""
	_commit(before)
	_fill_inspector()


## Enter or leaving the box applies the team (blank: the unit's own team).
func _on_team_edited() -> void:
	var ref := _selected_enemy()
	if ref == null or ref.strategy != UnitReference.STRATEGY_DEFENSIVE:
		return
	var team := team_edit.text.strip_edges()
	if team == ref.team:
		return
	var before := _snapshot()
	ref.team = team
	_commit(before)


## The selected placement while it's an enemy and the inspector isn't syncing.
func _selected_enemy() -> UnitReference:
	if _syncing:
		return null
	var ref: UnitReference = level.level_state.map_data.units.get(selected_unit_id)
	return ref if ref != null and ref.faction == UnitReference.Faction.ENEMY else null


## Marks or unmarks the selected enemy as the commander. Only one per level, so
## marking it clears any other.
func _on_commander_toggled(pressed: bool) -> void:
	if _syncing:
		return
	var ref: UnitReference = level.level_state.map_data.units.get(selected_unit_id)
	if ref == null:
		return
	var before := _snapshot()
	if pressed:
		for other: UnitReference in level.level_state.map_data.units.values():
			other.commander = false
	ref.commander = pressed
	_commit(before)
	_rebuild_units()  # the crown is drawn by the unit's node
	_refresh_objective_panel()


# --- Objective -----------------------------------------------------------------
# Each condition is a row: its text, its settings inline (from the registry's
# "settings"), a remove button, and a warning line when it has a problem. The
# "+ Add" menus offer each type once per list.


## What the warning line asks for, by setting, when a condition has a problem.
const SETTING_HINTS := {
	&"commander": "Pick the commander from the list, or Choose on map.",
	&"cells": "Press Choose cell, click a map cell, then Confirm.",
	&"units": "Tick at least one unit.",
	&"turns": "Set at least 1 turn.",
}
const WIN_COLOR := Color(0.55, 0.95, 0.55)
const LOSE_COLOR := Color(1.0, 0.55, 0.5)
const DIM_COLOR := Color(1, 1, 1, 0.55)


func _build_objective_panel() -> void:
	problems_label = Label.new()
	problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	problems_label.add_theme_color_override("font_color", PROBLEM_COLOR)
	objective_box.add_child(problems_label)

	objective_box.add_child(_section_header("WIN when any of these happens", WIN_COLOR))
	win_rows = VBoxContainer.new()
	objective_box.add_child(win_rows)
	win_add_menu = _add_menu(Objective.WIN, "+ Add win condition")

	objective_box.add_child(HSeparator.new())
	lose_header = _section_header("LOSS when any of these happens", LOSE_COLOR)
	objective_box.add_child(lose_header)
	lose_rows = VBoxContainer.new()
	objective_box.add_child(lose_rows)
	lose_add_menu = _add_menu(Objective.LOSE, "+ Add loss condition")


func _section_header(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label


## A "+ Add" menu of the types allowed on `side`; picking one adds its row.
func _add_menu(side: StringName, text: String) -> MenuButton:
	var menu := MenuButton.new()
	menu.text = text
	menu.flat = false
	var types := Objective.types_for(side)
	var popup := menu.get_popup()
	for i in types.size():
		popup.add_item(Objective.title_of(types[i]), i)
	popup.id_pressed.connect(func(id: int) -> void: _add_condition(side, types[id]))
	objective_box.add_child(menu)
	return menu


## Adds a `type_name` condition with default settings to `side`. Each type goes
## in a list at most once (one seize holds many cells, one "falls" many units).
func _add_condition(side: StringName, type_name: String) -> void:
	if _has_type(side, type_name):
		return
	var before := _snapshot()
	_conditions(side).append(Objective.create(type_name))
	_commit(before)
	_refresh_objective_panel()


func _remove_condition(side: StringName, index: int) -> void:
	var list := _conditions(side)
	if index < 0 or index >= list.size():
		return
	var before := _snapshot()
	if list[index] == _pick_condition:
		_cancel_pick()
	list.remove_at(index)
	_commit(before)
	_refresh_objective_panel()


func _has_type(side: StringName, type_name: String) -> bool:
	for condition in _conditions(side):
		if condition.type == type_name:
			return true
	return false


## The level's conditions on `side` (the live arrays, edited in place).
func _conditions(side: StringName) -> Array[Objective.Condition]:
	var objective := level.level_state.objective
	if side == Objective.WIN:
		return objective.win
	if side == Objective.LOSE:
		return objective.lose
	return [] as Array[Objective.Condition]


## A map click in Objective mode: while a Choose is in progress, it picks the
## pending cell (for the commander, it has to be an enemy). Nothing changes
## until Confirm.
func _objective_click(cell: Vector2i) -> void:
	if _pick_condition == null:
		status.text = "To set a seize cell, press Choose cell on the Seize row, then click the map."
		return
	if _pick_condition is Objective.DefeatCommander:
		var unit_id := _unit_id_at(cell)
		var ref: UnitReference = level.level_state.map_data.units.get(unit_id)
		if ref == null or ref.faction != UnitReference.Faction.ENEMY:
			status.text = "Click an enemy unit to make it the commander."
			return
		status.text = "Commander: %s. Press Confirm to set it." % ref.display_name()
	else:
		# A seize cell has to be somewhere a unit can stand on the map.
		if not level.level_state.map_data.bounds().has_point(cell) or level.pathfinding.terrain_at(cell) == null:
			status.text = "That cell isn't on the map; pick a cell with terrain."
			return
		status.text = "Cell %s. Press Confirm to add it." % cell
	_pending_cell = cell
	_has_pending = true
	_refresh_objective_panel()


## Starts picking on the map for `condition` (its Choose button).
func _start_pick(condition: Objective.Condition) -> void:
	_pick_condition = condition
	_has_pending = false
	status.text = "Click an enemy on the map, then Confirm." if condition is Objective.DefeatCommander \
			else "Click a map cell, then Confirm."
	_refresh_objective_panel()


## Applies the pending pick: adds the seize cell, or marks the commander.
func _confirm_pick() -> void:
	if _pick_condition == null or not _has_pending:
		return
	var condition := _pick_condition
	var cell := _pending_cell
	_cancel_pick()
	if condition is Objective.DefeatCommander:
		_on_commander_picked(_unit_id_at(cell))  # commits and redraws
		return
	var seize := condition as Objective.Seize
	if not seize.cells.has(cell):
		var before := _snapshot()
		seize.cells.append(cell)
		_commit(before)
	_refresh_objective_panel()


## Ends a pick without changing anything.
func _cancel_pick() -> void:
	_pick_condition = null
	_has_pending = false
	_refresh_objective_panel()


func _remove_seize_cell(condition: Objective.Condition, cell: Vector2i) -> void:
	var before := _snapshot()
	(condition as Objective.Seize).cells.erase(cell)
	_commit(before)
	_refresh_objective_panel()


## Stops any pick (the level changed under it: load, new, undo).
func _stop_picking() -> void:
	_pick_condition = null
	_has_pending = false


func is_picking() -> bool:
	return _pick_condition != null


func has_pending() -> bool:
	return _has_pending


func pending_cell() -> Vector2i:
	return _pending_cell


## Rebuilds every row from the level's objective, and the add menus.
func _refresh_objective_panel() -> void:
	if win_rows == null or level.level_state == null:
		return
	for rows in [win_rows, lose_rows]:
		for child in rows.get_children():
			rows.remove_child(child)
			child.queue_free()
	_rows.clear()
	for i in level.level_state.objective.win.size():
		_build_row(Objective.WIN, i)
	_build_fixed_loss_row()
	for i in level.level_state.objective.lose.size():
		_build_row(Objective.LOSE, i)
	for pair in [[win_add_menu, Objective.WIN], [lose_add_menu, Objective.LOSE]]:
		var menu: MenuButton = pair[0]
		var types := Objective.types_for(pair[1])
		for i in types.size():
			menu.get_popup().set_item_disabled(i, _has_type(pair[1], types[i]))
	_update_problems()
	overlay.queue_redraw()


func _build_fixed_loss_row() -> void:
	_fixed_loss_label = Label.new()
	_fixed_loss_label.text = "%s   (always)" % Objective.ARMY_DEFEATED_TEXT
	_fixed_loss_label.add_theme_color_override("font_color", DIM_COLOR)
	_fixed_loss_label.tooltip_text = "Built in: losing every player unit always loses."
	lose_rows.add_child(_fixed_loss_label)


## One condition's row, on up to three lines so it fits the narrow panel: its
## text and remove button, then its settings, then a warning if it has a problem.
func _build_row(side: StringName, index: int) -> void:
	var condition: Objective.Condition = _conditions(side)[index]
	var controls := {}
	var row := VBoxContainer.new()
	var title_line := HBoxContainer.new()
	row.add_child(title_line)
	var text := Label.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls[&"text"] = text
	title_line.add_child(text)
	# The settings wrap onto as many lines as the panel needs.
	var line := HFlowContainer.new()
	row.add_child(line)

	for setting in Objective.settings_of(condition.type):
		match setting:
			&"turns":
				var spin := SpinBox.new()
				spin.min_value = 1
				spin.max_value = 99
				spin.value = (condition as Objective.TurnCount).turns
				spin.value_changed.connect(func(v: float) -> void: _on_turns_changed(condition, v))
				# Enter lets go of the box, so its outline goes and the value reads as set.
				spin.get_line_edit().text_submitted.connect(func(_t: String) -> void: spin.get_line_edit().release_focus())
				controls[&"turns"] = spin
				line.add_child(spin)
			&"commander":
				var pick := OptionButton.new()
				pick.add_item("choose...")
				pick.set_item_metadata(0, "")
				for id: String in level.level_state.map_data.units:
					var ref: UnitReference = level.level_state.map_data.units[id]
					if ref.faction == UnitReference.Faction.ENEMY:
						pick.add_item("%s (%s)" % [ref.display_name(), id])
						pick.set_item_metadata(pick.item_count - 1, id)
						if ref.commander:
							pick.select(pick.item_count - 1)
				pick.item_selected.connect(func(i: int) -> void: _on_commander_picked(pick.get_item_metadata(i)))
				controls[&"commander"] = pick
				line.add_child(pick)
				# A commander that arrives later says when.
				var arrives := Label.new()
				var commander: UnitReference = level.level_state.map_data.units.get(level.level_state.commander_id())
				var turn := arrival_turn(commander)
				arrives.text = "arrives on turn %d" % turn if turn > 0 else ""
				arrives.visible = turn > 0
				controls[&"arrives"] = arrives
				line.add_child(arrives)
				_add_pick_controls(condition, line, controls, "Choose on map")
			&"cells":
				# The chosen cells, each removable, then how to add one.
				var cells_line := HFlowContainer.new()
				var chips := {}
				var cells_label := Label.new()
				cells_label.text = "Cells:" if not (condition as Objective.Seize).cells.is_empty() else "Cells: none yet"
				cells_line.add_child(cells_label)
				for cell in (condition as Objective.Seize).cells:
					var chip := Button.new()
					chip.text = "(%d, %d)  x" % [cell.x, cell.y]
					chip.tooltip_text = "Remove this seize cell"
					chip.pressed.connect(func() -> void: _remove_seize_cell(condition, cell))
					chips[cell] = chip
					cells_line.add_child(chip)
				controls[&"cells"] = chips
				row.add_child(cells_line)
				var choose_line := HFlowContainer.new()
				row.add_child(choose_line)
				_add_pick_controls(condition, choose_line, controls, "Choose cell")
			&"name":
				var name_line := HBoxContainer.new()
				var shown := Label.new()
				shown.text = "Shown as: Seize"
				name_line.add_child(shown)
				var edit := LineEdit.new()
				edit.placeholder_text = "the marked cell"
				edit.tooltip_text = "Optional: what the objective calls the seize point, e.g. the gate"
				edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				edit.text = (condition as Objective.Seize).name
				edit.text_changed.connect(func(t: String) -> void: _on_seize_name_changed(condition, t))
				controls[&"name"] = edit
				name_line.add_child(edit)
				row.add_child(name_line)
			&"units":
				# Checkboxes below the line: your units and allies, never enemies.
				var boxes := HFlowContainer.new()
				var by_id := {}
				for id: String in level.level_state.map_data.units:
					var ref: UnitReference = level.level_state.map_data.units[id]
					if ref.faction == UnitReference.Faction.ENEMY:
						continue
					var box := CheckBox.new()
					box.text = ref.display_name()
					box.tooltip_text = id
					box.set_pressed_no_signal((condition as Objective.UnitsFall).units.has(id))
					box.toggled.connect(func(_on: bool) -> void: _on_units_ticked(condition))
					by_id[id] = box
					boxes.add_child(box)
				controls[&"units"] = by_id
				row.add_child(boxes)

	var remove := Button.new()
	remove.text = "X"
	remove.tooltip_text = "Remove this condition"
	remove.pressed.connect(func() -> void: _remove_condition(side, _conditions(side).find(condition)))
	controls[&"remove"] = remove
	title_line.add_child(remove)
	if line.get_child_count() == 0:
		row.remove_child(line)
		line.queue_free()

	var problem := Label.new()
	problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	problem.add_theme_color_override("font_color", PROBLEM_COLOR)
	controls[&"problem"] = problem
	row.add_child(problem)

	_rows[condition] = controls
	(win_rows if side == Objective.WIN else lose_rows).add_child(row)
	_update_row(condition)


## A Choose button, or while this row is picking: a prompt, Confirm and Cancel.
func _add_pick_controls(condition: Objective.Condition, line: Container, controls: Dictionary,
		choose_text: String) -> void:
	if _pick_condition != condition:
		var choose := Button.new()
		choose.text = choose_text
		choose.pressed.connect(func() -> void: _start_pick(condition))
		controls[&"choose"] = choose
		line.add_child(choose)
		return
	var prompt := Label.new()
	if not _has_pending:
		prompt.text = "Click the map..."
	elif condition is Objective.DefeatCommander:
		var ref: UnitReference = level.level_state.map_data.units.get(_unit_id_at(_pending_cell))
		prompt.text = "Selected: %s" % (ref.display_name() if ref != null else "?")
	else:
		prompt.text = "Selected: (%d, %d)" % [_pending_cell.x, _pending_cell.y]
	line.add_child(prompt)
	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.disabled = not _has_pending
	confirm.pressed.connect(_confirm_pick)
	controls[&"confirm"] = confirm
	line.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_cancel_pick)
	controls[&"cancel"] = cancel
	line.add_child(cancel)


## Refreshes a row's text, pick count and warning without rebuilding it, so a
## field being typed in keeps its focus.
func _update_row(condition: Objective.Condition) -> void:
	var controls: Dictionary = _rows.get(condition, {})
	if controls.is_empty():
		return
	(controls[&"text"] as Label).text = condition.describe(level.level_state)
	var problems := condition.validate(level.level_state)
	var hints := PackedStringArray()
	if not problems.is_empty():
		for setting in Objective.settings_of(condition.type):
			if SETTING_HINTS.has(setting) and not hints.has(SETTING_HINTS[setting]):
				hints.append(SETTING_HINTS[setting])
		if hints.is_empty():
			hints = problems
	var problem := controls[&"problem"] as Label
	problem.text = "! " + " ".join(hints) if not hints.is_empty() else ""
	problem.visible = not hints.is_empty()
	_update_problems()


func _on_turns_changed(condition: Objective.Condition, value: float) -> void:
	var count := condition as Objective.TurnCount
	if count.turns == int(value):
		return
	var before := _snapshot()
	count.turns = int(value)
	_commit(before, "objective_turns")
	_update_row(condition)


## A "falls" condition's units are the ticked boxes, in the map's order.
func _on_units_ticked(condition: Objective.Condition) -> void:
	var fall := condition as Objective.UnitsFall
	var before := _snapshot()
	var picked: Array[String] = []
	var boxes: Dictionary = _rows[condition][&"units"]
	for id: String in boxes:
		if (boxes[id] as CheckBox).button_pressed:
			picked.append(id)
	fall.units = picked
	_commit(before)
	_update_row(condition)


func _on_seize_name_changed(condition: Objective.Condition, text: String) -> void:
	var before := _snapshot()
	(condition as Objective.Seize).name = text.strip_edges()
	_commit(before, "objective_name")
	_update_row(condition)


## Marks `unit_id` as the commander (clearing any other), the same mark as the
## Units mode checkbox. "" clears it.
func _on_commander_picked(unit_id: String) -> void:
	var before := _snapshot()
	for ref: UnitReference in level.level_state.map_data.units.values():
		ref.commander = ref.id == unit_id
	_commit(before)
	_rebuild_units()  # the badge is drawn by the unit's node
	_refresh_objective_panel()


## Lookups for tests and tools: a row's control by key (&"text", &"remove",
## &"turns", &"commander", &"choose", &"confirm", &"cancel", &"name",
## &"problem"). Seize cell chips: cell_chip(); unit checkboxes: unit_checkbox().
func row_control(side: StringName, index: int, key: StringName) -> Control:
	var conditions := _conditions(side)
	if index < 0 or index >= conditions.size():
		return null
	return _rows.get(conditions[index], {}).get(key)


## The remove chip for `cell` in a seize row.
func cell_chip(side: StringName, index: int, cell: Vector2i) -> Button:
	var conditions := _conditions(side)
	if index < 0 or index >= conditions.size():
		return null
	var chips: Dictionary = _rows.get(conditions[index], {}).get(&"cells", {})
	return chips.get(cell)


func row_text(side: StringName, index: int) -> String:
	var label := row_control(side, index, &"text") as Label
	return label.text if label != null else ""


func unit_checkbox(side: StringName, index: int, unit_id: String) -> CheckBox:
	var conditions := _conditions(side)
	if index < 0 or index >= conditions.size():
		return null
	var boxes: Dictionary = _rows.get(conditions[index], {}).get(&"units", {})
	return boxes.get(unit_id)


func fixed_loss_text() -> String:
	return _fixed_loss_label.text if _fixed_loss_label != null else ""


## What stops the level from being saved: Objective.validate's problems, and a
## Rout that would be won at once because every enemy arrives later.
func objective_problems() -> PackedStringArray:
	var problems := level.level_state.objective.validate(level.level_state)
	var counts := _enemy_counts()
	if _has_rout() and counts[1] > 0 and counts[0] == 0:
		problems.append("No enemy starts on the map, so Rout wins at once.")
	return problems


## Worth a look but not blocking: an empty win list means "never" (a level an
## event will end later), which is easy to do by accident.
func objective_notes() -> PackedStringArray:
	var notes := PackedStringArray()
	if level.level_state.objective.win.is_empty():
		notes.append("No win condition: the level can only be lost.")
	var counts := _enemy_counts()
	if _has_rout() and counts[1] > 0 and counts[0] > 0:
		notes.append("Rout counts only enemies on the map; %d more arrive later." % counts[1])
	return notes


func _has_rout() -> bool:
	for condition in level.level_state.objective.win:
		if condition is Objective.FactionDefeated:
			return true
	return false


## [enemies on the map when Rout is first checked, enemies arriving later].
## Arrivals on turn 1's player phase count as on the map: that event runs before
## the first check.
func _enemy_counts() -> Array[int]:
	var counts: Array[int] = [0, 0]
	for ref: UnitReference in level.level_state.map_data.units.values():
		if ref.faction != UnitReference.Faction.ENEMY:
			continue
		var turn := arrival_turn(ref)
		var first_phase := turn == 1 and str(level.level_state.events[ref.event]["trigger"]["phase"]) == "player"
		counts[1 if turn > 0 and not first_phase else 0] += 1
	return counts


## The summary at the top of the panel: blocking problems, then notes.
func _update_problems() -> void:
	if problems_label == null or level.level_state == null:
		return  # before the first level loads
	var problems := objective_problems()
	var lines := PackedStringArray()
	if not problems.is_empty():
		# Each row says what it needs; the summary only lists what no row shows
		# (e.g. two commanders marked in Units mode).
		var own := PackedStringArray()
		for condition in level.level_state.objective.win + level.level_state.objective.lose:
			own.append_array(condition.validate(level.level_state))
		lines.append("Can't save yet: fix the rows marked with !" if not own.is_empty() else "Can't save yet:")
		for problem in problems:
			if not own.has(problem):
				lines.append("- " + problem)
	for note in objective_notes():
		lines.append("Note: " + note)
	problems_label.text = "\n".join(lines)
	problems_label.visible = not lines.is_empty()


# --- Events: reinforcements ----------------------------------------------------------
# Each event is a row: WHEN turn N's enemy or player phase starts, THEN these
# enemies arrive. Units join an event here (Choose -> click -> Confirm, or Place
# new units) or from the Units inspector's Arrives dropdown: the same data.


const EVENT_PHASE_TEXT := ["enemy phase", "player phase"]


func _build_events_panel() -> void:
	events_problems_label = Label.new()
	events_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	events_problems_label.add_theme_color_override("font_color", PROBLEM_COLOR)
	events_box.add_child(events_problems_label)
	events_box.add_child(_section_header("REINFORCEMENTS: enemies that arrive later", WIN_COLOR))
	event_rows = VBoxContainer.new()
	events_box.add_child(event_rows)
	add_event_button = Button.new()
	add_event_button.text = "+ Add reinforcement event"
	add_event_button.pressed.connect(_add_event)
	events_box.add_child(add_event_button)


## The turn `ref` arrives on, or 0 when it starts on the map (or its event is
## missing or broken, so it would start there in play too).
func arrival_turn(ref: UnitReference) -> int:
	if ref == null or ref.event.is_empty() or ref.faction != UnitReference.Faction.ENEMY:
		return 0
	var event: Variant = level.level_state.events.get(ref.event)
	if event == null or not LevelState.event_problem(event).is_empty():
		return 0
	return int(event["trigger"]["turn"])


## An event's name, or "Turn N reinforcements".
func event_title(event_id: String) -> String:
	var event: Variant = level.level_state.events.get(event_id)
	if not event is Dictionary:
		return event_id
	var name := str((event as Dictionary).get("name", ""))
	if not name.is_empty():
		return name
	var trigger: Variant = (event as Dictionary).get("trigger")
	return "Turn %d reinforcements" % int(trigger.get("turn", 0)) if trigger is Dictionary else event_id


## The ids of the units tied to `event_id`, in map order.
func event_units(event_id: String) -> Array[String]:
	var ids: Array[String] = []
	if event_id.is_empty():
		return ids
	for id: String in level.level_state.map_data.units:
		if level.level_state.map_data.units[id].event == event_id:
			ids.append(id)
	return ids


## What stops saving: events that can't run, and events with no units.
func event_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	for event_id: String in level.level_state.events:
		var problem := LevelState.event_problem(level.level_state.events[event_id])
		if not problem.is_empty():
			problems.append("Event '%s': %s." % [event_id, problem])
		elif event_units(event_id).is_empty():
			problems.append("%s: no units arrive." % event_title(event_id))
	return problems


func _add_event() -> void:
	var before := _snapshot()
	var n := level.level_state.events.size() + 1
	while level.level_state.events.has("wave_%d" % n):
		n += 1
	var id := "wave_%d" % n
	level.level_state.events[id] = {
		"trigger": {"type": "turn_start", "turn": 2, "phase": "enemy"},
		"actions": [{"type": "spawn"}],
	}
	_commit(before)
	_focused_event = id
	_refresh_events_panel()


func _remove_event(event_id: String) -> void:
	var before := _snapshot()
	for id in event_units(event_id):
		level.level_state.map_data.units[id].event = ""
	level.level_state.events.erase(event_id)
	_commit(before)
	if preselected_event == event_id:
		_preselect_event("")
	if _event_pick == event_id:
		_stop_event_pick()
	_after_event_change()


## Units, inspector, objective notes and this panel all follow an event edit.
func _after_event_change() -> void:
	_rebuild_units()  # also refreshes this panel
	_fill_inspector()
	_refresh_objective_panel()


func _on_event_turn(event_id: String, value: float) -> void:
	var trigger: Dictionary = level.level_state.events[event_id]["trigger"]
	if int(trigger.get("turn", 0)) == int(value):
		return
	var before := _snapshot()
	trigger["turn"] = int(value)
	_commit(before, "event_turn:" + event_id)
	_focused_event = event_id
	_tint_units()
	_update_event_row(event_id)
	_update_events_problems()
	# Other modes show the turn too: the Arrives dropdown and the commander's
	# "arrives on turn N". Neither is on screen here, so rebuilding them is safe.
	_fill_inspector()
	_refresh_objective_panel()


func _on_event_phase(event_id: String, index: int) -> void:
	var before := _snapshot()
	level.level_state.events[event_id]["trigger"]["phase"] = "enemy" if index == 0 else "player"
	_commit(before)
	_focused_event = event_id
	_update_problems()


func _on_event_name(event_id: String, text: String) -> void:
	var before := _snapshot()
	var event: Dictionary = level.level_state.events[event_id]
	if text.strip_edges().is_empty():
		event.erase("name")
	else:
		event["name"] = text.strip_edges()
	_commit(before, "event_name:" + event_id)
	_fill_inspector()


func _remove_from_event(unit_id: String) -> void:
	var before := _snapshot()
	level.level_state.map_data.units[unit_id].event = ""
	_commit(before)
	_after_event_change()


# Choose -> click enemies -> Confirm.


## The event whose units are outlined in Events mode: the one being chosen for,
## else the one last worked on.
func outlined_event() -> String:
	return _event_pick if is_picking_event() else _focused_event


func is_picking_event() -> bool:
	return not _event_pick.is_empty()


func _start_event_pick(event_id: String) -> void:
	_event_pick = event_id
	_focused_event = event_id
	_event_pending.clear()
	status.text = "Click enemies on the map to add them, then Confirm."
	_refresh_events_panel()
	overlay.queue_redraw()


## A map click in Events mode: while choosing, toggles the enemy there.
func _events_click(cell: Vector2i) -> void:
	if not is_picking_event():
		status.text = "To add units, press Choose units on an event, then click enemies."
		return
	var id := _unit_id_at(cell)
	var ref: UnitReference = level.level_state.map_data.units.get(id)
	if ref == null or ref.faction != UnitReference.Faction.ENEMY:
		status.text = "Only enemies arrive later: click an enemy."
		return
	if _event_pending.has(id):
		_event_pending.erase(id)
	else:
		_event_pending.append(id)
	status.text = "%d chosen. Press Confirm to add them." % _event_pending.size()
	_refresh_events_panel()
	overlay.queue_redraw()


func _confirm_event_pick() -> void:
	var event_id := _event_pick
	var chosen := _event_pending.duplicate()
	_stop_event_pick()
	if not chosen.is_empty():
		var before := _snapshot()
		for id: String in chosen:
			level.level_state.map_data.units[id].event = event_id
		_commit(before)
	_after_event_change()
	status.text = "%d enemy(s) added to %s." % [chosen.size(), event_title(event_id)]


func _cancel_event_pick() -> void:
	_stop_event_pick()
	_refresh_events_panel()
	overlay.queue_redraw()


func _stop_event_pick() -> void:
	_event_pick = ""
	_event_pending.clear()


# Placing new units into an event.


## New enemy placements join `event_id` until it's cleared ("" clears). Switches
## to Units mode with Enemy picked.
func _preselect_event(event_id: String) -> void:
	preselected_event = event_id
	if not event_id.is_empty():
		_focused_event = event_id
		if mode != Mode.UNITS:
			_set_mode(Mode.UNITS)
		preselected_event = event_id  # _set_mode doesn't clear it entering Units
		faction_option.selected = UnitReference.Faction.ENEMY
		_select_unit("")
	preselect_row.visible = not preselected_event.is_empty()
	preselect_label.text = "New enemies arrive with: %s" % event_title(preselected_event)


func _on_arrives_picked(index: int) -> void:
	var ref := _selected_enemy()
	if ref == null:
		return
	var before := _snapshot()
	ref.event = "" if index == 0 else String(level.level_state.events.keys()[index - 1])
	_commit(before)
	_after_event_change()


# Rows.


func _refresh_events_panel() -> void:
	if event_rows == null or level.level_state == null:
		return
	for child in event_rows.get_children():
		event_rows.remove_child(child)
		child.queue_free()
	_event_rows.clear()
	for event_id: String in level.level_state.events:
		_build_event_row(event_id)
	_update_events_problems()


func _build_event_row(event_id: String) -> void:
	var event: Variant = level.level_state.events[event_id]
	var controls := {}
	var row := VBoxContainer.new()
	var valid := LevelState.event_problem(event).is_empty()

	var when := HFlowContainer.new()
	row.add_child(when)
	var when_label := Label.new()
	when_label.text = "WHEN turn"
	when.add_child(when_label)
	if valid:
		var trigger: Dictionary = event["trigger"]
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = 99
		spin.value = int(trigger["turn"])
		spin.value_changed.connect(func(v: float) -> void: _on_event_turn(event_id, v))
		spin.get_line_edit().text_submitted.connect(func(_t: String) -> void: spin.get_line_edit().release_focus())
		controls[&"turn"] = spin
		when.add_child(spin)
		var phase := OptionButton.new()
		for text: String in EVENT_PHASE_TEXT:
			phase.add_item(text)
		phase.selected = 0 if trigger["phase"] == "enemy" else 1
		phase.item_selected.connect(func(i: int) -> void: _on_event_phase(event_id, i))
		controls[&"phase"] = phase
		when.add_child(phase)
		var starts := Label.new()
		starts.text = "starts"
		when.add_child(starts)
	var remove := Button.new()
	remove.text = "X"
	remove.tooltip_text = "Delete this event: its units start on the map"
	remove.pressed.connect(_remove_event.bind(event_id))
	controls[&"remove"] = remove
	when.add_child(remove)

	if valid:
		var name_line := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = "Name"
		name_line.add_child(name_label)
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Turn %d reinforcements" % int(event["trigger"]["turn"])
		name_edit.text = str((event as Dictionary).get("name", ""))
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.text_changed.connect(func(t: String) -> void: _on_event_name(event_id, t))
		controls[&"name"] = name_edit
		name_line.add_child(name_edit)
		row.add_child(name_line)

		var then := Label.new()
		then.text = "THEN these enemies arrive:"
		row.add_child(then)
		var chips_line := HFlowContainer.new()
		var chips := {}
		var units := event_units(event_id)
		if units.is_empty():
			var none := Label.new()
			none.text = "none yet"
			chips_line.add_child(none)
		for id in units:
			# The name selects the unit on the map; the x takes it out of the event.
			var chip := HBoxContainer.new()
			chip.add_theme_constant_override("separation", 0)
			var select := Button.new()
			select.text = level.level_state.map_data.units[id].display_name()
			select.tooltip_text = "Select it on the map"
			select.pressed.connect(_select_unit.bind(id))
			chip.add_child(select)
			var remove_unit := Button.new()
			remove_unit.text = "x"
			remove_unit.tooltip_text = "Take it out of this event: it starts on the map"
			remove_unit.pressed.connect(_remove_from_event.bind(id))
			chips[id] = remove_unit
			chip.add_child(remove_unit)
			chips_line.add_child(chip)
		controls[&"chips"] = chips
		row.add_child(chips_line)

		var actions := HFlowContainer.new()
		if _event_pick == event_id:
			var prompt := Label.new()
			prompt.text = "Click enemies... (%d chosen)" % _event_pending.size()
			actions.add_child(prompt)
			var confirm := Button.new()
			confirm.text = "Confirm"
			confirm.disabled = _event_pending.is_empty()
			confirm.pressed.connect(_confirm_event_pick)
			controls[&"confirm"] = confirm
			actions.add_child(confirm)
			var cancel := Button.new()
			cancel.text = "Cancel"
			cancel.pressed.connect(_cancel_event_pick)
			controls[&"cancel"] = cancel
			actions.add_child(cancel)
		else:
			var choose := Button.new()
			choose.text = "+ Add units"
			choose.tooltip_text = "Click enemies already on the map, then Confirm"
			choose.pressed.connect(_start_event_pick.bind(event_id))
			controls[&"choose"] = choose
			actions.add_child(choose)
			var place := Button.new()
			place.text = "Place new units"
			place.tooltip_text = "Go to Units mode: enemies you place join this event"
			place.pressed.connect(_preselect_event.bind(event_id))
			controls[&"place"] = place
			actions.add_child(place)
		row.add_child(actions)

	var problem := Label.new()
	problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	problem.add_theme_color_override("font_color", PROBLEM_COLOR)
	controls[&"problem"] = problem
	row.add_child(problem)
	row.add_child(HSeparator.new())
	_event_rows[event_id] = controls
	event_rows.add_child(row)
	_update_event_row(event_id)


## The row's warning, without rebuilding it (a spin being typed in keeps focus).
func _update_event_row(event_id: String) -> void:
	var controls: Dictionary = _event_rows.get(event_id, {})
	if controls.is_empty():
		return
	var problem := LevelState.event_problem(level.level_state.events[event_id])
	if problem.is_empty() and event_units(event_id).is_empty():
		problem = "add the enemies that arrive"
	var label := controls[&"problem"] as Label
	label.text = "! " + problem if not problem.is_empty() else ""
	label.visible = not problem.is_empty()
	if controls.has(&"name"):
		(controls[&"name"] as LineEdit).placeholder_text = "Turn %d reinforcements" \
				% int(level.level_state.events[event_id]["trigger"]["turn"])


func _update_events_problems() -> void:
	if events_problems_label == null:
		return
	var problems := event_problems()
	events_problems_label.text = "Can't save yet: fix the events marked with !" if not problems.is_empty() else ""
	events_problems_label.visible = not problems.is_empty()


func event_control(event_id: String, key: StringName) -> Control:
	return _event_rows.get(event_id, {}).get(key)


func event_chip(event_id: String, unit_id: String) -> Button:
	return _event_rows.get(event_id, {}).get(&"chips", {}).get(unit_id)
