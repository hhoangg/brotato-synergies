extends Node2D

# Precision Kill activation VFX.
# Four crosshair lines snap inward toward center + brief inner circle pulse.
# Spawned at player position in world space, auto-frees when done.

var flash_color: Color = Color(1.0, 0.15, 0.1, 1.0)

var _time: float = 0.0

const SNAP_DURATION: float = 0.15
const HOLD_DURATION: float = 0.1
const FADE_DURATION: float = 0.15
const TOTAL_LIFE: float = 0.4

const LINE_START_DIST: float = 120.0
const LINE_END_DIST: float = 18.0
const LINE_LENGTH: float = 30.0
const LINE_WIDTH: float = 2.5
const CIRCLE_RADIUS: float = 12.0


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	_time += delta
	if _time >= TOTAL_LIFE:
		queue_free()
		return
	update()


func _draw() -> void:
	var snap_t = clamp(_time / SNAP_DURATION, 0.0, 1.0)
	var ease_t = 1.0 - pow(1.0 - snap_t, 3.0)

	var fade_start = SNAP_DURATION + HOLD_DURATION
	var alpha = 1.0
	if _time > fade_start:
		alpha = 1.0 - clamp((_time - fade_start) / FADE_DURATION, 0.0, 1.0)

	var dist = lerp(LINE_START_DIST, LINE_END_DIST, ease_t)

	var c = Color(flash_color.r, flash_color.g, flash_color.b, alpha * 0.9)
	var glow_c = Color(flash_color.r, flash_color.g, flash_color.b, alpha * 0.3)

	# Four crosshair arms converging inward
	var directions = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	for dir in directions:
		var start = dir * dist
		var end = dir * (dist + LINE_LENGTH)
		# Glow line (wider, faint)
		draw_line(start, end, glow_c, LINE_WIDTH * 3.0)
		# Core line
		draw_line(start, end, c, LINE_WIDTH)

	# Inner circle pulse
	var circle_alpha = alpha * 0.6
	if snap_t < 1.0:
		circle_alpha *= snap_t
	var circle_c = Color(flash_color.r, flash_color.g, flash_color.b, circle_alpha)
	_draw_circle_outline(Vector2.ZERO, CIRCLE_RADIUS, circle_c, 1.5)

	# Center dot on lock-in
	if snap_t >= 0.8:
		var dot_a = alpha * 0.7
		draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0, dot_a))


func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points = 32
	var prev = center + Vector2(radius, 0.0)
	for i in range(1, points + 1):
		var angle = TAU * float(i) / float(points)
		var next = center + Vector2(cos(angle) * radius, sin(angle) * radius)
		draw_line(prev, next, color, width)
		prev = next
