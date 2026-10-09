class_name SpriteFramesBuilder
extends RefCounted
## Builds SpriteFrames for the Fantasy Battle Pack sheets in code, so no
## .tres needs authoring per class/colour and every unit on the same sheet
## shares one SpriteFrames.

const FRAME_SIZE := Vector2i(32, 32)
const FRAME_COUNT := 4
const IDLE_FPS := 5.0
const WALK_FPS := 10.0

## Animation name -> row (y offset in pixels) in every sheet.
const ROWS := {
	&"idle_side": 0,
	&"walk_side": 32,
	&"idle_down": 160,
	&"walk_down": 192,
	&"idle_up": 320,
	&"walk_up": 352,
}

static var _cache: Dictionary = {}


static func for_sheet(sheet_path: String) -> SpriteFrames:
	if not _cache.has(sheet_path):
		_cache[sheet_path] = build(sheet_path)
	return _cache[sheet_path]


static func build(sheet_path: String) -> SpriteFrames:
	var sheet := load(sheet_path) as Texture2D
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in ROWS:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, WALK_FPS if String(anim).begins_with("walk") else IDLE_FPS)
		for i in FRAME_COUNT:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(i * FRAME_SIZE.x, ROWS[anim], FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame(anim, frame)
	return frames
