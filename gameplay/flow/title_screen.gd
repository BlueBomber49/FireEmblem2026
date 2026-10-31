class_name TitleScreen
extends Control
## The title: a blinking "Press Start", then a menu of New Game and Quit.
## Cancel in the menu goes back to "Press Start".
##
## It only reports what was picked, through [signal new_game_chosen] and
## [signal quit_chosen]. GameFlow decides what those do.

signal new_game_chosen
signal quit_chosen

enum Stage { PRESS_START, MENU }

const OPTIONS: Array[StringName] = [&"new_game", &"quit"]
## Seconds for one fade out (or back in) of "Press Start".
const BLINK_TIME := 0.6

var stage := Stage.PRESS_START
var _blink: Tween

@onready var _press_start: Label = %PressStart
@onready var _menu: ActionMenu = %Menu


func _ready() -> void:
	_menu.option_selected.connect(_on_menu_option)
	_menu.cancelled.connect(_show_press_start)
	_show_press_start()


func _unhandled_input(event: InputEvent) -> void:
	# In MENU, ActionMenu handles input itself.
	if stage != Stage.PRESS_START:
		return
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	var pressed_key := key != null and key.pressed and not key.echo
	var pressed_click := click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	# Cancel doesn't start: there's nothing before this screen to back out to.
	if (event.is_action_pressed(&"confirm") or pressed_key or pressed_click) \
			and not event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		_open_menu()


func _show_press_start() -> void:
	stage = Stage.PRESS_START
	_menu.close()
	_press_start.show()
	_press_start.modulate.a = 1.0
	if _blink != null:
		_blink.kill()
	_blink = create_tween().set_loops()
	_blink.tween_property(_press_start, "modulate:a", 0.2, BLINK_TIME)
	_blink.tween_property(_press_start, "modulate:a", 1.0, BLINK_TIME)


func _open_menu() -> void:
	stage = Stage.MENU
	if _blink != null:
		_blink.kill()
	_press_start.hide()
	_menu.open(OPTIONS)


## ActionMenu closes itself before reporting [param option_id].
func _on_menu_option(option_id: StringName) -> void:
	match option_id:
		&"new_game":
			new_game_chosen.emit()
			
		&"quit":
			quit_chosen.emit()
			
		_:
			push_warning("Invalid menu option chosen: '%s'." %option_id)
			_show_press_start()
