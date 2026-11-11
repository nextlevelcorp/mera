# Product Requirements Document

Status: **draft v1 for owner approval** (phase 1, Definition). Approving this document is the owner's call and is required before any gameplay code. Nothing below is approved until the owner says so.

Inputs: `project_spec.md` (the spec), `research.md` (phase 0), the owner interview (decision log at the end). Where this PRD adds to or narrows the spec, it says so. English is the source language; Turkish and Spanish text come from the localisation table.

## 1. Summary

Mera is a shore-fishing RPG that plays like a relaxed exploration game and resolves like a simulation. The player picks a real shore spot, reads the conditions, rigs, casts, waits, strikes and fights a fish in a first-person view; outcomes come from depth, feeding time, tackle match and line tension, and the screen shows enough to reason about them. The first audience is hobby anglers who want realism they can check against their own experience.

## 2. Problem and audience

- **Audience (first):** realism enthusiasts, hobby anglers (owner decision). They check details: research found real anglers criticise fight length, line logic and lure behaviour in existing sims, and also play sims when they cannot fish.
- **Later audiences (not targeted yet):** cozy and collection players; people curious about fishing.
- **Evidence status:** market evidence moderate, demand for this exact concept weak (0 direct requests, no Turkish signal). The slice and its tests exist to find out. See `research.md`.
- **Unmet needs the product answers:** no ads, timers or pay-to-win (top complaint cluster); fair, short fights; sourced places and species labelled as such.

## 3. Goals and non-goals

**Goals (0.1 slice)**
1. A complete cast, wait, bite, fight, land, log loop at one real spot that a hobby angler finds believable.
2. Readable outcomes: every result can be explained from depth, feeding time, tackle match and line tension, and the test suite checks it.
3. A web build that holds a stable frame rate on a mid-range phone (target and test device set in phase 2).
4. Honest sourcing: every spot and species value has a source or a design-fill label.

**Non-goals (0.1):** walking world, multiple spots, bait or float fishing, XP, money, tackle unlocks, shop, accounts, cloud save, backend, ads, in-app purchases, live weather data, native builds, multiplayer.

## 4. Versions and scope (versioning plan)

| Version | Scope | Gate to start |
| --- | --- | --- |
| 0.1 slice | One spot with 3-4 standing positions, lure spinning/LRF only, 3 species, simulation core, fight with two-thumb input, catch log and records, local save, en/tr/es, debug menu, anonymous counters, web build on GitHub Pages | This PRD approved |
| 0.5 MVP | 3-5 Turkey spots, 15-25 species with sourced behaviour (spec 4.6), wider conditions (waves, clarity, season), more tackle, progression | The slice passes the tester threshold |
| 1.0 release | Paid one-time iOS/Android app, store listing, security audit, full test pass | MVP retention evidence (spec 4.7) |
| Later | More regions, community features (spec 4.7) | As in the spec |

Spec 4.6 listed top-down exploration for the MVP; this PRD narrows the slice to a static top-down map with 3-4 tappable standing positions. A walkable top-down world is not in 0.1.

## 5. The first five minutes (slice experience)

1. Open the web build on a landscape phone (portrait shows the turn-your-phone screen).
2. Arrive at the spot, pick a time slot (dawn, day, evening, night). Wind and water clarity come from a date-based seed.
3. A ready-made rig and a standing position are preselected. "Edit rig" and the position choice are always open.
4. First cast within about 2 minutes. Cast, retrieve the lure, read signs.
5. A bite (nibble or committed take), strike, fight, fish appears near the shore, land or lose it. The log records it.

Round length: the simulation decides the wait (good spot and hour about 20-40 s, bad: minutes), the player may speed time up, signs stay readable. A fight lasts 20-90 s by species and size and never exceeds 90 s. Typical round 1.5-4 min.

## 6. Functional requirements

Each requirement is testable; the simulation requirements are tested headless.

**Views and controls**
- R1. Landscape only, 1280x720 design space, `canvas_items` stretch, `expand` aspect; portrait shows the guard screen.
- R2. Top-down spot map: one image with 3-4 tappable standing positions, each with different depth and structure.
- R3. First-person fishing view from cast to land or loss; centred 1280x720 design rectangle, backgrounds to the screen edges.
- R4. Fight input, two thumbs: left corner reel (hold, slide for speed); right corner drag/brake and pulling the rod tip against the fish's run. Tension bar centred. No gyro.
- R5. Touch controls pinned to the screen corners; targets large enough for thumbs (size fixed in phase 2).

