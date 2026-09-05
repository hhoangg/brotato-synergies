# A summoned turret: reuses the base-game turret SPRITE (visual authenticity) but fires with OUR proven
# AOE-hitbox + beam/arc mechanics (no game-projectile pooling). Auto-targets the nearest enemy in range
# every `interval`s, lives `life`s then fades out, and self-frees when the wave ends. Heal mode tops up
# nearby allies instead of damaging. Driven by the synergies controller, which it calls back for the
# damage/heal/targeting helpers it already owns.
extends Node2D

const Beam = preload("res://mods-unpacked/tato-Synergies/lib/beam.gd")
const Lightning = preload("res://mods-unpacked/tato-Synergies/lib/lightning.gd")

var _ctrl = null            # the synergies controller (helpers: _nearest_enemy/_spawn_aoe_hitbox/_turret_heal/_in_wave)
var _caster = null          # summoning player node (damage attribution)
var _mode := "damage"       # "damage" | "heal"
var _interval := 1.0
var _range := 350.0
var _hit_radius := 70.0
var _dmg := 20
var _heal := 12
var _color := Color(0.45, 0.85, 1.0, 1.0)
var _shot := "beam"         # "beam" | "arc" | "none"
var _burn = null
var life := 6.0
var _t := 0.0
var _cd := 0.6              # short arming delay before the first shot
var _sp = null


func setup(ctrl, caster, opts: Dictionary) -> void:
	_ctrl = ctrl
	_caster = caster
	_mode = String(opts.get("mode", "damage"))
	_interval = float(opts.get("interval", 1.0))
	_range = float(opts.get("range", 350.0))
	_hit_radius = float(opts.get("hit_radius", 70.0))
	_dmg = int(opts.get("dmg", 20))
	_heal = int(opts.get("heal", 12))
	_color = opts.get("color", _color)
	_shot = String(opts.get("shot", "beam"))
	_burn = opts.get("burn", null)
	life = float(opts.get("life", 6.0))
	_sp = Sprite.new()
	var tex = load(String(opts.get("sprite", "res://entities/structures/turret/turret.png")))
	if tex != null:
		_sp.texture = tex
	add_child(_sp)


func _process(delta: float) -> void:
	_t += delta
	# vanish at wave end (like buffs) or when its lifetime runs out
	if _t >= life or (_ctrl != null and _ctrl.has_method("_in_wave") and not _ctrl._in_wave()):
		queue_free()
		return
	if _sp != null:
		_sp.modulate = Color(1, 1, 1, clamp((life - _t) / 0.5, 0.0, 1.0))   # fade in the last 0.5s
	_cd -= delta
	if _cd <= 0.0:
		_cd = _interval
		_fire()


func _fire() -> void:
	if _ctrl == null:
		return
	if _mode == "heal":
		_ctrl._turret_heal(global_position, _range, _heal)
		return
	var target = _ctrl._nearest_enemy(global_position)
	if target == null or not is_instance_valid(target):
		return
	var tp = target.global_position
	if global_position.distance_to(tp) > _range:
		return
	_spawn_shot(tp)
	var from = _caster if (_caster != null and is_instance_valid(_caster)) else self
	_ctrl._spawn_aoe_hitbox(tp, _dmg, _hit_radius, from, _color, _burn)


# Draw the turret's shot tracer (a laser beam or a lightning arc) from the muzzle to the target.
func _spawn_shot(tp: Vector2) -> void:
	if _shot == "none":
		return
	var host = get_parent()
	if host == null:
		host = self
	var v = (Lightning.new() if _shot == "arc" else Beam.new())
	host.add_child(v)
	v.setup(global_position, tp, _color, 0.18)
