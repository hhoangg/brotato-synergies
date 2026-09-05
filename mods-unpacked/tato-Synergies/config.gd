# Config for the Co-op Synergies mod (tato-Synergies).
# Framework constants for the per-character active-skill system + faction affinities.
extends Reference

const MOD_ID := "tato-Synergies"

# Shown in the load log so you can confirm the installed build at a glance.
# KEEP IN SYNC with manifest.json "version_number".
const MOD_VERSION := "0.39.14"

# ---- Skill icons (one per character slug; generated, masked to a transparent circle) ----
const SKILLS_ICON_DIR := "res://mods-unpacked/tato-Synergies/assets/skills"

# ---- Active-skill framework rules (see docs/superpowers/specs co-op-depth design) ----
# ---- TEST MODE — lower the gates so we can iterate without grinding a real run ----
# true = test build (fast cooldown + skills usable from level 1). Flip to false for real play.
const TEST_MODE := false

# Skills are a CO-OP feature by design (solo gets no active skills). TEMP: enabled in solo too so we
# can test fast with one player + keyboard. SET FALSE for release → skills only when >1 player.
const ENABLE_IN_SOLO := false

const UNLOCK_LEVEL := 6                    # real: a character's active skill unlocks at this level
const UNLOCK_LEVEL_TEST := 1               # TEST_MODE: usable from level 1 (no grind to test)
const UPGRADE_EVERY := 6                   # +1 skill tier every this many levels (L12/18/24/30)
const MAX_TIER := 5                        # tier 1 (unlock) + 4 upgrades
const COOLDOWN_WAVE_FRACTION := 0.45       # real: cooldown = 45% of the wave's duration (~2 casts/wave)
const COOLDOWN_WAVE_FRACTION_TEST := 0.05  # TEST_MODE: ~5% of the wave so we can spam-test trigger/HUD

# COOLDOWN CLASSES — each skill carries a `cooldown_class` that MULTIPLIES the base 45% cooldown, so
# weaker/spammier skills fire more often and high-impact "payoff" skills fire less. Diversifies playstyle
# beyond "everyone gets ~2 casts/wave". A skill with no class defaults to "normal". (Shown on the card as
# the casts-per-wave estimate.)
const COOLDOWN_CLASS_MULT := {
	"fast": 0.5,     # ~4 casts/wave — low-impact, spammy
	"normal": 1.0,   # ~2 casts/wave — the default
	"slow": 1.6,     # ~1.2 casts/wave — high-impact payoff
}
# TEST_MODE: buffs last this long so you can PAUSE mid-wave and read the stat panel (number rises),
# then watch it revert when it expires. Clearly temporary — NOT the ~5-8s of real play, just comfier
# to observe. (In real play the cooldown is longer than the buff, so casts never stack.)
const TEST_BUFF_SECONDS := 20.0

# ---- Endless scaling — keep damage/heal skills relevant when enemies get tanky in late/endless waves ----
# A skill's fixed (tier-capped) numbers go stale by wave 20+. Two scalers, tuned "just enough" (not OP):
#  - base damage/heal is multiplied by a WAVE factor (a floor that grows every wave, for every build),
#  - PLUS a tier-growing share of the caster's Damage stat is added (rewards an invested build).
# dmg = round(base_tier * (1 + WAVE_DMG_GROWTH*(wave-1))  +  casterDamage * (CASTER_BASE + CASTER_PER_TIER*(tier-1)))
const SKILL_WAVE_DMG_GROWTH := 0.15        # +15% base skill damage per wave
const SKILL_CASTER_DMG_BASE := 1.0         # caster-Damage share at tier 1 (×1)
const SKILL_CASTER_DMG_PER_TIER := 0.25    # +0.25× caster Damage per tier (tier 5 → ×2.0)
const SKILL_WAVE_HEAL_GROWTH := 0.12       # heal grows a bit slower than damage

# ---- Input: one free button per player to fire the skill (Brotato co-op uses only movement) ----
# Trigger is POLL-based (read button STATE each frame, fire on the rising edge — robust against
# flaky pad event delivery; see synergies_controller.gd _poll_trigger).
# Keyboard: Space. Controller: the BOTTOM face button = joypad button index 0 (Xbox "A"; on a
# Nintendo-layout pad it's the bottom button labelled "B" — Godot maps by POSITION, not label).
# Reverted to 0 (from R1=5) so we don't clash with OTHER mods that commonly bind the shoulders.
# The only overlap is the game's own `ui_accept` (shop-buy / menu confirm) — harmless here: poll
# never consumes the event, and skills fire ONLY during an ACTIVE WAVE (not the shop/menu), where
# `ui_accept` does nothing anyway. Routing resolves by DEVICE, so the button is purely ergonomic.
# (Want a fully conflict-free button later? R3 = right-stick click = index 9.) Avoid 6 (BattleCries L2).
const SKILL_KEY := KEY_SPACE
const SKILL_BUTTON := 0

# ---- Roles (drive the skill archetype + icon color coding; assigned per character later) ----
const ROLE_SUPPORT := "support"
const ROLE_AD := "ad"
const ROLE_CASTER := "caster"
const ROLE_TANK := "tank"
const ROLE_LATE := "late"
const ROLE_SKIRMISHER := "skirmisher"
const ROLE_FLEX := "flex"

# ---- Effect templates (each skill is ONE of these — build the path once, reuse for 64) ----
# Implemented so far:
const TMPL_BUFF_SELF := "buff_self"     # temp stat(s) on the CASTER only
const TMPL_BUFF_PARTY := "buff_party"   # temp stat(s) on ALL co-op players (incl. the caster)
const TMPL_HEAL := "heal"               # instant heal to all allies (incl. caster)
const TMPL_AOE_SELF := "aoe_self"       # damage burst around the caster
const TMPL_SHIELD := "shield"           # temp defensive stats (+Armor/+Max HP) on the caster, fills the HP
const TMPL_AOE_CURSOR := "aoe_cursor"   # damage burst at the nearest enemy cluster
const TMPL_DASH := "dash"               # teleport the caster + a temp evasive self-buff (dodge/speed)
const TMPL_SUMMON := "summon"           # deploy a temporary turret that auto-fires at nearby enemies
const TMPL_CC := "cc"                    # crowd-control: freeze ALL enemies (speed→0) for a bit, NO damage
const TMPL_CURSE_CLOUD := "curse_cloud"   # purple poison cloud: slow + DoT scaled by curse count
const TMPL_HEAL_ZONE := "heal_zone"       # blink to the lowest-HP ally, drop a lasting heal+slow field (%HP/s)
const TMPL_GREED := "greed"               # team "Midas window": ×mult on ALL materials the team picks up for a bit
# (more templates — TAUNT … — land as they're wired)
#   cc: duration(+dur_per_tier), freeze_tint:[r,g,b]. Brotato has no hard stun, so "freeze" = slow to 0
#     (can't move → melee can't reach) + an icy tint; deals no damage (pure control).
#   clear_fog: <secs>(+clear_fog_per_tier) — universal RIDER on any skill: hides the Danger-6 fog for N s.
#   summon: sprite, shot:"beam"/"arc"/"none", shot_color:[r,g,b], interval, range, hit_radius(+_per_tier),
#     damage(+_per_tier), life(+life_per_tier), summon_mode:"damage"/"heal"(+heal), burn. Reuses the game's
#     turret SPRITE but fires with our AOE-hitbox + beam/arc (no game-projectile pooling). `stats` = self-buff rider.

