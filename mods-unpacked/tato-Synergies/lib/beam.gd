# A short-lived laser beam (a glowing line + bright core + a hit dot) drawn from a caster to a target.
# Used by the AOE-on-cast rider's `beam` flag (e.g. cyborg's Overclock laser). Fades out, self-frees.
extends Node2D

var _to := Vector2.ZERO        # endpoint in LOCAL coords (node sits at the `from` world point)
var _col := Color(0.40, 0.90, 1.0, 0.95)
var _w := 7.0
var life := 0.25
var _t := 0.0


func setup(from: Vector2, to: Vector2, color: Color, width: float, l: float) -> void:
	global_position = from
	_to = to - from
	_col = color
	_w = width
	life = l
	update()


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
	else:
		update()


func _draw() -> void:
	var k : float = clamp(1.0 - _t / life, 0.0, 1.0)
	var core := Color(_col.r, _col.g, _col.b, _col.a * k)
	var glow := Color(_col.r, _col.g, _col.b, _col.a * 0.30 * k)
	draw_line(Vector2.ZERO, _to, glow, _w * 2.4)      # soft wide glow
	draw_line(Vector2.ZERO, _to, core, _w)            # bright core
	draw_circle(_to, _w * 1.3, core)                  # impact dot at the target
