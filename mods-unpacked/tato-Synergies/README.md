# tato-Synergies — Co-op Synergies (Brotato mod)

Turns Brotato co-op into a team game: per-character **active skills**, faction **affinities**
(buff + nerf when related characters team up), and a **role** read on every character.

**Status:** v0.5.0 — **skill framework vertical slice.** Per-player input routing PASSED (maps the
firing device → co-op player via Brotato's per-device `ui_accept_<token>` bindings). Now a per-player
skill **state machine**: unlock at level N, tier from level, **cooldown = a fraction of the wave's
duration** (read off the game's `EndWaveTimer`), fires **wave-only**, routed to the firing player.
The cast is a placeholder (HUD flash + log + cooldown) until per-skill effects are wired. A lean
cooldown HUD lives in `lib/skill_hud.gd`. **`config.gd TEST_MODE`** = fast cooldown (~5% of wave) +
skills usable from level 1, so it's testable without grinding (flip off for real play).
**To test:** `./sync-to-mac.sh` (or `./build-zip.sh`), start a co-op run, press the trigger (bottom pad
button / `R`) during a WAVE and watch each player's cooldown count down. See the umbrella design at
`docs/superpowers/specs/2026-06-15-coop-depth-skills-affinities-roles-design.md` and the content
draft `…/2026-06-15-coop-content-skills-affinities-draft.md`.

## Layout
- `manifest.json` — ModLoader manifest (id `tato-Synergies`, MLloader 6.x).
- `config.gd` — framework constants (unlock level, upgrade cadence, cooldown fraction, input keys, role tags) + the (empty) `SKILLS` / `AFFINITIES` registries to fill in.
- `mod_main.gd` — ModLoader entry; spawns the controller.
- `lib/synergies_controller.gd` — persistent controller; holds the per-player input-routing spike (`_place_for` device→place mapping).
- `assets/skills/<slug>.png` — per-character skill icons (256×256, masked to a transparent circle).

## Build / dev (from repo root)
- `./build-zip.sh` → `dist/tato-Synergies.zip`
- `./sync-to-mac.sh` → build + sync into the local Steam Workshop folder (needs the mod published + subscribed once; set `WS_ITEM`)
- Publish: `./publish-steamcmd.sh <steam_account>` (needs `thumbnail.png`)
- Mask new icons: `bun run tools/circle-mask-icons.ts mods-unpacked/tato-Synergies/assets/skills`

**Version bump:** any mod edit bumps `MOD_VERSION` (config.gd) AND `version_number` (manifest.json) — keep them in sync.
