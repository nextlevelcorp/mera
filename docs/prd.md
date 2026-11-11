# Product Requirements Document

Status: **approved by the owner on 2026-11-11** (phase 1, Definition). Changes after this date need the owner's approval.

Inputs: `project_spec.md`, `research.md`, the owner interview (decision log in the appendix). Where this PRD narrows or adds to the spec it says so. Priorities: **P0** = the version cannot ship without it, **P1** = should follow soon, **P2** = designed for, not built.

## 1. Problem statement

Hobby anglers who play fishing games get arcade timing bars, invented fish, pay-to-win and ads (research: monetisation was the largest complaint theme in a 117-review mobile sample, and "microtransactions/DLC/grind" in 11 of 21 sampled negative Fishing Planet reviews). Realistic simulators rate only 62-84% positive among English Steam reviewers, and real anglers specifically criticise fight length, line logic and lure behaviour. Nothing found lets a player learn and practise reading a real shore spot with outcomes they can explain. Not solving it leaves anglers with games they do not trust, and people curious about fishing with videos and forums only.

Evidence status: market evidence **moderate**; demand for this exact concept (realistic, real-location shore fishing) **weak** (0 direct requests found, no Turkish signal). Version 0.1 exists to find out, cheaply.

## 2. Target players

| Player | Wants | Status |
| --- | --- | --- |
| **Hobby angler (primary)**: rod anglers, rod-and-lure shore fishing in Turkey first | Their own waters, real species, tackle choices that matter, a fight and line model they can believe | Owner decision: first audience |
| Cozy / collection player | A calm world, a log to fill, steady mastery | Later; not designed for in 0.1 |
| Fishing-curious person | A way to learn rigs, lures and reading water without gear | Later; served indirectly by explanations in 0.1 |

Research notes for the primary player: real anglers play sims also when they cannot fish (age, weather, time), check species and place accuracy, and mark down long fights.

## 3. Goals

1. **Believable fight and line logic (0.1).** At least 4 of 5 tester anglers call it believable (pass bar, section 9).
2. **Readable outcomes (0.1).** Every catch attempt result can be explained from depth, feeding time, tackle match and line tension; a headless test asserts every stage logs its inputs.
3. **Fast first cast (0.1).** A new player reaches a first cast within about 2 minutes of the game loading (measured by anonymous counters; target set after a baseline).
4. **Honest sourcing (0.1+).** 100% of spot and species values carry a source or a design-fill label; a data test fails otherwise.
5. **Playable on a phone (0.1).** The single-threaded web build holds a stable frame rate on a named mid-range phone (target and device set in phase 2).
6. **Evidence of demand (0.1 to 0.5).** Tester pass bar met, then a funnel baseline from the first 100 visitors.

## 4. Non-goals

- **Ads, timers, pay-to-win, loot boxes**: the most-complained-about features in competing games; against pillars 2 and 5.
- **Accounts, cloud save, backend, email collection, waitlist**: web build keeps all data on the phone (owner decision); native data collection is a later, separately approved design.
- **Walkable top-down world in 0.1**: a static map with standing positions tests the same decision at far lower cost; revisited for 0.5.
- **Bait/float fishing, boats, sonar, deep sea**: 0.1 is lure spinning/LRF only; the rest is out of the MVP (spec 4.6).
- **Live weather or any live data**: conditions come from a date-based seed; live data is a later pipeline (spec 4.7).
- **Native iOS/Android in 0.1 and 0.5**: native paid release is 1.0.
- **Real-brand tackle names**: fictional tackle labelled design fill avoids the brand-licence question.

## 5. User stories

