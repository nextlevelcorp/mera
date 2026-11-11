# Workflow and commands
Run from the repository root. `GODOT` is the Godot 4.4.1 binary (version pinned in `.godot-version`).

- Import (first run, or after adding assets): `$GODOT --headless --path game --import`
- Unit tests: `$GODOT --headless --path game --script res://tests/run_tests.gd` (exit code 1 on failure)
- Web export: `mkdir -p build/web && $GODOT --headless --path game --export-release Web`
- Serve locally: `python3 -m http.server -d build/web 8000`

Rules:
- Branch from main, one draft PR per thread. Never merge, force-push, or change CI or export settings without approval.
- Played the flow in the web build and report what you saw, including what did not work.
- After a milestone or major addition update `docs/architecture.md`, `docs/changelog.md`, `docs/project_status.md`, `docs/reference_docs.md` in the same PR.
- No gameplay code before phase 1 is approved.
