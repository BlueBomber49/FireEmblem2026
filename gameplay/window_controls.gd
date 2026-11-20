extends Node
## Autoload: window-level behaviour that applies to every scene.
##
## The game renders at a fixed BASE_SIZE (640x360, set in project.godot) and the
## "viewport" stretch scales that image up by whole multiples, with black bars
## filling any leftover space, so pixel art stays crisp at any window size.
##
## At startup the window is sized to the largest whole multiple of BASE_SIZE
## that comfortably fits the screen. Sizes are in physical pixels: on a Mac
## retina screen (screen scale 2) a 1280x720 window would look half-size, so
## working from the screen's usable rect in pixels picks the right multiple on
## both retina and ordinary displays. The window is re-fitted when it moves to
## a screen with a different scale (e.g. laptop to external monitor).
##
## When the game runs embedded in the editor's Game tab this code can't size
## the window. The tab starts the game at the project's window size override
## (2560x1440 physical pixels) and shrinks it to fit the tab, keeping the aspect
## ratio. Without the override it would use 640x360, which is tiny on retina.
##
## F11 (or Alt+Enter) toggles fullscreen.
## F3 toggles a window/scale readout for debugging stretch problems.

const BASE_SIZE := Vector2i(640, 360)
## How much of the screen's usable area the startup window may cover.
const SCREEN_FILL := 0.85

var _debug: Label


## The largest whole scale n >= 1 at which `base * n` fits inside `usable * fill`.
static func best_window_scale(usable: Vector2i, base: Vector2i = BASE_SIZE, fill: float = SCREEN_FILL) -> int:
	var room := Vector2(usable) * fill
	var n := int(floor(minf(room.x / base.x, room.y / base.y)))
	return maxi(n, 1)


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_debug = Label.new()
	_debug.visible = false
	_debug.position = Vector2(2, 2)
	_debug.theme = preload("res://resources/ui_theme.tres")
	_debug.add_theme_constant_override("outline_size", 2)
	layer.add_child(_debug)

	if _can_resize_window():
		var window := get_window()
		window.min_size = BASE_SIZE
		fit_window_to_screen()
		window.dpi_changed.connect(fit_window_to_screen)


## Sizes the window to the best whole multiple of BASE_SIZE for its current
## screen and centres it there. Does nothing outside windowed mode.
func fit_window_to_screen() -> void:
	var window := get_window()
	if window.mode != Window.MODE_WINDOWED:
		return
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var size := BASE_SIZE * best_window_scale(usable.size)
	window.size = size
	window.position = usable.position + (usable.size - size) / 2


## False when there is no real window to size: headless test runs, and the
## game embedded in the editor's Game tab.
func _can_resize_window() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return not Engine.is_embedded_in_editor()


func _process(_delta: float) -> void:
	if not _debug.visible:
		return
	var window := get_window()
	var vp := window.get_visible_rect().size
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	_debug.text = "window %s px   screen %d scale %.2f   usable %s\nviewport %s   stretch %s / aspect %s\nscale %dx   mode %s" % [
		window.size, window.current_screen, DisplayServer.screen_get_scale(window.current_screen), usable.size,
		vp, _scale_mode_name(window.content_scale_mode), _aspect_name(window.content_scale_aspect),
		_current_scale(window), _mode_name(window.mode),
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


## The whole multiple the integer stretch is drawing BASE_SIZE at.
func _current_scale(window: Window) -> int:
	return maxi(1, mini(window.size.x / BASE_SIZE.x, window.size.y / BASE_SIZE.y))


func _mode_name(mode: Window.Mode) -> String:
	return ["windowed", "minimized", "maximized", "fullscreen", "exclusive fullscreen"][mode]


func _scale_mode_name(mode: Window.ContentScaleMode) -> String:
	return ["disabled", "canvas_items", "viewport"][mode]


func _aspect_name(aspect: Window.ContentScaleAspect) -> String:
	return ["ignore", "keep", "keep_width", "keep_height", "expand"][aspect]
