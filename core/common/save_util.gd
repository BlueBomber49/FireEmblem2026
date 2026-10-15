class_name SaveUtil
## Type-checked reads from save data, which may be hand-edited, corrupted or old.
## Every read falls back (with a warning) instead of erroring on the wrong type.


## The int at `key`, or `fallback` when it's missing or not a number.
## JSON numbers come back as floats, so floats are accepted.
static func read_int(d: Dictionary, key: String, fallback: int) -> int:
	if not d.has(key):
		push_warning("Save data: '%s' is missing; using %d." % [key, fallback])
		return fallback
	var value: Variant = d[key]
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	push_warning("Save data: '%s' isn't a number; using %d." % [key, fallback])
	return fallback


## The Dictionary at `key`, or an empty one when it's missing or another type.
static func read_dict(d: Dictionary, key: String) -> Dictionary:
	var value: Variant = d.get(key)
	if value is Dictionary:
		return value
	push_warning("Save data: '%s' isn't a dictionary." % key)
	return {}


## The Array at `key`, or an empty one when it's missing or another type.
static func read_array(d: Dictionary, key: String) -> Array:
	var value: Variant = d.get(key)
	if value is Array:
		return value
	push_warning("Save data: '%s' isn't a list." % key)
	return []
