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
## Name of the child that shows when a reinforcement arrives (the map editor only).
const ARRIVAL_BADGE_NAME := &"ArrivalBadge"

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


## Shows "T<turn>" on the unit (a reinforcement, in the map editor), or removes
## it when `turn` is 0.
func set_arrival_turn(turn: int) -> void:
	var badge := get_node_or_null(NodePath(ARRIVAL_BADGE_NAME)) as ArrivalBadge
	if turn <= 0:
		if badge != null:
			remove_child(badge)
			badge.queue_free()
		return
	if badge == null:
		badge = ArrivalBadge.new()
		badge.name = ARRIVAL_BADGE_NAME
		add_child(badge)
	badge.text = "T%d" % turn
	badge.queue_redraw()


## When a reinforcement arrives, in the bottom-left corner of its cell like the
## commander's badge in the top-right, so neither covers the sprite's middle.
class ArrivalBadge:
	extends Node2D

	const TOP_LEFT := Vector2(-8, 1)
	const SIZE := Vector2(11, 7)
	const FONT_SIZE := 7
	const BACK := Color(0.08, 0.05, 0.12, 0.9)
	const INK := Color(1.0, 0.85, 0.3)

	var text := ""

	func _ready() -> void:
		z_index = 1

	func _draw() -> void:
		draw_rect(Rect2(TOP_LEFT, SIZE), BACK)
		draw_string(ThemeDB.fallback_font, TOP_LEFT + Vector2(1, SIZE.y - 1), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)


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