**Hobby angler**
- As a hobby angler, I want to pick a standing position at a real spot and see its depth and structure so that I can decide where to cast, as I would on the shore.
- As a hobby angler, I want the time of day, wind and water clarity to change what bites so that reading conditions is a skill I can learn.
- As a hobby angler, I want to choose lure, line and hook, and see why a choice worked or failed so that I learn tackle matching.
- As a hobby angler, I want a bite to feel like a nibble or a committed take and my strike timing to matter so that patience pays off.
- As a hobby angler, I want a fight that is short, intense and decided by line tension and drag, not a timing bar so that I trust the game.
- As a hobby angler, I want a catch log with my records so that I have something to beat and fill.
- As a hobby angler on an iPhone, I want every cue that Android shows as vibration to also show on screen and in sound so that I lose nothing.
- As a hobby angler, I want to play in Turkish so that terms feel natural.

**First-time visitor**
- As a first-time visitor, I want to cast within about 2 minutes with a sensible rig preselected so that I am not stopped by menus.
- As a visitor holding the phone upright, I want a clear "turn your phone" screen so that I know what to do.

**Owner (reviewer and tester)**
- As the owner, I want a debug menu to jump to a spot, set time, wind and clarity, force a bite and pick species and size so that I can check any flow in the time I have (about 3 hours a week).

## 6. Player funnel (measurable steps)

Measured with anonymous event counts only: no identifier, no cookie, no email. A counter that cannot be measured without identifying a person is not measured. Targets are not set for any step until the first 100 visitors give a baseline (owner decision); the tester threshold is the 0.1 pass gate.

