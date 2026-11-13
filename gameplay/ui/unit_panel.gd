class_name UnitPanel
extends PanelContainer
## The small window in the top-left corner showing the unit under the cursor:
## its portrait, name, class and level, and HP.
##
## It only displays what it's given through [method set_unit]. Whoever owns
## the cursor decides when to show or hide it.

const MARGIN := 16
## Faction -> the panel's theme type variation.
const FACTION_VARIATIONS := {
	UnitReference.Faction.PLAYER: &"UnitPanelPlayer",
	UnitReference.Faction.ENEMY: &"UnitPanelEnemy",
	UnitReference.Faction.ALLY: &"UnitPanelAlly",
}

@onready var _portrait: TextureRect = %Portrait
@onready var _unit_name: Label = %UnitName
@onready var _class_name: Label = %ClassName
@onready var _level: Label = %Level
@onready var _hp: Label = %Hp
@onready var _hp_bar: ProgressBar = %HpBar


func _ready() -> void:
	# It sits over map tiles, so the cursor must keep following the mouse under it.
	TerrainPanel.ignore_mouse(self)


func set_unit(info: UnitInfo) -> void:
	theme_type_variation = FACTION_VARIATIONS[info.faction]
	_portrait.texture = info.portrait
	_unit_name.text = info.unit_name
	_class_name.text = info.class_name_text
	_level.text = "Lv %d" % info.level
	_hp.text = "%d/%d" % [info.hp, info.max_hp]
	show_hp(_hp_bar, info.hp, info.max_hp)
	# Size first, then pin by that size, as in TerrainPanel.set_side. Long names
	# clip instead of widening the panel.
	reset_size()
	set_anchors_and_offsets_preset(PRESET_TOP_LEFT, PRESET_MODE_KEEP_SIZE, MARGIN)


## Fills [param bar] to [param current] / [param maximum] in UnitInfo.hp_color.
## Shared with the status screen so both bars read the same.
static func show_hp(bar: ProgressBar, current: int, maximum: int) -> void:
	bar.max_value = maxi(maximum, 1)
	bar.value = current
	var fill := bar.get_theme_stylebox(&"fill").duplicate() as StyleBoxFlat
	fill.bg_color = UnitInfo.hp_color(current, maximum)
	bar.add_theme_stylebox_override(&"fill", fill)
