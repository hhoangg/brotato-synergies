extends Node2D

# Isometric glowing ellipse below the player with smooth gradient edges
# and floating particles. Child of the player node — follows automatically.
# Call fade_out() to smoothly remove.

var aura_color: Color = Color.white
var life: float = 0.0   # >0 → auto fade_out after this many secs (0 = caller manages removal)

var _time: float = 0.0
var _fading_out: bool = false
var _particles: Array = []

# Isometric ellipse dimensions
const RADIUS_X: float = 64.0   # horizontal radius (wider)
const RADIUS_Y: float = 32.0   # vertical radius (squished for isometric)
const CENTER_OFFSET_Y: float = 10.0  # below player center (at feet)
const GRADIENT_STEPS: int = 12  # number of concentric layers for smooth gradient
const ELLIPSE_POINTS: int = 32  # polygon resolution

const PULSE_SPEED: float = 2.5
const BASE_ALPHA: float = 0.4
const PULSE_AMPLITUDE: float = 0.08
const FADE_DURATION: float = 0.25

# Particles
const PARTICLE_SPAWN_RATE: float = 16.0
const PARTICLE_LIFE: float = 0.8
const PARTICLE_SPEED_Y: float = -40.0
const PARTICLE_SPREAD_X: float = 48.0
const PARTICLE_SIZE: float = 2.0
var _spawn_accum: float = 0.0


func _ready() -> void:
	show_behind_parent = true
	z_as_relative = true


func _process(delta: float) -> void:
	_time += delta
	# Self-expire: once `life` elapses, fade out and free (prevents the aura living forever — the
	# spawner doesn't hold a reference to call fade_out(), so without this it leaks + emits particles
	# every frame for the rest of the run).
	if life > 0.0 and not _fading_out and _time >= life:
		fade_out()
	# Stop emitting new particles once fading out, so they don't outlive the aura.
	if not _fading_out:
		_spawn_accum += delta
		var spawn_interval = 1.0 / PARTICLE_SPAWN_RATE
		while _spawn_accum >= spawn_interval:
			_spawn_accum -= spawn_interval
			_spawn_particle()

	var i = _particles.size() - 1
	while i >= 0:
		var p = _particles[i]
		p["life"] -= delta
		if p["life"] <= 0.0:
			_particles.remove(i)
		else:
			p["x"] += p["vx"] * delta
			p["y"] += p["vy"] * delta
		i -= 1

	update()


func _draw() -> void:
	var pulse = sin(_time * PULSE_SPEED)
	var alpha = BASE_ALPHA + pulse * PULSE_AMPLITUDE
	var center = Vector2(0, CENTER_OFFSET_Y)

	# Draw gradient ellipse: outer layers first (faintest), inner layers last (brightest)
	for step in range(GRADIENT_STEPS, 0, -1):
		var t = float(step) / float(GRADIENT_STEPS)  # 1.0 = outermost, ~0 = innermost
		var rx = RADIUS_X * t
		var ry = RADIUS_Y * t

		# Alpha: fades to 0 at edge, peaks at center
		# Using smooth quadratic falloff for soft gradient
		var layer_alpha = alpha * (1.0 - t * t)

		# Color: brighter toward center
		var brightness = 1.0 + (1.0 - t) * 0.4
		var c = Color(
			min(aura_color.r * brightness, 1.0),
			min(aura_color.g * brightness, 1.0),
			min(aura_color.b * brightness, 1.0),
			layer_alpha
		)

		_draw_ellipse(center, rx, ry, c)

	# Draw particles
	for p in _particles:
		var life_t = p["life"] / p["max_life"]
		var p_alpha = life_t * alpha * 1.2
		var p_size = PARTICLE_SIZE * (0.5 + life_t * 0.5)
		var p_color = Color(
			min(aura_color.r * 1.3, 1.0),
			min(aura_color.g * 1.3, 1.0),
			min(aura_color.b * 1.3, 1.0),
			p_alpha
		)
		draw_circle(Vector2(p["x"], p["y"]), p_size, p_color)


func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	var points = PoolVector2Array()
	for i in ELLIPSE_POINTS:
		var angle = TAU * float(i) / float(ELLIPSE_POINTS)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, color)


func _spawn_particle() -> void:
	# Spawn particles from the ellipse area
	var angle = rand_range(0, TAU)
	var dist = rand_range(0.3, 1.0)
	var start_x = cos(angle) * RADIUS_X * dist * 0.8
	var start_y = CENTER_OFFSET_Y + sin(angle) * RADIUS_Y * dist * 0.5
	var p = {
		"x": start_x,
		"y": start_y,
		"vx": rand_range(-5.0, 5.0),
		"vy": PARTICLE_SPEED_Y + rand_range(-10.0, 10.0),
		"life": PARTICLE_LIFE + rand_range(-0.2, 0.2),
		"max_life": PARTICLE_LIFE
	}
	p["max_life"] = p["life"]
	_particles.append(p)


func fade_out() -> void:
	if _fading_out:
		return
	_fading_out = true

	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(
		self, "modulate:a",
		modulate.a, 0.0,
		FADE_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_IN
	)
	tween.connect("tween_all_completed", self, "queue_free")
	tween.start()
