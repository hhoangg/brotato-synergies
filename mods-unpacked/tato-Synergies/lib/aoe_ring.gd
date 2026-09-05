# A short-lived world-space ring that shows an AOE's radius, then fades out and frees itself.
# Spawned in the arena at the cast origin (NOT screen-space like the HUD).
extends Node2D

var radius := 100.0
var color := Color(1.0, 0.42, 0.2)   # orange-red "damage zone"
var life := 0.5
var _t := 0.0


func setup(r: float, c: Color, l: float) -> void:
	radius = r
	color = c
	life = l
	update()


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	update()   # redraw each frame for the fade


func _draw() -> void:
	var k : float = clamp(1.0 - _t / life, 0.0, 1.0)
	# Radial gradient: solid at center → transparent at edge
	var center_color := color
	center_color.a = 0.35 * k
	var edge_color := color
	edge_color.a = 0.0
	# Draw concentric rings to approximate a gradient (Godot 3.x has no radial gradient fill)
	var steps := 12
	for i in range(steps):
		var t_inner = float(i) / float(steps)
		var t_outer = float(i + 1) / float(steps)
		var r_inner = radius * t_inner
		var r_outer = radius * t_outer
		var ring_color = center_color.linear_interpolate(edge_color, (t_inner + t_outer) * 0.5)
		draw_circle(Vector2.ZERO, r_outer, ring_color)
