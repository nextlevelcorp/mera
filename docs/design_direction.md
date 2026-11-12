# Design direction: performance, art and audio

**Status:** Proposed (phase 2, Design), 2026-11-12. **Decider:** the owner. Nothing here is decided until the owner answers section 6.

Inputs: `project_spec.md` 5.1, 6.1, 6.3, 7.8; `prd.md` (goal 5, F1, F8, F11, F17, F18); `data_model.md`. This document covers what the PRD left to phase 2: frame-rate target and test phone, touch-target sizes, art direction, audio direction, and the water prototype the spec requires before the art is locked.

## 1. What was measured, and what could not be

| Measurement (2026-11-12) | Result | What it does and does not show |
| --- | --- | --- |
| Web build size (release export, engine only plus 54 KB of game) | `index.wasm` 43.7 MB raw, **9.4 MB with gzip -9**; `index.js` 0.3 MB | The first visit downloads about 9-10 MB if the host compresses `.wasm`. Whether GitHub Pages does was not checked from this environment |
| Real-time fight step (`FightSim.step`) | **4.8 microseconds per tick** on a server CPU (Xeon 2.1 GHz, native headless build) | The simulation is not the risk: 30 ticks a second cost about 0.15 ms here. A phone running WebAssembly will be slower by a factor that was not measured |
| Full catch resolution (`CatchModel.resolve`) | 39 microseconds per call, same machine | Called a few times per cast; negligible |
| Frame rate on a phone | **Not measured** | No phone is reachable from this environment. Headless Chromium here renders with software GL, so its frame rate says nothing about a phone |

Conclusion: rendering, and above all the water, decides the frame rate (spec 6.3 says the same). The numbers below are targets to test, not results.

## 2. Performance budget (proposal)

| Item | Proposal | Reason |
| --- | --- | --- |
| Frame rate | **Floor 30 fps, goal 60 fps** on the test phone, measured in the first-person fishing view during a fight | 30 fps is the least that keeps a tension bar readable; 60 is the browser's normal refresh. A feature that drops the test phone under 30 fps is rejected or simplified |
| How it is measured | Debug menu overlay: average fps and the worst 1% of frames over a 60 s fight, before and after any visual feature, noted in the pull request | CLAUDE.md: measure before and after any visual feature |
| Simulation | Fixed 30 Hz step, independent of the frame rate (built: `FightSim`) | A slow frame must not change the outcome of a fight |
| Download | First load under 12 MB compressed; check that the host compresses `.wasm`, otherwise 44 MB | A 2-minute first cast (PRD goal 3) is not reachable on mobile data with a 44 MB download |
| Render resolution | Water and world drawn at **640x360 and scaled up**, UI at full resolution | A quarter of the pixels to shade. This is an inference to be tested in the water prototype, not a measured gain |
| Test phone | **The owner's own phone as device 1**; a second, older Android phone if one is available | A named device the owner can hold is worth more than a specification sheet. Model and year are recorded here once known (section 6) |

## 3. Art direction: options

The spec asks for top-down 2D "in the spirit of Stardew Valley and Nightshoal" and a first-person water view with realistic waves, in a single-threaded web build. One person produces all of it with free tools and CC0 sources.

| | A. Low-resolution pixel look for both views (recommended) | B. Flat vector shapes | C. Painted or photo-based realism |
| --- | --- | --- | --- |
| Top-down map | Pixel art, matches the spec's reference games | Clean, map-like | Painted or traced from imagery |
| Water view | Shader water drawn at 640x360 and scaled up; stylised but physically driven (wind, chop, clarity from the simulation) | Shader water at full resolution with flat colours | High-detail water and sky |
| Fits the spec | Yes for the top-down view; the water is stylised, not photoreal | Partly (not the Stardew spirit) | Yes for realism |
| Performance risk | Lowest: fewest pixels shaded | Medium | Highest |
| Production effort for one person | Medium: pixel art is slow but small; Krita or free pixel tools | Lowest | Highest; source and licence checks for every image |
| Readable gameplay (pillar 2) | Good if text and gauges stay at full resolution | Best | Depends on contrast |
| Honest weakness | "Realistic" then means behaviour, not looks; some anglers may expect photoreal | Looks generic | Likely to miss the frame-rate floor and the schedule |

