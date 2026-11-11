# RevoCred card-data audit — 2026-10-25

Live date checked: `2026-10-25 UTC` via `date -u` (2026-10-25T23:49:06Z). File date names are snapshot labels, not a claim external content is unchanged.

Scope: READ ONLY. No app, DB, config, service, or model changes. No migrations, messages, secrets, installs, commits, or deploys. Allowed writes only under this work directory (`output/`, `evidence/`). Inventory snapshot: `inventory.json` captured 2026-10-25T23:45:30Z — 14 active `issuer_snapshot` catalog cards, 99 search-reference cards, plus excluded aggregates (1 active user-supplied custom, 6 inactive demo). Demo stays demo; custom stays custom.

Method: compared each of the 14 `inventory.json` catalog benefits/rates/fees against `evidence/issuer-pages/*.txt|*.html` cached 2026-10-25 and `issuer-fetch.json` (all 200s, but a 200 is NOT verification — Amex Platinum category page is 51–52 chars and effectively empty). Fresh specific pages fetched 2026-10-25 for Platinum, Strata base, and Double Cash (see Recommendations). `revocred-api/migrations/000006_catalog_integrity.sql`, `000012_card_reference_index.sql`, `000023_sourced_card_credits.sql` read for context: scoring intentionally uses a conservative subset; conditional credits/bonuses excluded from estimates; catalog versions/sources immutable. That separation is preserved here: display gaps are not auto-added to projected value.

Never equate a nonempty benefits list with complete benefits. No record is marked `fully_verified`. Missing evidence never implies “no benefit.” Community data is a candidate, not authoritative terms. No card artwork reproduced.

## Summary

- Javed’s Sapphire Reserve report confirmed: stored 6 lines vs ~83k-char issuer page with 2025–2026 refresh ($300 travel + $500 Edit + $300 dining + $300 StubHub + Lyft/Peloton + Global Entry + lounge network + Points Boost + full protections). Priority P0.
- Broad/empty stored sources confirmed for 3 cards: Amex Platinum (category page, empty), Double Cash (Rewards hub, no Double Cash terms), Strata (family hub mixing 3 tiers). Fresh specific pages verified; upgrades proposed in Recommendations only.
- Two records need exact-variant pinning, not assumed wrong: Quicksilver → Good-Credit variant; SavorOne $39 (Fair) vs $0 Savor variants.
- Two 2026-10-13 benefit snapshots (Amex Gold, Sapphire Preferred) match fresh evidence on core credits/fees; remaining gaps are intentionally conservative scoring + promo-vs-recurring separation.
- Reference index: 99 rows = 14 `verified` + 85 `partial` (counted programmatically from `inventory.json`). The 14 `verified` mirror catalog conservative snapshots (fee + base rates only) and are search-only identity records, never fully verified benefit records.

## Table — all 14 catalog cards

