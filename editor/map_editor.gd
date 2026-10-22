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


@export_file("*.json") var level_path := "res://resources/levels/simple_level.json"

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

## Level snapshots (toJson(false)) to restore on undo / redo.
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
		_select_unit("")
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
	for node_id in level.unit_nodes:
		level.unit_nodes[node_id].modulate = SELECTED_TINT if node_id == selected_unit_id else Color.WHITE
	_fill_inspector()
	overlay.queue_redraw()
	_update_status()


## Units in the editor always show their authored start cells.
func _rebuild_units() -> void:
	level.level_state.level_units = LevelUnitState.build_all(level.level_state.map_data.units, {})
	level.respawn_units()
	for node_id in level.unit_nodes:
		level.unit_nodes[node_id].modulate = SELECTED_TINT if node_id == selected_unit_id else Color.WHITE


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
	level.level_state = loaded
	level.rebuild()
	_frame_camera()
	_refresh_layer_list()
	_select_unit("")
	_clear_history()
	status.text = "Loaded %s" % level_path


func _save() -> void:
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
	if mode == Mode.UNITS:
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
