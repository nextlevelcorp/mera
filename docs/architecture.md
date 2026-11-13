# Architecture

Status: phase 3 skeleton. Only the empty web build exists; there is no gameplay code.

## Repository layout
See `project_spec.md` 6.5. `game/` is the Godot 4.4 project:

| Path | Purpose | State |
| --- | --- | --- |
| `game/scenes/` | Scenes; `main.tscn` is the entry scene; `water_prototype/` is a temporary test scene (shader water in a half-resolution SubViewport, full-resolution overlay) | skeleton and prototype |
| `game/ui/` | UI scripts; `device_guard.gd` shows the "turn your phone" screen in portrait; `frame_stats.gd` computes average and worst-1% fps | skeleton; `fx/verlet_rope.gd` (line as a point-mass chain) and `fx/splash_fx.gd` (droplets and rings): visual only, seeded |
| `game/locale/` | `translations.csv` (en, tr, es) | skeleton |
| `game/tests/` | Headless tests, run by `run_tests.gd` | skeleton |
| `game/data/` | `schema.json`, `constants.json`; real species, spot and tackle data not written yet | schema and constants |
| `game/sim/` | Data validator, loader, catch model | first parts |

## Decisions
- **Engine**: Godot 4.4.1, pinned in `.godot-version` and read by CI and the cloud setup script.
- **Renderer**: GL Compatibility (required for web).
- **Display**: 1280×720 design space, `canvas_items` stretch, `expand` aspect, landscape only.
- **Web export**: single-threaded (`variant/thread_support=false`), no GDExtension. Tests guard these settings.
- **Tests**: own minimal headless runner (`game/tests/run_tests.gd`). The GUT plugin from spec 7.9 is not installed because new plugins need the owner's approval.
- **Export type on Pages**: release export at `/`, and the same release template with the `mera_debug` feature tag at `/debug/` (debug menu).

## Data layer and simulation (first parts built)
See `data_model.md`. JSON files under `game/data/` with `schema.json` and `constants.json`; `game/sim/data_validator.gd` and `data_store.gd` load and validate them (errors returned, the caller decides how loudly to fail); `game/sim/catch_model.gd` holds the staged catch resolution as pure functions (no nodes, no globals, no randomness). `game/sim/fight_sim.gd` is the real-time fight: a `RefCounted` object stepped at a fixed 30 Hz with the player's input (`reel`, `rod`, `drag_kg`), seeded, returning a snapshot for the scene to draw; the scene accumulates frame time and calls `step` as many times as needed, so the simulation does not depend on the frame rate. Tests use illustrative fixtures in `game/tests/fixtures/`, excluded from the export. Fishing loop (2026-11-13): `game/scenes/fishing/fishing_screen.gd` runs ready, cast (power swing), lure flight, wait (`game/sim/wait_sim.gd`), strike, fight (`FightController`), result and catch log; it holds no rules. `game/sim/save_game.gd` is the versioned save as pure data (migration and records unit-tested); `game/save/save_file.gd` writes it to `user://save.json` (IndexedDB on the web, nothing leaves the device) through a temporary file. `game/ui/fx/fish_body.gd` draws the fish near the shore (steering head, tail wave per fight state, drawn at twice its size). `game/ui/audio/cue_synth.gd` generates the nibble, take and landed cues in code. `game/debug/debug_menu.gd` is loaded only when `OS.is_debug_build()` or the `mera_debug` feature tag is set; it changes slot, wind, clarity, position and rig, forces a bite by species and size, and shows the stage numbers and frame-rate figures. The release preset excludes `debug/*`; the "Web Debug" preset (feature tag `mera_debug`) is exported to `build/web/debug/` and deployed at `/debug/` on Pages; CI checks that the release pck has no debug menu. `game/ui/audio/sound_director.gd` plays the recorded CC0 sounds in `game/audio/`.

Fight screen: `game/sim/fight_controller.gd` wraps `FightSim` for the scene (accumulates frame time into fixed ticks, hides fish energy from the HUD, maps pad / slider / button input to `reel`, `rod`, `drag_kg`); `fight_setup.gd` builds the context from a database; `game/scenes/fight/fight_screen.gd` only draws state and sends input; `game/ui/water_view.gd` is the water control. The fight reads demo data from `game/data/demo/` (design fills) until real spot data exists. Raw touch events are handled on the pull button because a second finger does not emulate a mouse.

## CI (`.github/workflows/ci.yml`)
`changelog` (PRs only: code changed needs `docs/changelog.md` changed) and `build` (import, unit tests, web export, uploaded as Pages artifact) → `deploy` (only on push to `main`, GitHub Pages). Godot binary and web templates are downloaded from the official `godotengine/godot-builds` releases and cached by version.

## Cloud environment
`scripts/cloud_env_setup.sh` installs the same Godot version and web templates into a cloud session. Paste its contents into the environment's Setup script field (environment menu in the session title bar → Edit). The environment's network access must allow `github.com`, `objects.githubusercontent.com` and `release-assets.githubusercontent.com`; package registries alone are not enough.