**Simulation (plain GDScript, deterministic under a seed, no scene dependencies)**
- R6. Environment: time slot, wind direction and speed, water clarity from the date seed.
- R7. Presence: which of the 3 species can be at the position now (spot, season, time, wind, depth).
- R8. Attraction: lure type, size, colour/flash, retrieve speed and depth against species preference.
- R9. Bite: nibbles versus a committed take; hook size versus mouth size; strike timing.
- R10. Fight: fish strength and stamina against rod power, line strength, drag and player input; runs; tiring; line break, hook pull-out or landing.
- R11. Landing: tired fish appears near the shore at a distance set by water clarity; landed or lost at the edge.
- R12. Every stage logs its inputs so a result can be explained to the player and asserted in tests.
- R13. Fish stays invisible during the wait and the early fight; the player reads float/line/rod bend/splashes/rings.

**Feedback**
- R14. Every cue that vibration carries on Android also has a visual and an audio equivalent (iPhone Safari has no Vibration API). Tension is never shown by colour alone.
- R15. Sound starts after the first player tap (browser autoplay rule).

**Progress, data, platform**
- R16. Catch log: first-seen date and biggest length and weight per species; records; last rig and standing position. Versioned local save on the phone; nothing leaves the phone.
- R17. Game data in data files with a schema and a source field: spot, 3 species, rod, reel, line, hook, lures (spec 5.3 attributes, 1-20 scale where defined). Loaded and validated at start-up; schema errors fail loudly.
- R18. Every user-facing string through the localisation table (en, tr, es); the test fails on a missing key. Spanish is flagged "not reviewed by a native speaker" until someone reviews it.
- R19. Debug menu in development builds only, compiled out of release: jump to spot, set time slot, wind and clarity, force a bite, pick species and size, grant tackle, show simulation inputs. Every flow the owner must check is reachable from it.
- R20. Anonymous counters (see section 8). No identifiers, no cookies, no emails, no waitlist.
- R21. Accessibility defaults (proposed, owner to review): readable text sizes, no colour-only signals, sound cues have visual counterparts.

## 7. Data and sourcing

- **Spot record:** id, English source name, localisation keys, coordinates, region, shore type, depth profile per standing position, bottom type, structure, exposure by wind direction, typical clarity, access notes, species list with seasonal weights, `source` or `design_fill: true`.
- **Source rule for spots:** owner's own visit with dated notes, plus official or public-authority data after its licence is read. Not OpenStreetMap until a lawyer has advised (owner decision). Unsourced values are labelled design fill in the data and in the in-game log.
- **Species (3 in the slice):** one common and easy, one medium, one rare chase species. Chosen by the owner's observation plus a published source.
- **Species licence rule (recommendation, section 11):** do not import FishBase or similar datasets in bulk; hand-enter values with citations; any bulk import needs the owner's approval after the licence is read.
- **Spot shortlist (candidates only):** these come from general knowledge, were not verified in this session, and are for the owner to confirm on a visit or replace with a better-known spot. Criteria: reachable and fishable, 3-4 distinct standing positions, simple known depth and structure.
  1. Galata Bridge, Karaköy/Eminönü side (bridge deck, positions along the rail).
  2. A Kadıköy/Moda breakwater or pier area.
  3. A Bosphorus-side or Black Sea pier or breakwater the owner knows well.
  The slice builds spot 1 or the owner's replacement; the rest of the 3-5 spots follow after the slice passes.

## 8. Measurement and funnel

Slice funnel: page open, first cast within 2 minutes, first fish landed, returning visit. No numeric targets until the first 100 visitors set a baseline; targets are then written here. The pass gate is the tester threshold (section 9).

- Counters are anonymous event counts (no identifier, no cookie, no email). "Returning visit" is computed on the phone from a local last-visit date, and only the count is sent, never an identifier.
- Counter service (recommendation): GoatCounter. It is open source and, per its README, offers a free hosted service, does not track with unique identifiers and says it needs no GDPR notice. Its hosted terms for commercial use could not be checked from this environment; the PR that adds it must check them first. If they do not fit, the fallback is no analytics and the testers only.
- Funnel steps and event names are final in phase 2.

## 9. Success criteria and schedule

