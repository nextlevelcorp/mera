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

## Spot and species research sources (2026-11-13, `spot_research.md`)
No value from these is in `game/data/` yet.

| Source | Licence or terms | How used |
| --- | --- | --- |
| Wikidata (SPARQL and entity data; items listed in `spot_candidates_tr.csv`) | CC0 (structured data) | Names and coordinates of piers, breakwaters, capes, lighthouses and ports; the Q-number is the source of each row |
| MGM, Marmara sea-water temperature 2025 PDF | Terms of use not found | Twelve monthly means cited as facts with the source; no table copied |
| Zengin (2009), SÜMAE Yunus Araştırma Bülteni 9(3), via DergiPark | Article copyright | Facts cited (species, seasons, angler counts); no text copied |
| Öndes (2019), Anadolu Çev. ve Hay. Dergisi 4(3), via DergiPark | Article copyright | Percentages cited; no table copied |
| WoRMS REST API | WoRMS terms; names cited | Valid scientific names and AphiaIDs |
| GBIF occurrence API | Per record (CC0, CC BY, CC BY-NC) | Counts only; no record copied |
| Search summaries of yemek.com, ensonhaber.com, istanbul.com, rudaw.net | Page copyright; pages not opened | Leads only, marked "S" |

## Galata Bridge data in `game/data/` (2026-11-13)
Single values entered by hand with their citation in each record's `provenance`; no table or text copied.

| Value | Source | Licence or terms |
| --- | --- | --- |
| Coordinates, length | Wikidata Q81523 | CC0 |
| Monthly water temperature | MGM Marmara 2025 PDF | Terms not found; facts cited |
| Angler pressure; seasons of horse mackerel, çinekop, bonito | Zengin (2009), SÜMAE Yunus Araştırma Bülteni 9(3) | Article copyright; facts cited |
| Legal minimum sizes (13, 18, 25 cm), bonito closed season, 5 kg daily limit | Communique 6/2 (2024/21), Resmî Gazete 32629, Çizelge 7 and article 15(4) | Official text; values cited. Article 31 reading still for the legal consultation |
| Horse mackerel length range and LW (5.3-18.8 cm, W=0.00758 L^3.0311); Marmara minimum 9.2 cm | Van, Gümüş & Süer (2019) NESciences 4(1); Dürrani (2023) JAES 8(3) | Article copyright; values cited |
| Bluefish length range and LW (12.3-43.7 cm, W=0.0107 L^2.9574) | Bal, Yanık & Türker (2015), South Marmara | Article copyright; values cited |
| Bonito length range and LW (17.7-63.0 cm FL, W=0.01 FL^3.085) | Kahraman et al. (2014) as tabled in Genç et al. (2025) Turk. J. Marit. Mar. Sci. 11(1) | Article copyright; values cited (the 2014 paper itself was not opened) |
| Valid names (AphiaID 126820, 151482, 127021) | WoRMS REST API | WoRMS terms |

## Agent skills and tooling (2026-11-14, owner request)
Files in `.claude/skills/`; licences and copyright lines in `.claude/skills/THIRD_PARTY_NOTICES.md`. None ships in the game export.

| File | Source | Licence | Use |
| --- | --- | --- | --- |
| CLAUDE.md working principles | github.com/forrestchang/andrej-karpathy-skills @2c60614 | MIT (stated in README) | Paraphrased |
| `caveman.md` | github.com/JuliusBrussee/caveman @b4ee71d | Apache 2.0 | Skill text unchanged, Mera notes added |
| `compound-engineering.md` | github.com/EveryInc/compound-engineering-plugin @ee46dde | MIT | Paraphrased |
| `game-studios.md` | github.com/Donchitos/Claude-Code-Game-Studios @abc0de7; threejs-game-skills | MIT | Paraphrased |
| `threejs-graphics.md` | github.com/scottstts/Threejs-Awesome-Graphics-Agent-Skills @53eb5a2 | MIT | Paraphrased |
| `threejs-game.md`, `rapier.md` (part) | github.com/majidmanzarpour/threejs-game-skills @8286774 | MIT | Paraphrased |
| `founder-skill.md` | github.com/jakeschincariol/founder-skill | MIT | Paraphrased index |
| `design-skills.md` | Anthropic frontend-design skill | Apache 2.0 | Paraphrased; the requested repository was not named |
| `gltf-transform.md`, `rapier.md` (part) | gltf-transform.dev; rapier.rs | MIT; Apache 2.0 | Compiled from general knowledge |
| `.mcp.json` firecrawl | npm firecrawl-mcp 3.35.0 | MIT | Agent tooling; the Firecrawl service needs an API key (free and paid plans) |
