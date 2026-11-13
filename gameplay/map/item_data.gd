class_name ItemData
extends Resource
## Base for anything that can go in an inventory.
##
## Save each item as its own .tres file. Units reference items by file, so
## an item created inside another resource can't be saved with a unit.

@export var id: StringName
@export var display_name := ""


## Returns a list of problems with this item; empty when it's valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Item has no id.")
	return errors
