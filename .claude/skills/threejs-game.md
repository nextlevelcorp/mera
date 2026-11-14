<!--
Summary written for Mera from https://github.com/majidmanzarpour/threejs-game-skills at commit 8286774
(skills: threejs-game-director, threejs-gameplay-systems and its references/physics-engine-selection.md,
threejs-debug-profiler and references/debug-playbook.md, threejs-game-ui-designer, threejs-qa-release),
fetched 2026-11-14. Copyright (c) 2026 Majid Manzarpour, MIT License. Paraphrased.
Full skills: https://github.com/majidmanzarpour/threejs-game-skills and
https://github.com/scottstts/Threejs-Awesome-Graphics-Agent-Skills. See THIRD_PARTY_NOTICES.md.
-->

# Game mechanics, architecture, camera, controls, loop, performance

Read for: game architecture, the update loop, camera, input and controls, mechanics, performance.

**Mera context.** The game runs on Godot 4.4; the stack below (TypeScript, Vite, Three.js) applies only
if the owner approves an engine change. The design, loop and performance rules apply either way.

## Design before building

- **Design brief**: the player promise in one sentence, the target feeling, the primary verb, what the
  player repeats every 5 to 30 seconds, what changes over 1 to 5 minutes.
- **Core loop contract**: "Player does [verb] to achieve [objective] while [pressure] creates risk;
  success gives [reward], failure causes [cost or retry]". Prove every clause in code through real
  input. (Mera: cast to get a bite while tension threatens the line; landing fills the log; a break
  costs the fish.)
- **Encounter plan**: what the camera can and cannot see, the first decision, first threat, first
  reward, how the challenge escalates.

## Build

1. Inspect the existing structure, loop, input, camera, state and UI before adding anything.
2. Keep small ownership boundaries: core, game, entities, systems, assets, ui, tests.
3. Build in playable increments: input, state, feedback, HUD and audio hooks, diagnostics.
4. Tune feel: acceleration, camera follow and field of view, impact feedback, restart speed.
5. Keep hot paths allocation-free; make update order explicit.
6. Route all gameplay randomness through a seeded generator so tests stay deterministic.

## Update order and timestep

Input intents, then fixed-step simulation (accumulator with a clamped frame time), then game state
and collisions, then VFX, camera and UI, then render. Sync render transforms from simulation in
exactly one place.

## Camera and controls

- The camera never hides the next decision; it must show the line, the rod tip and the water near
  the fish (Mera pillar 2).
- Touch targets at least 96 px in the 1280×720 design space, pinned to corners; two-thumb play needs
  raw multitouch, not mouse emulation.

## Typical failures

A static demo instead of a playable loop; mechanics bolted onto a scene built first; a loop described
but not provable through input; state changes that never reach UI, audio or VFX; abstractions built
before a mechanic needed them; camera lag that hides the next decision.

## Debugging and profiling

- Blank canvas: check the console, the render loop, camera clipping and canvas size, in that order.
- Profile one fixed scenario: baseline frame time, draw calls, triangles, textures, heap, bundle size;
  classify the bottleneck (CPU, draw, fragment, vertex, memory, network); change one thing; re-measure.
- Keep a diagnostics object (fps, draw calls, body counts) readable from tests and the debug menu.

## UI and HUD

Hierarchy: survival and status (tension), then objective (distance, fish state), then feedback, then
flavour. Stable dimensions, safe-area padding, text that fits the longest language, pressed and
disabled states. UI reads game state; it never duplicates game rules.

## Release check

Production build, debug tools gated out, static-host base paths, bundle and asset size reviewed,
active play captured on desktop and phone viewports (see `game-studios.md`).
