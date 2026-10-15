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
