# Persistent controller for the Co-op Synergies mod. Spawned at /root by mod_main.
#
# v0.5.0 SKILL FRAMEWORK — vertical slice. Per-player skill STATE MACHINE:
#   * unlock at level N (Config.UNLOCK_LEVEL; TEST_MODE → 1),
#   * tier from level (+1 every UPGRADE_EVERY levels, capped MAX_TIER),
#   * cooldown = fraction of the wave's duration (Config.COOLDOWN_WAVE_FRACTION; TEST_MODE → 5%),
#   * fires only in active combat (living enemies present) and never while paused,
#   * routed to the FIRING player via CoopService.connected_players (entry INDEX == co-op place).
# The cast itself is a PLACEHOLDER for now (flash the HUD + log + start cooldown); per-skill effects
# get wired next. The routing-test diagnostic/overlay is gone — replaced by lib/skill_hud.gd.
extends Node

const Config = preload("res://mods-unpacked/tato-Synergies/config.gd")
const SkillHud = preload("res://mods-unpacked/tato-Synergies/lib/skill_hud.gd")
const AoeRing = preload("res://mods-unpacked/tato-Synergies/lib/aoe_ring.gd")
const CharselPanel = preload("res://mods-unpacked/tato-Synergies/lib/charsel_panel.gd")
const HealAura = preload("res://mods-unpacked/tato-Synergies/lib/heal_aura.gd")
const Beam = preload("res://mods-unpacked/tato-Synergies/lib/beam.gd")
const Lightning = preload("res://mods-unpacked/tato-Synergies/lib/lightning.gd")
const SummonTurret = preload("res://mods-unpacked/tato-Synergies/lib/summon_turret.gd")
const ModSettings = preload("res://mods-unpacked/tato-Synergies/lib/mod_settings.gd")
const SettingsPanel = preload("res://mods-unpacked/tato-Synergies/lib/settings_panel.gd")
const CharacterCodex = preload("res://mods-unpacked/tato-Synergies/lib/character_codex.gd")

# Procedural VFX (ported from Alexandre-ActiveSkills, pure _draw() Node2D)
const VfxArcaneRing = preload("res://mods-unpacked/tato-Synergies/lib/vfx/arcane_ring.gd")
const VfxBuffAura = preload("res://mods-unpacked/tato-Synergies/lib/vfx/buff_aura.gd")
const VfxBuffRing = preload("res://mods-unpacked/tato-Synergies/lib/vfx/buff_ring.gd")
const VfxExplosionBurst = preload("res://mods-unpacked/tato-Synergies/lib/vfx/explosion_burst.gd")
const VfxHitBurst = preload("res://mods-unpacked/tato-Synergies/lib/vfx/hit_burst.gd")
const VfxNecroticPulse = preload("res://mods-unpacked/tato-Synergies/lib/vfx/necrotic_pulse.gd")
const VfxStompShockwave = preload("res://mods-unpacked/tato-Synergies/lib/vfx/stomp_shockwave.gd")
const VfxStoneScatter = preload("res://mods-unpacked/tato-Synergies/lib/vfx/stone_scatter.gd")
const VfxVortexBurst = preload("res://mods-unpacked/tato-Synergies/lib/vfx/vortex_burst.gd")
const VfxTracerLine = preload("res://mods-unpacked/tato-Synergies/lib/vfx/tracer_line.gd")
const VfxPrecisionFlash = preload("res://mods-unpacked/tato-Synergies/lib/vfx/precision_flash.gd")
const VfxEnergyShockwave = preload("res://mods-unpacked/tato-Synergies/lib/vfx/energy_shockwave.gd")

# Sprite-sheet VFX (Vivid Motions 23 status-effect pack — 4x4 64px sheets). One generic player
# (lib/vfx/sprite_vfx.gd) animates any of them; _spawn_sprite_vfx maps an effect name → its sheet.
const SpriteVfx = preload("res://mods-unpacked/tato-Synergies/lib/vfx/sprite_vfx.gd")
const VIVID_DIR := "res://mods-unpacked/tato-Synergies/assets/vfx/Vivid_Motion_23_ Universal_Status_Effects"

# The game's own character-outline shader (the "Làm Nổi Nhân Vật" setting) — a canvas_item shader that
# traces the sprite silhouette. We reuse it with white to mark a shielded player. Loaded lazily (game res).
const OUTLINE_SHADER := "res://resources/shaders/outline.gdshader"
const DASH_GLIDE_SEC := 0.18   # DASH glides over this many secs (ease-out) instead of teleporting
const FREEZE_RESCAN_INTERVAL := 0.2   # CC: how often the open freeze window re-scans to lock newly-spawned enemies
const BOSS_FREEZE_SPEED := 0.4   # CC: bosses can't be fully frozen — they keep this fraction of move speed (=-60%)

# Reused game particle VFX (CPUParticles2D, one_shot) — spawn on cast for feel, no new assets.
const VFX_HEAL := "res://particles/heal_particles.tscn"
const VFX_BLAST := "res://particles/explosion_smoke.tscn"
const VFX_BUFF := "res://particles/critical_particles.tscn"
const VFX_DASH := "res://particles/ghost_scepter_particles.tscn"

const FALLBACK_WAVE_SECONDS := 20.0   # cooldown wave-duration fallback if the WaveTimer isn't found
const HITBOX_SCENE := "res://overlap/hitbox.tscn"             # bare damage hitbox (Area2D) for AOE

# Pre-built BurningData resources from the base game — load() one and assign it to a Hitbox's
# `burning_data` so struck enemies CATCH FIRE (the game's real DoT + unit_burning_particles VFX).
# Tuned STRONG on purpose: an active skill is on a long cooldown (~2 casts per wave), so it should hit
# hard to be worth using — a light DoT wouldn't justify the cast. We use the high-tier game profiles.
const BURN_RES := {
	"arcane": "res://items/characters/mage/mage_burning_data.tres",                  # 1 dmg, 25% — light/arcane
	"ember": "res://weapons/melee/torch/3/torch_3_burning_data.tres",                # 8 dmg, 6s — strong burst
	"fire": "res://weapons/ranged/flamethrower/4/flamethrower_4_burning_data.tres",  # 5 dmg, 8s — strong, long
}
# Particle spawned ON struck enemies to read as a debuff (reused game particles; visual for now).
const HIT_VFX := {
	"curse": "res://particles/curse/curse_enemy_particles.tscn",
	"burn": "res://particles/burning/unit_burning_particles.tscn",
}
const HIT_VFX_MAX := 12   # cap per-enemy debuff particles so a big AOE can't spawn dozens at once

# Reused base-game rocket explosion SFX — the "boom" that was missing from our hand-built AOE bursts.
const SFX_EXPLO := [
	"res://projectiles/rocket/explosion_small_no_tail_01.wav",
	"res://projectiles/rocket/explosion_small_no_tail_02.wav",
	"res://projectiles/rocket/explosion_small_no_tail_03.wav",
]
const ARC_MAX := 4   # chain-lightning: how many nearest enemies the arc jumps to

# Stat keys that live on the Player's current_stats/max_stats Stats object (props confirmed via probe:
# [health, speed, damage, armor, dodge]) — mutate these fields DIRECTLY, NOT through the effects dict.
const STATS_FIELDS := {
	"stat_armor": "armor",
	"stat_speed": "speed",
	"stat_damage": "damage",
	"stat_dodge": "dodge",
}

var _hud = null
var _cd := {}          # place:int -> cooldown seconds remaining
var _kb_down := false
var _btn_down := {}     # device:int -> bool (poll edge state)
var _outline_shader = null   # cached load() of the game's outline.gdshader
var _charsel = null          # char-select skill-info card
var _settings = null         # ModSettings — persisted on/off toggles (skills_solo, synergies_coop)
var _settings_panel = null   # injects the toggles into the Options → Accessibility tab
var _char_codex = null       # injects the Character tab into the game's Codex menu
var _active_buffs := []   # [{ caster, targets:[pi], stats:{stat_key:amount}, remaining, total, auras }] — temp buffs to undo
var _combat_active := false   # in a live wave this frame? (used to force-expire buffs when a wave ends)
var _dashes := []   # active DASH glides: [{ node, from:Vector2, to:Vector2, t, dur }]
var _pushed := []   # KNOCKBACK: enemies being shoved outward [{ node, from, to, t, dur }] — pos lerped each frame
var _frozen := []   # CC: frozen enemies [{ node, speed, modulate, remaining, boss }] — velocity zeroed each frame (non-boss)
var _freeze_window := {}   # CC: open lockdown window { remaining, tint, vfx_n, scan_t } — keeps freezing NEW spawns
var _drain_zones := []  # STAT DRAIN zones: [{ pos, radius, remaining, slowed: {e: {cs, speed, modulate}} }]
var _greed := {}   # GREED window (Jack): { mult, remaining, prev:{place:gold} } — ×materials the team picks up
var _taunt := {}   # TAUNT window (Masochist): { place, remaining, radius } — drags nearby enemies toward the caster
var _diag_t := 0.0   # throttle for the co-op HUD-gating diagnostic (temp)
var _burn_cache := {}   # kind:String -> loaded BurningData resource (null if missing)
var _burn_probed := false   # logged the "burning_data settable?" diagnostic once
var _sfx_idx := 0   # rolling index to vary the explosion SFX clip per cast


func _ready() -> void:
	print("[Synergies] controller ready v" + Config.MOD_VERSION + (" [TEST]" if Config.TEST_MODE else ""))
	var layer := CanvasLayer.new()
	layer.name = "SynergiesHudLayer"
	layer.layer = 3   # low enough to sink behind the pause/shop menus (like the life bar), above the world
	_hud = SkillHud.new()
	layer.add_child(_hud)
	get_tree().root.call_deferred("add_child", layer)
	# Char-select skill card lives on its OWN high layer so it draws on top of that menu.
	var cs_layer := CanvasLayer.new()
	cs_layer.name = "SynergiesCharSelLayer"
	cs_layer.layer = 20
	_charsel = CharselPanel.new()
	cs_layer.add_child(_charsel)
	get_tree().root.call_deferred("add_child", cs_layer)
	# Persisted settings + the Options→Accessibility toggle injector (reads/writes the mod ConfigFile).
	_settings = ModSettings.new()
	_charsel.settings = _settings   # so the char-select card hides when synergies are toggled off
	_settings_panel = SettingsPanel.new()
	_settings_panel.settings = _settings
	get_tree().root.call_deferred("add_child", _settings_panel)
	# Character Codex tab — injects a 5th tab into the game's Codex menu (all characters + skills).
	_char_codex = CharacterCodex.new()
	get_tree().root.call_deferred("add_child", _char_codex)


func _process(delta: float) -> void:
	if _hud == null:
		return
	var run := _is_run_active()
	if not run:
		_hud.set_active(false)
		_cd.clear()
		_kb_down = false
		_btn_down.clear()
		_active_buffs.clear()   # run torn down — the game rebuilds players_data next run, so just drop them
		_dashes.clear()
		_pushed.clear()
		_frozen.clear()
		_freeze_window.clear()
		_scouts.clear()
		_greed.clear()          # drop any active material-multiplier window
		_taunt.clear()          # drop any active taunt-drag window
		_clear_drain_zones()    # restore slowed enemies + drop every heal/curse/slow zone
		_streamer_last_move_time.clear()
		_streamer_places = []
		_combat_active = false
		return
	if not _skills_enabled():
		# Solo with co-op-only skills (release) → no HUD, no casting, nothing ticks.
		_hud.set_active(false)
		return
	# Use the WaveTimer signal for both: show the widget only during a live wave, AND reset all temp
	# buffs the moment the wave ends (the player stays under Entities in the shop, so arena-units never
	# detected the wave end — that's why buffs leaked into the next wave).
	var inwave := _in_wave()
	_hud.set_active(inwave)
	if inwave and not _combat_active:
		_apply_affinities()                # wave just started → (re)apply the team faction traits
		_refresh_streamer_places()         # cache which places (if any) are Streamer — gates per-frame tracking
		# SKILL_KEY (Space) and SKILL_BUTTON (bottom face) are the SAME inputs that buy items / confirm
		# "go" in the shop. The "go" press is what STARTS the wave, so its rising edge would otherwise be
		# read as a fresh skill trigger on this first in-wave frame. Prime the edge state to whatever's
		# held RIGHT NOW (this runs before _poll_trigger below) so a held confirm-press is absorbed, not
		# fired — the player must release + press again in-wave to actually cast.
		_kb_down = Input.is_key_pressed(Config.SKILL_KEY)
		for dev in Input.get_connected_joypads():
			_btn_down[dev] = Input.is_joy_button_pressed(dev, Config.SKILL_BUTTON)
	elif _combat_active and not inwave:
		_expire_all_buffs("wave ended")    # clears skill buffs AND the affinity team buffs
		_clear_wave_effects()              # also drop lingering zones / freezes so nothing leaks into the shop + next wave
	_combat_active = inwave
	# DIAG (TEST_MODE only): once/sec, dump what gates the skill HUD so co-op "no icon" is diagnosable.
	if Config.TEST_MODE:
		_diag_t += delta
		if _diag_t >= 1.0:
			_diag_t = 0.0
			var lv := []
			for pl in _places():
				lv.append("p%d:lvl%d:%s:%s" % [pl, _level_for(pl), _slug_for(pl), ("U" if _level_for(pl) >= _unlock_level() else "LOCK")])
			print("[Synergies][diag] coop=%s enabled=%s inwave=%s unlock=%d places=%s states=%s" % [
				str(_is_coop()), str(_skills_enabled()), str(inwave), _unlock_level(), str(_places()), str(lv)])
	# Cooldowns tick whenever a run is active.
	for p in _cd.keys():
		if _cd[p] > 0.0:
			_cd[p] = max(0.0, _cd[p] - delta)
	_tick_buffs(delta)
	_tick_dashes(delta)
	_tick_pushed(delta)
	_tick_frozen(delta)
	_tick_freeze_window(delta)
	_tick_drained(delta)
	_tick_scouts(delta)
	_tick_greed(delta)
	_tick_taunt(delta)
	_track_streamer_movement()
	_poll_trigger()
	_hud.update_states(_states())


# ---------------------------------------------------------------------------
# per-player skill state snapshot (for the HUD)
# ---------------------------------------------------------------------------

func _states() -> Array:
	var out := []
	var unlock := _unlock_level()
	for place in _places():
		var lvl := _level_for(place)
		var bs := _buff_state_for(place)
		out.append({
			"place": place,
			"slug": _slug_for(place),
			"unlock_level": unlock,
			"unlocked": lvl >= unlock,
			"tier": _tier_for(lvl, unlock),
			"cd": float(_cd.get(place, 0.0)),
			"cd_total": _cooldown_seconds(_slug_for(place)),   # per-skill class → radial sweep matches the real CD
			"buff": bs[0],
			"buff_total": bs[1],
		})
	return out


# Longest-remaining active buff CAST BY this place → [remaining, total] for the HUD effect countdown.
func _buff_state_for(place: int) -> Array:
	var rem := 0.0
	var tot := 0.0
	for b in _active_buffs:
		if int(b.get("caster", -1)) == place and float(b["remaining"]) > rem:
			rem = float(b["remaining"])
			tot = float(b.get("total", b["remaining"]))
	return [rem, tot]


# ---------------------------------------------------------------------------
# trigger (poll-based rising edge, routed to the firing player) → cast
# ---------------------------------------------------------------------------

func _poll_trigger() -> void:
	var kdown := Input.is_key_pressed(Config.SKILL_KEY)
	if kdown and not _kb_down:
		_try_cast(0, true)
	_kb_down = kdown
	for dev in Input.get_connected_joypads():
		var down : bool = Input.is_joy_button_pressed(dev, Config.SKILL_BUTTON)
		if down and not bool(_btn_down.get(dev, false)):
			_try_cast(dev, false)
		_btn_down[dev] = down


func _try_cast(device: int, is_key: bool) -> void:
	if not _is_run_active() or not _skills_enabled():
		return
	# Wave gate: only cast during a live wave (WaveTimer running / enemies present) and never while
	# paused — same gate the HUD uses, so "can cast" matches "widget visible".
	if get_tree().paused:
		return
	if not _in_wave():
		return
	var place := _resolve_place(device, is_key)
	var lvl := _level_for(place)
	if lvl < _unlock_level():
		return                                  # skill not unlocked yet
	if float(_cd.get(place, 0.0)) > 0.0:
		return                                  # still on cooldown
	var cd := _cooldown_seconds(_slug_for(place))
	_cd[place] = cd
	print("[Synergies] CAST place=%d char=%s tier=%d cd=%.1fs" % [place, _char_id_for(place), _tier_for(lvl, _unlock_level()), cd])
	if _hud != null:
		_hud.note_cast(place)
	_cast_skill(place, lvl)