| slug | stored fee / rates | stored source | finding | priority |
|---|---|---|---|---|
| amex-gold | $325; {other:1,dining:4,flights:3,groceries:4}; 9 benefits | specific product page | Specific source OK. Fees + 5 credits match evidence. **Absent:** 5x prepaid hotels, 2x car rentals/cruises in benefits/rates. **Intentionally conservative scoring** retains subset; do not auto-add to value. | P2 |
| amex-platinum | $895; {other:1}; 5 generic lines | **broad category page, empty** | **Fresh evidence confirms mismatch.** Cached txt 52 chars, no terms. Specific page shows 5x flights/hotels + ~$3,500 stack (see snippets). | **P0** |
| quicksilver | $0; {other:1.5}; 4 lines | specific but variant-narrow (good-credit) | **Variant ambiguous.** Page is Good-Credit variant (“won’t be eligible for bonus/0% APR”). Do not generalize to standard/One/Secured/Student. Rates match this variant. | P1 |
| savor-for-students | $0; {other:1,dining:3,groceries:3,entertainment:3}; 4 lines | specific | Core rates match; $50 bonus correctly excluded from scoring (welcome, not recurring). **Absent nuance:** Walmart/Target exclusion. | P2 |
| savorone | $39; {other:1,dining:3,groceries:3,entertainment:3}; 4 lines + Savor warning | specific but variant-narrow (Fair, $39) | **Variant ambiguous.** Page shows “Fair Credit, $39”. $0 Savor variants exist. Stored warning is correct; pin exact variant. | P1 |
| venture-x | $395; {other:2}; 7 lines ($300 credit + 10k anniversary) | specific | Core fee/rates/credits **confirmed in HTML** (txt extraction missed $300/anniversary). **Absent display:** lounge (Capital One + 1,300 Priority Pass), $800 cell protection, Collection experience credits, transfers. Scoring {other:2} intentionally conservative. | P2 |
| freedom-flex | $0; {other:1,dining:3,drugstores:3}; 6 lines | specific | Core 5% rotating ($1,500/qtr activated) + 5% Travel + 3%/1% confirmed. Scoring omits 5% uplift by design. DashPass/Lyft promos are time-bound, correctly omitted from recurring. | P2 |
| freedom-rise | $0; {other:1.5}; 3 lines | specific | 1.5% flat confirmed. Same promo separation. | P2 |
| freedom-unlimited | $0; {other:1.5,dining:3,drugstores:3}; 5 lines | specific | 1.5%/3%/5% Travel confirmed. Scoring omits 5% Travel uplift by design. | P2 |
| sapphire-preferred | $95; {other:1,dining:3,travel:2}; 6 benefits (2026-10-13) | specific | **Current terms confirmed — do not “correct” to older $50 hotel memory.** $100 hotel + $120 Global Entry/TSA/NEXUS + transfer + rental/trip protections match page. Rates intentionally conservative (omit 5x Travel/streaming/grocery + Lyft/Peloton promos). | P2 |
| sapphire-reserve | $795; {other:1,dining:3,hotels:4,flights:4}; 6 lines | specific | **Mismatch confirmed, P0.** 6 lines vs full refresh (see snippets). Fee matches; everything else incomplete. | **P0** |
| double-cash | $0; {other:2}; 3 lines | **broad Rewards hub** | **Mismatch confirmed.** Hub txt has no Double Cash terms (lists Strata/AAdvantage/Costco). Specific page shows 2% (1%+1%) + 5% total Citi Travel + ThankYou mechanics + warranty/Entertainment. | **P0** |
| strata | $0; {gas:3,other:1,dining:2,groceries:3}; 5 lines | **broad family hub** | **Mismatch confirmed.** Family page mixes 3 tiers. Stored omits 5x Citi Travel tier. Must not copy Elite credits to base. | **P0** |
| strata-elite | $595; {other:1.5,dining:3}; 7 lines | specific | **Mismatch confirmed.** Stored “Hotel and lounge benefits” hides $300 hotel + $200 Splurge + $200 Blacklane + 4 Admirals + Priority Pass 1,500 + $120 Global Entry + Citi Nights 6x nuance + protections. | **P0** |

Reference index (programmatic count from `inventory.json`): `verified: 14, partial: 85, total: 99`. The 14 `verified` slugs (`amex-gold-index`, `amex-platinum-index`, `quicksilver-index`, `savor-for-students-index`, `savorone-index`, `venture-x-index`, `freedom-flex-index`, `freedom-rise-index`, `freedom-unlimited-index`, `sapphire-preferred-index`, `sapphire-reserve-index`, `double-cash-index`, `strata-index`, `strata-elite-index`) mirror catalog conservative snapshots. They are **search-only, not fully verified benefit records**. The 85 `partial` rows carry no rates/fees and must be supplied by the user before scoring. No benefits invented for the 99; see `card-audit.json` + `card-audit.csv` (CSV has 14 rows only).

Excluded: `user_supplied active custom: 1`, `demo inactive: 6` — out of scope for recommendation audit.

## Highest-priority fixes (data work only; no app/DB edits here)

1. **Sapphire Reserve rebuild (P0).** Stored 6 lines omit Edit $500, dining $300, StubHub $300, Lyft/Peloton, Global Entry, lounge network, Points Boost, transfer, and full protections. Requires new reviewed version with field-level URL/quote/fetched_at/hash; keep credits display-only, not in projected value.
2. **Amex Platinum rebuild (P0).** Replace broad category source with specific product page (see Recommendations). Stored {other:1} + 5 generic lines vs 5x + ~$3,500 credit stack + 19/7/8 benefit groups + status/insurance suite.
3. **Double Cash + Strata source upgrades (P0).** Both stored sources are hubs. Use discovered specific pages (below) for next reviewed versions; add Double Cash 5% Citi Travel tier and Strata 5x travel tier; do not copy Elite credits to base Strata.
4. **Strata Elite itemization (P0).** Expand “Hotel and lounge benefits” to typed credits with cadence/activation ($300 hotel 2-night min, $200 Splurge choice-of-2, $200 Blacklane halves, Admirals passes, Priority Pass, $120 Global Entry) + Citi Nights 6x + protections, each with evidence quote/hash.
5. **Variant pinning (P1).** Rename/display `quicksilver` as “Quicksilver Rewards for Good Credit” (or split variants); pin `savorone` to “SavorOne $39 (Fair)” vs $0 Savor variants. Both already partially warned; enforce in next version identity fields.

## What remains unverified

