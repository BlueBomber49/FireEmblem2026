class_name JsonUtil
extends RefCounted
## Helpers for the bits of JSON that don't map onto Godot types directly.
## JSON has no integers (every number parses as float) and no Vector2i.


static func to_int(value: Variant, default := 0) -> int:
	if value == null:
		return default
	return int(value)


static func vec2i_to_json(v: Vector2i) -> Array:
	return [v.x, v.y]


static func vec2i_from_json(value: Variant, default := Vector2i.ZERO) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return default


static func vec2i_array_to_json(values: Array[Vector2i]) -> Array:
	var out := []
	for v in values:
		out.append(vec2i_to_json(v))
	return out


static func vec2i_array_from_json(value: Variant) -> Array[Vector2i]:
	# A typed array can't be assigned from a parsed (untyped) array, so copy it.
	var out: Array[Vector2i] = []
	if value is Array:
		for item in value:
			out.append(vec2i_from_json(item))
	return out
