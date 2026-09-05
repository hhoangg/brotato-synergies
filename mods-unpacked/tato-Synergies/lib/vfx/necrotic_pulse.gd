extends Node2D

# Necrotic pulse VFX for Lich's Death Pulse.
# Combines a dark corruption pool on the ground with a jagged tendril ring.
# Spawned at player position in world space, auto-frees when done.

var max_radius: float = 350.0
var ring_tint = null   # optional Color override for the main ring + tendrils (null = use the const green)

var _time: float = 0.0
var _tendril_angles: Array = []
var _tendril_lengths: Array = []
var _tendril_offsets: Array = []

const EXPAND_DURATION: float = 0.5
const LINGER_DURATION: float = 0.6
const TOTAL_DURATION: float = 1.1  # EXPAND + LINGER
const ELLIPSE_POINTS: int = 48
const RING_THICKNESS: float = 6.0
const TENDRIL_COUNT: int = 16
const TENDRIL_MIN_LEN: float = 15.0
const TENDRIL_MAX_LEN: float = 40.0

# Necrotic colors
const POOL_COLOR = Color(0.08, 0.12, 0.05, 1.0)
const RING_COLOR_INNER = Color(0.5, 0.85, 0.2, 1.0)
const RING_COLOR_OUTER = Color(0.25, 0.15, 0.4, 1.0)
const TENDRIL_COLOR = Color(0.35, 0.6, 0.15, 1.0)


func _ready() -> void:
	z_index = 1
	# Pre-generate random tendril data
	for _i in TENDRIL_COUNT:
		_tendril_angles.append(rand_range(0, TAU))
		_tendril_lengths.append(rand_range(TENDRIL_MIN_LEN, TENDRIL_MAX_LEN))
		_tendril_offsets.append(rand_range(-0.15, 0.15))  # angular wobble


func _process(delta: float) -> void:
	_time += delta
	if _time >= TOTAL_DURATION:
		queue_free()
		return
	update()


func _draw() -> void:
	var expand_t = clamp(_time / EXPAND_DURATION, 0.0, 1.0)
	var ease_t = 1.0 - pow(1.0 - expand_t, 3.0)

	var rx = max_radius * ease_t
	var ry = rx * 0.5

	if rx < 3.0:
		return

	# Fade out during linger phase
	var fade = 1.0
	if _time > EXPAND_DURATION:
		fade = 1.0 - clamp((_time - EXPAND_DURATION) / LINGER_DURATION, 0.0, 1.0)

	# --- Layer 1: Dark corruption pool on the ground ---
	var pool_alpha = fade * 0.18
	var pool_color = Color(POOL_COLOR.r, POOL_COLOR.g, POOL_COLOR.b, pool_alpha)
	_draw_filled_ellipse(Vector2.ZERO, rx * 0.95, ry * 0.95, pool_color)

	# Slightly brighter edge to the pool
	var pool_edge_alpha = fade * 0.1
	var pool_edge_color = Color(0.15, 0.25, 0.08, pool_edge_alpha)
	_draw_ring(Vector2.ZERO, rx * 0.92, ry * 0.92, 12.0, pool_edge_color)

	# --- Layer 2: Jagged tendril ring ---
	# Outer glow (purple tint, wide)
	var glow_alpha = fade * 0.2
	var glow_color = Color(RING_COLOR_OUTER.r, RING_COLOR_OUTER.g, RING_COLOR_OUTER.b, glow_alpha)
	_draw_ring(Vector2.ZERO, rx, ry, RING_THICKNESS * 3.5, glow_color)

	# Main ring (sickly green, or the caller's tint)
	var ring_base = ring_tint if (ring_tint is Color) else RING_COLOR_INNER
	var main_alpha = fade * 0.8
	var main_color = Color(ring_base.r, ring_base.g, ring_base.b, main_alpha)
	_draw_ring(Vector2.ZERO, rx, ry, RING_THICKNESS, main_color)

	# --- Layer 3: Decay tendrils radiating outward ---
	for i in TENDRIL_COUNT:
		var angle = _tendril_angles[i] + _tendril_offsets[i] * sin(_time * 3.0)
		var tendril_len = _tendril_lengths[i] * ease_t
		var tendril_alpha = fade * 0.7

		# Tendril starts at ring edge, extends outward
		var start_x = cos(angle) * rx
		var start_y = sin(angle) * ry
		var end_x = cos(angle) * (rx + tendril_len)
		var end_y = sin(angle) * (ry + tendril_len * 0.5)

		var tendril_base = ring_tint if (ring_tint is Color) else TENDRIL_COLOR
		var t_color = Color(tendril_base.r, tendril_base.g, tendril_base.b, tendril_alpha)
		draw_line(Vector2(start_x, start_y), Vector2(end_x, end_y), t_color, 2.0)

		# Small branch off each tendril
		var mid_x = (start_x + end_x) * 0.6
		var mid_y = (start_y + end_y) * 0.6
		var branch_angle = angle + (0.4 if i % 2 == 0 else -0.4)
		var branch_len = tendril_len * 0.4
		var branch_end_x = mid_x + cos(branch_angle) * branch_len
		var branch_end_y = mid_y + sin(branch_angle) * branch_len * 0.5

		var branch_color = Color(tendril_base.r, tendril_base.g, tendril_base.b, tendril_alpha * 0.5)
		draw_line(Vector2(mid_x, mid_y), Vector2(branch_end_x, branch_end_y), branch_color, 1.5)

	# --- Layer 4: Center flash (brief sickly green flash) ---
	if _time < 0.12:
		var flash_t = _time / 0.12
		var flash_a = (1.0 - flash_t) * 0.4
		var flash_c = Color(0.4, 0.7, 0.2, flash_a)
		_draw_filled_ellipse(Vector2.ZERO, 50.0, 25.0, flash_c)


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
