extends Node2D

# Stone scatter VFX for Crumble.
# Chunks of stone rip outward and tumble, leaving a cracked zone.
# Distinct from stomp_shockwave (ring + ground cracks) — this is physical debris.

var scatter_color: Color = Color(0.55, 0.4, 0.25, 1.0)  # stone brown
var max_radius: float = 200.0
var below_50: bool = false  # red tint when Golem is berserk

var _time: float = 0.0
var _chunks: Array = []
var _dust: Array = []

const SCATTER_DURATION: float = 0.3
const LINGER_DURATION: float = 0.5
const TOTAL_LIFE: float = 0.8
const CHUNK_COUNT: int = 10
const DUST_COUNT: int = 20


func _ready() -> void:
	z_index = 1
	_generate_chunks()
	_generate_dust()


func _process(delta: float) -> void:
	_time += delta
	if _time >= TOTAL_LIFE:
		queue_free()
		return

	for c in _chunks:
		if c["life"] > 0.0:
			c["life"] -= delta
			c["vy"] += 60.0 * delta  # gravity (chunks fall)
			c["vx"] *= 0.94
			c["vy"] *= 0.94
			c["x"] += c["vx"] * delta
			c["y"] += c["vy"] * delta
			c["rotation"] += c["spin"] * delta

	for d in _dust:
		if d["life"] > 0.0:
			d["life"] -= delta
			d["vx"] *= 0.90
			d["vy"] *= 0.90
			d["x"] += d["vx"] * delta
			d["y"] += d["vy"] * delta

	update()


func _draw() -> void:
	var fade = 1.0 - clamp((_time - SCATTER_DURATION) / LINGER_DURATION, 0.0, 1.0)

	# --- Dust cloud (behind chunks) ---
	for d in _dust:
		if d["life"] <= 0.0:
			continue
		var t = d["life"] / d["max_life"]
		var c: Color = d["color"]
		c.a = t * 0.35
		draw_circle(Vector2(d["x"], d["y"]), d["size"] * (0.5 + t * 0.5), c)

	# --- Stone chunks (angular rectangles) ---
	for ch in _chunks:
		if ch["life"] <= 0.0:
			continue
		var t = ch["life"] / ch["max_life"]
		var pos = Vector2(ch["x"], ch["y"])
		var sz = ch["size"]

		# Draw as rotated rectangle
		var half = Vector2(sz * 0.5, sz * 0.35)
		var corners = PoolVector2Array()
		for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
			var rotated = corner.rotated(ch["rotation"])
			corners.append(pos + rotated)

		var base_c = ch["color"]
		base_c.a = t * 0.9
		draw_colored_polygon(corners, base_c)

		# Highlight edge
		var highlight = Color(min(base_c.r + 0.2, 1.0), min(base_c.g + 0.2, 1.0), min(base_c.b + 0.15, 1.0), t * 0.5)
		var top_edge = PoolVector2Array([corners[0], corners[1]])
		if corners.size() >= 2:
			draw_line(corners[0], corners[1], highlight, 1.5)

	# --- Zone outline (faint cracked circle) ---
	if fade > 0.1:
		var expand_t = clamp(_time / SCATTER_DURATION, 0.0, 1.0)
		var rx = max_radius * expand_t
		var ry = rx * 0.5
		if rx > 4.0:
			var ring_a = fade * 0.3
			var tint = scatter_color if not below_50 else Color(0.7, 0.3, 0.15, 1.0)
			var ring_c = Color(tint.r, tint.g, tint.b, ring_a)
			_draw_ring(Vector2.ZERO, rx, ry, 2.5, ring_c)


func _generate_chunks() -> void:
	for i in CHUNK_COUNT:
		var angle = TAU * float(i) / float(CHUNK_COUNT) + rand_range(-0.2, 0.2)
		var speed = rand_range(100.0, 250.0)
		var launch_up = rand_range(-80.0, -30.0)  # chunks arc upward first
		var life = rand_range(0.4, 0.7)
		var base_shade = rand_range(0.35, 0.65)
		var color: Color
		if below_50:
			color = Color(base_shade + 0.15, base_shade * 0.5, base_shade * 0.3, 1.0)
		else:
			color = Color(base_shade, base_shade * 0.8, base_shade * 0.5, 1.0)
		_chunks.append({
			"x": 0.0,
			"y": 0.0,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed * 0.5 + launch_up,
			"life": life,
			"max_life": life,
			"size": rand_range(6.0, 14.0),
			"rotation": randf() * TAU,
			"spin": rand_range(-8.0, 8.0),
			"color": color,
		})


func _generate_dust() -> void:
	for i in DUST_COUNT:
		var angle = TAU * float(i) / float(DUST_COUNT) + rand_range(-0.4, 0.4)
		var speed = rand_range(40.0, 120.0)
		var life = rand_range(0.3, 0.6)
		var shade = rand_range(0.5, 0.8)
		_dust.append({
			"x": rand_range(-8.0, 8.0),
			"y": rand_range(-4.0, 4.0),
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed * 0.5,
			"life": life,
			"max_life": life,
			"size": rand_range(4.0, 10.0),
			"color": Color(shade, shade * 0.85, shade * 0.6, 1.0),
		})


func _draw_ring(center: Vector2, rx: float, ry: float, thickness: float, color: Color) -> void:
	if rx < 1.0 or ry < 1.0:
		return
	var points_count = 32
	var outer = PoolVector2Array()
	var inner = PoolVector2Array()
	var irx = max(rx - thickness, 0.0)
	var iry = max(ry - thickness * 0.5, 0.0)
	for i in range(points_count + 1):
		var angle = TAU * float(i) / float(points_count)
		outer.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		inner.append(center + Vector2(cos(angle) * irx, sin(angle) * iry))
	for i in points_count:
		var quad = PoolVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]])
		draw_colored_polygon(quad, color)