# ---------------------------------------------------------------------------
# cooldown / wave timing
# ---------------------------------------------------------------------------

func _cooldown_seconds(slug := "") -> float:
	var frac : float = Config.COOLDOWN_WAVE_FRACTION_TEST if Config.TEST_MODE else Config.COOLDOWN_WAVE_FRACTION
	return frac * _wave_duration() * _cooldown_mult(slug)


# Per-skill cooldown multiplier from its `cooldown_class` (fast/normal/slow). Unknown/missing → 1.0.
func _cooldown_mult(slug: String) -> float:
	if slug == "" or not Config.SKILLS.has(slug):
		return 1.0
	var cls = String(Config.SKILLS[slug].get("cooldown_class", "normal"))
	return float(Config.COOLDOWN_CLASS_MULT.get(cls, 1.0))


func _wave_duration() -> float:
	# Real 45%-of-wave cooldown: read the live WaveTimer's length (Brotato waves get longer, so the
	# cooldown scales with them). Falls back to a fixed base only if the timer isn't found.
	var scene = get_tree().current_scene
	if scene != null:
		var wt = scene.get_node_or_null("WaveTimer")
		if wt != null:
			var w = wt.get("wait_time")
			if (typeof(w) == TYPE_INT or typeof(w) == TYPE_REAL) and float(w) > 0.0:
				return float(w)
	return FALLBACK_WAVE_SECONDS


# ---------------------------------------------------------------------------
# skill effects — BUFF_SELF / BUFF_PARTY (temp stats that self-undo after N s)
# ---------------------------------------------------------------------------
# Mechanism (from the game's own effect source, e.g. stat_gains_modification_effect.gd):
#   RunData.get_player_effects(player_index)[Keys.generate_hash(stat_key)] += amount   # apply
#   ...                                                                        -= amount   # unapply
# "place" == player_index in co-op. "Allies" includes the caster.

func _cast_skill(place: int, lvl: int) -> void:
	var slug := _slug_for(place)
	if not Config.SKILLS.has(slug):
		print("[Synergies] no skill data for slug='%s' (place=%d) — cast is a no-op for now" % [slug, place])
		return
	var skill = Config.SKILLS[slug]
	var tier := _tier_for(lvl, _unlock_level())
	var template := String(skill.get("template", Config.TMPL_BUFF_SELF))
	if template == Config.TMPL_BUFF_SELF or template == Config.TMPL_BUFF_PARTY:
		_cast_buff(place, skill, tier, template)
	elif template == Config.TMPL_HEAL:
		_cast_heal(place, skill, tier)
	elif template == Config.TMPL_AOE_SELF:
		_cast_aoe_self(place, skill, tier)
	elif template == Config.TMPL_SHIELD:
		_cast_buff(place, skill, tier, template)   # +Armor/+Max HP temp stats (self); _apply_max_hp fills the gained HP
	elif template == Config.TMPL_AOE_CURSOR:
		_cast_aoe_cursor(place, skill, tier)
	elif template == Config.TMPL_DASH:
		_cast_dash(place, skill, tier)
	elif template == Config.TMPL_SUMMON:
		_cast_summon(place, skill, tier)
	elif template == Config.TMPL_CC:
		_cast_cc(place, skill, tier)
	elif template == Config.TMPL_CURSE_CLOUD:
		_cast_curse_cloud(place, skill, tier)
	elif template == Config.TMPL_HEAL_ZONE:
		_cast_heal_zone(place, skill, tier)
	elif template == Config.TMPL_GREED:
		_cast_greed(place, skill, tier)
	else:
		print("[Synergies] unknown template '%s' for slug='%s'" % [template, slug])
	# universal RIDER: dispel the Danger-6 fog for a few seconds (no-op on other dangers)
	if skill.has("clear_fog"):
		var fsec : float = float(skill.get("clear_fog", 6.0)) + float(skill.get("clear_fog_per_tier", 0.0)) * (tier - 1)
		_clear_fog(fsec)
	# universal RIDER: TAUNT — drag nearby enemies toward the caster for a window (Masochist).
	if skill.has("taunt"):
		_apply_taunt(place, skill, tier)
	# Procedural VFX rider — spawn a visual effect on cast
	_apply_vfx_rider(place, skill, tier)


# BUFF_SELF / BUFF_PARTY — temp stat(s) that self-undo after `dur` (tracked in _active_buffs).
func _cast_buff(place: int, skill, tier: int, template: String) -> void:
	var dur : float = float(skill.get("duration", 5.0)) + float(skill.get("dur_per_tier", 0.0)) * (tier - 1)
	var targets := _targets_for(template, place)
	var scaled := {}
	var base_stats : Dictionary = skill.get("stats", {})
	var per_tier : Dictionary = skill.get("stats_per_tier", {})
	for sk in base_stats.keys():
		scaled[sk] = int(base_stats[sk]) + int(per_tier.get(sk, 0)) * (tier - 1)
	for pi in targets:
		for sk in scaled.keys():
			_apply_stat(pi, sk, int(scaled[sk]))
		_recalc_player(pi)
		# Force stat panel UI refresh — emit health_updated + stats_changed signals
		var p = _player_node_for(pi)
		if p != null:
			_refresh_health(p, pi)
			# Also try to emit stats_changed if the player has it
			for s in p.get_signal_list():
				if String(s.name) == "stats_changed":
					p.emit_signal("stats_changed")
					break
		var tp = _player_node_for(pi)
		if tp != null and (tp is Node2D):
			if not skill.has("vfx"):
				_spawn_vfx(VFX_BUFF, tp.global_position)
			# Vivid burst keyed to the buff's reach: party → Blessed halo, self → Rage. (SHIELD routes
			# through here too but gets its own bubble below, so it's excluded.)
			var buff_fx := ""
			if template == Config.TMPL_BUFF_PARTY:
				buff_fx = "Blessed"
			elif template == Config.TMPL_BUFF_SELF:
				buff_fx = "Rage"
			if buff_fx != "" and scaled.has("stat_armor"):
				buff_fx = "Armor"   # a defensive (armor) buff reads as Armor, not generic Rage/Blessed
			if buff_fx != "":
				_spawn_sprite_vfx(buff_fx, Vector2.ZERO, {"parent": tp, "fps": 18.0, "scale": 1.0})
	# +Armor isn't visible in the stat panel, so put a white silhouette outline on each shielded player
	# (the game's own outline shader) for the buff duration; restored when it expires.
	var auras := {}
	if scaled.has("stat_armor"):
		for pi in targets:
			var o = _apply_shield_outline(pi)
			if o != null:
				auras[pi] = o
	_active_buffs.append({"caster": place, "targets": targets, "stats": scaled, "remaining": dur, "total": dur, "auras": auras})
	# SHIELD: a looping Vivid shield bubble clings to each shielded ally for the buff's duration,
	# then self-fades — a clear "you're protected" read on top of the white silhouette outline.
	if template == Config.TMPL_SHIELD:
		for pi in targets:
			var sp = _player_node_for(pi)
			if sp != null and (sp is Node2D):
				_spawn_sprite_vfx("Shield", Vector2.ZERO, {"parent": sp, "loop": true, "life": dur, "fps": 16.0, "scale": 1.1})
	print("[Synergies] EFFECT '%s' tmpl=%s tier=%d dur=%.1fs targets=%s stats=%s" % [
		String(skill.get("name", "?")), template, tier, dur, str(targets), str(scaled)])
	_apply_aoe_rider(place, skill, tier, null)   # optional damaging burst on cast (cyborg laser / captain volley)
	# STAT DRAIN ZONE: create a persistent slow zone at caster position for the buff duration.
	# Any creep walking INTO the zone gets slowed; leaving restores speed.
	if bool(skill.get("stat_drain", false)):
		var caster = _player_node_for(place)
		if caster != null:
			var drain_radius = float(skill.get("radius", 150.0)) + float(skill.get("radius_per_tier", 0.0)) * (tier - 1)
			_spawn_drain_zone(caster.global_position, drain_radius, dur)
	# MATERIAL DROP RIDER: spawn materials around caster (Saver / Buccaneer)
	if skill.has("material_drop"):
		_apply_material_drop_rider(place, skill, tier)
	# STREAMER STANDING STILL BONUS: if caster was standing still for `standing_still_window` seconds
	# before casting, buff stats are multiplied by `standing_still_bonus`
	if skill.has("standing_still_bonus") and template == Config.TMPL_BUFF_PARTY:
		_apply_standing_still_rider(place, skill, tier, targets, scaled, dur)


# DASH — reposition the caster (teleport in the move direction) + a temp evasive self-buff (dodge/speed)
# + brief I-FRAMES (the caster's Hurtbox is disabled for `iframe` secs → truly takes no damage).
func _cast_dash(place: int, skill, tier: int) -> void:
	var caster = _player_node_for(place)
	if caster == null:
		return
	var dist : float = float(skill.get("distance", 250.0)) + float(skill.get("distance_per_tier", 0.0)) * (tier - 1)
	var dir := _dash_dir(caster)
	var before = caster.global_position
	# GLIDE smoothly to the target over DASH_GLIDE_SEC (like the Horned Bruiser charge) instead of a
	# blink — _tick_dashes lerps the position each frame. i-frames cover the glide (phases through).
	var to = before + dir * dist
	_dashes.append({"node": caster, "from": before, "to": to, "t": 0.0, "dur": DASH_GLIDE_SEC})
	# temp self-buff (dodge/speed) over the dash window
	var dur : float = float(skill.get("duration", 2.0)) + float(skill.get("dur_per_tier", 0.0)) * (tier - 1)
	var scaled := _scaled_stats(skill, tier)
	_grant_buff(place, [place], scaled, dur)
	var ifr : float = float(skill.get("iframe", 0.0)) + float(skill.get("iframe_per_tier", 0.0)) * (tier - 1)
	if ifr > 0.0:
		_grant_iframes(caster, ifr)
	if not skill.has("vfx"):
		_spawn_vfx(VFX_DASH, before)
	# Haste streak riding on the dasher through the glide.
	_spawn_sprite_vfx("Haste", Vector2.ZERO, {"parent": caster, "fps": 24.0, "scale": 1.0})
	# optional explosion at the LANDING point, timed to when the glide finishes (bull's impact charge)
	if skill.has("aoe_on_cast"):
		var t = get_tree().create_timer(DASH_GLIDE_SEC)
		t.connect("timeout", self, "_apply_aoe_rider", [place, skill, tier, to])
	# optional KNOCKBACK at the landing point (diver's rescue surge) — blast enemies outward + slow them
	if skill.has("knockback"):
		var tk = get_tree().create_timer(DASH_GLIDE_SEC)
		tk.connect("timeout", self, "_apply_knockback_rider", [place, skill, tier, to])
	print("[Synergies] DASH '%s' tier=%d dir=%s dist=%.0f iframe=%.2f %s->%s buff=%s" % [
		String(skill.get("name", "?")), tier, str(dir), dist, ifr, str(before), str(to), str(scaled)])


# Advance active DASH glides: ease-out lerp the node's position over `dur`; zero velocity so physics
# doesn't fling it after, drop when done or the unit is gone.
func _tick_dashes(delta: float) -> void:
	if _dashes.empty():
		return
	var i := _dashes.size() - 1
	while i >= 0:
		var d = _dashes[i]
		var node = d["node"]
		if node == null or not is_instance_valid(node):
			_dashes.remove(i)
			i -= 1
			continue
		d["t"] = float(d["t"]) + delta
		var k : float = clamp(float(d["t"]) / float(d["dur"]), 0.0, 1.0)
		var e : float = 1.0 - (1.0 - k) * (1.0 - k)   # ease-out quad
		node.global_position = (d["from"] as Vector2).linear_interpolate(d["to"], e)
		if "linear_velocity" in node:
			node.set("linear_velocity", Vector2.ZERO)
		if k >= 1.0:
			_dashes.remove(i)
		i -= 1


# Brief invulnerability: turn OFF the caster's Hurtbox (Area2D child) so no enemy hit registers, then
# restore after `dur`. set_deferred keeps it physics-safe; the restore is guarded if the unit is gone.
func _grant_iframes(caster, dur: float) -> void:
	var hb = caster.get_node_or_null("Hurtbox")
	if hb == null:
		print("[Synergies] i-frames: no Hurtbox child on caster")
		return
	hb.set_deferred("monitoring", false)
	hb.set_deferred("monitorable", false)
	var t = get_tree().create_timer(dur)
	t.connect("timeout", self, "_restore_hurtbox", [hb])


func _restore_hurtbox(hb) -> void:
	if hb != null and is_instance_valid(hb):
		hb.set_deferred("monitoring", true)
		hb.set_deferred("monitorable", true)


# --- Procedural VFX helpers (self-contained Node2D, _draw(), auto-free) ---

func _host_node():
	var host = _entities_node()
	if host == null:
		host = get_tree().current_scene
	return host

func spawn_arcane_ring(pos: Vector2, color: Color = Color(0.7, 0.3, 1.0), radius: float = 300.0) -> void:
	var host = _host_node()
	if host == null: return
	var v = VfxArcaneRing.new()
	v.ring_color = color
	v.max_radius = radius
	host.add_child(v)
	v.global_position = pos

func spawn_hit_burst(pos: Vector2, color_a: Color = Color(0.7, 0.3, 1.0), color_b: Color = Color(1.0, 0.5, 0.1), count: int = 12) -> void:
	var host = _host_node()
	if host == null: return
	var v = VfxHitBurst.new()
	v.burst_color_a = color_a
	v.burst_color_b = color_b
	v.particle_count = count
	host.add_child(v)
	v.global_position = pos

func spawn_explosion(pos: Vector2, color: Color = Color(1.0, 0.5, 0.1), radius: float = 100.0) -> void:
	var host = _host_node()
	if host == null: return
	var v = VfxExplosionBurst.new()
	v.explosion_color = color
	v.max_radius = radius
	host.add_child(v)
	v.global_position = pos

func spawn_stomp_shockwave(pos: Vector2, color: Color = Color(0.75, 0.45, 0.15), radius: float = 300.0) -> void:
	var host = _host_node()
	if host == null: return
	var v = VfxStompShockwave.new()
	v.stomp_color = color
	v.max_radius = radius
	host.add_child(v)
	v.global_position = pos

func spawn_vortex(pos: Vector2, outer_color: Color = Color(0.55, 0.3, 0.9), inner_color: Color = Color(0.3, 0.7, 0.85)) -> void:
	var host = _host_node()
	if host == null: return
	var v = VfxVortexBurst.new()
	v.outer_color = outer_color
	v.inner_color = inner_color
	host.add_child(v)
	v.global_position = pos

func spawn_necrotic_pulse(pos: Vector2, radius: float = 350.0, tint = null) -> void:
	var host = _host_node()
	if host == null: return
	var v = VfxNecroticPulse.new()
	v.max_radius = radius
	if tint is Color:
		v.ring_tint = tint   # caller's vfx_color (e.g. sick's green); null → the VFX's default necrotic green
	host.add_child(v)
	v.global_position = pos

func spawn_stone_scatter(pos: Vector2, color: Color = Color(0.6, 0.5, 0.4), radius: float = 200.0) -> void:
	var host = _host_node()
	if host == null: return
	var v = VfxStoneScatter.new()
	v.zone_color = color
	v.max_radius = radius
	host.add_child(v)
	v.global_position = pos

func spawn_tracer_line(from: Vector2, to: Vector2, color: Color = Color(1.0, 0.9, 0.5)) -> void:
	var host = _host_node()
	if host == null: return
	var v = VfxTracerLine.new()
	v.line_color = color
	v.start_pos = from
	v.end_pos = to
	host.add_child(v)
	v.global_position = Vector2.ZERO

func spawn_precision_flash(pos: Vector2) -> void:
	var host = _host_node()
	if host == null: return
	var v = VfxPrecisionFlash.new()
	host.add_child(v)
	v.global_position = pos

