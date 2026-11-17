# Architecture

**Single reference for how the game is built and how it will grow.** Written 2026-11-16 by the technical lead pass (owner request: prepare the architecture so later sessions can continue without rediscovering the project). Status words used everywhere: **Implemented**, **Partial**, **Designed** (not built), **Not started**, **Blocked**. Related references, each the only home of its topic: product and scope `prd.md`; vision and pillars `project_spec.md`; data schema, catch model and save format `data_model.md`; art, audio and performance budget `design_direction.md`; what is done, open and next `project_status.md`; sources and licences `reference_docs.md`; history `changelog.md`; working rules `CLAUDE.md` and `.claude/rules/`.

## 1. The game in one page
Mera has two views of one world (spec 5.1). **World mode**: a top-down 2D shore the player walks (in the spirit of Stardew Valley and Night Shoal): real places drawn as areas, people to talk to, a shop, the catch log, and fishing markers at real standing positions. **Fishing mode**: first person in 3D from the cast until the fish is landed or lost. The owner decided on 2026-11-16 that the walkable world is the main game (PRD M5, which had left "static map or walkable" open). Fishing mode is built (sections 5 and 6); world mode is designed here and not started.

| Layer | Folder | Rule | State |
| --- | --- | --- | --- |
| Simulation | `game/sim/` | Pure GDScript, no Node, no `randf()`, seeded, 30 Hz fixed steps. Owns every rule | Implemented for fishing; Designed for inventory, economy, progression, quests |
| Static data | `game/data/` | JSON with `schema.json`, validated at load, every value sourced or `design_fill` | Implemented (1 spot, 3 species, 3 rigs) |
| Player data | `game/sim/save_game.gd`, `game/sim/inventory.gd`, `game/save/`, `game/core/profile.gd` | Versioned dictionary, migrations, atomic write, one writer | Implemented v2 (log, settings, last rig, bag, money field, counters); later slices Designed (`data_model.md` 12) |
| Core | `game/core/` (new) | Autoloads that own mode, data, profile and audio; the only code that changes scenes | Designed |
| Views | `game/scenes/`, `game/ui/` | Read simulation state, send input, hold no rules | Implemented for fishing; Not started for the world |
| Tests | `game/tests/` | Headless runner, every rule and every fixed bug has a test | Implemented (144 tests) |

Dependencies point one way: views -> core -> sim and data. `sim/` never imports from `scenes/` or `ui/`. Views talk down by calling methods and up by signals. There is no global event bus; the few game-wide signals live on the `Game` autoload (section 3).

## 2. Repository layout
| Path | Purpose | State |
| --- | --- | --- |
| `game/sim/` | `fishing_session`, `inventory`, `catch_model`, `wait_sim`, `fight_sim`, `fight_controller`, `fight_setup`, `why_report`, `shoal_field`, `session_conditions`, `motion_gesture`, `save_game`, `data_store`, `data_validator` | Implemented |
| `game/data/` | `schema.json`, `constants.json`, `species.json`, `spots.json`, `tackle/`, `angler.json`, `demo/` | Implemented |
| `game/scenes/fishing/` | `fishing_screen.gd` (`FishingScreen`: phases, simulations, view physics), `fishing_hud.gd` (`FishingHud`: controls, panels, raw thumb state), `fishing_overlay.gd` (`FishingOverlay`: the 2D layer) | Implemented; split 2026-11-17 (R1) |
| `game/ui/water_view.gd`, `game/ui/sea/` | The 3D fishing scene: sea and sky shaders, `Bridge3D`, `Rig3D`, `SeaMaps` | Implemented |
| `game/ui/fx/` | Screen-space motion and effects: `rod_spring`, `verlet_rope`, `angler_rig`, `cast_motion`, `fish_body`, `splash_fx`, `gull_flock`, `neighbor_anglers` | Implemented |
| `game/ui/audio/` | `sound_director` (recorded CC0 beds and one-shots), `cue_synth` | Implemented |
| `game/ui/device_motion.gd`, `device_guard.gd`, `frame_stats.gd` | Phone motion bridge, portrait guard, fps statistics | Implemented |
| `game/debug/` | Debug menu, excluded from the release export | Implemented |
| `game/scenes/water_prototype/` | First 2D water test scene; keeps the old shader | Legacy, remove after the owner agrees |
| `game/core/` | `db.gd`, `profile.gd`, `game.gd` (static holders) | Implemented (data, save, request and result); mode and world session Designed |
| `game/scenes/world/` | Top-down world: `world.tscn`, `areas/`, `actors/` | Not started |
| `game/ui/screens/` | Bag, shop, quest journal, map as pushed screens | Not started |
| `game/assets/` | Imported CC0 models and textures, one folder per asset with its licence row | Not started |