- No record is `fully_verified`. Even P2 “match” cards lack field-level hashes, Guide-to-Benefits limits (rental/trip/baggage caps, exclusions), enrollment proofs, and portal-accelerator scoping. All need the verification policy (field evidence + review + immutable versioning) before publishing.
- Protections for every card: stored either generic or absent. Evidence confirms Preferred/Reserve/Elite protection headlines, but limits/exclusions require the Guide to Benefits PDFs, not just marketing pages.
- Promo vs recurring: Freedom DashPass/Lyft, Preferred/Reserve Lyft/Peloton/DashPass windows, Venture Collection experience credits, and all welcome bonuses are intentionally excluded from scoring and (mostly) from recurring display. Each needs expiry-aware review before any display addition.
- CFPB/TCCP and community feeds (see `free-data-sources.md`) do not replace issuer verification; no complete free feed was found.
- Live content drifts: all evidence is 2026-10-25 snapshots; re-fetch + re-verify before any publish.

## Real source links + evidence snippets (verbatim, truncated)

- Amex Gold (stored source, specific): https://www.americanexpress.com/us/credit-cards/card/gold-card/ — “4X POINTS At Restaurants Worldwide, on up to $50K in purchases per calendar year.” / “$120 Dining Credit Earn up to $10 monthly ... at Grubhub (including Seamless), Buffalo Wild Wings, Five Guys, The Cheesecake Factory, and Wonder. Enrollment required.” / “$100 Resy Credit Get up to $100 ... $50 Jan–Jun + $50 Jul–Dec. Enrollment required.” / “The annual fee for the American Express Gold Card is $325” (`evidence/issuer-pages/amex-gold.txt`).
- Amex Platinum stored (broad, empty): https://www.americanexpress.com/us/credit-cards/category/reward-points/ — cached `evidence/issuer-pages/amex-platinum.txt` is “Membership Rewards points Cards | American Express” (52 chars; sha256 bc1b294e...). 200 is not verification.
- Amex Platinum specific (fresh 2026-10-25, `evidence/fetched/amex-platinum-correct.html`): https://www.americanexpress.com/us/credit-cards/card/platinum/ — “5X Points on Flights Booked directly with airlines or through American Express Travel, on up to $500,000” / “5X Points on Prepaid Hotels” / “Up to $600 Hotel Credit: $300 semi-annually on Fine Hotels + Resorts / The Hotel Collection” / “$200 Uber Cash: $15/mo + $20 Dec” / “$400 Resy: $100/qtr” / “$300 Digital Entertainment: $25/mo”.
- Quicksilver Good Credit: https://www.capitalone.com/credit-cards/quicksilver-good-credit/ — “Earn unlimited 1.5% cash back on every purchase, every day. $0 annual fee.” / “won’t be eligible for new cardmember bonus cash or 0% intro APR” / “No Foreign Transaction Fees” (`evidence/issuer-pages/quicksilver.txt`).
- Savor Student: https://www.capitalone.com/credit-cards/savor-student/ — “Earn Unlimited 3% Cash Back at Grocery Stores, on Dining, Entertainment and Popular Streaming Services. $0 Annual Fee.” / “excluding superstores like Walmart and Target”.
- SavorOne ($39 Fair): https://www.capitalone.com/credit-cards/savorone/ — “Earn unlimited 3% cash back ... with a $39 annual fee.” / “Credit Level: FAIR” / “excluding superstores like Walmart and Target”.
- Venture X: https://www.capitalone.com/credit-cards/venture-x/ — txt: “$395” + “10X Miles on hotels & rental cars via Capital One Travel” + “5X Miles on flights and vacation rentals” + “2X Miles on all other purchases”; html JSON: “$300 annual Capital One Travel credit” + “10,000 miles anniversary bonus”; txt also: “Capital One Lounge and Landing” + “Priority Pass 1,300+” + “Cell Phone Protection ... up to $800”.
- Freedom Flex: https://creditcards.chase.com/cash-back-credit-cards/freedom/flex — “Earn 5% cash back on up to $1,500 in rotating categories each quarter you activate. Plus, earn 5% on travel via Chase Travel, 3% on dining/drugstores, 1% else.” / “ANNUAL FEE $0”.
- Freedom Rise: https://creditcards.chase.com/cash-back-credit-cards/freedom/rise — “Establish credit and earn 1.5% cash back on all purchases” / “1.5% for each $1 spent.”
- Freedom Unlimited: https://creditcards.chase.com/cash-back-credit-cards/freedom/unlimited — “3% dining/drugstores and 5% travel via Chase Travel” + “1.5% all other”.
- Sapphire Preferred (current, do not regress): https://creditcards.chase.com/rewards-credit-cards/sapphire/preferred — “$95 annual fee” / “$100 Chase Travel Hotel Credit ... each anniversary year” / “Global Entry or TSA PreCheck or NEXUS ... up to $120 every four years” / “Auto Rental Coverage ... primary ... up to $60,000” / “Trip Cancellation ... $10,000/$20,000”.
- Sapphire Reserve: https://creditcards.chase.com/rewards-credit-cards/sapphire/reserve — “$795 annual fee” / “8x Chase Travel incl. The Edit” / “$300 annual travel credit ... Purchases that qualify will not earn points” / “$500 credit for stays with The Edit” / “$850+ Lounge Network: Sapphire Lounges + 1,300 Priority Pass + Maple Leaf” / “$300 dining ... $300 StubHub ... $120 Lyft +5x ... $120 Peloton +10x” / “Global Entry/TSA/NEXUS” / “Auto Rental ... $75,000” / “Trip Cancellation $10k/$20k”.
- Double Cash hub (stored, broad): https://www.citi.com/credit-cards/rewards-credit-cards — cached txt lists “Strata Elite / Premier / AAdvantage / Costco”, no Double Cash terms.
- Double Cash specific (fresh 2026-10-25, `evidence/fetched/citi-double-cash-specific.html`): https://www.citi.com/credit-cards/citi-double-cash-credit-card/ — “Earn unlimited 1% when you buy, plus 1% as you pay” / “Plus, earn a total of 5% on select travel ... additional 3% on hotels, car rentals, attractions via Citi Travel” / “No Annual Fee” / “Extended warranty” / “Citi Entertainment”.
- Strata family (stored, broad): https://www.citi.com/credit-cards/citi-strata-all-cards — `evidence/issuer-pages/strata.txt` lines 144–162: “5x Hotels/Cars/Attractions via cititravel.com / 3x Supermarkets / 3x Gas & EV + Transit / 3x Self-Select / 2x Restaurants / 1x else” (mixed with Elite 12x/Premier 10x blocks).
- Strata base specific (fresh): https://www.citi.com/credit-cards/citi-strata-credit-card (`evidence/fetched/citi-strata-specific.html`) — “5x Hotels/Cars/Attractions / 3x Supermarkets / 3x Gas & EV + Transit / 3x Self-Select (Fitness/Streaming/Live/Cosmetic/Pet) / 2x Restaurants / 1x else” + “$0 Annual Fee”.
- Strata Elite (specific): https://www.citi.com/credit-cards/citi-strata-elite-credit-card — “12x Hotels/Cars/Attractions” + “6x Air” + “6x Restaurants on Citi Nights (Fri–Sat 6PM–6AM ET), 3x other times” + “1.5x else” + “$300 Hotel (2-night min)” + “$200 Splurge (choice of 2: 1stDibs/American/Best Buy/Future/Live Nation)” + “$200 Blacklane ($100 halves)” + “4 Admirals passes (~$300)” + “Priority Pass 1,500+ ($469)” + “$120 Global Entry/PreCheck (4yr)” + “Trip Delay / Enhanced Cancellation / Luggage / MasterRental / Extended Warranty”.

