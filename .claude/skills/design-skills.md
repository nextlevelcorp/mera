<!--
Compiled for Mera on 2026-11-14. The repository named in the owner's request reached this session as a
bare "https://github.com" link, so its rules could not be fetched. Sources used instead: the installed
frontend-design skill (Anthropic, Apache License 2.0; paraphrased), the UI rules of
https://github.com/majidmanzarpour/threejs-game-skills (skills/threejs-game-ui-designer, MIT),
docs/design_direction.md and the PRD. Replace or extend once the intended repository is named.
-->

# UI and UX design (HUD, menus, panels)

Read for: HUD, menus, result and log panels, touch controls, the debug menu's layout, any web page
about the game. Use together with the `frontend-design` plugin.

## Ground it in the subject

Mera is a calm, realistic shore-fishing game at real Istanbul places. The UI should feel like an
angler's instruments: a tension gauge, a line counter, a logbook. Pick details only this subject has
(kilograms on the line, metres out, legal sizes, the time of day at the bridge) and show them as
content, not ornament.

## Hierarchy (in-game)

1. Survival and status: line tension against line strength, strain timer.
2. Objective: distance to the fish, fish visible or not.
3. Feedback: rings, rod bend, splashes, cues (each sound cue has a visual twin, PRD F11).
4. Flavour: place, time, wind.
Calm phases (wait) show little; the fight shows the gauge large (pillar 4: calm, then tense).

## Layout and touch

- Design space 1280×720, landscape. Controls pinned to the corners; thumbs never cover the gauge.
- Touch targets at least 96 px; two-thumb play works with simultaneous touches.
- Safe-area padding on phones; test 1280×720 and one wider phone ratio (844×390).
- Text fits the longest language (check Spanish) at the longest likely value.
- State is shown by shape and position, not colour alone (PRD F8, F18).

## Typography and colour

- One or two type families, clearly distinct roles, a fixed type scale; line length under 80 chars.
- Choose the palette from the scene (sea, dusk, stone, rope), 4 to 6 named tokens; avoid generic
  defaults (cream with terracotta, near-black with one acid accent, identical rounded cards with the
  same grey shadow, all-caps eyebrow labels above every heading).
- A font change needs its licence recorded in `docs/reference_docs.md`.

## Process

1. Plan: palette, type, layout sketch, the one memorable element. Review the plan against the brief
   and remove anything that would look the same in any other game.
2. Build with stable dimensions and pressed, focused and disabled states.
3. Critique with screenshots on both viewports; fix overlaps and clipped text; spend boldness in one
   place and keep the rest quiet.

## Copy

Short, concrete, in the player's words. Every string goes through `translations.csv` (en, tr, es).
Errors say what happened and what to do. No exclamation marks unless something really happened
(a landed fish earns one).
