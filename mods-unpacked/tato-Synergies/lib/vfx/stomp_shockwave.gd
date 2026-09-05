extends Node2D

# Tremor Stomp ground-crack shockwave VFX.
# Expanding ring + radial crack lines + dust debris particles.
# Spawned at player position in world space, auto-frees when done.

var stomp_color: Color = Color(0.75, 0.45, 0.15, 1.0)
var max_radius: float = 300.0

var _time: float = 0.0
var _cracks: Array = []
var _debris: Array = []

const EXPAND_DURATION: float = 0.3
const FADE_DURATION: float = 0.4
const TOTAL_LIFE: float = 0.7
const RING_THICKNESS: float = 6.0
const ELLIPSE_POINTS: int = 48
const CRACK_COUNT: int = 8
const CRACK_BRANCHES: int = 2
const DEBRIS_COUNT: int = 16


func _ready() -> void:
	z_index = 1
	_generate_cracks()
	_generate_debris()


func _process(delta: float) -> void:
	_time += delta
	if _time >= TOTAL_LIFE:
		queue_free()
		return

	for d in _debris:
		if d["life"] > 0.0:
			d["life"] -= delta
			d["vx"] *= 0.92
			d["vy"] *= 0.92
			d["x"] += d["vx"] * delta
			d["y"] += d["vy"] * delta

	update()


func _draw() -> void:
	var expand_t = clamp(_time / EXPAND_DURATION, 0.0, 1.0)
	var ease_t = 1.0 - pow(1.0 - expand_t, 3.0)
	var fade = 1.0 - clamp((_time - EXPAND_DURATION) / FADE_DURATION, 0.0, 1.0)

	# -- Earthy impact zone (drawn first so cracks render on top) --
	var rx = max_radius * ease_t
	var ry = rx * 0.5
	if rx > 4.0:
		var fill_a = fade * 0.12
		var fill_c = Color(0.35, 0.22, 0.08, fill_a)
		_draw_filled_ellipse(Vector2.ZERO, rx * 0.85, ry * 0.85, fill_c)

	# -- Impact flash --
	if _time < 0.08:
		var flash_a = (1.0 - _time / 0.08) * 0.5
		_draw_filled_ellipse(Vector2.ZERO, 50.0, 25.0, Color(1.0, 0.9, 0.7, flash_a))

	# -- Ground cracks (on top of the earthy fill) --
	_draw_cracks(ease_t, fade)

	# -- Shockwave ring --
	if rx > 2.0:
		var glow_a = fade * 0.25
		var glow_c = Color(stomp_color.r, stomp_color.g, stomp_color.b, glow_a)
		_draw_ring(Vector2.ZERO, rx, ry, RING_THICKNESS * 5.0, glow_c)

		var main_a = fade * 0.85
		var main_c = Color(stomp_color.r, stomp_color.g, stomp_color.b, main_a)
		_draw_ring(Vector2.ZERO, rx, ry, RING_THICKNESS * 1.5, main_c)

	# -- Dust debris --
	_draw_debris()


func _generate_cracks() -> void:
	for i in CRACK_COUNT:
		var base_angle = TAU * float(i) / float(CRACK_COUNT) + rand_range(-0.15, 0.15)
		var length = rand_range(0.6, 1.0)
		var segments = []

		# Main crack line with jagged segments
		var seg_count = int(rand_range(4, 7))
		var prev = Vector2.ZERO
		for s in range(1, seg_count + 1):
			var frac = float(s) / float(seg_count)
			var r = max_radius * length * frac
			var jitter = rand_range(-0.08, 0.08)
			var a = base_angle + jitter
			var pt = Vector2(cos(a) * r, sin(a) * r * 0.5)
			segments.append({"from": prev, "to": pt, "frac": frac})
			prev = pt

			# Branch off at mid-segments
			if s == int(seg_count * 0.5) or s == int(seg_count * 0.7):
				for _b in CRACK_BRANCHES:
					var branch_a = base_angle + rand_range(-0.4, 0.4)
					var branch_r = r * rand_range(0.3, 0.5)
					var branch_pt = prev + Vector2(cos(branch_a) * branch_r, sin(branch_a) * branch_r * 0.5)
					segments.append({"from": prev, "to": branch_pt, "frac": frac + 0.1})

		_cracks.append(segments)


func _generate_debris() -> void:
	for i in DEBRIS_COUNT:
		var angle = TAU * float(i) / float(DEBRIS_COUNT) + rand_range(-0.3, 0.3)
		var speed = rand_range(60.0, 180.0)
		var life = rand_range(0.3, 0.55)
		var shade = rand_range(0.3, 0.7)
		_debris.append({
			"x": rand_range(-10.0, 10.0),
			"y": rand_range(-5.0, 5.0),
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed * 0.5,
			"life": life,
			"max_life": life,
			"size": rand_range(1.5, 3.5),
			"color": Color(shade, shade * 0.7, shade * 0.3, 1.0),
		})


func _draw_cracks(expand_progress: float, fade: float) -> void:
	var dark = Color(0.15, 0.1, 0.05, fade * 0.9)
	var edge = Color(stomp_color.r * 0.6, stomp_color.g * 0.4, stomp_color.b * 0.2, fade * 0.5)

	for crack in _cracks:
		for seg in crack:
			if expand_progress < seg["frac"]:
				continue
			var seg_t = clamp((expand_progress - seg["frac"] + 0.3) / 0.3, 0.0, 1.0)
			var from_pt: Vector2 = seg["from"] * expand_progress
			var to_pt_full: Vector2 = seg["to"] * expand_progress
			var to_pt = from_pt.linear_interpolate(to_pt_full, seg_t)

			# Dark core line
			draw_line(from_pt, to_pt, dark, 2.5)
			# Lighter edge
			draw_line(from_pt, to_pt, edge, 1.0)


func _draw_debris() -> void:
	for d in _debris:
		if d["life"] <= 0.0:
			continue
		var t = d["life"] / d["max_life"]
		var c: Color = d["color"]
		c.a = t * 0.9
		var sz: float = d["size"] * (0.4 + t * 0.6)
		draw_circle(Vector2(d["x"], d["y"]), sz, c)


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
		var quad = PoolVector2Array([
			outer[i], outer[i + 1],
			inner[i + 1], inner[i]
		])
		draw_colored_polygon(quad, color)


func _draw_filled_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points = PoolVector2Array()
	for i in ELLIPSE_POINTS:
		var angle = TAU * float(i) / float(ELLIPSE_POINTS)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, color)
