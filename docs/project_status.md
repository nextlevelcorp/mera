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
- Debug menu exists in debug builds only. GitHub Pages deploys the release export, so the owner cannot use it there yet: needs a decision (second debug export on Pages, or a feature-tag preset) and approval for the CI and export change.
- 90 s rule lands a fish whose energy is low even when it is far out (seen: 93 cm sea bass at 69 m). The rule in `data_model.md` 5.5 checks energy only; needs the owner's decision.
- Real recordings for ambient, reel and cast sounds still wait for the owner to listen to `audio_sources.md`. Generated cues cover nibble, take and landed.
- Performance budget and test device are set in phase 2.
