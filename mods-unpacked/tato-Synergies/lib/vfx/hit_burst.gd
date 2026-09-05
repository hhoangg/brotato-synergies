extends Node2D

# Burst of particles at an enemy position when hit by a skill.
# Spawned in world space at the enemy's position, auto-frees when done.

var burst_color_a: Color = Color(0.7, 0.3, 1.0, 1.0)  # purple
var burst_color_b: Color = Color(1.0, 0.5, 0.1, 1.0)   # orange
var particle_count: int = 12

var _particles: Array = []
var _time: float = 0.0

const PARTICLE_LIFE: float = 0.5
const PARTICLE_SPEED: float = 120.0
const PARTICLE_SIZE: float = 3.0


func _ready() -> void:
	z_index = 5
	for i in particle_count:
		var angle = TAU * float(i) / float(particle_count) + rand_range(-0.2, 0.2)
		var speed = PARTICLE_SPEED * rand_range(0.5, 1.2)
		var life = PARTICLE_LIFE * rand_range(0.7, 1.0)
		var color = burst_color_a.linear_interpolate(burst_color_b, rand_range(0.0, 1.0))
		_particles.append({
			"x": 0.0,
			"y": 0.0,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed * 0.5,  # isometric squish
			"life": life,
			"max_life": life,
			"size": PARTICLE_SIZE * rand_range(0.6, 1.4),
			"color": color,
		})


func _process(delta: float) -> void:
	_time += delta
	var alive = false
	for p in _particles:
		if p["life"] > 0.0:
			alive = true
			p["life"] -= delta
			# Decelerate
			p["vx"] *= 0.95
			p["vy"] *= 0.95
			p["x"] += p["vx"] * delta
			p["y"] += p["vy"] * delta
	if not alive:
		queue_free()
		return
	update()


func _draw() -> void:
	for p in _particles:
		if p["life"] <= 0.0:
			continue
		var t = p["life"] / p["max_life"]
		var alpha = t
		var size = p["size"] * (0.3 + t * 0.7)
		var c = p["color"]
		c.a = alpha
		draw_circle(Vector2(p["x"], p["y"]), size, c)
