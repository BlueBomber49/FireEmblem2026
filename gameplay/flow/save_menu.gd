class_name SaveMenu
extends Control
## A placeholder between chapters and on the title: in save mode it asks "Save
## your progress?" (Save / Continue), then lists the files; in load mode it lists
## them. It reports through signals; GameFlow decides what happens next.

## Saved, or chose to continue without saving.
signal finished
## Load mode: a used file was picked.
signal slot_loaded(slot: int)
## Load mode: backed out to the title.
signal back

enum Stage { QUESTION, FILES, OVERWRITE }

## Set before adding: load mode, and what save mode writes.
var loading := false
var chapter_id: StringName
var chapter_index := 0
var roster: Dictionary = {}

var stage := Stage.QUESTION
var _overwrite_slot := -1

@onready var menu: ActionMenu = %Menu
@onready var _title: Label = %Title


func _ready() -> void:
	menu.option_selected.connect(_on_option)
	menu.cancelled.connect(_on_cancelled)
	if loading:
		_show_files()
	else:
		_ask()


func title_text() -> String:
	return _title.text


func _ask() -> void:
	stage = Stage.QUESTION
	_title.text = "Save your progress?"
	menu.open([&"save", &"continue"] as Array[StringName])


func _show_files() -> void:
	stage = Stage.FILES
	_title.text = "Load which file?" if loading else "Save to which file?"
	var ids: Array[StringName] = []
	var labels := {}
	var summaries := SaveSlots.summaries()
	for slot in SaveSlots.COUNT:
		var id := StringName("slot_%d" % slot)
		ids.append(id)
		var s: Dictionary = summaries[slot]
		labels[id] = "File %d   %s" % [slot + 1, "(empty)" if s.is_empty()
				else "Chapter %d: %s   %s" % [s["chapter_index"] + 1, s["chapter_id"], s["saved_at"]]]
	menu.open(ids, labels)


func _on_option(option_id: StringName) -> void:
	match stage:
		Stage.QUESTION:
			if option_id == &"save":
				_show_files()
			else:
				finished.emit()
		Stage.FILES:
			var slot := int(String(option_id).trim_prefix("slot_"))
			var used := not SaveSlots.read(slot).is_empty()
			if loading:
				if used:
					slot_loaded.emit(slot)
				else:
					_show_files()  # nothing to load there
			elif used:
				_overwrite_slot = slot
				stage = Stage.OVERWRITE
				_title.text = "Overwrite File %d?" % (slot + 1)
				menu.open([&"yes", &"no"] as Array[StringName])
			else:
				_save(slot)
		Stage.OVERWRITE:
			if option_id == &"yes":
				_save(_overwrite_slot)
			else:
				_show_files()


## Writes the file and moves on, or says it couldn't and shows the files again.
func _save(slot: int) -> void:
	if SaveSlots.write(slot, chapter_id, chapter_index, roster) != OK:
		_show_files()
		_title.text = "Couldn't save to File %d. Try another file, or cancel." % (slot + 1)
		return
	finished.emit()


func _on_cancelled() -> void:
	match stage:
		Stage.QUESTION:
			_ask()  # nothing to back out to
		Stage.FILES:
			if loading:
				back.emit()
			else:
				_ask()
		Stage.OVERWRITE:
			_show_files()
