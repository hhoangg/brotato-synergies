# A short-lived jagged electric arc drawn from a caster to a target — used by `arc` skills (lich Death
# Coil, technomage Arc Turret) to read as chain lightning. Crackles (re-jitters each frame), fades, frees.
extends Node2D

var _to := Vector2.ZERO        # endpoint in LOCAL coords (node sits at the `from` world point)
var _col := Color(0.6, 0.85, 1.0, 1.0)
var life := 0.22
var _t := 0.0
var _pts := []                 # jagged points (local), rebuilt each frame for a crackle


func setup(from: Vector2, to: Vector2, color: Color, l: float) -> void:
	global_position = from
	z_index = 4096          # draw ON TOP of the explosion smoke / AOE ring / enemies
	z_as_relative = false
	_to = to - from
	_col = color
	life = l
	_build()
	update()


func _build() -> void:
	_pts = [Vector2.ZERO]
	var segs := 6
	var perp := Vector2(-_to.y, _to.x).normalized()
	for i in range(1, segs):
		var base : Vector2 = _to * (float(i) / float(segs))
		_pts.append(base + perp * rand_range(-14.0, 14.0))
	_pts.append(_to)


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	_build()       # re-jitter → crackling look
	update()


func _draw() -> void:
	var k : float = clamp(1.0 - _t / life, 0.0, 1.0)
	var glow := Color(_col.r, _col.g, _col.b, _col.a * 0.35 * k)
	var core := Color(_col.r, _col.g, _col.b, _col.a * k)
	var hot := Color(1.0, 1.0, 1.0, _col.a * k)   # white-hot inner core for pop
	for i in range(_pts.size() - 1):
		draw_line(_pts[i], _pts[i + 1], glow, 16.0)
		draw_line(_pts[i], _pts[i + 1], core, 7.0)
		draw_line(_pts[i], _pts[i + 1], hot, 2.5)
