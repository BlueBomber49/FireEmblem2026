class_name Level
extends Node2D
## A playable map. Shows a LevelState (an authored level or a save) as stacked
## TileMapLayers and LevelUnits, built by rebuild(). Units stand on tile cells;
## the vertex data in MapData only decides which tiles get drawn.

## Seconds a unit takes to cross one tile.
const STEP_TIME := 0.15
const SELECTED_TINT := Color(1.0, 1.0, 0.5)

## Loaded and built in _ready when set.
@export_file("*.json") var level_path := ""
@export var tile_size := Vector2i(16, 16)
@export var camera_zoom := 2.0
## Off in the map editor, which brings its own camera and input.
@export var create_camera := true
@export var interactive := true

## The map and unit states this level shows; null until one is loaded or assigned.
var level_state: LevelState

var pathfinding: Pathfinding
var tiles: LevelTileSet
var layers_root: Node2D
var units_root: Node2D
var camera: Camera2D
## id -> LevelUnit; the views for `level_state.level_units`.
var unit_nodes: Dictionary = {}
var selected: LevelUnit = null
var moving := false


func _ready() -> void:
	if level_state == null:
		if level_path.is_empty():
			return
		level_state = LevelState.load_file(level_path)
		if level_state == null:
			return
	rebuild()


# --- Scene construction ----------------------------------------------------


## Rebuilds the layer, unit and camera nodes from `level_state`.
func rebuild() -> void:
	clear_scene()
	var max_z := _build_layers()
	_spawn_units(max_z + 1)
	pathfinding = Pathfinding.new(level_state)
	if create_camera:
		_setup_camera()


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
	for layer in level_state.map_data.layerData.sorted_layers():
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
	var layer: MapLayer = level_state.map_data.layerData.layers.get(layer_name)
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


## Rebuilds just the unit nodes from `level_state` (used by the map editor).
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

	for id in level_state.level_units:
		var state: LevelUnitState = level_state.level_units[id]
		if not state.is_alive():
			continue
		var unit := LevelUnit.create(state.unit_ref, state)
		units_root.add_child(unit)
		unit.global_position = cell_center(state.cell)
		unit_nodes[id] = unit


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	var bounds := level_state.map_data.layerData.bounds()
	camera.position = (Vector2(bounds.position) + Vector2(bounds.size) / 2.0) * Vector2(tile_size)
	add_child(camera)
	camera.make_current()


# --- Input and movement ----------------------------------------------------

##Tony: This function will need to change, assuming we're going to be using the keyboard
##for map and menu navigation
func _unhandled_input(event: InputEvent) -> void:
	if moving or not interactive:
		return
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return

	var clicked := cell_at(get_global_mouse_position())
	var clicked_unit := unit_at(clicked)

	if clicked_unit != null:
		# Clicking the selected unit deselects it; clicking another switches to it.
		select(null if clicked_unit == selected else clicked_unit)
	elif selected != null and pathfinding.is_walkable(clicked):
		var path := pathfinding.find_path(selected.state, clicked)
		if not path.is_empty():
			var unit := selected
			select(null)
			walk(unit, path)


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


func cell_at(global_pos: Vector2) -> Vector2i:
	return Vector2i((to_local(global_pos) / Vector2(tile_size)).floor())


func cell_center(cell: Vector2i) -> Vector2:
	return to_global((Vector2(cell) + Vector2(0.5, 0.5)) * Vector2(tile_size))
