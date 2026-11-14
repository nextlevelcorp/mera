# Spot research: Turkish sea shore, first pass

**Status:** 2026-11-13. The owner chose the Galata Bridge; its records are in `game/data/` (see `reference_docs.md`). The owner asked (2026-11-13) to find real sea places from the web, starting in Turkey, without a site visit.

## How this was done

- **Coordinates from Wikidata (CC0).** One SPARQL query on 2026-11-13 for items in Turkey (P17 = Q43) with a coordinate (P625) and an instance-of type of pier, breakwater, lighthouse, cape, port and a few related types. 480 rows (287 distinct coast items of the pier, breakwater, cape, lighthouse and port types) are in `spot_candidates_tr.csv`. Wikidata's data is CC0, so coordinates and names can be used without a licence condition; each record keeps its Q-number as the source. A Wikidata item says a structure exists and where; it says nothing about fishing.
- **Fishing evidence** from pages read in full where the session could reach them (DergiPark PDFs, MGM PDF), and from web search summaries where it could not (news and guide sites are outside the session's network). Check level: **R** = read in full, **S** = search-result summary only.
- **Not used:** OpenStreetMap (owner decision: legal advice first), SHODB charts (treated as protected), FishBase (non-commercial terms).

## Istanbul shortlist

| Candidate | Wikidata, coordinates | Fishing evidence | Species named for this place | Check |
| --- | --- | --- | --- | --- |
| **Galata Bridge** (Karaköy-Eminönü, mouth of the Golden Horn) | Q81523; 41.02000, 28.97306; length 490 m | Zengin, M. (2009) "Galata Köprüsünün Oltacıları", SÜMAE Yunus Araştırma Bülteni 9(3), https://dergipark.org.tr/en/download/article-file/204298: two observation visits (April and September 2008); 514 anglers counted in spring, 406 in autumn; fishing all year and at all hours, best in spring and autumn; an experienced angler takes up to 15-20 kg of horse mackerel a day. Also Alıçlı, Göktürk and Deniz (2018), KSÜ Tarım ve Doğa Dergisi 21: 339-352 (catch per effort on the bridge; not read, full text not found) | Horse mackerel (istavrit) all year; bluefish young (çinekop) in autumn when the water cools; Atlantic bonito (palamut) September to late November; annular/green bream (izmarit) all year; mullet late spring | R (Zengin), S (Alıçlı) |
| Sarayburnu (below Topkapı) and Ahırkapı Lighthouse | Q1247633; 41.01714, 28.98605. Ahırkapı Feneri Q4696460; 41.00633, 28.98543 | Guide and news pages (yemek.com, ensonhaber.com) say casting gear works here and the point is on the migration path | Horse mackerel, mackerel, çinekop, bluefish, sometimes bonito | S |
| Kuzguncuk-Kuleli shore (Asian Bosphorus) | Kuzguncuk İskelesi Q6025724; 41.03683, 29.02978 | istanbul.com guide | Horse mackerel all year in front of Kuleli, scorpionfish (iskorpit), çinekop | S |
| Akıntıburnu (Arnavutköy-Bebek current point) | Q12808375; no coordinate on Wikidata | Guide pages (yemek.com, ensonhaber.com) | Horse mackerel and bluefish because of the current; mackerel | S |
| Haydarpaşa breakwater with İnciburnu Lighthouse (Kadıköy) | Q135479169; 40.99537, 29.01673. Lighthouse Q6345873 on the breakwater, 11 m above the sea (tr.wikipedia) | Only "Kadıköy shores" in general (rudaw.net) | None specific | S |
| Moda Pier, Fenerbahçe Lighthouse | Q114871544; 40.97895, 29.02506. Q6085777; 40.96806, 29.03194 | None found | None | - |

**Sea bass (levrek):** no source places it at any Istanbul candidate. The 0.1 species list (horse mackerel, bluefish, sea bass) was a provisional choice; for the Galata Bridge the sources support horse mackerel, bluefish/çinekop and bonito instead.

## Regional values found

| Value | Source | Check | Use |
| --- | --- | --- | --- |
| Sea of Marmara mean sea-water temperature by month, 1970-2025: 9.3, 8.2, 8.7, 11.3, 15.4, 20.2, 23.4, 24.2, 22.3, 18.8, 15.2, 12.0 °C | MGM, "Marmara Denizi deniz suyu sıcaklık" 2025, https://mgm.gov.tr/FILES/resmi-istatistikler/denizSuyu/2025-Marmara.pdf | R | `water_temp_by_month_c` for any Marmara or Istanbul spot (sea-wide mean, not a station) |
| Shore anglers' catch in the southern Marmara: 29 species; horse mackerel 19%, sand steenbras 16%, bluefish/çinekop 15% | Öndes, F. (2019) Anadolu Çev. ve Hay. Dergisi 4(3): 414-421, https://doi.org/10.35229/jaes.620801 | R | Relative abundance as a regional cross-check (Bandırma, not Istanbul) |
| Preferred fishing time of those anglers: early morning 61%, evening 22%, any time 10%, night 4%, noon 3% | Öndes (2019), as above | R | A check on `activity_by_slot`: what anglers prefer, not fish activity |
| Valid names: Trachurus mediterraneus (AphiaID 126820), Pomatomus saltatrix (151482), Dicentrarchus labrax (126975) | WoRMS REST API, 2026-11-13 | R | `scientific_name` |
| GBIF occurrences in a Marmara-Istanbul box (40.7-41.4 N, 28.0-29.9 E): bluefish 14, horse mackerel 4, sea bass 0; mostly iNaturalist research-grade observations | GBIF occurrence API, 2026-11-13 | R | Presence check only; too few to set abundance |

## Depth at the bridge (2026-11-14)

English Wikipedia (Golden Horn) gives a maximum depth of about 35 m where the Golden Horn flows into the Bosphorus. That bounds the Galata profiles but does not give depths at the rail; the four profiles (5-8 m at the rail, 12-22 m at 40 m out, deeper on the Bosphorus side) remain design fills.

## What the web cannot give

- **Depth profiles at standing positions.** Charts are protected (SHODB); EMODnet is about 115 m per cell. Without a visit these stay design fills, labelled as such.
- **Clarity, exposure by wind, structure, landing difficulty, angling pressure numbers.** Pressure has one real anchor at the Galata Bridge (hundreds of anglers a day per Zengin 2009); the rest are design fills.
- **Monthly abundance per species at a place.** Only seasons in words (Zengin 2009), turned into numbers by hand and labelled "design fill from <source>".

## Recommendation

Make the **Galata Bridge** the first real spot. It has the best-sourced angling record in Istanbul, a CC0 coordinate, a known length, named species with seasons, and a pressure figure; it is also the most recognisable angling place in the city. Two consequences need the owner's decision:

1. **It is a bridge, not a shore.** Anglers fish from the deck rail over the Golden Horn mouth; casts are short and fish are lifted straight up. Standing positions would be the Karaköy and Eminönü ends, Golden Horn side and Bosphorus side.
2. **Species change** for this spot: horse mackerel, bluefish (çinekop in autumn) and bonito instead of sea bass.

Alternative: Sarayburnu shore (lighthouse, rocks, Bosphorus current; species from search summaries only).

Beyond Istanbul, `spot_candidates_tr.csv` lists 287 coastal structures in Turkey; each needs its own fishing evidence before it becomes a spot.
