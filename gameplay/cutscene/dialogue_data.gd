class_name DialogueData
extends RefCounted
## One conversation, read from resources/dialogue/<id>.json: the lines in order,
## each with who says it and which side of the screen they stand on.
##
## Loading is strict like GameData: unknown keys, wrong types and unknown
## speakers are listed in `errors` (naming the file) and the bad line is dropped.
## Nothing crashes. See docs/data-format.md.

const DEFAULT_DIR := "res://resources/dialogue"
const SIDES: Array[StringName] = [&"left", &"back_left", &"right", &"back_right"]


class Line:
	extends RefCounted
	## A character id, or empty for narration (no portrait, no name).
	var speaker: StringName
	var side: StringName = &"left"
	var text: String
	var face_outside: bool = false


	## The speaker's name from their character file, or "" for narration.
	func display_name() -> String:
		if speaker.is_empty():
			return ""
		var data := GameData.get_character(speaker)
		return data.display_name if data != null else String(speaker)


var id: StringName
## A texture path, or empty for a plain background.
var background := ""
var lines: Array[Line] = []
## Problems found while reading, one line each, naming the file.
var errors := PackedStringArray()


static func path_for(dialogue_id: StringName) -> String:
	return DEFAULT_DIR.path_join("%s.json" % dialogue_id)


## Reads a dialogue file. Always returns a DialogueData; check `errors`.
static func read(path: String) -> DialogueData:
	var d := DialogueData.new()
	var r := GameData._Reader.new(path)
	if r.parse():
		r.allow_keys(["id", "background", "lines"])
		d.id = StringName(r.string("id"))
		if String(d.id) != path.get_file().get_basename():
			r.error("id '%s' doesn't match the file name." % d.id)
		d.background = r.string("background", false)
		if not d.background.is_empty() and not ResourceLoader.exists(d.background):
			r.error("background '%s' doesn't exist." % d.background)
		d._read_lines(r)
	d.errors = r.errors
	if not d.errors.is_empty():
		push_warning("Dialogue: %d problem(s):\n%s" % [d.errors.size(), "\n".join(d.errors)])
	return d


func _read_lines(r: GameData._Reader) -> void:
	var raw: Variant = r.data.get("lines")
	if not raw is Array or raw.is_empty():
		r.error("'lines' must be a non-empty list [ ... ].")
		return
	for i in raw.size():
		if not raw[i] is Dictionary:
			r.error("lines[%d] must be an object { ... }." % i)
			continue
		# A reader per line, so its errors say which line ("x.json lines[2]: ...").
		var lr := GameData._Reader.new("%s lines[%d]" % [r.path, i])
		lr.data = raw[i]
		lr.allow_keys(["speaker", "side", "text", "face_outside"])
		var line := Line.new()
		line.speaker = StringName(lr.string("speaker", false))
		if not line.speaker.is_empty() and GameData.get_character(line.speaker) == null:
			lr.error("speaker '%s' isn't a known character id." % line.speaker)
		line.side = StringName(lr.string("side", false))
		if line.side.is_empty():
			line.side = &"left"
		elif not line.side in SIDES:
			lr.error("side must be 'left', 'right', 'back_left', or 'back_right', not '%s'." % line.side)
		line.text = lr.string("text")
		line.face_outside = lr.boolean("face_outside", false)
		if lr.errors.is_empty():
			lines.append(line)
		r.errors.append_array(lr.errors)
