class_name ExpPopup
extends PanelContainer
## A placeholder shown after a fight: "Lyn  EXP +33" with the bar filling from the
## old value, then on a level-up "LEVEL UP!" and the stats that rose. Battle
## awaits [method play]. Each screen waits for confirm or a click; one during the
## fill finishes it at once.

## FE's short stat names, for the level-up lines.
const SHORT_NAMES := {
	&"hp": "HP", &"strength": "Str", &"magic": "Mag", &"skill": "Skl",
	&"speed": "Spd", &"luck": "Lck", &"defense": "Def", &"resistance": "Res",
}
const GAINS_PER_LINE := 4


## Seconds for the bar to fill.
@export var fill_time := 0.6
## Wait for confirm or a click on each screen. Off (tests), each just holds
## for hold_time seconds instead.
@export var wait_for_player := true
@export var hold_time := 0.8

## A confirm or click arrived (finishes a fill, or moves on from a screen).
var _pressed := false
var _tween: Tween

@onready var _title: Label = %Title
@onready var _bar: ProgressBar = %Bar
@onready var _gains: Label = %Gains


func _ready() -> void:
	hide()
	_bar.max_value = Experience.PER_LEVEL


## Shows `amount` EXP going onto `start_exp`, then each of `level_ups` (from
## Experience.gain), ending on `end_exp`: the unit's EXP afterward (0 once it
## reaches level 20), so the bar never has to work it out. Returns once it's gone.
func play(unit_name: String, start_exp: int, amount: int, level_ups: Array[Dictionary],
		end_exp: int) -> void:
	_pressed = false
	_title.text = "%s   EXP +%d" % [unit_name, amount]
	_gains.hide()
	_bar.value = start_exp
	show()
	# Up to 100 on a level-up; the leftover is shown after the last one.
	var levelled := not level_ups.is_empty()
	await _fill(float(Experience.PER_LEVEL if levelled else end_exp))
	await _next()
	for i in level_ups.size():
		_bar.value = 0
		_title.text = "%s   LEVEL UP!" % unit_name
		_gains.text = gains_text(level_ups[i])
		_gains.show()
		if i == level_ups.size() - 1:
			await _fill(float(end_exp))
		await _next()
	_stop_tween()
	hide()


## Tweens the bar to `value`; a press during it jumps the bar there.
func _fill(value: float) -> void:
	_stop_tween()
	_pressed = false
	_tween = create_tween()
	_tween.tween_property(_bar, ^"value", value, fill_time)
	# Frame by frame rather than awaiting finished: a skip kills the tween, and a
	# killed tween never sends finished.
	while _tween != null and _tween.is_running():
		await get_tree().process_frame
	_tween = null
	_bar.value = value


## "HP +1  Str +1  ..." for one level-up, four to a line, or a note when nothing
## rose.
static func gains_text(up: Dictionary) -> String:
	var parts := PackedStringArray()
	for field: StringName in Stats.FIELDS:
		if up.has(field):
			parts.append("%s +%d" % [SHORT_NAMES.get(field, String(field).capitalize()), up[field]])
	if parts.is_empty():
		return "No stats rose"
	var lines := PackedStringArray()
	for i in range(0, parts.size(), GAINS_PER_LINE):
		lines.append("  ".join(parts.slice(i, i + GAINS_PER_LINE)))
	return "\n".join(lines)


func _stop_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


## Waits for the player to move on (or hold_time, when wait_for_player is off).
func _next() -> void:
	_pressed = false
	var left := hold_time
	while not _pressed and (wait_for_player or left > 0.0):
		await get_tree().process_frame
		left -= get_process_delta_time()
	_pressed = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var click := event as InputEventMouseButton
	if event.is_action_pressed(&"confirm") or (click != null and click.pressed):
		get_viewport().set_input_as_handled()
		if _tween != null:
			_stop_tween()  # _fill sees it gone and jumps the bar to its end
		else:
			_pressed = true
