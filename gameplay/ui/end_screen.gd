class_name EndScreen
extends Control
## "Stage Clear" or "Defeat" over the dimmed map once the battle is decided. It
## stays up until the player presses confirm or clicks, which asks Battle to
## move on through [signal continue_requested].

signal continue_requested

const FADE_TIME := 0.4
const CLEAR_ART: Texture2D = preload("res://assets/banners/stage_clear.png")
const DEFEAT_ART: Texture2D = preload("res://assets/banners/defeat.png")

@onready var _band: PanelContainer = %Band
@onready var _title: TextureRect = %Title
@onready var _prompt: Label = %Prompt

## The result last shown.
var won := false


func _ready() -> void:
	hide()


func show_result(p_won: bool) -> void:
	won = p_won
	_prompt.text = "Press Z to continue" if won else "Press Z to retry"
	_title.texture = CLEAR_ART if won else DEFEAT_ART
	_band.theme_type_variation = &"EndBannerClear" if won else &"EndBannerDefeat"
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, ^"modulate:a", 1.0, FADE_TIME)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"confirm"):
		get_viewport().set_input_as_handled()
		continue_requested.emit()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		continue_requested.emit()
