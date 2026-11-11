# Fishing game market: real numbers, still no proven niche

> **Status: second pass, replaces the first report. Date 2026-11-11.**
>
> **Verdict box**
> - **Overall: split.** Evidence about the *market* (who plays, what they praise and hate) moves from WEAK to **MODERATE**: primary store numbers and real reviews now exist. Evidence of *demand for Mera's exact concept* (a realistic, real-location shore-fishing game) is **still WEAK**.
> - **What improved:** primary Steam, Google Play, App Store and fws.gov pages were read; real, dated, verbatim reviews with stated sample sizes (504 Steam sim reviews, 1,391 Steam cozy/indie reviews, 117 mobile reviews); a reproducible Steam Fishing-tag count (1,765 results); a primary US angler number (39.9M).
> - **What did NOT change:** **0 direct requests** for a real-location shore game; **0 Turkish demand signals**; Turkey has **no official angler count**. Reddit, SteamDB, Eksi Sozluk, Roblox, Poki, CrazyGames, the itunes API, Dergipark, TUIK and others were unreachable.
> - **Why not "moderate" overall:** the closest evidence is about 4 Steam forum posts (2015 to 2025) asking Fishing Planet for more real or shore locations, and they ask for features in an existing game, not for a new product. Absence of evidence is not evidence of absence, but it is not support either.
> - **Board (first-pass, not re-run):** 3 x FUND IF, average 4.7/10.

## Research overview

**Question.** What do players of mobile and web fishing games, fishing sims and cozy games with fishing praise and complain about; what is unmet; is there evidence of demand for a realistic, real-location shore-fishing game (Mera)?

**Pass 1 (first-pass, snippet level).** Five researchers used web-search result summaries only; WebFetch could not reach Steam, Play, the App Store or fws.gov. A three-member founder board (Offers, Monopoly, Product lenses) then read the brief. The market-and-economics findings and the board verdict were **not re-run** in pass 2; they are kept below and labelled **[1st]** because they rest on search summaries and aggregator sites. Nothing from pass 1 that has no source URL is carried over.

**Pass 2 (primary pages).** Four researchers read pages with `curl` through the session proxy (WebFetch could not resolve Steam, Apple or fws.gov hosts). Tagged **[P]** = read from a primary page on 2026-11-11.
- Steam: store pages, `appdetails` JSON, the community review hub, discussion threads, and tag search results.
- Google Play (17 listings) and App Store (7 listings): installs brackets, ratings, rating counts, descriptions, reviews.
- fws.gov: the 2022 national survey report and press material.

**Limits, stated plainly.**
- **Review samples are small, non-random and keyword-tagged.** Steam's JSON review endpoint redirected to the store home for every app (one retry with browser-like headers was blocked by the harness and not repeated), and the hub returns only 10 cards per filter. Sim samples are pooled from 9 hub filters (most recent, trending, most helpful, funniest), so they mix old and new. Sample sizes: Fishing Planet 59 (38 positive / 21 negative), Call of the Wild 49 (33/16), UFS2 42 (18/24), Euro Fishing 26 (13/13), Fishing Sim World 34 (19/15), Russian Fishing 4 50 (40/10), Pro Fishing Simulator 19 (9/10), Real VR Fishing 33 (19/14), How to Fish 46 (39/7), UFS1 41 (31/10), Bassmaster 37 (23/14), Professional Fishing 2 32 (25/7), Fish Hunters 36 (8/28); **504 in total**. The target of 15 positive and 15 negative per game was met only partly. Cozy/indie samples (helpful-sorted plus recent): Cast n Chill 195/141, Moonglow Bay 165/135, DREDGE 196/188, WEBFISHING 186/185 (**1,391 in total**), with forced near-equal positive and negative pools that over-represent negatives for 95%-positive games. Mobile: **117 reviews** (Play 48, three embedded per page; App Store 69, about ten per app).
- **Theme counts are not prevalence rates.** They come from regex keyword tagging with manual spot-reading, accurate to about +/-2 per theme; the mobile "monetisation" count is an upper bound.
- **English only.** All Steam percentages are English-language figures. Steam shows no all-language percentage, and pass-1 totals from trackers were all-language, so the two sets are not comparable. Positive/negative counts are percent x total and therefore derived.
- **Unreachable:** Reddit, SteamDB, Eksi Sozluk, Roblox, Poki, CrazyGames, the itunes API, Dergipark, TUIK, tarimorman.gov.tr, gov.uk, mhlw.go.jp, tbmm.gov.tr, mynet.com, tamindir.com, donanimhaber.com; Google Play "See all reviews"; Steam's Fishing Fest page. EU, UK, Japan and Korea official angler counts were not reached.
- **Confidence labels.** High = primary page or several independent sources agree; Medium = primary but small or biased sample; Low = single, aggregator or marketing source.

## Corrections to the first report

The new notes override the old where they conflict. Conflicts are listed, not smoothed.