func spawn_energy_shockwave(pos: Vector2, color: Color = Color(0.8, 0.9, 1.0)) -> void:
	var host = _host_node()
	if host == null: return
	var v = VfxEnergyShockwave.new()
	v.ring_color = color
	host.add_child(v)
	v.global_position = pos

func spawn_buff_ring(pos: Vector2, color: Color = Color(1.0, 0.9, 0.4)) -> void:
	var host = _host_node()
	if host == null: return
	var v = VfxBuffRing.new()
	v.ring_color = color
	host.add_child(v)
	v.global_position = pos

func spawn_buff_aura(parent: Node2D, color: Color = Color(1.0, 0.9, 0.4, 0.6), life: float = 0.0) -> VfxBuffAura:
	var v = VfxBuffAura.new()
	v.aura_color = color
	v.life = life   # >0 → the aura self-expires (no dangling reference needed); 0 = caller manages it
	parent.add_child(v)
	v.position = Vector2.ZERO
	return v


# Spawn a reused game particle (one-shot) at a world position, then free it after its lifetime.
# Pure visual — safe to instance (no pool/physics deps). No-op if the scene fails to load.
func _spawn_vfx(path: String, pos: Vector2) -> void:
	var scn = load(path)
	if scn == null:
		return
	var p = scn.instance()
	var host = _entities_node()
	if host == null:
		host = get_tree().current_scene
	if host == null:
		p.free()
		return
	host.add_child(p)
	if p is Node2D:
		p.global_position = pos
	if "emitting" in p:
		p.set("emitting", true)
	var life := 1.2
	if "lifetime" in p:
		life = float(p.get("lifetime")) + 0.5
	var t = get_tree().create_timer(life)
	t.connect("timeout", p, "queue_free")


# Path to a Vivid-Motions effect's 4x4 spritesheet. effect="Heal" → ".../HealEffect/Spritesheets/
# HealEffect_Sheet_64x64.png". (PoisonBubble is the one folder without the "Effect" suffix; the few
# effects we wire all follow the regular pattern, so a dict override isn't needed yet.)
func _vivid_sheet(effect: String) -> String:
	return "%s/%sEffect/Spritesheets/%sEffect_Sheet_64x64.png" % [VIVID_DIR, effect, effect]


# Spawn a Vivid sprite VFX. opts: {parent:Node2D (follow it; else world pos), loop:bool, life:float,
# fps:float, scale:float, y:float, tint:Color}. Oneshot bursts free themselves after one pass;
# looping ones self-fade after `life` (or live until the caller frees them, when life<=0). Returns the
# node so a caller managing a persistent indicator (e.g. per-enemy slow) can queue_free it later.
func _spawn_sprite_vfx(effect: String, pos: Vector2, opts: Dictionary = {}) -> Node2D:
	var v = SpriteVfx.new()
	v.sheet_path = _vivid_sheet(effect)
	v.loop = bool(opts.get("loop", false))
	v.life = float(opts.get("life", 0.0))
	v.fps = float(opts.get("fps", 24.0))
	v.sprite_scale = float(opts.get("scale", 1.0))
	v.y_offset = float(opts.get("y", -8.0))
	if opts.has("tint"):
		v.tint = opts["tint"]
	var parent = opts.get("parent", null)
	if parent != null and is_instance_valid(parent) and (parent is Node2D):
		parent.add_child(v)
		v.position = Vector2.ZERO   # follow the parent; y_offset lifts the inner sprite
		return v
	var host = _entities_node()
	if host == null:
		host = get_tree().current_scene
	if host == null:
		v.free()
		return null
	host.add_child(v)
	v.global_position = pos
	return v


# Dash direction: current movement (RigidBody linear_velocity) if moving; else away from the nearest
# enemy (escape); else rightwards.
func _dash_dir(caster) -> Vector2:
	var v = caster.get("linear_velocity")
	if typeof(v) == TYPE_VECTOR2 and v.length() > 10.0:
		return v.normalized()
	var e = _nearest_enemy(caster.global_position)
	if e != null and is_instance_valid(e):
		var away : Vector2 = caster.global_position - e.global_position
		if away.length() > 1.0:
			return away.normalized()
	return Vector2.RIGHT


# Scale a skill's `stats` to a tier → {stat_key: amount}.
func _scaled_stats(skill, tier: int) -> Dictionary:
	var scaled := {}
	var base_stats : Dictionary = skill.get("stats", {})
	var per_tier : Dictionary = skill.get("stats_per_tier", {})
	for sk in base_stats.keys():
		scaled[sk] = int(base_stats[sk]) + int(per_tier.get(sk, 0)) * (tier - 1)
	return scaled


# Optional flavor RIDERS on a skill (what makes each AOE/HEAL distinct, not just numbers):
#   stats/stats_per_tier (+duration, buff_party) → a temp buff (self, or whole team if buff_party);
#   drain/drain_per_tier (+drain_party) → heal on cast (self, or team) — the "drain"/"siphon" flavor.
func _apply_skill_riders(place: int, skill, tier: int) -> void:
	var base_stats : Dictionary = skill.get("stats", {})
	if not base_stats.empty():
		var scaled := _scaled_stats(skill, tier)
		var dur : float = float(skill.get("duration", 4.0)) + float(skill.get("dur_per_tier", 0.0)) * (tier - 1)
		var targets := _places() if bool(skill.get("buff_party", false)) else [place]
		_grant_buff(place, targets, scaled, dur)
	var drain := int(skill.get("drain", 0)) + int(skill.get("drain_per_tier", 0)) * (tier - 1)
	if drain > 0:
		# Wave-scale the drain heal like _cast_heal does, so the siphon (vampire/lich/druid) doesn't go
		# stale in late waves while the skill's damage keeps scaling.
		var drain_amt := int(round(float(drain) * _wave_heal_mult()))
		var ts := _places() if bool(skill.get("drain_party", false)) else [place]
		for pi in ts:
			_heal_player(pi, drain_amt)


# SUMMON — deploy a temporary turret at the caster that auto-fires at nearby enemies (or heals allies).
# Reuses the game's turret SPRITE but our AOE-hitbox + beam/arc mechanics (no game-projectile pooling).
func _cast_summon(place: int, skill, tier: int) -> void:
	# SCOUT MODE (Curious): deploy a non-combat drone that orbits the caster, revealing enemies
	if bool(skill.get("scout_mode", false)):
		_cast_scout(place, skill, tier)
		return
	var caster = _player_node_for(place)
	if caster == null:
		return
	var host = _entities_node()
	if host == null:
		host = get_tree().current_scene
	if host == null:
		return
	var hit_radius : float = float(skill.get("hit_radius", 70.0)) + float(skill.get("hit_radius_per_tier", 0.0)) * (tier - 1)
	var life : float = float(skill.get("life", 6.0)) + float(skill.get("life_per_tier", 0.0)) * (tier - 1)
	var dmg := _aoe_damage(skill, tier, caster)   # base + the caster's Damage, like all AOE
	var opts := {
		"mode": String(skill.get("summon_mode", "damage")),
		"sprite": String(skill.get("sprite", "res://entities/structures/turret/turret.png")),
		"shot": String(skill.get("shot", "beam")),
		"color": _color_from(skill.get("shot_color", null), Color(1.0, 0.62, 0.2)),
		"interval": float(skill.get("interval", 1.0)),
		"range": float(skill.get("range", 350.0)) + float(skill.get("range_per_tier", 0.0)) * (tier - 1),
		"hit_radius": hit_radius,
		"dmg": dmg,
		"heal": int(skill.get("heal", 12)) + int(skill.get("heal_per_tier", 0)) * (tier - 1),
		"life": life,
		"burn": _burn_data(String(skill.get("burn", ""))),
	}
	var turret = SummonTurret.new()
	host.add_child(turret)
	if turret is Node2D:
		turret.global_position = caster.global_position + Vector2(0, -24)
	turret.setup(self, caster, opts)
	print("[Synergies] SUMMON '%s' tier=%d dmg=%d life=%.1fs shot=%s at=%s" % [
		String(skill.get("name", "?")), tier, dmg, life, String(skill.get("shot", "beam")), str(turret.global_position)])
	_apply_skill_riders(place, skill, tier)   # optional self-buff on cast (e.g. +Engineering)


# Heal allies within `radius` of a healing turret (called back by summon_turret.gd in heal mode).
func _turret_heal(center: Vector2, radius: float, amt: int) -> void:
	for pi in _places():
		var p = _player_node_for(pi)
		if p != null and (p is Node2D) and p.global_position.distance_to(center) <= radius:
			_heal_player(pi, amt)
	_spawn_heal_aura(center, radius)


# SCOUT MODE (Curious) — deploy a non-combat drone that orbits the caster, revealing enemies.
# The drone doesn't attack — it just flies around, highlights enemies it passes near, and auto-picks
# up materials within its orbit radius.
var _scouts := []  # active scout drones [{node, caster, orbit_radius, angle, life, reveal_nodes}]

func _cast_scout(place: int, skill, tier: int) -> void:
	var caster = _player_node_for(place)
	if caster == null:
		return
	var host = _entities_node()
	if host == null:
		host = get_tree().current_scene
	if host == null:
		return
	var life : float = float(skill.get("life", 5.0)) + float(skill.get("life_per_tier", 1.0)) * (tier - 1)
	var orbit_radius : float = float(skill.get("range", 300.0)) + float(skill.get("range_per_tier", 30.0)) * (tier - 1)
	# Create a simple drone node (reuse the turret sprite as a small drone)
	var drone = Sprite.new()
	var tex = load(String(skill.get("sprite", "res://entities/structures/turret/turret.png")))
	if tex != null:
		drone.texture = tex
		drone.scale = Vector2(0.4, 0.4)  # smaller than turret
	drone.modulate = Color(1.0, 0.9, 0.3, 0.8)  # gold tint
	host.add_child(drone)
	if drone is Node2D:
		drone.global_position = caster.global_position + Vector2(0, -40)
	_scouts.append({
		"node": drone,
		"caster": caster,
		"orbit_radius": orbit_radius,
		"angle": 0.0,
		"life": life,
		"reveal_nodes": [],
	})
	print("[Synergies] SCOUT '%s' tier=%d life=%.1fs orbit=%.0f" % [
		String(skill.get("name", "?")), tier, life, orbit_radius])


# Tick all active scout drones: orbit the caster, reveal nearby enemies, auto-pickup materials.
func _tick_scouts(delta: float) -> void:
	if _scouts.empty():
		return
	var i := _scouts.size() - 1
	while i >= 0:
		var s = _scouts[i]
		var drone = s["node"]
		var caster = s["caster"]
		# Remove if drone or caster is gone
		if drone == null or not is_instance_valid(drone) or caster == null or not is_instance_valid(caster):
			_restore_scout_tints(s)
			if drone != null and is_instance_valid(drone):
				drone.queue_free()
			_scouts.remove(i)
			i -= 1
			continue
		# Countdown life
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			_restore_scout_tints(s)
			drone.queue_free()
			_scouts.remove(i)
			i -= 1
			continue
		# Orbit the caster
		s["angle"] = float(s["angle"]) + delta * 2.0  # 2 radians/sec orbit speed
		var orbit_pos = caster.global_position + Vector2(
			cos(float(s["angle"])) * float(s["orbit_radius"]),
			sin(float(s["angle"])) * float(s["orbit_radius"]) * 0.5  # flatten for top-down
		)
		drone.global_position = orbit_pos
		# Reveal nearby enemies (add gold outline)
		var reveal_radius := 150.0
		for e in _enemies_near(orbit_pos, reveal_radius):
			if e != null and is_instance_valid(e) and e is Node2D:
				# Apply reveal effect (gold modulate)
				if "modulate" in e:
					var cur = e.modulate
					e.modulate = Color(cur.r, cur.g * 0.9, cur.b * 0.5, 1.0)  # golden tint
				if "reveal_nodes" in s and not (e in s["reveal_nodes"]):
					s["reveal_nodes"].append(e)
		i -= 1
	# Clean up reveal effects on remaining scouts
	for s in _scouts:
		_restore_scout_tints(s)


func _restore_scout_tints(s) -> void:
	for e in s.get("reveal_nodes", []):
		if e != null and is_instance_valid(e) and "modulate" in e:
			e.modulate = Color.white


# CC FREEZE — stop ALL living enemies for `duration` (Brotato has no hard stun, so we zero their speed
# stat → movement behavior yields ~0 velocity → melee can't reach; also zero velocity + icy tint). NO
# damage (pure control). Speed + modulate are restored when the freeze expires or the enemy dies.
func _cast_cc(place: int, skill, tier: int) -> void:
	var dur : float = float(skill.get("duration", 1.5)) + float(skill.get("dur_per_tier", 0.0)) * (tier - 1)
	var tint := _color_from(skill.get("freeze_tint", null), Color(0.55, 0.85, 1.0))
	var caster = _player_node_for(place)
	var origin = caster.global_position if caster != null else Vector2.ZERO
	# Open a FREEZE WINDOW: lock the whole arena now, and keep locking enemies that spawn during `dur`
	# (_tick_freeze_window re-scans). Re-casting extends any still-frozen enemy to the new window end.
	_freeze_window = {"remaining": dur, "tint": tint, "vfx_n": 0, "scan_t": 0.0}
	for f in _frozen:
		f["remaining"] = max(float(f["remaining"]), dur)
	var n := _freeze_scan(dur, tint)
	if not skill.has("vfx"):
		_spawn_vfx(VFX_BUFF, origin)
	print("[Synergies] CC FREEZE '%s' tier=%d dur=%.1fs froze=%d (window open)" % [String(skill.get("name", "?")), tier, dur, n])


# Freeze every arena enemy not already held, leaving `remaining` secs on each. Returns how many NEWLY froze.
# Shared by the initial cast and the window re-scan, so new spawns get the same treatment.
func _freeze_scan(remaining: float, tint: Color) -> int:
	var frozen_set := {}
	for f in _frozen:
		var fn = f["node"]
		if fn != null and is_instance_valid(fn):
			frozen_set[fn] = true
	var n := 0
	for e in _enemies_near(Vector2.ZERO, 1.0e9):   # every enemy on the arena
		if e == null or not is_instance_valid(e) or frozen_set.has(e):
			continue
		_freeze_one_enemy(e, remaining, tint)
		n += 1
	return n


# Hold one enemy for `remaining` secs. Bosses (see _is_boss_enemy) CAN'T be fully frozen — they keep
# BOSS_FREEZE_SPEED of their move speed (the rest of the lockdown doesn't apply); normal enemies stop dead.
func _freeze_one_enemy(e, remaining: float, tint: Color) -> void:
	if e == null or not is_instance_valid(e):
		return
	var is_boss := _is_boss_enemy(e)
	var cs = e.get("current_stats")
	var spd = null
	if cs != null and ("speed" in cs):
		spd = int(cs.get("speed"))
		cs.set("speed", int(spd * BOSS_FREEZE_SPEED) if is_boss else 0)
	if (not is_boss) and ("linear_velocity" in e):
		e.set("linear_velocity", Vector2.ZERO)
	var prevmod = null
	if "modulate" in e:
		prevmod = e.modulate
		e.modulate = tint
	# VFX: normal enemy → Freeze crystal; boss → Slow (it's only hard-slowed). Capped via the window budget.
	if _freeze_window.has("vfx_n") and int(_freeze_window["vfx_n"]) < 60:
		var fx := "Slow" if is_boss else "Freeze"
		_spawn_sprite_vfx(fx, Vector2.ZERO, {"parent": e, "loop": true, "life": remaining, "fps": 13.0, "scale": 0.9})
		_freeze_window["vfx_n"] = int(_freeze_window["vfx_n"]) + 1
	_frozen.append({"node": e, "cs": cs, "speed": spd, "modulate": prevmod, "remaining": remaining, "boss": is_boss})


# Brotato bosses (mom, gargoyle, colossus, croc, …) carry health_increase_each_wave ≈ 700-750; every
# normal mob / elite is ≤ ~35. A ≥100 threshold cleanly flags the true bosses. Read off the unit's Stats.
func _is_boss_enemy(e) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	var st = e.get("max_stats")
	if st == null:
		st = e.get("current_stats")
	if st != null and ("health_increase_each_wave" in st):
		return float(st.get("health_increase_each_wave")) >= 100.0
	return false


