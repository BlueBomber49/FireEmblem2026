class_name Level
extends Node2D
## A playable map. Loaded from JSON (an authored level or a save), built into
## stacked TileMapLayers and LevelUnits by toTscn(), and saved back to JSON
## from the unit states. Units stand on tile cells; the vertex data in
## MapData only decides which tiles get drawn.

const SAVE_VERSION := 1
## Seconds a unit takes to cross one tile.
const STEP_TIME := 0.15
const SELECTED_TINT := Color(1.0, 1.0, 0.5)

## Loaded and built in _ready when set. Cleared on the root of a packed .tscn
## so opening that file doesn't rebuild it.
@export_file("*.json") var level_path := ""
@export var tile_size := Vector2i(16, 16)
@export var camera_zoom := 2.0
## Off in the map editor, which brings its own camera and input.
@export var create_camera := true
@export var interactive := true

var map_data: MapData
## id -> LevelUnitState; the saveable state of every unit.
var level_units: Dictionary = {}
## Unimplemented for now; carried through JSON untouched.
var events: Dictionary = {}

var astar := AStarGrid2D.new()
var tiles: LevelTileSet
var layers_root: Node2D
var units_root: Node2D
var camera: Camera2D
## id -> LevelUnit; the views for `level_units`.
var unit_nodes: Dictionary = {}
var selected: LevelUnit = null
var moving := false


func _ready() -> void:
	if map_data == null and level_path != "":
		if load_file(level_path) == OK:
			toTscn()


# --- Serialization ---------------------------------------------------------


func fromJson(d: Dictionary) -> void:
	map_data = MapData.fromJson(d.get("map_data", {}))
	events = d.get("events", {}).duplicate(true)
	# A save carries level_units; an authored level doesn't, so units start fresh.
	level_units = LevelUnitState.build_all(map_data.units, d.get("level_units", {}))


## With `include_state` off this is an authored level (no level_units), so
## loading it starts every unit fresh.
func toJson(include_state := true) -> Dictionary:
	var d := {
		"version": SAVE_VERSION,
		"map_data": map_data.toJson(),
		"events": events.duplicate(true),
	}
	if include_state:
		var saved_units := {}
		for id in level_units:
			saved_units[id] = level_units[id].toJson()
		d["level_units"] = saved_units
	return d


func load_file(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open level '%s': %s" % [path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Level '%s' is not a JSON object" % path)
		return ERR_PARSE_ERROR
	fromJson(parsed)
	return OK


func save_file(path: String, include_state := true) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write level '%s': %s" % [path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(toJson(include_state), "\t"))
	return OK


# --- Scene construction ----------------------------------------------------


## Rebuilds the layer, unit and camera nodes from `map_data` and `level_units`.
## With `save_path`, also packs the result and writes it as a .tscn (a visual
## snapshot for the editor; the JSON stays the source of truth).
func toTscn(save_path := "") -> PackedScene:
	clear_scene()
	var max_z := _build_layers()
	_spawn_units(max_z + 1)
	_setup_astar()
	if create_camera:
		_setup_camera()

	if save_path.is_empty():
		return null
	# pack() only keeps nodes owned by the root.
	_set_owner_recursive(self)
	var boot_path := level_path
	level_path = ""
	var scene := PackedScene.new()
	var err := scene.pack(self)
	if err == OK:
		err = ResourceSaver.save(scene, save_path)
	level_path = boot_path
	if err != OK:
		push_error("Could not save scene '%s': %s" % [save_path, error_string(err)])
		return null
	return scene


func clear_scene() -> void:
	for node in [layers_root, units_root, camera]:
		if node != null:
			remove_child(node)
			node.free()
	layers_root = null
	units_root = null
	camera = null
	unit_nodes.clear()
	selected = null
	moving = false


## Returns the highest layer z so units can be drawn above it.
func _build_layers() -> int:
	tiles = LevelTileSet.new(tile_size)
	layers_root = Node2D.new()
	layers_root.name = "Layers"
	add_child(layers_root)

	var max_z := 0
	for layer in map_data.layerData.sorted_layers():
		var terrain := TerrainType.load_by_id(layer.terrain)
		if terrain == null:
			push_error("Layer '%s': unknown terrain '%s'" % [layer.name, layer.terrain])
			continue
		tiles.add_terrain(terrain)

		var tile_layer := TileMapLayer.new()
		tile_layer.name = layer.name
		tile_layer.tile_set = tiles.tile_set
		tile_layer.z_index = layer.z
		layers_root.add_child(tile_layer)
		_paint_layer(tile_layer, layer, terrain)
		max_z = maxi(max_z, layer.z)
	return max_z


