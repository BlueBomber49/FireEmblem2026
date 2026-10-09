class_name MapEditor
extends Node2D
## Paints terrain vertices onto a Level's layers, places units, and saves the
## result as a level JSON. Run this scene directly (not the main scene).
##
## Terrain mode: left mouse paints, right mouse erases.
## Units mode: left click places a unit, drag moves one, right click deletes.
## Both: middle-drag / arrows pan, wheel zooms, Ctrl+Z / Ctrl+Shift+Z undo / redo.

enum Mode { TERRAIN, UNITS }
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

const SHEETS_DIR := "res://Fantasy Battle Pack/Sprite Sheets/"
## Faction -> colour suffix used by the sheet filenames.
const FACTION_COLORS := {
	UnitReference.Faction.PLAYER: "Blue",
	UnitReference.Faction.ENEMY: "Red",
	UnitReference.Faction.ALLY: "Green",
}
## Stats a newly placed unit starts with.
const DEFAULT_STATS := {
	&"hp": 20, &"str": 5, &"mag": 0, &"skl": 5, &"spd": 5,
	&"lck": 3, &"def": 4, &"res": 1, &"con": 6, &"mov": 5,
}

@export_file("*.json") var level_path := "res://data/maps/simple_level.json"

@onready var level: Level = $Level
@onready var camera: Camera2D = $Camera
@onready var overlay: Node2D = $Overlay
@onready var path_edit: LineEdit = %PathEdit
@onready var mode_option: OptionButton = %ModeOption
@onready var terrain_box: VBoxContainer = %TerrainBox
@onready var units_box: VBoxContainer = %UnitsBox
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
## Class name -> directory under SHEETS_DIR.
var unit_classes: Array[String] = []
## StringName -> SpinBox, built in _ready.
var stat_spins: Dictionary = {}
## True while the inspector is being filled from a unit, so edits don't echo back.
var _syncing := false

## Level snapshots (toJson(false)) to restore on undo / redo.
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
## Tag of the last committed change; consecutive changes with the same tag merge.
var _last_change_tag := ""
## Snapshot taken when a brush stroke started, committed when it ends.
var _stroke_before: Dictionary = {}


func _ready() -> void:
	level.interactive = false
	level.create_camera = false
	path_edit.text = level_path
	_fill_terrain_options()
	_fill_unit_options()
	_build_stats_grid()
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
	%DeleteUnitButton.pressed.connect(_delete_selected_unit)
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

	var click := event as InputEventMouseButton
	if click == null:
		return
	match click.button_index:
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
			_update_hover()
			if mode == Mode.TERRAIN:
				_terrain_click(click)
			else:
				_unit_click(click)
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
	mode = new_mode
	mode_option.selected = mode
	terrain_box.visible = mode == Mode.TERRAIN
	units_box.visible = mode == Mode.UNITS
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
	return level.map_data.layerData.layers.get(layer_list.get_item_metadata(items[0]))


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
	for layer in level.map_data.layerData.sorted_layers():
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
	if level.map_data.layerData.layers.has(layer_name):
		status.text = "A layer named '%s' already exists." % layer_name
		return
	var before := _snapshot()
	level.map_data.layerData.layers[layer_name] = MapLayer.new(layer_name, int(z_spin.value), terrain)
	_commit(before)
	name_edit.text = ""
	level.toTscn()
	_refresh_layer_list(layer_name)


func _remove_layer() -> void:
	var layer := selected_layer()
	if layer == null:
		return
	var before := _snapshot()
	level.map_data.layerData.layers.erase(layer.name)
	_commit(before)
	level.toTscn()
	_refresh_layer_list()


func _next_z() -> int:
	var z := 0
	for layer in level.map_data.layerData.layers.values():
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
			var ref: UnitReference = level.map_data.units.get(dragging_unit_id)
			if ref != null and ref.start_cell != hover_cell:
				var before := _snapshot()
				ref.start_cell = hover_cell
				_commit(before)
				_rebuild_units()
		dragging_unit_id = ""


