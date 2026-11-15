# Project status

**Phase**: 2 Design. PRD approved by the owner on 2026-11-11; data model approved; schema, validator, catch model, cast model and real-time fight built with tests (`data_model.md` section 11); design direction proposed (`design_direction.md`). Phase 0 second pass done (`research.md`: market evidence moderate, demand for the concept still weak); skeleton exists ahead of it at the owner's request. No gameplay code until phase 1 is approved.

## Owner decisions (2026-11-11)
- Scope: one-spot vertical slice first (not 3-5 spots), with a waitlist demand test in parallel.
- First audience: realism enthusiasts (hobby anglers).
- Spot data: first spot from non-OSM sources (coordinates and shore data from an official source or own survey, source recorded); legal advice before any OSM data is used.
- Business model: MVP is free, no ads, no timers, with a waitlist. Later a one-time paid release. Ads, energy timers and pay-to-win are out (pillars 2 and 5). Risk: realistic-sim audience is small, so a paid model may cap reach.

## Reminders for the owner
- Water, fourth round, like-for-like (chop 1, 720p, clarity unknown): realistic and basic both average 60 fps on both phones; worst 1% realistic 54 (16e) and 56 (14), basic 56 and 57. Settings corrected by the owner to clarity 20, chop 1. The owner declined more water measurements for now.
- Water, third round (superseded): realistic at chop 1, 720p: iPhone 16e 50 fps, iPhone 14 56 fps (metric unstated). Still needed: basic water on both phones at 720p, same chop, and the metric (average or worst 1%).
- Water, second round (superseded): on both iPhones open "Water prototype", press "At" a few times, and report average and worst-1% fps for "Water: Realistic" and "Water: Basic" at 720p (about a minute each, also at chop 1), and whether the look is right.
- Sound: listen to the shortlist in `audio_sources.md` and say which files to use. Reel-under-load and cast sounds are missing; choose between the single reel file, hand-picked Freesound downloads (the site blocks automated clients) or the paid fallback.
- An Android phone (borrowed is fine) is needed before the tester round: vibration and mid-range performance are untested on iPhones.
- Before 0.1: remove the water prototype or move it behind the debug menu.
- First spot and species are provisional (Kadıköy/Moda breakwater or pier area; horse mackerel, bluefish, sea bass). After your visit: confirm or replace them, name the exact structure and send your notes; real data is written only after that and the licence reads.
- One legal consultation covers: OpenStreetMap (ODbL), article 31 of Law 5846 for the fishing communique, Sentinel-2 and Copernicus Marine terms.
- After the slice passes: add the remaining 2-4 spots (MVP is 3-5 spots).
- When the slice is playable: recruit the first 10 testers (angler groups, creators); set a stop date first.
- Before the counter service is added: check GoatCounter's hosted terms for commercial use.
- Before the MVP: a native speaker reviews the Spanish text; hand-enter species data with citations.
- At the release gate: developer accounts (cost), age rating, privacy and regional rules for the native app.
- Check the schedule at week 4 (owner has about 3 hours a week).