# While a CC freeze window is open: tick it down and, throttled, re-scan to lock enemies that spawned
# after the cast — so the whole arena stays held for the full duration. Clears itself when it expires.
func _tick_freeze_window(delta: float) -> void:
	if _freeze_window.empty():
		return
	_freeze_window["remaining"] = float(_freeze_window["remaining"]) - delta
	if float(_freeze_window["remaining"]) <= 0.0:
		_freeze_window.clear()
		return
	_freeze_window["scan_t"] = float(_freeze_window.get("scan_t", 0.0)) + delta
	if float(_freeze_window["scan_t"]) >= FREEZE_RESCAN_INTERVAL:
		_freeze_window["scan_t"] = 0.0
		_freeze_scan(float(_freeze_window["remaining"]), _freeze_window["tint"])


# TAUNT (Masochist "Retribution") — open a window that drags nearby enemies toward the caster, like the
# Scapegoat pet pulling aggro. The game's enemy AI can't be reliably retargeted from here, so _tick_taunt
# overrides enemy POSITION each frame (the same lever the knockback/dash glides use), which is decisive.
func _apply_taunt(place: int, skill, tier: int) -> void:
	var dur : float = float(skill.get("taunt", 5.0)) + float(skill.get("taunt_per_tier", 1.0)) * (tier - 1)
	var radius : float = float(skill.get("taunt_radius", 450.0))
	_taunt = {"place": place, "remaining": dur, "radius": radius}
	var caster = _player_node_for(place)
	if caster != null and (caster is Node2D):
		spawn_buff_aura(caster, Color(1.0, 0.3, 0.2, 0.55), dur)   # red "provoke" glow for the window
	print("[Synergies] TAUNT '%s' place=%d dur=%.1fs r=%.0f" % [String(skill.get("name", "?")), place, dur, radius])


# Each frame of the taunt: pull every non-boss enemy within `radius` toward the caster at ~1.5× its own
# pace (bounded), overriding its movement so the room collapses onto the Masochist. Bosses are exempt.
func _tick_taunt(delta: float) -> void:
	if _taunt.empty():
		return
	_taunt["remaining"] = float(_taunt["remaining"]) - delta
	if float(_taunt["remaining"]) <= 0.0:
		_taunt.clear()
		return
	var p = _player_node_for(int(_taunt["place"]))
	if p == null or not is_instance_valid(p) or not (p is Node2D):
		_taunt.clear()
		return
	var center = p.global_position
	var radius : float = float(_taunt["radius"])
	for e in _enemies_near(center, radius):
		if e == null or not is_instance_valid(e) or not (e is Node2D):
			continue
		if _is_boss_enemy(e):
			continue
		var to = center - e.global_position
		var d : float = to.length()
		if d <= 24.0:
			continue
		var spd : float = 0.0
		var cs = e.get("current_stats")
		if cs != null and ("speed" in cs):
			spd = float(cs.get("speed"))
		var pull : float = clamp(spd * 1.5, 150.0, 450.0)   # decisive but follows the enemy's own pace
		var step : float = min(d - 24.0, pull * delta)
		e.global_position = e.global_position + to.normalized() * step


# Hold frozen enemies still each frame; restore speed + tint when the freeze ends or the enemy dies.
func _tick_frozen(delta: float) -> void:
	if _frozen.empty():
		return
	var i := _frozen.size() - 1
	while i >= 0:
		var f = _frozen[i]
		var e = f["node"]
		var gone : bool = (e == null) or (not is_instance_valid(e))
		f["remaining"] = float(f["remaining"]) - delta
		if not gone and not bool(f.get("boss", false)) and ("linear_velocity" in e):
			e.set("linear_velocity", Vector2.ZERO)   # backup hold (speed=0); bosses keep crawling at 40%
		if gone or float(f["remaining"]) <= 0.0:
			_restore_frozen(f)
			_frozen.remove(i)
		i -= 1


func _restore_frozen(f) -> void:
	var e = f["node"]
	if e == null or not is_instance_valid(e):
		return
	var cs = f["cs"]
	if cs != null and f["speed"] != null and ("speed" in cs):
		cs.set("speed", f["speed"])
	if f["modulate"] != null and ("modulate" in e):
		e.modulate = f["modulate"]


# CURSE CLOUD — purple poison zone: slow enemies + DoT scaled by player's curse count.
# Zone persists for the skill duration; any enemy inside gets slowed and takes damage every 0.2s.
func _cast_curse_cloud(place: int, skill, tier: int) -> void:
	var dur : float = float(skill.get("duration", 6.0)) + float(skill.get("dur_per_tier", 1.0)) * (tier - 1)
	var radius : float = float(skill.get("radius", 150.0)) + float(skill.get("radius_per_tier", 0.0)) * (tier - 1)
	var curse_dmg_pct : float = float(skill.get("curse_dmg_percent", 0.2))
	var tick_interval : float = float(skill.get("tick_interval", 0.2))
	var slow_pct : float = float(skill.get("slow_percent", 0.5))
	var caster = _player_node_for(place)
	if caster == null:
		return
	# Read player's curse count from effects dict (Lời Nguyện stat)
	var curse_count := 0
	var rd = _run_data()
	if rd != null:
		var effects = rd.get_player_effects(place)
		if typeof(effects) == TYPE_DICTIONARY:
			var curse_key = _stat_hash("stat_curse")
			curse_count = int(effects.get(curse_key, 0))
	# DoT/tick = max( wave-scaled base floor , curse_count * curse_dmg_percent ). The floor keeps the cloud
	# useful on low/zero-curse builds AND grows with the wave; a curse-stacking build overtakes it (its
	# whole identity), so the skill rewards the build without being dead weight otherwise.
	var base_dmg := int(skill.get("base_damage", 5)) + int(skill.get("base_damage_per_tier", 0)) * (tier - 1)
	var floor_dmg := _scaled_damage(base_dmg, tier, caster)
	var curse_dmg := int(curse_count * curse_dmg_pct)
	var final_dmg = max(floor_dmg, curse_dmg)
	# Spawn visual purple ring
	var ring = AoeRing.new()
	var host = _host_node()
	if host != null:
		host.add_child(ring)
		ring.global_position = caster.global_position
		ring.setup(radius, Color(0.5, 0.2, 0.7, 0.6), dur)
	# Curse sigil pulsing at the cloud's heart for its lifetime (the ring already shows the area).
	_spawn_sprite_vfx("Curse", caster.global_position, {"loop": true, "life": dur, "fps": 13.0, "scale": 1.6})
	# Create the cloud zone
	var zone = {
		"pos": caster.global_position,
		"radius": radius,
		"remaining": dur,
		"dmg": final_dmg,
		"tick_interval": tick_interval,
		"tick_timer": 0.0,
		"slow_percent": slow_pct,   # key MUST match what _tick_drained reads (was "slow_pct" → ignored)
		"slowed": {},
	}
	_drain_zones.append(zone)
	print("[Synergies] CURSE CLOUD: pos=%s r=%.0f dur=%.1fs dmg/tick=%d (floor=%d curse=%d) curseStat=%d slow=%.0f%%" % [
		str(caster.global_position), radius, dur, final_dmg, floor_dmg, curse_dmg, curse_count, slow_pct * 100])


# HEAL ZONE (Doctor's Field Hospital) — BLINK to the lowest-HP ally, then drop a lasting field that heals
# every ally inside for a % of their MAX HP each second AND slows enemies that step in. The zone is tracked
# in _drain_zones (which already slows + restores enemies); we tag it with `heal_percent` so _tick_drained
# also pulses the heal. Radius + %/s both grow with tier.
func _cast_heal_zone(place: int, skill, tier: int) -> void:
	var dur : float = float(skill.get("duration", 6.0)) + float(skill.get("dur_per_tier", 0.0)) * (tier - 1)
	var radius : float = float(skill.get("radius", 180.0)) + float(skill.get("radius_per_tier", 0.0)) * (tier - 1)
	var heal_pct : float = float(skill.get("heal_percent", 0.03)) + float(skill.get("heal_percent_per_tier", 0.0)) * (tier - 1)
	var tick_interval : float = float(skill.get("tick_interval", 1.0))
	var slow_pct : float = float(skill.get("slow_percent", 0.4))
	var caster = _player_node_for(place)
	if caster == null:
		return
	# BLINK to the lowest-HP ally (could be the caster — then it's an in-place cast). Glide via _dashes so
	# it reads as a teleport-dash, not a jump-cut; brief i-frames cover the move.
	var target_pi := _lowest_hp_ally(place)
	var dest = caster.global_position
	var ally = _player_node_for(target_pi)
	if ally != null and (ally is Node2D) and target_pi != place:
		# land a little to the side of the ally, not on top of them
		dest = ally.global_position + Vector2(36, 0)
		_dashes.append({"node": caster, "from": caster.global_position, "to": dest, "t": 0.0, "dur": DASH_GLIDE_SEC})
		_grant_iframes(caster, DASH_GLIDE_SEC + 0.1)
	# Mark the zone with the game's Doc Moth aura sprite ONLY (the soft green "butterfly" glow), held for
	# the whole duration — no hand-drawn ring. Heal pulses spawn the rising heal particles each tick.
	var aura = _spawn_heal_aura(dest, radius, dur)
	# Regen sigil marking the field for its lifetime, layered over the soft green aura.
	_spawn_sprite_vfx("Regen", dest, {"loop": true, "life": dur, "fps": 12.0, "scale": 1.4})
	_drain_zones.append({
		"pos": dest, "radius": radius, "remaining": dur,
		"heal_percent": heal_pct, "tick_interval": tick_interval, "tick_timer": 0.0,
		"slow_percent": slow_pct, "slowed": {}, "aura": aura,
	})
	print("[Synergies] HEAL ZONE: -> ally pi=%d pos=%s r=%.0f dur=%.1fs heal=%.1f%%/s slow=%.0f%%" % [
		target_pi, str(dest), radius, dur, heal_pct * 100, slow_pct * 100])


# The co-op place whose unit has the lowest current/max HP fraction (ties → lowest place). Falls back to
# `caster_place` if no other ally has readable stats.
func _lowest_hp_ally(caster_place: int) -> int:
	var best_pi := caster_place
	var best_frac := 2.0
	for pi in _places():
		var p = _player_node_for(pi)
		if p == null:
			continue
		var cs = p.get("current_stats")
		var ms = p.get("max_stats")
		if cs == null or ms == null:
			continue
		var maxh : float = float(ms.get("health"))
		if maxh <= 0.0:
			continue
		var frac : float = float(cs.get("health")) / maxh
		if frac < best_frac:
			best_frac = frac
			best_pi = pi
	return best_pi


# STAT DRAIN ZONE — create a persistent slow zone at a position.
# Any enemy INSIDE the zone gets slowed; leaving restores speed.
func _spawn_drain_zone(pos: Vector2, radius: float, dur: float) -> void:
	# Spawn visual ring (reuse AoeRing with blue color, longer life)
	var ring = AoeRing.new()
	var host = _host_node()
	if host != null:
		host.add_child(ring)
		ring.global_position = pos
		ring.setup(radius, Color(0.3, 0.6, 1.0, 0.6), dur)
	# (Slow shows per-enemy in _apply_zone_slow, not as a center marker — the blue ring is the area.)
	# Track the zone
	var zone = {"pos": pos, "radius": radius, "remaining": dur, "slowed": {}}
	_drain_zones.append(zone)
	print("[Synergies] DRAIN ZONE: pos=%s r=%.0f dur=%.1fs" % [str(pos), radius, dur])


# ZONE tick — slow enemies inside + DoT for curse_cloud zones. The heavy work (a full _enemies_near
# scan of the arena) is THROTTLED to each zone's tick_interval (~0.2s) instead of running every frame:
# a 0.2s lag on acquiring/releasing a slow is imperceptible, but it cuts the per-frame cost ~12× and
# keeps multiple zones in late/endless waves from stacking into a per-frame tree-walk storm.
func _tick_drained(delta: float) -> void:
	if _drain_zones.empty():
		return
	var i := _drain_zones.size() - 1
	while i >= 0:
		var zone = _drain_zones[i]
		zone["remaining"] = float(zone["remaining"]) - delta
		# Zone expired → restore all slowed enemies + free the aura
		if float(zone["remaining"]) <= 0.0:
			for e in zone["slowed"].keys():
				_restore_slowed_enemy(e, zone["slowed"][e])
			_free_zone_aura(zone)
			_drain_zones.remove(i)
			i -= 1
			continue
		# Throttle: only do the expensive scan/slow/DoT pass on the tick boundary.
		var tick_int = float(zone.get("tick_interval", 0.2))
		zone["tick_timer"] = float(zone.get("tick_timer", 0.0)) + delta
		if float(zone["tick_timer"]) < tick_int:
			i -= 1
			continue
		zone["tick_timer"] = float(zone["tick_timer"]) - tick_int
		var pos = zone["pos"]
		var radius = zone["radius"]
		var slowed = zone["slowed"]
		var slow_pct = float(zone.get("slow_percent", 0.5))
		var is_curse : bool = zone.has("dmg") and int(zone["dmg"]) > 0
		# HEAL ZONE (Doctor): pulse a %-of-max-HP heal to every ally standing inside, this tick.
		if zone.has("heal_percent"):
			_heal_zone_pulse(pos, radius, float(zone["heal_percent"]))
		# ONE arena scan, reused for both DoT and slow-acquisition.
		var inside = _enemies_near(pos, radius)
		var inside_set = {}
		for e in inside:
			if e == null or not is_instance_valid(e):
				continue
			inside_set[e] = true
			# DoT (curse_cloud only): damage via the real hitbox pipeline.
			if is_curse:
				_spawn_aoe_hitbox(e.global_position, int(zone["dmg"]), 10.0, _player_node_for(0), Color(0.5, 0.2, 0.7), null, true)
			# Slow on entry (skip if already slowed by this zone).
			if slowed.has(e):
				continue
			_apply_zone_slow(e, slowed, slow_pct, is_curse, false)
		# Restore enemies that LEFT the zone (or died). STICKY ones (knocked-back) stay slowed even when
		# outside — they only restore when the zone expires.
		var to_remove = []
		for e in slowed.keys():
			if e == null or not is_instance_valid(e):
				_restore_slowed_enemy(e, slowed[e])
				to_remove.append(e)
			elif not inside_set.has(e) and not bool(slowed[e].get("sticky", false)):
				_restore_slowed_enemy(e, slowed[e])
				to_remove.append(e)
		for e in to_remove:
			slowed.erase(e)
		i -= 1


# Apply a zone's slow to one enemy and record the pre-slow data into `slowed` (so it can be restored).
# `sticky` = stay slowed even after leaving the zone (used for knocked-back enemies). No-op if already in.
func _apply_zone_slow(e, slowed, slow_pct: float, is_curse: bool, sticky: bool) -> void:
	if e == null or not is_instance_valid(e) or slowed.has(e):
		return
	var cs = e.get("current_stats")
	var orig_speed = null
	if cs != null and "speed" in cs:
		orig_speed = int(cs.get("speed"))
		if orig_speed > 0:
			cs.set("speed", int(orig_speed * (1.0 - slow_pct)))
	var prevmod = null
	if "modulate" in e:
		prevmod = e.modulate
		e.modulate = Color(0.6, 0.2, 0.8) if is_curse else Color(0.55, 0.85, 1.0)
	# A Slow snail clinging to each slowed enemy (Doctor's field 40%, Diver, drain zones). Skipped inside
	# a curse cloud — those enemies already read as cursed (purple tint + Curse sigil), no need to stack.
	var vfx = null
	if (e is Node2D) and not is_curse:
		vfx = _spawn_sprite_vfx("Slow", Vector2.ZERO, {"parent": e, "loop": true, "fps": 11.0, "scale": 0.7})
	slowed[e] = {"cs": cs, "speed": orig_speed, "modulate": prevmod, "sticky": sticky, "vfx": vfx}


# Heal every co-op ally standing within `radius` of `pos` by `pct` of their MAX HP (one pulse). Clamped
# to max HP by _heal_player. Used by the Doctor's heal zone each tick.
func _heal_zone_pulse(pos: Vector2, radius: float, pct: float) -> void:
	for pi in _places():
		var p = _player_node_for(pi)
		if p == null or not (p is Node2D):
			continue
		if p.global_position.distance_to(pos) > radius:
			continue
		var ms = p.get("max_stats")
		if ms == null:
			continue
		var amt := int(round(float(ms.get("health")) * pct))
		if amt > 0:
			_heal_player(pi, amt)


