# A soft circular aura (reuses the game's Doc Moth aura sprite `aura_effect.png`) shown for a moment to
# mark a radius effect — e.g. the doctor's heal area. Scales to the radius, fades out, self-frees.
extends Node2D

const AURA_TEX := "res://particles/sprites/aura_effect.png"

var life := 0.7
var _t := 0.0
var _col := Color(0.40, 1.0, 0.55, 0.40)
var _sp = null


func setup(radius: float, color: Color, l: float) -> void:
	_col = color
	life = l
	_sp = Sprite.new()
	var tex = load(AURA_TEX)
	if tex != null:
		_sp.texture = tex
		var w : float = float(tex.get_width())
		if w > 0.0:
			_sp.scale = Vector2.ONE * (2.0 * radius / w)
	add_child(_sp)
	_redraw(1.0)


func _process(delta: float) -> void:
	_t += delta
	var k : float = clamp(1.0 - _t / life, 0.0, 1.0)
	_redraw(k)
	if _t >= life:
		queue_free()


func _redraw(k: float) -> void:
	if _sp != null:
		_sp.modulate = Color(_col.r, _col.g, _col.b, _col.a * k)