# Per-character skill registry — ALL 64, EACH with a UNIQUE combo (not just different numbers).
#   buff/shield/dash: duration, dur_per_tier, stats{k:base}, stats_per_tier{k:inc} (+distance for dash)
#   heal: heal, heal_per_tier   ·   aoe: radius, radius_per_tier, damage, damage_per_tier
#   RIDERS (flavor, optional): stats(+duration,buff_party)=temp buff on cast; drain(+drain_party)=heal on cast.
#   aoe_on_cast{damage,damage_per_tier,radius,radius_per_tier,at:"self"/"cursor"/"impact",count,spread,
#     beam:true(laser line),ring_color:[r,g,b],burn,hit_vfx} = a damaging burst fired WHEN cast, so a buff/dash
#     also hits (cyborg laser, captain volley, bull impact). Scales with the caster's Damage like all AOE.
#   ELEMENTAL riders (any AOE skill or aoe_on_cast): burn:"ember"/"fire"/"arcane" → sets the Hitbox's
#     burning_data from a base-game BurningData.tres so struck enemies CATCH FIRE (real DoT + fire particles).
#     hit_vfx:"curse"/"burn" → spawns that particle on each struck enemy (debuff read; visual for now).
#   arc:true (+arc_color:[r,g,b]) on an AOE skill → crackling chain-lightning from caster to nearest enemies
#     (lich/technomage). AOE casts also play the game's rocket explosion SFX (the "boom").
# Tier scaling: value(T) = base + (T-1)*per_tier, T1..MAX_TIER(5). The char-select card shows the T1->T5 range.
const SKILLS := {
	"doctor": {
		"name": "Field Hospital",
		"role": ROLE_SUPPORT,
		"template": TMPL_HEAL_ZONE,
		# Blink to the lowest-HP ally, then drop a lasting field that heals allies inside for a % of their
		# MAX HP every second AND slows enemies that wander in. Both the radius and the %/s grow with tier.
		"radius": 180.0,
		"radius_per_tier": 30.0,
		"duration": 6.0,
		"dur_per_tier": 0.75,
		"heal_percent": 0.03,            # 3% max HP per second at T1 …
		"heal_percent_per_tier": 0.0175, # … → ~10% at T5
		"tick_interval": 1.0,            # heal pulse every second
		"slow_percent": 0.4,             # enemies inside are slowed 40%
	},
	"pacifist": {
		"name": "Harmony",
		"role": ROLE_SUPPORT,
		"template": TMPL_BUFF_PARTY,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_harvesting": 20, "stat_xp_gain": 15},
		"stats_per_tier": {"stat_harvesting": 8, "stat_xp_gain": 6},
	},
	"romantic": {
		"name": "Charm",
		"role": ROLE_SUPPORT,
		"template": TMPL_HEAL,
		"cooldown_class": "fast",
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"heal": 10,
		"heal_per_tier": 4,
		"stats": {"stat_speed": 15},
		"stats_per_tier": {"stat_speed": 4},
		"buff_party": true,
		"charm": {
			"count": 2,
			"count_per_tier": 0,
			"hp_threshold": 0.6,
			"duration": 3.0,
			"duration_per_tier": 0.5,
		},
	},
	"beast-master": {
		"name": "Rally Beasts",
		"role": ROLE_SUPPORT,
		"template": TMPL_BUFF_PARTY,
		"duration": 5.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_damage": 8, "stat_attack_speed": 8},
		"stats_per_tier": {"stat_damage": 4, "stat_attack_speed": 4},
	},
	"king": {
		"name": "Royal Decree",
		"role": ROLE_SUPPORT,
		"template": TMPL_BUFF_PARTY,
		"cooldown_class": "slow",
		"duration": 5.0,
		"dur_per_tier": 0.75,
		"stats": {"stat_damage": 10, "stat_armor": 5, "stat_luck": 10},
		"stats_per_tier": {"stat_damage": 5, "stat_armor": 2, "stat_luck": 5},
	},
	"lucky": {
		"name": "Lucky Charm",
		"role": ROLE_SUPPORT,
		"template": TMPL_BUFF_PARTY,
		"cooldown_class": "slow",
		"duration": 5.0,
		"dur_per_tier": 0.75,
		"stats": {"stat_luck": 30, "stat_crit_chance": 10},
		"stats_per_tier": {"stat_luck": 17, "stat_crit_chance": 4},
		"clear_fog": 6.0,
		"clear_fog_per_tier": 1.0,
	},
	"old": {
		"name": "Veteran's Resolve",
		"role": ROLE_SUPPORT,
		"template": TMPL_SHIELD,
		"cooldown_class": "slow",
		"duration": 5.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_armor": 20, "stat_hp_regeneration": 5},
		"stats_per_tier": {"stat_armor": 8, "stat_hp_regeneration": 2},
	},
	"chef": {
		"name": "Hot Meal",
		"role": ROLE_SUPPORT,
		"template": TMPL_HEAL,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"heal": 12,
		"heal_per_tier": 5,
		"stats": {"stat_damage": 5},
		"stats_per_tier": {"stat_damage": 2},
		"buff_party": true,
	},
	"ranger": {
		"name": "Steady Aim",
		"role": ROLE_AD,
		"template": TMPL_BUFF_SELF,
		"cooldown_class": "fast",
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_ranged_damage": 25, "stat_range": 15},
		"stats_per_tier": {"stat_ranged_damage": 9, "stat_range": 6},
	},
	"hunter": {
		"name": "Aimed Volley",
		"role": ROLE_AD,
		"template": TMPL_AOE_CURSOR,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"radius": 140.0,
		"radius_per_tier": 25.0,
		"damage": 30,
		"damage_per_tier": 15,
		"stats": {"stat_crit_chance": 20},
		"stats_per_tier": {"stat_crit_chance": 5},
		"vfx": "precision_flash",
	},
	"soldier": {
		"name": "Suppressing Fire",
		"role": ROLE_AD,
		"template": TMPL_AOE_CURSOR,
		"duration": 3.0,
		"dur_per_tier": 0.50,
		"radius": 150.0,
		"radius_per_tier": 26.0,
		"damage": 24,
		"damage_per_tier": 12,
		"stats": {"stat_ranged_damage": 15},
		"stats_per_tier": {"stat_ranged_damage": 6},
		"vfx": "tracer_line",
	},
	"renegade": {
		"name": "Volley",
		"role": ROLE_AD,
		"template": TMPL_AOE_CURSOR,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"radius": 160.0,
		"radius_per_tier": 28.0,
		"damage": 24,
		"damage_per_tier": 12,
		"stats": {"stat_ranged_damage": 22},
		"stats_per_tier": {"stat_ranged_damage": 8},
		"vfx": "hit_burst",
	},
	"gladiator": {
		"name": "Arena Sweep",
		"role": ROLE_AD,
		"template": TMPL_AOE_SELF,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"radius": 150.0,
		"radius_per_tier": 25.0,
		"damage": 20,
		"damage_per_tier": 10,
		"stats": {"stat_attack_speed": 25},
		"stats_per_tier": {"stat_attack_speed": 8},
		"vfx": "stomp_shockwave",
	},
	"multitasker": {
		"name": "All Out",
		"role": ROLE_AD,
		"template": TMPL_BUFF_SELF,
		"duration": 3.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_attack_speed": 40, "stat_damage": 10},
		"stats_per_tier": {"stat_attack_speed": 12, "stat_damage": 5},
	},
	"one-armed": {
		"name": "Haymaker",
		"role": ROLE_AD,
		"template": TMPL_AOE_CURSOR,
		"cooldown_class": "slow",
		"radius": 120.0,
		"radius_per_tier": 20.0,
		"damage": 50,
		"damage_per_tier": 25,
		"vfx": "stomp_shockwave",
		"vfx_color": [0.9, 0.6, 0.2],
	},
	"demon": {
		"name": "Soul Harvest",
		"role": ROLE_AD,
		"template": TMPL_AOE_SELF,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"radius": 150.0,
		"radius_per_tier": 25.0,
		"damage": 25,
		"damage_per_tier": 12,
		"stats": {"stat_lifesteal": 30},
		"stats_per_tier": {"stat_lifesteal": 8},
		"burn": "ember",
		"vfx": "necrotic_pulse",
	},
	"vampire": {
		"name": "Bloodlust",
		"role": ROLE_AD,
		"template": TMPL_AOE_SELF,
		"radius": 150.0,
		"radius_per_tier": 25.0,
		"damage": 20,
		"damage_per_tier": 10,
		"drain": 12,
		"drain_per_tier": 5,
		"vfx": "hit_burst",
		"vfx_color": [0.8, 0.1, 0.1],
	},
	"masochist": {
		"name": "Retribution",
		"role": ROLE_AD,
		"template": TMPL_AOE_SELF,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"radius": 160.0,
		"radius_per_tier": 25.0,
		"damage": 25,
		"damage_per_tier": 12,
		"stats": {"stat_armor": 15},
		"stats_per_tier": {"stat_armor": 6},
		# TAUNT rider: for 5→9s, drag nearby enemies toward the masochist (like the Scapegoat pet draws
		# aggro) so he soaks the room while his armor + retaliation pay it back. Own timer, not the 4s skill.
		"taunt": 5.0,
		"taunt_per_tier": 1.0,
		"taunt_radius": 450.0,
		"vfx": "stomp_shockwave",
	},
	"gangster": {
		"name": "Drive-By",
		"role": ROLE_AD,
		"template": TMPL_AOE_CURSOR,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"radius": 150.0,
		"radius_per_tier": 26.0,
		"damage": 26,
		"damage_per_tier": 13,
		"stats": {"stat_harvesting": 20},
		"stats_per_tier": {"stat_harvesting": 8},
		"vfx": "tracer_line",
	},
	"captain": {
		"name": "Broadside",
		"role": ROLE_AD,
		"template": TMPL_BUFF_PARTY,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_attack_speed": 10, "stat_damage": 5},
		"stats_per_tier": {"stat_attack_speed": 4, "stat_damage": 2},
		"aoe_on_cast": {
			"at": "cursor",
			"count": 3,
			"spread": 100.0,
			"ring_color": [1.0, 0.7, 0.2],
			"radius": 90.0, "radius_per_tier": 14.0,
			"damage": 16, "damage_per_tier": 8,
		},
	},
	"sailor": {
		"name": "Cannonade",
		"role": ROLE_AD,
		"template": TMPL_AOE_CURSOR,
		"duration": 3.0,
		"dur_per_tier": 0.50,
		"radius": 160.0,
		"radius_per_tier": 28.0,
		"damage": 28,
		"damage_per_tier": 14,
		"stats": {"stat_range": 20},
		"stats_per_tier": {"stat_range": 6},
		"vfx": "explosion_burst",
	},
	"cyborg": {
		"name": "Overclock",
		"role": ROLE_AD,
		"template": TMPL_BUFF_SELF,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_attack_speed": 30, "stat_crit_chance": 8},
		"stats_per_tier": {"stat_attack_speed": 10, "stat_crit_chance": 3},
		"aoe_on_cast": {
			"at": "cursor",
			"beam": true,
			"ring_color": [0.35, 0.85, 1.0],
			"radius": 110.0, "radius_per_tier": 18.0,
			"damage": 22, "damage_per_tier": 12,
			"burn": "ember",
		},
		"vfx": "energy_shockwave",
		"vfx_color": [0.35, 0.85, 1.0],
	},
	"buccaneer": {
		"name": "Plunder",
		"role": ROLE_AD,
		"template": TMPL_BUFF_SELF,
		"duration": 3.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_attack_speed": 35, "stat_luck": 20},
		"stats_per_tier": {"stat_attack_speed": 10, "stat_luck": 6},
		"material_drop": 8,
		"material_drop_per_tier": 2,
	},
	"arms-dealer": {
		"name": "Fire Sale",
		"role": ROLE_AD,
		"template": TMPL_AOE_CURSOR,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"radius": 170.0,
		"radius_per_tier": 30.0,
		"damage": 26,
		"damage_per_tier": 13,
		"stats": {"stat_engineering": 12, "stat_damage": 8},
		"stats_per_tier": {"stat_engineering": 5, "stat_damage": 3},
		"vfx": "explosion_burst",
		"vfx_color": [1.0, 0.3, 0.1],
	},
	"brawler": {
		"name": "Flurry",
		"role": ROLE_AD,
		"template": TMPL_AOE_SELF,
		"cooldown_class": "fast",
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"radius": 140.0,
		"radius_per_tier": 22.0,
		"damage": 20,
		"damage_per_tier": 10,
		"stats": {"stat_attack_speed": 20, "stat_speed": 15},
		"stats_per_tier": {"stat_attack_speed": 6, "stat_speed": 4},
		"vfx": "hit_burst",
		"vfx_color": [1.0, 0.5, 0.1],
	},
	"wildling": {
		"name": "Primal Rage",
		"role": ROLE_AD,
		"template": TMPL_BUFF_SELF,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_attack_speed": 30, "stat_lifesteal": 10},
		"stats_per_tier": {"stat_attack_speed": 10, "stat_lifesteal": 4},
		"vfx": "buff_aura",
		"vfx_color": [0.9, 0.3, 0.1],
	},
	"crazy": {
		"name": "Berserk",
		"role": ROLE_AD,
		"template": TMPL_BUFF_SELF,
		"duration": 3.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_attack_speed": 50, "stat_dodge": 10},
		"stats_per_tier": {"stat_attack_speed": 12, "stat_dodge": 3},
		"vfx": "buff_aura",
		"vfx_color": [1.0, 0.2, 0.2],
	},
	"mage": {
		"name": "Arcane Nova",
		"role": ROLE_CASTER,
		"template": TMPL_AOE_CURSOR,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"radius": 160.0,
		"radius_per_tier": 30.0,
		"damage": 30,
		"damage_per_tier": 15,
		"stats": {"stat_elemental_damage": 25},
		"stats_per_tier": {"stat_elemental_damage": 8},
		"burn": "fire",
		"vfx": "arcane_ring",
	},
	"apprentice": {
		"name": "Arcane Bolt",
		"role": ROLE_CASTER,
		"template": TMPL_AOE_SELF,
		"cooldown_class": "fast",
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"radius": 130.0,
		"radius_per_tier": 22.0,
		"damage": 20,
		"damage_per_tier": 10,
		"stats": {"stat_elemental_damage": 15},
		"stats_per_tier": {"stat_elemental_damage": 6},
		"burn": "ember",
		"vfx": "arcane_ring",
	},
	"lich": {
		"name": "Death Coil",
		"role": ROLE_CASTER,
		"template": TMPL_AOE_SELF,
		"radius": 160.0,
		"radius_per_tier": 28.0,
		"damage": 22,
		"damage_per_tier": 11,
		"drain": 10,
		"drain_per_tier": 4,
		"drain_party": true,
		"arc": true,
		"arc_color": [0.9, 0.15, 0.15],
		"aoe_color": [0.9, 0.15, 0.15],
	},
	"druid": {
		"name": "Overgrowth",
		"role": ROLE_CASTER,
		"template": TMPL_AOE_CURSOR,
		"cooldown_class": "fast",
		"radius": 170.0,
		"radius_per_tier": 30.0,
		"damage": 20,
		"damage_per_tier": 10,
		"drain": 8,
		"drain_per_tier": 3,
		"drain_party": true,
		"hit_vfx": "curse",
	},
	"technomage": {
		"name": "Arc Turret",
		"role": ROLE_CASTER,
		"template": TMPL_SUMMON,
		"cooldown_class": "slow",
		"sprite": "res://entities/structures/turret/laser/laser_turret.png",
		"shot": "arc",
		"shot_color": [0.40, 0.85, 1.0],
		"interval": 0.8,
		"range": 580.0,
		"range_per_tier": 50.0,
		"hit_radius": 60.0,
		"hit_radius_per_tier": 7.0,
		"damage": 14,
		"damage_per_tier": 8,
		"life": 6.0,
		"life_per_tier": 1.0,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_engineering": 20},
		"stats_per_tier": {"stat_engineering": 7},
	},
	"artificer": {
		"name": "Cluster Bomb",
		"role": ROLE_CASTER,
		"template": TMPL_AOE_CURSOR,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"radius": 180.0,
		"radius_per_tier": 32.0,
		"damage": 24,
		"damage_per_tier": 12,
		"stats": {"stat_engineering": 18, "stat_elemental_damage": 10},
		"stats_per_tier": {"stat_engineering": 6, "stat_elemental_damage": 4},
		"burn": "fire",
		"vfx": "explosion_burst",
	},
	"sick": {
		"name": "Plague Cloud",
		"role": ROLE_CASTER,
		"template": TMPL_AOE_SELF,
		"cooldown_class": "fast",
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"radius": 150.0,
		"radius_per_tier": 25.0,
		"damage": 15,
		"damage_per_tier": 8,
		"stats": {"stat_speed": 20},
		"stats_per_tier": {"stat_speed": 6},
		"hit_vfx": "curse",
		"vfx": "necrotic_pulse",
		"vfx_color": [0.3, 0.7, 0.2],
	},
	"bull": {
		"name": "Bullrush",
		"role": ROLE_TANK,
		"template": TMPL_DASH,
		"distance": 300.0,
		"distance_per_tier": 30.0,
		"iframe": 0.50,
		"iframe_per_tier": 0.15,
		"duration": 3.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_armor": 15, "stat_speed": 20},
		"stats_per_tier": {"stat_armor": 6, "stat_speed": 6},
		"aoe_on_cast": {
			"at": "impact",
			"ring_color": [1.0, 0.4, 0.15],
			"radius": 150.0, "radius_per_tier": 24.0,
			"damage": 25, "damage_per_tier": 13,
		},
		"vfx": "stomp_shockwave",
		"vfx_at": "impact",
	},
	"golem": {
		"name": "Bastion",
		"role": ROLE_TANK,
		"template": TMPL_SHIELD,
		"cooldown_class": "slow",
		"duration": 5.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_armor": 20, "stat_max_hp": 20},
		"stats_per_tier": {"stat_armor": 10, "stat_max_hp": 10},
		"vfx": "stone_scatter",
	},
	"knight": {
		"name": "Shield Wall",
		"role": ROLE_TANK,
		"template": TMPL_SHIELD,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_armor": 15, "stat_dodge": 8},
		"stats_per_tier": {"stat_armor": 6, "stat_dodge": 3},
	},
	"ogre": {
		"name": "Smash",
		"role": ROLE_TANK,
		"template": TMPL_AOE_SELF,
		"duration": 3.0,
		"dur_per_tier": 0.50,
		"radius": 170.0,
		"radius_per_tier": 28.0,
		"damage": 25,
		"damage_per_tier": 12,
		"stats": {"stat_armor": 12},
		"stats_per_tier": {"stat_armor": 5},
		"vfx": "stomp_shockwave",
		"vfx_color": [0.6, 0.4, 0.2],
	},
	"chunky": {
		"name": "Bulk Up",
		"role": ROLE_TANK,
		"template": TMPL_SHIELD,
		"cooldown_class": "slow",
		"duration": 6.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_max_hp": 20, "stat_armor": 10},
		"stats_per_tier": {"stat_max_hp": 8, "stat_armor": 4},
	},
	"dwarf": {
		"name": "Stoneskin",
		"role": ROLE_TANK,
		"template": TMPL_SHIELD,
		"cooldown_class": "slow",
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_armor": 20, "stat_max_hp": 8},
		"stats_per_tier": {"stat_armor": 10, "stat_max_hp": 4},
		"vfx": "stone_scatter",
	},
	"loud": {
		"name": "Sonic Boom",
		"role": ROLE_TANK,
		"template": TMPL_CC,
		"cooldown_class": "slow",
		"duration": 1.5,
		"dur_per_tier": 0.30,
		"freeze_tint": [0.55, 0.85, 1.0],
		"vfx": "energy_shockwave",
	},
	"glutton": {
		"name": "Devour",
		"role": ROLE_TANK,
		"template": TMPL_HEAL,
		"duration": 6.0,
		"dur_per_tier": 0.50,
		"heal": 20,
		"heal_per_tier": 8,
		"stats": {"stat_max_hp": 15},
		"stats_per_tier": {"stat_max_hp": 6},
	},
	"engineer": {
		"name": "Deploy Turret",
		"role": ROLE_LATE,
		"template": TMPL_SUMMON,
		"cooldown_class": "slow",
		"sprite": "res://entities/structures/turret/builder/builder_turret_4.png",
		"shot": "beam",
		"shot_color": [1.0, 0.62, 0.2],
		"interval": 0.9,
		"range": 560.0,
		"range_per_tier": 50.0,
		"hit_radius": 70.0,
		"hit_radius_per_tier": 8.0,
		"damage": 16,
		"damage_per_tier": 9,
		"life": 6.0,
		"life_per_tier": 1.0,
		"duration": 5.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_engineering": 15, "stat_range": 10},
		"stats_per_tier": {"stat_engineering": 6, "stat_range": 4},
	},
	"builder": {
		"name": "Barricade",
		"role": ROLE_LATE,
		"template": TMPL_SHIELD,
		"duration": 5.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_armor": 18, "stat_max_hp": 15},
		"stats_per_tier": {"stat_armor": 7, "stat_max_hp": 6},
		"vfx": "stone_scatter",
	},
	"farmer": {
		"name": "Bountiful Harvest",
		"role": ROLE_LATE,
		"template": TMPL_HEAL,
		"duration": 5.0,
		"dur_per_tier": 0.50,
		"heal": 10,
		"heal_per_tier": 4,
		"stats": {"stat_harvesting": 25},
		"stats_per_tier": {"stat_harvesting": 8},
		"buff_party": true,
		"radius": 200.0,
		"radius_per_tier": 40.0,
	},
	"saver": {
		"name": "Cash Out",
		"role": ROLE_LATE,
		"template": TMPL_BUFF_SELF,
		"duration": 5.0,
		"dur_per_tier": 0.75,
		"stats": {"stat_damage": 15, "stat_armor": 10},
		"stats_per_tier": {"stat_damage": 5, "stat_armor": 5},
		"material_drop": 15,
		"material_drop_per_tier": 5,
	},
	"entrepreneur": {
		"name": "Liquidate",
		"role": ROLE_LATE,
		"template": TMPL_BUFF_SELF,
		"duration": 5.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_damage": 15, "stat_harvesting": 20},
		"stats_per_tier": {"stat_damage": 5, "stat_harvesting": 8},
	},
	"streamer": {
		"name": "Go Live",
		"role": ROLE_LATE,
		"template": TMPL_BUFF_PARTY,
		"cooldown_class": "fast",
		"duration": 5.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_damage": 5, "stat_attack_speed": 5, "stat_armor": 3},
		"stats_per_tier": {"stat_damage": 2, "stat_attack_speed": 2, "stat_armor": 2},
		"standing_still_bonus": 1.5,
		"standing_still_window": 1.0,
	},
	"curious": {
		"name": "Treasure Hunt",
		"role": ROLE_LATE,
		"template": TMPL_SUMMON,
		"cooldown_class": "slow",
		"sprite": "res://mods-unpacked/tato-Synergies/assets/skills/curious.png",
		"shot": "none",
		"interval": 999.0,
		"range": 300.0,
		"range_per_tier": 30.0,
		"hit_radius": 0.0,
		"hit_radius_per_tier": 0.0,
		"damage": 0,
		"damage_per_tier": 0,
		"life": 5.0,
		"life_per_tier": 1.0,
		"duration": 5.0,
		"dur_per_tier": 1.0,
		"scout_mode": true,
	},
	"baby": {
		"name": "Growth Spurt",
		"role": ROLE_LATE,
		"template": TMPL_BUFF_SELF,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_damage": 15, "stat_attack_speed": 15, "stat_armor": 10, "stat_speed": 10},
		"stats_per_tier": {"stat_damage": 6, "stat_attack_speed": 6, "stat_armor": 5, "stat_speed": 5},
	},
	"fisherman": {
		"name": "Cast Net",
		"role": ROLE_LATE,
		"template": TMPL_AOE_CURSOR,
		"cooldown_class": "fast",
		"duration": 3.0,
		"dur_per_tier": 0.50,
		"radius": 160.0,
		"radius_per_tier": 28.0,
		"damage": 18,
		"damage_per_tier": 9,
		"stats": {"stat_harvesting": 15},
		"stats_per_tier": {"stat_harvesting": 6},
		"vfx": "vortex_burst",
	},
	"speedy": {
		"name": "Sprint",
		"role": ROLE_SKIRMISHER,
		"template": TMPL_DASH,
		"cooldown_class": "fast",
		"distance": 280.0,
		"distance_per_tier": 30.0,
		"iframe": 0.50,
		"iframe_per_tier": 0.18,
		"duration": 3.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_speed": 40},
		"stats_per_tier": {"stat_speed": 12},
		"vfx": "buff_ring",
		"vfx_color": [0.3, 0.7, 1.0],
	},
	"diver": {
		"name": "Tidal Surge",
		"role": ROLE_SKIRMISHER,
		"template": TMPL_DASH,
		"distance": 280.0,
		"distance_per_tier": 30.0,
		"iframe": 0.40,
		"iframe_per_tier": 0.10,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_speed": 20},
		"stats_per_tier": {"stat_speed": 6},
		# RESCUE: surge to the landing point and SHOVE enemies outward (a tidal wave), then leave them
		# briefly slowed so a cornered ally can escape. `amount` = push distance in PIXELS (enemies are
		# lerped outward over `push_duration`); the game's hitbox-knockback property doesn't apply here.
		"knockback": {
			"amount": 220, "amount_per_tier": 60,
			"radius": 150.0, "radius_per_tier": 25.0,
			"push_duration": 0.18,
			"slow_percent": 0.5, "slow_duration": 1.0, "slow_duration_per_tier": 0.2,
			"ring_color": [0.2, 0.6, 1.0],
		},
		"vfx": "vortex_burst",
		"vfx_at": "impact",
	},
	"ghost": {
		"name": "Phase",
		"role": ROLE_SKIRMISHER,
		"template": TMPL_DASH,
		"cooldown_class": "fast",
		"distance": 220.0,
		"distance_per_tier": 26.0,
		"iframe": 0.70,
		"iframe_per_tier": 0.20,
		"duration": 2.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_dodge": 50},
		"stats_per_tier": {"stat_dodge": 12},
		"vfx": "buff_aura",
		"vfx_color": [0.6, 0.3, 0.9],
	},
	"cryptid": {
		"name": "Vanish",
		"role": ROLE_SKIRMISHER,
		"template": TMPL_DASH,
		"cooldown_class": "fast",
		"distance": 340.0,
		"distance_per_tier": 30.0,
		"iframe": 0.60,
		"iframe_per_tier": 0.18,
		"duration": 3.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_dodge": 30, "stat_speed": 20},
		"stats_per_tier": {"stat_dodge": 8, "stat_speed": 6},
		"vfx": "buff_aura",
		"vfx_color": [0.2, 0.2, 0.3],
	},
	"creature": {
		"name": "Curse Cloud",
		"role": ROLE_SKIRMISHER,
		"template": "curse_cloud",
		"duration": 6.0,
		"dur_per_tier": 1.0,
		"radius": 150.0,
		"radius_per_tier": 25.0,
		"curse_dmg_percent": 0.2,
		"tick_interval": 0.2,
		"slow_percent": 0.5,
		# DoT/tick = max(wave-scaled base, curse_count * curse_dmg_percent). The base FLOOR keeps the
		# cloud useful on low-curse builds and grows with the wave; a curse build overtakes it (its flavor).
		"base_damage": 5,
		"base_damage_per_tier": 2,
	},
	"explorer": {
		"name": "Trailblaze",
		"role": ROLE_SKIRMISHER,
		"template": TMPL_DASH,
		"cooldown_class": "fast",
		"distance": 240.0,
		"distance_per_tier": 26.0,
		"iframe": 0.45,
		"iframe_per_tier": 0.15,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_speed": 25, "stat_harvesting": 15},
		"stats_per_tier": {"stat_speed": 6, "stat_harvesting": 6},
	},
	"hiker": {
		"name": "Second Wind",
		"role": ROLE_SKIRMISHER,
		"template": TMPL_DASH,
		"cooldown_class": "fast",
		"distance": 240.0,
		"distance_per_tier": 26.0,
		"iframe": 0.45,
		"iframe_per_tier": 0.15,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_speed": 25, "stat_hp_regeneration": 4},
		"stats_per_tier": {"stat_speed": 6, "stat_hp_regeneration": 2},
	},
	"wounded": {
		"name": "Adrenaline",
		"role": ROLE_SKIRMISHER,
		"template": TMPL_BUFF_SELF,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_damage": 30, "stat_dodge": 15},
		"stats_per_tier": {"stat_damage": 10, "stat_dodge": 5},
		"vfx": "buff_ring",
		"vfx_color": [1.0, 0.3, 0.3],
	},
	"generalist": {
		"name": "Adapt",
		"role": ROLE_FLEX,
		"template": TMPL_BUFF_PARTY,
		"cooldown_class": "fast",
		"duration": 5.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_damage": 5, "stat_attack_speed": 5, "stat_armor": 3, "stat_speed": 3},
		"stats_per_tier": {"stat_damage": 2, "stat_attack_speed": 2, "stat_armor": 1, "stat_speed": 1},
	},
	"well-rounded": {
		"name": "Fortify",
		"role": ROLE_FLEX,
		"template": TMPL_SHIELD,
		"duration": 5.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_armor": 15, "stat_damage": 5},
		"stats_per_tier": {"stat_armor": 8, "stat_damage": 3},
	},
	"vagabond": {
		"name": "Scavenge",
		"role": ROLE_FLEX,
		"template": TMPL_BUFF_SELF,
		"cooldown_class": "fast",
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_damage": 15, "stat_speed": 15},
		"stats_per_tier": {"stat_damage": 5, "stat_speed": 4},
	},
	"jack": {
		"name": "Jackpot",
		"role": ROLE_FLEX,
		"template": TMPL_GREED,
		"cooldown_class": "slow",        # a big "ăn đậm" payoff — a deliberate windfall, not spammable
		"duration": 6.0,
		"dur_per_tier": 0.50,            # 6s → 8s at T5
		"mult": 3.0,                     # ×materials picked up by the WHOLE TEAM during the window
		"mult_per_tier": 1.0,            # ×3 (T1) → ×7 (T5). Self-balances: only multiplies gems actually on the floor.
	},
	"mutant": {
		"name": "Mutate",
		"role": ROLE_FLEX,
		"template": TMPL_BUFF_SELF,
		"duration": 4.0,
		"dur_per_tier": 0.50,
		"stats": {"stat_damage": 20, "stat_elemental_damage": 15},
		"stats_per_tier": {"stat_damage": 7, "stat_elemental_damage": 5},
	},
}

