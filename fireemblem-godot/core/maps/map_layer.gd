class_name MapLayer
extends RefCounted
## One terrain layer of a map: a terrain type and the vertices it occupies.

## Key in MapLayersData.layers.
var name: String
var z: int = 0
## A TerrainType id (data/terrain/<id>.tres).
var terrain: String
## Corner vertices covered by this terrain; see CornerMask.
var verts: Array[Vector2i] = []


func _init(p_name := "", p_z := 0, p_terrain := "", p_verts: Array[Vector2i] = []) -> void:
	name = p_name
	z = p_z
	terrain = p_terrain
	verts = p_verts


## cell -> CornerMask for every tile this layer draws.
func cell_masks() -> Dictionary:
	return CornerMask.cell_masks(verts)


static func fromJson(p_name: String, d: Dictionary) -> MapLayer:
	return MapLayer.new(
		p_name,
		JsonUtil.to_int(d.get("z")),
		str(d.get("terrain", "")),
		JsonUtil.vec2i_array_from_json(d.get("verts", [])),
	)


func toJson() -> Dictionary:
	return {
		"z": z,
		"terrain": terrain,
		"verts": JsonUtil.vec2i_array_to_json(verts),
	}
