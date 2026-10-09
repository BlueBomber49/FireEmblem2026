class_name UnitReference
extends RefCounted
## A unit as authored in a map: who it is, its stats, and where it starts.
## Runtime changes (HP, position) live in LevelUnitState, not here.

enum Faction { PLAYER, ENEMY, ALLY }

const FACTION_NAMES := {
	Faction.PLAYER: "player",
	Faction.ENEMY: "enemy",
	Faction.ALLY: "ally",
}

## GBA-style stat block. "hp" is max HP.
const STAT_KEYS: Array[StringName] = [
	&"hp", &"str", &"mag", &"skl", &"spd", &"lck", &"def", &"res", &"con", &"mov",
]

## Key in MapData.units.
var id: String
var name: String
## "class" is a GDScript keyword.
var unit_class: String
var faction: Faction = Faction.PLAYER
var level: int = 1
## StringName (one of STAT_KEYS) -> int. Missing stats read as 0.
var stats: Dictionary = {}
## Full res:// path to the sprite sheet; sheet filenames are irregular so it isn't derived.
var sprite_sheet: String
var start_cell := Vector2i.ZERO
var facing := Vector2i.DOWN


func stat(key: StringName) -> int:
	return stats.get(key, 0)


static func faction_from_string(s: String) -> Faction:
	for f in FACTION_NAMES:
		if FACTION_NAMES[f] == s:
			return f
	push_warning("Unknown faction '%s', defaulting to player" % s)
	return Faction.PLAYER


static func fromJson(p_id: String, d: Dictionary) -> UnitReference:
	var ref := UnitReference.new()
	ref.id = p_id
	ref.name = str(d.get("name", p_id))
	ref.unit_class = str(d.get("unit_class", ""))
	ref.faction = faction_from_string(str(d.get("faction", "player")))
	ref.level = JsonUtil.to_int(d.get("level"), 1)
	var raw_stats: Dictionary = d.get("stats", {})
	for key in STAT_KEYS:
		if raw_stats.has(key):
			ref.stats[key] = JsonUtil.to_int(raw_stats[key])
	ref.sprite_sheet = str(d.get("sprite_sheet", ""))
	ref.start_cell = JsonUtil.vec2i_from_json(d.get("start_cell"))
	ref.facing = JsonUtil.vec2i_from_json(d.get("facing"), Vector2i.DOWN)
	return ref


func toJson() -> Dictionary:
	var raw_stats := {}
	for key in STAT_KEYS:
		if stats.has(key):
			raw_stats[String(key)] = stats[key]
	return {
		"name": name,
		"unit_class": unit_class,
		"faction": FACTION_NAMES[faction],
		"level": level,
		"stats": raw_stats,
		"sprite_sheet": sprite_sheet,
		"start_cell": JsonUtil.vec2i_to_json(start_cell),
		"facing": JsonUtil.vec2i_to_json(facing),
	}
