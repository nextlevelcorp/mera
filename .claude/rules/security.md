# Security checklist (applies to every change; a separate thread audits before release)
- No secrets in the repository, the CI logs or the exported game. Anything in the web export is public.
- Only `.env.example` (names, no values) is tracked. CI values go in GitHub Secrets.
- No new dependency, plugin or GitHub Action without the owner's approval; pin Actions to a major version or SHA, pin tools to an exact version.
- No network calls from the game in the MVP. Anything that touches player data needs the owner's approval first.
- The debug menu must be absent from release builds.
