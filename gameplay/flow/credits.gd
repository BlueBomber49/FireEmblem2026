class_name Credits
extends Control
## The credits: the game's title, each person and their role, then a closing
## line, rolling up the screen over the title music. The text comes from
## resources/credits.json, so the team can change it without touching code.
##
## Holding confirm (or the left mouse button) speeds it up; cancel ends it. The
## closing line comes a screen-half after the rest, so by the time it reaches
## the middle everything else has rolled off the top. It rests there until the
## player confirms or clicks. Whoever shows it decides what comes next, through
## [signal finished].

signal finished

const DATA_PATH := "res://resources/credits.json"
const TITLE_SIZE := 56
const NAME_SIZE := 32
const ROLE_SIZE := 22
const TITLE_COLOR := Color(1, 0.88, 0.55)
const ROLE_COLOR := Color(0.75, 0.75, 0.8)

## Pixels per second while rolling.
@export var speed := 50.0
## How much faster while confirm is held.
@export var fast_multiplier := 6.0
## Play the title music here. GameFlow turns this off and plays it itself, so
## the song carries on between the title and the credits.
@export var play_music := true
## Room between the credits and the closing line, past half the screen, so the
## last credit is gone off the top when the closing line stops in the middle.
const CLOSING_GAP_MARGIN := 48.0

## Confirm (or the mouse button) is held down.
var fast := false
## The closing line has reached the middle and waits there for the player.
var resting := false
var _done := false
var _closing: Label

@onready var _column: VBoxContainer = %Column
@onready var _music: AudioStreamPlayer = $Music


func _ready() -> void:
	_build(read(DATA_PATH))
	_column.position.y = _screen_size().y
	if play_music:
		_music.play()


## The credits' text: {"title", "people": [{"name", "role"}], "closing"}. A missing
## or broken file warns and gives just the title and closing line.
static func read(path: String) -> Dictionary:
	var out := {"title": "Flame Insignia", "people": [], "closing": "Thanks for playing!"}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_warning("Credits: can't read %s; showing the title only." % path)
		return out
	var d: Dictionary = json.data
	out["title"] = str(d.get("title", out["title"]))
	out["closing"] = str(d.get("closing", out["closing"]))
	for person: Variant in d.get("people", []):
		if person is Dictionary:
			out["people"].append({"name": str(person.get("name", "")), "role": str(person.get("role", ""))})
	return out


## Moves the credits on by `delta` seconds (what _process does each frame).
func step(delta: float) -> void:
	if _done or resting:
		return
	_column.position.y -= speed * (fast_multiplier if fast else 1.0) * delta
	var middle := _screen_size().y / 2.0
	var closing_middle := _column.position.y + _closing.position.y + _closing.size.y / 2.0
	if closing_middle <= middle:
		_column.position.y += middle - closing_middle
		resting = true


## Ends the credits, once.
func finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func _process(delta: float) -> void:
	step(delta)


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	var is_click := click != null and click.button_index == MOUSE_BUTTON_LEFT
	if event.is_action(&"confirm") or is_click:
		get_viewport().set_input_as_handled()
		# A fresh press on the resting closing line ends the credits; a press held
		# from the roll doesn't, so the player sees where they landed.
		if event.is_pressed() and not fast and resting:
			finish()
		fast = event.is_pressed()
	elif event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		finish()


func _build(data: Dictionary) -> void:
	_column.size.x = _screen_size().x
	_column.add_child(_label(str(data["title"]), TITLE_SIZE, TITLE_COLOR))
	for person: Dictionary in data["people"]:
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 0)
		entry.add_child(_label(person["name"], NAME_SIZE, Color.WHITE))
		entry.add_child(_label(person["role"], ROLE_SIZE, ROLE_COLOR))
		_column.add_child(entry)
	var gap := Control.new()
	gap.name = "ClosingGap"
	gap.custom_minimum_size.y = _screen_size().y / 2.0 + CLOSING_GAP_MARGIN
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(gap)
	_closing = _label(str(data["closing"]), NAME_SIZE, TITLE_COLOR)
	_column.add_child(_closing)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _screen_size() -> Vector2:
	return get_viewport_rect().size
