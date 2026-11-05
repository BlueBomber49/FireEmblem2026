class_name LevelUnit
extends AnimatedSprite2D
## The view for one unit on the field. All gameplay data lives in `state`
## (what gets saved) and `reference` (what was authored); this node only draws.

## Name of the child that draws the commander's crown.
const COMMANDER_ICON_NAME := &"CommanderIcon"
## Art for the commander's crown, drawn on the badge. Null draws a placeholder
## crown in code; set a small texture (about 5x5) here to replace it everywhere,
## game and editor.
const COMMANDER_ICON: Texture2D = null

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
	if reference != null and reference.commander:
		var icon := CommanderIcon.new()
		icon.name = COMMANDER_ICON_NAME
		add_child(icon)


## The enemy commander's badge: a gold crown on a dark round badge in the
## top-right corner of its cell, readable against any sprite. A child of the
## sprite, so it takes the acted tint and fades out with the unit.
class CommanderIcon:
	extends Node2D

	## The unit is centred on its 16 px cell, so the cell's top-right corner is
	## (8, -8); the badge sits just inside it.
	const BADGE_CENTER := Vector2(7, -7)
	const BADGE_RADIUS := 4.0
	const CROWN_SCALE := 0.75
	const GOLD := Color(1.0, 0.82, 0.15)
	const BADGE := Color(0.08, 0.05, 0.12, 0.9)

	func _ready() -> void:
		z_index = 1

	func _draw() -> void:
		draw_circle(BADGE_CENTER, BADGE_RADIUS, BADGE)
		draw_arc(BADGE_CENTER, BADGE_RADIUS, 0, TAU, 16, GOLD, 1.0)
		# Through a typed variable: calling a method on the (null) constant itself
		# trips the script checker.
		var art: Texture2D = COMMANDER_ICON
		if art != null:
			draw_texture(art, BADGE_CENTER - art.get_size() / 2.0)
			return
		# A 6 x 5 crown, scaled and centred on the badge.
		var size := Vector2(6, 5) * CROWN_SCALE
		var o := BADGE_CENTER - size / 2.0
		var s := CROWN_SCALE
		var points := PackedVector2Array([o + Vector2(0, 5) * s, o + Vector2(0, 1) * s, o + Vector2(1.5, 3) * s,
				o + Vector2(3, 0) * s, o + Vector2(4.5, 3) * s, o + Vector2(6, 1) * s, o + Vector2(6, 5) * s])
		draw_colored_polygon(points, GOLD)


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
