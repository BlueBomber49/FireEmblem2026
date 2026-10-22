class_name UnitReference
extends RefCounted
## A unit placed on a map, as authored: where it starts, which side it's on, and
## who it is. Either a named character ("character": "lyn", defined in
## resources/characters/lyn.json), or a generic unit defined right here: a class,
## a level, items, and optional per-stat overrides of the class's base stats.
## Runtime changes (position, HP, items) live in LevelUnitState and its Unit.
##
## A placement that can't be built (a typo'd character id, an unknown class) is
## kept exactly as written so saving never loses it; it's only skipped in play.

enum Faction { PLAYER, ENEMY, ALLY }

const FACTION_NAMES := {
	Faction.PLAYER: "player",
	Faction.ENEMY: "enemy",
	Faction.ALLY: "ally",
}
## Faction -> the colour filled into a sprite template's {color}.
const FACTION_COLORS := {
	Faction.PLAYER: "Blue",
	Faction.ENEMY: "Red",
	Faction.ALLY: "Green",
}
## Keys this class reads; anything else in the JSON is carried through untouched.
const KNOWN_KEYS := ["character", "class", "name", "level", "items", "stats", "faction",
	"sprite_sheet", "start_cell", "facing"]


static func are_hostile(ref_a: UnitReference, ref_b: UnitReference) -> bool:
	var a_is_enemy: bool = ref_a.faction == UnitReference.Faction.ENEMY
	var b_is_enemy: bool = ref_b.faction == UnitReference.Faction.ENEMY
	return a_is_enemy != b_is_enemy


## Key in MapData.units.
var id: String
var faction: Faction = Faction.PLAYER
var start_cell := Vector2i.ZERO
var facing := Vector2i.DOWN
## Full res:// path to the sprite sheet. Empty uses the character's or class's
## default sprite in this faction's colour (see resolved_sprite).
var sprite_sheet: String

## A named character's id (resources/characters/<id>.json), or "" for a generic unit.
var character_id: String

# Generic units only; ignored for characters.
var class_id: String
## Display name; empty uses the class's name.
var name: String
var level: int = 1
## Item ids, in inventory order.
var items: Array[String] = []
## Stats.FIELDS name -> value, replacing the class's base stat. Usually partial.
var stat_overrides: Dictionary = {}

## Keys from the JSON this class doesn't read, written back unchanged.
var _extra: Dictionary = {}


func is_character() -> bool:
	return not character_id.is_empty()


## The unit's name as shown in play, for either kind of placement.
func display_name() -> String:
	var data := build_unit_data()
	if data != null:
		return data.display_name
	return name if not name.is_empty() else id


## Why this placement can't be built into a unit, or "" when it can.
func build_problem() -> String:
	if is_character():
		if GameData.get_character(StringName(character_id)) == null:
			return "unit '%s': no character '%s'." % [id, character_id]
		return ""
	if class_id.is_empty():
		return "unit '%s': needs a \"character\" or a \"class\"." % id
	var klass := GameData.get_class_data(StringName(class_id))
	if klass == null:
		return "unit '%s': no class '%s'." % [id, class_id]
	# Same rule as UnitData.validate(): 0 HP would spawn the unit already dead.
	for field in ["hp", "constitution"]:
		var value: int = stat_overrides.get(field, klass.base_stats.get(field))
		if value <= 0:
			return "unit '%s': %s must be above 0." % [id, field]
	return ""


## The definition a Unit is built from, or null when build_problem() isn't empty.
## Characters share their GameData definition; a generic unit gets its own, with
## the class's base stats plus any overrides. Unknown item ids are skipped with a
## warning.
func build_unit_data() -> UnitData:
	if not build_problem().is_empty():
		return null
	if is_character():
		return GameData.get_character(StringName(character_id))
	var klass := GameData.get_class_data(StringName(class_id))
	var data := UnitData.new()
	data.id = StringName(id)
	data.display_name = name if not name.is_empty() else klass.display_name
	data.class_data = klass
	data.level = clampi(level, UnitData.MIN_LEVEL, UnitData.MAX_LEVEL)
	var base := klass.base_stats.copy()
	for field in stat_overrides:
		base.set(field, stat_overrides[field])
	data.starting_stats = base
	var starting: Array[ItemData] = []
	for item_id in items:
		var item := GameData.get_item(StringName(item_id))
		if item == null:
			push_warning("Level: unit '%s': no item '%s'; skipping it." % [id, item_id])
		else:
			starting.append(item)
	data.starting_items = starting
	return data


## The sprite sheet to draw: sprite_sheet if set, otherwise the character's or
## class's sprite template in this faction's colour. Never scans folders, so it
## works in exported builds.
func resolved_sprite() -> String:
	if not sprite_sheet.is_empty():
		return sprite_sheet
	return sprite_for(default_sprite_template(), faction)


## The character's sprite template if it has one, otherwise its class's; "" when
## the placement can't be built.
func default_sprite_template() -> String:
	var data := build_unit_data()
	if data == null:
		return ""
	if not data.sprite.is_empty():
		return data.sprite
	return data.class_data.sprite


## Fills a sprite template's {color} for `p_faction`. Shared by the game and the
## map editor so both always pick the same sheet.
static func sprite_for(template: String, p_faction: Faction) -> String:
	return template.replace("{color}", FACTION_COLORS[p_faction])


static func faction_from_string(s: String) -> Faction:
	for f in FACTION_NAMES:
		if FACTION_NAMES[f] == s:
			return f
	push_warning("Unknown faction '%s', defaulting to player" % s)
	return Faction.PLAYER


static func fromJson(p_id: String, d: Dictionary) -> UnitReference:
	var ref := UnitReference.new()
	ref.id = p_id
	ref.character_id = str(d.get("character", ""))
	ref.class_id = str(d.get("class", ""))
	ref.name = str(d.get("name", ""))
	ref.level = JsonUtil.to_int(d.get("level"), 1)
	var raw_items: Variant = d.get("items", [])
	if raw_items is Array:
		for item in raw_items:
			ref.items.append(str(item))
	var raw_stats: Variant = d.get("stats", {})
	if raw_stats is Dictionary:
		for key in raw_stats:
			if StringName(key) in Stats.FIELDS:
				ref.stat_overrides[String(key)] = JsonUtil.to_int(raw_stats[key])
			else:
				push_warning("Level: unit '%s': unknown stat '%s'; ignoring it." % [p_id, key])
	ref.faction = faction_from_string(str(d.get("faction", "player")))
	ref.sprite_sheet = str(d.get("sprite_sheet", ""))
	ref.start_cell = JsonUtil.vec2i_from_json(d.get("start_cell"))
	ref.facing = JsonUtil.vec2i_from_json(d.get("facing"), Vector2i.DOWN)
	for key in d:
		if not key in KNOWN_KEYS:
			ref._extra[key] = d[key]
	return ref


func toJson() -> Dictionary:
	var d := {}
	if is_character():
		d["character"] = character_id
	else:
		d["class"] = class_id
		if not name.is_empty():
			d["name"] = name
		d["level"] = level
		d["items"] = items.duplicate()
		if not stat_overrides.is_empty():
			d["stats"] = stat_overrides.duplicate()
	d["faction"] = FACTION_NAMES[faction]
	if not sprite_sheet.is_empty():
		d["sprite_sheet"] = sprite_sheet
	d["start_cell"] = JsonUtil.vec2i_to_json(start_cell)
	d["facing"] = JsonUtil.vec2i_to_json(facing)
	d.merge(_extra.duplicate(true))
	return d
