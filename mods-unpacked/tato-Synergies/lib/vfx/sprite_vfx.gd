extends Node2D

# Generic Vivid-Motions spritesheet VFX player.
#
# Plays a status-effect spritesheet (a 4x4 grid of 64x64 frames, the format shipped in
# assets/vfx/Vivid_Motion_23_…) as a frame animation. Raw mod PNGs aren't import-cooked, so
# load("res://…png") FAILS — we read the bytes and decode with load_png_from_buffer (the exact
# pattern proven in skill_hud._icon_for), cached per sheet path so each effect decodes once.
#
# Two modes:
#   * oneshot (loop=false): plays the 16 frames once, then frees itself — a cast burst.
#   * loop   (loop=true):   loops the frames; if life>0 it fades out + frees after `life` secs —
#                           a status indicator that clings to a player for a buff's duration.
#
# Parent it to a player node (position stays ZERO) to FOLLOW the player, or add it to the world
# entities layer at a global_position for a fixed-point burst.

const _CACHE := {}   # sheet_path -> ImageTexture | null  (const dict = one shared cache for the run)

var sheet_path : String = ""
var frame_w : int = 64
var frame_h : int = 64
var columns : int = 4
var frame_count : int = 16
var fps : float = 24.0
var loop : bool = false
var life : float = 0.0          # loop only: >0 → auto fade+free after this many secs
var tint : Color = Color.white
var sprite_scale : float = 1.0
var y_offset : float = 0.0      # lift the sprite onto the body instead of the feet

var _sprite : Sprite = null
var _frame : int = 0
var _accum : float = 0.0
var _time : float = 0.0
var _fading : bool = false


# Decode (or fetch cached) the spritesheet texture. Nearest filtering (flags 0) — matches the
# game's pixel look AND avoids region-rect edge bleed between adjacent cells of the sheet.
static func _load_sheet(path: String):
	if _CACHE.has(path):
		return _CACHE[path]
	var tex = null
	var fh := File.new()
	if fh.file_exists(path) and fh.open(path, File.READ) == OK:
		var buf := fh.get_buffer(fh.get_len())
		fh.close()
		var img := Image.new()
		if img.load_png_from_buffer(buf) == OK:
			var t := ImageTexture.new()
			t.create_from_image(img, 0)
			tex = t
	_CACHE[path] = tex
	return tex


func _ready() -> void:
	z_as_relative = true
	var tex = _load_sheet(sheet_path)
	if tex == null:
		# missing/undecodable sheet → don't leave an invisible node ticking forever
		queue_free()
		return
	_sprite = Sprite.new()
	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.centered = true
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_sprite.position = Vector2(0.0, y_offset)
	_sprite.modulate = tint
	add_child(_sprite)
	_set_region(0)


func _set_region(i: int) -> void:
	var col = i % columns
	var row = int(i / columns)
	_sprite.region_rect = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_time += delta
	if loop and life > 0.0 and not _fading and _time >= life:
		_fade_out()
	_accum += delta
	var step : float = 1.0 / max(fps, 1.0)
	while _accum >= step:
		_accum -= step
		_frame += 1
		if _frame >= frame_count:
			if loop:
				_frame = 0
			else:
				queue_free()
				return
		_set_region(_frame)


func _fade_out() -> void:
	if _fading:
		return
	_fading = true
	var tw := Tween.new()
	add_child(tw)
	tw.interpolate_property(self, "modulate:a", modulate.a, 0.0, 0.25, Tween.TRANS_QUAD, Tween.EASE_IN)
	tw.connect("tween_all_completed", self, "queue_free")
	tw.start()
