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

## R14 species research, picarel (izmarit), 2026-11-18

Zengin (2009) names picarel (izmarit, *Spicara smaris*) at the Galata Bridge all year. **Added to `game/data/` on 2026-11-20** (owner decision: a checked "no minimum size" is enough; Çizelge 7 does not list it, so "Diğer türler: Yok"). Before that, a record was ready but not added: every species must carry a legal minimum size (`test_galata_data.gd`, from the Tebliğ 6/2 table) and that value could not be checked, because `www.resmigazete.gov.tr` does not resolve from the session any more.

| Field | Value | Source |
| --- | --- | --- |
| `scientific_name` | *Spicara smaris* (Linnaeus, 1758), accepted, AphiaID 126830 | WoRMS REST API, 2026-11-18 |
| `lw_a`, `lw_b` | 0.004, 3.365 (both sexes, R2 0.963) | Özpiçak & İbitürk (2024) KMUJENS 6(2): 1-8, Black Sea n=50, TL, https://doi.org/10.55213/kmujens.1478476 (read in full from https://dergipark.org.tr/en/download/article-file/3905889). Aegean sample for comparison: a 0.013, b 2.870 |
| `length_min_cm`, `length_max_cm` | 9.5, 17.5 (TL, Black Sea sample; weight 7.4-64.2 g) | same |
| `regulation.min_length_cm` | **not found** | needs Tebliğ 6/2 (2024/21), Çizelge 7, Resmî Gazete 32629 |
| Everything else (strength, speed, diet `plankton` and `crustacean`, gape about 8 mm, activity, monthly abundance) | design fill | picarel is a plankton and small-crustacean feeder (same paper's introduction); the numbers are ours |

Marmara or Istanbul values for *S. smaris* were not found in a text that could be read (North Marmara study at Marmara University's repository: `openaccess.marmara.edu.tr` does not resolve). The Black Sea sample is the nearest read.

Other species named for Istanbul in sources already read: mullet (kefal, late spring, Zengin 2009), chub mackerel (kolyoz) and Atlantic mackerel at Sarayburnu (search summaries only), scorpionfish (iskorpit) and çinekop at Kuzguncuk (summary only). None has a read length-weight source yet. A Marmara study of *Scomber scombrus* exists (b above 3) but its values were not read.

## Second spot chosen (2026-11-19)

**Sarayburnu** (Q1247633; 41.01714, 28.98605, CC0) is spot 2 in `game/data/spots.json`: the point where the Bosphorus, the Sea of Marmara and the Golden Horn meet; rocky shore (stage `quay`), three positions (Bosphorus side facing NE, Marmara side facing S, Golden Horn side facing NW). Real values: the coordinates (Wikidata), the monthly sea temperature (MGM Marmara mean) and the species named for the place (guide and news pages, search-result summaries only, level S). Everything else (depth profiles, exposure by wind, structure, current, landing difficulty, clarity, pressure, monthly abundance) is a labelled design fill. The three species are the ones already in the game, so no new legal minimum size was needed.

## R17 legal sizes outside Turkey, first pass (2026-11-19)

Read in full (R):

| Text | What it says for our species | Scope | Source |
| --- | --- | --- | --- |
| Regulation (EU) 2019/1241, Annex IX Part A (Mediterranean minimum conservation reference sizes) | Horse mackerel (*Trachurus* spp.) **15 cm**; mackerel (*Scomber* spp.) 18 cm; bluefish and Atlantic bonito are **not listed** | Article 2(2): only Articles 7, 10, 11 and 12 apply to recreational fishing; Annex IX applies to it only if a delegated act extends it to a region. So for anglers the binding sizes come from national law unless such an act exists | Publications Office: https://publications.europa.eu/resource/celex/32019R1241 (EUR-Lex itself answers with a bot check) |
| Spain, Real Decreto 560/1995 (consolidated, BOE-A-1995-8639), Annex II (Mediterranean) | Jurel (*Trachurus* spp.) **12 cm**; no entry for anjova or bonito | Article 1: species "capturadas por buques españoles"; whether it binds shore anglers is a legal reading | https://www.boe.es/buscar/pdf/1995/BOE-A-1995-8639-consolidado.pdf |

Not read yet: Spain's recreational rules (Real Decreto 347/2011 and regional rules such as Andalusia's), Italy (DPR 1639/1968 Allegato 4, Gazzetta Ufficiale), Greece (the ΦΕΚ texts). Turkey: the 6/2 Tebliğ was amended in 2025 (2025/12, spearfishing licence) and again in 2026 (2026/26, Resmî Gazete of 16 September 2026, contents not read); `www.resmigazete.gov.tr` and `www.mevzuat.gov.tr` time out from the cloud, so the Galata sizes (as of 2024-09-01) may be out of date. **For the owner's legal consultation:** which national text binds a shore angler in each country, and whether "not listed" means no minimum size.

## R17 legal sizes, second pass (2026-11-20)

`resmigazete.gov.tr` (without `www.`) answers from the cloud, slowly (one page in up to five minutes); `www.resmigazete.gov.tr` still times out. The tables of Tebliğ 6/2 are images inside the gazette page and were read by eye.

| Country | Text read (R) | Horse mackerel | Bluefish | Atlantic bonito | Scope and open points | Source |
| --- | --- | --- | --- | --- | --- | --- |
| Turkey | Tebliğ 6/2 (2024/21), Çizelge 7 "Denizlerde avlanabilecek türler" (image), and Tebliğ 2026/26 | **12 cm** since 16.09.2026 (row "İstavrit / İstavrit (karagöz)", *Trachurus trachurus, T. mediterraneus*, 13 cm in 2024/21; 2026/26 Madde 5 changed "13 cm" to "12 cm"; Madde 9: in force on publication) | 18 cm (unchanged) | 25 cm, closed 1 April to 14 August (unchanged) | The amateur communique itself, so it binds shore anglers. 2026/26 also: a licence from age 15 with a parent's consent (Madde 1), a permit and catch document for bluefin tuna (Madde 6), a boat licence for amateur boats from 1 September 2027 (Madde 6), no fishing in the traffic separation lanes of the Istanbul and Çanakkale straits (Madde 7). "Diğer türler" (every species not listed, e.g. picarel *Spicara smaris*): size limit "Yok" (none), quantity in the 5 kg day limit | https://resmigazete.gov.tr/eskiler/2024/08/20240811-4.htm (Çizelge 7 in `20240811-4_dosyalar/image024.gif` and `image016.gif`); https://resmigazete.gov.tr/eskiler/2026/09/20260916-5.pdf; the Ministry's note of the publication: https://www.tarimorman.gov.tr/HHGM/Haber/267/ |
| Spain | Real Decreto 347/2011 (pesca marítima de recreo en aguas exteriores, consolidated text of 19.03.2026), Article 4 | 12 cm (through RD 560/1995 Annex II, Mediterranean, consolidated 01.11.2025: "Jurel (Trachurus spp) 12") | not listed | not listed | Article 4: recreational fishing may take only Annex I species and must respect "las tallas mínimas establecidas en el Real Decreto 560/1995". This settles the scope question of the first pass for **outer waters** (aguas exteriores); **inner waters** (inside the baselines, where most shore fishing is) are regulated by each autonomous community (Andalusia, Catalonia, Valencia, Murcia, Balearics), not read yet. Other Mediterranean sizes in Annex II: lubina 23, dorada 20, sargo (*Diplodus* spp.) 15, lisa 16, caballa (*S. scombrus*) 18, boga 11 | https://www.boe.es/buscar/act.php?id=BOE-A-2011-6099 ; https://www.boe.es/buscar/act.php?id=BOE-A-1995-8639 |
| Italy | DPR 1639/1968, Article 87 (text in force since 30.06.1987, Normattiva), and Articles 138 to 144 (sport fishing) | not listed (the general rule: fish under 7 cm are juveniles) | not listed | palamita (*Sarda sarda*) **25 cm** | Article 87 is in the general part of the regulation; Articles 138 to 144 add the sport-fishing rules (gear, at most 5 rods, 5 kg a day, one grouper a day). Whether the EU sizes (Reg. 2019/1241 Annex IX: *Trachurus* 15 cm) also bind Italian anglers is a legal reading; Italian guides say they do. Others in Article 87: spigola 20, orata 20, sgombro 15, cefalo 20 | https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.del.presidente.della.repubblica:1968-10-02;1639~art87 |
| Greece | **Blocked** | | | | `www.minagric.gr` answers HTTP 403 from the cloud; web search finds only blogs and forums whose numbers disagree (horse mackerel 12 or 15 cm). Presidential Decree 373/1985 is the recreational-fishing decree; its size table was not reached | — |

**For the owner (legal reading, not decided here):** (1) Spain: a shore spot is almost always in inner waters, so its sizes are the region's; choose the region before the spot. (2) Italy: do the EU Annex IX sizes apply to recreational anglers? (3) Turkey: the picarel has no minimum size under 6/2 ("Diğer türler: Yok"); is "checked: no minimum" enough to add it (owner decision 2026-11-19 was: no species without a checked legal size)? (4) Greece: keep it in R17 and wait for the source, or replace it with a country whose texts are reachable.

## R17 legal sizes, third pass (2026-11-20)

After the owner's decisions D10 to D14 and a network update (`www.juntadeandalucia.es`, `www.dgrm.pt`, `dgrm.pt`, `www.legifrance.gouv.fr`, `www.dirm.mediterranee.developpement-durable.gouv.fr`, `www.vgo.gr`, `fishradar.ai`). The values are in `game/data/jurisdictions.json`.

| Jurisdiction | Read | Horse mackerel | Bluefish | Bonito | Picarel | Source |
| --- | --- | --- | --- | --- | --- | --- |
| Spain, Andalusia (inner waters) | Decreto 205/2023 (BOJA 169, 4.9.2023), Article 8: recreational fishing respects the EU minimum conservation reference sizes (Reg. 2019/1241); Article 9: 5 kg a day | 15 cm (Annex IX) | not listed | not listed | not listed | https://www.juntadeandalucia.es/boja/2023/169/BOJA23-169-00019-13843-01_00288842.pdf |
| Italy | (second pass) Article 87 is silent on horse mackerel | 15 cm by design (D11: the stricter EU size) | 7 cm (Article 87's juvenile rule) | 25 cm | 7 cm | Normattiva, DPR 1639/1968 |
| Portugal (mainland) | DGRM table of minimum sizes, 27.02.2026; DGRM FAQ (2018): the sizes apply to recreational fishing (Portaria 14/2014, Article 10(2)) | 15 cm | "não se aplica" | "não se aplica" | not checked | https://www.dgrm.pt/documents/20143/121101/Esp%C3%A9cies+-+Peixes+-+2026-02-27.pdf/163f9588-b859-eb23-c134-4413c40da185 ; https://www.dgrm.pt/documents/20143/0/FAQ-PescaLudica2018.pdf/730e6d56-1f8c-66a2-a020-aecc016685bb |
| Greece (unofficial) | vgo.gr guide (2025) citing P.D. 373/1985 and its revisions: sea bass 25 cm, groupers 45 cm, octopus 750 g, other fish under 150 g go back, 5 kg a day; fishradar.ai lists sea bass 23 cm, sea bream 20 cm | 15 cm (guides apply the EU sizes) | unknown | unknown | unknown | https://www.vgo.gr/tips/177.html?lang=En ; https://fishradar.ai/fishing/regulations/greece/ |
| France | **Blocked**: Légifrance answers HTTP 403, the DIRM Méditerranée table 404. A search summary gives chinchard 15 cm and bar 30 cm in the Mediterranean (arrêté of 26 October 2012) | — | — | — | — | not read |

Still open for R17: the map screen, a spot per country with its species list (sourced), and which spots use which jurisdiction.

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

## İzmir Kordon (2026-11-22, R17, owner decision: three spots per country)
Kordon (Wikidata Q6013884; 38.43556, 27.13944, CC0), the waterfront of İzmir's inner bay. Positions: Alsancak by the ferry terminal (Q55808401), Pasaport pier (Q18209626), Konak pier (Q6428725); stage `quay`. Sea temperature: MGM Aegean monthly means 1970-2025 (R). Species (R): Ulaş, Tunca and Aydın (2019, Acta Adriatica 60(2): 157-180) interviewed 634 shore anglers in 2016 in Göztepe, Karataş, Konak, Pasaport, Alsancak, Bayraklı, Karşıyaka and Bostanlı: gilthead sea bream (*Sparus aurata*) was the main catch, then sea bass and mullets; horse mackerel (*T. trachurus*), chub mackerel, bogue, pandora, annular and common two-banded sea bream, squid (*L. vulgaris*) and serranids in small amounts; bluefish and bonito are not reported. Gökçe et al. (2005) add picarel in the bay. In the game: horse mackerel, picarel and squid. Not added: gilthead sea bream, the spot's main fish, which would need its own species record (legal size in Çizelge 7, a length-weight source); a question for the owner.
