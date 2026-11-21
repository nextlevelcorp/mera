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

## Jurisdictions in `game/data/jurisdictions.json` (2026-11-20, R17)
| Source | Licence or terms | How used |
| --- | --- | --- |
| BOJA: Decreto 205/2023 (Andalusia) | Official gazette | Andalusia's rule: EU sizes apply to recreational fishing in inner waters |
| Regulation (EU) 2019/1241 Annex IX | Official EU legal text | Horse mackerel 15 cm where it applies |
| DGRM size table (27.02.2026) and recreational FAQ (2018), Portugal | Government site | Portugal's sizes |
| Normattiva: DPR 1639/1968 | Official legal database | Italy's sizes |
| vgo.gr guide; fishradar.ai | Third-party web pages, read only | Greece, marked unofficial; values cited, text not copied |

## European squid in `game/data/` (2026-11-21)
| Value | Source | Licence or terms |
| --- | --- | --- |
| Name *Loligo vulgaris* Lamarck, 1798 | WoRMS AphiaID 140271 (REST API) | CC BY 4.0 (WoRMS) |
| Mantle length 10.8-39.7 cm, heaviest 755 g, mean 18.2 cm and 166.7 g (n=288, Izmir Bay, Oct-Nov 2003); fished at night | Gökçe, Metin, Aydın and Bayramiç (2005) E.Ü. Su Ürünleri Dergisi 22(3-4): 419-422, https://dergipark.org.tr/tr/download/article-file/57843 | Open-access journal article; values cited, text not copied |
| No legal minimum size | Tebliğ 6/2 (2024/21) Çizelge 7 (not listed: "Diğer türler") | Official gazette |
| Presence at the Galata Bridge, activity, depths, temperatures, diet, the length-weight exponent, fight values, the squid jig and rod, the price | Design fill (owner decision 2026-11-21); GBIF has no occurrence in the Istanbul Strait or the Sea of Marmara (checked 2026-11-21) | Not applicable |

## Picarel in `game/data/` (2026-11-20)
| Value | Source | Licence or terms |
| --- | --- | --- |
| Name *Spicara smaris* | WoRMS AphiaID 126830 | CC BY 4.0 (WoRMS) |
| Length range, length-weight relation, diet | Özpiçak and İbitürk (2024) KMUJENS 6(2): 1-8, https://doi.org/10.55213/kmujens.1478476 | Open-access journal article; values cited, text not copied |
| No legal minimum size | Tebliğ 6/2 (2024/21) Çizelge 7 ("Diğer türler") | Official gazette |

## Legal minimum sizes, second pass (2026-11-20, R17)
| Source | Licence or terms | How used |
| --- | --- | --- |
| Resmî Gazete: Tebliğ 6/2 (2024/21), Çizelge 7 (images), and Tebliğ 2026/26 (PDF), `resmigazete.gov.tr` | Official gazette, public legal text | Horse mackerel 12 cm since 16.09.2026 in `species.json`; facts in `spot_research.md` |
| Tarım ve Orman Bakanlığı, HHGM news 267 (`www.tarimorman.gov.tr`) | Government site | Confirms the date and number of 2026/26 |
| BOE: Real Decreto 347/2011 and Real Decreto 560/1995 (consolidated) | Official gazette, public legal text | Spain's recreational scope and Mediterranean sizes, research only |
| Normattiva: DPR 1639/1968, Articles 87 and 138 to 144 | Official legal database | Italy's sizes and sport-fishing rules, research only |

## Fishing controls design plate (2026-11-20)
`docs/design/tide_instruments.png` is a design reference, not a game asset (not exported). Drawn in code (Pillow) with fonts from the canvas-design skill folder, all SIL Open Font License 1.1: Italiana, Instrument Serif, Jura, DM Mono. The in-game controls (`game/ui/instrument.gd`) are drawn in code with the engine's default font; no font or image was added to the game.

## Galata Bridge look in the top-down world (2026-11-18)
All pixel art is drawn in code for this project (`game/ui/pixel_art.gd`, `game/scenes/world/world_painter.gd`); no image is downloaded. The landmarks (Galata Tower, New Mosque, Spice Bazaar, the T1 tram line across the bridge, city ferries, simit carts, the pigeons of Eminönü) are drawn from general knowledge of the place, simplified and placed for recognition; layout and distances are design fills. Reference for the place: https://en.wikipedia.org/wiki/Galata_Bridge (not opened from the build environment). Place names on signs are proper names (Karaköy, Eminönü, Mısır Çarşısı).

## Float rig and bait (2026-11-18)
`game/data/tackle/baits.json` (shrimp, live horse mackerel), `floats.json` and the `float_*` rod, reel, line and leader records: all values are game-design fills (no source read). Shrimp price in `shop.json` is a design fill. Only legal-size horse mackerel can be live bait: the legal length comes from `species.json` (sourced there).

