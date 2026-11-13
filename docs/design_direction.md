# Design direction: performance, art and audio

**Status:** Decided by the owner on 2026-11-12 (section 6). Art direction for the water: revised after the first phone test towards stylised realism at full resolution (section 6b); it is locked once the owner has judged the second water on the phones.

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

## 6. Owner decisions (2026-11-12)

| # | Question | Decision |
| --- | --- | --- |
| 1 | Test phones | **iPhone 16e (device 1) and iPhone 14 (device 2, the older one).** Both run Safari on iOS |
| 2 | Frame rate | **Floor 30 fps, goal 60 fps.** Approved |
| 3 | Art direction | **Option A for now**, to be judged in the game. The water prototype (below) exists for that |
| 4 | Sound | The owner cannot record. **Free real recordings first** (CC0); if that fails, a paid service such as ElevenLabs. Paying needs the owner's go-ahead at that time, and generated sound is labelled as generated, not as a recording of the place |
| 5 | Music | **None in 0.1** |

Consequences to keep in view:
- **No Android test device.** Vibration (Android only) and Android performance stay untested, and neither iPhone is the "mid-range phone" the project rules name. The 30 fps floor proven on these two phones does not prove it for a mid-range Android phone. An Android device, borrowed if need be, is needed before the tester round.
- **Sound sourcing:** after the owner opened the hosts, opengameart.org and (partly) commons.wikimedia.org were scanned on 2026-11-12; freesound.org still refuses automated clients. The shortlist and its gaps are in `audio_sources.md`. Nobody has listened to the files yet.

## 6a. Water prototype (built 2026-11-12)

`game/scenes/water_prototype/`, opened from the title screen's "Water prototype" button. It is a test scene, not the game: on-screen controls for chop, clarity, light slot and render resolution (360p or 720p), with average fps and the worst 1% over the last 60 s. It shows the same visibility distance the simulation computes. It must be removed or moved behind the debug menu before 0.1, because release builds may not carry debug controls.

Checked in desktop Chromium (software rendering, so its 15-19 fps says nothing about a phone): the scene opens from the title screen and returns to it, all controls respond, calm and rough water and clear and murky water look different, the turn-your-phone screen still appears in portrait, no console errors. **Not checked: any phone.** The owner measures on the two iPhones against the pass criteria of section 5 and reports average and worst-1% fps at 360p and 720p.

Known weak points of the first version: wave shapes are plain sine layers and look smooth and synthetic, there is no shoreline or structure, and the pixel look of option A is barely visible because the water has no hard edges. It answers "does shader water hold 30 fps on the phone", not yet "is this the look".

## 6b. First phone measurement and the second water (2026-11-12)

The owner ran the first prototype (basic shader) on both test phones and reported:

| Phone | Setting | Worst 1% of frames |
| --- | --- | --- |
| iPhone 16e | 720p, basic water | **55 fps** |
| iPhone 14 | 720p, basic water | **57 fps** |

Average fps and the 360p figures were not reported; the average cannot be lower than the worst 1%. Against the pass criteria of section 5: criterion 1 (30 fps average, 24 fps worst 1%) **passed on both phones at full resolution**, criterion 2 (chop levels look different) **passed**, criterion 3 (clear against murky) was not reported. The browser caps the frame rate at the display's refresh rate, so these numbers show the basic water is near that cap; they do not show how much room is left.

Owner feedback on the look: **it could be more realistic.** Consequences:
- The half-resolution "pixel look" of option A is dropped as the default: it is not needed for the frame rate on these phones and it works against realism. The art direction for the water moves to **stylised realism at full resolution** (between options A and C). The top-down map's style is still open.
- A second shader, `water_realistic.gdshader`, was added and is the default: a camera ray cast onto the sea plane, five directional waves with sharpened crests plus noise ripples giving a surface normal, Fresnel reflection of the sky, a sun or moon with its glitter path, light through the crests, whitecaps when it blows, haze and a generic far shore on the horizon (not a real skyline). The "Water" button switches between realistic and basic so the cost can be compared on the phone.
- Cost: unknown on a phone. In desktop software rendering the realistic water ran at about 8 fps against 15-19 fps for the basic one, so it costs roughly twice as much per frame. Whether the iPhones stay above the floor has to be measured again.

