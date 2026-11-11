PROJECT
Mera is a realistic shore-fishing RPG set at real places. Phone-first web build now, native iOS and Android later. Godot 4.4, GDScript. Repository: nextlevelcorp/mera. The full specification is docs/project_spec.md; read it before any design or code decision. If the spec and a task disagree, stop and ask.

HOW TO WORK WITH ME
- Reply to me in Turkish. Code, comments, commit messages, docs, database content and in-game source strings are English.
- Ask instead of assuming. If a requirement is missing or two requirements conflict, list the options with a recommendation and wait.
- When we brainstorm or research, think widely and do not self-censor ideas. When we build, hold a strict scope: every task states what is in, what is out, and how we will know it is done. Propose the scope yourself unless I say otherwise.
- Tell me plainly when an idea is weak, expensive or risky. I want the reason, not agreement.

PHASES (do not skip ahead)
0. Discovery: market and competitor research, player pain points, signs of product-market fit.
1. Definition: PRD, player funnel, MVP scope, versioning plan.
2. Design: game systems, data model, architecture, art and audio direction.
3. Build: vertical slice first (one spot, a few species, full cast-bite-fight-land loop), then widen.
4. Release gates: full playtest, security audit, store and legal checklist.
No gameplay code before phase 1 is approved by me.

DESIGN PILLARS (reject work that breaks one)
1. Real places, honestly sourced. Every spot, species list and tip carries a source, or is labelled as a game-design fill.
2. Realism you can read. Outcomes come from depth, feeding time, tackle match and line tension, and the screen always shows enough to reason about them.
3. A living shore. Motion follows Nature of Code principles: forces, springs, particles, steering, oscillation, noise.
4. Calm, then tense. Walking and waiting are relaxed; the bite and the fight are short and intense.
5. Collection and mastery, not hypercasual one-tap rounds.

ENGINEERING RULES
- Branch from main. One draft pull request per thread. Never merge, force-push, or change CI or export settings without my approval.
- Simulation logic is deterministic and separated from rendering, so it can be unit-tested headless.
- Game data lives in data files with a schema and a source field, never hard-coded in scene scripts.
- Every user-facing string goes through the localisation table (en, tr, es). English is the source language.
- Web export is single-threaded and must hold a stable frame rate on a mid-range phone. Measure before and after any visual feature.
- No secrets in the repository or in the exported game. Anything shipped to the browser is public.

DEFINITION OF DONE
- Tests pass and the web export builds.
- You played the changed flow yourself in the web build and say what you saw, including what did not work.
- Any flow I need to check is reachable from the in-game debug menu (jump to spot, set time and weather, force a bite, pick a species). Debug menu is compiled out of release builds.
- After a milestone or a major addition, update docs/architecture.md, docs/changelog.md, docs/project_status.md and docs/reference_docs.md in the same pull request.
- Final message: what changed, how it was verified, what is still open.

WHEN BLOCKED
If a repository, secret, connector, asset or licence is missing, say exactly what is missing in your first message and stop. Do not mock, substitute or guess.

NEEDS MY GO-AHEAD FIRST
New dependencies or plugins, anything that costs money, licence choices for data or assets, changes to scope or pillars, anything touching player data, and release steps.

COMMANDS (run from repo root; GODOT = Godot binary, version pinned in .godot-version)
- Import: $GODOT --headless --path game --import
- Test: $GODOT --headless --path game --script res://tests/run_tests.gd
- Web export: mkdir -p build/web && $GODOT --headless --path game --export-release Web
- Serve: python3 -m http.server -d build/web 8000
- Cloud setup: scripts/install_godot.sh installs Godot and the web templates.
