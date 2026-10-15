class_name ResourceRef
## Saves and loads references to resource files (such as a unit's definition or an item)
## so saves point at the shared .tres file instead of copying it.
##
## A reference stores the resource's UID, which survives renaming and moving
## the file, plus its path as a readable fallback.


## True when `resource` is saved as its own file, so a reference to it can be loaded back.
## Resources created in code have no path; ones created inside another file have "::" in theirs.
static func can_reference(resource: Resource) -> bool:
	return resource != null and not resource.resource_path.is_empty() \
		and not resource.resource_path.contains("::")


## A reference to `resource`: {"uid": "uid://...", "path": "res://..."}.
## Returns {} (with an error) when the resource isn't its own file, since a
## reference to it couldn't be loaded back.
static func to_dict(resource: Resource) -> Dictionary:
	if not can_reference(resource):
		var description := "null" if resource == null else "'%s'" % resource.resource_path
		push_error("Can't save a reference to %s: it isn't saved as its own file." % description)
		return {}
	var ref := {"path": resource.resource_path}
	var uid := ResourceLoader.get_resource_uid(resource.resource_path)
	if uid != ResourceUID.INVALID_ID:
		ref["uid"] = ResourceUID.id_to_text(uid)
	return ref


## Loads the resource a reference points at, trying the UID first and then the path.
## Returns null (with a warning) when neither loads, or the result isn't an
## `expected_type` (a class such as UnitData). Checks before loading, so a bad
## reference never raises an engine error.
static func load_from(ref: Variant, expected_type: Script) -> Resource:
	if not ref is Dictionary:
		push_warning("Save data: a resource reference isn't a dictionary.")
		return null
	var uid_text: Variant = ref.get("uid")
	if typeof(uid_text) == TYPE_STRING:
		var loaded := _load_checked(_path_for_uid(uid_text), expected_type)
		if loaded != null:
			return loaded
	var path: Variant = ref.get("path")
	if typeof(path) == TYPE_STRING:
		var loaded := _load_checked(path, expected_type)
		if loaded != null:
			return loaded
	push_warning("Save data: can't load reference %s as %s." % [ref, expected_type.get_global_name()])
	return null


## The path a "uid://..." string points at, or "" when it isn't a known UID.
static func _path_for_uid(uid_text: String) -> String:
	if not uid_text.begins_with("uid://"):
		return ""
	var id := ResourceUID.text_to_id(uid_text)
	if id == ResourceUID.INVALID_ID or not ResourceUID.has_id(id):
		return ""
	return ResourceUID.get_id_path(id)


## Loads `path` only if it's a project file (res://, not embedded) that exists and
## holds an `expected_type`. Save files are user-editable, so never load other paths.
static func _load_checked(path: String, expected_type: Script) -> Resource:
	if not path.begins_with("res://") or path.contains("::") or not ResourceLoader.exists(path):
		return null
	var loaded := load(path)
	if loaded == null or not is_instance_of(loaded, expected_type):
		return null
	return loaded
