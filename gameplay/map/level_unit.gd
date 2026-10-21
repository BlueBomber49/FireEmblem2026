class_name LevelUnit
extends AnimatedSprite2D
## The view for one unit on the field. All gameplay data lives in `state`
## (what gets saved) and `reference` (what was authored); this node only draws.

var reference: UnitReference
var state: LevelUnitState


static func create(ref: UnitReference, unit_state: LevelUnitState) -> LevelUnit:
	var unit := LevelUnit.new()
	unit.name = ref.id
	unit.reference = ref
	unit.state = unit_state
	unit.sprite_frames = SpriteFramesBuilder.for_sheet(ref.resolved_sprite())
	return unit


func _ready() -> void:
	if state != null:
		play_animation("idle")


## Plays a one-shot action such as "attack" toward `direction`, waits for it
## to finish, then returns to idle.
func play_once(action: String, direction := Vector2i.ZERO) -> void:
	play_animation(action, direction)
	await animation_finished
	play_animation("idle")


## Plays "idle", "walk" or "attack" for the given facing. The sheets only have a
## right-facing side view, so facing left mirrors it.
func play_animation(action: String, direction := Vector2i.ZERO) -> void:
	if direction != Vector2i.ZERO:
		state.facing = direction
	var view := "side"
	if state.facing == Vector2i.UP:
		view = "up"
	elif state.facing == Vector2i.DOWN:
		view = "down"
	flip_h = state.facing == Vector2i.LEFT
	play(StringName(action + "_" + view))
