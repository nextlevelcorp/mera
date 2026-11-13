# Data model and catch resolution

**Status:** Approved by the owner (2026-11-11), with the open questions in section 9. Schema, validator and the formulas of section 5 (except the cast model, the shoal follow-up and the real-time fight) are implemented in `game/sim/` and `game/data/`; see section 11.

Inputs: `project_spec.md` 5.2-5.4, `prd.md` (F2-F12, F14), `research.md`. Companion workbook: `data_model_examples.xlsx` (the three worked examples with live formulas; 136 cells checked against a reference calculation, 0 mismatches).

**Read this first**
- Every number in the formulas, the constants and the example records is a **design fill**: a starting value to be tuned in tests and by the owner's judgement as an angler. None is a sourced fact about real fish, places or tackle.
- The example species (horse mackerel, bluefish, sea bass) are candidates for illustration. The owner still chooses the three slice species (PRD open question).
- Section 8 lists where this design narrows or adds to the spec. Those points need the owner's approval.

## 1. Decision record: where the data lives

**Context.** The spec leaves format and schema validation to phase 2. Requirements: data in files with a schema and a source field, loaded and validated at start-up, failing loudly (PRD F12); no new dependency without approval; one owner with about 3 hours a week who must be able to read and correct values; a simulation core that is plain GDScript and headless-testable.

| Option | Complexity | Fit | Pros | Cons |
| --- | --- | --- | --- | --- |
| **A. JSON files + one schema file + a GDScript validator (recommended)** | Low | High | Plain text, readable diffs in pull requests, built-in JSON parser, no dependency, nested records (positions, monthly arrays) are natural, easy to export to a spreadsheet for review | JSON has no comments (provenance fields carry the notes); numbers arrive as floats, so the validator checks integer fields |
| B. Godot custom Resources (`.tres`) | Medium | Medium | Typed in the editor, loads fast | Tied to scene/engine classes, noisy diffs, harder for the owner to edit, validation still has to be written |
| C. CSV per entity | Low | Low | Opens directly in a spreadsheet | Nested data (positions, depth profiles, per-field provenance) does not fit; needs many joined files |

**Decision (proposed):** option A. Files under `game/data/`:

```
game/data/
  schema.json          # field name, type, range, required, per entity
  constants.json       # simulation constants (section 5.8), all design fills
  species.json
  spots.json           # each spot contains its standing positions
  tackle/rods.json  reels.json  lines.json  leaders.json  lures.json  baits.json
  angler.json          # starting angler attributes
```

**Consequences.** Easier: review in pull requests, tests over every record, a later spreadsheet round-trip. Harder: no editor UI; a validator must be written and tested first. Revisit if the MVP's 15-25 species make hand-editing painful.

## 2. Conventions

- **Scale.** Attributes are integers 1-20 unless a unit is given. `n(a) = (a - 1) / 19` maps them to 0..1.
- **Band function.** `band(x, lo, hi, m)` = 1 inside `[lo, hi]`, falling linearly to 0 at distance `m` outside.
- **Ids.** `snake_case`, unique per entity, never reused. Records refer to each other by id.
- **Names.** `name_key` points into the localisation table (en, tr, es). Species also carry `scientific_name` (not translated).
- **Provenance (pillar 1).** Every record has a `provenance` block. `default` applies to every field; `fields` overrides single fields. Each entry is either a `source` (URL or citation, with `accessed` date) or `design_fill: true`. The validator rejects a record without it; the in-game log shows design fills as such.

```json
{
  "id": "example_species",
  "name_key": "SPECIES_EXAMPLE",
  "scientific_name": "Genus species",
  "strength": 6,
  "provenance": {
    "default": { "design_fill": true },
    "fields": {
      "length_max_cm": { "source": "Author (Year), Journal, page", "accessed": "2026-11-11" }
    }
  }
}
```

## 3. Entity schemas

Types: `int20` = integer 1-20; `float01` = 0..1. Units are in the field name. "0.1" marks fields the slice formulas use; the rest are stored for the MVP.

### 3.1 Species

