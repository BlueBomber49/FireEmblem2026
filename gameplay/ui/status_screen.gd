class_name StatusScreen
extends Control
## A unit's full status page over the dimmed map, like Fire Emblem's R-button
## screen: portrait, name, class, level, EXP and HP on top, stats on the left
## and the inventory on the right.
##
## It only shows the UnitInfo it's given. Whoever opens it decides which unit
## comes next when the player cycles, through [signal cycle_requested].

## Up / wheel up asks for the previous unit (-1), down / wheel down the next (1).
signal cycle_requested(step: int)
signal closed

## Label -> Stats.FIELDS name, in the order the stat column lists them.
const STAT_ROWS := [
	["Str", "strength"],
	["Mag", "magic"],
	["Skl", "skill"],
	["Spd", "speed"],
	["Lck", "luck"],
	["Def", "defense"],
	["Res", "resistance"],
]
## Always this many inventory rows, so the page keeps one size.
const ITEM_ROWS := Inventory.DEFAULT_CAPACITY
const UNUSABLE_COLOR := ItemMenu.UNUSABLE_COLOR

var can_cycle := false

@onready var _name_banner: PanelContainer = %NameBanner
@onready var _portrait: TextureRect = %Portrait
@onready var _unit_name: Label = %UnitName
@onready var _class_name: Label = %ClassName
@onready var _level: Label = %Level
@onready var _experience: Label = %Experience
@onready var _hp: Label = %Hp
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _movement: Label = %Movement
@onready var _constitution: Label = %Constitution
@onready var _stat_grid: GridContainer = %StatGrid
@onready var _item_rows: VBoxContainer = %ItemRows
@onready var _hint: Label = %Hint


func _ready() -> void:
	hide()
	for row: Array in STAT_ROWS:
		_stat_grid.add_child(_label(String(row[0]) + "Label", row[0]))
		var value := _label(String(row[1]).to_pascal_case(), "0")
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stat_grid.add_child(value)
	for i in ITEM_ROWS:
		var row := HBoxContainer.new()
		row.name = "Item%d" % i
		row.add_theme_constant_override(&"separation", 8)
		_item_rows.add_child(row)
		row.add_child(_label("Equipped", "", 24))
		var item_name := _label("ItemName", "")
		item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item_name)
		var uses := _label("Uses", "")
		uses.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(uses)


## Shows [param info]. With [param cycle] the player can step to other units.
func open(info: UnitInfo, cycle: bool) -> void:
	can_cycle = cycle
	_hint.text = "Up/Down: other units    X: close" if cycle else "X: close"
	show_unit(info)
	show()


## Swaps the unit shown without closing, e.g. while cycling.
func show_unit(info: UnitInfo) -> void:
	_name_banner.theme_type_variation = UnitPanel.FACTION_VARIATIONS[info.faction]
	_portrait.texture = info.portrait
	_unit_name.text = info.unit_name
	_class_name.text = info.class_name_text
	_level.text = str(info.level)
	_experience.text = str(info.experience)
	_hp.text = "%d/%d" % [info.hp, info.max_hp]
	UnitPanel.show_hp(_hp_bar, info.hp, info.max_hp)
	_movement.text = str(info.stats.get("movement", 0))
	_constitution.text = str(info.stats.get("constitution", 0))
	for row: Array in STAT_ROWS:
		(_stat_grid.get_node(String(row[1]).to_pascal_case()) as Label).text = str(info.stats.get(row[1], 0))
	for i in ITEM_ROWS:
		_show_item(_item_rows.get_child(i), info.items[i] if i < info.items.size() else null)


func close() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# The page covers the map, so nothing gets past it while it's open.
	get_viewport().set_input_as_handled()
	var click := event as InputEventMouseButton
	if click != null:
		if not click.pressed:
			return
		match click.button_index:
			MOUSE_BUTTON_RIGHT:
				_close_and_report()
			MOUSE_BUTTON_WHEEL_UP:
				_cycle(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_cycle(1)
		return
	if event.is_action_pressed(&"cancel") or event.is_action_pressed(&"status"):
		_close_and_report()
	elif event.is_action_pressed(&"ui_up", true):
		_cycle(-1)
	elif event.is_action_pressed(&"ui_down", true):
		_cycle(1)


func _cycle(step: int) -> void:
	if can_cycle:
		cycle_requested.emit(step)


func _close_and_report() -> void:
	close()
	closed.emit()


## Fills one inventory row, or blanks it when [param item] is null.
func _show_item(row: Node, item: UnitInfo.ItemInfo) -> void:
	var equipped := row.get_node("Equipped") as Label
	var item_name := row.get_node("ItemName") as Label
	var uses := row.get_node("Uses") as Label
	if item == null:
		equipped.text = ""
		item_name.text = ""
		uses.text = ""
		return
	var color := Color.WHITE if item.usable else UNUSABLE_COLOR
	equipped.text = "E" if item.equipped else ""
	item_name.text = item.item_name
	uses.text = "--" if item.uses_left < 0 else "%d/%d" % [item.uses_left, item.max_uses]
	for label: Label in [equipped, item_name, uses]:
		label.add_theme_color_override(&"font_color", color)


func _label(label_name: String, text: String, min_width := 0) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.theme_type_variation = &"ItemLabel"
	label.custom_minimum_size.x = min_width
	return label