## 3. Core: modes, scenes and the hand-over between the two views (Designed)
**Core classes** (`game/core/`, Implemented 2026-11-17 as static holders rather than autoload nodes, so the headless test runner and the game reach them the same way; `Game` becomes a node when the world needs signals and a scene stack):
- `Db`: loads and validates `game/data` once (`DataStore.load_all`), exposes `Db.database()`, `Db.record(kind, id)`, `Db.constants()`, `Db.ok()` and `Db.errors`. Implemented; the fishing screen uses it.
- `Profile`: owns the save dictionary; the only writer. `Profile.open(path)`, `Profile.save`, `Profile.flush()` are Implemented. `Profile.apply(result)` (Implemented, R3) moves a `FishingResult` into the bag and the counters when the player leaves; experience and quests join it later. The catch log is still written by the fishing screen at the moment of landing, so a closed tab loses the bag entry of that session but not the log.
- `Game`: the contract. `Game.fishing_request(...)` and `Game.empty_result()` are Implemented; `FishingScreen.request`, `result()`, `leave()` and the `finished(result)` signal use them, and `scenes/main.gd` opens the fishing view over the title and takes the result back. Designed for R4: the mode (`enum Mode { TITLE, WORLD, FISHING }`), the session objects both views read (`conditions`, `shoals: ShoalField` per spot, the world clock) and the scene stack. A caller that shows 2D behind the fishing view must hide it: a canvas item covers the 3D scene (found when the title's background hid the sea).

**Scene tree at run time**: `Main` (root scene) with children `World` (kept loaded), `Fishing` (added on demand), `Ui` (a `CanvasLayer` stack for screens and toasts). Entering fishing sets `World.process_mode = PROCESS_MODE_DISABLED` and hides it; leaving reverses that. The world is not reloaded, so its state survives without serialising it.

**Contract between the views** (plain dictionaries, so tests can build them):
```
FishingRequest = { spot_id, position_id, rig, conditions, seed, neighbours: [npc_id], shoals: ShoalField }
FishingResult  = { catches: [{species_id, length_cm, weight_kg, kept}], lost: [{item_id, reason}],
                   casts, time_s, events: [{type, species_id?}] }
```
**World to fishing**: the player stands on a `FishingMarker`, presses the action button, `Game.start_fishing(request)`: 0.35 s zoom of the 2D camera towards the marker's facing with a fade, the fishing scene opens in its "looking along the shore" view (`WaterView.BRIDGE_YAW`, already built), and the view turns to the water on the cast. The ambience beds (wind, waves) keep playing through the change; only the world layers fade. **Fishing to world**: "Back" builds the `FishingResult`, `Profile.apply` moves fish to the bag and updates log, experience and quests, the world clock advances by `time_s`, the fade reverses and the player stands on the marker.

**Why the two views feel like one place**: the same `conditions` tint the world (`CanvasModulate`) and light the sea; the same `ShoalField` puts gulls over the water in the world and in the 3D view, so birds seen while walking are the birds fished under; the anglers standing at a marker in the world are the neighbours along the rail in 3D (`NeighborAnglers` seeded from `neighbours`); the marker's `facing` is the wind frame the cast already uses.

## 4. World mode: top-down 2D (Not started; design)
- **Areas**: one scene per real place, `scenes/world/areas/<spot_id>.tscn`, built from `TileMapLayer` nodes (ground, shore, props, overhead) with y-sorting. An area declares its exits, markers and NPC spawn points as nodes; `game/data/areas/<spot_id>.json` carries the sourced facts (names, coordinates of positions, links to `spots.json`). Areas load one at a time; exits change area with a fade.
- **Player**: `CharacterBody2D`, 8-direction movement at walking pace, virtual stick under the left thumb and one action button under the right (`godot-style.md`: controls pinned to the corners). `Camera2D` with limits and position smoothing. Keyboard and gamepad through `InputMap` actions for desktop testing.
- **Interaction**: one component, `Interactable` (`Area2D` with a prompt key and `interact(actor)`), reused by fishing markers, NPCs, the shop door, signs and the fish bucket. The nearest one in range owns the action button.
- **NPCs**: `Npc` node with a small state machine (idle, walk, fish, talk, trade) and a daily schedule from `game/data/npcs.json`; no behaviour-tree plugin (new dependencies need approval, and the behaviours are few).
- **Art**: a decision for the owner (see `project_status.md`, decision D1): the tile and character style, and whether to use a CC0 tileset or commissioned or generated art.
- **Performance**: 2D only, no shaders beyond the day tint, target 60 fps on the test phone; tiles in one atlas per area.

## 5. Fishing mode: first person in 3D (Implemented, with the limits listed)
**Flow**: `fishing_screen.gd` phases READY, CHARGE, FLIGHT, WAIT, FIGHT, LIFT, RESULT. Rules: `CatchModel` (staged resolve, cast), `WaitSim` (bites, strike, player-controlled retrieve and lure depth, shoal boost), `FightSim` through `FightController` (tension, drag, runs, sideways runs and side strain, jumps, player-driven landing, 90 s rule), `WhyReport` (the explanation). Controls: hold and release to cast with thumb aim; reel pad on the left; strike, drag slider and pull (with side strain) on the right; phone motion for strike, pull and jig.

**Coordinates**: the fishing world is square to the shore: x to the angler's right, z out over the water, the angler at the origin, eye 2.2 m above the water. `WaterView.project(world, height, size)` is the one mapping from that world to the screen; the 3D camera is a frustum built to match it exactly (unit test), and `WaterView.view_yaw` turns both together.

**What draws what**:
| Thing | How | State |
| --- | --- | --- |
| Sea, sky, far shore, sun, clouds | `sea.gdshader` (Gerstner mesh), `sky.gdshader`, shared `sea_sky.gdshaderinc`, ACES and glow | Implemented |
| Standing place | `Bridge3D`: deck, rail, lamps and lights, shadows, neighbours with rods | Implemented for one stage type (bridge) |
| Player's rod, reel, hands, forearms | `Rig3D`, lifted each frame from the screen-space `RodSpring` and `AnglerRig` | Implemented; hands are simple shapes (R7) |
| Line, lure, rings, splashes, fish, gulls, neighbours' lines | 2D overlay through `project()` | Implemented in 2D; 3D versions Designed (R6) |
| HUD | Godot controls built in code in `fishing_screen.gd` | Implemented |

**Designed next steps for this mode**
- *Split the screen*: `FishingHud` and `FishingOverlay` are out (R1, Implemented). Both hold a reference to the screen and read its state; the HUD calls it for what a press means. `FishingSession` (`game/sim/fishing_session.gd`, Implemented in R2, pure) owns the rule-bearing steps: context, cast, the wait and fight it starts, and the trip record. The phases stay on the screen on purpose: they follow the view's timing (lure flight, the lift, the result panel). Behaviour must not change; the existing loop tests are the guard.
- *Stages* (R5): `Bridge3D` becomes one implementation of a stage interface (`build()`, `set_light(light)`, `pose(neighbours, time)`, `tip_water(i)`, `lure_water(i, cast_m, side)`, `ready_yaw`). A position in `spots.json` names its stage (`bridge`, `quay`, `rocks`, `beach`); `WaterView` instantiates it.
- *3D fish, line, rings, gulls* (R6): fish as a mesh built from `FishBody`'s spine with per-species colour; line as a ribbon mesh through the `VerletRope` points lifted like `Rig3D` does; rings and boils as up to 8 ring uniforms in `sea.gdshader` (so the rail hides them correctly); gulls as quads in the 3D scene.
- *Presentations* (R12): the lure retrieve exists (`WaitSim` controlled mode). Float and bottom fishing are new presentations with their own small simulations feeding the same stages 1 to 4; needs `float` and `sinker` in the schema and bait data. PRD 4 lists bait and float fishing as a non-goal for the MVP: the owner decides when (decision D2).
- *Fish that can be seen coming*: only when clarity allows (`visible_at_m`); a view-only steering agent driven by `WaitSim` events, never a second source of truth.

## 6. 3D systems: assessment and rules
**What exists and is worth keeping**: the frustum camera matched to `project()`; the shared sky include that makes reflections agree with the sky; the lift technique of `Rig3D` (motion stays in tested screen space, shapes get real light); everything generated in code, so the download stays small.
**Weak points**: no asset pipeline yet (no models or textures in the repository); hands are capsules; `Bridge3D` is specific to Galata; the overlay is not depth-tested against 3D (rings can draw over the rail); night scenes are very dark; phone frame rate is measured only for the sea (58 fps, owner's phone, 2026-11-15), not for shadows, lamp lights and the 3D rig.
**Asset pipeline (Designed, R7)**: CC0 only (owner approved 2026-11-15; the tech lead's choice on 2026-11-16 is to adopt CC0 PBR textures and a CC0 rigged hand model rather than keep everything procedural, because hands and close surfaces are where procedural shapes read as fake). One folder per asset under `game/assets/3d/<name>/` with the `.glb` and textures; a row in `reference_docs.md` before the commit (`data-and-sources.md`); textures at most 1024 px, WebP, three maps per material at most; models optimised with gltf-transform (`.claude/skills/gltf-transform.md`). Needs the asset hosts on the network allowlist (decision D3).
**Budgets for the fishing view** (proposal until measured on the phone): at most 60,000 triangles, 80 draw calls, 1 shadowed directional light, 3 unshadowed omni lights, 15 MB total download at 0.5 (today: a 0.5 MB pack plus the 42 MB engine file before the host's compression).

## 7. Gameplay systems around the two views (Designed)
Each is a pure class in `game/sim/`, a data file, a slice of the save and one screen. None exists yet except the catch log.
| System | Sim class | Data | Save slice | Notes |
| --- | --- | --- | --- | --- |
| Inventory | `Inventory` (add, remove, count, fish entries): Implemented; capacity and `items.json` Designed | `items.json` (tackle pieces, lures, bait, fish as items) | `inventory.items[{id, count, meta}]` | Fish go to the bag today. A lure lost to a line break is only counted until the shop exists (R8); then it leaves a stock, so tackle choices get a cost |
| Economy | `Economy` (price of a fish from species, weight, legal size; shop prices) | `shop.json` | `money` | Sell at the fishmonger, buy at the tackle shop; no real money anywhere |
| Progression | `Progress` (experience per action, skill levels feeding the `angler` attributes the cast and hook stages already read) | `angler.json`, `progress.json` | `angler{xp, skills}` | Spot unlocks from the log (funnel steps S5, S6 in the PRD) |
| Quests | `Quests` (conditions over `FishingResult.events`, rewards) | `quests.json` | `quests{active, done}` | Given by NPCs; plain data, no scripting |
| Crafting | `Rigs` (tie a rig from parts) | `recipes.json` | uses inventory | Beyond the spec's MVP; owner decision D2 |
| Catch log | `SaveGame.record_catch` | species | `log` | Implemented |
One flow serves them all: fishing ends -> `FishingResult` -> `Profile.apply` -> each system's `apply(result)` in a fixed order (inventory, log, progress, quests) -> `Profile.changed` -> screens refresh.

## 8. AI (Partial)
- **Fish**: statistical, not agents: per species a Poisson interest rate from presence, attraction and commit (`data_model.md` 5), shoal follow-up, `ShoalField` patches; in the fight a state machine (run, rest, thrash, jump) with seeded durations. Implemented. Keep it: it is what makes outcomes explainable (pillar 2).
- **Neighbours**: `NeighborAnglers` state machine paced by the local bite rate. Implemented.
- **Gulls**: steering towards shoals (`GullFlock`). Implemented.
- **World NPCs**: state machine plus schedule (section 4). Not started.

## 9. UI, audio, platforms, performance, tests
- **UI**: touch first, landscape, 1280x720 design space expanded to the screen, controls at the corners, minimum touch size 96 px, every string through `translations.csv` (en, tr, es), colour never the only signal. Screens to add are pushed on a `Ui` stack owned by `Game`: bag, shop, journal, map; one theme resource for all (today the controls use the default theme with overrides in code).
- **Audio**: `SoundDirector` (wind and wave beds from conditions, reel and drag from line speed, tension creak, one-shots) is Implemented for fishing. Designed: move it under `Game` so beds continue across the mode change, add buses (ambience, effects, interface), world layers per area and footsteps by surface, at most 12 voices. Sources stay CC0 with a row in `reference_docs.md`.
- **Web** (Implemented): GL Compatibility, single thread, no extensions, save in IndexedDB, motion permission asked inside a real tap on iPhone Safari, release and debug builds on GitHub Pages. **iOS and Android** (Not started): same project and renderer; work to do: safe-area insets, haptics, store builds and signing (release steps, owner approval), sensors through `Input` (already abstracted in `device_motion.gd`).
- **Performance**: budgets in `design_direction.md` 2 and section 6 here; measure on the owner's phone with the debug menu's fps line before and after every visual feature; the debug "water detail" switch isolates the sea's extras and glow.
- **Tests**: unit tests for every rule in `sim/`, data validation tests, headless flow tests of the fishing screen, placeholder checks of every translated string, export-setting guards, and a played pass in a real browser with Playwright after each visual or gameplay change (`game-studios.md`). New systems follow the same pattern: write the rule's test first, add a test for every bug before fixing it.

## 10. Technical decisions (record)
| Date | Decision | Why |
| --- | --- | --- |
| 2026-11-11 | JSON data with a schema and a GDScript validator | Readable diffs, no dependency (`data_model.md` 1) |
| 2026-11-12 | Own headless test runner, no GUT plugin | Plugins need approval; the runner is 40 lines |
| 2026-11-14 | Godot stays; no Three.js or Rapier.js | Owner; an engine change would restart the work |
| 2026-11-15 | Fishing view moves to real 3D inside Godot, web target kept (option A) | Owner asked for photorealism; the phone browser sets the ceiling |
| 2026-11-15 | No anonymous counters | Owner (`counters_proposal.md`) |
| 2026-11-16 | Motion stays in screen space, 3D shapes are lifted from it | Keeps 140 tests of motion valid and the overlay aligned |
| 2026-11-16 | Fishing world is square to the shore; the view turns (along the shore when ready, to the water to cast) | Owner: the cast should not go where the neighbours fish; first the scene, then a first-person cast |
| 2026-11-16 | Walkable top-down world is the main game (PRD M5 decided) | Owner |
| 2026-11-16 | Three core classes (`Db`, `Profile`, `Game`), world kept loaded while fishing | Smallest structure that carries state between the views |
| 2026-11-17 | The core classes are static holders, not autoload nodes | The headless test runner starts from a script, so tests and the game must reach them the same way |
| 2026-11-16 | CC0 PBR textures and a CC0 hand model will be adopted | Tech lead's call at the owner's request; procedural hands read as fake |

## 11. Build decisions (2026-11-11 onwards)
- **Engine**: Godot 4.4.1, pinned in `.godot-version` and read by CI and the cloud setup script.
- **Renderer**: GL Compatibility (required for web).
- **Display**: 1280×720 design space, `canvas_items` stretch, `expand` aspect, landscape only.
- **Web export**: single-threaded (`variant/thread_support=false`), no GDExtension. Tests guard these settings.
- **Tests**: own minimal headless runner (`game/tests/run_tests.gd`). The GUT plugin from spec 7.9 is not installed because new plugins need the owner's approval.
- **Export type on Pages**: release export at `/`, and the same release template with the `mera_debug` feature tag at `/debug/` (debug menu).

## 12. Implementation notes by date (history, newest first inside each paragraph group)
See `data_model.md`. JSON files under `game/data/` with `schema.json` and `constants.json`; `game/sim/data_validator.gd` and `data_store.gd` load and validate them (errors returned, the caller decides how loudly to fail); `game/sim/catch_model.gd` holds the staged catch resolution as pure functions (no nodes, no globals, no randomness). `game/sim/fight_sim.gd` is the real-time fight: a `RefCounted` object stepped at a fixed 30 Hz with the player's input (`reel`, `rod`, `drag_kg`), seeded, returning a snapshot for the scene to draw; the scene accumulates frame time and calls `step` as many times as needed, so the simulation does not depend on the frame rate. Tests use illustrative fixtures in `game/tests/fixtures/`, excluded from the export. Neighbours and line (2026-11-15): `game/ui/fx/neighbor_anglers.gd` (seeded state machine per person: idle, nibble, fight, lift, recast; drawn behind the rail; pace set from the player's median wait) and the thread-like line in `fishing_screen.gd` `_draw_line`. Gestures: a flick strikes only with contact (a nibble within 1.2 s or a take), otherwise it jigs.

Why view and settings (2026-11-15): `game/sim/why_report.gd` turns `CatchModel.resolve` numbers and the fight's stats into translation keys with arguments (no text in the sim); the fishing screen translates and shows them. `SaveGame.settings_of` / `set_setting` hold the player settings (volume, `motion_sens`, `motion_flip`), applied to the audio bus, `MotionGesture.sensitivity` and `DeviceMotion.set_flip`.

Cast and rig (2026-11-15): `game/ui/fx/cast_motion.gd` (rod swing spring, line pay-out, thumb aim mapping) and `game/ui/fx/angler_rig.gd` (rod, reel and hands drawing, reel inertia) are visual only; the distance still comes from `CatchModel.cast`. `DeviceMotion` asks iPhone Safari for motion permission from a JavaScript touch listener.

View physics and motion input (2026-11-14): `game/ui/fx/rod_spring.gd` (rod), `game/ui/fx/verlet_rope.gd` (line), `game/sim/motion_gesture.gd` (pure gesture rules, unit-tested), `game/ui/device_motion.gd` (sensor bridge; web via JavaScriptBridge, native via Input). Rod and line are visual only; the catch outcome still comes from `WaitSim` and `FightSim`, which receive the motion as ordinary input (`strike`, `rod`, `jig`).

Retrieve control and conditions (2026-11-15): `WaitSim` has a controlled mode (input `reel` 0..1) in which reel effort sets the retrieve speed and the live lure depth (`depth_m`) that feed the catch model; without `reel` it keeps the constant retrieve. `FightSim` gains line from rod pull or reel while the drag holds. `game/sim/session_conditions.gd` (pure) derives slot, month and a seeded wind from the phone's clock; the screen uses it only when a save path is set.

3D rig (2026-11-16): `game/ui/sea/rig_3d.gd` draws the player's rod, reel, hands and forearms as meshes under `WaterView`; `AnglerRig` keeps only the motion (smoothed curve, crank inertia, spool) and `RodSpring` the bend, both still in screen space; `Rig3D.pose()` lifts their points to a depth that grows along the rod (0.75 m at the butt to 2.6 m at the tip) and sizes parts in the old screen pixels.

Shoals and bridge (2026-11-16): `game/sim/shoal_field.gd` (pure, seeded) holds the bait shoals; `WaitSim` multiplies interest by `shoals.boost_at(lure x, distance)` when a field is set; `game/ui/fx/gull_flock.gd` (visual) steers gulls over them. `game/ui/sea/bridge_3d.gd` builds the deck, rail, lamps (two `OmniLight3D`) and the neighbours in 3D under `WaterView`; `NeighborAnglers` keeps their behaviour and draws only lines and fish (`draw_lines`) from the projected 3D rod tips. The sun light casts shadows (orthogonal, 40 m).

3D sea (2026-11-15): `game/ui/water_view.gd` now builds a 3D scene under the fishing screen: `WorldEnvironment` (sky `game/ui/sea/sky.gdshader`, ACES, glow), a `DirectionalLight3D` for later 3D objects, the sea mesh (`SeaMaps.build_grid`, shader `game/ui/sea/sea.gdshader`) and a frustum `Camera3D` whose projection equals `WaterView.project()`. Sky and sea share `sea_sky.gdshaderinc`, so reflections match the sky. The sky shader uses no `TIME`, so reflections are not re-rendered each frame. `game/ui/sea/sea_maps.gd` makes the ripple normal map and the cloud and noise map from `FastNoiseLite` (seeded). The water prototype scene keeps the old 2D shader.

Fight additions (2026-11-15): `FightSim` also simulates the fish's sideways position (`side_m`, input `steer`), jumps (`jumping`) and a player-driven landing (`lift`, `kicking`); the screen only draws them and sends the thumb's sideways position on the Pull button as `steer` (`FightController.steer_from_pad`).

Fishing loop (2026-11-13): `game/scenes/fishing/fishing_screen.gd` runs ready, cast (power swing), lure flight, wait (`game/sim/wait_sim.gd`), strike, fight (`FightController`), result and catch log; it holds no rules. `game/sim/save_game.gd` is the versioned save as pure data (migration and records unit-tested); `game/save/save_file.gd` writes it to `user://save.json` (IndexedDB on the web, nothing leaves the device) through a temporary file. `game/ui/fx/fish_body.gd` draws the fish near the shore (steering head, tail wave per fight state, drawn at twice its size). `game/ui/audio/cue_synth.gd` generates the nibble, take and landed cues in code. `game/debug/debug_menu.gd` is loaded only when `OS.is_debug_build()` or the `mera_debug` feature tag is set; it changes slot, wind, clarity, position and rig, forces a bite by species and size, and shows the stage numbers and frame-rate figures. The release preset excludes `debug/*`; the "Web Debug" preset (feature tag `mera_debug`) is exported to `build/web/debug/` and deployed at `/debug/` on Pages; CI checks that the release pck has no debug menu. `game/ui/audio/sound_director.gd` plays the recorded CC0 sounds in `game/audio/`.

Fight screen: `game/sim/fight_controller.gd` wraps `FightSim` for the scene (accumulates frame time into fixed ticks, hides fish energy from the HUD, maps pad / slider / button input to `reel`, `rod`, `drag_kg`); `fight_setup.gd` builds the context from a database; `game/scenes/fight/fight_screen.gd` only draws state and sends input; `game/ui/water_view.gd` is the water control. The fishing screen reads the real data in `game/data/` (the Galata Bridge); `game/data/demo/` stays for tests. Raw touch events are handled on the pull button because a second finger does not emulate a mouse.

## CI (`.github/workflows/ci.yml`)
`changelog` (PRs only: code changed needs `docs/changelog.md` changed) and `build` (import, unit tests, web export, uploaded as Pages artifact) → `deploy` (only on push to `main`, GitHub Pages). Godot binary and web templates are downloaded from the official `godotengine/godot-builds` releases and cached by version.

## Cloud environment
`scripts/cloud_env_setup.sh` installs the same Godot version and web templates into a cloud session. Paste its contents into the environment's Setup script field (environment menu in the session title bar → Edit). The environment's network access must allow `github.com`, `objects.githubusercontent.com` and `release-assets.githubusercontent.com`; package registries alone are not enough.