**Pass bar for the slice (set before testing):** 5 anglers and 5 non-anglers play it. At least 4 of 5 anglers call the fight and line logic believable; at least 6 of 10 testers say they would play again tomorrow. Anonymous counters count as a second signal only with 100 or more visitors.

**Schedule:** target 8 weeks from phase 1 approval to a playable 0.1 slice. The owner decided testing comes last, so the first 10 testers are recruited (angler groups, creators) only when the slice is playable. With about 3 owner hours a week (about 24 in 8 weeks), a tester round of 10 sessions does not fit inside week 8. Proposed adjustment, owner to confirm: 8 weeks to a playable slice, tester round in weeks 9-10. The one first-spot visit also needs a block of owner time; plan it in the first weeks. Re-check the plan at week 4.

## 10. Non-functional requirements

- Web export single-threaded, stable frame rate on a mid-range phone; target frame rate and test device set in phase 2; measure before and after any visual feature.
- No secrets in the repository or the export; no backend.
- Network: only the anonymous counter request (section 8). No player data leaves the phone. Any native-app data collection later needs its own approval, consent and privacy design.
- Release build contains no debug menu.

## 11. Dependencies and approvals ledger

Owner decision of 2026-11-11: proceed with the recommendations below.

| Item | Recommendation | State |
| --- | --- | --- |
| Anonymous counter service | GoatCounter, terms check in the integration PR; fallback no analytics. `.claude/rules/security.md` gets a single stated exception for it. | Decided in principle; integration after phase 1 approval |
| Developer accounts (Apple about USD 99 a year, Google about USD 25 once) | Do not buy now. Buy at the release gate, when a native build exists. | Decided: no cost now |
| Species data licence | No bulk import; hand-entered values with citations; owner approval for any import. Licence terms of FishBase, GBIF and others were not readable from this environment. | Decided |
| Regional rules (Turkey, Spain, age rating, privacy) | Web slice collects no personal data, so little applies now; a compliance check (store age rating, KVKK/GDPR for the native app's separate data collection) at the release gate. | Decided: deferred to release gate |

## 12. Risks

| Risk | Mitigation |
| --- | --- |
| No proven demand for a real-location shore game | Slice plus tester pass bar and anonymous counters; stop date: owner sets one before the tester round |
| Fight or loop becomes repetitive or too long | Fight cap 90 s; tester question on repeated catches; simulation tuned from tests |
| Real anglers reject line or fight logic | Owner (an angler) reviews the model; tester threshold is on anglers |
| iPhone has no vibration | Visual and audio equivalents (R14) |
| Phone web performance breaks the first five minutes | Measure early on a named mid-range phone; phase 2 sets the budget |
| Unsourced or wrong spot or species data is caught by players | Source or design-fill label on every value; owner's visit notes |
| Owner time (3 h a week) limits visits, reviews and tests | Schedule check at week 4; tester round after the slice |

## 13. Open items, defaults and reminders

- **Phase 2 (design) decides:** art and audio direction, target frame rate and test device, counter event names, tension model parameters, sizes of touch targets.
- **Owner to do:** confirm or replace the spot shortlist after a visit; confirm the schedule adjustment in section 9; set a stop date before the tester round.
- **Reminders for the owner** (listed in `project_status.md`): add the remaining 2-4 spots after the slice passes; Turkish demand evidence from the tester round; Spanish native review; counter-service terms check; developer accounts and compliance at the release gate.

## 14. Approval

- [ ] Owner approves this PRD (phase 1). Until then no gameplay code.

## Appendix: decision log (owner interview, 2026-11-11)

## Decisions so far

### Carried over from phase 0
- Scope: one-spot vertical slice first, with a demand test in parallel; widen only after the slice passes (see threshold).
- First audience: realism enthusiasts (hobby anglers).
- First spot data: non-OSM sources (owner's own visit and dated notes, unsourced values labelled design fill); legal advice before any OSM use.
- Business model: MVP free, no ads, no timers, no pay-to-win. Later a one-time paid release.

### Interview (contradictions in the spec)
1. **Measuring demand without personal data.** Web build sends no personal data and has no waitlist or email. It uses anonymous, cookieless, identity-free counters (page open, first cast, first fish, returning visit). The counter service is a new third-party dependency: needs the owner's go-ahead before it enters the build.
2. **Top-down in the slice.** One spot with 3-4 tappable standing positions on a top-down map (different depth and structure). No walking world in the slice.
3. **Vibration.** iPhone Safari has no Vibration API (caniuse: iOS Safari up to 27.2 "no", Android Chrome "yes", Firefox "no"). Vibration is an extra on Android; every cue also has a visual and audio equivalent so the game reads the same on iPhone. Real iOS haptics wait for the native build. Pillar 4 text stays.
4. **Paid release platform.** iOS/Android paid app, as in the spec. Web build stays a free demo and measurement tool. Developer accounts (Apple about USD 99/year, Google about USD 25 once) cost money: owner approval needed before purchase.
5. **Round length.** The simulation decides the wait for a bite (good spot and hour about 20-40 s, bad spot minutes); the player can speed time up and the signs stay readable. A fight lasts 20-90 s by species and size and never exceeds 90 s. Typical round 1.5-4 min.
6. **First cast.** A ready-made rig and standing position are preselected. "Edit rig" is always visible and fully open. Target: first cast within about 2 minutes. The ready rig carries a design-fill label.

### Interview (PRD gaps)
7. **First spot.** Owner lives in Istanbul and fishes with rod and lure, so the owner is the primary domain expert and can visit. Superseded by decisions 18 and 20: criteria fixed, shortlist in section 7.
8. **Pass bar for the slice.** 5 anglers plus 5 non-anglers: at least 4 of 5 anglers call the fight and line logic believable; at least 6 of 10 testers say they would play again tomorrow. Anonymous counters count as second evidence only with 100 or more visitors.
9. **Reach.** Angler groups (Facebook, Instagram, Telegram) and fishing content creators. Not available: own circle, tackle shops. Superseded by decision 21: recruiting starts when the slice is playable.
10. **Technique in the slice.** Lure spinning / light rock fishing (LRF). No bait/float in the slice.
11. **Fight input.** Two thumbs in landscape: left corner reel (hold, slide for speed); right corner drag/brake and pulling the rod tip against the fish's run. Tension bar centred. No gyro.

12. **Waitlist.** Removed from the web MVP. Demand is measured with the anonymous counters and the testers. An "tell me when the app is out" opt-in, if ever, is collected inside the native app with its own consent and privacy rules; that is a later decision.
13. **Schedule.** Target 8 weeks from phase 1 approval to a playable 0.1 slice with the first 10 testers. Owner's hours per week not stated: open.
14. **Species.** 3 species in the slice: one common and easy, one medium, one rare "chase" species. Selection rule: owner's observation plus a published source; any value without a source is labelled design fill. Species data licence (FishBase terms and similar) is not yet researched and must be closed before species data is committed.
15. **Local save.** Versioned local save of: catch log (first-seen date, biggest length and weight per species), records, last rig and standing position. No XP, money or unlocks in the slice.
16. **Languages.** en, tr and es all ship; es is marked "not reviewed by a native speaker" until someone reviews it; the slice test is played in tr and en. The localisation test and the CLAUDE.md rule stay unchanged.
17. **Funnel targets.** No numeric targets yet. The first 100 visitors only set the baseline; targets are written into the PRD afterwards. The pass gate stays the tester threshold (decision 8).
18. **First spot criteria.** The owner can visit it regularly and rod fishing is allowed there (owner confirms current rules); it has 3-4 distinct standing positions; simple, well-known depth and structure (pier, breakwater, harbour wall). Not required: being famous among Istanbul rod anglers. Spot not chosen yet.
19. **Conditions.** At arrival the player picks a time slot (dawn, day, evening, night). Wind direction and strength and water clarity come from a date-based seed (no server; same for everyone that day). The simulation stays deterministic.
20. **Spots.** Owner delegated the choice: a shortlist of 3 Turkey spots now (below); the MVP has 3-5; the slice builds only the first; the other spots are added after the slice passes. The owner wants a reminder when the project reaches that point.
21. **Testing comes last.** Build the slice first. Tester recruiting (angler groups, creators) starts only when the slice is playable. No tester work now.
22. **Owner time.** About 3 hours per week.
23. **Approvals delegated to recommendations** (owner, 2026-11-11): anonymous counter service, developer accounts, species data licence, regional rules. Recommendations are in section 11.
24. **Unreachable sources** (Reddit, Ekşi Sözlük, TÜİK, etc.): skipped. Turkish demand evidence will come from the end-of-slice test, not desk research.