## Recommendations — source upgrades (NOT in app/DB; process fix only)

- `amex-platinum`: replace `.../category/reward-points/` with `https://www.americanexpress.com/us/credit-cards/card/platinum/` (verified 200 2026-10-25, 4.2 MB html, `evidence/fetched/amex-platinum-correct.html`). Category page is not a product source.
- `double-cash`: replace `.../rewards-credit-cards` hub with `https://www.citi.com/credit-cards/citi-double-cash-credit-card/` (found via `site:citi.com` search, verified 200 2026-10-25, 704 kB, `evidence/fetched/citi-double-cash-specific.html`). Do not guess; this URL was searched, not assumed.
- `strata`: replace `.../citi-strata-all-cards` family hub with `https://www.citi.com/credit-cards/citi-strata-credit-card` (verified 200 2026-10-25, `evidence/fetched/citi-strata-specific.html`). Keep Elite/Premier/base tier separation; never copy Elite credits to base.
- All other 11 stored URLs are already specific product pages; keep but re-verify with field-level quotes/hashes per `data-verification-policy.md` before any new version. No app/DB edits authorized here.

## Files

- `output/card-audit.json` (14 records, slugs exactly match inventory; reference 14/85/99; no `fully_verified`)
- `output/card-audit.csv` (14 rows + header; slugs match JSON)
- `output/free-data-sources.md`, `output/data-verification-policy.md`, `output/verify_audit.py`, `output/verification-result.txt`, `output/completion.json`
- Evidence: `evidence/issuer-pages/*.{txt,html}`, `evidence/fetched/*`, `issuer-fetch.json`, `inventory.json`
