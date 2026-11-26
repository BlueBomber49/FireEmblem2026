class_name MapData
extends RefCounted
## Everything authored for a map: its terrain layers, walls, doors, forts and chests, structures, and the units placed on it.

## Tile ids walls, closed doors and forts go by in the terrain rules (TerrainData.tiles).
const WALL_TILE := "wall"
const DOOR_TILE := "door"
const FORT_TILE := "fort"

## name -> MapLayer
var layers: Dictionary = {}
## Cells with a wall; WallTiles picks how each one draws.
var walls: Array[Vector2i] = []
## Cells with a door. A cell holds one of a wall, a door or a fort.
var doors: Array[Vector2i] = []
## Doors opened in play. Play state, not authored: LevelState saves it only with
## unit state. An open door no longer overrules the terrain under it.
var opened_doors: Array[Vector2i] = []
## Cells with a fort -> which fort art it draws (WallTiles.FORT_VARIANTS).
var forts: Dictionary = {}
## cell -> id of the item inside. A chest stands on terrain, so unlike walls,
## doors and forts it doesn't change the rules terrain. The editor keeps chests
## off wall, door and fort cells.
var chests: Dictionary = {}
## Chests opened in play. Play state like opened_doors: LevelState saves it only
## with unit state.
var opened_chests: Array[Vector2i] = []
## Unimplemented for now; carried through JSON untouched.
var structures: Dictionary = {}
## id -> UnitReference
var units: Dictionary = {}

## cell -> terrain id for gameplay (see rules_terrain_at); built on first use.
var _rules_terrain: Dictionary = {}
var _rules_terrain_ready := false


## Layers from bottom to top (z ascending; name breaks ties so order is stable).
func sorted_layers() -> Array[MapLayer]:
	var out: Array[MapLayer] = []
	for layer in layers.values():
		out.append(layer)
	out.sort_custom(func(a: MapLayer, b: MapLayer) -> bool:
		return a.z < b.z if a.z != b.z else a.name < b.name)
	return out


## Set (Dictionary cell -> true) of every cell any layer, wall, door or fort draws a tile on.
func drawn_cells() -> Dictionary:
	var cells := {}
	for layer in layers.values():
		for cell in layer.cell_masks():
			cells[cell] = true
	for cell in walls:
		cells[cell] = true
	for cell in doors:
		cells[cell] = true
	for cell in forts:
		cells[cell] = true
	return cells


## Until per-tile terrain data exists, "something is drawn here" is walkability.
func is_drawn(cell: Vector2i) -> bool:
	if cell in walls or cell in doors or forts.has(cell):
		return true
	for layer in layers.values():
		if CornerMask.mask_at(cell, _vert_set(layer)) != 0:
			return true
	return false


## Terrain id of the topmost layer that draws `cell`, or "" when nothing does.
func top_terrain_at(cell: Vector2i) -> String:
	var layers_top_down := sorted_layers()
	layers_top_down.reverse()
	for layer in layers_top_down:
		if CornerMask.mask_at(cell, _vert_set(layer)) != 0:
			return layer.terrain
	return ""


## The terrain id gameplay uses for `cell` (movement, combat, terrain panel), or ""
## when the cell counts as empty (impassable). Maps paint corners, so an edge cell
## can mix terrains; the majority rule decides:
## - the highest layer covering 3 or 4 of the cell's corners wins, or covering a
##   straight half-edge (2 corners side by side) if its terrain rules count
##   half-edges (TerrainData.half_edge_counts; forest does, sea doesn't);
## - otherwise the layer covering the most corners, ties to the higher layer;
## - but a cell with fewer than 3 corners painted at all is empty.
## Walls, closed doors and forts overrule all of that, whatever terrain is under
## them. An opened door is just the terrain under it (so with none, it's empty).
## top_terrain_at is for drawing; this is for rules. Cached: call
## invalidate_terrain_cache() after changing layers.
func rules_terrain_at(cell: Vector2i) -> String:
	if not _rules_terrain_ready:
		_build_rules_terrain()
	return _rules_terrain.get(cell, "")


## Forget the cached rules terrain; the next lookup recomputes it from the layers.
func invalidate_terrain_cache() -> void:
	_rules_terrain = {}
	_rules_terrain_ready = false


func _build_rules_terrain() -> void:
	var layers_top_down := sorted_layers()
	layers_top_down.reverse()
	var vert_sets: Array[Dictionary] = []
	for layer in layers_top_down:
		vert_sets.append(_vert_set(layer))

	_rules_terrain = {}
	for cell in drawn_cells():
		var painted := 0
		var majority := ""
		var most := ""
		var most_count := 0
		for i in layers_top_down.size():
			var mask := CornerMask.mask_at(cell, vert_sets[i])
			painted |= mask
			var count := _corner_count(mask)
			if majority.is_empty() and (count >= 3 or (mask in HALF_EDGES and _counts_half_edges(layers_top_down[i].terrain))):
				majority = layers_top_down[i].terrain
			# Strictly greater keeps the higher layer on a tie (we go top-down).
			if count > most_count:
				most_count = count
				most = layers_top_down[i].terrain
		if _corner_count(painted) >= 3:
			_rules_terrain[cell] = majority if not majority.is_empty() else most
	for cell in walls:
		_rules_terrain[cell] = WALL_TILE
	for cell in doors:
		if not cell in opened_doors:
			_rules_terrain[cell] = DOOR_TILE
	for cell in forts:
		_rules_terrain[cell] = FORT_TILE
	_rules_terrain_ready = true


