class_name Cutscene
extends Control
## A conversation: portraits on the left and right, a text box along the
## bottom, each line typed out in turn. The speaker is lit, the other dimmed.
##
## Confirm (or left click) finishes the line being typed, or moves to the next.
## Cancel skips the rest. It only plays what it's given: whoever plays it
## decides what comes after, through [signal finished].

signal finished

const CHARS_PER_SECOND := 40.0
const PORTRAIT_DIR := "res://assets/portraits"
const DIM_TINT := Color(0.4, 0.4, 0.4)

## For running this scene on its own (F6); GameFlow calls play() instead.
@export_file("*.json") var dialogue_path := ""

var dialogue: DialogueData
## The line on screen, or -1 before the first.
var line_index := -1
var _typing: Tween
var _done := false
## side -> the flip_h the scene gives that slot, i.e. facing inward.
var _inward_flip: Dictionary = {}
## side -> the speaker standing there, so someone who moves leaves their old slot.
var _occupants: Dictionary = {}

@onready var _backdrop: TextureRect = %Backdrop
## side (one of DialogueData.SIDES) -> the portrait slot drawn there.
@onready var _slots: Dictionary = {
	&"left": %LeftPortrait,
	&"back_left": %BackLeftPortrait,
	&"right": %RightPortrait,
	&"back_right": %BackRightPortrait,
}
@onready var _name_label: Label = %NameLabel
@onready var _text: RichTextLabel = %Text


func _ready() -> void:
	for side: StringName in _slots:
		_inward_flip[side] = (_slots[side] as TextureRect).flip_h
	if dialogue == null and not dialogue_path.is_empty():
		dialogue = DialogueData.read(dialogue_path)
	if dialogue != null:
		_start()


## Plays [param data] from its first line. May be called before the scene is
## in the tree; it starts once it's ready.
func play(data: DialogueData) -> void:
	dialogue = data
	if is_node_ready():
		_start()


func is_typing() -> bool:
	return _typing != null and _typing.is_running()


## What confirm does: finish typing the line, else go on to the next, else end.
func advance() -> void:
	if _done:
		return
	if is_typing():
		_typing.kill()
		_text.visible_ratio = 1.0
	elif line_index + 1 < dialogue.lines.size():
		_show_line(line_index + 1)
	else:
		_finish()


## What cancel does: ends the cutscene now.
func skip() -> void:
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _done or dialogue == null:
		return
	var click := event as InputEventMouseButton
	if event.is_action_pressed(&"confirm") \
			or (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		advance()
	elif event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		skip()


func _start() -> void:
	_done = false
	_occupants.clear()
	for slot: TextureRect in _slots.values():
		slot.texture = null
	_backdrop.texture = load(dialogue.background) if not dialogue.background.is_empty() else null
	if dialogue.lines.is_empty():
		_finish()
	else:
		_show_line(0)


func _show_line(index: int) -> void:
	line_index = index
	var line: DialogueData.Line = dialogue.lines[index]
	var narration := line.speaker.is_empty()
	if not narration:
		_place(line.speaker, line.side, line.face_outside)
	for side: StringName in _slots:
		var lit := not narration and side == line.side
		(_slots[side] as TextureRect).modulate = Color.WHITE if lit else DIM_TINT
	_name_label.text = line.display_name()
	_name_label.visible = not narration
	_text.text = line.text
	_text.visible_ratio = 0.0
	if _typing != null:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, line.text.length() / CHARS_PER_SECOND)


## Puts [param speaker] in [param side]'s slot. Everyone else stays where they
## are until replaced, except the speaker's own old slot, which empties.
## Facing is set on every line: a line without face_outside turns them back in.
func _place(speaker: StringName, side: StringName, face_outside: bool) -> void:
	for old_side: StringName in _occupants.keys():
		if _occupants[old_side] == speaker and old_side != side:
			(_slots[old_side] as TextureRect).texture = null
			_occupants.erase(old_side)
	var slot: TextureRect = _slots[side]
	slot.texture = _portrait(speaker)
	slot.flip_h = _inward_flip[side] != face_outside
	_occupants[side] = speaker


func _finish() -> void:
	if _done:
		return
	_done = true
	if _typing != null:
		_typing.kill()
	finished.emit()


## The speaker's portrait, or null when they don't have one yet.
static func _portrait(speaker: StringName) -> Texture2D:
	var path := PORTRAIT_DIR.path_join("%s.png" % speaker)
	return load(path) if ResourceLoader.exists(path) else null
