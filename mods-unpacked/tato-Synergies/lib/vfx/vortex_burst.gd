extends Node2D

# Contracting vortex ring VFX — starts large, shrinks to center, then fades.
# Conveys a "pulling inward" feel matching the enemy pull animation.
# Spawned at the player's position, self-destructs via Tween.

var outer_color: Color = Color(0.55, 0.3, 0.9, 1.0)
var inner_color: Color = Color(0.3, 0.7, 0.85, 1.0)
var duration: float = 0.35

var _radius: float = 64.0
var _alpha: float = 0.9
var _ring_width: float = 3.0


func _ready() -> void:
	var tween = Tween.new()
	add_child(tween)

	# Ring contracts inward (large -> small)
	tween.interpolate_property(
		self, "_radius",
		64.0, 6.0,
		duration,
		Tween.TRANS_QUAD, Tween.EASE_IN
	)
	# Fade out
	tween.interpolate_property(
		self, "_alpha",
		0.9, 0.0,
		duration,
		Tween.TRANS_QUAD, Tween.EASE_IN
	)
	# Ring gets thicker as it contracts
	tween.interpolate_property(
		self, "_ring_width",
		2.5, 5.0,
		duration,
		Tween.TRANS_LINEAR, Tween.EASE_IN
	)
	tween.connect("tween_all_completed", self, "queue_free")
	tween.start()


func _process(_delta: float) -> void:
	update()


func _draw() -> void:
	# Outer ring (purple)
	var c = Color(outer_color.r, outer_color.g, outer_color.b, _alpha * 0.8)
	draw_arc(Vector2.ZERO, _radius, 0, TAU, 36, c, _ring_width)
	# Inner glow ring (teal, slightly smaller)
	var ic = Color(inner_color.r, inner_color.g, inner_color.b, _alpha * 0.5)
	draw_arc(Vector2.ZERO, _radius * 0.65, 0, TAU, 28, ic, _ring_width * 1.5)
	# Center glow dot
	var dc = Color(inner_color.r, inner_color.g, inner_color.b, _alpha * 0.35)
	draw_circle(Vector2.ZERO, max(_radius * 0.15, 2.0), dc)