# Restore one slowed enemy's speed + modulate from its stashed pre-slow data (guards a freed node).
func _restore_slowed_enemy(e, data) -> void:
	# Free the clinging Slow sprite first — do this even if the enemy node is gone (the sprite is its
	# child, so it's freed with the parent anyway, but an explicit free is harmless and clear).
	var vfx = data.get("vfx", null)
	if vfx != null and is_instance_valid(vfx):
		vfx.queue_free()
	if e == null or not is_instance_valid(e):
		return
	var cs = data["cs"]
	if cs != null and ("speed" in cs) and data["speed"] != null:
		cs.set("speed", data["speed"])
	if data["modulate"] != null and ("modulate" in e):
		e.modulate = data["modulate"]


# Restore every enemy slowed by a zone, free any held aura, then drop all zones (heal/curse_cloud/drain).
func _clear_drain_zones() -> void:
	for zone in _drain_zones:
		for e in zone["slowed"].keys():
			_restore_slowed_enemy(e, zone["slowed"][e])
		_free_zone_aura(zone)
	_drain_zones.clear()


# Free a zone's persistent aura node, if it holds one (the Doctor's field).
func _free_zone_aura(zone) -> void:
	var a = zone.get("aura", null)
	if a != null and is_instance_valid(a):
		a.queue_free()


# Wave ended → drop every lingering in-arena effect so nothing leaks into the shop or the next wave:
# the persistent zones, frozen/slowed enemies, and in-flight dashes. (Buffs are handled separately by
# _expire_all_buffs; the aura/ring VFX self-free on their own timers.)
func _clear_wave_effects() -> void:
	_clear_drain_zones()
	for f in _frozen:
		_restore_frozen(f)
	_frozen.clear()
	_freeze_window.clear()
	_dashes.clear()
	_pushed.clear()
	_scouts.clear()
	_greed.clear()   # a Midas window never carries into the shop / next wave
	_taunt.clear()   # a taunt drag never carries into the shop / next wave


# GREED (Jack "Jackpot") — for `duration`s, ×`mult` EVERY material the whole team picks up. Each frame
# we read each player's materials (RunData.players_data[place].gold) and top up the bonus for whatever
# they just collected. Self-balancing: it can only multiply gems that actually exist on the floor, so
# even a high mult can't farm infinitely — it rewards casting when the arena is littered with gems.
func _cast_greed(place: int, skill, tier: int) -> void:
	var dur : float = float(skill.get("duration", 6.0)) + float(skill.get("dur_per_tier", 0.0)) * (tier - 1)
	var mult : float = float(skill.get("mult", 3.0)) + float(skill.get("mult_per_tier", 0.0)) * (tier - 1)
	# Baseline = every player's current materials, so we only multiply NEW pickups during the window.
	var prev := {}
	for pl in _places():
		prev[pl] = _player_gold(pl)
	_greed = {"mult": mult, "remaining": dur, "prev": prev}
	# Gold sparkle on each player so the team sees the windfall kick in.
	for pl in _places():
		var p = _player_node_for(pl)
		if p != null and (p is Node2D):
			_spawn_vfx(VFX_BUFF, p.global_position)
	print("[Synergies] GREED (Jackpot) x%.1f for %.1fs over places %s" % [mult, dur, str(_places())])


func _tick_greed(delta: float) -> void:
	if _greed.empty():
		return
	_greed["remaining"] = float(_greed["remaining"]) - delta
	var mult : float = float(_greed["mult"])
	var prev : Dictionary = _greed["prev"]
	for pl in _places():
		var now : int = _player_gold(pl)
		if now < 0:
			continue                      # can't read this player's materials this frame
		var base : int = int(prev.get(pl, now))
		var gained : int = now - base
		if gained > 0:
			var bonus : int = int(round(float(gained) * (mult - 1.0)))
			if bonus > 0:
				_add_player_gold(pl, bonus)
				now += bonus              # account for our own top-up so next tick's delta is natural-only
		prev[pl] = now
	if float(_greed["remaining"]) <= 0.0:
		print("[Synergies] GREED window ended")
		_greed.clear()


# Player `place`'s current materials (RunData.players_data[place].gold), or -1 if unreadable.
func _player_gold(place: int) -> int:
	var rd = _run_data()
	if rd == null or not ("players_data" in rd):
		return -1
	var arr = rd.players_data
	if typeof(arr) != TYPE_ARRAY or arr.size() <= place:
		return -1
	var pd = arr[place]
	if pd == null or not ("gold" in pd):
		return -1
	return int(pd.gold)


# Grant `amount` materials to player `place` by writing players_data[place].gold (the game stores it as
# a plain property; the HUD refreshes on the next natural pickup, which happens constantly mid-window).
func _add_player_gold(place: int, amount: int) -> void:
	if amount <= 0:
		return
	var rd = _run_data()
	if rd == null or not ("players_data" in rd):
		return
	var arr = rd.players_data
	if typeof(arr) != TYPE_ARRAY or arr.size() <= place:
		return
	var pd = arr[place]
	if pd != null and ("gold" in pd):
		pd.gold = int(pd.gold) + amount


# Dispel the Danger-6 fog for `secs` by hiding the fog viewport (modulate alpha → 0). No-op on dangers
# without fog. The original modulate is stashed in node meta so overlapping casts don't lose it.
func _clear_fog(secs: float) -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return
	var fog = _find_fog(scene, 0)
	if fog == null:
		print("[Synergies] clear_fog: no fog node found (not Danger 6?)")
		return
	if not ("modulate" in fog):
		return
	if not fog.has_meta("syn_fog_orig"):
		fog.set_meta("syn_fog_orig", fog.modulate)
	var orig = fog.get_meta("syn_fog_orig")
	fog.modulate = Color(orig.r, orig.g, orig.b, 0.0)
	print("[Synergies] clear_fog %.1fs (node=%s)" % [secs, String(fog.name)])
	var t = get_tree().create_timer(secs)
	t.connect("timeout", self, "_restore_fog", [fog])


func _restore_fog(fog) -> void:
	if fog != null and is_instance_valid(fog) and fog.has_meta("syn_fog_orig"):
		fog.modulate = fog.get_meta("syn_fog_orig")
		fog.remove_meta("syn_fog_orig")


# CHARM RIDER (Romantic) — charm nearby enemies below HP threshold for a duration.
# Charmed enemies wander randomly and don't attack the player (similar to Flute weapon mechanic).
func _apply_charm_rider(place: int, skill, tier: int) -> void:
	var charm_cfg = skill.get("charm", {})
	var count = int(charm_cfg.get("count", 2)) + int(charm_cfg.get("count_per_tier", 0)) * (tier - 1)
	var hp_thresh : float = float(charm_cfg.get("hp_threshold", 0.6))
	var charm_dur : float = float(charm_cfg.get("duration", 3.0)) + float(charm_cfg.get("duration_per_tier", 0.5)) * (tier - 1)
	var caster = _player_node_for(place)
	if caster == null:
		return
	var origin = caster.global_position
	# Find nearby enemies below HP threshold
	var nearby = _enemies_near(origin, 400.0)
	var candidates = []
	for e in nearby:
		if e == null or not is_instance_valid(e):
			continue
		var cs = e.get("current_stats")
		var ms = e.get("max_stats")
		if cs != null and ms != null:
			var hp : float = float(cs.get("health"))
			var maxhp : float = float(ms.get("health"))
			if maxhp > 0.0 and (hp / maxhp) < hp_thresh:
				candidates.append(e)
	# Charm up to `count` enemies
	var charmed = 0
	for e in candidates:
		if charmed >= count:
			break
		_charm_enemy(e, charm_dur)
		charmed += 1
	if charmed > 0:
		print("[Synergies] CHARM RIDER: charmed %d enemies for %.1fs (threshold=%.0f%%)" % [
			charmed, charm_dur, hp_thresh * 100])


# Charm a single enemy — it wanders randomly for `dur` seconds, doesn't attack the player.
func _charm_enemy(e, dur: float) -> void:
	if e == null or not is_instance_valid(e):
		return
	# Store original behavior state
	var prev_modulate = e.modulate if "modulate" in e else null
	# Apply pink tint (charm visual)
	if "modulate" in e:
		e.modulate = Color(1.0, 0.6, 0.8, 1.0)
	# Spawn heart VFX
	if e is Node2D:
		_spawn_vfx(VFX_BUFF, e.global_position)
		# Charm hearts cling to the enemy for the charm window as it wanders off.
		_spawn_sprite_vfx("Charm", Vector2.ZERO, {"parent": e, "loop": true, "life": dur, "fps": 12.0, "scale": 0.85})
	# Disable enemy's ability to attack (set speed to wandering mode)
	var cs = e.get("current_stats")
	var orig_speed = null
	if cs != null and "speed" in cs:
		orig_speed = cs.get("speed")
		cs.set("speed", cs.get("speed") * 0.5)  # slow down but don't stop
	# Set random wandering velocity
	if "linear_velocity" in e:
		var wander_dir = Vector2(rand_range(-1, 1), rand_range(-1, 1)).normalized()
		e.set("linear_velocity", wander_dir * 80.0)
	# Timer to restore
	var t = get_tree().create_timer(dur)
	t.connect("timeout", self, "_restore_charmed", [e, prev_modulate, orig_speed])


func _restore_charmed(e, prev_modulate, orig_speed) -> void:
	if e == null or not is_instance_valid(e):
		return
	if "modulate" in e and prev_modulate != null:
		e.modulate = prev_modulate
	var cs = e.get("current_stats")
	if cs != null and orig_speed != null and "speed" in cs:
		cs.set("speed", orig_speed)
	if "linear_velocity" in e:
		e.set("linear_velocity", Vector2.ZERO)


# MATERIAL DROP RIDER — spawn materials around the caster when casting (Saver / Buccaneer).
# Materials fall from above with a gold sparkle effect.
func _apply_material_drop_rider(place: int, skill, tier: int) -> void:
	var count = int(skill.get("material_drop", 5)) + int(skill.get("material_drop_per_tier", 1)) * (tier - 1)
	var caster = _player_node_for(place)
	if caster == null:
		return
	var origin = caster.global_position
	# Find the RunData to add materials
	var run_data = null
	if get_tree().current_scene and get_tree().current_scene.has_method("get"):
		run_data = get_tree().current_scene.get("run_data")
	# Also try via GameRunManager
	if run_data == null:
		var grm = get_tree().root.get_node_or_null("GameRunManager")
		if grm != null:
			run_data = grm.get("run_data")
	if run_data == null:
		print("[Synergies] MATERIAL DROP: no RunData found, skipping")
		return
	# Spawn material entities in a circle around caster
	var angle_step = TAU / max(count, 1)
	var spawn_radius = 60.0
	for i in range(count):
		var ang : float = angle_step * float(i) + rand_range(-0.3, 0.3)
		var offset = Vector2(cos(ang), sin(ang)) * spawn_radius
		var pos = origin + offset
		# Add material to RunData (the game handles the pickup entity display)
		if run_data.has_method("add_materials"):
			run_data.add_materials(1)
	# Visual: spawn gold sparkle VFX at caster position
	_spawn_vfx(VFX_BUFF, origin)
	print("[Synergies] MATERIAL DROP: spawned %d materials at %s" % [count, str(origin)])


# STANDING STILL RIDER (Streamer) — if the caster was standing still for `standing_still_window`
# seconds before casting, buff stats are multiplied by `standing_still_bonus` (1.5x at all tiers).
# Checks the caster's linear_velocity over the window period.
var _streamer_last_move_time = {}  # place -> last time the caster moved

func _apply_standing_still_rider(place: int, skill, tier: int, targets: Array, scaled: Dictionary, dur: float) -> void:
	var bonus_mult : float = float(skill.get("standing_still_bonus", 1.5))
	var window : float = float(skill.get("standing_still_window", 1.0))
	var caster = _player_node_for(place)
	if caster == null:
		return
	# Check if caster was standing still for the window period
	var now = OS.get_ticks_msec() / 1000.0
	var last_move = _streamer_last_move_time.get(place, 0.0)
	var still_time = now - last_move
	if still_time >= window:
		# Standing still — grant the EXTRA (bonus - base) as its own tracked buff so it's cleanly undone
		# on expiry/wave-end (applying via raw _apply_stat would leak the +50% — it was never recorded).
		var bonus_delta := {}
		for sk in scaled.keys():
			var base_val = int(scaled[sk])
			var diff = int(base_val * bonus_mult) - base_val
			if diff > 0:
				bonus_delta[sk] = diff
		if not bonus_delta.empty():
			_grant_buff(place, targets, bonus_delta, dur)
			for pi in targets:
				var p = _player_node_for(pi)
				if p != null:
					_refresh_health(p, pi)
		print("[Synergies] STREAMER STANDING STILL BONUS: %.1fx multiplier applied (still for %.1fs)" % [bonus_mult, still_time])
	else:
		print("[Synergies] STREAMER: no standing still bonus (moved %.1fs ago, need %.1fs)" % [now - last_move, window])


# Track player movement for Streamer standing still detection (called from _process)
var _streamer_places := []   # places whose char is Streamer — recomputed at each wave start

# Which places (if any) are playing Streamer. Computed ONCE per wave (in _process when the wave starts),
# so the per-frame _track_streamer_movement loop is skipped entirely when no Streamer is in the run.
func _refresh_streamer_places() -> void:
	_streamer_places = []
	for pi in _places():
		if _slug_for(pi) == "streamer":
			_streamer_places.append(pi)


func _track_streamer_movement() -> void:
	if _streamer_places.empty():
		return   # no Streamer in the run → nothing to track (avoids a per-frame tree walk for everyone)
	for pi in _streamer_places:
		var p = _player_node_for(pi)
		if p == null:
			continue
		var v = p.get("linear_velocity")
		if typeof(v) == TYPE_VECTOR2 and v.length() > 10.0:
			_streamer_last_move_time[pi] = OS.get_ticks_msec() / 1000.0


# Find the Danger-6 fog node (a CanvasItem whose name or script mentions "fog").
func _find_fog(node, depth: int):
	if depth > 6:
		return null
	for c in node.get_children():
		if "modulate" in c:
			if "fog" in String(c.name).to_lower():
				return c
			var scr = c.get_script()
			if scr != null and ("fog" in String(scr.resource_path).to_lower()):
				return c
	for c in node.get_children():
		var r = _find_fog(c, depth + 1)
		if r != null:
			return r
	return null


# AOE-on-cast RIDER — a damaging burst fired WHEN a non-AOE skill is cast, so a buff/dash also HITS
# (cyborg laser, captain cannon volley, bull impact-explosion). Reuses the same Hitbox pipeline as the
# AOE templates (so damage scales with the caster's Damage). `at`: "self" (caster) / "cursor" (nearest
# enemy) / "impact" (an explicit world pos passed in by DASH). `count`>1 scatters a volley around the
# center; `beam` draws a laser line from caster to the center first. No-op if the skill has no rider.
func _apply_aoe_rider(place: int, skill, tier: int, impact_pos) -> void:
	var aoc = skill.get("aoe_on_cast", null)
	if typeof(aoc) != TYPE_DICTIONARY:
		return
	var caster = _player_node_for(place)
	if caster == null:
		return
	var radius : float = float(aoc.get("radius", 140.0)) + float(aoc.get("radius_per_tier", 0.0)) * (tier - 1)
	var rbase = int(aoc.get("damage", 18)) + int(aoc.get("damage_per_tier", 0)) * (tier - 1)
	var dmg = _scaled_damage(rbase, tier, caster)   # same endless scaling as all AOE
	var origin = caster.global_position
	var center
	if typeof(impact_pos) == TYPE_VECTOR2:
		center = impact_pos
	elif String(aoc.get("at", "self")) == "cursor":
		var target = _nearest_enemy(origin)
		center = target.global_position if (target != null and is_instance_valid(target)) else origin
	else:
		center = origin
	var ring_col = _color_from(aoc.get("ring_color", null), Color(1.0, 0.42, 0.2))
	var burn = _burn_data(String(aoc.get("burn", "")))
	if bool(aoc.get("beam", false)):
		_spawn_beam(origin, center, ring_col)
	var count = int(aoc.get("count", 1))
	print("[Synergies] AOE-RIDER '%s' tier=%d dmg=%d r=%.0f count=%d at=%s" % [
		String(skill.get("name", "?")), tier, dmg, radius, count, str(center)])
	_spawn_hit_vfx(center, radius, String(aoc.get("hit_vfx", "")))
	_play_explosion_sfx()
	if count <= 1:
		_spawn_aoe_hitbox(center, dmg, radius, caster, ring_col, burn)
		return
	# volley: scatter `count` bursts evenly on a ring around the center (deterministic — no RNG)
	var spread : float = float(aoc.get("spread", 90.0))
	for i in range(count):
		var ang : float = TAU * float(i) / float(count)
		var off = Vector2(cos(ang), sin(ang)) * spread
		_spawn_aoe_hitbox(center + off, dmg, radius, caster, ring_col, burn)


