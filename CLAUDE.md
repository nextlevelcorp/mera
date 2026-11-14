# CLAUDE.md

## ALWAYS ON

### Working principles
Adapted from the Karpathy-inspired guidelines at https://github.com/forrestchang/andrej-karpathy-skills (MIT, see .claude/skills/THIRD_PARTY_NOTICES.md). They bias toward caution over speed; for trivial tasks, use judgment.

1. Think before coding. Do not assume, do not hide confusion, surface tradeoffs. State assumptions; if several readings exist, present them instead of picking silently; if a simpler approach exists, say so; if something is unclear, stop, name it and ask.
2. Simplicity first. The minimum code that solves the problem: no features beyond the request, no abstractions for single-use code, no unrequested configurability, no error handling for impossible cases. If 200 lines could be 50, rewrite.
3. Surgical changes. Touch only what the task needs. Do not "improve" adjacent code, comments or formatting; match the existing style; mention unrelated dead code instead of deleting it; remove only what your own change made unused. Every changed line traces to the request.
4. Goal-driven execution. Turn tasks into verifiable goals ("fix the bug" becomes "write a test that reproduces it, then make it pass"). For multi-step work, state a short plan with a check per step, and loop until each check passes.

### Caveman mode (token saving)
Chat replies are terse: answer first, then reason, then next step. No greeting, hedging, recap or closing offer. Keep every technical fact, number, path, command and error exact; never drop a negation. Still reply in Turkish. Write full, normal sentences for: security warnings, irreversible actions, questions and options to the owner, and everything persisted (code, comments, commits, docs, data, PRs, in-game strings). Full rules: .claude/skills/caveman.md.

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

ACTIVE PLUGINS (how to use them)
- New feature: use the superpowers or feature-dev workflow: plan first (scope in, out, done-when; files; tests), then code. Large work also follows .claude/skills/compound-engineering.md (brainstorm, plan, work, simplify, review, compound).
- HUD and UI code: apply the frontend-design plugin and .claude/skills/design-skills.md.
- Any visual or gameplay change: open the web build in the browser with playwright, check console errors, take screenshots of active play at 1280x720 and one phone landscape size, and report what was seen (QA pass in .claude/skills/game-studios.md).
- After large code changes: review the diff with code-review against .claude/skills/compound-engineering.md before the PR is marked ready.
- Current documentation or web data: use firecrawl (MCP server in .mcp.json; the key is FIRECRAWL_API_KEY, see .env.example). Record every data source and its licence in docs/reference_docs.md as usual.

CONDITIONAL SKILLS (read the file when the task touches the topic)
- 3D scene, materials, shaders, lighting, water, post-processing: .claude/skills/threejs-graphics.md
- Game architecture, camera, controls, update loop, performance: .claude/skills/threejs-game.md; full skills in https://github.com/majidmanzarpour/threejs-game-skills and https://github.com/scottstts/Threejs-Awesome-Graphics-Agent-Skills
- Studio standards and the game QA process: .claude/skills/game-studios.md
- Physics engine and collisions: .claude/skills/rapier.md
- 3D model compression and .glb/.gltf work: .claude/skills/gltf-transform.md
- Marketing, pricing or launch plans (only when the owner asks a business question): .claude/skills/founder-skill.md

ENGINE NOTE
The game runs on Godot 4.4 (GDScript). The Three.js and Rapier skills hold general rules that also apply to Godot; using Three.js or Rapier.js in the game is an engine change and needs the owner's explicit decision first (see NEEDS MY GO-AHEAD FIRST).
