class_name ItemPopup
extends PanelContainer
## A placeholder shown when a unit gets an item, such as from a chest: "Got
## Vulnerary". Battle awaits [method play], which waits for confirm or a click.

## Wait for confirm or a click. Off (tests), it just holds for hold_time seconds.
@export var wait_for_player := true
@export var hold_time := 0.8

var _pressed := false

@onready var _text: Label = %Text


func _ready() -> void:
	hide()


## Shows "Got <item_name>" and returns once it's gone.
func play(item_name: String) -> void:
	_text.text = "Got %s" % item_name
	_pressed = false
	show()
	var left := hold_time
	while not _pressed and (wait_for_player or left > 0.0):
		await get_tree().process_frame
		left -= get_process_delta_time()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var click := event as InputEventMouseButton
	if event.is_action_pressed(&"confirm") or (click != null and click.pressed):
		get_viewport().set_input_as_handled()
		_pressed = true