**Recommendation: A.** It is the cheapest way to meet the frame-rate floor, it matches the spec's own reference for the top-down view, and it puts the realism where the research says anglers judge it: in fight length, line logic and lure behaviour, not in the picture. The risk is taste: if the owner wants the water to look real, option A is the wrong choice and option C needs a longer schedule.

Rules that hold for any option:
- Line, rod tip, surface rings, splashes and the tension gauge are drawn at full resolution with strong contrast; tension is never shown by colour alone (PRD F8, F18).
- The fish is not drawn during the wait and the early fight (spec 5.1); it appears inside the visibility distance the simulation computes.
- Motion follows the living-shore pillar: the line as a spring-mass chain, splashes as particles, swell as oscillation, wind and current from noise. Each is added only with a before-and-after frame-rate note.
- Text uses the engine's default font in 0.1 (it rendered Turkish and Spanish characters correctly in the skeleton build). A font change needs its licence recorded.
- Touch targets: at least 96 px in the 720-px-high design space for the reel and drag controls, pinned to the screen corners. The physical size is checked on the test phone; 96 px is a starting value, not a tested one.

## 4. Audio direction (proposal)

| Layer | Content | Source |
| --- | --- | --- |
| Ambient (calm) | Waves on the structure, wind scaled by the day's wind, distant harbour | **The owner's own recordings at the spot** (phone recording is enough) or Freesound files under CC0 only |
| Wait | Sparse: line in the wind, small splashes for rings | Generated or CC0 |
| Bite | One sharp, dry cue per take; softer ticks for nibbles | Generated (sfxr class tools) |
| Fight | Reel drag sound whose pitch follows the line-out speed from `FightSim`; rod creak with tension; splash on thrash | Own recording of a real reel, or CC0 |
| Landing and log | Short, warm confirmation | Generated |

Rules: sound starts after the first tap (browser rule, PRD F11). Every sound cue has a visual twin. Vibration is an Android extra with the same timing as the sound cue. No music in 0.1 (cost and licence work without a clear gain); revisit for the MVP. Every file is listed in `reference_docs.md` with source and licence before it is committed; CC-BY files are avoided in 0.1 so that no credits screen is needed yet.

Own recordings are the recommended source: they are licence-free, they are of the real place (pillar 1), and the owner fishes there anyway.

## 5. Water prototype (required by spec 6.3 before the art is locked)

Scope: one first-person scene with shader water driven by three simulation values (chop, clarity, light), a line with a float or lure, and the fps overlay. No gameplay.

Pass criteria, set before building:
1. At least 30 fps average and no worse than 24 fps in the worst 1% of frames on the test phone, in landscape, for 60 s.
2. Chop 0, 0.5 and 1.0 are visibly different to the owner without labels.
3. Clear and murky water are visibly different, and the visibility distance matches what the simulation reports.
4. If criterion 1 fails at 640x360, the fallbacks are tried in this order: fewer wave layers, lower resolution, a non-shader animated texture. The art direction is locked only after one of them passes.

## 6. Decisions needed from the owner

| # | Question | Recommendation |
| --- | --- | --- |
| 1 | Which phone is the test phone (model and year)? Is an older Android phone available as a second device? | The owner's own phone as device 1 |
| 2 | Frame-rate floor 30 fps, goal 60 fps? | Yes |
| 3 | Art direction A, B or C? | A |
| 4 | Will the owner record ambient and reel sounds at the spot? | Yes; otherwise CC0 files only |
| 5 | No music in 0.1? | Agree |

## 7. Out of scope here

Colour palette, character and tackle sprites, the exact screen layout of the rig editor and the log, and store art. They follow the art decision and the water prototype.
