extends Node
## Autoload: window-level shortcuts that apply to every scene.
## F11 (or Alt+Enter) toggles fullscreen; the game's 640x360 viewport
## stretches to fill whatever size the window ends up at.
## F3 toggles a window/scale readout for debugging stretch problems.

var _debug: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_debug = Label.new()
	_debug.visible = false
	_debug.position = Vector2(4, 4)
	_debug.add_theme_color_override("font_color", Color.WHITE)
	_debug.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug.add_theme_constant_override("outline_size", 4)
	layer.add_child(_debug)


func _process(_delta: float) -> void:
	if not _debug.visible:
		return
	var window := get_window()
	var vp := window.get_visible_rect().size
	_debug.text = "window %s px   screen scale %.2f\nviewport %s   stretch %s / aspect %s\ncontent scale factor %.2f   mode %s" % [
		window.size, DisplayServer.screen_get_scale(),
		vp, _scale_mode_name(window.content_scale_mode), _aspect_name(window.content_scale_aspect),
		window.size.x / vp.x, _mode_name(window.mode),
	]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F3:
		_debug.visible = not _debug.visible
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var window := get_window()
	var fullscreen := window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	window.mode = Window.MODE_WINDOWED if fullscreen else Window.MODE_FULLSCREEN


func _mode_name(mode: Window.Mode) -> String:
	return ["windowed", "minimized", "maximized", "fullscreen", "exclusive fullscreen"][mode]


func _scale_mode_name(mode: Window.ContentScaleMode) -> String:
	return ["disabled", "canvas_items", "viewport"][mode]


func _aspect_name(aspect: Window.ContentScaleAspect) -> String:
	return ["ignore", "keep", "keep_width", "keep_height", "expand"][aspect]