func _unit_id_at(cell: Vector2i) -> String:
	for id in level.map_data.units:
		if level.map_data.units[id].start_cell == cell:
			return id
	return ""


func _place_unit(cell: Vector2i) -> void:
	if unit_classes.is_empty():
		status.text = "No sprite sheets found under %s" % SHEETS_DIR
		return
	var ref := UnitReference.new()
	ref.unit_class = class_option.get_item_text(class_option.selected)
	ref.faction = faction_option.selected as UnitReference.Faction
	ref.id = _free_unit_id(ref.unit_class)
	ref.name = ref.unit_class
	ref.level = 1
	ref.stats = DEFAULT_STATS.duplicate()
	ref.sprite_sheet = sheet_for(ref.unit_class, ref.faction)
	ref.start_cell = cell
	var before := _snapshot()
	level.map_data.units[ref.id] = ref
	_commit(before)
	_rebuild_units()
	_select_unit(ref.id)


func _delete_unit(id: String) -> void:
	var before := _snapshot()
	level.map_data.units.erase(id)
	_commit(before)
	if selected_unit_id == id:
		selected_unit_id = ""
	_rebuild_units()
	_select_unit(selected_unit_id)


func _delete_selected_unit() -> void:
	if not selected_unit_id.is_empty():
		_delete_unit(selected_unit_id)


func _select_unit(id: String) -> void:
	selected_unit_id = id if level.map_data.units.has(id) else ""
	for node_id in level.unit_nodes:
		level.unit_nodes[node_id].modulate = SELECTED_TINT if node_id == selected_unit_id else Color.WHITE
	_fill_inspector()
	overlay.queue_redraw()
	_update_status()


## Units in the editor always show their authored start cells.
func _rebuild_units() -> void:
	level.level_units = LevelUnitState.build_all(level.map_data.units, {})
	level.respawn_units()
	for node_id in level.unit_nodes:
		level.unit_nodes[node_id].modulate = SELECTED_TINT if node_id == selected_unit_id else Color.WHITE


func _free_unit_id(unit_class: String) -> String:
	var base := unit_class.to_snake_case()
	var n := 1
	while level.map_data.units.has("%s_%d" % [base, n]):
		n += 1
	return "%s_%d" % [base, n]


func _fill_inspector() -> void:
	_syncing = true
	var ref: UnitReference = level.map_data.units.get(selected_unit_id)
	var editing := ref != null
	unit_header.text = "Editing '%s'" % selected_unit_id if editing else "New unit template"
	id_edit.editable = editing
	unit_name_edit.editable = editing
	level_spin.editable = editing
	%DeleteUnitButton.disabled = not editing
	for spin in stat_spins.values():
		spin.editable = editing
	if editing:
		class_option.selected = maxi(unit_classes.find(ref.unit_class), 0)
		faction_option.selected = ref.faction
		id_edit.text = ref.id
		unit_name_edit.text = ref.name
		level_spin.value = ref.level
		for key in stat_spins:
			stat_spins[key].value = ref.stat(key)
	else:
		id_edit.text = ""
		unit_name_edit.text = ""
		level_spin.value = 1
		for key in stat_spins:
			stat_spins[key].value = DEFAULT_STATS[key]
	_syncing = false


