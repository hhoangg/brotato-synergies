extends Node2D

# Expanding isometric ring + center flash for Arcane Eruption.
# Spawned at player position in world space, auto-frees when done.

var ring_color: Color = Color(0.7, 0.3, 1.0, 1.0)
var max_radius: float = 500.0

var _time: float = 0.0
var _flash_alpha: float = 1.0

const EXPAND_DURATION: float = 0.4
const RING_THICKNESS: float = 8.0
const ELLIPSE_POINTS: int = 48
const FLASH_RADIUS: float = 60.0


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	_time += delta
	if _time >= EXPAND_DURATION + 0.3:
		queue_free()
		return
	update()


func _draw() -> void:
	var t = clamp(_time / EXPAND_DURATION, 0.0, 1.0)
	# Ease out for satisfying expansion
	var ease_t = 1.0 - pow(1.0 - t, 3.0)

	var rx = max_radius * ease_t
	var ry = rx * 0.5  # isometric squish

	# Center flash (fades fast)
	if _time < 0.15:
		var flash_t = _time / 0.15
		var flash_a = (1.0 - flash_t) * 0.6
		var flash_c = Color(1.0, 1.0, 1.0, flash_a)
		_draw_filled_ellipse(Vector2.ZERO, FLASH_RADIUS, FLASH_RADIUS * 0.5, flash_c)

	if rx < 2.0:
		return

	# Outer glow ring (wider, faint)
	var fade = 1.0 - clamp((_time - EXPAND_DURATION * 0.5) / (EXPAND_DURATION * 0.5 + 0.3), 0.0, 1.0)
	var glow_alpha = fade * 0.25
	var glow_color = Color(ring_color.r, ring_color.g, ring_color.b, glow_alpha)
	_draw_ring(Vector2.ZERO, rx, ry, RING_THICKNESS * 3.0, glow_color)

	# Main ring
	var main_alpha = fade * 0.9
	var main_color = Color(ring_color.r, ring_color.g, ring_color.b, main_alpha)
	_draw_ring(Vector2.ZERO, rx, ry, RING_THICKNESS, main_color)

	# Inner bright edge
	var inner_alpha = fade * 0.7
	var bright = Color(
		min(ring_color.r * 1.5, 1.0),
		min(ring_color.g * 1.5, 1.0),
		min(ring_color.b * 1.5, 1.0),
		inner_alpha
	)
	_draw_ring(Vector2.ZERO, rx * 0.97, ry * 0.97, RING_THICKNESS * 0.5, bright)


func _draw_ring(center: Vector2, rx: float, ry: float, thickness: float, color: Color) -> void:
	if rx < 1.0 or ry < 1.0:
		return
	var outer_points = PoolVector2Array()
	var inner_points = PoolVector2Array()
	var inner_rx = max(rx - thickness, 0.0)
	var inner_ry = max(ry - thickness * 0.5, 0.0)
	for i in range(ELLIPSE_POINTS + 1):
		var angle = TAU * float(i) / float(ELLIPSE_POINTS)
		outer_points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		inner_points.append(center + Vector2(cos(angle) * inner_rx, sin(angle) * inner_ry))

	# Draw as triangle strip using polygon pairs
	for i in ELLIPSE_POINTS:
		var quad = PoolVector2Array([
			outer_points[i], outer_points[i + 1],
			inner_points[i + 1], inner_points[i]
		])
		draw_colored_polygon(quad, color)


func _draw_filled_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points = PoolVector2Array()
	for i in ELLIPSE_POINTS:
		var angle = TAU * float(i) / float(ELLIPSE_POINTS)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, color)
