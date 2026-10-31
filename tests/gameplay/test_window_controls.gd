extends GutTest

const WindowControlsScript := preload("res://gameplay/window_controls.gd")


func _scale(usable: Vector2i) -> int:
	return WindowControlsScript.best_window_scale(usable)


func test_retina_macbook_picks_4x() -> void:
	# 14" MacBook Pro: 1512x945 points of usable space at screen scale 2.
	assert_eq(_scale(Vector2i(3024, 1890)), 4)


func test_1080p_monitor_picks_2x() -> void:
	# 3x (1920x1080) would cover the whole screen, more than the 85% allowed.
	assert_eq(_scale(Vector2i(1920, 1040)), 2)


func test_4k_monitor_picks_5x() -> void:
	assert_eq(_scale(Vector2i(3840, 2120)), 5)


func test_tiny_screen_still_gets_1x() -> void:
	assert_eq(_scale(Vector2i(320, 200)), 1)


func test_tall_screen_is_limited_by_width() -> void:
	assert_eq(_scale(Vector2i(1440, 2560)), 1)


func test_fill_fraction_is_respected() -> void:
	assert_eq(WindowControlsScript.best_window_scale(Vector2i(1920, 1080), Vector2i(640, 360), 1.0), 3)
