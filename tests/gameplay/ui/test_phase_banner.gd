extends GutTest

const PhaseBannerScene: PackedScene = preload("res://gameplay/ui/phase_banner.tscn")

var _banner: PhaseBanner


func before_each() -> void:
	_banner = PhaseBannerScene.instantiate() as PhaseBanner
	_banner.slide_time = 0.05
	_banner.hold_time = 0.1
	add_child_autofree(_banner)


func _title() -> TextureRect:
	return _banner.get_node("%Title") as TextureRect


func _band() -> PanelContainer:
	return _banner.get_node("%Band") as PanelContainer


func _confirm() -> void:
	var event := InputEventAction.new()
	event.action = &"confirm"
	event.pressed = true
	_banner._unhandled_input(event)


func test_starts_hidden_and_lets_the_mouse_through() -> void:
	assert_false(_banner.visible)
	assert_false(_banner.is_playing())
	assert_eq(_banner.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_player_phase_art_and_color() -> void:
	_banner.play(TurnLoop.Phase.PLAYER)
	assert_true(_banner.is_playing())
	assert_eq(_title().texture, PhaseBanner.ART[TurnLoop.Phase.PLAYER])
	assert_eq(_band().theme_type_variation, &"PhaseBannerPlayer")
	assert_eq(_banner.mouse_filter, Control.MOUSE_FILTER_STOP, "blocks the map while up")


func test_enemy_phase_art_and_color() -> void:
	_banner.play(TurnLoop.Phase.ENEMY)
	assert_eq(_title().texture, PhaseBanner.ART[TurnLoop.Phase.ENEMY])
	assert_eq(_band().theme_type_variation, &"PhaseBannerEnemy")


func test_the_art_is_pixel_crisp_at_a_whole_scale() -> void:
	assert_eq(_title().texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	for art: Texture2D in PhaseBanner.ART.values():
		assert_eq(art.get_size() * 3, _title().custom_minimum_size, "%s is 240x32" % art.resource_path)


func test_finishes_after_sliding_in_holding_and_sliding_out() -> void:
	watch_signals(_banner)
	_banner.play(TurnLoop.Phase.PLAYER)
	await wait_seconds(0.1)
	assert_true(_banner.is_playing(), "still up during the hold")
	await wait_for_signal(_banner.finished, 1.0)
	assert_signal_emitted(_banner, "finished")
	assert_false(_banner.visible)
	assert_eq(_banner.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_play_can_be_awaited() -> void:
	await _banner.play(TurnLoop.Phase.ENEMY)
	assert_false(_banner.is_playing())
	# The await resumes inside the banner's finished signal; step out of it so
	# GUT doesn't free the banner mid-emit.
	await get_tree().process_frame


func test_confirm_skips_to_the_slide_out() -> void:
	_banner.hold_time = 10.0
	watch_signals(_banner)
	_banner.play(TurnLoop.Phase.PLAYER)
	_confirm()
	await wait_for_signal(_banner.finished, 1.0)
	assert_signal_emitted(_banner, "finished", "didn't wait out the 10s hold")


func test_skipping_twice_still_finishes_once() -> void:
	_banner.hold_time = 10.0
	watch_signals(_banner)
	_banner.play(TurnLoop.Phase.PLAYER)
	_banner.skip()
	_banner.skip()
	await wait_seconds(0.2)
	assert_signal_emit_count(_banner, "finished", 1)


func test_a_click_skips_too() -> void:
	_banner.hold_time = 10.0
	watch_signals(_banner)
	_banner.play(TurnLoop.Phase.PLAYER)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_banner._gui_input(click)
	await wait_for_signal(_banner.finished, 1.0)
	assert_signal_emitted(_banner, "finished")