| # | Step | Definition (event) | Measured as | Target |
| --- | --- | --- | --- | --- |
| S0 | Discover | A page open of the build (counter's page view) | Daily count | Baseline only |
| S1 | Open the build | Game finished loading and showed the first screen (`loaded`) | `loaded` / S0 | Baseline after 100 visitors |
| S2 | First cast within 2 minutes | First cast completed within 120 s of `loaded` in a fresh session (`first_cast_fast`); slower first casts are `first_cast_slow` | `first_cast_fast` / `loaded` for first-time visitors (first visit flagged on the phone) | Baseline after 100 visitors |
| S3 | First fish landed | First landed fish ever on this phone (`first_fish`) | `first_fish` / `loaded` for first-time visitors | Baseline after 100 visitors |
| S4 | Return next day | First `loaded` on a later calendar day than the first visit; only the event is sent (`return_next_day`), the phone computes it from a local date | Approximate: `return_next_day` on day N / `first_visit` on day N-1. A true cohort cannot be built without identifiers, so use only with enough daily volume | Baseline after 100 visitors |
| S5* | Third spot unlocked | MVP only | Event defined in the MVP design | Set with the MVP |
| S6* | Log half complete | MVP only | Event defined in the MVP design | Set with the MVP |

Notes: counter events are not sent from development or debug builds; failures to reach the counter are silent and never block play. The counter service is GoatCounter pending a check of its hosted terms (section 11). Tester observation (section 9) covers what counters cannot: believability and "play again tomorrow".

## 7. Feature list and acceptance criteria

### 7.1 Version 0.1 (the slice)

Scope: one real spot with 3-4 standing positions, lure spinning/LRF only, 3 species, the full cast, wait, bite, fight, land, log loop, local save, en/tr/es, debug menu, anonymous counters, web build on GitHub Pages.

**F1. Landscape layout (P0).** 1280x720 design space, `canvas_items`, `expand`.
- Given the window is taller than wide, then a "turn your phone" screen covers the game and gameplay input is ignored.
- Given a 16:9 and a wider phone ratio, then the first-person view keeps a centred 1280x720 rectangle with backgrounds to the screen edges and touch controls inside the screen corners.

**F2. Spot and standing positions (P0).** Static top-down map of one real spot.
- Given the map, when the player taps a standing position, then it is selected and its depth and structure are shown.
- Given the spot data, then it has 3-4 positions and no two share both depth profile and structure (data test).

**F3. Conditions (P0).** Four time slots; wind and clarity from a date seed.
- Given arrival, when the player picks dawn, day, evening or night, then the choice is applied.
- Given the same date and seed, then wind direction, wind speed and clarity are identical (unit test); given 30 consecutive dates, then they are not all identical (unit test).

**F4. Rig (P0).** A ready rig is preselected; "Edit rig" is always open.
- Given a first launch, then a rig and standing position are preselected and labelled design fill in the data.
- Given Edit rig, then rod, line, hook and lure come from data; a lure outside the rod's casting-weight range shows a visible warning.

**F5. Cast (P0).**
- Given a rig and a position, when the player casts, then the view switches to first person and the lure lands at a distance set by rod, lure weight and the cast input, identically for the same seed and input (unit test).

**F6. Wait and read (P0).**
- Given a lure in the water, then line, rod tip, surface rings and splashes show activity and the fish itself is never visible.
- Given a headless run over seeded trials, then for the best position, time slot and lure the median wait for a bite is between 20 and 40 s, and for the worst it is at least 120 s.
- Given the player taps speed-up, then waiting runs faster and the signs stay readable.

**F7. Bite and strike (P0).**
- Given a fish interested in the lure, then it produces either nibbles or a committed take.
- Given a committed take and a strike inside the strike window, then the hook sets with a probability that depends on hook size and mouth size; given a strike outside the window, then no hook set (unit tests).

**F8. Fight (P0).** Two thumbs: left corner reel (hold, slide for speed), right corner drag/brake and pulling the rod tip against the fish's run; tension bar centred.
- Given a hooked fish, then it runs, tires and can be landed, lost to a line break (tension above line strength for too long) or lost to a hook pull-out.
- Given every species and size combination, then a fight ends (landed or lost) within 90 s and a typical one lasts 20-90 s (unit test over seeded fights).
- Given the fight screen, then tension is shown by shape or position, not colour alone.

**F9. Landing and log (P0).**
- Given a tired fish, then it appears near the shore at a distance set by water clarity; the player lands it or loses it at the edge.
- Given a landed fish, then the log records first-seen date and keeps the biggest length and weight per species, and shows records.

**F10. Explainable outcomes (P0).**
- Given any catch attempt, then each stage (presence, attraction, bite, hook hold, fight) records its inputs and result, a "why" view shows depth, feeding time, tackle match and tension, and a headless test asserts every stage logs its inputs.

**F11. Equal cues (P0 for equivalents, P1 for Android vibration).**
- Given any cue that vibrates on Android, then the same information is shown on screen and in sound; iPhone Safari gets no vibration and loses no information.
- Given a fresh page, then sound starts after the player's first tap.

**F12. Sourced data (P0).** Data files with a schema.
- Given any spot or species record, then it has `id`, English source name, localisation keys and either `source` or `design_fill: true`; a record missing these fails the data test and fails loudly at start-up.
- Given a value with no source, then the in-game log shows it as a design fill.

**F13. Localisation (P0).**
- Given every user-facing string, then it exists in en, tr and es (test fails on a missing key); Spanish carries a "not reviewed by a native speaker" flag until reviewed.

**F14. Local save (P0).** Versioned save on the phone.
- Given the player closes and reopens, then log, records, last rig and last position are restored.
- Given an old or corrupt save, then it migrates or resets with a message and does not crash; nothing is sent off the phone.

**F15. Debug menu (P0).** Development builds only.
- Given a development build, then the menu can jump to a position, set time slot, wind and clarity, force a bite, pick species and size, grant tackle and show simulation inputs.
- Given the release export, then no debug menu is present (checked in CI by export contents).

**F16. Anonymous counters (P0, after the terms check).**
- Given S0-S4, then the events in section 6 are sent with no identifier, no cookie and no email; an unreachable counter never blocks play; development builds send nothing.

**F17. Build, tests and deploy (P0).**
- Given a pull request, then CI imports, runs the unit tests and exports the web build; given a push to `main`, then the build deploys to GitHub Pages.
- Given a visual feature, then frame rate is measured before and after on the named test phone.

**F19. Overmatched-tackle hint (P1, owner decision 2026-11-11).**
- Given a hooked fish whose estimated fight exceeds the 90 s cap on the current tackle, then the player sees a hint that the fish is too big for the tackle (the "why" view shows the numbers); the fight still ends by the 90 s rule.
- Given a fish that is not overmatched, then no hint is shown.

**F18. Settings and accessibility basics (P1).** Readable text size; adjustable text scale; sound cues have visual counterparts.

**P2 (designed for, not built in 0.1):** bait/float fishing, walkable top-down world, gyro rod angle, XP, money and tackle unlocks, shop, season changes, waves simulation, more spots and species.

### 7.2 Version 0.5 (the MVP, scope from spec 4.6; criteria detailed after the slice passes)

| Feature | Acceptance criteria (summary) |
| --- | --- |
| M1. 3-5 Turkey spots | Each has 3-4 positions, sources or design-fill labels, owner-visit notes; the data test passes |
| M2. 15-25 species with sourced behaviour | Each with source or design-fill label; species data licence rule kept (no bulk import) |
| M3. Wind-driven waves, clarity, season | Simulation tests per stage; frame rate re-measured on the test phone |
| M4. Tackle breadth and progression | Experience, money, tackle and spot unlocks; funnel steps S5 and S6 defined and counted |
| M5. Exploration | Owner decides at the end of 0.1: static map again or walkable top-down |
| M6. Save migration and Spanish review | Old saves migrate; Spanish reviewed by a native speaker |

## 8. Success metrics

**Leading (days to weeks)**
- Tester pass bar met (section 9).
- Funnel baseline recorded from the first 100 visitors; targets then written into this PRD.
- Frame rate on the named test phone meets the phase 2 target.
- Zero console errors in the smoke test of the web build.

**Lagging (weeks to months)**
- Return-next-day trend (approximate, section 6).
- Share of first-time visitors who land a first fish.
- Tester comments on repeated catches ("does the fight stay interesting").

No revenue metric applies: the web build is free. The willingness-to-pay question moves to the paid 1.0 release; counters can not measure it.

## 9. Pass bar and schedule

**Pass bar (set before testing, owner decision):** 5 anglers and 5 non-anglers play the slice. At least 4 of 5 anglers call the fight and line logic believable; at least 6 of 10 testers say they would play again tomorrow. Counters count as a second signal only with 100 or more visitors. A stop date is set before the tester round (owner to choose).

**Schedule (owner-approved):** 8 weeks from phase 1 approval to a playable 0.1 slice; tester round in weeks 9-10 (testing comes last). Owner time: about 3 hours a week. Outline: weeks 1-2 phase 2 design (data schema, architecture, frame-rate target and test phone, art and audio direction); weeks 3-7 build; week 8 hardening and the debug menu; plan one block for the spot visit early. Re-check the plan at week 4.

## 10. Non-functional requirements

- Single-threaded web export, stable frame rate on a mid-range phone; measure before and after any visual feature.
- No secrets in the repository or the export; no backend; no player data leaves the phone.
- Network: only the anonymous counter request, as allowed by `.claude/rules/security.md`.
- Simulation core is plain GDScript, deterministic under a seed, headless-testable; rendering reads simulation state.
- Release builds contain no debug menu.

## 11. Dependencies and approvals ledger

Owner decision of 2026-11-11: proceed with the recommendations below.

| Item | Recommendation | State |
| --- | --- | --- |
| Anonymous counter service | GoatCounter (open source; README says no unique identifiers). Hosted commercial terms could not be checked from this environment: check them in the integration PR. Fallback: no analytics, testers only | Decided in principle |
| Developer accounts (Apple about USD 99 a year, Google about USD 25 once) | Do not buy now; buy at the release gate | Decided |
| Species data licence | No bulk import of FishBase or similar; hand-enter values with citations; owner approval for any import. Terms of FishBase, GBIF not readable from this environment | Decided |
| Regional rules and age rating | Web slice collects no personal data; check at the release gate, including privacy for any native data collection | Decided: deferred |
| OpenStreetMap | Not used for the first spot; legal advice before any use | Decided |

## 12. Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| No real demand for a realistic real-location shore game | Unknown (weak evidence) | High | Slice, tester pass bar, counters; stop date before the tester round |
| Loop or fight becomes repetitive or too long | Medium | High | 90 s fight cap; tests across species and sizes; tester question on repeated catches |
| Real anglers reject the fight or line logic | Medium | High | Owner (an angler) reviews the model; threshold is on anglers |
| iPhone has no vibration | Certain | Low | Visual and audio equivalents (F11) |
| Phone web performance breaks the first five minutes | Medium | High | Phase 2 sets the budget; measure early on a named phone |
| Spot or species data wrong or unsourced | Medium | Medium | Source or design-fill label on every value; owner-visit notes; data test |
| Owner time (about 3 h a week) limits visits, reviews and tests | High | Medium | Tester round after the slice; check at week 4; debug menu for fast checks |
| Crowded fishing releases on Steam (706 dated 2023-2026) hide a small new game | High | Medium | Free web build and reach through angler groups and creators; no store dependence for 0.1 |
| Counter terms do not fit commercial use | Low-Medium | Low | Fallback: no analytics |
| Realistic sims are a small, mid-rated audience; a paid 1.0 may cap reach | Medium | Medium | Decide platform and price evidence at 1.0, not now |

## 13. Open questions

| Question | Who | Blocking? |
| --- | --- | --- |
| Which spot is first (candidates in section 15)? Confirm on a visit | Owner | Blocks spot data, not simulation work |
| Which 3 species (easy, medium, chase) and their sources? | Owner with data research | Blocks species data |
| Target frame rate, test phone, touch-target sizes, event names | Engineering (phase 2) | Blocks build |
| Art and audio direction | Design (phase 2) | Blocks build |
| GoatCounter hosted terms for commercial use | Legal/owner | Blocks only the counter PR |
| Stop date for the tester round | Owner | Before testers |
| 0.5 exploration: static map or walkable top-down | Owner | At the end of 0.1 |

## 14. Approval

- [x] Owner approved this PRD on 2026-11-11 ("Prd ok"). Phase 2 (design) may start; build follows the phase order in CLAUDE.md.

## 15. Spot shortlist (candidates only)

From general knowledge, not verified in this session; the owner confirms on a visit or replaces them. Criteria (owner): fishable and reachable regularly; 3-4 distinct standing positions; simple, well-known depth and structure.
1. Galata Bridge, Karaköy/Eminönü side (positions along the rail).
2. A Kadıköy/Moda breakwater or pier area.
3. A Bosphorus-side or Black Sea pier or breakwater the owner knows well.

**Chosen (2026-11-11, by Claude at the owner's request: "Sen seç"): candidate 2, a Kadıköy/Moda breakwater or pier area.** Reason: a breakwater gives three naturally different standing positions (inner harbour side, outer face, head) with simple depth and structure; Galata Bridge positions along a rail are too alike. The exact structure is named and confirmed on the owner's visit; the choice is provisional until then.

The slice builds the first confirmed spot; the rest of the 3-5 MVP spots follow after the slice passes (the owner wants a reminder; see `project_status.md`).

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
25. **Approved by the owner** (2026-11-11, reply "Onaylıyorum" to the three points raised in the previous PR): the single network exception in `.claude/rules/security.md` (anonymous counters); the schedule adjustment (8 weeks to a playable slice, tester round after); the spot shortlist as candidates only (owner confirms on a visit). The PRD itself is approved only when the box in section 14 is ticked.
26. **PRD approved** by the owner (2026-11-11). Next task given: the data model (`docs/data_model.md`).
27. **Fight rules (owner, 2026-11-11):** the 90 s fight cap stays even though big fish on light tackle would run longer, with an overmatched-tackle hint (F19); toothy species cut leaders (`teeth` attribute; wire leaders are immune).
28. **First spot and species (provisional):** the owner asked Claude to choose. Spot: a Kadıköy/Moda breakwater or pier area (confirmed on the owner's visit). Species: horse mackerel (easy), bluefish (medium), sea bass (chase), chosen for variety of behaviour; none of their values has been sourced yet. No real data files are written until the owner's visit notes and the licence reads exist. The owner confirms or replaces both choices after the visit.
