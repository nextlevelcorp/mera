# Changelog

## Unreleased
- Data layer and catch model: `game/data/schema.json` and `constants.json`, `DataValidator` and `DataStore`, and `CatchModel` (stages 0-4 and 6, closed-form fight) in `game/sim/`; illustrative fixtures and 18 new tests (26 in total) that reproduce the three worked examples of `data_model.md`. Not wired into the scenes. Cast distance, shoal follow-up and the real-time fight are not ported.
- Docs: PRD approved by the owner (2026-11-11). Data model proposal in `docs/data_model.md` (schemas, staged catch resolution with formulas, three worked examples, data sources and licences) with companion workbook `docs/data_model_examples.xlsx`.
- Docs: PRD draft v2 in `docs/prd.md` (problem, players, goals and non-goals, user stories, measurable funnel, feature list with acceptance criteria for 0.1 and 0.5, success metrics, schedule, risks, approvals ledger). `security.md` allows one network exception: anonymous event counters.
- Docs: PRD decision log started in `docs/prd.md` (interview answers on measurement, top-down scope, vibration, platform, round length, first cast, pass bar, reach, technique, fight input).
- Docs: owner decisions on scope, first audience and spot data sources recorded in `project_status.md`.
- Docs: phase 0 market research in `docs/research.md`, second pass with primary Steam, Play, App Store and fws.gov data (market evidence moderate, concept demand weak; corrections to the first pass listed; board stress test included).
- Repository skeleton: `.claude/rules`, `.env.example`, docs files, CI workflow (test, export, deploy to GitHub Pages), cloud setup script.
- CI: `changelog` job fails a PR that changes `game/`, `scripts/` or `.github/` without touching `docs/changelog.md`.
- CLAUDE.md: added build, test and export commands.
- Godot 4.4.1 project: 1280×720 canvas_items/expand, landscape only, GL Compatibility, localisation table (en, tr, es), `DeviceGuard` portrait screen, single-threaded web export preset, headless test runner with 8 tests.
