class_name GameData
extends RefCounted
## The game's data: classes, weapons, consumables, terrain rules and named
## characters, read from JSON files under res://resources and looked up by id.
##
## Data files are hand-edited, so loading is strict: an unknown key, a wrong type,
## a bad enum name or an id that doesn't match the file name is reported (with the
## file) and that file is skipped. Nothing crashes. load_errors() lists the
## problems; tests assert it's empty for the real data.
## See docs/data-format.md for each file's fields.

const DEFAULT_ROOT := "res://resources"
## Every warning GameData pushes starts with this, so tests can recognize them.
const WARNING_PREFIX := "Game data:"
## Terrain rules used for a drawn tile no terrain file claims.
const FALLBACK_TERRAIN := &"plains"

static var _root := DEFAULT_ROOT
static var _loaded := false
## StringName id -> ClassData
static var _classes: Dictionary = {}
## StringName id -> ItemData (weapons and consumables share one id space)
static var _items: Dictionary = {}
## StringName id -> TerrainData
static var _terrain: Dictionary = {}
## StringName id -> UnitData (named characters)
static var _characters: Dictionary = {}
## tile id (a TerrainType id such as "trees") -> TerrainData
static var _tile_terrain: Dictionary = {}
## Unknown tile ids already warned about, so each warns once.
static var _warned_tiles: Dictionary = {}
static var _errors := PackedStringArray()


## (Re)reads every data file under `root`. Tests point it at a fixture folder and
## must call load_all() afterwards to get the real data back. (Not "reload": that
## name is Script.reload, which a call on the class would hit instead.)
static func load_all(root := DEFAULT_ROOT) -> void:
	_root = root
	# Marked loaded first: validating a character looks items up through GameData,
	# which must not start a second load.
	_loaded = true
	_classes = {}
	_items = {}
	_terrain = {}
	_characters = {}
	_tile_terrain = {}
	_warned_tiles = {}
	_errors = PackedStringArray()
	_load_dir("classes", _classes)
	_load_dir("weapons", _items)
	_load_dir("consumables", _items)
	_load_dir("terrain_data", _terrain)
	# Characters last: they refer to classes and items by id.
	_load_dir("characters", _characters)
	_map_tiles()
	if not _errors.is_empty():
		push_warning("%s %d problem(s) loading %s:\n%s" % [WARNING_PREFIX, _errors.size(), root, "\n".join(_errors)])


## Problems found by the last load, one line each, naming the file.
static func load_errors() -> PackedStringArray:
	_ensure_loaded()
	return _errors


static func get_class_data(id: StringName) -> ClassData:
	_ensure_loaded()
	return _classes.get(id)


## A weapon or consumable by id, or null.
static func get_item(id: StringName) -> ItemData:
	_ensure_loaded()
	return _items.get(id)


## A named character's definition, shared by every placement of them. Units copy
## what they need, so don't change it.
static func get_character(id: StringName) -> UnitData:
	_ensure_loaded()
	return _characters.get(id)


static func get_terrain(id: StringName) -> TerrainData:
	_ensure_loaded()
	return _terrain.get(id)


## The terrain rules for a drawn tile id (MapData.rules_terrain_at). Null for ""
## (nothing drawn, impassable). A tile no terrain file claims falls back to
## plains, with one warning per tile id.
static func terrain_for_tile(tile_id: String) -> TerrainData:
	_ensure_loaded()
	if tile_id.is_empty():
		return null
	if _tile_terrain.has(tile_id):
		return _tile_terrain[tile_id]
	if not _warned_tiles.has(tile_id):
		_warned_tiles[tile_id] = true
		push_warning("%s no terrain rules list tile '%s'; treating it as %s." % [WARNING_PREFIX, tile_id, FALLBACK_TERRAIN])
	return _terrain.get(FALLBACK_TERRAIN)


static func all_class_ids() -> Array[StringName]:
	_ensure_loaded()  # before reading the table: loading replaces it
	return _sorted_ids(_classes)


static func all_item_ids() -> Array[StringName]:
	_ensure_loaded()  # before reading the table: loading replaces it
	return _sorted_ids(_items)


static func all_terrain_ids() -> Array[StringName]:
	_ensure_loaded()  # before reading the table: loading replaces it
	return _sorted_ids(_terrain)


static func all_character_ids() -> Array[StringName]:
	_ensure_loaded()  # before reading the table: loading replaces it
	return _sorted_ids(_characters)


# --- Loading -----------------------------------------------------------------


static func _ensure_loaded() -> void:
	if not _loaded:
		load_all(_root)


