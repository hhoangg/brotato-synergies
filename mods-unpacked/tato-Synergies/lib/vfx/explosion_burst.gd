extends Node2D

# Fiery explosion VFX for Bomb Drop.
# Expanding fireball with ember particles and heat shimmer ring.
# Distinct from stomp_shockwave (earthy ground cracks) — this is fire/combustion.

var explosion_color: Color = Color(1.0, 0.5, 0.1, 1.0)  # orange
var flash_color: Color = Color(1.0, 0.95, 0.7, 1.0)      # bright white-yellow
var max_radius: float = 100.0

var _time: float = 0.0
var _embers: Array = []

const EXPAND_DURATION: float = 0.15
const FADE_DURATION: float = 0.35
const TOTAL_LIFE: float = 0.5
const EMBER_COUNT: int = 14
const ELLIPSE_POINTS: int = 32


func _ready() -> void:
	z_index = 3
	_generate_embers()


func _process(delta: float) -> void:
	_time += delta
	if _time >= TOTAL_LIFE:
		queue_free()
		return

	for e in _embers:
		if e["life"] > 0.0:
			e["life"] -= delta
			e["vx"] *= 0.88
			e["vy"] *= 0.88
			e["vy"] -= 30.0 * delta  # embers rise
			e["x"] += e["vx"] * delta
			e["y"] += e["vy"] * delta

	update()


func _draw() -> void:
	var expand_t = clamp(_time / EXPAND_DURATION, 0.0, 1.0)
	var ease_t = 1.0 - pow(1.0 - expand_t, 2.0)
	var global_fade = 1.0 - clamp((_time - EXPAND_DURATION) / FADE_DURATION, 0.0, 1.0)

	var rx = max_radius * ease_t
	var ry = rx * 0.5  # isometric

	# --- Central fireball (bright core fading to orange) ---
	if rx > 2.0:
		# Outer orange glow
		var outer_a = global_fade * 0.4
		var outer_c = Color(explosion_color.r, explosion_color.g * 0.5, 0.0, outer_a)
		_draw_filled_ellipse(Vector2.ZERO, rx * 0.7, ry * 0.7, outer_c)

		# Inner bright flash
		var flash_t = clamp(_time / 0.1, 0.0, 1.0)
		var flash_a = (1.0 - flash_t) * 0.9
		var inner_rx = rx * 0.4 * (1.0 - flash_t * 0.5)
		var inner_ry = ry * 0.4 * (1.0 - flash_t * 0.5)
		_draw_filled_ellipse(Vector2.ZERO, inner_rx, inner_ry, Color(flash_color.r, flash_color.g, flash_color.b, flash_a))

	# --- Heat shimmer ring (expanding thin ring) ---
	if rx > 4.0:
		var ring_a = global_fade * 0.6
		var ring_c = Color(explosion_color.r, explosion_color.g, explosion_color.b, ring_a)
		_draw_ring(Vector2.ZERO, rx, ry, 3.0, ring_c)

		# Brighter edge
		var edge_a = global_fade * 0.3
		var edge_c = Color(1.0, 0.8, 0.3, edge_a)
		_draw_ring(Vector2.ZERO, rx * 1.05, ry * 1.05, 1.5, edge_c)

	# --- Ember particles (rise upward) ---
	for e in _embers:
		if e["life"] <= 0.0:
			continue
		var t = e["life"] / e["max_life"]
		var c: Color = e["color"]
		c.a = t * 0.9
		var sz: float = e["size"] * (0.3 + t * 0.7)
		draw_circle(Vector2(e["x"], e["y"]), sz, c)


func _generate_embers() -> void:
	for i in EMBER_COUNT:
		var angle = TAU * float(i) / float(EMBER_COUNT) + rand_range(-0.3, 0.3)
		var speed = rand_range(80.0, 200.0)
		var life = rand_range(0.25, 0.45)
		# Embers are orange to yellow to red
		var t = randf()
		var color: Color
		if t < 0.4:
			color = Color(1.0, 0.6, 0.1, 1.0)  # orange
		elif t < 0.7:
			color = Color(1.0, 0.85, 0.2, 1.0)  # yellow
		else:
			color = Color(1.0, 0.25, 0.05, 1.0)  # deep red
		_embers.append({
			"x": rand_range(-5.0, 5.0),
			"y": rand_range(-3.0, 3.0),
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed * 0.5,
			"life": life,
			"max_life": life,
			"size": rand_range(2.0, 4.0),
			"color": color,
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