## Done
- Fight completed (2026-11-15): 133 tests pass; played in the debug web build (software GL, 1280x720) with forced bites: horse mackerel and bluefish fights showed the run arrow, the side-strain hint, the jump hint on the bluefish, "calm: reel it up" and "kicking: wait" during the landing, the fish reeled up on the line and the landed result; no console errors. Not played: side strain with a second finger (the mouse cannot hold two controls), a hook thrown on a jump, a fish lost at the rail (unit tests only). Owner decision: no counters.
- Retrieve control, pump and real clock (2026-11-15): 127 tests pass; played in the debug web build (software GL) at 1280x720: the HUD shows lure depth 0.5 m, then 2.4 m after the lure sank slack, then rising with the retrieve at 0.9 m/s while the distance fell 17.2 m to 15.4 m; reel buttons at top left, neighbours visible, no console errors. Not played in the browser: the fight pump and the clock-based conditions (covered by unit tests only); the phone is needed for feel.
- Line, neighbours, motion logic (2026-11-15): played in the debug web build (software GL): thin tapered line with a ripple at the water, four neighbours at the rail with a bent rod and a lifted fish seen in the captures, settings panel monitor showing 35 degrees tilt, 100 % pull and the rod standing up, no console errors. Not tested on a phone; whether the motion now "makes sense" is the owner's call. Counters proposal written (`counters_proposal.md`), waiting for the owner's choice.
- Why view and settings (2026-11-15): played in the debug web build (software GL) in tr, es and en, at 1280x720 and 844x390: the "Why?" panel after a line break (peak tension 2.84 kg against 2.10 kg, drag 2.8 kg) and after a landed fish; the settings panel with volume, motion sensitivity and the reverse switch. Open: the lure depth in the "why" line is a fixed design fill (3 m) because the player cannot control the retrieve depth yet; a count-down control would make it real. Not tested on a phone.
- Motion fix, cast sequence, rod, reel and hands (2026-11-15): played in the debug web build (software GL) at 1280x720 and 844x390 with a stubbed iPhone permission API and synthetic motion: permission asked once from a real browser tap and granted; chip shows "on"; wind-up, snap, line pay-out, landing, aim marker, reeling (handle turning, rod bending, 0.52 kg) all seen; a flick struck a forced take (take 8.5 s, hooked 8.7 s). Not seen: a real iPhone prompt; frame rate on the phones.
- Merge workflow (2026-11-14): owner gave standing approval to merge every update after green checks; recorded in CLAUDE.md.
- Water detail (2026-11-14): slicks, shore lights and reflections, checked in the debug web build at dusk, night and day with software GL; no shader errors in the console. Frame-rate cost unmeasured: on the phone, open Debug, note fps with "Water detail: on", switch it off, note again.
- Rod, line, wind, hands and phone motion (2026-11-14): played in the debug web build with software GL and synthetic devicemotion events: a forced take was struck by a simulated flick, tilting back raised the rod and tension (0.52 to 0.92 kg), the rod bends towards the line and settles, both hands and the reel are drawn, lamp light shows on the water at night. Not tested on a real phone: sensor sign and thresholds, iPhone permission prompt, frame rate.
- Galata open items (2026-11-14): çapari rig, bridge foreground, cast/drag/creak/zip sounds, depth profiles bounded. Played in the debug web build: rig panel switches to the çapari rig (longest cast about 54 m), bridge rail and lamp drawn, forced horse mackerel landed and flagged under 13 cm. A natural wait with "Faster ×4" ran at normal speed in that run; the speed-up works headless, so the click most likely landed while the lure was still in the air (button hidden). Recheck on the phone.
- Galata Bridge data (2026-11-13): first real spot in the game. Owner decisions: start at the Galata Bridge; species become horse mackerel, bluefish and bonito (no source places sea bass there). Played in the browser: a forced small bonito landed and flagged under the 25 cm legal size; catch log updated. A natural wait at Galata was checked headless (October evening, light rig: median 25 s), not in the browser.
- Spot research, first pass (2026-11-13): `spot_research.md`. Waiting for the owner's choice of first spot and species.
- Fishing loop on demo data (2026-11-13): played in the web debug build with software GL: cast, wait, forced bites, strike, fights (horse mackerel 23 cm landed, bluefish 35 cm landed with the fish body and splashes near the shore, sea bass 93 cm "landed" by the 90 s rule from 69 m out), result, catch log, rig and position kept after a page reload; release build shows no debug button; English, Spanish and 844×390 checked. Not measured on a phone.
- Fight screen on demo data (2026-11-13): played end to end in the web build with software GL: landed (bluefish, medium tackle), line broke at 2.89 kg against a 2.11 kg line (light tackle, drag at maximum, reel and pull held with two touches). Fish silhouette visible near the shore after the drawing-depth fix. Not measured on a phone yet; sound, body animation, cast/bite return, save, debug menu and real spot data are still to do.
- Spec and CLAUDE.md in repo.
- Repo skeleton and an empty Godot 4.4.1 web build (title screen, portrait guard, en/tr/es).
- CI workflow green on the PR (build job). Deploy job untested until the first push to `main`.

## Next
- Phase 0 leftovers: Turkish-language evidence pass (Reddit, Eksi Sozluk, Donanimhaber, TUIK are unreachable from the session), shore-feature check of Euro Fishing / Sea Fishing Simulator / Real VR Fishing, fish-data licence, regional rules.
- Demand test: waitlist (needs owner go-ahead: collects emails) plus 5 anglers + 5 non-anglers on the one-spot slice.
- Phase 1: PRD, funnel, MVP scope, versioning plan.

## Open
- Research verdict (pass 2): 0 direct requests for a real-location shore game, 0 Turkish demand signal, no official Turkish angler count; board (pass 1) 3 x FUND IF (4.7/10). Owner decisions listed in `research.md` section "What this means for the spec" (scope, first audience, OSM licence, business model).
- Network: owner added Steam, Play Store, App Store, fws.gov, PC Gamer hosts. Reddit, SteamDB, Eksi Sozluk (site-side 403), Roblox, Poki, CrazyGames, TUIK and others stay unreachable.
- GitHub Pages source must be set to GitHub Actions for the deploy job to pass (repo is now public).
- GUT test plugin: owner decided to skip for now; own runner stays.
- Debug menu on Pages: `/debug/` after the next merge to main (owner approved 2026-11-13).
- Sound candidates for the cast, drag clicker and rod creak are on a private listening page for the owner; none is committed until chosen.
- Performance budget and test device are set in phase 2.
