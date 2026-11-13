class_name UnitData
extends Resource
## The definition of a character or generic unit: who they are, not their current state.
## A Unit is the runtime copy built from this.

const MIN_LEVEL := 1
const MAX_LEVEL := 20

@export var id: StringName
@export var display_name := ""
@export var class_data: ClassData
@export_range(1, 20) var level := 1
## The character's TOTAL starting stats, as character pages list them.
## Leave empty for generic units, which use their class's base stats.
## `movement` is ignored: movement always comes from the class.
@export var starting_stats: Stats
## Personal growth rates, in percent. Leave empty to use the class's growths.
@export var growths: Stats
## Starting items. Each must be a known item id (resources/weapons or consumables),
## because saves store items by id.
@export var starting_items: Array[ItemData] = []
## Sprite sheet path with a {color} placeholder, overriding the class's default.
## Empty uses the class's sprite.
@export var sprite := ""


## Returns a list of problems with this definition; empty when it's valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Unit has no id.")
	if class_data == null:
		errors.append("%s: class_data is missing." % id)
	if level < MIN_LEVEL or level > MAX_LEVEL:
		errors.append("%s: level must be %d-%d." % [id, MIN_LEVEL, MAX_LEVEL])
	if starting_stats != null:
		# HP and Con are never 0 for a real unit, so 0 means the stats were only partly filled in.
		if starting_stats.hp <= 0:
			errors.append("%s: starting_stats.hp is 0; fill in the full stat line." % id)
		if starting_stats.constitution <= 0:
			errors.append("%s: starting_stats.constitution is 0; fill in the full stat line." % id)
	if starting_items.size() > Inventory.DEFAULT_CAPACITY:
		errors.append("%s: %d starting items; the limit is %d." % [id, starting_items.size(), Inventory.DEFAULT_CAPACITY])
	for item in starting_items:
		if item == null:
			errors.append("%s: a starting item slot is empty." % id)
		elif GameData.get_item(item.id) == null:
			errors.append("%s: starting item '%s' isn't a known item id." % [id, item.id])
	return errors
