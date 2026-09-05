extends Node2D

# Tracer line VFX for Dead Eye skill.
# Draws a bright line from shooter to target that fades out.
# Spawned in world space, auto-frees when done.

var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO
var tracer_color: Color = Color(1.0, 0.85, 0.3, 1.0)

var _time: float = 0.0
const LIFE: float = 0.3


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFE:
		queue_free()
		return
	update()


func _draw() -> void:
	var alpha = 1.0 - _time / LIFE
	var c = Color(tracer_color.r, tracer_color.g, tracer_color.b, alpha * 0.9)
	var glow_c = Color(tracer_color.r, tracer_color.g, tracer_color.b, alpha * 0.3)
	var local_from = from_pos - global_position
	var local_to = to_pos - global_position
	draw_line(local_from, local_to, glow_c, 8.0)
	draw_line(local_from, local_to, c, 3.0)