# KNOCKBACK RIDER (diver's rescue surge) — at the dash LANDING point, SHOVE every enemy in `radius`
# outward by `amount` pixels, then leave a brief SLOW zone so a cornered ally can escape. The push is a
# per-frame position lerp (tracked in _pushed, advanced by _tick_pushed) — the engine's hitbox-knockback
# property does NOT apply to these enemies, and a one-shot velocity write gets wiped by their chase
# behavior next frame, so we drive global_position directly (the same lever CC + the player dash use).
func _apply_knockback_rider(place: int, skill, tier: int, impact_pos) -> void:
	var kb = skill.get("knockback", null)
	if typeof(kb) != TYPE_DICTIONARY:
		return
	var caster = _player_node_for(place)
	if caster == null:
		return
	var center = impact_pos if typeof(impact_pos) == TYPE_VECTOR2 else caster.global_position
	var radius : float = float(kb.get("radius", 140.0)) + float(kb.get("radius_per_tier", 0.0)) * (tier - 1)
	var amount : float = float(kb.get("amount", 200)) + float(kb.get("amount_per_tier", 0)) * (tier - 1)
	var push_dur : float = float(kb.get("push_duration", 0.18))
	var slow_pct : float = float(kb.get("slow_percent", 0.5))
	var slow_dur : float = float(kb.get("slow_duration", 1.0)) + float(kb.get("slow_duration_per_tier", 0.0)) * (tier - 1)
	var ring_col = _color_from(kb.get("ring_color", null), Color(0.2, 0.6, 1.0))
	# Build the slow zone's tracked-enemy dict up front so we can STICKY-SLOW each shoved enemy at cast
	# time — the push throws them OUT of the radius, so a tick-based "slow while inside" would miss them.
	var slowed := {}
	var n := 0
	for e in _enemies_near(center, radius):
		if e == null or not is_instance_valid(e) or not (e is Node2D):
			continue
		var away : Vector2 = e.global_position - center
		var dist : float = away.length()
		var dir := away.normalized() if dist > 1.0 else Vector2(cos(float(n)), sin(float(n)))
		# closer enemies get pushed a bit more (fuller shove from the epicenter)
		var push : float = amount * (1.0 - 0.4 * clamp(dist / radius, 0.0, 1.0))
		_pushed.append({"node": e, "from": e.global_position, "to": e.global_position + dir * push, "t": 0.0, "dur": push_dur})
		if slow_dur > 0.0:
			_apply_zone_slow(e, slowed, slow_pct, false, true)   # sticky → stays slowed even when pushed outside
		n += 1
	print("[Synergies] KNOCKBACK '%s' tier=%d amount=%.0f r=%.0f at=%s pushed=%d" % [
		String(skill.get("name", "?")), tier, amount, radius, str(center), n])
	# feedback ring
	var ring = AoeRing.new()
	var host = _host_node()
	if host != null:
		host.add_child(ring)
		if ring is Node2D:
			ring.global_position = center
		ring.setup(radius, ring_col, 0.5)
	# Persisting slow zone at the landing point: the shoved enemies (sticky) stay slowed for the duration,
	# AND any enemy that later walks into the radius is slowed too (handled by _tick_drained).
	if slow_dur > 0.0:
		_drain_zones.append({"pos": center, "radius": radius, "remaining": slow_dur, "slow_percent": slow_pct, "tick_interval": 0.2, "tick_timer": 0.0, "slowed": slowed})
	_play_explosion_sfx()


# Advance active knockback shoves: ease-out lerp each enemy's position outward over `dur`, zero its
# velocity each frame so its chase behavior can't fight the push, drop when done or the unit is gone.
func _tick_pushed(delta: float) -> void:
	if _pushed.empty():
		return
	var i := _pushed.size() - 1
	while i >= 0:
		var d = _pushed[i]
		var node = d["node"]
		if node == null or not is_instance_valid(node):
			_pushed.remove(i)
			i -= 1
			continue
		d["t"] = float(d["t"]) + delta
		var k : float = clamp(float(d["t"]) / float(d["dur"]), 0.0, 1.0)
		var e : float = 1.0 - (1.0 - k) * (1.0 - k)   # ease-out quad
		node.global_position = (d["from"] as Vector2).linear_interpolate(d["to"], e)
		if "linear_velocity" in node:
			node.set("linear_velocity", Vector2.ZERO)
		if k >= 1.0:
			_pushed.remove(i)
		i -= 1


# Load (and cache) a base-game BurningData resource by kind ("ember"/"fire"/"arcane"). Returns null if
# the kind is unknown or the .tres failed to load — _set_if then leaves the Hitbox's burning_data unset.
func _burn_data(kind: String):
	if kind == "":
		return null
	if _burn_cache.has(kind):
		return _burn_cache[kind]
	var res = null
	if BURN_RES.has(kind):
		res = load(BURN_RES[kind])
	_burn_cache[kind] = res
	return res


# Spawn a debuff particle (curse/burn) on each enemy within `radius` of `center` — pure visual read of
# the skill's effect. Capped at HIT_VFX_MAX so a wide AOE can't spawn dozens of particles at once.
func _spawn_hit_vfx(center: Vector2, radius: float, kind: String) -> void:
	if kind == "" or not HIT_VFX.has(kind):
		return
	var path : String = HIT_VFX[kind]
	var n = 0
	for e in _enemies_near(center, radius):
		if e is Node2D:
			_spawn_vfx(path, e.global_position)
			n += 1
			if n >= HIT_VFX_MAX:
				break


# Play a (varied) base-game explosion sound once per AOE cast — the satisfying "boom". Non-spatial so
# it's always audible; the player triggered it. Frees the one-shot player when the clip finishes.
func _play_explosion_sfx() -> void:
	if SFX_EXPLO.empty():
		return
	var stream = load(SFX_EXPLO[_sfx_idx % SFX_EXPLO.size()])
	_sfx_idx += 1
	if stream == null:
		return
	var sp = AudioStreamPlayer.new()
	sp.stream = stream
	sp.volume_db = -3.0
	var host = get_tree().current_scene
	if host == null:
		sp.free()
		return
	host.add_child(sp)
	sp.play()
	sp.connect("finished", sp, "queue_free")


# Chain lightning: draw a crackling arc from the caster to each of the nearest enemies around `center`
# (up to ARC_MAX). Pure visual — the AOE hitbox already deals the damage. No-op if no enemies.
func _spawn_lightning_chain(caster, center: Vector2, radius: float, color: Color) -> void:
	if caster == null:
		return
	var origin = caster.global_position
	# nearest enemies first; arc to up to ARC_MAX of them
	_arc_center = center
	var enemies = _enemies_near(center, radius)
	enemies.sort_custom(self, "_cmp_dist_to_center")
	var targets = []
	for e in enemies:
		if e is Node2D:
			targets.append((e as Node2D).global_position)
		if targets.size() >= ARC_MAX:
			break
	# No fallback — if no enemies in range, no lightning bolts
	if targets.empty():
		return
	print("[Synergies] arc: %d bolt(s) from %s (enemies_near=%d)" % [targets.size(), str(origin), enemies.size()])
	var host = _entities_node()
	if host == null:
		host = get_tree().current_scene
	if host == null:
		return
	for tp in targets:
		var lt = Lightning.new()
		host.add_child(lt)
		lt.setup(origin, tp, color, 0.40)


# sort helper for _spawn_lightning_chain (nearest enemy to the arc center first)
var _arc_center = Vector2.ZERO
func _cmp_dist_to_center(a, b) -> bool:
	return a.global_position.distance_to(_arc_center) < b.global_position.distance_to(_arc_center)


# Draw a short-lived laser beam from `from` to `to` (the AOE-on-cast `beam` flag, e.g. cyborg's laser).
func _spawn_beam(from: Vector2, to: Vector2, color: Color) -> void:
	var b = Beam.new()
	var host = _entities_node()
	if host == null:
		host = get_tree().current_scene
	if host == null:
		b.free()
		return
	host.add_child(b)
	b.setup(from, to, color, 7.0, 0.25)


# Parse a [r,g,b] / [r,g,b,a] config array into a Color (fallback if it's missing/malformed).
func _color_from(v, fallback: Color) -> Color:
	if typeof(v) == TYPE_ARRAY and (v.size() == 3 or v.size() == 4):
		var a : float = float(v[3]) if v.size() == 4 else 1.0
		return Color(float(v[0]), float(v[1]), float(v[2]), a)
	return fallback


# Apply a temp stat buff to targets and track it for timed/wave-end expiry (shared by DASH; no outline).
func _grant_buff(place: int, targets: Array, scaled: Dictionary, dur: float) -> void:
	for pi in targets:
		var needs_recalc = false
		for sk in scaled.keys():
			_apply_stat(pi, sk, int(scaled[sk]))
			if not _is_direct_stat(sk):
				needs_recalc = true
		if needs_recalc:
			_recalc_player(pi)
	_active_buffs.append({"caster": place, "targets": targets, "stats": scaled, "remaining": dur, "total": dur, "auras": {}})


# Put a WHITE silhouette outline on player `pi`'s sprite (same shader as the game's character-outline
# setting). Returns {sprite, prev} so we can restore the original material on expiry, or null.
func _apply_shield_outline(pi: int):
	var sprite = _player_sprite(_player_node_for(pi))
	if sprite == null:
		return null
	var sh = _outline_shader_res()
	if sh == null:
		return null
	var mat = ShaderMaterial.new()
	mat.shader = sh
	var tsize = Vector2(32, 32)
	var tex = sprite.get("texture")
	if tex != null:
		tsize = tex.get_size()
	mat.set_shader_param("texture_size", tsize)
	mat.set_shader_param("width", 4.0)
	mat.set_shader_param("alpha", 1.0)
	mat.set_shader_param("desaturation", 0.0)
	mat.set_shader_param("outline_color_0", Color(1, 1, 1, 1))
	mat.set_shader_param("outline_color_1", Color(0, 0, 0, 0))
	mat.set_shader_param("outline_color_2", Color(0, 0, 0, 0))
	mat.set_shader_param("outline_color_3", Color(0, 0, 0, 0))
	var prev = sprite.material
	sprite.material = mat
	print("[Synergies] shield outline ON pi=%d texsize=%s" % [pi, str(tsize)])
	return {"sprite": sprite, "prev": prev}


# Lazily load the game's outline shader (a base-game resource → load() works, unlike mod PNGs).
func _outline_shader_res():
	if _outline_shader == null:
		_outline_shader = load(OUTLINE_SHADER)
	return _outline_shader


# The unit sprite is at Animation/Sprite (from entity.tscn); fall back to a recursive Sprite search.
func _player_sprite(p):
	if p == null:
		return null
	var s = p.get_node_or_null("Animation/Sprite")
	if s != null:
		return s
	return _find_sprite_rec(p, 0)


func _find_sprite_rec(node, depth: int):
	if depth > 3:
		return null
	for c in node.get_children():
		if c is Sprite:
			return c
	for c in node.get_children():
		var r = _find_sprite_rec(c, depth + 1)
		if r != null:
			return r
	return null


# Restore the original sprite material for every shielded player on a buff record (expiry / wave end).
func _clear_buff_auras(b) -> void:
	if not b.has("auras"):
		return
	for pi in b["auras"].keys():
		var o = b["auras"][pi]
		if typeof(o) == TYPE_DICTIONARY and o.has("sprite"):
			var s = o["sprite"]
			if s != null and is_instance_valid(s):
				s.material = o["prev"]
	b["auras"] = {}


# HEAL — instant heal to all allies (incl. caster) via the Player node's heal() method.
# heal() updates health data but doesn't redraw the life bar, so we refresh it explicitly after.
func _cast_heal(place: int, skill, tier: int) -> void:
	var amount = int(round(float(int(skill.get("heal", 15)) + int(skill.get("heal_per_tier", 0)) * (tier - 1)) * _wave_heal_mult()))
	var targets = _places()
	# If the skill has a `radius`, it's an AURA heal: only allies inside the radius of the caster are
	# healed, and we show the soft green aura ring (the Doc Moth aura sprite) to mark the area.
	var radius : float = float(skill.get("radius", 0.0)) + float(skill.get("radius_per_tier", 0.0)) * (tier - 1)
	if radius > 0.0:
		var caster = _player_node_for(place)
		if caster != null:
			_spawn_heal_aura(caster.global_position, radius)
			var inrange = []
			for pi in targets:
				var ap = _player_node_for(pi)
				if ap != null and ap.global_position.distance_to(caster.global_position) <= radius:
					inrange.append(pi)
			targets = inrange
	var done = []
	for pi in targets:
		if _heal_player(pi, amount):
			done.append(pi)
	print("[Synergies] HEAL '%s' tier=%d amount=%d r=%.0f targets=%s healed=%s" % [
		String(skill.get("name", "?")), tier, amount, radius, str(targets), str(done)])
	_apply_skill_riders(place, skill, tier)   # optional flavor buff (e.g. chef regen, glutton +Max HP)
	# ROMANTIC CHARM RIDER: charm nearby enemies below HP threshold
	if skill.has("charm"):
		_apply_charm_rider(place, skill, tier)


# Spawn the soft green heal-radius aura (reused Doc Moth aura sprite) at a world position. `life` is how
# long it shows — a brief 0.7s flash for instant heals, or the full zone duration for the Doctor's field.
# Returns the aura node (or null) so a zone can free it early when cleared at wave end.
func _spawn_heal_aura(pos: Vector2, radius: float, life: float = 0.7):
	var aura = HealAura.new()
	var host = _entities_node()
	if host == null:
		host = get_tree().current_scene
	if host == null:
		aura.free()
		return null
	host.add_child(aura)
	if aura is Node2D:
		aura.global_position = pos
	aura.setup(radius, Color(0.40, 1.0, 0.55, 0.40), life)
	return aura


# Heal one player by `amount`, clamped to max HP, and refresh the life bar. heal() doesn't cap, so we do.
func _heal_player(pi: int, amount: int) -> bool:
	var p = _player_node_for(pi)
	if p == null or not p.has_method("heal"):
		return false
	var cs = p.get("current_stats")
	var ms = p.get("max_stats")
	var actual = amount
	if cs != null and ms != null:
		var room : float = max(0.0, float(ms.get("health")) - float(cs.get("health")))
		actual = int(min(float(amount), room))
	if actual > 0:
		p.call("heal", actual)
	if cs != null and ms != null and float(cs.get("health")) > float(ms.get("health")):
		cs.set("health", ms.get("health"))
	_refresh_health(p, pi)
	if actual > 0 and (p is Node2D):
		_spawn_vfx(VFX_HEAL, p.global_position)
		# Vivid sprite burst riding on the healed player (follows them through the play-out).
		_spawn_sprite_vfx("Heal", Vector2.ZERO, {"parent": p, "fps": 22.0, "scale": 1.0})
	return true


# AOE_CURSOR: same damaging hitbox as AOE_SELF, but spawned at the nearest enemy cluster (auto-aim).
# Real AOE damage = config base + per-tier, PLUS the caster's Damage stat so it stays relevant in
# Endless (per spec). current_stats.damage is the player's computed flat Damage (probe-confirmed field).
func _aoe_damage(skill, tier: int, caster) -> int:
	var base = int(skill.get("damage", 20)) + int(skill.get("damage_per_tier", 0)) * (tier - 1)
	return _scaled_damage(base, tier, caster)


# Endless-scaled skill damage (keeps skills useful in late waves): base × wave-floor + caster Damage ×
# a tier-growing share. See Config.SKILL_* constants. Used by every AOE / rider / summon damage value.
func _scaled_damage(base: int, tier: int, caster) -> int:
	var dmg : float = float(base) * _wave_dmg_mult()
	if caster != null:
		var cs = caster.get("current_stats")
		if cs != null:
			var ck : float = Config.SKILL_CASTER_DMG_BASE + Config.SKILL_CASTER_DMG_PER_TIER * float(tier - 1)
			dmg += float(int(cs.get("damage"))) * ck
	return int(round(dmg))


