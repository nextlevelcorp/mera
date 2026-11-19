# Release checklist

Nothing ships to a store until all four gates are closed and recorded here (spec 6.6). Prepared 2026-11-19 (roadmap R15, part 1): what is already true, what is missing, and which steps need the owner's approval first. Every step that spends money, adds a dependency, changes CI or export settings, touches player data or publishes is the owner's call (CLAUDE.md, NEEDS MY GO-AHEAD FIRST).

Status words: **Done**, **Partial**, **Open**, **Owner** (needs the owner's approval or an item only the owner has).

## Gate 1. Full test pass and audit

| Item | Status | Notes |
| --- | --- | --- |
| Unit tests (228) pass in CI on every pull request | Done | The runner counts assertions only; a `SCRIPT ERROR` inside a test does not fail it. **Owner**: approve a CI step that fails the job on `SCRIPT ERROR` (changes CI) |
| Web build exports and deploys to GitHub Pages | Done | `.github/workflows/ci.yml`; release preset excludes `tests/*` and `debug/*`; "Web Debug" lives under `/debug/` |
| Playthrough in the browser at 1280x720 and a phone landscape size | Partial | Every update is played in a software-GL browser; nothing is measured on a phone |
| Frame rate on the test phones | **Owner** | Last measured after R6 (57 average, 34 worst 1% on the owner's phone). Not measured after the pixel-art world, floats or world audio. Debug menu shows the numbers |
| Save migration check | Done | v1 to v2 test; the old file is copied to `save.json.bak` first |
| Localisation en, tr, es | Done | `test_localisation.gd` fails on a missing key. Spanish common names of species are not checked against a source (`reference_docs.md`) |
| Tester round (5 anglers, 5 non-anglers, `prd.md` 9) | **Owner** | Owner recruits; a stop date comes first (decision D4) |
| Real-device checks of phone motion (iPhone and Android) | **Owner** | Motion works on the owner's iPhone; Android untested, needs a phone |

## Gate 2. Security audit

Findings of the repository scan on 2026-11-19 (a separate thread audits before release):

| Item | Result |
| --- | --- |
| Network calls from the game | None: no `HTTPRequest`, `HTTPClient`, `WebSocket` or `fetch` in `game/` (anonymous counters were declined by the owner, 2026-11-15) |
| Secrets in the repository | None found: no key, token or password strings in `game/`; only `.env.example` (names, no values) is tracked; no keystore or certificate files tracked |
| Debug menu in release builds | Absent: the release preset excludes `debug/*`, and the menu loads only with a debug build or the `mera_debug` feature |
| `JavaScriptBridge` use | Only `game/ui/device_motion.gd` (reads the browser's motion event); a native branch exists in the same file and has never run on a device: see the Android spike |
| Dependencies and actions | Godot 4.4.1 pinned in `.godot-version`; CI Actions pinned to a major version or SHA (`security.md`). No Godot plugins or addons |
| Third-party assets | CC0 only (Poly Haven textures, recorded sounds, generated cues); rows in `reference_docs.md`. Poly Haven licence pages were not opened from the build environment: **Open**, confirm each page before release |
| Player data | Local only (`user://save.json`, IndexedDB on the web). Nothing leaves the device |
| Full audit | **Owner**: a separate security thread runs it before release; this table is its starting point |

## Gate 3. Store and legal

| Item | Status | Notes |
| --- | --- | --- |
| Developer accounts | **Owner** | Google Play: a one-time fee. Apple Developer Program: a yearly fee. Both cost money |
| Age rating questionnaires | Open | Content: fishing, no violence beyond catching fish, no ads, no purchases, no network. Expect the lowest rating; answer at submission |
| Privacy policy | Open | The truthful short version: the game collects nothing and sends nothing. Needs a public URL and the owner's legal contact |
| Data-safety forms (Play) and privacy labels (App Store) | Open | Answer "no data collected" while the game has no network code; revisit if counters or accounts ever come back |
| Attribution and licence notices | Partial | CC0 needs none; the engine's licence notice (MIT) must be in the credits screen, which does not exist yet. Third-party code in `.claude/skills/` is tooling, not shipped |
| Legal reading of the Tebliğ 6/2 text (article 31 of Law 5846) | **Owner** | Same consultation as the OpenStreetMap question; the in-game "check the official text" line |
| Names, brand, store text and art | Open | The name "Mera" has not been checked for trademark or store collisions |
| Game content labelled | Done | Every record carries a source or `design_fill`; fictional people say so in `data/npcs.json` |

## Gate 4. Owner sign-off

Open. The owner signs after gates 1 to 3 are closed and recorded here.

## Order of work for R15

1. **Part 1 (this document and `android_spike.md`)**: what is needed, nothing installed or changed. Done 2026-11-19.
2. **Part 2, the Android spike** (owner approved 2026-11-19; the preset is in; the SDK needs `dl.google.com` on the network list and there is no phone or emulator to run it): see `android_spike.md`.
3. **Part 3, iOS**: needs a Mac with Xcode (the owner's machine) and the paid account. Not before the Android spike works.
4. **Part 4, the gates above**, one by one, each recorded here.
