extends Node2D

# Expanding activation ring that fades out over its lifetime.
# Spawned at the player's position, self-destructs via Tween.

var ring_color: Color = Color.white
var ring_width: float = 3.0
var duration: float = 0.3

var _radius: float = 8.0
var _alpha: float = 1.0


func _ready() -> void:
	var tween = Tween.new()
	add_child(tween)

	tween.interpolate_property(
		self, "_radius",
		8.0, 48.0,
		duration,
		Tween.TRANS_QUAD, Tween.EASE_OUT
	)
	tween.interpolate_property(
		self, "_alpha",
		1.0, 0.0,
		duration,
		Tween.TRANS_QUAD, Tween.EASE_IN
	)
	tween.connect("tween_all_completed", self, "queue_free")
	tween.start()


func _process(_delta: float) -> void:
	update()


func _draw() -> void:
	var c = Color(ring_color.r, ring_color.g, ring_color.b, _alpha * 0.8)
	draw_arc(Vector2.ZERO, _radius, 0, TAU, 32, c, ring_width)
	# Inner softer glow ring
	var inner_c = Color(ring_color.r, ring_color.g, ring_color.b, _alpha * 0.3)
	draw_arc(Vector2.ZERO, _radius * 0.7, 0, TAU, 24, inner_c, ring_width * 2.0)
