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
@onready var _heal_label: Label = %HealLabel
@onready var _heal: Label = %Heal


func set_terrain(info: TerrainInfo) -> void:
	_terrain_name.text = info.terrain_name
	_defense.text = str(info.defense)
	_avoid.text = str(info.avoid)
	_move.text = "--" if info.move_cost == TerrainInfo.IMPASSABLE else str(info.move_cost)

	var heals := info.heal_percent > 0
	_heal_label.visible = heals
	_heal.visible = heals
	_heal.text = "%d%%" % info.heal_percent

	# A Control never shrinks on its own when content is hidden, so drop back to
	# the minimum size and re-pin it to its corner.
	reset_size()
	set_side(_side)


## Pins the panel to the bottom-left or bottom-right corner.
func set_side(side: ScreenSide) -> void:
	_side = side
	var preset := PRESET_BOTTOM_LEFT if side == ScreenSide.LEFT else PRESET_BOTTOM_RIGHT
	set_anchors_and_offsets_preset(preset, PRESET_MODE_MINSIZE, MARGIN)
