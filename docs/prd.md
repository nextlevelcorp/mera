# Product Requirements Document

Status: **interview in progress** (phase 1, Definition). This file is the decision log; the full PRD is written once the interview has no open assumptions. Nothing here approves gameplay code: phase 1 needs the owner's explicit approval.

Sources: `project_spec.md`, `research.md`. Decisions below are the owner's, dated 2026-11-11.

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
7. **First spot.** Not chosen yet. Owner lives in Istanbul and fishes with rod and lure, so the owner is the primary domain expert and can visit. Selection criteria still to agree.
8. **Pass bar for the slice.** 5 anglers plus 5 non-anglers: at least 4 of 5 anglers call the fight and line logic believable; at least 6 of 10 testers say they would play again tomorrow. Anonymous counters count as second evidence only with 100 or more visitors.
9. **Reach.** Angler groups (Facebook, Instagram, Telegram) and fishing content creators. Not available: own circle, tackle shops. Open: the first 10 testers need a plan, since the owner's own circle is not an option.
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

## Open (still to ask)
- Owner's hours per week for testing, spot visits and decisions.
- Who recruits the first 10 testers and when (angler groups, creators), and the post text.
- First spot: which one (owner picks against decision 18).
- Species licence and source check (FishBase and similar); regional rules (Turkey, Spain; age rating).
- Anonymous counter service: which one, and the owner's go-ahead (new dependency).
- Art and audio direction: parked for phase 2.
- Accessibility basics and debug menu scope: proposed as PRD defaults (tension never colour-only, readable text sizes; debug menu as in CLAUDE.md), owner to review.
