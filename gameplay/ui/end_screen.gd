class_name EndScreen
extends Control
## "Stage Clear" or "Defeat" over the dimmed map once the battle is decided. It
## stays up until the player presses confirm or clicks, which asks for a restart
## through [signal restart_requested].

signal restart_requested

const FADE_TIME := 0.4
const CLEAR_ART: Texture2D = preload("res://assets/art/ui/banners/stage_clear.png")
const DEFEAT_ART: Texture2D = preload("res://assets/art/ui/banners/defeat.png")

@onready var _band: PanelContainer = %Band
@onready var _title: TextureRect = %Title


func _ready() -> void:
	hide()


func show_result(won: bool) -> void:
	_title.texture = CLEAR_ART if won else DEFEAT_ART
	_band.theme_type_variation = &"EndBannerClear" if won else &"EndBannerDefeat"
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, ^"modulate:a", 1.0, FADE_TIME)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"confirm"):
		get_viewport().set_input_as_handled()
		restart_requested.emit()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		restart_requested.emit()
