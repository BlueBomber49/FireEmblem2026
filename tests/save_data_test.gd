extends GutTest
## Base for tests of tolerant save loading.
##
## GUT fails a test on any engine error, and it counts push_warning as one. Tolerant
## loading deliberately warns (every message starts with "Save data:"), so these
## helpers mark those warnings as expected. Any other error still fails the test.
## Not collected as a test itself because its name doesn't start with "test_".

const WARNING_PREFIX := "Save data:"


## Passes if at least one save-data warning happened, and marks them all as expected.
func assert_save_warning(msg := "") -> void:
	assert_gt(_handle_save_warnings(), 0, "expected a '%s' warning. %s" % [WARNING_PREFIX, msg])


## Marks any save-data warnings as expected, without requiring one.
func allow_save_warnings() -> void:
	_handle_save_warnings()


## Fails if any save-data warning happened.
func assert_no_save_warnings(msg := "") -> void:
	var count := 0
	for err in get_errors():
		if err.is_engine_error() and err.contains_text(WARNING_PREFIX):
			count += 1
	assert_eq(count, 0, "expected no '%s' warnings. %s" % [WARNING_PREFIX, msg])


func _handle_save_warnings() -> int:
	var count := 0
	for err in get_errors():
		if err.is_engine_error() and err.contains_text(WARNING_PREFIX) and not err.handled:
			err.handled = true
			count += 1
	return count
