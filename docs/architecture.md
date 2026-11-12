# Architecture

Status: phase 3 skeleton. Only the empty web build exists; there is no gameplay code.

## Repository layout
See `project_spec.md` 6.5. `game/` is the Godot 4.4 project:

| Path | Purpose | State |
| --- | --- | --- |
| `game/scenes/` | Scenes; `main.tscn` is the entry scene | skeleton |
| `game/ui/` | UI scripts; `device_guard.gd` shows the "turn your phone" screen in portrait | skeleton |
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
- **Export type on Pages**: release export. A debug menu will be gated by a feature tag later.

## Data layer and simulation (first parts built)
See `data_model.md`. JSON files under `game/data/` with `schema.json` and `constants.json`; `game/sim/data_validator.gd` and `data_store.gd` load and validate them (errors returned, the caller decides how loudly to fail); `game/sim/catch_model.gd` holds the staged catch resolution as pure functions (no nodes, no globals, no randomness). `game/sim/fight_sim.gd` is the real-time fight: a `RefCounted` object stepped at a fixed 30 Hz with the player's input (`reel`, `rod`, `drag_kg`), seeded, returning a snapshot for the scene to draw; the scene accumulates frame time and calls `step` as many times as needed, so the simulation does not depend on the frame rate. Tests use illustrative fixtures in `game/tests/fixtures/`, excluded from the export. Not wired into the scenes yet.

## CI (`.github/workflows/ci.yml`)
`changelog` (PRs only: code changed needs `docs/changelog.md` changed) and `build` (import, unit tests, web export, uploaded as Pages artifact) → `deploy` (only on push to `main`, GitHub Pages). Godot binary and web templates are downloaded from the official `godotengine/godot-builds` releases and cached by version.

## Cloud environment
`scripts/cloud_env_setup.sh` installs the same Godot version and web templates into a cloud session. Paste its contents into the environment's Setup script field (environment menu in the session title bar → Edit). The environment's network access must allow `github.com`, `objects.githubusercontent.com` and `release-assets.githubusercontent.com`; package registries alone are not enough.
