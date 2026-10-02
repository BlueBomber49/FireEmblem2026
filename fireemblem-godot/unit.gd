extends AnimatedSprite2D

## The direction the unit is looking, as a grid step.
var facing := Vector2i.DOWN


func _ready() -> void:
	play_animation("idle")


## Plays "idle" or "walk" for the given facing. The sheets only have a
## right-facing side view, so facing left mirrors it.
func play_animation(action: String, direction := facing) -> void:
	facing = direction
	var view := "side"
	if facing == Vector2i.UP:
		view = "up"
	elif facing == Vector2i.DOWN:
		view = "down"
	flip_h = facing == Vector2i.LEFT
	play(action + "_" + view)
