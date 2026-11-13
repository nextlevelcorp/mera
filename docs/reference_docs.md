# Reference docs: external sources, data sources and licences

| Name | Address | Used for | Licence | Attribution |
| --- | --- | --- | --- | --- |
| Godot Engine 4.4.1 | https://godotengine.org | Game engine, export templates | MIT | Not required in game; keep the notice in credits |
| godot-builds releases | https://github.com/godotengine/godot-builds | Godot binary and templates in CI and setup script | MIT (same as engine) | n/a |
| `game/icon.svg` | this repo | Placeholder project icon, drawn for this project | project's own | n/a |
| Founder skill pack (Jakeschincariol/founder-skill v1.0) | https://github.com/Jakeschincariol/founder-skill | `founder-board` used for the phase 0 stress test; installed per session, not vendored in this repo | MIT | Not required; no network calls or hooks (source read before use) |
| Phase 0 market research sources | see Sources in `docs/research.md` | Market and player-sentiment evidence | Facts and short paraphrase only; no third-party text or data reused | n/a |
| GoatCounter (candidate, not used yet) | https://www.goatcounter.com | Anonymous event counters | Open source, modified EUPL 1.2 (self-hostable); hosted service terms for commercial use not verified | None needed for the library; check hosted terms before use |
| Candidate data sources for species and spots | see `docs/data_model.md` section 7 | Proposed only; nothing imported | Each row lists the licence as found in search summaries on 2026-11-11; none read in full | Read each source's terms before its data is committed, then add a row here |
| Sound sources (none used yet) | see `docs/audio_sources.md` | Shortlist of CC0 and public-domain recordings from opengameart.org and commons.wikimedia.org (scanned 2026-11-12); freesound.org blocks automated clients | CC0 or public domain per source page; nothing committed | Add one row per file here when it is committed |

Add every data, art, audio and tool source here with its licence before it is used (spec 5.4, 7.8).

## Fight screen demo data (2026-11-13)
`game/data/demo/` holds invented species, spot, angler and tackle records copied from the test fixtures; every record is `design_fill: true` and names use `DEMO_` keys. No external source, no licence to record. Replace with sourced records before 0.1.

## Generated sound cues (2026-11-13)
`game/ui/audio/cue_synth.gd` computes the nibble, take and landed cues from formulas at start-up (filtered noise and sine partials, fixed seeds). No external source, no file, no licence. They are generated sound, not recordings of a place.

## Recorded sounds in `game/audio/` (2026-11-13, owner listened and approved on 2026-11-13)
Converted to mono 22.05 kHz Ogg Vorbis; cuts and loops made with ffmpeg and numpy. All CC0 as shown on the source page on 2026-11-12/13. None is a recording of an Istanbul shore; in the game they are generic recordings.

| File | Source page | Author | Licence | Edit |
| --- | --- | --- | --- | --- |
| `wave_01.ogg` … `wave_04.ogg` | https://opengameart.org/content/beach-ocean-waves | jasinski (extracted from Freesound 18363, not checked) | CC0 | mono, normalised |
| `wind_loop.ogg` | https://opengameart.org/content/mild-wind-background-noise | Bashar3A | CC0 | 12.5-16.5 s cut, 0.6 s crossfade loop |
| `wind_gust.ogg` | https://opengameart.org/content/short-wind-sound | remaxim | CC0 | mono, normalised |
| `reel_loop.ogg` | https://opengameart.org/content/fisheefects | Memoraphile, You're Perfect Studio | CC0 (also offered as CC-BY 4.0 and OGA-BY 3.0; CC0 used) | 0.5-8.0 s loop, pitch follows the line in the game |
| `splash.ogg` | https://opengameart.org/content/fisheefects | Memoraphile | CC0 | first 1.0 s |
| `splash_heavy.ogg` | https://opengameart.org/content/ocean-splash | Thimras | CC0 | mono, normalised |
| `lure_drop.ogg` | https://opengameart.org/content/object-dropping-into-water-0 | angeloyazar | CC0 | 0.15-0.65 s (first drop), gain raised |
