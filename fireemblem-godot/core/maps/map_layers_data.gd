class_name MapLayersData
extends RefCounted
## The stack of terrain layers that make up a map's ground.

## name -> MapLayer
var layers: Dictionary = {}
## Unimplemented for now; carried through JSON untouched.
var structures: Dictionary = {}


## Layers from bottom to top (z ascending; name breaks ties so order is stable).
func sorted_layers() -> Array[MapLayer]:
	var out: Array[MapLayer] = []
	for layer in layers.values():
		out.append(layer)
	out.sort_custom(func(a: MapLayer, b: MapLayer) -> bool:
		return a.z < b.z if a.z != b.z else a.name < b.name)
	return out


## Set (Dictionary cell -> true) of every cell any layer draws a tile on.
func drawn_cells() -> Dictionary:
	var cells := {}
	for layer in layers.values():
		for cell in layer.cell_masks():
			cells[cell] = true
	return cells


## Until per-tile terrain data exists, "something is drawn here" is walkability.
func is_drawn(cell: Vector2i) -> bool:
	for layer in layers.values():
		if CornerMask.mask_at(cell, _vert_set(layer)) != 0:
			return true
	return false


## Bounding rect of all drawn cells. Empty rect when nothing is drawn.
func bounds() -> Rect2i:
	var cells := drawn_cells()
	if cells.is_empty():
		return Rect2i()
	var rect := Rect2i(cells.keys()[0], Vector2i.ONE)
	for cell in cells:
		rect = rect.expand(cell).expand(cell + Vector2i.ONE)
	return rect


static func fromJson(d: Dictionary) -> MapLayersData:
	var data := MapLayersData.new()
	var raw_layers: Dictionary = d.get("layers", {})
	for layer_name in raw_layers:
		data.layers[layer_name] = MapLayer.fromJson(layer_name, raw_layers[layer_name])
	data.structures = d.get("structures", {}).duplicate(true)
	return data


func toJson() -> Dictionary:
	var raw_layers := {}
	for layer_name in layers:
		raw_layers[layer_name] = layers[layer_name].toJson()
	return {
		"layers": raw_layers,
		"structures": structures.duplicate(true),
	}


static func _vert_set(layer: MapLayer) -> Dictionary:
	var vert_set := {}
	for v in layer.verts:
		vert_set[v] = true
	return vert_set
