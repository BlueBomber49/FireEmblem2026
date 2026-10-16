class_name CombatForecast
extends PanelContainer
## The panel shown before an attack: each side's damage, hit and crit, with the
## player on the left, the enemy on the right and the stat names in between.
##
## It only displays numbers it's given through [method open]. Combat logic does
## the math, and decides what happens on [signal confirmed] or [signal cancelled].

signal confirmed
signal cancelled

enum ScreenSide { LEFT, RIGHT }

const MARGIN := 16
const ADVANTAGE_COLOR := Color(0.45, 1, 0.45)
const DISADVANTAGE_COLOR := Color(1, 0.45, 0.45)

var _side := ScreenSide.LEFT


func _ready() -> void:
	hide()


## Fills in both sides and shows the panel.
func open(player: ForecastSide, enemy: ForecastSide) -> void:
	_fill_column("Player", player)
	_fill_column("Enemy", enemy)
	show()
	set_side(_side)


func close() -> void:
	hide()


## Pins the panel to the top-left or top-right corner, so it can sit on the
## half of the screen away from the fight.
func set_side(side: ScreenSide) -> void:
	_side = side
	var preset := PRESET_TOP_LEFT if side == ScreenSide.LEFT else PRESET_TOP_RIGHT
	set_anchors_and_offsets_preset(preset, PRESET_MODE_MINSIZE, MARGIN)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# No Button has focus here, so confirm is read directly, unlike ActionMenu.
	if event.is_action_pressed(&"confirm"):
		get_viewport().set_input_as_handled()
		close()
		confirmed.emit()
	elif event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		close()
		cancelled.emit()


func _fill_column(prefix: String, side: ForecastSide) -> void:
	_label(prefix, "Name").text = side.unit_name
	_label(prefix, "Weapon").text = side.weapon_name
	_label(prefix, "Hp").text = str(side.hp)

	var advantage := _label(prefix, "Advantage")
	advantage.visible = side.advantage != 0
	advantage.text = "+" if side.advantage > 0 else "-"
	advantage.add_theme_color_override(&"font_color",
			ADVANTAGE_COLOR if side.advantage > 0 else DISADVANTAGE_COLOR)

	var count := _label(prefix, "Count")
	count.text = "x%d" % side.attack_count
	count.visible = side.can_counter and side.attack_count > 1

	if side.can_counter:
		_label(prefix, "Damage").text = str(side.damage)
		_label(prefix, "Hit").text = str(side.hit)
		_label(prefix, "Crit").text = str(side.crit)
	else:
		for stat: String in ["Damage", "Hit", "Crit"]:
			_label(prefix, stat).text = "--"


func _label(prefix: String, stat: String) -> Label:
	return get_node("%" + prefix + stat) as Label
