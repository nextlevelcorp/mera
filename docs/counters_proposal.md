# Anonymous counters: proposal (PRD F16, section 6)

**Status:** 2026-11-15. A proposal for the owner. **No code, no network call and no dependency has been added.** Nothing here may be built until the owner approves it (CLAUDE.md: new dependencies, player data, costs).

## What is needed
PRD section 6 measures the funnel with anonymous event counts only: no identifier, no cookie, no email. The events: `loaded`, `first_cast_fast` / `first_cast_slow`, `first_fish`, `return_next_day`, and the page open itself. `.claude/rules/security.md` allows this single network call in principle (owner, 2026-11-11) on one condition: the service and its terms are checked in the PR that adds it.

## What could not be checked
The session cannot reach goatcounter.com (the owner declined to add it to the network list on 2026-11-15). So this document rests on search-result summaries of the official pages and on third-party listings, which disagree with each other. **The official terms and privacy pages have not been read.** Anything marked "unverified" must be read at goatcounter.com before a decision.

| Question | What was found | Check |
| --- | --- | --- |
| Is the hosted free plan allowed for a commercial product? | Third-party listings say the free hosted tier is for non-commercial use and name three different commercial prices (from about 5 USD to 15 EUR a month). The official homepage describes a donation-supported hosted service and does not mention commercial use in the snippet | **Unverified.** Read the terms page |
| Cookies or browser storage | The official privacy page (as summarised): nothing is stored in the browser through cookies, localStorage or similar | Summary only |
| What the server receives | Standard visit fields: browser, screen size, referrer, location (country). Like any web service it sees the request's IP address; whether and how it hashes or discards it is not confirmed | **Unverified.** Read the privacy page and the sessions help page |
| Consent banner | GoatCounter's own GDPR page argues a consent notice is probably not needed because no personally identifiable information is collected; it also says case law is thin and enforcement differs between member states | Not legal advice; Mera targets Turkey, Spain and Latin America as well |
| Licence of the software | EUPL-1.2 per third-party listings; self-hosting allowed | **Unverified** |

## Two facts the owner should weigh
1. **Mera is free now but a paid release is planned.** If the hosted free tier is non-commercial only, the web build might fit (it is free, no ads) but a later paid app would not, and the analytics would have to move.
2. **Any hosted counter sees the player's IP address** in the request, even if it stores nothing. "No identifier" holds for what the game sends, not for what a network request reveals. A privacy notice in the game should say so plainly.

## Options
| Option | Cost | Privacy | Effort | Notes |
| --- | --- | --- | --- | --- |
| **A. No counters in 0.1; testers only (recommended for the first round)** | 0 | Nothing leaves the phone | 0 | The 0.1 pass bar is tester-based (5 anglers, 5 non-anglers). Counters count as second evidence only above 100 visitors, which the slice will not have yet |
| B. GoatCounter hosted | Free or paid, depending on the terms | Cookieless; IP seen by the service | Small: one HTTPS request per event, silent on failure | Needs the terms read first; revisit when the paid release is planned |
| C. GoatCounter self-hosted | Server cost and upkeep | Data stays with the owner | Medium | Needs a server and a domain; overkill for 0.1 |
| D. A tiny owner-run counter (serverless function) | Free tier, then cents | Owner controls what is stored: counts per day and event, IP discarded | Medium: code and hosting accounts | Costs an account; needs the owner's go-ahead |

## Recommendation
**Option A for the 0.1 tester round, then option B if the hosted terms allow it, otherwise option D at 0.5.** Reason: the slice's success is decided by testers; counters add little before 100 visitors, and the unread terms are a risk with no payoff yet. If the owner wants counters now, the owner reads the two pages (terms and privacy) and says "go" for option B, and the integration PR is small:

- One class `Counters` with a fixed event list; no free-form text, no player id.
- `OS.has_feature("mera_debug")` or a debug build sends nothing (PRD F16).
- The first-visit flag and the "returned on a later day" check use the phone's local date only; only the event name goes out.
- Failure is silent and never blocks play; one test asserts the event names and that no request is made in debug builds.
- A one-line privacy note in Settings: "The game counts anonymous events (for example 'first fish'). No account, no cookie."
- `docs/reference_docs.md` records the service, its terms page and the date they were read.

## Decision needed
Which option: A (testers only), B (GoatCounter hosted, after the owner has read its terms) or D (own counter)?