## Quests (2026-11-18)
`game/data/quests.json`: asks, texts and rewards are game-design fills. The only real-world value they use is the legal minimum length of each species, read from `species.json` (sourced there).

## People in the world (2026-11-17)
`game/data/npcs.json`: the anglers and vendors are fictional; names, looks and routines are design fills, not real people.

## Shop prices (2026-11-17)
`game/data/shop.json`: every price is a game-design fill (labelled in the file); no source for real fish or tackle prices was used.

## CC0 PBR textures in `game/assets/3d/` (2026-11-17, roadmap R7)
Owner approved CC0 assets (2026-11-15) and added the hosts `polyhaven.com`, `dl.polyhaven.org` and `ambientcg.com` to the network list (2026-11-17). Fetched with `scripts/fetch_polyhaven_textures.py` from `dl.polyhaven.org` (the only host of those that served files to the build environment). Each set is the 1k JPG diffuse, OpenGL normal and roughness map, shrunk to 512 px and stored as lossy WebP; each folder has a `source.txt`. **Licence evidence:** Poly Haven's licence policy (https://polyhaven.com/license) puts every asset under CC0 1.0; the build environment could not open `polyhaven.com` (HTTP 403) so the individual asset pages were not read. Before a release, open each page below and confirm CC0.

| Asset (folder) | Source page | Author | Licence | Used for |
| --- | --- | --- | --- | --- |
| `concrete_pavement` | https://polyhaven.com/a/concrete_pavement | per asset page (not read) | CC0 1.0 per Poly Haven policy | Bridge deck paving and coping strip |
| `metal_plate` | https://polyhaven.com/a/metal_plate | per asset page (not read) | CC0 1.0 per Poly Haven policy | Bridge rail and lamp standards (tinted dark green) |
| `cobblestone_floor_04` | https://polyhaven.com/a/cobblestone_floor_04 | per asset page (not read) | CC0 1.0 per Poly Haven policy | Quay apron |
| `rough_concrete` | https://polyhaven.com/a/rough_concrete | per asset page (not read) | CC0 1.0 per Poly Haven policy | Quay coping |
| `rusty_metal_02` | https://polyhaven.com/a/rusty_metal_02 | per asset page (not read) | CC0 1.0 per Poly Haven policy | Quay bollards |
| `stone_wall_04` | https://polyhaven.com/a/stone_wall_04 | per asset page (not read) | CC0 1.0 per Poly Haven policy | Quay wall below the waterline |

Quaternius (https://quaternius.com, CC0 per its pack pages): the site is reachable from the build environment but every pack download is on `drive.google.com` or `quaternius.itch.io`, which are not on the network list, so nothing was downloaded (checked 2026-11-17 over all 84 pack pages).

ambientCG: its API answers (200) from the build environment but its files redirect to `acg-download.struffelproductions.com`, which the network list does not include (HTTP 403), so no ambientCG file is used. A first-person hand model: no CC0 source is reachable (Poly Haven has none; model sites are not on the list); see `project_status.md`.

## 3D sea textures (2026-11-15)
No image, model or HDRI asset is used yet: the ripple normal map, the cloud and noise map and the sea mesh are generated in code (`game/ui/sea/sea_maps.gd`, Godot's `FastNoiseLite`, MIT as part of the engine). The owner approved CC0 assets for the later 3D steps (2026-11-15); each one gets a row here when it is committed.

## Fight screen demo data (2026-11-13)
`game/data/demo/` holds invented species, spot, angler and tackle records copied from the test fixtures; every record is `design_fill: true` and names use `DEMO_` keys. No external source, no licence to record. Replace with sourced records before 0.1.

## Generated sound cues (2026-11-13)
`game/ui/audio/cue_synth.gd` computes the nibble, take and landed cues from formulas at start-up (filtered noise and sine partials, fixed seeds). No external source, no file, no licence. They are generated sound, not recordings of a place.
Added 2026-11-18 (R13), the same way: `tram_bell`, `ferry_horn`, `gull`, `step`, `step_stone` and the looping `traffic` rumble for the top-down world. Generated, not recorded at the Galata Bridge; the sea and wind beds there reuse the CC0 recordings listed below.

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
| `cast_swish.ogg` | https://opengameart.org/content/swish-bamboo-stick-weapon-swhoshes | qubodup (own recording of a bamboo stick) | CC0 | 5.1-5.7 s of the montage preview; owner go-ahead 2026-11-14 |
| `drag_click.ogg` | https://opengameart.org/content/mechanical-sounds (`rattle1.wav`) | BMacZero | CC0 | mono; looped and pitched with line-out speed in the game |
| `rod_creak.ogg` | https://opengameart.org/content/tree-creaking | AntumDeluge, cleaned from a recording by Department64 (original page not checked) | CC0 as stated on the page | first 2.5 s |
| `line_zip.ogg` | https://opengameart.org/content/zipper | AntumDeluge (recording of a jacket zipper) | CC0 | mono |

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