# One-line FLAVOR per skill (EN + VI) — evokes the character's identity, shown under the mechanical
# stats on the char-select card (like Brotato's own item flavor). Keyed by slug; falls back to "".
const SKILL_FLAVOR := {
	"doctor": {"en": "Rush to whoever's bleeding worst and raise a field tent over them.", "vi": "Lao tới người trọng thương nhất, dựng ngay lều cứu thương che chở."},
	"pacifist": {"en": "Lay down arms — turn a held breath into shared bounty.", "vi": "Buông vũ khí xuống, biến khoảnh khắc an yên thành lộc cho cả đội."},
	"romantic": {"en": "Blow a kiss — foes swoon while your friends mend.", "vi": "Gửi một nụ hôn gió, kẻ thù ngẩn ngơ còn đồng đội được chữa lành."},
	"beast-master": {"en": "Sound the horn — the whole pack bares its fangs at once.", "vi": "Thổi tù và, cả bầy thú cùng nhe nanh xông lên một lượt."},
	"king": {"en": "Issue the royal decree — the realm marches harder by command.", "vi": "Ban chiếu chỉ hoàng gia, cả vương quốc ra trận mạnh mẽ hơn."},
	"lucky": {"en": "Rub the charm — fortune smiles and the fog lifts for the crew.", "vi": "Xoa bùa hên, vận may mỉm cười và màn sương cũng tan đi cho cả đội."},
	"old": {"en": "Plant your boots — old scars harden into a veteran's wall.", "vi": "Đứng vững gót chân, vết sẹo xưa hóa thành bức tường của lão làng."},
	"chef": {"en": "Ring the dinner bell — a hot plate heals and fires up the table.", "vi": "Gõ chuông gọi cơm, bữa nóng vừa hồi máu vừa tiếp lửa cho cả bàn."},
	"ranger": {"en": "One breath, one shot — the world narrows to the crosshair.", "vi": "Một hơi thở, một phát đạn — cả thế giới thu vào đầu ruồi."},
	"hunter": {"en": "Mark the pack, loose the volley — nothing in the kill-box walks away.", "vi": "Đánh dấu bầy địch, buông loạt tên — không con nào trong tầm sống sót."},
	"soldier": {"en": "Lay down a wall of lead and let nothing lift its head.", "vi": "Dội một bức tường đạn, không cho địch nào ngóc đầu lên."},
	"renegade": {"en": "No orders, no mercy — just a rebel's full magazine downrange.", "vi": "Không mệnh lệnh, không khoan nhượng — kẻ phản loạn nã hết băng đạn."},
	"gladiator": {"en": "The crowd roars as you carve a bloody circle through the arena.", "vi": "Đám đông gào thét khi bạn quét một vòng máu giữa đấu trường."},
	"multitasker": {"en": "Every hand on a trigger at once — overwhelm with sheer output.", "vi": "Mọi bàn tay cùng bóp cò một lúc — áp đảo bằng hỏa lực thuần."},
	"one-armed": {"en": "One arm, one shot — put everything you've got into it.", "vi": "Một tay, một cú — dồn hết những gì bạn có vào đó."},
	"demon": {"en": "Reap the souls of the fallen and drink the life they leave behind.", "vi": "Gặt lấy linh hồn kẻ ngã xuống và nuốt trọn sinh khí chúng để lại."},
	"vampire": {"en": "Open every wound at once and let the blood come rushing back to you.", "vi": "Xé toang mọi vết thương cùng lúc để máu địch tuôn ngược về mình."},
	"masochist": {"en": "Every blow you take is loaded into the one you fire back.", "vi": "Mỗi đòn bạn hứng chịu đều dồn vào cú phản đòn giáng trả."},
	"gangster": {"en": "Roll up, light 'em up, and pocket whatever drops.", "vi": "Lượn tới, xả một tràng, rồi vơ sạch đồ rơi ra."},
	"captain": {"en": "Bring the whole ship's guns to bear — fire a broadside across the deck.", "vi": "Dồn toàn bộ hỏa pháo của tàu — bắn một loạt đại bác quét cả sàn."},
	"sailor": {"en": "Wheel the cannons round and pound the horde to splinters.", "vi": "Xoay nòng đại bác, nã nát bầy quái thành từng mảnh."},
	"cyborg": {"en": "Redline the chassis — let the servos scream and the laser sing.", "vi": "Đẩy bộ khung vượt giới hạn — để động cơ gào và tia laser hát."},
	"buccaneer": {"en": "Smash, grab, and sail off with the spoils before the smoke clears.", "vi": "Đập, cướp, rồi cao chạy xa bay với chiến lợi phẩm trước khi khói tan."},
	"arms-dealer": {"en": "Everything must go — clear the shelves with one explosive markdown.", "vi": "Xả hàng tất tay — dọn sạch kệ bằng một cú nổ giảm giá."},
	"brawler": {"en": "A storm of fists — nobody gets a turn to hit back.", "vi": "Một cơn bão nắm đấm — không kẻ nào kịp đánh trả."},
	"wildling": {"en": "Drop the spear and the manners — go feral.", "vi": "Vứt giáo, bỏ luôn lý trí — hóa thú hoang."},
	"crazy": {"en": "Pure adrenaline, zero plan — just swing until it stops moving.", "vi": "Toàn adrenaline, chẳng tính toán — cứ vung tới khi nó ngừng cựa quậy."},
	"mage": {"en": "Detonate a starburst of raw arcana that lingers as creeping fire.", "vi": "Bùng nổ một vầng phép thuật thuần khiết, để lại ngọn lửa âm ỉ lan dần."},
	"apprentice": {"en": "Still learning, still loud — the spell goes off right in your own hands.", "vi": "Vẫn còn học việc, vẫn còn vụng — phép nổ ngay trong chính tay mình."},
	"lich": {"en": "Hurl a coil of undeath that arcs between the dying and feeds the coven.", "vi": "Tung ra lọn năng lượng tử thần, nhảy giữa những kẻ hấp hối và nuôi cả bầy."},
	"druid": {"en": "Tear life from the field and let it bloom back into your allies.", "vi": "Rút sự sống từ mặt đất rồi để nó nở lại trong đồng đội của bạn."},
	"technomage": {"en": "Bolt together a crackling arc turret and let science do the killing.", "vi": "Lắp ráp một tháp pháo phóng tia điện và để khoa học làm phần giết chóc."},
	"artificer": {"en": "Lob a tinkered bomb that splits into a blossom of fire on the pack.", "vi": "Ném quả bom tự chế, nở thành một đóa lửa ngay giữa bầy địch."},
	"sick": {"en": "Exhale a sickly haze and let the contagion do your fighting.", "vi": "Thở ra một làn khí bệnh hoạn, để dịch bệnh thay bạn chiến đấu."},
	"bull": {"en": "Lower your horns and bulldoze straight through the swarm.", "vi": "Cúi sừng húc thẳng một đường, xé toạc cả bầy quái."},
	"golem": {"en": "Harden into a wall of living stone — nothing gets through.", "vi": "Hóa thành bức tường đá sống, không gì xuyên thủng nổi."},
	"knight": {"en": "Raise the shield and weather the storm of blows.", "vi": "Giương khiên lên, hứng trọn cơn bão đòn đánh."},
	"ogre": {"en": "Bring both fists down and shatter the ground beneath them.", "vi": "Giáng cả hai nắm đấm, nứt toác mặt đất dưới chân lũ địch."},
	"chunky": {"en": "Pack on the bulk — soak hits that would flatten anyone else.", "vi": "Phình to hết cỡ, gánh trọn những cú mà kẻ khác chỉ có gục."},
	"dwarf": {"en": "Skin turns to granite; blades just skip off.", "vi": "Da hóa đá granite, lưỡi đao chạm vào chỉ trượt đi."},
	"loud": {"en": "Let out a scream so loud the whole arena freezes mid-step.", "vi": "Hét một tiếng inh tai, cả đấu trường chết đứng giữa chừng."},
	"glutton": {"en": "Swallow the battlefield whole — every bite mends and makes you bigger.", "vi": "Nuốt chửng cả trận địa, mỗi miếng vừa lành thương vừa to ra."},
	"engineer": {"en": "Bolt down a whirring turret and let it scream covering fire while you reload.", "vi": "Dựng một tháp súng kêu è è, để nó nhả đạn yểm trợ trong lúc bạn nạp đạn."},
	"builder": {"en": "Throw up a wall of scrap and bolts — nothing's getting through your handiwork.", "vi": "Dựng vội bức tường sắt vụn — chẳng kẻ nào xuyên nổi công trình của bạn."},
	"farmer": {"en": "Reap a season's bounty in a heartbeat — green growth knits every wound.", "vi": "Gặt cả mùa màng trong tích tắc — mầm xanh chữa lành vết thương cả đội."},
	"saver": {"en": "Crack the piggy bank — coins rain down and your savings buy raw muscle.", "vi": "Đập con heo đất — tiền vàng đổ xuống, khoản tiết kiệm hoá thành sức mạnh."},
	"entrepreneur": {"en": "Cash in every asset at once and turn pure profit into killing power.", "vi": "Thanh lý sạch tài sản, biến lợi nhuận thành sức sát thương thuần tuý."},
	"streamer": {"en": "Hit the GO LIVE button — the bigger the crowd, the harder your squad hits.", "vi": "Bấm nút LÊN SÓNG — càng đông người xem, cả đội càng đánh rát."},
	"curious": {"en": "Send a little drone skittering off to sniff out every lurking threat.", "vi": "Thả một chú drone nhỏ bay vòng, đánh hơi mọi mối nguy đang rình rập."},
	"baby": {"en": "A sudden growth spurt — tiny no more, you erupt into a tougher, faster brawler.", "vi": "Một cú lớn vọt bất ngờ — hết bé bỏng, bạn bùng nổ mạnh mẽ và nhanh hơn hẳn."},
	"fisherman": {"en": "Fling the net wide and haul the whole swarm into a churning vortex.", "vi": "Quăng lưới thật rộng, cuốn cả bầy địch vào xoáy nước cuộn trào."},
	"speedy": {"en": "Blink across the arena in a blue streak — too fast to touch.", "vi": "Lao vút qua đấu trường như một vệt xanh, nhanh đến mức không ai chạm nổi."},
	"diver": {"en": "Surge in like a breaking wave and sweep the swarm off your friends.", "vi": "Lao tới như sóng vỡ bờ, cuốn phăng bầy địch khỏi đồng đội."},
	"ghost": {"en": "Slip out of reality for a heartbeat — nothing can hit a ghost.", "vi": "Tan biến khỏi thực tại trong khoảnh khắc — chẳng đòn nào chạm được hồn ma."},
	"cryptid": {"en": "Melt into the shadows and reappear where no one's looking.", "vi": "Tan vào bóng tối rồi hiện ra ở nơi không ai ngờ tới."},
	"creature": {"en": "Leave a stain of rot where it walks — the air itself turns against you.", "vi": "Để lại một vũng thối rữa trên đường đi — chính bầu không khí cũng quay lưng với ngươi."},
	"explorer": {"en": "Blaze a path through the swarm and scoop up everything in your wake.", "vi": "Mở lối xuyên qua bầy địch, vơ sạch mọi thứ trên đường đi."},
	"hiker": {"en": "Catch your breath on the move and push on, stronger than before.", "vi": "Lấy lại hơi sức giữa đường rồi tiến tới, khỏe hơn lúc đầu."},
	"wounded": {"en": "Pain becomes fuel — the closer to death, the deadlier you fight.", "vi": "Cơn đau hóa thành sức mạnh — càng cận kề cái chết, đòn đánh càng hiểm."},
	"generalist": {"en": "Read the fight and bend the whole squad to meet it.", "vi": "Đọc trận đánh rồi tùy biến cả đội cho khớp tình thế."},
	"well-rounded": {"en": "No weak spot to exploit — just brace and hold the line.", "vi": "Không có điểm yếu nào để khai thác — cứ trụ vững mà giữ tuyến."},
	"vagabond": {"en": "Make do with whatever the wasteland leaves behind.", "vi": "Tận dụng bất cứ thứ gì vùng đất hoang còn sót lại."},
	"jack": {"en": "Hit the jackpot — for a moment, the whole crew rakes it in.", "vi": "Trúng độc đắc — trong chốc lát, cả đội hốt bạc."},
	"mutant": {"en": "Rewrite your own flesh into something deadlier on the spot.", "vi": "Tự cải biến cơ thể thành thứ gì đó nguy hiểm hơn ngay tức thì."},
}

