# Contributing

Thanks for looking. This is a Godot 3.x GDScript mod for Brotato, loaded by Godot Mod Loader 6.x.
There is no build system beyond a shell script and no test suite — everything is verified by
launching the game and reading the log, so a good bug report and a small, focused PR are worth a lot
here.

## Reporting a bug

Open an issue using the templates in [`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE/) — the bug
template asks for exactly what is needed. Two things matter more than anything else:

**1. Attach the Godot log.** Mod errors show up there and almost nowhere else:

| OS | Path |
|---|---|
| macOS | `~/Library/Application Support/Brotato/logs/godot.log` |
| Windows | `%APPDATA%\Brotato\logs\godot.log` |
| Linux | `~/.local/share/Brotato/logs/godot.log` |

The mod prints `[Synergies] loaded v<version>` on start and `[Synergies] CAST place=… char=… tier=…`
on every cast, so the log usually shows immediately whether the cast fired and for which player.

**2. If it happened in co-op, say exactly which input device each player used.** Local keyboard + one
pad? Two Xbox pads? An Xbox pad and a PlayStation pad? Steam Remote Play Together? The mapping from a
firing device to a co-op player slot is the most fragile part of this mod — a bug there shows up as
"player 2's button does nothing" or "my button fires player 1's skill", and it reproduces only with
the same device combination. Include the mod version (shown in the HUD watermark and the mod list),
the Brotato version, the ModLoader version, and any other mods you have enabled.

## Development setup

1. Clone the repo. You need `bash` and `zip` to build; [Bun](https://bun.sh) with `sharp` only if you
   touch the scripts in `tools/`.
2. **Get the third-party VFX pack.** *Vivid Motion 23 — Universal Status Effects* is not in this
   repository and cannot be redistributed here. Obtain it yourself and place it at
   `mods-unpacked/tato-Synergies/assets/vfx/Vivid_Motion_23_ Universal_Status_Effects/`, keeping the
   pack's own folder layout. Without it everything still builds and runs — the spritesheet status
   effects just do not render — so it is optional unless you are working on those.
3. Brotato's shipped build loads mods **only** from the Steam Workshop content directory. You need
   the mod published and subscribed once so its Workshop folder exists; `sync-to-mac.sh` then
   overwrites the downloaded zip in place.

## Build and test loop

```bash
./build-zip.sh     # dist/tato-Synergies.zip — TEST build
./sync-to-mac.sh   # build + copy into the local Steam Workshop item folder
```

Then relaunch Brotato and read the log. The default (test) build flips `TEST_MODE := true` in
`config.gd` before zipping and restores the file afterwards, which makes iteration bearable: skills
unlock at level 1, cooldowns drop to ~5% of the wave, faction traits activate with a single member,
buffs last 20s so you can pause and read the stat panel, a gating diagnostic prints once a second,
and the solo-skills toggle appears in Options → Accessibility. `BUILD_RELEASE=1 ./build-zip.sh`
produces the real thing.

`sync-to-mac.sh` is macOS-flavoured; on Linux/Windows set `WS_DIR` to your Workshop item folder.

## GDScript house rules

These are not style preferences — most of them are parse errors or silent breakage.

- **TAB indentation only.** Mixing spaces into GDScript is a parse error, and a parse error in any
  file takes the whole mod down at load.
- **Do not use GDScript builtin names as identifiers.** `var sign`, `var range`, `var min` and
  friends are parse errors. When a name collides, prefix or rename it.
- **Watch `:=` type inference.** GDScript 3.x cannot always infer a type through a property access on
  a call result — `var x := get_tree().paused` is a parse error. Use plain `=` there. There is a
  comment marking exactly this trap in `lib/settings_panel.gd`.
- **UI is built in code, never in `.tscn`.** Every panel, HUD and injected menu control is
  constructed node by node in GDScript, styled by copying fonts and themes off the game's own nodes.
  Keep the game node paths as named constants at the top of the file, with a note on how they were
  verified.
- **Mod PNGs cannot be `load()`ed.** They are never import-cooked, so read the bytes and decode with
  `Image.load_png_from_buffer` (see `skill_hud._icon_for` and `vfx/sprite_vfx._load_sheet`), and
  cache the result.
- **Invalidate the stat cache after writing a stat.** The game caches computed stats; a buff written
  into `RunData.get_player_effects()` without invalidating the cache silently does nothing.
- **Bump the version on every change.** `MOD_VERSION` in `config.gd` and `version_number` in
  `manifest.json` must always match — the version is shown in the HUD watermark, so an in-game glance
  confirms which build is loaded. Semver:
  - **patch** — a small fix or tweak, no new capability;
  - **minor** — a new feature or capability;
  - **major** — a breaking change (anything that stops the mod working correctly against what was
    there before, or requires a coordinated change outside this repo).

## Adding or changing a skill

All skill content lives in `config.gd`. A skill is one entry in the `SKILLS` dictionary, keyed by the
character's slug (the same slug used for `assets/skills/<slug>.png`). The mechanical shape:

```gdscript
"engineer": {
    "name": "Deploy Turret",          # shown on the cards and in the Codex
    "role": ROLE_LATE,                # one of the ROLE_* constants
    "template": TMPL_SUMMON,          # which _cast_* handler runs
    "cooldown_class": "slow",         # "fast" | "normal" (default) | "slow"
    # template-specific fields, each with an optional <field>_per_tier companion:
    "sprite": "res://entities/structures/turret/builder/builder_turret_4.png",
    "shot": "beam", "shot_color": [1.0, 0.62, 0.2],
    "interval": 0.9, "range": 560.0, "range_per_tier": 50.0,
    "damage": 16, "damage_per_tier": 9,
    "life": 6.0, "life_per_tier": 1.0,
    # riders (optional, work on top of any template):
    "duration": 5.0, "dur_per_tier": 0.50,
    "stats": {"stat_engineering": 15, "stat_range": 10},
    "stats_per_tier": {"stat_engineering": 6, "stat_range": 4},
},
```

Every number scales as `value(T) = base + (T-1) * per_tier` for tiers 1..`MAX_TIER`, and the
character-select card renders the T1→T5 range from those two fields — so if you add a tunable, add
its `_per_tier` companion too. The header comment above `SKILLS` documents the fields each template
and rider accepts; read it before inventing a new key.

To add a skill:

1. Add the entry to `SKILLS`, plus a one-line `SKILL_FLAVOR` entry (`en` and, if you can, `vi`).
2. Reuse an existing `template` if at all possible. If you genuinely need a new one, declare a
   `TMPL_*` constant, document its fields in the header comment, add a `_cast_<name>` handler in
   `lib/synergies_controller.gd`, and wire it into the `if/elif` chain in `_cast_skill` — that
   function is the single dispatch point, and an unhandled template just logs
   `unknown template '…'` and does nothing.
3. If the effect leaves anything behind (a zone, a summon, a frozen enemy, a modified stat), make
   sure it is tracked in one of the controller's `_active_*` / `_tick_*` lists and torn down by
   `_expire_all_buffs` / `_clear_wave_effects`, so it cannot leak into the shop or the next wave.
4. Add the icon at `assets/skills/<slug>.png` (256×256). `SKILL-ICON-PROMPTS.md` holds the prompts
   used for the existing 64, and `tools/circle-mask-icons.ts` cuts a new one to the same transparent
   circle.

Changing a character's faction membership means editing `AFFINITIES` in the same file; each faction
also needs an entry in `AFFINITY_COLORS` and `AFFINITY_ORDER`.

## Verifying your change

There are no automated tests. Verification means: build, sync, launch the game, and read the log.
A useful pass covers at least:

- the mod loads (`[Synergies] loaded v<version>` with no parse errors above it);
- the skill fires — the `CAST` line appears with the right place, character and tier;
- the effect actually happens on screen and the numbers move in the pause-screen stat panel
  (`TEST_MODE`'s 20-second buffs exist for exactly this);
- it is cleaned up: the buff expires, and nothing survives into the shop or the next wave;
- in co-op, both players' triggers route to their own skills.

## Pull requests

Keep them small and focused on one thing. In the description, say **how you tested it in-game** —
solo or co-op, which devices, which characters, what you saw in the log. Include the version bump.
Do not reformat or refactor code the change does not need; if you spot another problem, open an issue
for it.

By contributing you agree that your contribution is licensed under this repository's licences: MIT
for code ([LICENSE](LICENSE)) and CC BY 4.0 for original art ([LICENSE-ASSETS](LICENSE-ASSETS)).