1. **Fishing Clash "about 144.6M Android installs" is unverified.** Google Play shows only a **100M+** bracket (4.74 from 1,960,791 ratings, updated 2026-11-02). 144.6M came from an AppGoblin estimate; Play cannot confirm or refute it ([Play](https://play.google.com/store/apps/details?id=com.tensquaregames.letsfish2&hl=en&gl=US)).
2. **Hooked Inc was mis-described.** The correct package is `se.ace.fishinc` (the id `com.lionstudios.hookedinc` returns HTTP 404; the developer shown is Lion Studios). The pass-1 "4.59 from about 2M reviews" holds only as **ratings, not reviews, and only combined across stores**: Play 4.56 from 1,514,561 ratings plus App Store 4.7 from 504,033 gives 2,018,594 ratings, weighted mean 4.60 (our arithmetic). No single store shows 4.59 ([Play](https://play.google.com/store/apps/details?id=se.ace.fishinc&hl=en&gl=US); [App Store](https://apps.apple.com/us/app/hooked-inc-fisher-tycoon/id1436213906)).
3. **Ace Fishing "30M downloads in 12 months" is not supported.** Play shows **10M+** lifetime (1,344,739 ratings) and iOS only 4,864 ratings; the figure was a circa-2015, undated search-summary claim ([Play](https://play.google.com/store/apps/details?id=com.com2us.acefishing.normal.freefull.google.global.android.common&hl=en&gl=US); [App Store](https://apps.apple.com/us/app/ace-fishing-wild-catch/id694972182)). Dropped.
4. **Call of the Wild: The Angler and Russian Fishing 4 are no longer "Mixed".** Steam now shows Call of the Wild **Mostly Positive, 71% of 3,149 English reviews** (last 30 days: Very Positive, 89% of 29), and Russian Fishing 4 **Mostly Positive, 79% of 7,762** (last 30 days: Very Positive, 82% of 1,179) ([CotW](https://store.steampowered.com/app/1408610/); [RF4](https://store.steampowered.com/app/766570/)).
5. **Earlier review totals were all-language tracker figures and are not comparable.** Pass 1: Fishing Planet about 65,699 reviews at about 87%; Russian Fishing 4 about 77,000; Call of the Wild 7,191 at about 63%; UFS2 2,005 to 2,239 at 67.55 to 68%. Steam English pages: Fishing Planet 84% of 29,654; UFS2 62% of 701 (label "Mixed" agrees, share is lower; Steam's all-language field, 2,108, fits the pass-1 range). Euro Fishing (64% of 1,500) and Fishing Sim World (79% of 953) agree with pass 1. Use Steam's English figures as lower-bound evidence only.
6. **iFishing identity.** On Play, `com.carlo.ifishing` is an unrelated social/e-commerce app (1K+ installs, no rating). The iOS "i Fishing" (id294380152, Chris Egerter) is a **paid $2.99 2008-era app** (4.7 from 782 ratings; reviews date from 2008). Pass 1 treated them as one product line; they are not ([App Store](https://apps.apple.com/us/app/i-fishing/id294380152)).
7. **Direct-request count.** Pass 1 said "0 verified direct requests, 3 adjacent threads". Pass 2 read about 4 dated Fishing Planet threads asking for real or shore locations, plus realism threads. Direct requests for the concept remain **0**.
8. **Not found as Steam products:** Legendary Fishing and Rapala Fishing (store search returned nothing), and "A Game About Fishing" by name. Pass 1 listed them as "not covered".
9. **Not rechecked, kept as [1st]:** Stardew mod download count, Webfishing concurrent peaks, Raijin/VaporLens/AppGoblin estimates, Roblox figures, portal revenue splits, UK sea-angler counts, Fishbrain history. Fishbrain's store text is itself inconsistent (App Store says both "more than 20 million anglers" and "over 15 million members") ([App Store](https://apps.apple.com/us/app/fishbrain-fishing-app/id477967747)).

## Key findings

### 1. The fishing audience is large, but realistic sims are mid-rated and the big players are free-to-play
- **Evidence [P].** Play: Fishing Clash 100M+; Hooked Inc, Ace Fishing, Let's Fish, Fishing and Life, Fishing Superstars 10M+; Fishing Planet and Fishing Master 5M+; Fly Fishing Simulator 1M+ (4.25) ([Play listings, table below](https://play.google.com/store/apps/details?id=com.pishtech.ffs&hl=en&gl=US)). Steam English ratings of realistic or real-place sims: Fishing Planet 84%, Russian Fishing 4 79%, Fishing Sim World 79%, Professional Fishing 2 77%, Real VR Fishing 75%, Call of the Wild 71%, Euro Fishing 64%, UFS2 62%, Pro Fishing Simulator 51% ([Steam search listing](https://store.steampowered.com/search/results/?term=fishing+simulator&category1=998&count=50&infinite=1&cc=us&l=english)); a **62 to 84% English range** for the better-known ones. The two free-to-play titles (Fishing Planet, Russian Fishing 4) carry the review volume; premium titles ($19.99 to $29.99) sit at 62 to 77%.
- **Frequency.** 9 realistic sims with a primary rating.
- **Impact.** A paying-sized audience exists, but nothing in it shows a realistic premium sim winning big. Realism sims are a niche with room (Play ratings of Fishing Planet 4.76 and Fly Fishing Simulator HD 4.66 are the highest in the set) rather than a mass market.
- **Confidence: High** for the figures, **Medium** for the niche reading.

### 2. Monetisation friction dominates free-to-play complaints; bugs and abandonment dominate premium sims
- **Evidence [P].** Mobile reviews (n=117): monetisation/pay-to-win/price 59 (upper bound), ads 27, bugs 26, grind/energy 25, PvP unfairness 29. Steam, monetisation/DLC/grind in negatives: Fishing Planet **11 of 21**, Russian Fishing 4 4 of 10, Fishing Sim World 6 of 15. Bugs: UFS2 10 of 24, Fishing Planet 9 of 21. Update stoppage: Real VR Fishing 7 of 14, Fishing Sim World 5 of 15. Verbatim: "Feels like I'm playing a [expletive] mobile game with all the popups begging for money" (Fishing Planet, 2026-10-12); "you can only play the game so long until you are forced to buy lure packs. This is nothing but a cash grab game" (Fishing Clash, Play, 2026-08-15); "Developers aren't working on this game anymore. They sold the rights of the game to a publisher who doesn't care about maintaining the game anymore" (UFS2, 2026-11-01) ([Steam hub](https://steamcommunity.com/app/380600/reviews/?browsefilter=mostrecent&filterLanguage=english); [Play](https://play.google.com/store/apps/details?id=com.tensquaregames.letsfish2&hl=en&gl=US); [UFS2 hub](https://steamcommunity.com/app/1136380/reviews/?browsefilter=mostrecent&filterLanguage=english)).
- **Frequency.** Every free-to-play title sampled; 4 of 5 premium sims show bugs or abandonment.
- **Impact.** The no-ads, no-timers promise addresses the most robust complaint theme. It also removes the revenue the incumbents live on (the 65% ads / 35% IAP split for Fishing Clash is an AppGoblin estimate with conflicting listings **[1st]**, do not quote).
- **Confidence: High** for direction, **Medium** for magnitude (non-random samples).

### 3. Real anglers police realism, and what they criticise is fight length, line logic and lure behaviour
- **Evidence [P].** About **16 positive and 6 to 7 negative** self-identified real-angler reviews in about 500 pooled sim reviews (about 4.5%). Negatives: "As an avid angler, this game makes ZERO sense to me. You break off fish that you could easily land IRL with same tackle. fish fights are way to long for fish size/species." (UFS1, 2026-06-04); "Obvioulsy the people who made this game have never fished in their lives. The amount of time you drop a fish is ridiculous" (Fishing Sim World, 2019-01-28); "Lures don't move... at all." (Bassmaster, 2026-02-10); "it takes way to long to bring in fish" (Fly Fishing Simulator, Play, 2022-02-15). Species and place accuracy are also checked: "as an avid IRL fisherman some of the incorrect/unrealistic species depictions and locations took away from my enjoyment." (Cast n Chill, 2025-08-19); an App Store reviewer flagged Redfish in Key West in Fishing Master (2024-12-14) ([FSW hub](https://steamcommunity.com/app/834280/reviews/?browsefilter=mostrecent&filterLanguage=english); [Fishing Master App Store](https://apps.apple.com/us/app/fishing-master/id6471659176?see-all=reviews)).
- **Frequency.** 7+ games; "unrealistic/arcade" mentions are 0 to 2 per game (thin per game).
- **Impact.** Supports pillar 2 (readable realism) and pillar 1 (sourcing): errors are caught and named. It also warns that a fight tuned for drama can be marked down by the very audience Mera targets.
- **Confidence: Medium.**

### 4. Real anglers also play sims as a substitute when they cannot fish
- **Evidence [P].** "Whenever I am not able to actually fish outside I do on here." (Fishing Planet, 2026-10-13); "I just turned 90 years old and can no longer go fishing in real life. I find this game to be a realistic fishing experience." (Call of the Wild, 2023-01-31); "I go fishing a lot irl, but when every its to bad of weather or the fish just wont eat, i play this, 10/10, super realistic" (Fishing Sim World, 2025-12-13); "Great refresher if you don't get out as often as you'd like." (Fly Fishing Simulator HD, App Store, 2024-05-10). A beginner bought a real rod after about 50 hours in UFS1 (2019-07-11).
- **Frequency.** About 6 reviews in 5 games (thin). Five of the positives are older or disabled former anglers.
- **Impact.** A plausible motivation for a calm shore game with real places, but the base is a handful of reviews.
- **Confidence: Low to Medium.**

### 5. Collection and calm are validated pulls, but the fishing verb alone is called shallow or repetitive
- **Evidence [P].** Cast n Chill positives: relaxing/cozy 107 of 195; collection or logbook 33 of 195. Negatives: repetitive 37 of 141, shallow 14 of 141. DREDGE negatives: repetitive 84 and shallow 33 of 188. Moonglow Bay: bugs/controls dominate (105 of 165 positives and 106 of 135 negatives match that regex; manual read of 18 negatives: 11 on bugs or controls). Quotes: "The fish logbook is fun to chase" (Cast n Chill, 2026-11-08); "It's very pretty. It's very chill... and that might be enough. Maybe... it's just also very, very shallow." (Cast n Chill, 2025-06-23); "if I wanted to do a bunch of waiting only to leave unsatisfied, I'd just go fishing in real life." (DREDGE, 2023-03-30); "If I wanted to sit on a lake all day and catch nothing I'd go real fishing." (Call of the Wild, 2022-11-27) ([Cast n Chill hub](https://steamcommunity.com/app/3483740/reviews/); [DREDGE hub](https://steamcommunity.com/app/1562430/reviews/)).
- **Frequency.** 4 of 4 cozy/indie titles read; the same shallow-loop complaint appears in 2 realistic sims (Call of the Wild "an exploration game with fishing elements").
- **Impact.** Pillar 5 (collection and mastery) has first-hand support; the cast-bite-fight loop needs depth and a reason to repeat. Waiting is criticised by both camps.
- **Confidence: Medium.**

### 6. Real places are common marketing, but explicit requests are thin and shore is barely mentioned
- **Evidence [P].** Of 14 Play descriptions read, **5 name specific real places** (Fishing Clash, Fishing Planet, Fishing Master, Let's Fish, Ace Fishing); only Fishing Planet states "All waterways are based on real locations." Reviews (n=117): about 8 explicit real-place or real-life correspondence mentions; a Fly Fishing Simulator reviewer "found a new king salmon spot by trying one of the streams in the game on an actual fishing trip" (2021-12-14). Steam threads, Fishing Planet: "Saltwater fishing?" (2015-08-07, asks for Montauk surf and Kona), "Surf Fishing" (2017-03-22), "Ocean Fishing" (2017-07-17), "Surf fishing" (2025-10-14, 0 replies), "why is there only one place on shore to fish, in the japan map" (2024-12). Shore, bank or surf is mentioned in **1 to 2 reviews per game at most**; no tide request was found ([Fishing Planet threads](https://steamcommunity.com/app/380600/discussions/3/537405286637202337/); [2024 thread](https://steamcommunity.com/app/380600/discussions/0/591757083455540113/)).
- **Frequency.** About 4 independent real or shore location requests; **0 for a new game built on real shore spots**; none for a specific sourced local spot.
- **Impact.** The central Mera claim is still unevidenced as demand. Players do police accuracy, so unsourced claims carry risk (pillar 1).
- **Confidence: Medium** that the demand is thin; **Low** that it is absent (Reddit, Turkish forums and 5 of 6 other games' threads were not searched; Steam discussion search returned HTTP 429 for every app but Fishing Planet).

### 7. Steam fishing is crowded and growing, and the best recent hit is not a realism game
- **Evidence [P].** The Steam Fishing tag (id 15564) returns **1,765** results; of 1,671 unique ids retrieved, **915** have an exact release date up to 2026-11-11 and **706 of those (77%)** are dated 2023 to 2026. Per year: 2022: 52; 2023: 85; 2024: 124; 2025: 198; 2026 to date: 299. 94 ids were not recovered; the tag is user-applied, so many entries are small or only partly about fishing ([search method](https://store.steampowered.com/search/results/?query&start=0&count=50&tags=15564&category1=998&infinite=1&cc=us&l=english)). Big recent fishing-centred hits: Cast n Chill (2025, $14.99, 8,685 reviews, 95% of 5,352 English) and WEBFISHING (2024, $4.99, 57,425 reviews, 97% of 50,091 English); **How to Fish (Aug 2026, $7.99) is 95% of 29,893**, but Steam describes it as a "physics based fishing simulator" about crashing on an island, a 1 to 4 player co-op comedy, not a realistic sim ([How to Fish](https://store.steampowered.com/api/appdetails?appids=4001890)). New real-place or realistic entrants exist: Professional Fishing 2 (Sep 2025, 77% of 450, $24.99), Finnish Fishing Simulator (coming soon, "Relaxed Finnish lake fishing"), Wade: Fly Fishing (Q4 2026, Quebec river, VR).
- **Frequency.** One tag count; 4 notable recent entrants.
- **Impact.** Discovery, not feasibility, is the constraint. Review volume goes to hybrids and comedy; realism titles sell, but modestly.
- **Confidence: High** for counts (method disclosed), **Low** for any sales reading (no owner data; SteamDB unreachable).

### 8. The addressable population is large in the US, unmeasured in Turkey
- **Evidence [P].** US: "In 2022, there were 14.4 million hunters and 39.9 million anglers 16 years and older"; about 15% of Americans 16+ fished; participation "had declined from prior levels" ([FWS 2022 report](https://www.fws.gov/sites/default/files/documents/2024-09/2022-fishing-and-hunting-r3-in-the-us.pdf); [FWS press release](https://www.fws.gov/press-release/2023-10/americans-spent-394b-hunting-fishing-and-wildlife-associated-activities-22)). 43% of anglers also use motorboats; shore versus boat share was not in the pages read. Turkey: no official count. A federation figure of about 2M rod anglers (OBAF president, quoted in a mynet article) comes with his own statement that it is "not firm because anglers are not registered"; the page was not opened (search snippet) **[1st/snippet]**. Local figures: 11,276 licensed amateur anglers in Ankara (undated), 94.6% of surveyed Elazig anglers unlicensed (snippets) ([Dergipark](https://dergipark.org.tr/tr/pub/yunusae/article/235404)). Fishing Planet's Steam listing has no Turkish among 14 languages ([appdetails](https://store.steampowered.com/api/appdetails?appids=380600&l=english)).
- **Frequency.** 1 primary count (US); 0 primary Turkish counts.
- **Impact.** US size is real but shrinking; Turkish market size is guesswork. The absent Turkish language in the dominant sim is a possible gap, with no evidence Turkish players ask for it.
- **Confidence: High** (US figure), **Low** (Turkey).

## Game-by-game table

Tags: **[P]** = read from the primary store page on 2026-11-11; **[1st]** = pass-1 search-summary or aggregator figure, unrechecked. Steam percentages are English-only unless stated. "Praised" and "complained" are from the samples above unless tagged [1st].

| Game | Platform | Scale | Praised | Complained |
|---|---|---|---|---|
| Fishing Clash | Mobile | [P] Play 100M+, 4.74, 1,960,791 ratings; iOS 4.8, 158,709. [1st] bookings PLN 197.5M in 2025, -18.6% y/y ([TSG](https://tensquaregames.com/2026/03/23/financial-results-of-ten-square-games-group-for-q4-and-full-year-2025-trophy-hunter-and-portfolio-transformation-mark-a-new-stage-of-development/)) | [1st] visuals, authentic reel feel | [P] pay-to-play, FOMO events, lags and crashes |
| Hooked Inc | Mobile | [P] Play 10M+, 4.56, 1,514,561; iOS 4.7, 504,033 | [1st] relaxing, art style | [P] flooding with ads (App Store, 2021), double-charge (Play, 2026-09-04) |
| Ace Fishing: Wild Catch | Mobile | [P] Play 10M+, 4.51, 1,344,739; iOS 4.6, 4,864 | [P] depth versus others (2022) | [P] "Good game but realistic? Not so much." (2018) |
| Let's Fish; Fishing and Life | Mobile | [P] Play 10M+; 4.37 (717,677) and 4.01 (338,892) | [P] "really chill and relaxing" (Fishing and Life, 2019) | [1st] ads, energy timers |
| Fishing Master | Mobile | [P] Play 5M+, 4.05, 11,658; iOS 4.8, 23,918 | [P] hook sets, directional changes, line tightness (2025) | [P] species error (Redfish), wants more spots; [1st] energy timers |
| Fishing Planet | Mobile and PC | [P] Play 5M+, 4.76, 84,691; iOS 4.8, 21,855. Steam free-to-play, 84% of 29,654, last 30 days 86% of 504; 2017 release | "only game that mimics real fishing" (App Store, 2025); real locations (store claim) | [P] travel and licence costs, popups, grind, bugs; no novice guide (App Store, 2026-01-02) |
| Fly Fishing Simulator (and HD) | Mobile | [P] Play 1M+ 4.25 and 500K+ 4.66; iOS HD 4.4, 383 | [P] fish react to environment, used on real trips | [P] fight too long (Play, 2022) |
| Fishing Paradiso; Monster Fishing; Fishing Superstars; Ace Crew | Mobile | [P] Play 1M+ (4.57), 1M+ (3.72), 10M+ (4.17, last updated 2024-04-04), 1M+ (4.17) | [P] "Fish acting like fish" (Paradiso, 2020) | none read |
| Tiny Fishing and portal games | Web | [P] one Play clone 100K+, 3.89; portal play counts unreachable | n/a | n/a |
| Russian Fishing 4 | PC | [P] free-to-play; 79% of 7,762; last 30 days 82% of 1,179 | [P] "reference to real life fishing", dynamic fish spots, hard | [P] premium pricing, refund ban claim |
| Call of the Wild: The Angler | PC | [P] $29.99; 71% of 3,149; [1st] about 140.9K copies, about $2.5M gross (Raijin estimate) | [P] relaxing; real anglers' praise | [P] "exploration game with fishing elements", shallow, visuals |
| Ultimate Fishing Simulator 2 | PC | [P] $19.99; 62% of 701 | [P] "best choice" for IRL anglers (2025) | [P] bugs, unrealistic physics, developers left (2026-11-01) |
| Ultimate Fishing Simulator 1 | PC | [P] 88% of 2,590 (listing) | [P] a beginner bought a real rod | [P] fights too long, "arcade" |
| Euro Fishing | PC, console | [P] $2.99 on sale (was $14.99); 64% of 1,500; five peg and bank venues [1st] | [P] a UK course fisherman's praise (2015) | [P] "arcade rubbish", console dumbing-down |
| Fishing Sim World: Pro Tour | PC | [P] $3.99 on sale (was $19.99); 79% of 953 | [P] "super realistic" (2025-12-13) | [P] crashes, line breaks on small fish, abandoned updates |
| Pro Fishing Simulator | PC | [P] $0.99 on sale (was $9.99); 51% of 49 | [P] "relaxing and entertaining" | [P] glitches |
| Real VR Fishing | PC, VR | [P] $19.99; 75% of 193 | [P] "love fishing in real life, of all kinds" | [P] no updates to the Steam version (7 of 14 negatives) |
| Bassmaster Fishing 2022 | PC, console | [P] 72% of 313 | [P] AI "better than most" (2022) | [P] lures static, small fishable area |
| Professional Fishing 2 | PC | [P] $24.99; 77% of 450 | not read | not read |
| How to Fish | PC | [P] $7.99; 95% of 29,893 (co-op comedy) | co-op fun | none (7 negatives) |
| Cast n Chill | PC | [P] $14.99; 95% of 5,352 English; 8,685 all-language | relaxing, art, logbook | shallow, repetitive, price |
| WEBFISHING | PC | [P] $4.99; 97% of 50,091 English; 57,425 all-language | social hangout, calm | lost saves, abandonment (reviewer claims) |
| DREDGE | PC, console | [P] $19.99 (sale; list $39.99); 96% of 33,128; 48,562 all-language | atmosphere, fish notebook | repetitive, shallow |
| Moonglow Bay | PC, console | [P] $24.99; Mixed, 65% of 683 | cozy story | bugs, controls |
| Dave the Diver; Stardew Valley; Spiritfarer; Cozy Grove; Dreamlight Valley | PC | [P] 96% of 51,600; 98% of 397,093; 94% of 18,998; 90% of 3,847; 91% of 15,982 (English). [1st] Dave 10M copies | early fish-and-serve loop (Dave) | fishing as chore or shallow in Spiritfarer and Cozy Grove; thin elsewhere |
| Fisch / Fish It! | Roblox | [1st] only; RoWatcher figures unverified; Roblox unreachable | n/a | n/a |
| Fishbrain (not a game) | Mobile | [P] Play 10M+, 4.53, 67,763; store text claims 15M+ anglers; [1st/estimate] about 649K MAU (AppGoblin) | spot-based social use | [P] ads |

## Segments

**Realism enthusiasts (hobby anglers).** The group Mera targets first. The best-rated realism sims (Fishing Planet 84%, Russian Fishing 4 and Fishing Sim World 79%, English, all players) draw praise for realism from them, while self-described anglers mark down UFS1, Euro Fishing after its console changes and Bassmaster. Size for shore anglers is unknown: no country gives a shore share. A US ceiling of 39.9M anglers (about 15% of adults, declining) is the only primary number.

**Substitute players.** Anglers who cannot fish (age, injury, weather, time) and play a sim instead. About 6 reviews; plausible, small evidence.

**Cozy collectors.** Cast n Chill and WEBFISHING show review volume and a calm, collection-led pull. They do not ask for realism, but a few real anglers appear in them (about 4 positive, 3 to 4 negative in 336 Cast n Chill reviews).

**Casual mobile players.** The largest base (Fishing Clash, Hooked Inc, Ace Fishing) but the least fitting: events, ads, energy. A long-session realistic game suits ad-funded portal economics poorly (inference **[1st]**).

**Turkish shore anglers.** No evidence of game demand. Fishing Planet has no Turkish language; a Turkish listicle recommends Rapala, UFS, Fishing Planet and Russian Fishing 4 as the most realistic (snippet **[1st]**) ([Tamindir](https://www.tamindir.com/liste/en-iyi-balik-tutma-oyunlari/)). That is a gap in the search, not proof of a gap in the market.

## Opportunity areas

1. **A fight and line model that real anglers accept.** Fight length, line breaks on small fish and lure behaviour are the named complaints. Evidence: Medium (7+ games). Risk: needs expert input; the Steam reviewer advice is blunt ("Consult actual fisherman").
2. **Sourced places and species, labelled design fill where no source exists.** Competitors name places as marketing; none in the set exposes sources. Players catch species and place errors. Evidence: Medium for the pain, untested for willingness to value sourcing.
3. **No ads, no timers, no pay-to-win.** The strongest complaint cluster (finding 2). It also removes incumbents' income, so it is a promise, not a moat.
4. **Shore as a first-class feature.** Shore or bank is rare in review text (1 to 2 per game) but Fishing Planet users ask for it across 2015 to 2025, and Euro Fishing, Sea Fishing Simulator (iOS: shore, pier, boat, kayak, real-time and weather mode) and Real VR Fishing (real-world locations) are the nearest products, per store descriptions and search summaries only **[1st/snippet]**. Unverified whether any is shore-first.
5. **Beginner guidance.** Thin: two clear requests (Fishing Planet, 2026-01-02, "no systematic novice guide") and the fly-fishing "refresher" use. Evidence: Low.
6. **Offline, single-player economics.** Live-service fishing shutdowns (Fishing Frenzy, World of Fishing, Atom Fishing 2) cite revenue not covering ongoing cost **[1st]**; a no-network design avoids it (inference).

## Recommendations

Aligned with the owner's decisions of 2026-11-11 (next section).

1. **Treat the concept as a hypothesis, not a validated market.** Run the waitlist demand test in parallel with the one-spot slice. Set the pass bar before launching it.
2. **Test 5 anglers and 5 non-anglers** on the slice, with a pass bar written beforehand, covering: does the fight stay interesting across repeated catches, is line logic believable, does a first-time player understand the screen.
3. **Run a "shore" feature check** of Euro Fishing, Sea Fishing Simulator and Real VR Fishing (the nearest competitors) by playing or reading their store pages, before claiming a gap.
4. **Do not quote any aggregator estimate** (AppGoblin, VaporLens, Raijin, RoWatcher, GameSensor) in the PRD or store copy.
5. **Run a Turkish-language evidence pass** from a network that reaches Eksi Sozluk, Donanimhaber, Turkish olta forums, Reddit, Dergipark and TUIK; until then, no Turkish market number goes into the PRD.
6. **Build realism review into the data**: every spot and species line carries a source or a design-fill label, in the data and in the in-game log.

## Board stress test (first-pass, kept)

The founder board (Offers, Monopoly and Product lenses, applying published frameworks, no real person's views) read **only the pass-1 brief**, built from search-snippet notes. It was **not re-run** with pass-2 evidence; its verdict stress-tests the logic of the idea, not the new data. Vote: **3 x FUND IF**; scores Offers 4, Monopoly 4, Product 6; **average 4.7/10**.

Risks raised by more than one member: no verified demand for a real-location shore game and no Turkish signal (all three; pass 2 did not change either); two audiences with opposite wants, realism hobbyist versus cozy collector (pass 2 data suggests the audiences differ in the same way, see finding 5); the cast-bite-fight loop may become repetitive (pass 2 supports this in cozy and sim reviews); no distribution plan or cost per player in a crowded field (pass 2 confirms crowding, finding 7). Single-member risks: realism and sourced data are copyable; phone web performance and landscape-only could break the first five minutes.

Merged conditions: one first audience and a one-sentence pitch; a verified demand signal in at least one language market (waitlist or priced pre-sale); a one-spot slice tested with at least 5 anglers and 5 non-anglers against a pre-set bar, including whether the fight stays interesting; frame rate on a named mid-range phone; one distribution channel with cost per player; a named compounding asset while keeping no ads and no timers; a stop date if tests fail. The strongest version the board saw: a free, calm, no-ads web game with one very good real Turkish spot, aimed at one audience, as a cheap experiment.

## What this means for the spec

Nothing below changes a decision. The owner's decisions of 2026-11-11 are recorded first; the new evidence follows each, with risks and what to test. Open items list options with a recommendation.

### Owner decisions, 2026-11-11

1. **Scope:** one-spot vertical slice first, plus a waitlist demand test in parallel.
2. **First audience:** realism enthusiasts (hobby anglers).
3. **First spot data** from non-OSM sources; **legal advice before any OSM use.**
4. **Business model:** MVP free, no ads, no timers, with a waitlist; later a one-time paid release; ads, timers and pay-to-win are out.

### What the new evidence says

**Decision 1, one spot plus waitlist.** Support: demand for the concept is unproven (finding 6), so a small build plus a cheap demand test fits the evidence; the board's conditions say the same. Risk: players judge locations by size and variety (map or location mentions: Call of the Wild 7 positive / 10 negative, Fishing Planet 1 / 11; Bassmaster: "Maps appear large, but fishable area is actually very small" (2026-02-10)), so a single spot will be judged on depth, and "shallow" is the main complaint of fishing-centred games (finding 5). New real-place sims (Finnish Fishing Simulator, Wade: Fly Fishing) are arriving. Test: the waitlist; 5 anglers plus 5 non-anglers; the shore feature check.

**Decision 2, realism enthusiasts first.** Support: the best-rated realism sims (79 to 84% English, all players) are praised by anglers for realism, and anglers are the group most able to value sourced places (an inference). Risks: (a) realistic sims are a small audience with mid ratings (62 to 84% English, finding 1); (b) real anglers are the harshest judges and criticise fight length and line logic (finding 3); (c) the "audience uses sims when they cannot fish" pattern (finding 4) means some of them are not looking for a technique simulator; (d) no shore share or Turkish count exists. Test: do the 5 anglers accept the fight and line model; compare their reaction with the 5 non-anglers.

**Decision 3, non-OSM first-spot data; legal advice before OSM.** Plain-language ODbL, from the pass-1 reading of OSM pages **[1st]**: OpenStreetMap data may be used commercially if the game visibly credits OpenStreetMap. If the game builds its own database by combining OSM data with other data, or copies a substantial part of OSM, the combined database may have to be shared under the same licence, and "substantial" and the status of data files shipped in a public web export are not defined, so a lawyer should decide ([OSM wiki](https://wiki.openstreetmap.org/wiki/License/Use_Cases); [OSMF FAQ](https://osmfoundation.org/wiki/Licence_and_Legal_FAQ)). Pass 2 adds nothing on licences. It adds a reason for care: players name accuracy errors (species, locations), so a sourced spot record is part of the product, not paperwork. Not researched: which non-OSM source exists for the first spot; fish-data licences (FishBase, GBIF, IUCN). Test: no player test; legal review, then record each source and licence in `docs/reference_docs.md`.

**Decision 4, free MVP, no ads, no timers; later one-time paid.** Support: monetisation is the most robust complaint theme (finding 2), and a one-time paid model avoids the F2P backlash. Risks: (a) no evidence in the notes that players pay for a realistic shore sim: premium realistic titles at $19.99 to $29.99 sit at 62 to 77% English, older ones sell at 80 to 90% discounts (Euro Fishing $2.99, Fishing Sim World $3.99, Pro Fishing Simulator $0.99), and the only sales datapoint is an unofficial Raijin estimate of about $2.5M gross for Call of the Wild **[1st]**; (b) a free launch yields no revenue and no evidence of willingness to pay, so the waitlist should include a price question; (c) a paid niche does exist on mobile (i Fishing $2.99, 2008 era; Fly Fishing Simulator with IAP unlock), but evidence is old and thin. Test: put a later price point in the waitlist survey; watch the free-to-paid story against the "free MVP" decision.

### Open items (options and a recommendation; owner decides)

- **Waitlist channel.** (A) A simple landing page with an email form in English and Turkish; (B) a store or community page that counts follows (cost and rules not researched); (C) share a short playable build. **Recommendation: A**, one channel, one language market first, with a cost-per-signup record. Collecting emails touches player data and may need a third-party form tool, so it needs the owner's go-ahead.
- **Turkish market sizing.** (A) No number until waitlist data exists; (B) use the unverified 0.2M to 2M range **[1st]** as a labelled ceiling; (C) a Turkish-language research pass with network access to TUIK and the ministry. **Recommendation: A now, C when access exists.**
- **Regional rules** (age rating, Turkey and Spain specifics, children's data, waitlist consent). Not researched. **Recommendation:** a short compliance check before the waitlist collects data and before any release.
- **Fish data licence.** Not researched. **Recommendation:** a small research task before species data is committed; record licences in `docs/reference_docs.md`.
- **Source for the first spot.** Options: (A) the owner's own site visit with dated notes; (B) a public-authority dataset after its licence is read; (C) a labelled design fill for anything unsourced. **Recommendation:** A plus C, then B only after a licence check.

## Open questions

- Do shore anglers, in Turkey or elsewhere, ask for or play real-location games? Needs Reddit, Eksi Sozluk, Donanimhaber, olta forums.
- What share of anglers fish from shore, per country? Not in the pages read.
- Is any nearby competitor shore-first (Euro Fishing, Sea Fishing Simulator, Real VR Fishing)? Not verified.
- How did the 706 fishing-tagged Steam games from 2023 to 2026 sell, and how many have 100+ reviews? Not obtained.
- Is retention in calm fishing games healthy? WEBFISHING's decline is a caution **[1st]**; no D1/D7/D30 benchmarks.
- Would a less-biased review sample (Playwright capture of the Steam hub with scrolling) change the theme counts? Not attempted.
- Roblox and portal scale (Fisch, Tiny Fishing web) remains snippet-level or unknown.

## Conclusion

The second pass makes the market picture much firmer and the central bet no firmer. Primary pages confirm a big fishing audience, realistic sims that rate 62 to 84% among English reviewers, a crowded and fast-growing Steam tag (706 released 2023 to 2026), and a recent breakout (How to Fish) that is a comedy co-op, not realism. The most useful new fact is about the audience Mera chose: real anglers check the details and punish fight length and line logic, yet also use sims as a stand-in when they cannot fish. That makes a believable, sourced fight model both the main risk and the main differentiator.

What the evidence still cannot say is whether anyone wants a real-location shore game, in Turkey or anywhere. The next useful evidence is not more desk research but the waitlist, ten testers and a hands-on check of the nearest shore-capable competitors, with a Turkish-language pass once network access allows. Until one of those returns a signal, the honest reading is: moderate evidence about the market, weak evidence about the demand.

## Sources

All accessed 2026-11-11. **[P]** primary page read in pass 2; **[1st]** read only as a search summary or via an aggregator in pass 1.

Steam [P]
- https://store.steampowered.com/app/380600/
- https://store.steampowered.com/app/1408610/
- https://store.steampowered.com/app/766570/
- https://store.steampowered.com/app/1266470/
- https://store.steampowered.com/api/appdetails?appids=4001890
- https://store.steampowered.com/api/appdetails?appids=380600&l=english
- https://store.steampowered.com/search/results/?term=fishing+simulator&category1=998&count=50&infinite=1&cc=us&l=english
- https://store.steampowered.com/search/results/?query&start=0&count=50&tags=15564&category1=998&infinite=1&cc=us&l=english
- https://steamcommunity.com/app/380600/reviews/?browsefilter=mostrecent&filterLanguage=english
- https://steamcommunity.com/app/1136380/reviews/?browsefilter=mostrecent&filterLanguage=english
- https://steamcommunity.com/app/834280/reviews/?browsefilter=mostrecent&filterLanguage=english
- https://steamcommunity.com/app/3483740/reviews/
- https://steamcommunity.com/app/1562430/reviews/
- https://steamcommunity.com/app/380600/discussions/3/537405286637202337/
- https://steamcommunity.com/app/380600/discussions/0/591757083455540113/
- https://steamcommunity.com/app/380600/discussions/0/694249702288286190/
- https://steamcommunity.com/app/380600/discussions/0/3047235309994036968/
- https://steamcommunity.com/app/1408610/discussions/0/561409599920535202/

Google Play and App Store [P]
- https://play.google.com/store/apps/details?id=com.tensquaregames.letsfish2&hl=en&gl=US
- https://play.google.com/store/apps/details?id=se.ace.fishinc&hl=en&gl=US
- https://play.google.com/store/apps/details?id=com.com2us.acefishing.normal.freefull.google.global.android.common&hl=en&gl=US
- https://play.google.com/store/apps/details?id=com.pishtech.ffs&hl=en&gl=US
- https://apps.apple.com/us/app/fishing-clash-sport-simulator/id1151811380
- https://apps.apple.com/us/app/hooked-inc-fisher-tycoon/id1436213906
- https://apps.apple.com/us/app/ace-fishing-wild-catch/id694972182
- https://apps.apple.com/us/app/fishing-master/id6471659176?see-all=reviews
- https://apps.apple.com/us/app/i-fishing/id294380152
- https://apps.apple.com/us/app/fishbrain-fishing-app/id477967747

Angler population
- [P] https://www.fws.gov/sites/default/files/documents/2024-09/2022-fishing-and-hunting-r3-in-the-us.pdf
- [P] https://www.fws.gov/press-release/2023-10/americans-spent-394b-hunting-fishing-and-wildlife-associated-activities-22
- [1st/snippet] https://dergipark.org.tr/tr/pub/yunusae/article/235404
- [1st/snippet] https://www.mynet.com/turkiyede-2-milyona-yakin-olta-balikcisi-var-180101228739
- [1st/snippet] https://www.tamindir.com/liste/en-iyi-balik-tutma-oyunlari/

First-pass sources kept [1st]
- https://tensquaregames.com/2026/03/23/financial-results-of-ten-square-games-group-for-q4-and-full-year-2025-trophy-hunter-and-portfolio-transformation-mark-a-new-stage-of-development/
- https://wiki.openstreetmap.org/wiki/License/Use_Cases
- https://osmfoundation.org/wiki/Licence_and_Legal_FAQ
- https://appgoblin.info/apps/1151811380/trends
- https://raijin.gg/app/1408610/Call_of_the_Wild_The_Angler