## The table's ids, sorted. Callers load first: loading swaps in new tables, so
## a table passed in before loading would be the old, empty one.
static func _sorted_ids(table: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(table.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## Builds one resource per JSON file in `dir` and stores the valid ones in `table` by id.
static func _load_dir(dir: String, table: Dictionary) -> void:
	var dir_path := _root.path_join(dir)
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var files := Array(DirAccess.get_files_at(dir_path))
	files.sort()
	for file: String in files:
		if not file.ends_with(".json"):
			continue
		var reader := _Reader.new(dir_path.path_join(file))
		var resource: Resource = null
		if reader.parse():
			resource = _build(dir, reader)
		if resource != null:
			var id: StringName = resource.get("id")
			if String(id) != file.get_basename():
				reader.error("id '%s' doesn't match the file name '%s'." % [id, file.get_basename()])
			elif table.has(id):
				reader.error("id '%s' is already used by another file." % id)
			for problem in resource.call("validate"):
				reader.error(problem)
		if reader.errors.is_empty() and resource != null:
			table[resource.get("id")] = resource
		_errors.append_array(reader.errors)


static func _map_tiles() -> void:
	for terrain: TerrainData in _terrain.values():
		for tile in terrain.tiles:
			if _tile_terrain.has(tile):
				_errors.append("terrain_data: tile '%s' is listed by both '%s' and '%s'." % [tile, _tile_terrain[tile].id, terrain.id])
			else:
				_tile_terrain[tile] = terrain


static func _build(dir: String, r: _Reader) -> Resource:
	match dir:
		"classes":
			return _build_class(r)
		"weapons":
			return _build_weapon(r)
		"consumables":
			return _build_consumable(r)
		"terrain_data":
			return _build_terrain(r)
		"characters":
			return _build_character(r)
	return null


static func _build_class(r: _Reader) -> ClassData:
	r.allow_keys(["id", "name", "movement_type", "weapon_types", "base_stats", "growths", "caps",
			"crit_bonus", "class_power", "promoted", "tags", "sprite"])
	var c := ClassData.new()
	c.id = StringName(r.string("id"))
	c.display_name = r.string("name")
	c.movement_type = r.movement_type("movement_type")
	var weapon_types: Array[Enums.WeaponType] = []
	for type_name in r.string_list("weapon_types"):
		var type := Enums.weapon_type_from_name(type_name)
		if type < 0:
			r.error("'%s' in weapon_types isn't a weapon type." % type_name)
		else:
			weapon_types.append(type)
	c.usable_weapon_types = weapon_types
	c.base_stats = r.stats("base_stats", true)
	c.growths = r.stats("growths", false)
	c.caps = r.stats("caps", true)
	c.crit_bonus = r.integer("crit_bonus", false, 0)
	c.class_power = r.integer("class_power", false, 3)
	c.promoted = r.boolean("promoted", false)
	var tags: Array[StringName] = []
	for tag in r.string_list("tags", false):
		tags.append(StringName(tag))
	c.tags = tags
	c.sprite = r.string("sprite")
	return c


static func _build_weapon(r: _Reader) -> WeaponData:
	r.allow_keys(["id", "name", "type", "might", "hit", "crit", "weight", "min_range", "max_range",
			"effective_against"])
	var w := WeaponData.new()
	w.id = StringName(r.string("id"))
	w.display_name = r.string("name")
	var type_name := r.string("type")
	var type := Enums.weapon_type_from_name(type_name)
	if type < 0:
		r.error("type '%s' isn't a weapon type." % type_name)
	else:
		w.weapon_type = type
	w.might = r.integer("might")
	w.hit = r.integer("hit")
	w.crit = r.integer("crit")
	w.weight = r.integer("weight")
	w.min_range = r.integer("min_range")
	w.max_range = r.integer("max_range")
	var effective: Array[StringName] = []
	for tag in r.string_list("effective_against", false):
		effective.append(StringName(tag))
	w.effective_against = effective
	return w


static func _build_consumable(r: _Reader) -> ConsumableData:
	r.allow_keys(["id", "name", "max_uses", "heal"])
	var c := ConsumableData.new()
	c.id = StringName(r.string("id"))
	c.display_name = r.string("name")
	c.max_uses = r.integer("max_uses")
	# "heal" is a number of HP, or "full".
	if r.data.get("heal") is String and r.data["heal"] == "full":
		c.heal_amount = ConsumableData.FULL_HEAL
	else:
		c.heal_amount = r.integer("heal")
	return c


static func _build_terrain(r: _Reader) -> TerrainData:
	r.allow_keys(["id", "name", "defense", "avoid", "heal_percent", "move_costs", "tiles", "half_edge_counts"])
	var t := TerrainData.new()
	t.id = StringName(r.string("id"))
	t.display_name = r.string("name")
	t.defense = r.integer("defense", false)
	t.avoid = r.integer("avoid", false)
	t.heal_percent = r.integer("heal_percent", false)
	var costs := r.dict("move_costs")
	for group_name in costs:
		var group := Enums.movement_type_from_name(str(group_name))
		if group < 0:
			r.error("move_costs: '%s' isn't a movement group." % group_name)
			continue
		var cost: Variant = costs[group_name]
		if not _is_whole_number(cost):
			r.error("move_costs.%s must be a whole number (-1 for impassable)." % group_name)
			continue
		t.move_costs[group] = int(cost)
	t.tiles = PackedStringArray(r.string_list("tiles", false))
	t.half_edge_counts = r.boolean("half_edge_counts", false)
	return t


static func _build_character(r: _Reader) -> UnitData:
	r.allow_keys(["id", "name", "class", "level", "stats", "growths", "items", "sprite"])
	var u := UnitData.new()
	u.id = StringName(r.string("id"))
	u.display_name = r.string("name")
	var class_id := r.string("class")
	u.class_data = _classes.get(StringName(class_id))
	if u.class_data == null and not class_id.is_empty():
		r.error("class '%s' isn't a known class id." % class_id)
	u.level = r.integer("level", false, 1)
	# Totals, as character pages list them. Movement comes from the class, so it may be left out.
	u.starting_stats = r.stats("stats", true, [&"movement"])
	if r.data.has("growths"):
		u.growths = r.stats("growths", false)
	var items: Array[ItemData] = []
	for item_id in r.string_list("items", false):
		var item: ItemData = _items.get(StringName(item_id))
		if item == null:
			r.error("item '%s' isn't a known item id." % item_id)
		else:
			items.append(item)
	u.starting_items = items
	u.sprite = r.string("sprite", false)
	return u


static func _is_whole_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and value == floorf(value))


## Reads one JSON data file and collects every problem, prefixed with the file name.
class _Reader:
	extends RefCounted

	var path: String
	var data: Dictionary = {}
	var errors := PackedStringArray()


	func _init(p_path: String) -> void:
		path = p_path


	func error(message: String) -> void:
		errors.append("%s: %s" % [path.get_file(), message])


	## Reads and parses the file into `data`. False (with an error) if that fails.
	func parse() -> bool:
		if not FileAccess.file_exists(path):
			error("file not found.")
			return false
		var json := JSON.new()
		# JSON.new().parse reports bad syntax without raising an engine error,
		# unlike JSON.parse_string.
		if json.parse(FileAccess.get_file_as_string(path)) != OK:
			error("line %d: %s" % [json.get_error_line(), json.get_error_message()])
			return false
		if not json.data is Dictionary:
			error("the top level must be a JSON object { ... }.")
			return false
		data = json.data
		return true


	## Reports every key not in `allowed` (catches typos like "mght").
	func allow_keys(allowed: Array) -> void:
		for key in data:
			if not key in allowed:
				error("unknown key '%s'." % key)


	func string(key: String, required := true) -> String:
		if not data.has(key):
			if required:
				error("'%s' is missing." % key)
			return ""
		if not data[key] is String:
			error("'%s' must be text." % key)
			return ""
		return data[key]


	## A whole number. Missing is an error when `required`, otherwise `default`.
	func integer(key: String, required := true, default := 0) -> int:
		if not data.has(key):
			if required:
				error("'%s' is missing." % key)
			return default
		if not GameData._is_whole_number(data[key]):
			error("'%s' must be a whole number." % key)
			return default
		return int(data[key])


	func boolean(key: String, default := false) -> bool:
		if not data.has(key):
			return default
		if not data[key] is bool:
			error("'%s' must be true or false." % key)
			return default
		return data[key]


	func dict(key: String) -> Dictionary:
		if not data.get(key) is Dictionary:
			error("'%s' must be an object { ... }." % key)
			return {}
		return data[key]


	func string_list(key: String, required := true) -> Array[String]:
		var out: Array[String] = []
		if not data.has(key):
			if required:
				error("'%s' is missing." % key)
			return out
		if not data[key] is Array:
			error("'%s' must be a list [ ... ]." % key)
			return out
		for item in data[key]:
			if item is String:
				out.append(item)
			else:
				error("'%s' must only contain text." % key)
		return out


	func movement_type(key: String) -> Enums.MovementType:
		var type_name := string(key)
		var type := Enums.movement_type_from_name(type_name)
		if type < 0:
			if not type_name.is_empty():
				error("%s '%s' isn't a movement group." % [key, type_name])
			return Enums.MovementType.FOOT
		return type


	## A stat block. With `all_required`, every stat except those in `optional`
	## must be listed; otherwise missing stats are 0. Unknown stat names are always
	## reported.
	func stats(key: String, all_required: bool, optional: Array = []) -> Stats:
		var result := Stats.new()
		if not data.has(key):
			if all_required:
				error("'%s' is missing." % key)
			return result
		if not data[key] is Dictionary:
			error("'%s' must be an object { ... }." % key)
			return result
		var block: Dictionary = data[key]
		for stat_name in block:
			if not StringName(stat_name) in Stats.FIELDS:
				error("%s: unknown stat '%s'." % [key, stat_name])
		for field in Stats.FIELDS:
			if not block.has(String(field)):
				if all_required and not field in optional:
					error("%s: '%s' is missing." % [key, field])
				continue
			if not GameData._is_whole_number(block[String(field)]):
				error("%s.%s must be a whole number." % [key, field])
				continue
			result.set(field, int(block[String(field)]))
		return result