func _wave_dmg_mult() -> float:
	return 1.0 + Config.SKILL_WAVE_DMG_GROWTH * float(_wave_number() - 1)


func _wave_heal_mult() -> float:
	return 1.0 + Config.SKILL_WAVE_HEAL_GROWTH * float(_wave_number() - 1)


# Current wave number (RunData.current_wave); falls back to 1 (menu / not found).
func _wave_number() -> int:
	var rd = _run_data()
	if rd != null and ("current_wave" in rd):
		return int(rd.current_wave)
	return 1


func _cast_aoe_cursor(place: int, skill, tier: int) -> void:
	var radius : float = float(skill.get("radius", 150.0)) + float(skill.get("radius_per_tier", 0.0)) * (tier - 1)
	var caster = _player_node_for(place)
	if caster == null:
		return
	var dmg = _aoe_damage(skill, tier, caster)
	var origin = caster.global_position
	var target = _nearest_enemy(origin)
	var pos = target.global_position if (target != null and is_instance_valid(target)) else origin
	print("[Synergies] AOE_CURSOR '%s' tier=%d dmg=%d r=%.0f at=%s" % [
		String(skill.get("name", "?")), tier, dmg, radius, str(pos)])
	var skip_ring = skill.has("vfx")
	_spawn_aoe_hitbox(pos, dmg, radius, caster, Color(1.0, 0.42, 0.2), _burn_data(String(skill.get("burn", ""))), skip_ring)
	_spawn_hit_vfx(pos, radius, String(skill.get("hit_vfx", "")))
	if not skip_ring:
		_play_explosion_sfx()
	if bool(skill.get("arc", false)):
		_spawn_lightning_chain(caster, pos, radius, _color_from(skill.get("arc_color", null), Color(0.5, 0.8, 1.0)))
		_spawn_sprite_vfx("Shock", pos, {"fps": 24.0, "scale": max(1.0, radius / 90.0)})
	_apply_skill_riders(place, skill, tier)


# Nearest living enemy to `origin` (null if none).
func _nearest_enemy(origin: Vector2):
	var ent = _entities_node()
	var all = []
	if ent != null:
		_collect_enemies(ent, origin, 1.0e9, all, 0)   # huge radius → all enemies
	var best = null
	var best_d = 1.0e12
	for e in all:
		var d : float = e.global_position.distance_to(origin)
		if d < best_d:
			best_d = d
			best = e
	return best


# Force the life bar to redraw after a heal: recompute stats (proven-safe) + re-emit the unit's
# health_updated(current, max) signal — guarded to its real arity so a mismatch can't crash the mod.
func _refresh_health(node, pi: int) -> void:
	# Live HP lives in the node's `current_stats` Stats object (heal() bumps current_stats.health);
	# RunData's copy is a stale serialization. Emit health_updated with the node's own values.
	var cs = node.get("current_stats")
	var ms = node.get("max_stats")
	var cur = cs.get("health") if cs != null else null
	var mx = ms.get("health") if ms != null else null
	if cur == null:
		return
	if mx == null:
		mx = cur
	# unit.gd: signal health_updated(unit, current_health, max_health) — emit it so the life bar redraws.
	for s in node.get_signal_list():
		if String(s.name) == "health_updated" and ("args" in s) and (s["args"] as Array).size() == 3:
			node.emit_signal("health_updated", node, cur, mx)
			print("[Synergies][heal] refreshed life bar pi=%d cur=%s max=%s" % [pi, str(cur), str(mx)])
			break


# AOE_SELF — damage burst around the caster. v0.6.0: spawns the game's explosion as a VISUAL and
# dumps the explosion/Hitbox config schema (damage is applied via Area2D overlap, not a direct call —
# wiring the Hitbox damage comes next once the recon dump lands in godot.log).
func _cast_aoe_self(place: int, skill, tier: int) -> void:
	var radius : float = float(skill.get("radius", 150.0)) + float(skill.get("radius_per_tier", 0.0)) * (tier - 1)
	var caster = _player_node_for(place)
	if caster == null:
		print("[Synergies] AOE: caster node not found (place=%d)" % place)
		return
	var dmg = _aoe_damage(skill, tier, caster)
	var origin = caster.global_position
	var enemies = _enemies_near(origin, radius)
	print("[Synergies] AOE '%s' tier=%d dmg=%d r=%.0f enemies_near=%d" % [
		String(skill.get("name", "?")), tier, dmg, radius, enemies.size()])
	var skip_ring = skill.has("vfx") or bool(skill.get("skip_ring", false))
	var aoe_col = _color_from(skill.get("aoe_color", null), Color(1.0, 0.42, 0.2))
	_spawn_aoe_hitbox(origin, dmg, radius, caster, aoe_col, _burn_data(String(skill.get("burn", ""))), skip_ring)
	_spawn_hit_vfx(origin, radius, String(skill.get("hit_vfx", "")))
	if not skip_ring:
		_play_explosion_sfx()
	if bool(skill.get("arc", false)):
		_spawn_lightning_chain(caster, origin, radius, _color_from(skill.get("arc_color", null), Color(0.5, 0.8, 1.0)))
		_spawn_sprite_vfx("Shock", origin, {"fps": 24.0, "scale": max(1.0, radius / 90.0)})
	_apply_skill_riders(place, skill, tier)
	# STAT DRAIN: reduce enemy speed in range by 50% for the buff duration
	if bool(skill.get("stat_drain", false)):
		var dur : float = float(skill.get("duration", 4.0)) + float(skill.get("dur_per_tier", 0.0)) * (tier - 1)
		for e in enemies:
			if e == null or not is_instance_valid(e):
				continue
			var cs = e.get("current_stats")
			if cs != null and "speed" in cs:
				var orig_speed = cs.get("speed")
				cs.set("speed", int(orig_speed * 0.5))
				_frozen.append({"node": e, "cs": cs, "speed": orig_speed, "modulate": null, "remaining": dur})


# Apply damage to one enemy via the unit's take_damage (a GDScript method → a bad call logs an error,
# it does NOT hard-crash like the pooled explosion did).
# Spawn a configured Hitbox (Area2D) at the cast point. The enemy HURTBOX detects it (layer 8) and
# calls the unit's take_damage internally with the full damage context — the game's real pipeline, so
# no Nil-signal problem and proper floating numbers. Lives ~0.15s (enough physics frames), then frees.
func _spawn_aoe_hitbox(origin: Vector2, dmg: int, radius: float, caster, ring_color = Color(1.0, 0.42, 0.2), burn = null, skip_ring = false) -> void:
	var scn = load(HITBOX_SCENE)
	if scn == null:
		print("[Synergies] AOE: hitbox scene failed to load")
		return
	var hb = scn.instance()
	# configure BEFORE add_child (the script's _ready may read these)
	_set_if(hb, "deals_damage", true)
	_set_if(hb, "damage", dmg)
	_set_if(hb, "crit_chance", 0.0)
	_set_if(hb, "crit_damage", 1.0)
	_set_if(hb, "effect_scale", 1.0)
	_set_if(hb, "accuracy", 1.0)
	_set_if(hb, "is_healing", false)
	_set_if(hb, "knockback_amount", 0)
	_set_if(hb, "knockback_piercing", 0.0)
	_set_if(hb, "speed_percent_modifier", 0)
	_set_if(hb, "scaling_stats", [])
	_set_if(hb, "projectiles_on_hit", [])
	_set_if(hb, "ignored_objects", [])
	_set_if(hb, "effects", [])
	_set_if(hb, "burning_data", burn)   # a base-game BurningData → struck enemies catch fire (or null)
	if burn != null and not _burn_probed:
		_burn_probed = true
		print("[Synergies] burn: 'burning_data' is a Hitbox property = %s" % str("burning_data" in hb))
	_set_if(hb, "from", caster)
	_set_if(hb, "player_attack_id", 0)
	hb.collision_layer = 8        # player-hitbox layer → enemy hurtboxes detect it
	hb.collision_mask = 0
	hb.monitorable = true
	# resize the collision circle to the AOE radius
	var col = hb.get_node_or_null("Collision")
	if col != null:
		var shape = CircleShape2D.new()
		shape.radius = radius
		col.shape = shape
	var parent = _entities_node()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		hb.free()
		return
	parent.add_child(hb)
	if hb is Node2D:
		hb.global_position = origin
	if hb.has_method("enable"):
		hb.call("enable")
	# Vivid flame burst at the fire-AOE landing point when this hit sets enemies alight.
	if burn != null:
		_spawn_sprite_vfx("Burn", origin, {"fps": 24.0, "scale": max(1.0, radius / 90.0)})
	var t = get_tree().create_timer(0.15)
	t.connect("timeout", hb, "queue_free")
	# range ring (world-space) — flashes the AOE radius for 0.5s, then fades + frees itself
	if not skip_ring:
		var ring = AoeRing.new()
		parent.add_child(ring)
		if ring is Node2D:
			ring.global_position = origin
		ring.setup(radius, ring_color, 0.5)
		_spawn_vfx(VFX_BLAST, origin)


func _targets_for(template: String, caster_place: int) -> Array:
	if template == Config.TMPL_BUFF_PARTY:
		return _places()              # all co-op places (includes the caster)
	return [caster_place]             # BUFF_SELF (default)


# Living enemies (player_index == -1) within `radius` of `origin`, under the Entities node.
func _enemies_near(origin: Vector2, radius: float) -> Array:
	var ent = _entities_node()
	var out = []
	if ent != null:
		_collect_enemies(ent, origin, radius, out, 0)
	return out


func _collect_enemies(node, origin: Vector2, radius: float, out: Array, depth: int) -> void:
	if depth > 3:
		return
	for c in node.get_children():
		if ("player_index" in c) and int(c.player_index) == -1 and (c is Node2D):
			if c.global_position.distance_to(origin) <= radius:
				out.append(c)
		_collect_enemies(c, origin, radius, out, depth + 1)


# Set a property only if the node actually has it (guards against renamed/absent fields).
func _set_if(node, prop: String, val) -> void:
	if prop in node:
		node.set(prop, val)


func _tick_buffs(delta: float) -> void:
	if _active_buffs.empty():
		return
	var i = _active_buffs.size() - 1
	while i >= 0:
		var b = _active_buffs[i]
		b.remaining -= delta
		if b.remaining <= 0.0:
			for pi in b.targets:
				var needs_recalc = false
				for sk in b.stats.keys():
					_apply_stat(pi, sk, -int(b.stats[sk]))   # undo exactly what this buff added
					if not _is_direct_stat(sk):
						needs_recalc = true
				if needs_recalc:
					_recalc_player(pi)
			_clear_buff_auras(b)
			print("[Synergies] EFFECT expired targets=%s stats=%s" % [str(b.targets), str(b.stats)])
			_active_buffs.remove(i)
		i -= 1


# Undo every active buff immediately (used at wave end). Same math as a timed expiry.
func _expire_all_buffs(reason: String) -> void:
	if _active_buffs.empty():
		return
	for b in _active_buffs:
		for pi in b.targets:
			var needs_recalc = false
			for sk in b.stats.keys():
				_apply_stat(pi, sk, -int(b.stats[sk]))
				if not _is_direct_stat(sk):
					needs_recalc = true
			if needs_recalc:
				_recalc_player(pi)
		_clear_buff_auras(b)
	print("[Synergies] %s — cleared %d active buff(s)" % [reason, _active_buffs.size()])
	_active_buffs.clear()


# ---------------------------------------------------------------------------
# AFFINITIES — faction team traits (>=2 same-faction members → team buff + nerf)
# ---------------------------------------------------------------------------
# Applied team-wide at each wave start as a long buff (caster=-1) and cleared at wave end by
# _expire_all_buffs, so it survives in-wave but never stacks across waves (the game recomputes stats
# between waves, so we re-apply fresh each wave). TEST_MODE lowers the activation threshold to 1 so a
# solo player can verify a faction trait.

func _apply_affinities() -> void:
	var active = _active_affinities()
	if active.empty():
		return
	var places = _places()
	for aff in active:
		_grant_buff(-1, places, aff["stats"], 1.0e9)   # caster=-1 → excluded from per-player HUD timers
	print("[Synergies] AFFINITIES active=%d: %s" % [active.size(), _affinity_summary(active)])
	if _hud != null and _hud.has_method("update_affinities"):
		_hud.update_affinities(active)


# Which factions are active this run + the combined stat bundle (buff + nerf + named-pair bonuses) for
# the tier matching the member count. [{key, label, label_vi, count, stats}]
func _active_affinities() -> Array:
	var slugs = []
	for place in _places():
		slugs.append(_slug_for(place))
	var threshold = 1 if Config.TEST_MODE else 2
	var out = []
	for key in Config.AFFINITIES.keys():
		var aff = Config.AFFINITIES[key]
		var members : Array = aff.get("members", [])
		var count = 0
		for s in slugs:
			if s in members:
				count += 1
		if count < threshold:
			continue
		var tiers : Array = aff.get("tiers", [])
		if tiers.empty():
			continue
		var chosen = tiers[0]
		for t in tiers:
			if count >= int(t.get("at", 99)):
				chosen = t
		var stats = {}
		_merge_stats(stats, chosen.get("buff", {}))
		_merge_stats(stats, chosen.get("nerf", {}))
		for pr in aff.get("pairs", []):
			if (String(pr.get("a", "")) in slugs) and (String(pr.get("b", "")) in slugs):
				_merge_stats(stats, pr.get("buff", {}))
		out.append({
			"key": key,
			"label": String(aff.get("label", "?")),
			"label_vi": String(aff.get("label_vi", aff.get("label", "?"))),
			"count": count,
			"stats": stats,
		})
	return out


# Accumulate src{stat:amount} into dst (amounts may be negative for nerfs).
func _merge_stats(dst: Dictionary, src) -> void:
	if typeof(src) != TYPE_DICTIONARY:
		return
	for k in src.keys():
		dst[k] = int(dst.get(k, 0)) + int(src[k])


func _affinity_summary(active: Array) -> String:
	var parts = []
	for aff in active:
		parts.append("%s x%d %s" % [String(aff["label"]), int(aff["count"]), str(aff["stats"])])
	return PoolStringArray(parts).join(" | ")


# Add `amount` (may be negative) to one player's stat.
# ALL stats are written to the effects dict (which update_player_stats() reads from).
# Direct stats (armor/speed/damage/dodge) are ALSO written to current_stats for immediate effect.
func _apply_stat(pi: int, stat_key: String, amount: int) -> bool:
	if stat_key == "stat_max_hp":
		return _apply_max_hp(pi, amount)
	# Always write to effects dict so update_player_stats() picks it up
	var rd = _run_data()
	if rd == null:
		return false
	var effects = rd.get_player_effects(pi)
	if typeof(effects) != TYPE_DICTIONARY:
		return false
	var key = _stat_hash(stat_key)
	var before = effects[key] if effects.has(key) else 0
	effects[key] = before + amount
	_invalidate_stat_cache(pi)   # else the game keeps returning the STALE cached stat (the affinity bug)
	# For direct stats, also mutate current_stats immediately
	if STATS_FIELDS.has(stat_key):
		_apply_stats_field(pi, String(STATS_FIELDS[stat_key]), amount)
	print("[Synergies][stat] pi=%d %s effects %s -> %s (%+d)" % [pi, stat_key, str(before), str(effects[key]), amount])
	return true


# Direct mutation of a current_stats/max_stats field (armor/speed/damage/dodge). Visible in the panel.
func _apply_stats_field(pi: int, field: String, amount: int) -> bool:
	var p = _player_node_for(pi)
	if p == null:
		return false
	var cs = p.get("current_stats")
	var ms = p.get("max_stats")
	var before = cs.get(field) if cs != null else null
	if cs != null:
		cs.set(field, int(cs.get(field)) + amount)
	if ms != null:
		ms.set(field, int(ms.get(field)) + amount)
	var after = cs.get(field) if cs != null else null
	print("[Synergies][stat] pi=%d %s(field) %s -> %s (%+d)" % [pi, field, str(before), str(after), amount])
	return true


