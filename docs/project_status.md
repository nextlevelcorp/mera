# Project status

**Phase**: 2 Design. PRD approved by the owner on 2026-11-11; data model approved; schema, validator and catch model built with tests (`data_model.md` section 11). Phase 0 second pass done (`research.md`: market evidence moderate, demand for the concept still weak); skeleton exists ahead of it at the owner's request. No gameplay code until phase 1 is approved.

## Owner decisions (2026-11-11)
- Scope: one-spot vertical slice first (not 3-5 spots), with a waitlist demand test in parallel.
- First audience: realism enthusiasts (hobby anglers).
- Spot data: first spot from non-OSM sources (coordinates and shore data from an official source or own survey, source recorded); legal advice before any OSM data is used.
- Business model: MVP is free, no ads, no timers, with a waitlist. Later a one-time paid release. Ads, energy timers and pay-to-win are out (pillars 2 and 5). Risk: realistic-sim audience is small, so a paid model may cap reach.

## Reminders for the owner
- First spot and species are provisional (Kadıköy/Moda breakwater or pier area; horse mackerel, bluefish, sea bass). After your visit: confirm or replace them, name the exact structure and send your notes; real data is written only after that and the licence reads.
- One legal consultation covers: OpenStreetMap (ODbL), article 31 of Law 5846 for the fishing communique, Sentinel-2 and Copernicus Marine terms.
- After the slice passes: add the remaining 2-4 spots (MVP is 3-5 spots).
- When the slice is playable: recruit the first 10 testers (angler groups, creators); set a stop date first.
- Before the counter service is added: check GoatCounter's hosted terms for commercial use.
- Before the MVP: a native speaker reviews the Spanish text; hand-enter species data with citations.
- At the release gate: developer accounts (cost), age rating, privacy and regional rules for the native app.
- Check the schedule at week 4 (owner has about 3 hours a week).

## Done
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
- Debug menu does not exist yet; required before any gameplay flow is reviewed.
- Performance budget and test device are set in phase 2.
