class_name SaveSlots
extends RefCounted
## The campaign's save files: one JSON file per slot, holding the next chapter to
## play and the roster (character id -> Unit.save_state()).
##
## { "version": 1, "chapter_id": "...", "chapter_index": 0, "saved_at": "...",
##   "roster": { ... } }

const COUNT := 3
const VERSION := 1

## Where the files go. Tests point this at their own folder, so they never touch
## the player's real saves.
static var dir := "user://saves"


static func path(slot: int) -> String:
	return "%s/slot_%d.json" % [dir, slot]


static func write(slot: int, chapter_id: StringName, chapter_index: int, roster: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Save: can't write %s (%s)." % [path(slot), error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"version": VERSION,
		"chapter_id": String(chapter_id),
		"chapter_index": chapter_index,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"roster": roster,
	}, "\t"))
	return OK


## The slot's contents, or {} when it's empty, unreadable, or not a save. JSON
## reads numbers back as floats; chapter_index comes back as an int.
static func read(slot: int) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	# A JSON instance reports bad text quietly; JSON.parse_string logs an engine error.
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(FileAccess.get_file_as_string(path(slot))) == OK else null
	if not parsed is Dictionary:
		push_warning("Save: %s isn't a save file; treating it as empty." % path(slot))
		return {}
	var d: Dictionary = parsed
	if not d.get("roster") is Dictionary or not (d.get("chapter_index") is float or d.get("chapter_index") is int):
		push_warning("Save: %s is missing its chapter or roster; treating it as empty." % path(slot))
		return {}
	d["chapter_index"] = int(d["chapter_index"])
	d["chapter_id"] = str(d.get("chapter_id", ""))
	return d


static func has_any() -> bool:
	for slot in COUNT:
		if not read(slot).is_empty():
			return true
	return false


## What a file list shows, one entry per slot: {} for an empty slot, otherwise
## its chapter_id, chapter_index and saved_at.
static func summaries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in COUNT:
		var d := read(slot)
		out.append({} if d.is_empty() else {"chapter_id": d["chapter_id"],
				"chapter_index": d["chapter_index"], "saved_at": str(d.get("saved_at", ""))})
	return out
