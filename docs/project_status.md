# Project status

**Phase**: 0 Discovery first pass done (`research.md`, evidence weak); skeleton exists ahead of it at the owner's request. No gameplay code until phase 1 is approved.

## Owner decisions (2026-11-11)
- Scope: one-spot vertical slice first (not 3-5 spots), with a waitlist demand test in parallel.
- First audience: realism enthusiasts (hobby anglers).
- Spot data: first spot from non-OSM sources (coordinates and shore data from an official source or own survey, source recorded); legal advice before any OSM data is used.
- Business model: MVP is free, no ads, no timers, with a waitlist. Later a one-time paid release. Ads, energy timers and pay-to-win are out (pillars 2 and 5). Risk: realistic-sim audience is small, so a paid model may cap reach.

## Done
- Spec and CLAUDE.md in repo.
- Repo skeleton and an empty Godot 4.4.1 web build (title screen, portrait guard, en/tr/es).
- CI workflow green on the PR (build job). Deploy job untested until the first push to `main`.

## Next
- Phase 0: re-run research with blocked hosts reachable (Steam, Reddit, Play Store, SteamDB, fws.gov, Turkish forums); direct demand test (waitlist or 5+5 player test).
- Phase 1: PRD, funnel, MVP scope, versioning plan.

## Open
- Research verdict: no verified request for a real-location shore game, no Turkish demand signal; board 3 x FUND IF (4.7/10). Owner decisions listed in `research.md` section "What this means for the spec" (scope, first audience, OSM licence, business model).
- Network: owner added Steam, Play Store, App Store, fws.gov, PC Gamer hosts to the environment. Reddit, SteamDB and Eksi Sozluk return 403 (site-side bot blocking), so they stay unreachable.
- GitHub Pages source must be set to GitHub Actions for the deploy job to pass (repo is now public).
- GUT test plugin: owner decided to skip for now; own runner stays.
- Debug menu does not exist yet; required before any gameplay flow is reviewed.
- Performance budget and test device are set in phase 2.
