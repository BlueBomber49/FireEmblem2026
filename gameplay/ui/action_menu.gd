class_name ActionMenu
extends PanelContainer
## A vertical list of commands, like Fire Emblem's map menu or unit menu.
##
## The menu only reports what the player picked through [signal option_selected].
## Whoever opens it decides what each option does.

signal option_selected(option_id: StringName)
signal cancelled

## Ids of the options to show, top to bottom. The label is the capitalized id
## ([code]&"end"[/code] shows as "End").
@export var options: Array[StringName] = []

@onready var _option_list: VBoxContainer = %Options


func _ready() -> void:
	hide()


## Shows the menu with the cursor on the first option. Pass [param new_options]
## to replace [member options] before opening.
func open(new_options: Array[StringName] = []) -> void:
	if not new_options.is_empty():
		options = new_options
	_build_buttons()
	show()
	if _option_list.get_child_count() > 0:
		(_option_list.get_child(0) as Button).grab_focus()


func close() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		close()
		cancelled.emit()
	# Confirm needs no handling here. Z, Enter, Space and gamepad A are all
	# mapped to ui_accept, which presses the focused Button directly.


func _build_buttons() -> void:
	for child: Node in _option_list.get_children():
		_option_list.remove_child(child)
		child.queue_free()

	for option_id: StringName in options:
		var button := Button.new()
		button.name = String(option_id).to_pascal_case()
		button.text = String(option_id).capitalize()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_option_pressed.bind(option_id))
		button.mouse_entered.connect(button.grab_focus)
		_option_list.add_child(button)

	# Wrap the cursor around: up from the top goes to the bottom and back.
	var count := _option_list.get_child_count()
	if count > 1:
		var first := _option_list.get_child(0) as Button
		var last := _option_list.get_child(count - 1) as Button
		first.focus_neighbor_top = first.get_path_to(last)
		last.focus_neighbor_bottom = last.get_path_to(first)


func _on_option_pressed(option_id: StringName) -> void:
	close()
	option_selected.emit(option_id)