## Writes the inspector back to the selected unit. `respawn` when the sprite changes.
func _apply_inspector(respawn := false) -> void:
	if _syncing:
		return
	var ref: UnitReference = level.map_data.units.get(selected_unit_id)
	if ref == null:
		return
	var before := _snapshot()
	var tag := "inspector:" + ref.id
	var new_id := id_edit.text.strip_edges()
	if not new_id.is_empty() and new_id != ref.id:
		if level.map_data.units.has(new_id):
			status.text = "A unit with id '%s' already exists." % new_id
			id_edit.text = ref.id
		else:
			level.map_data.units.erase(ref.id)
			ref.id = new_id
			level.map_data.units[new_id] = ref
			selected_unit_id = new_id
			respawn = true
	ref.name = unit_name_edit.text
	ref.level = int(level_spin.value)
	for key in stat_spins:
		ref.stats[key] = int(stat_spins[key].value)
	ref.unit_class = class_option.get_item_text(class_option.selected)
	ref.faction = faction_option.selected as UnitReference.Faction
	ref.sprite_sheet = sheet_for(ref.unit_class, ref.faction)
	# Typing in a field produces many tiny edits; they merge into one undo step.
	_commit(before, tag)
	if respawn:
		_rebuild_units()
	unit_header.text = "Editing '%s'" % selected_unit_id


## The sheet for a class in a faction's colour, e.g. Archer + ENEMY -> Archer_Red1.png.
func sheet_for(unit_class: String, faction: UnitReference.Faction) -> String:
	var dir := DirAccess.open(SHEETS_DIR + unit_class)
	if dir == null:
		return ""
	var color: String = FACTION_COLORS[faction]
	var candidates := []
	for file in dir.get_files():
		if file.ends_with(".png") and (file.ends_with("_%s1.png" % color) or file.ends_with("_%s.png" % color)):
			candidates.append(file)
	if candidates.is_empty():
		return ""
	candidates.sort()
	return SHEETS_DIR + unit_class + "/" + candidates[0]


func _fill_unit_options() -> void:
	unit_classes.clear()
	class_option.clear()
	var dir := DirAccess.open(SHEETS_DIR)
	if dir != null:
		var names := dir.get_directories()
		names.sort()
		for n in names:
			unit_classes.append(n)
			class_option.add_item(n)
	faction_option.clear()
	for f in UnitReference.Faction.values():
		faction_option.add_item(UnitReference.FACTION_NAMES[f].capitalize(), f)


func _build_stats_grid() -> void:
	for key in UnitReference.STAT_KEYS:
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
	if level.load_file(level_path) != OK:
		status.text = "Could not load %s" % level_path
		return
	level.toTscn()
	_frame_camera()
	_refresh_layer_list()
	_select_unit("")
	_clear_history()
	status.text = "Loaded %s" % level_path


func _save() -> void:
	level_path = path_edit.text
	if level.save_file(level_path, false) == OK:
		status.text = "Saved %s" % level_path
	else:
		status.text = "Could not save %s" % level_path


func _new() -> void:
	level.fromJson({})
	level.toTscn()
	_refresh_layer_list()
	_select_unit("")
	_clear_history()
	status.text = "New empty map. Add a layer to start painting."


# --- Undo / redo ------------------------------------------------------------


func _snapshot() -> Dictionary:
	return level.toJson(false)


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
	level.fromJson(snapshot)
	level.toTscn()
	_refresh_layer_list()
	_select_unit(selected_unit_id)
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
	var bounds := level.map_data.layerData.bounds()
	if bounds.has_area():
		camera.position = (Vector2(bounds.position) + Vector2(bounds.size) / 2.0) * Vector2(level.tile_size)
		# Keep the map clear of the side panel.
		camera.position.x -= %Panel.size.x / (2.0 * camera.zoom.x)


func _update_status() -> void:
	if mode == Mode.UNITS:
		var here := _unit_id_at(hover_cell)
		status.text = "cell %s   |   %s" % [hover_cell, "unit: " + here if not here.is_empty() else "%d units" % level.map_data.units.size()]
		return
	var layer := selected_layer()
	var layer_text := "no layer selected" if layer == null else "%s: %d verts" % [layer.name, layer.verts.size()]
	status.text = "vert %s   |   %s" % [hover_vert, layer_text]


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

	if mode == Mode.UNITS:
		overlay.draw_rect(_cell_rect(hover_cell), CELL_COLOR, false, 1.0)
		var ref: UnitReference = level.map_data.units.get(selected_unit_id)
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