Added next, in the order agreed with the owner (2026-11-12):
1. **Foreground:** the concrete top of a breakwater with slab joints and a wet edge, and armour stones along the water line on the left. Generic shapes, not a survey of the real spot; replaced by the real structure after the owner's visit.
2. **Lure, rings and splash:** an "At / Cast" button in the bottom-right corner throws the lure in an arc to a random point 14-32 m out; on landing it throws droplets (particles under gravity) and two expanding rings drawn in perspective on the water. While it sits, small rings appear every few seconds and the lure rides the same waves as the shader (the three largest are computed again in GDScript).
3. **Clouds:** a noise cloud layer in the sky, its cover rising with chop, mirrored in the water's reflection with fewer octaves to save cost; clouds dim the sun.
4. **Line:** an 18-point Verlet chain (`game/ui/fx/verlet_rope.gd`) from the rod tip to the lure under gravity and noise-driven wind; it pays out while the lure flies and sags when it lands. Visual only: line tension in a fight comes from `FightSim`.

Cost: unknown on the phones. Clouds add noise lookups per pixel to both the sky and the water; the overlay adds a few hundred line segments and up to about 36 droplets. To be measured by the owner.

Still missing: a real-place foreground, the fish and its splash during a fight, rain and fog.

## 6c. Owner's report on the realistic water (2026-11-13)

- **Realistic water, 720p: 50 fps** (the owner did not say whether this is the average or the worst 1%; recorded as reported).
- **Look:** the owner says the look is going in the wanted direction.
- **Not yet reported:** the basic water at 720p again on the same phones, the chop-1 measurement, and the phone-by-phone split. Both phones were not reported separately.
- **Reading:** 50 fps is above the 30 fps floor and below the 60 fps goal. Earlier worst-1% figures for the basic water were 55 and 57 fps, so the realistic water costs roughly 5 fps or more at the same resolution, but the two numbers are not the same metric and cannot be compared exactly until the owner reports both as average and worst 1%.

## 6d. Owner's per-phone numbers, realistic water at chop 1 (2026-11-13)

| Phone | Water | Chop | Resolution | fps (metric not stated) |
| --- | --- | --- | --- | --- |
| iPhone 16e | Realistic | 1.0 | 720p | 50 |
| iPhone 14 | Realistic | 1.0 | 720p | 56 |

- The owner said these were taken at wave 1 with the realistic water. **The basic water has not been measured yet** on either phone; the earlier basic numbers (55 and 57 fps worst 1%, section 6b) were at chop 0.3.
- Metric still open: average or worst 1%. Needed for the comparison.
- Against the pass criteria (section 5): above the 30 fps floor on both phones at full resolution, and above the 60 fps goal only on neither phone. Recorded as measured at chop 1, the hardest setting.

## 6e. First like-for-like comparison, realistic against basic at 720p (2026-11-13)

Owner's table. Chop entered as "dalga 11", read as chop 1 (a typo for 1). Clarity entered as "berraklık 100", which is above the slider's maximum of 20; the value used is not known. Both shaders were measured on the same phone in the same session.

| Phone | Realistic average | Realistic worst 1% | Basic average | Basic worst 1% |
| --- | --- | --- | --- | --- |
| iPhone 16e | 60 | 54 | 60 | 56 |
| iPhone 14 | 60 | 56 | 60 | 57 |

Reading:
- **Average is 60 on both shaders and both phones.** That is the browser's refresh cap, so the average hides the cost: both shaders have headroom that these numbers do not show.
- **Worst 1% differs by 1 to 2 fps.** The realistic shader costs about 2 fps at the slow end on the iPhone 16e and 1 fps on the iPhone 14. Small in this condition.
- **Earlier realistic figures do not match this table.** Section 6d gave 50 fps for the iPhone 16e and 56 for the iPhone 14 at chop 1 with the metric unstated. This table gives 54 worst-1% for the same phone and condition, so one of the two runs is not comparable. Likely a different scene state or background load. Not resolved.
- **Clarity:** the owner confirmed "berraklık 100" and "dalga 1" (2026-11-13). The clarity slider in the prototype has a maximum of 20, so 100 cannot be set on it. The value that produced these numbers is therefore unresolved; the owner has chosen not to run more measurements now. Clarity changes how much of the bottom is drawn, so the cost depends on it.

Still open, not scheduled by the owner: runs at a lower clarity and with casts under chop 1, to see whether the 60 fps cap hides a real cost.

## 7. Out of scope here

Colour palette, character and tackle sprites, the exact screen layout of the rig editor and the log, and store art. They follow the art decision and the water prototype.
