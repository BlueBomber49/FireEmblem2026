class_name ItemMenu
extends HBoxContainer
## A unit's inventory, like Fire Emblem's Item command: one row per item, a
## stats panel for the highlighted one, and an Equip / Use submenu for the one
## picked.
##
## It only shows the UnitInfo it's given. Whoever opens it decides what Equip
## and Use do, through [signal action_chosen].

## The player picked [param action_id] ([code]&"equip"[/code] or
## [code]&"use"[/code]) for the item in slot [param index].
signal action_chosen(action_id: StringName, index: int)
signal cancelled

const UNUSABLE_COLOR := Color(0.6, 0.6, 0.6)
const ICON_SIZE := Vector2(32, 32)

var _items: Array[UnitInfo.ItemInfo] = []
## The row whose submenu is open, or -1.
var _chosen_index := -1

@onready var _rows: VBoxContainer = %Rows
@onready var _stats_panel: PanelContainer = %StatsPanel
@onready var _weapon_stats: Control = %WeaponStats
@onready var _type_label: Label = %TypeLabel
@onready var _effect_label: Label = %EffectLabel
@onready var _submenu: ActionMenu = %ActionSubmenu


func _ready() -> void:
	hide()
	_submenu.option_selected.connect(_on_submenu_option)
	_submenu.cancelled.connect(_on_submenu_cancelled)


## Shows [param info]'s items with the cursor on the first one.
func open(info: UnitInfo) -> void:
	show()
	refresh(info)


## Rebuilds the rows from [param info] without closing, e.g. after an equip
## moves a weapon to the top. The cursor goes to [param focus_index].
func refresh(info: UnitInfo, focus_index: int = 0) -> void:
	_submenu.close()
	_chosen_index = -1
	_items = info.items
	_build_rows()
	if _rows.get_child_count() > 0:
		_row(clampi(focus_index, 0, _rows.get_child_count() - 1)).grab_focus()
	else:
		_stats_panel.hide()


func close() -> void:
	_submenu.close()
	_chosen_index = -1
	hide()


## Steps back once: from the submenu to the list, or out of the menu.
func back() -> void:
	if _submenu.visible:
		_submenu.close()
		_on_submenu_cancelled()
	else:
		close()
		cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	# An open submenu is a child, so it sees cancel first and handles it itself.
	if not visible or _submenu.visible:
		return
	if event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		back()


func _row(index: int) -> Button:
	return _rows.get_child(index) as Button


func _build_rows() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	for i in _items.size():
		_build_row(i, _items[i])

	# Wrap the cursor around, as in ActionMenu.
	var count := _rows.get_child_count()
	if count > 1:
		var first := _row(0)
		var last := _row(count - 1)
		first.focus_neighbor_top = first.get_path_to(last)
		last.focus_neighbor_bottom = last.get_path_to(first)


## A Button isn't a container, so the row's labels sit in an HBox stretched over
## it, and the Button's minimum size is kept in step with the HBox's. The row
## joins the tree first so everything is measured with the menu's theme: sized
## with the default font, the list would lay out too short after a refresh.
func _build_row(index: int, item: UnitInfo.ItemInfo) -> void:
	var button := Button.new()
	button.name = "Row%d" % index
	button.pressed.connect(_on_row_pressed.bind(index))
	button.focus_entered.connect(_show_stats.bind(index))
	button.mouse_entered.connect(button.grab_focus)
	_rows.add_child(button)

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(columns)

	# Empty until there's item art, like the forecast's weapon icons.
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	columns.add_child(icon)

	var color := Color.WHITE if item.usable else UNUSABLE_COLOR
	columns.add_child(_row_label("Equipped", "E" if item.equipped else "", color, 24))
	var item_name := _row_label("ItemName", item.item_name, color)
	item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(item_name)
	var uses_text := "--" if item.uses_left < 0 else "%d/%d" % [item.uses_left, item.max_uses]
	var uses := _row_label("Uses", uses_text, color)
	uses.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	columns.add_child(uses)

	var margins := button.get_theme_stylebox(&"normal").get_minimum_size()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.offset_left = margins.x / 2
	columns.offset_right = -margins.x / 2
	var fit := func() -> void: button.custom_minimum_size = columns.get_combined_minimum_size() + margins
	columns.minimum_size_changed.connect(fit)
	fit.call()


func _row_label(label_name: String, text: String, color: Color, min_width := 0) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.custom_minimum_size.x = min_width
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", color)
	return label


func _show_stats(index: int) -> void:
	var item := _items[index]
	_stats_panel.show()
	_weapon_stats.visible = item.is_weapon
	_type_label.visible = item.is_weapon
	_effect_label.visible = not item.is_weapon
	if item.is_weapon:
		_type_label.text = item.weapon_type
		(%Might as Label).text = str(item.might)
		(%Hit as Label).text = str(item.hit)
		(%Crit as Label).text = str(item.crit)
		(%Weight as Label).text = str(item.weight)
		(%Range as Label).text = item.range_text()
	else:
		_effect_label.text = item.effect_text()


## Unusable items can be highlighted to read their stats, but not picked.
func _on_row_pressed(index: int) -> void:
	var item := _items[index]
	if not item.usable:
		return
	_chosen_index = index
	# Keep the row lit while focus is in the submenu.
	_row(index).add_theme_stylebox_override(&"normal", get_theme_stylebox(&"focus", &"Button"))
	var options: Array[StringName] = [&"use"]
	if item.is_weapon:
		options = [&"equip"]
	_submenu.open(options)


func _on_submenu_option(option_id: StringName) -> void:
	var index := _chosen_index
	_clear_chosen()
	action_chosen.emit(option_id, index)


func _on_submenu_cancelled() -> void:
	var index := _chosen_index
	_clear_chosen()
	if index >= 0:
		_row(index).grab_focus()


func _clear_chosen() -> void:
	if _chosen_index >= 0 and _chosen_index < _rows.get_child_count():
		_row(_chosen_index).remove_theme_stylebox_override(&"normal")
	_chosen_index = -1
