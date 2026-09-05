extends Node2D

# Energy burst shockwave VFX for Weapon Echo combo finisher.
# Clean white/cyan energy ring with radial slash marks — weapon energy, not earth.
# Distinct from stomp_shockwave (earthy cracks) and explosion_burst (fire).

var energy_color: Color = Color(0.85, 0.9, 1.0, 1.0)  # white-cyan
var max_radius: float = 250.0

var _time: float = 0.0
var _slashes: Array = []

const EXPAND_DURATION: float = 0.25
const FADE_DURATION: float = 0.3
const TOTAL_LIFE: float = 0.55
const SLASH_COUNT: int = 6
const ELLIPSE_POINTS: int = 36


func _ready() -> void:
	z_index = 3
	_generate_slashes()


func _process(delta: float) -> void:
	_time += delta
	if _time >= TOTAL_LIFE:
		queue_free()
		return
	update()


func _draw() -> void:
	var expand_t = clamp(_time / EXPAND_DURATION, 0.0, 1.0)
	var ease_t = 1.0 - pow(1.0 - expand_t, 3.0)
	var fade = 1.0 - clamp((_time - EXPAND_DURATION * 0.6) / FADE_DURATION, 0.0, 1.0)

	var rx = max_radius * ease_t
	var ry = rx * 0.5

	# --- Central energy flash ---
	if _time < 0.1:
		var flash_a = (1.0 - _time / 0.1) * 0.7
		_draw_filled_ellipse(Vector2.ZERO, 40.0, 20.0, Color(1.0, 1.0, 1.0, flash_a))

	# --- Main energy ring (double ring — bright inner, softer outer) ---
	if rx > 3.0:
		# Outer glow
		var glow_a = fade * 0.2
		var glow_c = Color(energy_color.r, energy_color.g, energy_color.b, glow_a)
		_draw_ring(Vector2.ZERO, rx, ry, 8.0, glow_c)

		# Main ring
		var main_a = fade * 0.85
		var main_c = Color(energy_color.r, energy_color.g, energy_color.b, main_a)
		_draw_ring(Vector2.ZERO, rx, ry, 2.5, main_c)

		# Inner bright edge
		var inner_rx = rx * 0.92
		var inner_ry = ry * 0.92
		var inner_a = fade * 0.5
		var inner_c = Color(1.0, 1.0, 1.0, inner_a)
		_draw_ring(Vector2.ZERO, inner_rx, inner_ry, 1.5, inner_c)

	# --- Radial slash marks (weapon energy lines) ---
	for slash in _slashes:
		var slash_expand = clamp((_time - slash["delay"]) / 0.15, 0.0, 1.0)
		if slash_expand <= 0.0:
			continue
		var slash_fade = fade * slash_expand

		var angle = slash["angle"]
		var len_start = max_radius * 0.3 * ease_t
		var len_end = max_radius * slash["length"] * ease_t
		var start = Vector2(cos(angle) * len_start, sin(angle) * len_start * 0.5)
		var end = Vector2(cos(angle) * len_end, sin(angle) * len_end * 0.5)

		var slash_c = Color(energy_color.r, energy_color.g, energy_color.b, slash_fade * 0.7)
		draw_line(start, end, slash_c, slash["width"])

		# Bright tip
		var tip_c = Color(1.0, 1.0, 1.0, slash_fade * 0.5)
		draw_circle(end, slash["width"] * 0.8, tip_c)


func _generate_slashes() -> void:
	for i in SLASH_COUNT:
		var base_angle = TAU * float(i) / float(SLASH_COUNT) + rand_range(-0.15, 0.15)
		_slashes.append({
			"angle": base_angle,
			"length": rand_range(0.6, 0.95),
			"width": rand_range(1.5, 3.0),
			"delay": rand_range(0.0, 0.08),
		})


func _draw_ring(center: Vector2, rx: float, ry: float, thickness: float, color: Color) -> void:
	if rx < 1.0 or ry < 1.0:
		return
	var outer = PoolVector2Array()
	var inner = PoolVector2Array()
	var irx = max(rx - thickness, 0.0)
	var iry = max(ry - thickness * 0.5, 0.0)
	for i in range(ELLIPSE_POINTS + 1):
		var angle = TAU * float(i) / float(ELLIPSE_POINTS)
		outer.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		inner.append(center + Vector2(cos(angle) * irx, sin(angle) * iry))
	for i in ELLIPSE_POINTS:
		var quad = PoolVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]])
		draw_colored_polygon(quad, color)


func _draw_filled_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points = PoolVector2Array()
	for i in ELLIPSE_POINTS:
		var angle = TAU * float(i) / float(ELLIPSE_POINTS)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, color)