# Faction AFFINITIES — having >=2 members of a faction in a co-op run grants a TEAM buff + a nerf
# (TFT-style trait with a tradeoff). Tiered: tiers[] entry whose `at` <= member count applies (2 = small,
# 3+ = larger). `pairs` = named-pair bonuses (both present → extra buff). A character can sit in multiple
# factions (draft depth). Applied team-wide at each wave start, cleared at wave end (see controller).
# Numbers are a first balance pass. Member slugs are from the 64-char set. (Source: coop affinities spec.)
const AFFINITIES := {
	"same_boat": {
		"label": "Same Boat", "label_vi": "Cùng Thuyền",
		"members": ["buccaneer", "captain", "sailor", "diver", "fisherman"],
		"tiers": [
			{"at": 2, "buff": {"stat_luck": 15, "stat_speed": 10}, "nerf": {"stat_armor": -6}},
			{"at": 3, "buff": {"stat_luck": 30, "stat_speed": 20}, "nerf": {"stat_armor": -10}},
		],
	},
	"arcane": {
		"label": "Arcane", "label_vi": "Phép Thuật",
		"members": ["mage", "apprentice", "lich", "druid", "technomage"],
		"tiers": [
			{"at": 2, "buff": {"stat_elemental_damage": 20}, "nerf": {"stat_max_hp": -8}},
			{"at": 3, "buff": {"stat_elemental_damage": 40}, "nerf": {"stat_max_hp": -14}},
		],
		"pairs": [{"a": "mage", "b": "apprentice", "buff": {"stat_xp_gain": 15}}],
	},
	"machines": {
		"label": "Machines", "label_vi": "Máy Móc",
		"members": ["engineer", "artificer", "cyborg", "golem", "technomage"],
		"tiers": [
			{"at": 2, "buff": {"stat_engineering": 12}, "nerf": {"stat_dodge": -5}},
			{"at": 3, "buff": {"stat_engineering": 24}, "nerf": {"stat_dodge": -8}},
		],
	},
	"damned": {
		"label": "The Damned", "label_vi": "Kẻ Bị Nguyền",
		"members": ["demon", "vampire", "lich", "ghost", "cryptid", "creature"],
		"tiers": [
			{"at": 2, "buff": {"stat_lifesteal": 8}, "nerf": {"stat_hp_regeneration": -3}},
			{"at": 3, "buff": {"stat_lifesteal": 15}, "nerf": {"stat_hp_regeneration": -5}},
		],
	},
	"crown_steel": {
		"label": "Crown & Steel", "label_vi": "Vương & Thép",
		"members": ["king", "knight", "gladiator", "soldier", "captain"],
		"tiers": [
			{"at": 2, "buff": {"stat_melee_damage": 15, "stat_armor": 6}, "nerf": {"stat_range": -10}},
			{"at": 3, "buff": {"stat_melee_damage": 30, "stat_armor": 12}, "nerf": {"stat_range": -16}},
		],
		"pairs": [{"a": "king", "b": "knight", "buff": {"stat_armor": 8}}],
	},
	"wild": {
		"label": "The Wild", "label_vi": "Hoang Dã",
		"members": ["wildling", "beast-master", "hunter", "ogre", "bull", "cryptid"],
		"tiers": [
			{"at": 2, "buff": {"stat_crit_chance": 8, "stat_attack_speed": 12}, "nerf": {"stat_engineering": -10}},
			{"at": 3, "buff": {"stat_crit_chance": 14, "stat_attack_speed": 22}, "nerf": {"stat_engineering": -16}},
		],
	},
	"hustlers": {
		"label": "Hustlers", "label_vi": "Con Buôn",
		"members": ["arms-dealer", "entrepreneur", "streamer", "saver", "gangster", "jack"],
		"tiers": [
			{"at": 2, "buff": {"stat_harvesting": 18}, "nerf": {"stat_damage": -6}},
			{"at": 3, "buff": {"stat_harvesting": 35}, "nerf": {"stat_damage": -10}},
		],
	},
	"caretakers": {
		"label": "The Caretakers", "label_vi": "Người Chăm Sóc",
		"members": ["doctor", "romantic", "pacifist", "lucky", "old", "chef"],
		"tiers": [
			{"at": 2, "buff": {"stat_hp_regeneration": 4}, "nerf": {"stat_damage": -6}},
			{"at": 3, "buff": {"stat_hp_regeneration": 8}, "nerf": {"stat_damage": -10}},
		],
	},
	"reckless": {
		"label": "Reckless", "label_vi": "Liều Lĩnh",
		"members": ["crazy", "masochist", "renegade", "mutant", "wounded"],
		"tiers": [
			{"at": 2, "buff": {"stat_damage": 12, "stat_attack_speed": 12}, "nerf": {"stat_max_hp": -10}},
			{"at": 3, "buff": {"stat_damage": 24, "stat_attack_speed": 22}, "nerf": {"stat_max_hp": -16}},
		],
	},
	"late_bloomers": {
		"label": "Late Bloomers", "label_vi": "Nở Muộn",
		"members": ["baby", "glutton", "hiker", "builder", "chunky", "mutant"],
		"tiers": [
			{"at": 2, "buff": {"stat_max_hp": 12, "stat_harvesting": 12}, "nerf": {"stat_damage": -6}},
			{"at": 3, "buff": {"stat_max_hp": 24, "stat_harvesting": 24}, "nerf": {"stat_damage": -10}},
		],
	},
	"drifters": {
		"label": "Drifters", "label_vi": "Lang Bạt",
		"members": ["explorer", "speedy", "vagabond", "curious", "hiker"],
		"tiers": [
			{"at": 2, "buff": {"stat_speed": 15, "stat_dodge": 5}, "nerf": {"stat_armor": -6}},
			{"at": 3, "buff": {"stat_speed": 28, "stat_dodge": 9}, "nerf": {"stat_armor": -10}},
		],
	},
}

# One distinct color per faction — drives the character-icon border + the legend swatches on the
# character-select screen, so players can spot same-faction picks at a glance.
const AFFINITY_COLORS := {
	"same_boat": [0.25, 0.55, 0.90],     # ocean blue
	"arcane": [0.72, 0.40, 0.95],        # purple
	"machines": [0.85, 0.58, 0.22],      # bronze
	"damned": [0.80, 0.18, 0.28],        # crimson
	"crown_steel": [0.93, 0.80, 0.30],   # gold
	"wild": [0.40, 0.78, 0.32],          # forest green
	"hustlers": [0.15, 0.78, 0.62],      # emerald
	"caretakers": [0.96, 0.58, 0.78],    # pink
	"reckless": [0.97, 0.42, 0.18],      # orange-red
	"late_bloomers": [0.66, 0.48, 0.30], # tan/brown
	"drifters": [0.40, 0.82, 0.93],      # sky cyan
}

# Faction display order for the legend (left column then right column).
const AFFINITY_ORDER := ["same_boat", "arcane", "machines", "damned", "crown_steel", "wild",
	"hustlers", "caretakers", "reckless", "late_bloomers", "drifters"]
