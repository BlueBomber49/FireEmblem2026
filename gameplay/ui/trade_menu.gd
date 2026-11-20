class_name TradeMenu
extends CenterContainer
## Fire Emblem's Trade screen: two units' inventories side by side, each under
## its owner's portrait and name, with the highlighted item's stats below.
##
## Pick an item on one side, then an item or an empty slot on the other: they
## swap, or the item moves across. Picking on the same side picks that item
## instead. Cancel drops a pick, then closes. It changes the two inventories
## itself; whoever opens it learns whether anything moved through [signal closed].

signal closed(traded: bool)

const SLOTS := Inventory.DEFAULT_CAPACITY
const LEFT := 0
const RIGHT := 1

## Something moved since the screen opened.
var traded := false
## [side, slot] of the picked item, or [] when nothing is picked.
var picked: Array = []

var _units: Array[Unit] = []

@onready var _sides: Array[VBoxContainer] = [%Left, %Right]
@onready var _stats: Label = %Stats


func _ready() -> void:
	hide()


## Shows `left` and `right` (each a Unit, its name and portrait, which may be null)
## with the cursor on the left unit's first slot.
func open(left: Unit, left_name: String, left_portrait: Texture2D,
		right: Unit, right_name: String, right_portrait: Texture2D) -> void:
	_units = [left, right]
	traded = false
	picked = []
	_set_owner(LEFT, left_name, left_portrait)
	_set_owner(RIGHT, right_name, right_portrait)
	_build_rows()
	show()
	row(LEFT, 0).grab_focus()


func close() -> void:
	hide()


## The button for `slot` (0-4) on `side` (LEFT or RIGHT).
func row(side: int, slot: int) -> Button:
	return _sides[side].get_node("Rows").get_child(slot) as Button


## What a click or confirm on a slot does.
func choose(side: int, slot: int) -> void:
	var unit := _units[side]
	if picked.is_empty() or picked[0] == side:
		# Nothing picked yet, or a different item on the same side: pick it.
		if slot < unit.inventory.size():
			picked = [side, slot]
			_refresh()
			row(1 - side, mini(slot, SLOTS - 1)).grab_focus()
		return
	var from_side: int = picked[0]
	var from_slot: int = picked[1]
	if _units[from_side].inventory.swap_with(from_slot, unit.inventory, slot):
		traded = true
	picked = []
	_refresh()
	row(from_side, mini(from_slot, SLOTS - 1)).grab_focus()


## Cancel: drops a pick, or closes the screen.
func back() -> void:
	if not picked.is_empty():
		var side: int = picked[0]
		var slot: int = picked[1]
		picked = []
		_refresh()
		row(side, slot).grab_focus()
		return
	close()
	closed.emit(traded)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		back()


func _set_owner(side: int, unit_name: String, portrait: Texture2D) -> void:
	(_sides[side].get_node("Portrait") as TextureRect).texture = portrait
	(_sides[side].get_node("Name") as Label).text = unit_name


func _build_rows() -> void:
	for side in [LEFT, RIGHT]:
		var rows := _sides[side].get_node("Rows")
		for child in rows.get_children():
			rows.remove_child(child)
			child.queue_free()
		for slot in SLOTS:
			var button := Button.new()
			button.name = "Slot%d" % slot
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(choose.bind(side, slot))
			button.focus_entered.connect(_show_stats.bind(side, slot))
			button.mouse_entered.connect(button.grab_focus)
			rows.add_child(button)
	_refresh()


## Rewrites every slot (E marker, name, uses; "-" when empty) and marks the pick.
func _refresh() -> void:
	for side in [LEFT, RIGHT]:
		var info := UnitInfo.from_unit(_units[side])
		for slot in SLOTS:
			var button := row(side, slot)
			if slot < info.items.size():
				var item := info.items[slot]
				var uses := "--" if item.uses_left < 0 else "%d/%d" % [item.uses_left, item.max_uses]
				button.text = "%s %s   %s" % ["E" if item.equipped else "  ", item.item_name, uses]
			else:
				button.text = "   -"
			if picked == [side, slot]:
				# Keep the picked row lit while the cursor is on the other side.
				button.add_theme_stylebox_override(&"normal", get_theme_stylebox(&"focus", &"Button"))
			else:
				button.remove_theme_stylebox_override(&"normal")


## One line for the highlighted item: a weapon's numbers, or what an item does.
func _show_stats(side: int, slot: int) -> void:
	var info := UnitInfo.from_unit(_units[side])
	if slot >= info.items.size():
		_stats.text = " "
		return
	var item := info.items[slot]
	if item.is_weapon:
		_stats.text = "%s   Mt %d   Hit %d   Wt %d   Crit %d   Rng %s" \
				% [item.weapon_type, item.might, item.hit, item.weight, item.crit, item.range_text()]
	else:
		_stats.text = item.effect_text()