| Field | Type | Used in | Meaning |
| --- | --- | --- | --- |
| `id`, `name_key`, `scientific_name` | string | 0.1 | Identity and names |
| `strength` | int20 | 0.1 fight | Peak pull relative to body weight |
| `stamina` | int20 | 0.1 fight | How long it can pull |
| `speed` | int20 | 0.1 attraction | Preferred prey speed; also run speed in the fight |
| `caution` | int20 | 0.1 commit | Sensitivity to visible line and fishing pressure |
| `aggression` | int20 | 0.1 commit, strike window | Readiness to hit a lure |
| `schooling` | int20 | 0.1 (section 5.3) | Chance of follow-up takes after a take |
| `feeding_depth_min_m`, `feeding_depth_max_m` | float | 0.1 presence, attraction | Depth band below the surface where it feeds |
| `temp_min_c`, `temp_max_c` | float | 0.1 presence | Water temperature range |
| `activity_by_slot` | {dawn, day, evening, night: float01} | 0.1 presence | Feeding activity per time slot |
| `activity_by_month` | float01 x 12 | MVP | Seasonal activity (in 0.1 the spot's monthly abundance carries the season) |
| `salinity` | list of `marine`, `brackish`, `fresh` | 0.1 validation | Must include the spot's water class |
| `mouth_gape_mm` | float | 0.1 attraction, hook | Mouth opening |
| `diet_tags` | list (`small_fish`, `crustacean`, `worm`, `plankton`, `squid`, ...) | 0.1 attraction | What it eats |
| `surface_thrash` | int20 | 0.1 visuals; MVP hook pull-out | Thrashing at the surface |
| `teeth` | int20 | 0.1 fight | How easily it cuts a leader (1 = none). Added by the owner's decision of 2026-11-11 |
| `length_min_cm`, `length_max_cm`, `length_record_cm` | float | 0.1 size draw | Catchable size range |
| `lw_a`, `lw_b` | float | 0.1 fight | Length-weight relation: weight in g = `a x length_cm ^ b` |
| `weight_record_kg` | float | log | Record weight |
| `rarity` | int20 | log display | How rare it feels; not used in formulas |
| `regulation` | object, optional | log display | Minimum legal length, daily limit, closed season, with source and date |
| `provenance` | object | validator | Section 2 |

### 3.2 Spot and standing positions

| Field | Type | Used in | Meaning |
| --- | --- | --- | --- |
| `id`, `name_key`, `region` | string | 0.1 | Identity |
| `lat`, `lon` | float | display | Coordinates |
| `shore_type` | `rock`, `sand`, `pier`, `harbour` | display | Spec 5.3 |
| `water_class` | `marine`, `brackish`, `fresh` | 0.1 validation | Against species `salinity` |
| `typical_clarity` | int20 | 0.1 environment | Clarity on a calm day |
| `pressure` | int20 | 0.1 commit | How heavily it is fished |
| `access_difficulty` | int20 | MVP | Effort to reach it |
| `water_temp_by_month_c` | float x 12 | 0.1 presence | Monthly water temperature |
| `wind_by_month` | object, optional | 0.1 seed | Typical directions and speeds the date seed draws from |
| `species` | list of {`species_id`, `abundance_by_month`: float01 x 12} | 0.1 presence | Who is here, and when |
| `positions` | list of 3-4 objects | 0.1 | Below |
| `provenance` | object | validator | Section 2 |

Standing position (inside a spot):

| Field | Type | Used in | Meaning |
| --- | --- | --- | --- |
| `id`, `name_key`, `map_x`, `map_y` | string, float | 0.1 map | Identity and place on the top-down map |
| `facing` | N, NE, E, SE, S, SW, W, NW | 0.1 cast | Compass direction the angler faces when casting; with the wind direction it gives the headwind |
| `depth_profile` | list of {`distance_m`, `depth_m`} | 0.1 presence, attraction | Depth along the cast line; interpolated at the lure's distance |
| `bottom_type` | `rock`, `sand`, `mud`, `weed`, `mixed` | display; MVP | Bottom |
| `structure` | int20 | 0.1 presence, line abrasion | Cover: rocks, pilings, weed, drop-offs |
| `structure_tags` | list | display | What the structure is |
| `exposure_by_wind` | {N, NE, E, SE, S, SW, W, NW: float01} | 0.1 environment | How much each wind direction roughens the water here |
| `current` | int20 | MVP | Current strength |
| `landing_difficulty` | float01 | 0.1 landing | Height and awkwardness of the landing |

### 3.3 Tackle

| Entity | Fields (type) | Used in 0.1 |
| --- | --- | --- |
| Rod | `length_m` (float), `power` (int20), `action` (int20), `cast_weight_min_g`, `cast_weight_max_g` (float), `sensitivity` (int20), `durability` (int20) | length, cast weights (cast); power (hook); sensitivity (strike window). `action`, `durability`: MVP |
| Reel | `size` (int), `drag_max_kg` (float), `retrieve_m_per_s` (float), `smoothness` (int20), `line_capacity_m` (float) | drag limit, retrieve speed, smoothness (tension spike). `line_capacity_m`: MVP |
| Line | `type` (`mono`, `braid`, `fluorocarbon`), `diameter_mm`, `breaking_strain_kg` (float), `stretch`, `visibility`, `abrasion_resistance` (int20) | breaking strain, stretch |
| Leader | `type`, `length_m`, `breaking_strain_kg` (float), `visibility`, `abrasion_resistance` (int20) | breaking strain, visibility (commit), abrasion |
| Lure | `type` (`soft_plastic`, `metal_jig`, `spoon`, `minnow`, `popper`), `length_cm`, `weight_g` (float), `flash`, `action`, `scent`, `durability` (int20), `imitates` (diet tags), `run_depth_min_m`, `run_depth_max_m`, `sink_rate_m_per_s` (float), `hook_gape_mm` (float), `hook_pattern` | length, weight, flash, action, imitates, depths, hook gape |
| Bait (MVP, not in 0.1) | `type`, `size_cm`, `scent`, `durability`, `target_diet_tags`, `effective_depth_min_m`, `effective_depth_max_m` | none |
| Float, sinker (MVP) | `float_type`, `buoyancy_g`, `sinker_weight_g` | none |

All tackle records carry `id`, `name_key` and `provenance`. Tackle is fictional and labelled design fill (PRD non-goal: real brands).

### 3.4 Angler

`casting_distance`, `casting_accuracy`, `strike_timing`, `fight_control`, `knot_strength`, `patience`, `species_knowledge`, `spot_knowledge` (all int20). In 0.1 there is no progression: every value is fixed at 10. The slice formulas use `casting_distance`, `casting_accuracy` and `knot_strength`; the player's own input stands in for `strike_timing` and `fight_control`.

### 3.5 Conditions (not stored; produced per session)

`slot` (chosen by the player), `month` (from the date), `wind_dir`, `wind_ms`, derived `water_temp_c`. Wind is drawn from the spot's `wind_by_month` with a random generator seeded by the date and the spot id, so it is the same for everyone that day and reproducible in tests.

## 4. Validation rules (start-up and tests)

1. Every required field present, of the right type and inside its range; integer fields are whole numbers.
2. `provenance.default` exists; every provenance entry is a non-empty `source` or `design_fill: true`.
3. Ids unique; every `species_id`, tackle id and `name_key` resolves; every `name_key` exists in en, tr and es.
4. A spot has 3-4 positions; no two share both depth profile and structure (PRD F2); depth profiles are sorted by distance.
5. `feeding_depth_min_m < feeding_depth_max_m`, `temp_min_c < temp_max_c`, `length_min_cm < length_max_cm <= length_record_cm`, `cast_weight_min_g < cast_weight_max_g`.
6. A species listed at a spot accepts the spot's `water_class`.
7. Any failure stops the game at start-up with the file, record id and field named.

## 5. Staged catch resolution

A catch attempt passes six stages. Each stage takes named inputs, returns a number and writes both to the attempt log (PRD F10), so the "why" view and the tests read the same record. All randomness comes from one seeded generator.

Symbols: `K.*` are constants (5.8). `sp` species, `pos` position, `spot`, and the tackle records.

### 5.0 Environment and cast

```
chop        = pos.exposure_by_wind[wind_dir] * min(wind_ms / 10, 1)
clarity_eff = clamp(spot.typical_clarity - K.CHOP_CLARITY * chop, 1, 20)
light       = K.LIGHT[slot]                       # dawn 0.6, day 1.0, evening 0.6, night 0.25
visibility  = n(clarity_eff) * light

reach_ref_m = K.CAST_LEN_FACTOR * rod.length_m * (1 + ln(1 + lure.weight_g) / ln(1 + K.CAST_WEIGHT_REF_G))
weight_fit  = max(K.CAST_FIT_MIN, band(lure.weight_g, rod.cast_weight_min_g, rod.cast_weight_max_g, rod.cast_weight_max_g))
headwind    = max(0, cos(angle between wind_dir and pos.facing)) * min(wind_ms / 10, 1)
cast_max_m  = reach_ref_m * weight_fit * (K.CAST_SKILL_BASE + (1 - K.CAST_SKILL_BASE) * n(angler.casting_distance)) * (1 - K.CAST_HEADWIND * headwind)
cast_m      = cast_max_m * power_input            # power_input 0..1 from the player
aim_error   = normal(0, 0.15 - 0.12 * n(angler.casting_accuracy)) radians
water_depth = interpolate(pos.depth_profile, cast_m)
```

`headwind` is 0..1: 1 when a wind of 10 m/s or more blows straight into the angler's face, 0 with the wind from the side or behind (a tail wind does not add distance in 0.1). The reference reach grows with rod length and with lure weight (a 30 g lure reaches twice as far as a weightless one); the first version of this formula ignored lure weight and gave a medium rod only 33 m, so it was replaced. A lure outside the rod's casting range sets `lure_out_of_range`, which drives the rig warning (PRD F4). The lure's depth during the retrieve comes from its sink rate, the count-down the player allows and the retrieve speed, kept between `run_depth_min_m` and `run_depth_max_m`; the formulas below take it as `lure_depth_m`.

### 5.1 Stage 1: presence (is the species here now?)

```
A     = spot.species[sp].abundance_by_month[month]
T     = sp.activity_by_slot[slot]
D     = clamp((water_depth - sp.feeding_depth_min_m) / (0.5 * (sp.feeding_depth_max_m - sp.feeding_depth_min_m)), 0, 1)
Theta = band(water_temp_c, sp.temp_min_c, sp.temp_max_c, K.TEMP_M)
S     = K.STRUCT_BASE + (1 - K.STRUCT_BASE) * n(pos.structure)
presence = A * T * D * Theta * S                  # 0..1
```

### 5.2 Stage 2: attraction (does the presentation reach it and appeal?)

```
G = band(lure_depth_m, sp.feeding_depth_min_m, min(sp.feeding_depth_max_m, water_depth), K.REACH_BASE + K.REACH_CLAR * n(clarity_eff))
M = 1 if lure.imitates shares a tag with sp.diet_tags else K.DIET_MISS
g = sp.mouth_gape_mm / 10                         # gape in cm
Z = band(lure.length_cm, K.SIZE_LO * g, K.SIZE_HI * g, K.SIZE_M * g)
V = 1 - K.SPEED_PEN * abs(n(retrieve_speed) - n(sp.speed))
F = K.DETECT_BASE + (1 - K.DETECT_BASE) * (visibility + (1 - visibility) * (0.5 * n(lure.flash) + 0.5 * n(lure.action)))
attraction = G * M * Z * V * F                    # 0..1
```

In murky water or low light, flash and action do the work that visibility cannot; in clear daylight they add little.

### 5.3 Stage 3: commit (nibble or take?)

While the lure is fished, each species produces **interest events** as a Poisson process:

```
rate_interest = K.R0 * presence * attraction      # events per second
suspicion     = n(sp.caution) * n(leader.visibility) * visibility
pressure      = n(sp.caution) * n(spot.pressure)
c = clamp(K.COMMIT_BASE + K.COMMIT_AGG * n(sp.aggression) - K.COMMIT_LINE * suspicion - K.COMMIT_PRESS * pressure, K.COMMIT_MIN, K.COMMIT_MAX)
rate_take     = rate_interest * c
```

Each interest event is a **committed take** with probability `c`, otherwise a **nibble** (a visible sign, no hook-up). The wait for a take is exponential with the summed `rate_take` of all species present: `median wait = ln(2) / sum(rate_take)`. After a take, that species' rate is multiplied by `1 + n(sp.schooling)` for 60 s (a shoal is under the lure).

Strike window after a take: `window_s = K.TW_BASE + K.TW_SENS * n(rod.sensitivity) + K.TW_AGG * n(sp.aggression)`. A strike outside it misses (PRD F7). `timing_quality` is 1 at the centre of the window and 0 at its edges.

### 5.4 Stage 4: hook hold

```
H1 = band(lure.hook_gape_mm, K.GAPE_LO * sp.mouth_gape_mm, K.GAPE_HI * sp.mouth_gape_mm, K.GAPE_M * sp.mouth_gape_mm)
H2 = K.PEN_BASE + (1 - K.PEN_BASE) * (0.5 * n(rod.power) + 0.5 * (1 - n(line.stretch)))
H3 = K.TIMING_BASE + (1 - K.TIMING_BASE) * timing_quality
h  = clamp(H1 * H2 * H3, 0, K.HOOK_MAX)           # probability the hook sets and holds
```

### 5.5 Stage 5: fight (does the tackle survive, does the fish tire?)

The fish drawn: `length_cm = length_min + (length_max - length_min) * u^2` with `u` uniform 0..1 (small fish common, big fish rare).

```
W      = sp.lw_a * length_cm ^ sp.lw_b / 1000                         # kg
F_max  = W * (K.PULL_BASE + K.PULL_STR * n(sp.strength))             # peak pull, kgf
E0     = F_max * (K.STA_BASE + K.STA_RANGE * n(sp.stamina))          # energy pool, kgf.s
B_eff  = min(line.breaking_strain_kg, leader.breaking_strain_kg)
         * (K.KNOT_BASE + K.KNOT_SKILL * n(angler.knot_strength))
         * (1 - K.ABRASION * n(pos.structure) * (1 - n(leader.abrasion_resistance)))
```

Real-time rules, per simulation tick:
- The fish alternates run, rest and thrash states (seeded). Its pull is `F_fish = F_max * effort * sqrt(energy / E0)`.
- The angler's pull is `P = angler_pull_max * (0.5 * reel + 0.5 * rod)` with `angler_pull_max = K.ANGLER_PULL_BASE + K.ANGLER_PULL_RANGE * n(rod.power)`; `reel` and `rod` are the two thumb inputs, 0..1.
- Line tension is `T = min(F_fish + P, drag)`. When fish and angler together exceed the drag, the drag slips and line pays out at `run_speed * effort * sqrt(energy / E0) * (F_fish + P - drag) / (F_fish + P)`, with `run_speed = K.RUN_SPEED_BASE + K.RUN_SPEED_RANGE * n(sp.speed)`.
- When the drag holds and the player reels, line comes in at `reel * reel.retrieve_m_per_s * (1 - F_fish / drag)`. So a fish strong enough to slip the drag cannot be brought closer until it tires.
- At the start of a run the tension overshoots: `spike = drag * (1 + K.SPIKE * (1 - n(reel.smoothness)))`.
- **Line break:** immediately if `T` or `spike` exceeds `B_eff`; also if `T` stays above `0.8 * B_eff` for more than 2 s.
- **Hook pull-out:** the line is slack when the fish is not running and the angler keeps less than `K.SLACK_SHARE` of the possible pull on it; then a hazard of `K.SLACK_HAZARD * (1 - h)` per second. Keep reeling when it rests.
- **Tiring:** `d(energy)/dt = -(T + K.REST_DRAIN * F_max)`. More drag tires the fish faster and risks the line. That trade-off is the fight.
- **Teeth (owner decision 2026-11-11):** a species with teeth cuts the leader at a constant hazard over the fight:
  `cut_rate = K.TEETH_RATE * n(sp.teeth) * (1 - n(leader.abrasion_resistance)) * (K.WIRE_CUT_FACTOR if leader.type == "wire" else 1)`, and `p_cut = 1 - exp(-cut_rate * min(t_fight, 90 s))`. A cut ends the fight at once. Wire is immune, but its visibility feeds stage 3 suspicion like any leader's.
- **Landing phase** starts when `energy <= K.LAND_ENERGY * E0` and the fish is close.
- **90 s rule (PRD F8):** if a fight reaches 90 s it is resolved at once: landed if `energy <= 0.4 * E0` and the fish is within `K.CAP_LAND_DISTANCE_M` (5 m) of the shore, otherwise the hook pulls out. The distance condition was added by the owner on 2026-11-13 after a 93 cm sea bass was counted as landed 69 m out. This is a deliberate game rule, not realism. It is not rare: with the drag set to a third of the line strength, the closed-form estimate exceeds 90 s on light tackle for a 62 cm sea bass (109 s) and an 80 cm bluefish (133 s), and on medium tackle for an 80 cm bluefish (95 s) and an 80 cm sea bass (102 s); it stays under it for the small and mid-size fish tested (50 cm bluefish on light tackle: 83 s). The owner decided on 2026-11-11 that the rule stays and that the game warns the player (PRD F19, P1) when light tackle meets a big fish.

Closed-form estimate at a constant drag, used in the worked examples and as the test oracle for the tick model:

```
T_bar   = min(drag, F_max)
t_tire  = (1 - K.LAND_ENERGY) * E0 / (T_bar + K.REST_DRAIN * F_max)
t_reel  = hook_distance_m / reel.retrieve_m_per_s
t_fight = (t_tire + t_reel  if F_max > drag  else  max(t_tire, t_reel)) + K.LAND_PHASE
```

### 5.6 Stage 6: landing

```
q         = 1 - clamp(W / B_eff - K.LAND_FREE, 0, 1) * pos.landing_difficulty   # probability the fish is landed at the edge
visible_m = K.VIS_BASE + K.VIS_RANGE * visibility                               # fish becomes visible inside this distance
```

### 5.7 The chain

`P(landed | take) = P(strike inside the window) * h * (1 - p_cut) * P(no break, no pull-out) * q`. The first and third factors are the player's doing; the others come from the match between tackle and fish. The attempt log stores every symbol above, per stage.

### 5.8 Constants (`constants.json`, all design fills)

| Constant | Value | Constant | Value | Constant | Value |
| --- | --- | --- | --- | --- | --- |
| R0 | 0.04 /s | COMMIT_BASE | 0.25 | PULL_BASE | 1.0 |
| LIGHT dawn / day / evening / night | 0.6 / 1.0 / 0.6 / 0.25 | COMMIT_AGG | 0.75 | PULL_STR | 2.0 |
| CHOP_CLARITY | 8 | COMMIT_LINE | 0.6 | STA_BASE | 6 s |
| STRUCT_BASE | 0.7 | COMMIT_PRESS | 0.3 | STA_RANGE | 18 s |
| TEMP_M | 3 C | COMMIT_MIN / MAX | 0.05 / 0.95 | REST_DRAIN | 0.1 |
| REACH_BASE / REACH_CLAR | 0.5 m / 1.5 m | TW_BASE / TW_SENS / TW_AGG | 0.4 / 0.6 / 0.4 s | LAND_ENERGY | 0.15 |
| DIET_MISS | 0.4 | GAPE_LO / HI / M | 0.25 / 0.7 / 0.25 | KNOT_BASE / KNOT_SKILL | 0.75 / 0.2 |
| SIZE_LO / HI / M | 1.0 / 4.0 / 2.0 | PEN_BASE | 0.6 | ABRASION | 0.3 |
| SPEED_PEN | 0.8 | TIMING_BASE | 0.7 | SPIKE | 0.5 |
| DETECT_BASE | 0.4 | HOOK_MAX | 0.98 | VIS_BASE / VIS_RANGE | 1 m / 7 m |
| LAND_FREE | 0.3 | LAND_PHASE | 5 s | TEETH_RATE | 0.02 /s |
| WIRE_CUT_FACTOR | 0.0 | FIGHT_CAP_S | 90 s | CAP_LAND_ENERGY | 0.4 |
| RUN_SPEED_BASE / RANGE | 0.3 / 1.2 m/s | ANGLER_PULL_BASE / RANGE | 0.5 / 3.5 kgf | EFFORT run / rest / thrash | 1.0 / 0.5 / 0.7 |
| STATE_SECONDS run / rest / thrash | 3-6 / 1-2 / 1-2 s | STRAIN_SHARE / LIMIT | 0.8 / 2 s | SLACK_SHARE / HAZARD | 0.1 / 0.15 /s |
| LAND_DISTANCE_M | 2 m | THRASH_DISTANCE_M | 10 m | CAST_LEN_FACTOR | 12 |
| CAST_WEIGHT_REF_G | 30 g | CAST_FIT_MIN | 0.3 | CAST_SKILL_BASE | 0.6 |
| CAST_HEADWIND | 0.3 | AIM_SIGMA_BASE / SKILL | 0.15 / 0.12 rad | WAIT_RETRIEVE_M_PER_S | 0.4 m/s |
| WAIT_END_M | 3 m | SHOAL_BOOST_S | 60 s | CAP_LAND_DISTANCE_M | 5 m |

`WAIT_RETRIEVE_M_PER_S` is how fast the lure comes back while the player waits; the cast ends when the lure is `WAIT_END_M` from the shore. `SHOAL_BOOST_S` is the 60 s shoal follow-up of 5.3. All three were added with the real-time wait (2026-11-13).

Calibration targets from the PRD: best-case median wait for a take 20-40 s (the examples give 28 s); worst case at least 120 s (608 s); fights 20-90 s (30-60 s in the examples).

## 6. Three worked examples

Illustrative records (design fills). The spot is an imagined pier with two positions: **pier end** (8 m of water, structure 12, exposed to south-west wind 0.8, landing difficulty 0.5) and **inner corner** (3 m, structure 5, sheltered, landing difficulty 0.2); typical clarity 11, pressure 15.

| Species (illustrative) | str | sta | spd | cau | agg | teeth | feeding depth m | temp C | activity dawn/day/eve/night | gape mm | lw a, b |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Horse mackerel | 6 | 6 | 12 | 5 | 14 | 1 | 1-15 | 12-24 | 0.8 / 0.5 / 1.0 / 0.7 | 14 | 0.0085, 3 |
| Bluefish | 15 | 13 | 17 | 9 | 18 | 18 | 1-20 | 14-24 | 1.0 / 0.4 / 0.9 / 0.5 | 30 | 0.011, 3 |
| Sea bass | 14 | 15 | 11 | 16 | 10 | 3 | 0.5-10 | 10-24 | 0.9 / 0.2 / 0.8 / 1.0 | 45 | 0.010, 3 |

| Tackle set | Rod power / sens | Reel smoothness / retrieve | Main line | Leader (strain / visibility / abrasion) | Lure |
| --- | --- | --- | --- | --- | --- |
| Light (LRF) | 4 / 16 | 12 / 1.0 m/s | 3.5 kg, stretch 2 | 2.7 kg / 4 / 12 | Soft plastic 5 cm, flash 5, action 14, imitates small fish and crustacean, hook gape 6 mm |
| Medium spin | 10 / 11 | 9 / 1.2 m/s | 9 kg, stretch 2 | 7 kg / 13 / 8 | Minnow 12 cm, flash 14, action 12, imitates small fish, hook gape 12 mm |

### Example A: a good match (horse mackerel, light tackle, October evening)

Pier end, south-west wind 3 m/s, lure at 4 m, retrieve speed 11, strike timing quality 0.8, a 20 cm fish, drag 0.8 kg, hooked at 25 m.

| Stage | Inputs to result |
| --- | --- |
| Environment | chop 0.8 x 0.3 = 0.24; clarity 11 - 8 x 0.24 = 9.08; light 0.6; visibility 0.255 |
| 1 Presence | A 0.9 x T 1.0 x D 1.0 x temp 1.0 x S 0.874 = **0.786** |
| 2 Attraction | G 1.0 x M 1.0 x Z 1.0 (5 cm inside 1.4-5.6 cm) x V 0.958 x F 0.753 = **0.721** |
| 3 Commit | suspicion 0.009, pressure 0.155; c = **0.712**; take rate 0.04 x 0.786 x 0.721 x 0.712 = 0.0161 /s; strike window 1.15 s |
| 4 Hook | H1 1.0 x H2 0.821 x H3 0.94 = **0.772** |
| 5 Fight | W 0.068 kg; peak pull 0.10 kgf; line strength 2.11 kg; spike 0.97 kg, no break; tire 8 s, recover line 25 s; **fight 30 s** |
| 6 Landing | q **1.0**; fish visible inside 2.8 m |

Result: with all three species in the water the summed take rate is 0.0247 /s, a **median wait of 28 s** (horse mackerel 65% of takes, bluefish 26%, sea bass 9%). A well-timed strike lands the fish 77% of the time. What the player reads: right depth, right size, right hour.

### Example B: wrong time and place (sea bass, medium tackle, October midday)

Inner corner, north wind 1 m/s, lure at 1.5 m, retrieve speed 16, timing quality 0.5, a 50 cm fish, drag 2.0 kg, hooked at 20 m.

| Stage | Inputs to result |
| --- | --- |
| Environment | chop 0.01; clarity 10.9; light 1.0; visibility 0.522 |
| 1 Presence | A 0.25 x T 0.2 (midday) x D 0.526 (3 m of water for a fish that feeds down to 10 m) x temp 1.0 x S 0.763 = **0.020** |
| 2 Attraction | G 1.0 x M 1.0 x Z 1.0 x V 0.789 (retrieve too fast) x F 0.894 = **0.706** |
| 3 Commit | suspicion 0.260 (cautious fish, visible leader, bright clear water), pressure 0.582; c = **0.275**; take rate 0.00016 /s |
| 4 Hook | 1.0 x 0.884 x 0.85 = **0.752** |
| 5 Fight | W 1.25 kg; peak pull 2.96 kgf; line strength 5.68 kg; spike 2.58 kg, no break; tire 21 s, then recover 17 s (the fish can slip a 2.0 kg drag), land 5 s; **fight 43 s** |
| 6 Landing | q **1.0**; visible inside 4.7 m |

Result: the lure itself is fine, but a sea bass alone would take about 74 minutes to arrive (median). With all species the median wait is 608 s, far above the 120 s "bad choice" bar. The "why" view shows the three weak inputs: time slot (0.2), depth (0.53) and commit (0.27). Evening, the pier end and a less visible leader each fix one of them. A sea bass that does get hooked has a 5.5% chance of cutting the leader (teeth 3), so a hooked fish lands with probability 0.752 x 0.945 x 1.0 = **0.71**.

### Example C: the fight is lost, then won (bluefish, light tackle, September dawn)

Pier end, south-west wind 6 m/s, lure at 3 m, retrieve speed 16, timing quality 0.9, a 45 cm fish, hooked at 30 m.

| Stage | Inputs to result |
| --- | --- |
| Environment | chop 0.48; clarity 7.16; light 0.6; visibility 0.195 |
| 1 Presence | A 0.8 x T 1.0 x D 0.737 x temp 1.0 x S 0.874 = **0.515** |
| 2 Attraction | 1.0 x 1.0 x 1.0 x 0.958 x 0.733 = **0.702** |
| 3 Commit | c = **0.820**; take rate 0.0119 /s (median 58 s for bluefish alone); strike window 1.23 s |
| 4 Hook | H1 0.8 (a 6 mm hook is small for a 30 mm mouth) x 0.821 x 0.97 = **0.637** |
| 5 Fight | W 1.00 kg; peak pull 2.48 kgf; line strength 2.11 kg |

- **Drag 2.6 kg:** spike 2.6 x 1.21 = 3.15 kg, above the 2.11 kg the leader really holds. **The line breaks on the first run.** P(landed) = 0.
- **Drag 1.2 kg:** spike 1.45 kg, under 2.11 kg. Tire 25 s, then recover line 30 s (a fish pulling 2.48 kgf slips a 1.2 kg drag, so no line comes in while it tires), land 5 s: **fight 60 s**; landing q 0.913 (a 1 kg fish lifted on a 2.1 kg line from a high pier). The bluefish's teeth cut the fluorocarbon leader with probability **0.37** over a 60 s fight (hazard 0.0075 /s). P(landed | take, good strike) = 0.637 x (1 - 0.37) x 0.913 = **0.37**.

What the player learns: the leader's label says 2.7 kg, but knot and abrasion leave 2.11 kg, and a jerky drag overshoots its setting. Setting the drag near a third of the weakest link is the lesson, and the screen shows each of those numbers. The teeth add a second lesson: against a bluefish a wire leader is never cut (spin tackle, same conditions: landing probability 0.86 with wire against 0.51 with fluorocarbon, the commit probability only slightly lower, 0.78 against 0.80, because a bluefish is not very cautious). A cautious, toothless species shifts that balance the other way (unit test `test_teeth_cut_fluorocarbon_but_not_wire`).

### Cast distance examples

Angler casting distance and accuracy 10; pier end, facing south-west. Workbook sheet `Cast`.

| Example | Reference reach | Weight fit | Skill | Headwind | Result |
| --- | --- | --- | --- | --- | --- |
| 1. Light rod 2.1 m (1-7 g), 3 g lure, calm, full power | 12 x 2.1 x 1.404 = 35.4 m | 1.0 | 0.789 | 0 | **27.9 m** |
| 2. Medium rod 2.7 m (7-28 g), 18 g lure, south-west wind 8 m/s in the face, full power | 12 x 2.7 x 1.857 = 60.2 m | 1.0 | 0.789 | 0.8 | 47.5 x (1 - 0.24) = **36.1 m** |
| 3. Light rod, 18 g lure (11 g over its range), west wind 5 m/s (quartering), half power | 46.8 m | 0.3 | 0.789 | 0.354 | maximum 9.9 m, cast **5.0 m**; rig warning shown |

Aim error is 0.093 rad (1 sigma, about 5 degrees) at accuracy 10.

### The real-time fight against the estimate

200 seeded fights per row with a simple policy (reel all the time, never touch the rod or the drag). The estimate is the closed form of 5.5.

| Example | Estimate | Real-time fight (200 seeds) |
| --- | --- | --- |
| A, horse mackerel, drag 0.8 kg | 30 s, always landed | mean 28 s, 200 of 200 landed |
| B, sea bass 50 cm, drag 2.0 kg | 43 s, landed 0.94 of hooked fish | mean landed fight 47 s; within 0.1 of the estimated landing rate |
| C, bluefish, drag 2.6 kg | line breaks | line breaks on the first tick, 200 of 200 |
| C2, bluefish, drag 1.2 kg | 60 s, landed 0.58 of hooked fish | mean landed fight 71 s; within 0.1 of the estimated landing rate |

The real-time fight runs up to 18% longer than the estimate because the fish also takes line while it tires; the unit tests hold the two within 25% for time and 0.1 for landing rate. Not reeling at all loses more than a quarter of example A's fish to hook pull-outs (tested), against none with a tight line.

## 7. Data sources and licences (proposal)

How each licence was checked on 2026-11-11: **S** = search-result summary of the cited page (the page itself was not opened); **M** = from general knowledge, not checked this session. None was read in full, so every row needs a check of the source's own terms page before its data is committed, and the result goes into `reference_docs.md`. Nothing here is legal advice.

### Species

| Source | Use for | Licence or terms | Check | Recommendation |
| --- | --- | --- | --- | --- |
| Owner's own notes and catches | Local behaviour, hours, lures that work, sizes | Own work | n/a | Primary source for local patterns; date every note |
| Published papers and regional studies | Length-weight relations, sizes, depth, diet, temperature | Each paper's own copyright | M | Enter single values by hand with a full citation; do not copy tables or text |
| FishBase ([citation page](https://fishbase.de/summary/citation.php), [GBIF listing](https://www.gbif.se/ipt/resource?r=fishbase), [API licence](https://fishbaseapi.readme.io/docs/license)) | Finding the primary reference for a value | CC BY-NC 4.0 per GBIF and OBIS listings; commercial users are asked to contact the maintainers | S | **Do not import or copy.** Mera plans a paid release, so non-commercial terms do not fit. Use it to find the paper, then cite the paper; or ask FishBase for permission |
| WoRMS ([terms](https://marinespecies.org/usersrequest.php)) | Valid scientific names | Own terms of use; site text CC BY | S | Check names by hand and cite; no bulk copy |
| GBIF ([terms](https://www.gbif.org/terms)) | Confirming a species occurs in the region | Per dataset: CC0, CC BY or CC BY-NC | S | Use only CC0 and CC BY datasets, cite the dataset |
| Amateur fishing communique no. 6/2 (2024/21), Official Gazette 32629 of 11 August 2024, in force 1 September 2024 to 31 August 2028, amended 16 April 2025 ([Official Gazette](https://resmigazete.gov.tr/eskiler/2024/08/20240811-3.htm), [amendment](https://www.resmigazete.gov.tr/eskiler/2025/04/20250416-4.htm)) | Minimum legal sizes, daily limits, closed seasons | Official legislation; officially published laws and communiques may be reproduced under article 31 of Law 5846, per a search summary | S | Read the current text and amendments, enter values by hand with article and date; show "check the official text" in game. Confirm the article 31 reading in the same legal consultation as OpenStreetMap |
| IUCN Red List | Conservation status | Restrictive terms for commercial use | M | Do not use without permission |

### Spots

| Source | Use for | Licence or terms | Check | Recommendation |
| --- | --- | --- | --- | --- |
| Owner's visit: dated notes, own photos, depths measured by counting a lure down | Positions, depth profiles, structure, bottom, landing height, pressure | Own work | n/a | **Primary source for the first spot** (owner decision) |
| Sentinel-2 imagery ([legal notice](https://sentinel.esa.int/documents/247904/690755/Sentinel_Data_Legal_Notice)) | Tracing the outline of the top-down map | "Free, full and open" access; credit "Contains modified Copernicus Sentinel data [year]"; commercial use not confirmed in the summaries | S | Good candidate for the map outline (10 m pixels: fine for a breakwater, coarse for a small pier). Read the notice first |
| EMODnet Bathymetry ([terms](https://emodnet.ec.europa.eu/en/terms-use-emodnet-online-services-data-and-data-products)) | General depth context | CC BY 4.0 with a set acknowledgement; grid about 115 m | S | Too coarse for standing positions; context only |
| Copernicus Marine Service ([licence](https://marine.copernicus.eu/user-corner/service-commitments-and-licence)) | Monthly water temperature and clarity climatology | Own licence; commercial terms not confirmed in the summaries | S | Candidate for `water_temp_by_month_c`; read the licence first |
| Turkish State Meteorological Service sea-water temperature statistics ([Marmara 2025](https://mgm.gov.tr/FILES/resmi-istatistikler/denizSuyu/2025-Marmara.pdf)) | Monthly water temperature | Terms of use not found | S | Cite single values as facts with the source; ask before copying tables |
| Turkish Navy hydrographic office (SHODB) charts | Depths | Terms not found; treat as protected | S | Do not copy. Ask SHODB if chart depths are ever needed |
| Commercial map and satellite services | Tracing | Terms generally forbid derived works | M | Do not trace or copy |
| OpenStreetMap | Coastline, names | ODbL, share-alike | first pass | Not used until legal advice (owner decision) |
| Natural Earth | Country-scale coast | Public domain | M | Too coarse; not needed |

Wind in 0.1 comes from the date seed and a design-fill distribution per spot, so no weather service is needed. Art and audio sources are in spec 7.8 and are out of scope here.

## 8. Where this narrows or adds to the spec (needs the owner's approval)

1. **Activity by time slot, not by hour.** The spec lists "activity by hour"; the PRD has four slots, so the schema stores four values. Hours can replace them later without changing the formulas.
2. **Depth range means feeding depth.** The spec's "preferred depth range" is defined here as the depth band below the surface where the species feeds.
3. **Fields added to the spec's lists:** `lw_a`, `lw_b`, `regulation`, `teeth` (species); `water_class`, `water_temp_by_month_c`, `wind_by_month`, `landing_difficulty`, `facing` (spot and positions); `retrieve_m_per_s` instead of a retrieve ratio (reel); a separate **leader** record; `imitates`, running depths, `sink_rate_m_per_s`, `hook_gape_mm` (lure). Hook size is stored as gape in mm because hook size numbers are not linear.
4. **Spec attributes stored but not used by the 0.1 formulas:** species `rarity`, `activity_by_month`; spot `access_difficulty`, position `current`, `bottom_type`; rod `action`, `durability`; reel `size`, `line_capacity_m`; line `diameter_mm`, `visibility`, `abrasion_resistance` (the leader's values are used instead); lure `scent`, `durability`; angler `strike_timing`, `fight_control`, `patience`, `species_knowledge`, `spot_knowledge`. They are kept so the MVP does not need a schema change.
5. **The 90 s rule** resolves a fight by a game rule (5.5). It follows the PRD's cap and is not realistic for very large fish.

## 9. Open questions

| Question | Who | Blocking? |
| --- | --- | --- |
| Do the formulas match an angler's judgement (drag at a third of the weakest link, flash in murky water, cautious fish and visible leaders)? | Owner | Blocks tuning, not the build |
| Species and spot are provisional (horse mackerel, bluefish, sea bass; a Kadıköy/Moda breakwater or pier area, chosen by Claude on 2026-11-11); sources for every value still needed | Owner (visit, citations) | Blocks real data |
| ~~Should toothy species cut leaders?~~ **Decided yes (2026-11-11)**: `teeth` attribute, section 5.5 | Owner | Done |
| ~~90 s rule~~ **Decided (2026-11-11)**: the cap stays; the game shows a hint when the capped fight is likely (PRD F19) | Owner | Done |
| Licence reads: Sentinel-2 notice, Copernicus Marine licence, the communique text, article 31 | Owner with legal advice | Blocks only the data that uses them |
| Is the top-down map traced from Sentinel-2 or drawn from the owner's photos? | Owner, art direction | Blocks the map art |
| Tick rate and state machine details of the fight (run, rest, thrash) | Engineering, with the architecture | Blocks the fight build |

## 10. Action items

1. [ ] Owner reviews sections 5, 6 and 8 and approves or corrects them.
2. [ ] Write `schema.json` and the validator with tests (first build task after approval).
3. [ ] Port the formulas to `game/sim/` as pure functions; the worked examples become unit tests with these exact numbers.
4. [ ] Owner picks the first spot and three species; values entered by hand with provenance.
5. [ ] Read each licence in section 7 before its data is committed; record it in `reference_docs.md`.

## 11. Implementation status

| Part | File | State |
| --- | --- | --- |
| Schema (all entities of section 3 except float and sinker) | `game/data/schema.json` | Done |
| Constants (section 5.8, all design fills) | `game/data/constants.json` | Done |
| Validator (sections 2 and 4) | `game/sim/data_validator.gd` | Done; negative tests for each rule |
| Loader | `game/sim/data_store.gd` | Done; returns errors, the caller decides how loudly to fail; not yet wired into start-up because no real data exists |
| Stages 0-4 and 6, cast distance (5.0), closed-form fight (5.5 estimate) including teeth and the 90 s cap flag | `game/sim/catch_model.gd` | Done; the three worked examples (four runs) are unit tests and agree with this document and the workbook |
| Real-time fight (5.5): fixed 30 Hz step, seeded, run / rest / thrash states, drag slip, line break and strain, teeth, slack hook pull-out, landing phase, 90 s rule | `game/sim/fight_sim.gd` | Done; tested against the closed-form estimate over 200 seeds per example. Takes `reel`, `rod`, `drag_kg` per tick; driven by the fishing screen |
| Real-time wait, bite and strike (5.3, 5.4): interest events as a Poisson process per species, nibble or take, strike window and timing quality, hook roll, shoal follow-up, slow retrieve, attempt log | `game/sim/wait_sim.gd` | Done; seeded, 30 Hz; best-case median wait over repeated casts 27 s and worst case 714 s (PRD F6 test). The window does not shrink on a slow frame: during a take at most two ticks run per frame |
| Fight on screen | `game/sim/fight_controller.gd`, `game/scenes/fishing/` | Done; overmatched-tackle flag (PRD F19) from the closed-form estimate |
| Fixtures (illustrative design fills, not real data) | `game/tests/fixtures/` | Excluded from the export |
| Real species and spot data | `game/data/species.json`, `spots.json`, `tackle/` | Galata Bridge and three species written 2026-11-13; sources per field in each record's provenance and in `reference_docs.md`; tackle and angler are design fills |