# Max HP is special. The CAP (max_stats.health) must go through the EFFECTS DICT, not a direct write:
# update_player_stats() rebuilds max_stats from the effects dict (e.g. when another stat in the same
# bundle triggers a recalc), so a directly-set ms.health gets WIPED back to base — leaving current HP
# stranded above the cap (the "24/12" bug) and going NEGATIVE on the symmetric undo. So: write the cap
# delta to the effects dict + recalc (rebuilds the cap correctly), then adjust CURRENT health —
# asymmetrically: fill the gained HP on a buff (+), but on expiry (−) only CLAMP under the new cap
# (never subtract, or a damaged player ends the wave at negative/0 HP).
func _apply_max_hp(pi: int, amount: int) -> bool:
	var rd = _run_data()
	if rd != null:
		var effects = rd.get_player_effects(pi)
		if typeof(effects) == TYPE_DICTIONARY:
			var key = _stat_hash("stat_max_hp")
			effects[key] = int(effects.get(key, 0)) + amount
	_invalidate_stat_cache(pi)   # so get_player_max_health() reads our delta, not the stale cap cache
	_recalc_player(pi)   # rebuild max_stats.health from the effects dict (cap now base + our delta)
	var p = _player_node_for(pi)
	if p == null:
		return false
	var cs = p.get("current_stats")
	var ms = p.get("max_stats")
	if cs != null and ms != null:
		var maxh := int(ms.get("health"))
		var curh := int(cs.get("health"))
		if amount > 0:
			cs.set("health", int(min(curh + amount, maxh)))   # fill the gained HP, capped
		elif curh > maxh:
			cs.set("health", maxh)                            # cap lowered → clamp current under it
	_refresh_health(p, pi)
	var mh = ms.get("health") if ms != null else null
	var ch = cs.get("health") if cs != null else null
	print("[Synergies][stat] pi=%d stat_max_hp -> ms.health=%s cs.health=%s (%+d via effects)" % [pi, str(mh), str(ch), amount])
	return true


# True for stats that mutate the Stats object directly (must NOT be followed by update_player_stats()).
func _is_direct_stat(stat_key: String) -> bool:
	return stat_key == "stat_max_hp" or STATS_FIELDS.has(stat_key)


# Map a stat key string to the hash the game uses for its effects dict (falls back to the string).
func _stat_hash(stat_key: String):
	var keys = _keys_singleton()
	if keys != null and keys.has_method("generate_hash"):
		return keys.generate_hash(stat_key)
	return stat_key


# The Player caches its usable stats in `current_stats` (read by the stat panel via get_stats_value);
# mutating the effects dict alone won't refresh them. `update_player_stats()` (confirmed via the
# v0.5.6 live dump) recomputes current_stats from the effects dict — call it after every apply/undo.
func _recalc_player(pi: int) -> void:
	var p = _player_node_for(pi)
	if p == null:
		print("[Synergies][recalc] pi=%d player node not found" % pi)
		return
	for m in ["update_player_stats", "update_stats"]:
		if p.has_method(m):
			p.call(m)
			print("[Synergies][recalc] pi=%d via player.%s()" % [pi, m])
			return


func _slug_for(place: int) -> String:
	return _char_id_for(place).replace("character_", "")


func _run_data():
	return get_tree().root.get_node_or_null("RunData")


func _keys_singleton():
	return get_tree().root.get_node_or_null("Keys")


func _utils_singleton():
	return get_tree().root.get_node_or_null("Utils")


# The game caches per-player stat reads in Utils._stat_caches (utils.gd get_stat). A raw effects-dict
# write NEVER invalidates it, so non-direct stats (crit/attack_speed/elemental_damage/luck/engineering/
# lifesteal/hp_regeneration/harvesting/range/xp_gain…) keep returning the stale cached value — only the
# 4 stats we ALSO write straight into current_stats appeared to apply. The game's own TempStats calls
# Utils.reset_stat_cache() after EVERY stat change; mirror that here so our buffs actually take effect.
func _invalidate_stat_cache(pi: int) -> void:
	var u = _utils_singleton()
	if u != null and u.has_method("reset_stat_cache"):
		u.reset_stat_cache(pi)


# Find the live player unit for a co-op place (== player_index) under the Entities node.
func _player_node_for(pi: int):
	var ent = _entities_node()
	if ent == null:
		return null
	return _find_player(ent, pi, 0)


func _find_player(node, pi: int, depth: int):
	if depth > 3:
		return null
	for c in node.get_children():
		# weapons share the player's player_index — require the stat-recompute method to pick the unit.
		if ("player_index" in c) and int(c.player_index) == pi and c.has_method("update_player_stats"):
			return c
	for c in node.get_children():
		var r = _find_player(c, pi, depth + 1)
		if r != null:
			return r
	return null


# ---------------------------------------------------------------------------
# unlock / tier / level
# ---------------------------------------------------------------------------

func _unlock_level() -> int:
	return Config.UNLOCK_LEVEL_TEST if Config.TEST_MODE else Config.UNLOCK_LEVEL


func _tier_for(level: int, unlock: int) -> int:
	if level < unlock:
		return 0
	return int(clamp(1 + (level - unlock) / Config.UPGRADE_EVERY, 1, Config.MAX_TIER))


# Player `place`'s current level off RunData (best-effort; default 1 so TEST_MODE stays usable).
func _level_for(place: int) -> int:
	var rd = get_tree().root.get_node_or_null("RunData")
	if rd != null and ("players_data" in rd) and typeof(rd.players_data) == TYPE_ARRAY and rd.players_data.size() > place:
		var pd = rd.players_data[place]
		if pd != null:
			for field in ["level", "current_level", "lvl"]:
				if field in pd:
					return int(pd.get(field))
	return 1


# ---------------------------------------------------------------------------
# device → co-op place
#
# Ground truth from the game's own singletons/coop_service.gd:
#   enum PlayerType { KEYBOARD_AND_MOUSE, GAMEPAD_XBOX, GAMEPAD_PLAYSTATION, GAMEPAD_SWITCH }
#   func _add_player(device, player_type): connected_players.push_back([device, player_type])
#   func get_remapped_player_device(player_index): return connected_players[player_index][0]
#   func get_player_input_type(player_index):     return connected_players[player_index][1]
# and main.gd drives it as `for player_index in RunData.get_player_count(): get_remapped_player_device(player_index)`.
#
# So an entry is [device, PlayerType] and THE CO-OP PLACE IS THE ENTRY'S INDEX — pair[1] is the
# controller BRAND, not the slot. (Reading pair[1] as the place is why a PlayStation pad resolved to
# place 2 and two same-brand pads both resolved to place 1, leaving one player with no skill.)
#
# Devices are remapped on join: the keyboard becomes KEYBOARD_DEVICE_ID, a pad sitting on raw device 0
# becomes GAMEPAD_DEVICE_ID; every other pad keeps its raw id.
# ---------------------------------------------------------------------------

const KEYBOARD_DEVICE_ID := 7   # CoopService.KEYBOARD_REMAPPED_DEVICE_ID
const GAMEPAD_DEVICE_ID := 6    # CoopService.GAMEPAD_REMAPPED_DEVICE_ID
const PLAYER_TYPE_KEYBOARD := 0 # CoopService.PlayerType.KEYBOARD_AND_MOUSE


func _resolve_place(device: int, is_key: bool) -> int:
	var players = _coop_table()
	if players.empty():
		return 0
	if is_key:
		# The keyboard player is the entry whose PlayerType is KEYBOARD_AND_MOUSE (same test the game
		# uses in is_player_using_gamepad); fall back to its remapped device id.
		for i in players.size():
			var pair = players[i]
			if typeof(pair) != TYPE_ARRAY or pair.size() < 2:
				continue
			if int(pair[1]) == PLAYER_TYPE_KEYBOARD or int(pair[0]) == KEYBOARD_DEVICE_ID:
				return i
		return 0
	# Input.get_connected_joypads() hands us RAW device ids; the co-op table stores the remapped one.
	var want := GAMEPAD_DEVICE_ID if device == 0 else device
	for i in players.size():
		var pair = players[i]
		if typeof(pair) == TYPE_ARRAY and pair.size() >= 1 and int(pair[0]) == want:
			return i
	return 0


# ---------------------------------------------------------------------------
# run state + helpers
# ---------------------------------------------------------------------------

func _coop_table() -> Array:
	var cs = get_tree().root.get_node_or_null("CoopService")
	if cs == null or not ("connected_players" in cs):
		return []
	var players = cs.connected_players
	if typeof(players) != TYPE_ARRAY:
		return []
	return players


# Co-op places, ascending; always at least [0]. A place is just a player slot index — RunData's
# players_data index and CoopService.connected_players' entry index are the same number.
func _places() -> Array:
	var n := 0
	var rd = _run_data()
	if rd != null and rd.has_method("get_player_count"):
		n = int(rd.get_player_count())
	if n <= 0:
		n = _coop_table().size()
	if n <= 0:
		n = 1
	var arr := []
	for i in n:
		arr.append(i)
	return arr


func _is_run_active() -> bool:
	return _char_id_for(0) != ""


# Co-op = more than one player in the run (RunData.get_player_count, fallback to the co-op place table).
func _is_coop() -> bool:
	var rd = _run_data()
	if rd != null and rd.has_method("get_player_count"):
		return int(rd.get_player_count()) > 1
	return _places().size() > 1


# Skills gating is driven by the in-game settings (Options → Accessibility): in co-op by the
# `synergies_coop` toggle (default ON), in solo by the `skills_solo` toggle (default OFF). The two are
# independent — synergies OFF + solo-skills ON = skills in solo, nothing in co-op. (Falls back to the
# old co-op-only behavior if settings somehow aren't ready yet.)
func _skills_enabled() -> bool:
	if _settings == null:
		return _is_coop()
	if _is_coop():
		return bool(_settings.synergies_coop())
	# Solo skills are a TEST-only convenience: published builds NEVER grant them, even if an old
	# `skills_solo=true` is still saved from a test build (the toggle is hidden in release).
	return Config.TEST_MODE and bool(_settings.skills_solo())


# Public cross-mod API. The EndlessLeaderboard mod calls this at run-finish (via has_method) to learn
# whether the Synergies system was ACTIVE this run and which skill each co-op player's character runs,
# so it can split synergies co-op runs onto their own leaderboard board and show per-player skills.
# Pure read — never mutates run state. Reads defensively so a partial/torn-down run can't error the
# caller. Shape:
#   {
#     active: bool,                  # co-op with the synergies toggle ON (skills actually in play)
#     is_coop: bool,
#     players: { <place:int>: { character_slug, skill_slug, skill_name } },   # skills are 1:1 w/ chars
#   }
func get_synergies_state() -> Dictionary:
	var active := _skills_enabled()
	var coop := _is_coop()
	var players := {}
	if active:
		for place in _places():
			var slug := _slug_for(place)
			if slug == "" or not Config.SKILLS.has(slug):
				continue
			var skill = Config.SKILLS[slug]
			players[place] = {
				"character_slug": slug,
				"skill_slug": slug,
				"skill_name": String(skill.get("name", "")),
			}
	return {"active": active, "is_coop": coop, "players": players}


func _char_id_for(place: int) -> String:
	var rd = get_tree().root.get_node_or_null("RunData")
	if rd == null:
		return ""
	if ("players_data" in rd) and typeof(rd.players_data) == TYPE_ARRAY and rd.players_data.size() > place:
		var pd = rd.players_data[place]
		if pd != null:
			for field in ["current_character", "character", "character_data", "character_id"]:
				if field in pd:
					var id = _char_id_of(pd.get(field))
					if id != "":
						return id
	if place == 0 and "current_character" in rd:
		return _char_id_of(rd.current_character)
	return ""


func _char_id_of(v) -> String:
	if v == null:
		return ""
	if typeof(v) == TYPE_ARRAY:
		if v.size() == 0:
			return ""
		v = v[0]
	if typeof(v) == TYPE_STRING:
		return v
	if v != null and ("my_id" in v):
		return String(v.my_id)
	return ""


# The arena "Entities" node — looked up MANY times per frame (every _player_node_for / _enemies_near /
# _nearest_enemy / _enemy_count call). find_node(recursive) walks the whole scene tree, so cache it and
# only re-find when the cached node was freed (scene/run change) — is_instance_valid catches that.
var _entities_cache = null

func _entities_node():
	if _entities_cache != null and is_instance_valid(_entities_cache):
		return _entities_cache
	var main = get_tree().current_scene
	if main == null:
		_entities_cache = null
		return null
	_entities_cache = main.find_node("Entities", true, false)
	return _entities_cache


# "In an active wave" = the WaveTimer is running (>0). It's 0/stopped on the shop screen, so the HUD
# hides there. (Same signal the DmgMeter mod uses.) Falls back to arena-units if the timer isn't found.
func _in_wave() -> bool:
	var main = get_tree().current_scene
	if main == null:
		return false
	var wt = main.find_node("WaveTimer", true, false)
	# WaveTimer is stopped in the shop (time_left may still read >0 as the next wave's preset).
	var timer_running : bool = wt != null and (not wt.is_stopped()) and float(wt.time_left) > 0.0
	return timer_running or _enemy_count() > 0     # second signal: enemies on the arena = a live wave


# Count enemies (player_index == -1) directly under Entities. -1 if Entities is absent.
func _enemy_count() -> int:
	var ent = _entities_node()
	if ent == null:
		return -1
	var n = 0
	for c in ent.get_children():
		if ("player_index" in c) and int(c.player_index) == -1:
			n += 1
	return n


func _scene_name() -> String:
	var s = get_tree().current_scene
	return s.name if s != null else "?"




# --- Procedural VFX rider (reads `vfx` field from skill config) ---

func _apply_vfx_rider(place: int, skill, tier: int) -> void:
	var vfx_name = String(skill.get("vfx", ""))
	if vfx_name == "":
		return
	var caster = _player_node_for(place)
	if caster == null:
		return
	var origin = caster.global_position
	# Determine spawn position: "self" (default) or "impact" (for dash skills)
	var vfx_at = String(skill.get("vfx_at", "self"))
	var pos = origin
	if vfx_at == "impact":
		# For dash skills, use the last known dash landing point or nearest enemy
		var e = _nearest_enemy(origin)
		pos = e.global_position if (e != null and is_instance_valid(e)) else origin
	# Parse optional color override
	var color = Color.white
	var has_color = false
	var col_arr = skill.get("vfx_color", null)
	if typeof(col_arr) == TYPE_ARRAY and col_arr.size() >= 3:
		color = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))
		has_color = true
	# Parse radius override
	var radius = 200.0
	if skill.has("radius"):
		radius = float(skill.get("radius", 200.0)) + float(skill.get("radius_per_tier", 0.0)) * (tier - 1)
	elif skill.has("aoe_on_cast"):
		var aoc = skill["aoe_on_cast"]
		radius = float(aoc.get("radius", 140.0)) + float(aoc.get("radius_per_tier", 0.0)) * (tier - 1)
	# Dispatch to the right VFX spawner
	# Isometric VFX use ry=rx*0.5 squish, so visual appears half-size — compensate with ×1.5
	var iso_radius = radius * 1.5
	match vfx_name:
		"arcane_ring":
			spawn_arcane_ring(pos, color, iso_radius)
		"hit_burst":
			spawn_hit_burst(pos, color, Color(1.0, 0.5, 0.1))
		"explosion_burst":
			spawn_explosion(pos, color, radius * 0.75)
		"stomp_shockwave":
			spawn_stomp_shockwave(pos, color, iso_radius)
		"vortex_burst":
			spawn_vortex(pos, color, Color(0.3, 0.7, 0.85))
		"necrotic_pulse":
			spawn_necrotic_pulse(pos, iso_radius, color if has_color else null)
		"stone_scatter":
			spawn_stone_scatter(pos, color, iso_radius)
		"tracer_line":
			spawn_tracer_line(origin, pos, color)
		"precision_flash":
			spawn_precision_flash(pos)
		"energy_shockwave":
			spawn_energy_shockwave(pos, color)
		"buff_ring":
			spawn_buff_ring(origin, color)
		"buff_aura":
			# Aura clings to the player for the buff's duration, then self-fades (no leak).
			var aura_life : float = float(skill.get("duration", 4.0)) + float(skill.get("dur_per_tier", 0.0)) * (tier - 1)
			spawn_buff_aura(caster, color, aura_life)
		_:
			print("[Synergies] unknown vfx '%s' for '%s'" % [vfx_name, String(skill.get("name", "?"))])

