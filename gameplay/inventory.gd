class_name Inventory
extends RefCounted
## A unit's ordered list of items. FE7's equipped weapon is the first one the class can use.

const DEFAULT_CAPACITY := 5

var capacity: int
var _items: Array[InventoryItem] = []


func _init(p_capacity: int = DEFAULT_CAPACITY) -> void:
	capacity = p_capacity


func size() -> int:
	return _items.size()


func is_full() -> bool:
	return _items.size() >= capacity


## Adds a new copy of `item` with full uses. Returns false when full or `item` is null.
func add(item: ItemData) -> bool:
	if item == null:
		return false
	return add_entry(InventoryItem.new(item))


## Adds an existing entry (used when loading a save). Returns false when full.
func add_entry(entry: InventoryItem) -> bool:
	if entry == null or entry.data == null or is_full():
		return false
	_items.append(entry)
	return true


## The entry at `index`, or null when out of range.
func get_item(index: int) -> InventoryItem:
	if index < 0 or index >= _items.size():
		return null
	return _items[index]


func remove_at(index: int) -> void:
	if index >= 0 and index < _items.size():
		_items.remove_at(index)


## Moves the entry at `index` to the front, shifting the others down (FE7's equip).
func move_to_front(index: int) -> void:
	if index <= 0 or index >= _items.size():
		return
	var entry := _items[index]
	_items.remove_at(index)
	_items.insert(0, entry)


## The inventory as save data: [{"item": <reference>, "uses_left": n}, ...].
## Only consumables save uses_left. Returns an empty Array for an empty inventory
## and null (not an Array) if any item can't be referenced, so callers can tell
## "no items" from "saving failed".
func to_array() -> Variant:
	var entries := []
	for entry in _items:
		var ref := ResourceRef.to_dict(entry.data)
		if ref.is_empty():
			return null
		var saved := {"item": ref}
		if entry.is_consumable():
			saved["uses_left"] = entry.uses_left
		entries.append(saved)
	return entries


## An inventory read from save data. Skips (with a warning) entries that aren't
## dictionaries or whose item can't load, and drops entries beyond capacity.
## A consumable's missing or bad uses_left becomes its max uses; others are clamped
## to 1 through max uses.
static func from_array(a: Variant, p_capacity: int = DEFAULT_CAPACITY) -> Inventory:
	var inventory := Inventory.new(p_capacity)
	if not a is Array:
		push_warning("Save data: inventory isn't a list; loading it empty.")
		return inventory
	for saved in a:
		if not saved is Dictionary:
			push_warning("Save data: skipping an inventory entry that isn't a dictionary.")
			continue
		var item := ResourceRef.load_from(saved.get("item"), ItemData) as ItemData
		if item == null:
			push_warning("Save data: skipping an inventory item that can't load.")
			continue
		var uses := -1
		if item is ConsumableData:
			var max_uses := (item as ConsumableData).max_uses
			uses = clampi(SaveUtil.read_int(saved, "uses_left", max_uses), 1, max_uses)
		if not inventory.add_entry(InventoryItem.new(item, uses)):
			push_warning("Save data: inventory is full; dropping '%s'." % item.id)
	return inventory


## Index of the first weapon `class_data` can wield, or -1.
func first_usable_weapon_index(class_data: ClassData) -> int:
	for i in _items.size():
		var weapon := _items[i].data as WeaponData
		if weapon != null and class_data != null and class_data.can_wield(weapon):
			return i
	return -1
