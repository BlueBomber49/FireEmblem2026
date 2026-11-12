class_name PhaseBanner
extends Control
## The "Player Phase" / "Enemy Phase" band that sweeps across the map when a
## phase begins: it slides in from the right, holds, then slides out to the
## left. Whoever calls [method play] awaits it, so nothing acts until it's gone.
##
## Confirm or a click skips ahead to the slide-out. While it plays it swallows
## the mouse, and Battle ignores everything else.

signal finished

## The pixel-art lettering for each phase.
const ART := {
	TurnLoop.Phase.PLAYER: preload("res://assets/banners/player_phase.png"),
	TurnLoop.Phase.ENEMY: preload("res://assets/banners/enemy_phase.png"),
}
const VARIATION := {
	TurnLoop.Phase.PLAYER: &"PhaseBannerPlayer",
	TurnLoop.Phase.ENEMY: &"PhaseBannerEnemy",
}

## Seconds for the band to cross onto or off the screen.
@export var slide_time := 0.25
## Seconds the band rests in the middle.
@export var hold_time := 1.0

var _tween: Tween
var _sliding_out := false

@onready var _band: PanelContainer = %Band
@onready var _title: TextureRect = %Title


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_playing() -> bool:
	return visible


## Shows the band for `phase` and returns once it has left the screen.
func play(phase: TurnLoop.Phase) -> void:
	_title.texture = ART[phase]
	_band.theme_type_variation = VARIATION[phase]
	_sliding_out = false
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_band.position.x = _width()

	_tween = create_tween()
	_tween.tween_property(_band, ^"position:x", 0.0, slide_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_time)
	_tween.tween_callback(_slide_out)
	await finished


## Cuts the slide-in or hold short and sends the band off the screen now.
func skip() -> void:
	if not is_playing() or _sliding_out:
		return
	_tween.kill()
	_slide_out()


func _slide_out() -> void:
	_sliding_out = true
	_tween = create_tween()
	_tween.tween_property(_band, ^"position:x", -_width(), slide_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_end)


func _end() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_playing() and event.is_action_pressed(&"confirm"):
		get_viewport().set_input_as_handled()
		skip()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		skip()


## The viewport's width, which the banner fills; its own size may not be laid
## out yet when the level's first banner starts.
func _width() -> float:
	return get_viewport_rect().size.x
