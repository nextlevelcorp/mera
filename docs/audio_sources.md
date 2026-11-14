# Audio sources: scan of free recordings

**Status (2026-11-13):** the owner listened to the shortlist and approved it; ten files are in `game/audio/` (see `reference_docs.md`). Second scan for the gaps (cast, drag clicker, rod creak) below, waiting for the owner's choice.

**Earlier status:** Shortlist for the owner to listen to, 2026-11-12. No audio file is in the repository and nothing is wired into the game. A file is committed only after the owner has heard it and its row is copied into `reference_docs.md`.

Scope: sounds for the 0.1 slice as listed in `design_direction.md` section 4 (ambient waves and wind, reel, splash, bite cue). Owner decision: free real recordings first; a paid service is the fallback and needs a separate go-ahead.

## What was scanned

| Site | Result |
| --- | --- |
| opengameart.org | **Reachable.** Searched sound effects filtered to CC0 for: waves, ocean, wind, fishing, reel, splash, water, seagull, ratchet, click. 115 unique entries; 12 candidate pages opened and their licence read from the page itself |
| commons.wikimedia.org | **Partly reachable.** The API answered some searches and rate-limited others (sea waves, seagulls harbour, waves breakwater got no result). 210 audio files listed, licence read from the API metadata. Downloads from upload.wikimedia.org were refused with an error page, except one file |
| freesound.org, cdn.freesound.org | **Not reachable:** HTTP 403 to automated clients, on every request. Not scanned. Two OpenGameArt entries are extracts of Freesound files; their original Freesound pages could not be checked |

Limits: nobody has listened to any file. Duration, format and level below were measured with ffprobe and ffmpeg on the downloaded files; whether a file sounds good, loops cleanly, or is a recording at all rather than a synthesised effect was **not** judged. None of these recordings is of the Istanbul spot, so in the game they are labelled as generic recordings, not as the sound of the place.

## Shortlist

Licence as shown on the source page on 2026-11-12. "Measured" files were downloaded to a scratch folder and analysed, then left out of the repository.

| Use | File | Source page | Licence | Author | Measured | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Ambient waves | `wave_01` to `wave_04` (Alki beach) | https://opengameart.org/content/beach-ocean-waves | CC0 | jasinski | FLAC, 44.1 kHz stereo, 2.3-4.0 s each, mean about -30 dB | Four single waves; can be layered at random to follow the chop value. Page says they are extracted from Freesound sound 18363, which could not be checked |
| Ambient waves | `wave_01` to `wave_04` | https://opengameart.org/content/water-waves | CC0 | transitking | FLAC, 44.1 kHz stereo, 1.8-3.2 s each | As above; extracted from Freesound sound 11505, not checked |
| Ambient water (calm) | `VistulaShort_0.mp3` | https://opengameart.org/content/sea-and-river-wave-sounds | CC0 | RandomMind | MP3, 300 s, 12 MB | Author states it is their own recording of the Vistula river. River, not sea. Needs trimming to a short loop and re-encoding; 12 MB is too large for the web build |
| Ambient waves | `Ocean Waves on a Tropical Beach.ogg` | https://commons.wikimedia.org/wiki/File:Ocean_Waves_on_a_Tropical_Beach.ogg | CC0 | Jarrod stanley | Not downloaded (17.7 MB per the API) | Needs trimming |
| Ambient shore | `On a pebble beach.ogg`, `Water over rocks as tide recedes.ogg` | https://commons.wikimedia.org/wiki/File:On_a_pebble_beach.ogg and https://commons.wikimedia.org/wiki/File:Water_over_rocks_as_tide_recedes.ogg | Public domain | earthcalling | Not downloaded (1.2 MB each per the API) | The second fits a rocky breakwater |
| Wind | `wind background noise 2.wav` | https://opengameart.org/content/mild-wind-background-noise | CC0 | Bashar3A | WAV, 44.5 s, 15.7 MB, mean -21 dB | Page says the wind gets stronger over time and bags rustle in the background; only a clean section is usable |
| Wind | `short wind sound.wav` | https://opengameart.org/content/short-wind-sound | CC0 | remaxim | WAV, 4.2 s, quiet (mean -40 dB) | Short gust |
| Reel | `reel.wav` | https://opengameart.org/content/fisheefects | CC0 (also offered as CC-BY 4.0 and OGA-BY 3.0; CC0 chosen) | Memoraphile, You're Perfect Studio | WAV, 48 kHz 24-bit stereo, 9.0 s | The only reel sound found on any site. Made for a game jam; whether it is a recording of a real reel is not stated |
| Splash | `splash.wav` | https://opengameart.org/content/fisheefects | CC0 (as above) | Memoraphile | WAV, 2.2 s | |
| Splash | `cannon_miss_0.ogg` | https://opengameart.org/content/ocean-splash | CC0 | Thimras | OGG, 1.6 s, loud (peak -0.5 dB) | A heavy splash; suits a big fish thrashing |
| Lure landing | `water_drops_1.ogg` | https://opengameart.org/content/object-dropping-into-water-0 | CC0 | angeloyazar | OGG, 7.0 s, very quiet (mean -52 dB) | Needs gain and trimming |
| Gulls (optional) | `Gull 1.ogg`, `Gull 2.ogg` | https://commons.wikimedia.org/wiki/File:Gull_1.ogg | Public domain | avphillips | Not downloaded | |
| Gulls (optional) | `XC707075 - European Herring Gull` | https://commons.wikimedia.org/wiki/File:XC707075_-_European_Herring_Gull_-_Larus_argentatus.mp3 | CC0 | Sonothèque ADVL | Not downloaded | A species recording from a bird-sound archive |

