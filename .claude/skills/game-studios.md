<!--
Summary written for Mera from https://github.com/Donchitos/Claude-Code-Game-Studios at commit abc0de7
(CLAUDE.md, .claude/rules/gameplay-code.md, test-standards.md, shader-code.md, ui-code.md, skill
descriptions of qa-plan, smoke-check, perf-profile, playtest-report, regression-suite), and the QA
release checklist of https://github.com/majidmanzarpour/threejs-game-skills (skills/threejs-qa-release)
at commit 8286774, both fetched 2026-11-14. Copyright (c) 2026 Donchitos and (c) 2026 Majid Manzarpour,
MIT License. Only web game development, the game loop and QA are summarised; the studio's 49-agent
structure and its ask-before-every-write protocol are not adopted. See THIRD_PARTY_NOTICES.md.
-->

# Game studio standards: web game, loop, QA

Read for: gameplay code, the game loop, test plans, and every QA pass before a PR is marked ready.

## Gameplay code

- Every gameplay value comes from a data file with a schema, never a literal in a scene script.
  (Mera: `game/data/*.json`, `constants.json`.)
- Time-dependent logic is frame-rate independent: fixed-step simulation with an accumulator and a
  clamped frame time, never raw per-frame increments. (Mera: `FightSim`, `WaitSim`, 30 Hz.)
- Simulation never references UI. The UI reads state and sends input; cross-system news travels by
  events (Godot signals).
- State machines have an explicit list of states and transitions, written down next to the code.
- Logic is separated from presentation so it is unit-tested headless.
- Each feature names the design doc or PRD item it implements in a comment.
- No static singletons for game state; pass dependencies in.
- All randomness goes through a seeded generator so a seed reproduces a run.

## Tests

- Test names say the scenario and the expected result.
- Arrange, act, assert. No filesystem, network or clock in unit tests unless the test is about them;
  integration tests clean up after themselves.
- Performance tests state a threshold and fail when it is exceeded.
- Every bug fix gets a regression test, and the test is watched failing against the unfixed code
  before it is trusted.

## QA pass (before a PR is ready, after any visual or gameplay change)

1. Build: tests pass, web export builds.
2. Open the build in a browser (Playwright). Capture console, page and network errors.
3. Confirm the canvas is not blank and shows varied pixels.
4. Capture active play, not only the title screen, at 1280×720 and one phone landscape size.
5. Exercise the main input, progress through the loop, fail and retry, and whatever changed most.
6. Check HUD text fit with the longest language (Spanish is often longest), safe areas, touch targets.
7. If audio changed: first-tap unlock, cue triggers, ambience start and stop, no decode errors.
8. If animation changed: capture a short unpaused sequence, not one frame.
9. Report what was seen, including what did not work, with screenshots.

## Smoke and regression

- A smoke check runs the automated suite and the critical path (title, cast, bite, fight, land, log).
  A failed smoke check means the build is not ready for the owner's phone test.
- Keep a regression list mapping PRD critical paths to tests; flag fixed bugs without a test.

## Performance

Profile one fixed scenario: baseline frame time (average and worst 1%), classify the bottleneck
(CPU simulation, draw calls, fragment cost, memory), change one thing, re-measure the same scenario,
then check that visuals and playability held. Mera budget: 30 fps floor, 60 goal on the test phones.

## Playtests

Turn tester notes into a structured report: what they tried, where they got stuck, what they said
about believability, and whether they would play again tomorrow (PRD section 9).