## Redraws one layer's tiles after its verts changed (used by the map editor).
func repaint_layer(layer_name: String) -> void:
	var layer: MapLayer = map_data.layerData.layers.get(layer_name)
	var tile_layer := layers_root.get_node_or_null(NodePath(layer_name)) as TileMapLayer
	if layer == null or tile_layer == null:
		return
	var terrain := TerrainType.load_by_id(layer.terrain)
	tiles.add_terrain(terrain)
	tile_layer.clear()
	_paint_layer(tile_layer, layer, terrain)


func _paint_layer(tile_layer: TileMapLayer, layer: MapLayer, terrain: TerrainType) -> void:
	var source_id := tiles.source_id_for(terrain)
	var masks := layer.cell_masks()
	for cell in masks:
		tile_layer.set_cell(cell, source_id, terrain.atlas_coords(masks[cell]))


## Rebuilds just the unit nodes from `level_units` (used by the map editor).
func respawn_units() -> void:
	var z := units_root.z_index
	remove_child(units_root)
	units_root.free()
	unit_nodes.clear()
	selected = null
	_spawn_units(z)


func _spawn_units(z: int) -> void:
	units_root = Node2D.new()
	units_root.name = "Units"
	units_root.z_index = z
	add_child(units_root)

	for id in level_units:
		var state: LevelUnitState = level_units[id]
		var ref: UnitReference = map_data.units.get(id)
		if ref == null or not state.is_alive():
			continue
		var unit := LevelUnit.create(ref, state)
		units_root.add_child(unit)
		unit.global_position = cell_center(state.cell)
		unit_nodes[id] = unit


func _setup_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = map_data.layerData.bounds()
	astar.cell_size = Vector2(tile_size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	# Manhattan gives long straight runs; the default (Euclidean) staircases
	# along the diagonal, which makes the unit turn on almost every tile.
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	# Any cell some layer draws on is walkable; everything else is not.
	var drawn := map_data.layerData.drawn_cells()
	for x in range(astar.region.position.x, astar.region.end.x):
		for y in range(astar.region.position.y, astar.region.end.y):
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, not drawn.has(cell))


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	var bounds := map_data.layerData.bounds()
	camera.position = (Vector2(bounds.position) + Vector2(bounds.size) / 2.0) * Vector2(tile_size)
	add_child(camera)
	camera.make_current()


func _set_owner_recursive(node: Node) -> void:
	for child in node.get_children():
		child.owner = self
		_set_owner_recursive(child)


# --- Input and movement ----------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if moving or not interactive:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_F5:
				toTscn("res://data/maps/test_level_generated.tscn")
			KEY_F6:
				save_file("user://quicksave.json")
			KEY_F7:
				if load_file("user://quicksave.json") == OK:
					toTscn()
		return

	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return

	var clicked := cell_at(get_global_mouse_position())
	var clicked_unit := unit_at(clicked)

	if clicked_unit != null:
		# Clicking the selected unit deselects it; clicking another switches to it.
		select(null if clicked_unit == selected else clicked_unit)
	elif selected != null and is_walkable(clicked):
		var path := find_path(selected, clicked)
		if not path.is_empty():
			var unit := selected
			select(null)
			walk(unit, path)


## Shortest route for `unit` to `target`, going around water and other units.
func find_path(unit: LevelUnit, target: Vector2i) -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	for other in unit_nodes.values():
		if other != unit and other.state.is_alive():
			blocked.append(other.state.cell)
	for cell in blocked:
		astar.set_point_solid(cell, true)
	var path := astar.get_id_path(unit.state.cell, target)
	for cell in blocked:
		astar.set_point_solid(cell, false)
	return path


func walk(unit: LevelUnit, path: Array[Vector2i]) -> void:
	moving = true
	var tween := create_tween()
	# path[0] is the cell the unit is already standing on.
	for i in range(1, path.size()):
		tween.tween_callback(unit.play_animation.bind("walk", path[i] - path[i - 1]))
		tween.tween_property(unit, "global_position", cell_center(path[i]), STEP_TIME)
	await tween.finished
	unit.state.cell = path[-1]
	unit.state.has_moved = true
	unit.play_animation("idle")
	moving = false


func select(unit: LevelUnit) -> void:
	if selected != null:
		selected.modulate = Color.WHITE
	selected = unit
	if selected != null:
		selected.modulate = SELECTED_TINT


func unit_at(cell: Vector2i) -> LevelUnit:
	for unit in unit_nodes.values():
		if unit.state.cell == cell:
			return unit
	return null


func is_walkable(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell)


func cell_at(global_pos: Vector2) -> Vector2i:
	return Vector2i((to_local(global_pos) / Vector2(tile_size)).floor())


func cell_center(cell: Vector2i) -> Vector2:
	return to_global((Vector2(cell) + Vector2(0.5, 0.5)) * Vector2(tile_size))