## Looked at and rejected

| Entry | Reason |
| --- | --- |
| https://opengameart.org/content/solo-seagull-sound-effects (CC0) | The page says the sounds were cut from a third party's video "with full permission". The uploader is not the author, and the permission cannot be checked |
| https://opengameart.org/content/windy-ambient-noise (CC0) | The page describes "atonal notes" mixed in: not a plain wind recording |
| Commons results under CC BY-SA or CC BY | Need attribution or share-alike; 0.1 avoids files that require a credits screen |

## What is still missing

- **A drag or clicker sound under tension** (line running out). One reel file exists, of unknown origin.
- **A cast sound** (rod whoosh, line leaving the spool) and a **line or rod creak**. Nothing found.
- **Any recording of an Istanbul shore.** Nothing found.
- The **bite cue** was always meant to be generated (see `design_direction.md`).

## Assessment

The scan found enough CC0 material for ambient waves, wind and splashes, and one usable candidate for the reel. It did not find the fight sounds that matter most for "calm, then tense": drag under load and the cast. Three ways to close that gap, for the owner to choose:

1. Use the single reel file and vary its pitch with the line-out speed from the simulation. Cheapest; quality unknown until heard.
2. A logged-in person downloads CC0 reel and cast recordings from Freesound by hand (the site blocks automated clients, not people) and sends the links; the licence of each is then recorded.
3. The paid fallback the owner named. It costs money and gives generated, not recorded, sound.

Recommendation: listen to the shortlist first, then option 2 for the reel and cast, and option 3 only if both fail.

## Second scan, 2026-11-13 (gaps)

OpenGameArt advanced search, sound effects, CC0 only, for: whoosh, swish, swoosh, ratchet, clicker, zipper, creak, fishing rod, fishing line, line reel, winch, spool. Kenney, Pixabay, Sonniss and Freesound did not answer from the session. Candidates (licence read on the page on 2026-11-13; trimmed listening copies on a private page for the owner):

| Use | Page | Author | Notes |
| --- | --- | --- | --- |
| Cast | https://opengameart.org/content/swish-bamboo-stick-weapon-swhoshes | qubodup | Own recording of a bamboo stick waved at the mic: closest to a rod swing |
| Cast | https://opengameart.org/content/swishes-sound-pack | artisticdude | 13 short swishes made for an RPG; recorded or synthesised not stated |
| Cast | https://opengameart.org/content/air-whoosh | pyranostudios | Whoosh loop |
| Drag clicker | https://opengameart.org/content/mechanical-sounds | BMacZero | Ratchets and clicks |
| Line running out | https://opengameart.org/content/zipper | AntumDeluge | Recording of a jacket zipper |
| Rod creak | https://opengameart.org/content/tree-creaking | AntumDeluge, from Department64 | Cleaned copy of another author's recording; the original page was not checked |

Still missing: a recording of a real reel's drag under load.
