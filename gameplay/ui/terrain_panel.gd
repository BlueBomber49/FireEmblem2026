class_name TerrainPanel
extends PanelContainer
## The small window in a bottom corner of the map showing the terrain under
## the cursor.
##
## It only displays what it's given through [method set_terrain]. Whoever owns
## the cursor decides when to show, hide or move it.

enum ScreenSide { LEFT, RIGHT }

const MARGIN := 16

var _side := ScreenSide.LEFT

@onready var _terrain_name: Label = %TerrainName
@onready var _defense: Label = %Defense
@onready var _avoid: Label = %Avoid
@onready var _move: Label = %Move
@onready var _heal: Label = %Heal


func _ready() -> void:
	# It sits over map tiles, so the cursor must keep following the mouse under it.
	ignore_mouse(self)


## Lets mouse hovers and clicks pass through `control` and everything in it.
## Panels and containers stop or catch the mouse by default.
static func ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			ignore_mouse(child)


func set_terrain(info: TerrainInfo) -> void:
	_terrain_name.text = info.terrain_name
	_defense.text = str(info.defense)
	_avoid.text = str(info.avoid)
	_move.text = "--" if info.move_cost == TerrainInfo.IMPASSABLE else str(info.move_cost)

	# Always shown, so the panel keeps one height as the cursor moves.
	_heal.text = "%d%%" % info.heal_percent if info.heal_percent > 0 else "--"
	set_side(_side)


## Pins the panel to the bottom-left or bottom-right corner.
func set_side(side: ScreenSide) -> void:
	_side = side
	var preset := PRESET_BOTTOM_LEFT if side == ScreenSide.LEFT else PRESET_BOTTOM_RIGHT
	# Size first, then pin by that size. MINSIZE mode would place it by its
	# content alone, ignoring the scene's fixed width, and the panel would then
	# grow past the corner. reset_size() also shrinks it back if a long name
	# ever stretched it.
	reset_size()
	set_anchors_and_offsets_preset(preset, PRESET_MODE_KEEP_SIZE, MARGIN)
