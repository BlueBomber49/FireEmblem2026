class_name Campaign
extends RefCounted
## The order the game plays in, read from resources/campaign.json: a list of
## chapters, each an optional intro cutscene, a level and an optional outro.
##
## Only GameFlow follows it. Cutscenes and battles don't know what comes after
## them, so reordering chapters is a data change. See docs/data-format.md.

const DEFAULT_PATH := "res://resources/campaign.json"
const LEVEL_DIR := "res://resources/levels"


class Chapter:
	extends RefCounted
	var id: StringName
	## Dialogue ids; empty means no cutscene there.
	var intro: StringName
	var outro: StringName
	## A level id: resources/levels/<level>.json.
	var level: StringName


	func level_path() -> String:
		return LEVEL_DIR.path_join("%s.json" % level)


var chapters: Array[Chapter] = []
## Problems found while reading, one line each.
var errors := PackedStringArray()


## Reads the campaign. Always returns a Campaign; check `errors`. Chapters with
## problems are dropped, so the rest still play.
static func read(path := DEFAULT_PATH) -> Campaign:
	var c := Campaign.new()
	var r := GameData._Reader.new(path)
	if r.parse():
		r.allow_keys(["chapters"])
		c._read_chapters(r)
	c.errors = r.errors
	if not c.errors.is_empty():
		push_warning("Campaign: %d problem(s):\n%s" % [c.errors.size(), "\n".join(c.errors)])
	return c


func _read_chapters(r: GameData._Reader) -> void:
	var raw: Variant = r.data.get("chapters")
	if not raw is Array or raw.is_empty():
		r.error("'chapters' must be a non-empty list [ ... ].")
		return
	var seen := {}
	for i in raw.size():
		if not raw[i] is Dictionary:
			r.error("chapters[%d] must be an object { ... }." % i)
			continue
		var cr := GameData._Reader.new("%s chapters[%d]" % [r.path, i])
		cr.data = raw[i]
		cr.allow_keys(["id", "intro", "level", "outro"])
		var chapter := Chapter.new()
		chapter.id = StringName(cr.string("id"))
		if seen.has(chapter.id):
			cr.error("id '%s' is already used by another chapter." % chapter.id)
		seen[chapter.id] = true
		chapter.intro = StringName(cr.string("intro", false))
		chapter.outro = StringName(cr.string("outro", false))
		chapter.level = StringName(cr.string("level"))
		for dialogue_id: StringName in [chapter.intro, chapter.outro]:
			if not dialogue_id.is_empty() and not FileAccess.file_exists(DialogueData.path_for(dialogue_id)):
				cr.error("no dialogue file for '%s'." % dialogue_id)
		if not chapter.level.is_empty() and not FileAccess.file_exists(chapter.level_path()):
			cr.error("no level file for '%s'." % chapter.level)
		if cr.errors.is_empty():
			chapters.append(chapter)
		r.errors.append_array(cr.errors)
