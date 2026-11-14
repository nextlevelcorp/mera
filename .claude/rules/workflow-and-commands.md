# Workflow and commands
Run from the repository root. `GODOT` is the Godot 4.4.1 binary (version pinned in `.godot-version`).

- Import (first run, or after adding assets): `$GODOT --headless --path game --import`
- Unit tests: `$GODOT --headless --path game --script res://tests/run_tests.gd` (exit code 1 on failure)
- Web export: `mkdir -p build/web && $GODOT --headless --path game --export-release Web`
- Serve locally: `python3 -m http.server -d build/web 8000`

Rules:
- Branch from main, one PR per update. Standing approval (2026-11-14): merge each update yourself once tests pass, CI is green, the web build was played and reported, and nothing in it needs the owner's go-ahead (CLAUDE.md, NEEDS MY GO-AHEAD FIRST). Squash-merge, then merge main back into the working branch.
- Never without approval: force-push, rewrite published history, change CI or export settings; updates that need a go-ahead stay draft PRs.
- Played the flow in the web build and report what you saw, including what did not work.
- After a milestone or major addition update `docs/architecture.md`, `docs/changelog.md`, `docs/project_status.md`, `docs/reference_docs.md` in the same PR.
- No gameplay code before phase 1 is approved.