## Whether `cell` has a door that hasn't been opened.
func is_closed_door(cell: Vector2i) -> bool:
	return cell in doors and not cell in opened_doors


## Corner masks for one straight side of a cell (top, bottom, left, right half).
## Diagonal pairs aren't here: they look like two small nubs.
const HALF_EDGES := [
	CornerMask.TL | CornerMask.TR, CornerMask.BL | CornerMask.BR,
	CornerMask.TL | CornerMask.BL, CornerMask.TR | CornerMask.BR,
]


static func _counts_half_edges(tile_id: String) -> bool:
	var terrain := GameData.terrain_for_tile(tile_id)
	return terrain != null and terrain.half_edge_counts


static func _corner_count(mask: int) -> int:
	var count := 0
	for bit in [CornerMask.TL, CornerMask.TR, CornerMask.BL, CornerMask.BR]:
		if mask & bit:
			count += 1
	return count


## Bounding rect of all drawn cells. Empty rect when nothing is drawn.
func bounds() -> Rect2i:
	var cells := drawn_cells()
	if cells.is_empty():
		return Rect2i()
	var rect := Rect2i(cells.keys()[0], Vector2i.ONE)
	for cell in cells:
		rect = rect.expand(cell).expand(cell + Vector2i.ONE)
	return rect


static func fromJson(d: Dictionary) -> MapData:
	var data := MapData.new()
	var raw_layers: Dictionary = d.get("layers", {})
	for layer_name in raw_layers:
		data.layers[layer_name] = MapLayer.fromJson(layer_name, raw_layers[layer_name])
	data.walls = JsonUtil.vec2i_array_from_json(d.get("walls", []))
	data.doors = JsonUtil.vec2i_array_from_json(d.get("doors", []))
	var raw_forts: Variant = d.get("forts", [])
	if raw_forts is Array:
		for raw: Variant in raw_forts:
			if raw is Dictionary:
				data.forts[JsonUtil.vec2i_from_json(raw.get("cell"))] = JsonUtil.to_int(raw.get("variant"))
	var raw_chests: Variant = d.get("chests", [])
	if raw_chests is Array:
		for raw: Variant in raw_chests:
			if raw is Dictionary:
				data.chests[JsonUtil.vec2i_from_json(raw.get("cell"))] = str(raw.get("item", ""))
	data.structures = d.get("structures", {}).duplicate(true)
	var raw_units: Dictionary = d.get("units", {})
	for id in raw_units:
		data.units[id] = UnitReference.fromJson(id, raw_units[id])
	return data


func toJson() -> Dictionary:
	var raw_layers := {}
	for layer_name in layers:
		raw_layers[layer_name] = layers[layer_name].toJson()
	var raw_units := {}
	for id in units:
		raw_units[id] = units[id].toJson()
	var raw_forts := []
	for cell: Vector2i in forts:
		raw_forts.append({"cell": JsonUtil.vec2i_to_json(cell), "variant": forts[cell]})
	return {
		"layers": raw_layers,
		"walls": JsonUtil.vec2i_array_to_json(walls),
		"doors": JsonUtil.vec2i_array_to_json(doors),
		"forts": raw_forts,
		"chests": _chests_to_json(),
		"structures": structures.duplicate(true),
		"units": raw_units,
	}


## The item id in the unopened chest on `cell`, or "" when there's none.
func chest_item_at(cell: Vector2i) -> String:
	if cell in opened_chests:
		return ""
	return chests.get(cell, "")


## Why each chest can't be opened in play (an item id that doesn't exist).
func chest_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	for cell: Vector2i in chests:
		if GameData.get_item(StringName(chests[cell])) == null:
			problems.append("the chest at %s holds unknown item '%s'" % [cell, chests[cell]])
	return problems


## A list, not a dictionary keyed by cell: JSON keys can only be strings. Sorted
## by row, then column, so saving the same chests always writes the same file.
func _chests_to_json() -> Array:
	var cells: Array[Vector2i] = []
	cells.assign(chests.keys())
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	var out := []
	for cell in cells:
		out.append({"cell": JsonUtil.vec2i_to_json(cell), "item": chests[cell]})
	return out


static func _vert_set(layer: MapLayer) -> Dictionary:
	var vert_set := {}
	for v in layer.verts:
		vert_set[v] = true
	return vert_set
