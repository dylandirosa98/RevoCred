# Free / open US consumer credit-card datasets and APIs — evaluated 2026-10-25

Live date: 2026-10-25 UTC. All candidates actually fetched (webfetch or Python stdlib urllib); failed fetches labeled unavailable, not reconstructed. GitHub LICENSE files read as raw text, not assumed. No sign-ups, purchases, installs, or paid APIs used. Focus is whether each can meet RevoCred needs (issuer-verified fee, typed reward conditions/caps, credits with amount/cadence/activation/eligibility/expiry, protections with source guide, perks, welcome separated from recurring value) — not card-number test datasets.

Conclusion up front: **no reliable complete free feed was found** that covers recurring credits/caps/enrollment plus protections with issuer-verified freshness. Issuer product pages (+ Guide to Benefits PDFs) remain the only authoritative source. The three community/open datasets below are usable only as **candidates for bootstrapping + human review**, each with gaps and staleness risk. Commercial free tiers with no verified free API are not recommended.

## 1. sgolovine/cc-offers — open research dataset (MIT) — candidate

- Exact URL: https://github.com/sgolovine/cc-offers
- What was fetched (2026-10-25): repo README via webfetch (200, “242 offers from 28 issuers”, SQLite + CSV + XLSX + Dexie seed); raw `https://raw.githubusercontent.com/sgolovine/cc-offers/main/data/cc-offers-export.csv` via urllib (200, 810,925 bytes, 242 rows) to `evidence/fetched/cc-offers-sample.csv`; raw `.../LICENSE` (200, 1,071 bytes, MIT) to `evidence/fetched/sgolovine-cc-offers-LICENSE.txt`; GitHub REST `.../commits?per_page=1` (200, latest `c125704e` 2026-05-31).
- License observed: `MIT License Copyright (c) 2026 Sunny Golovine ... free to use/copy/modify/merge/publish/distribute/sublicense/sell` (raw file, not assumed). Reuse: established commercial reuse permission (include copyright + license). No Commons Clause.
- Data fields / coverage: `id, issuer, card_offer, segment, category, welcome_intro_offer, bonus_miles, cash_bonus, spend_requirement, spend_timeframe_*, base_annual_fee_usd, additional_user_fee, intro_apr, regular_apr, rewards_key_perks (free text), source_url, source_basis, retrieved, notes, raw_json`. Covers all 14 RevoCred catalog examples in spot check: Sapphire Reserve $795 + “8x Travel / 4x direct / 3x dining / $300 travel”, Preferred $95, Flex/Unlimited/Rise, Venture X $395 + “2X/10X/5X + $300 + 10k”, SavorOne $39, Savor $0 + 5% travel, Savor Student, Quicksilver variants (standard/One $39/Secured/Student/Good Credit), Double Cash $0 + 5% travel, Strata $0/Elite $595/Premier $95 with typed perks. `retrieved` 2026-05-29 for sampled rows; `source_url` are issuer product pages; `raw_json` carries evidence.
- Freshness: last commit 2026-05-31 (~5 months before audit). Offer data time-sensitive; README warns “always verify current rates/fees/bonuses ... with issuer.”
- Free limits: none documented; raw GitHub + SQLite; no key, no rate limit observed for raw fetch.
- Missing pieces: `rewards_key_perks` is prose, not typed reward conditions/caps; credits lack amount/cadence/activation/eligibility/expiry structure; protections/perks incomplete; no Guide-to-Benefits limits; staleness risk (May data vs Oct issuer refresh, e.g., Reserve/Platinum stacks).
- Suitability: best open candidate for **discovery + cross-check** (variant disambiguation, source URLs). Cannot replace issuer verification or supply RevoCred’s credit/protection typing without human review + re-verification.

## 2. thedavidweng/opencard-db — open catalog (MIT code + CC BY 4.0 data) — candidate

- Exact URLs: https://thedavidweng.github.io/opencard-db/ ; https://github.com/thedavidweng/opencard-db ; API `https://opencard-db.davidweng.workers.dev/v1/search?q=...`
- What was fetched: site + docs via webfetch (200, “548 cards”, `cards-all.json` + `cards.csv/yaml` + `meta.json` + `/v1` REST, 30 req/min, `X-Client-Name`); `.../exports/meta.json` via urllib to `evidence/fetched/opencard-meta.json` (200, 228 bytes: `card_count 548, countries ca/cn/us, generated_at 2026-10-22T23:21:36Z`); `LICENSE` (1,081 bytes MIT) + `LICENSE-DATA` (797 bytes CC BY 4.0) to `evidence/fetched/`; API `search?q=sapphire|strata|venture` via urllib to `evidence/fetched/opencard-search-*.json` (200, 12–27 kB each, 3/3/6 hits).
- License observed (not assumed): code MIT; data `CC BY 4.0 — Share/Adapt even commercially with attribution + link + change note` (`LICENSE-DATA` raw). Card art excluded (bank copyright). Reuse: established commercial reuse with attribution.
- Fields / coverage: per-card JSON `id, name, issuer, network/tier, status, annual_fee{amount,currency}, apr{range,variable}, rewards{currency, base_rate, categories[{label, points_per_dollar, cap}]}, signup_bonus{amount,spend,months,as_of}, benefits[{id,title,category}], travel_perks, official_url, sources[], last_verified, notes`. Sample: `us-chase-sapphire-preferred` ($95, 5x Travel / 3x dining/streaming/grocery / 2x travel, $75k/$5k bonus as_of 2026-07-24, DashPass, sources [chase.com], last_verified implicit); `us-citi-strata` ($0, 5x travel / 3x supermarket/gas-transit/self-select / 2x dining, $20k/$1k bonus, official_url `.../citi-strata-credit-card`, last_verified 2026-10-22); Venture sample is Venture (not X) — X coverage needs check.
- Freshness: `generated_at 2026-10-22` (3 days before audit); per-card `last_verified` (e.g., 2026-10-22 Strata, 2026-07-25 Venture). CI validates schema + sources + review. Freshest of the candidates.
- Free limits: CDN pinned releases + latest; `/v1` 30/min, best-effort official instance, self-hostable on Cloudflare free plan. No sign-up.
- Missing pieces: `benefits[]` sparse (Strata base `[]`; Preferred only 4 insurance/DashPass, no hotel/Global Entry typing in sample); credits lack cadence/activation/eligibility typing; caps often null; protections need Guide PDFs; transfer ratios/valuations out of scope (see valuations note).
- Suitability: best-structured candidate for **fee/APR/base-rate bootstrapping with attribution**. Still requires issuer re-verification for every credit/protection before RevoCred publish. Do not ingest art.

## 3. andenacitelli/credit-card-bonuses-api — bonuses only (MIT + Commons Clause) — limited candidate

- Exact URL: https://github.com/andenacitelli/credit-card-bonuses-api
- What was fetched: repo README via webfetch (200, “Free API for bonuses, JSON/CSV/YAML, read-only mirror, daily sync from private monorepo”); raw `.../main/exports/data.csv` via urllib (200, 52,867 bytes, 179 rows) to `evidence/fetched/bonuses-api-sample.csv`; raw `.../main/LICENSE` (200, 2,014 bytes) to `evidence/fetched/andenacitelli-LICENSE.txt`; REST commits (200, latest `30639ebe` 2026-06-08 bot sync).
- License observed: `MIT License ... Copyright (c) 2023 Anden Acitelli` **plus** `Commons Clause v1.0 — grant does NOT include right to Sell ... product/service whose value derives substantially from Software`. Reuse: hobbyist/non-commercial OK; **not established commercial reuse permission for RevoCred** (commercial product). Do not treat as MIT-only.
- Fields / coverage: `cardId, name, issuer, network, currency, isBusiness, annualFee, isAnnualFeeWaived, universalCashbackPercent, url, imageUrl, credits (short, e.g., “300 Travel Credit; 500 Travel Credit (The Edit); 469 Lounge Access ...”), offers/historicalOffers, discontinued, offerAmount/offerSpend/offerDays/countsTowards524`. Sample: Reserve $795 + 150k/6k + credits string; Preferred $95 + 75k/5k + “50 Hotel Credit” (stale vs current $100 — staleness proof); Platinum $895 + 100k/8k; Strata Elite $595 + 75k/6k; Double Cash $0 + 200/1500. Rewards multipliers/caps, credit cadence/activation, protections absent.
- Freshness: daily-sync claim, but last public mirror commit 2026-06-08 (~4.5 months stale; Preferred $50 hotel string is outdated vs Oct $100 page).
- Free limits: raw GitHub, no key. No SLA.
- Missing pieces: everything RevoCred needs beyond bonuses: typed reward caps, credit cadence/enrollment/eligibility/expiry, protections/guides, perks. `credits` is a short display string, not a rule.
- Suitability: useful only as **bonus-amount cross-check, kept separate from recurring value** (RevoCred already excludes bonuses from estimates). Not a source for display terms; Commons Clause blocks commercial reuse as substantial part of product.

## 4. CFPB Credit Card Agreements Database — official legal source — authoritative but unstructured

- Exact URLs: https://www.consumerfinance.gov/data-research/credit-card-data/ ; https://www.consumerfinance.gov/credit-cards/agreements/ ; archive https://www.consumerfinance.gov/credit-cards/agreements/archive/
- What was fetched: landing + data pages via webfetch (200, “>600 issuers”, quarterly CARD Act collection, Q2-2026 archive current). Direct bulk via urllib **failed 403** (`evidence/fetched/cfpb-agreements.html.meta.json`: `HTTP 403 Forbidden` 2026-10-25) — labeled unavailable, not reconstructed. data.gov catalog API for `credit-card-agreements-database` returned 404 in this check.
- License observed: no explicit license string retrieved (403 blocked bulk/license page fetch). U.S. federal content often public domain, but **not verified here — do not assume reuse permission**.
- Fields / coverage: cardholder agreements (general terms, pricing, fees) as PDFs per issuer, quarterly. Authoritative for APR/fees/legal terms and Guide-adjacent language. No structured rewards multipliers, no credits/caps/enrollment, no protections typing, no perks.
- Freshness: quarterly (Q2-2026 latest per archive page 200). Strong for legal currency, weak for marketing-page credit stacks that change faster.
- Free limits: public search + bulk download (when accessible); no key. Bulk is hundreds of MB per quarter (DataLumos mirror lists 700 MB–1 GB per quarter 2020–2024) — heavy for RevoCred pipeline.
- Missing pieces: all reward/credit/protection structure RevoCred displays. PDFs require extraction + per-field issuer-page verification anyway.
- Suitability: **authoritative complement for fee/APR/legal verification**, not a feed for display terms. Use to corroborate Pricing Details, not to source credits.

## 5. CFPB Terms of Credit Card Plans (TCCP) Survey — official pricing survey — narrow

- Exact URL: https://www.consumerfinance.gov/data-research/credit-card-data/terms-credit-card-plans-survey/ (linked from credit-card-data hub)
- What was fetched: hub via webfetch (200, “every six months ... TCCP Survey ... Collect portal”); direct TCCP page via urllib **403** (same as above, `evidence/fetched/cfpb-tccp.html.meta.json`). No CSV downloaded in this audit; availability labeled as listed-but-not-directly-fetched here.
- License / limits: same as agreements (federal, no explicit license retrieved; public bulk, no key; semi-annual).
- Fields / coverage (as documented on hub): plan-level price/availability from 150+ issuers (APR, fees, grace, etc.). Structured, but **no rewards, no credits, no caps/enrollment, no protections**.
- Suitability: useful for **APR/fee benchmarking**, not for RevoCred display/scoring.

## Rejected / out-of-scope (checked, not recommended)

- `madhav921/stmtforge-cards-db` (https://github.com/madhav921/stmtforge-cards-db, webfetch 200): “Database for all the Indian Credit Cards”, 5 commits, 0 stars. India-only, no US coverage — irrelevant to RevoCred US catalog.
- `wanderwiseguide/points-transfer-valuations` (`makenomistakesllc/points-transfer-valuations`, webfetch 200; also `wanderwiseguide.com` per search): 98 program→partner cpp ranges, CC BY 4.0 data + MIT code. Editorial value estimates, explicitly “not guarantees ... verify current ratios”. Useful for valuation thinking, **not a terms source**; RevoCred uses 1 cpp conservative model by design.
- Card-number test datasets (Luhn fixtures) and affiliate/commercial “APIs” with no verified free endpoint: excluded per task (irrelevant to credits/caps/enrollment/protections). No paid APIs used.

## Recommendation (at most 3)

1. **Issuer pages + Guide to Benefits PDFs as primary** (authoritative, versioned per `data-verification-policy.md`). No feed replaces this.
2. **OpenCard DB (CC BY 4.0) as structured bootstrap candidate** — freshest schema + sources + attribution; re-verify every credit/protection before publish.
3. **cc-offers (MIT) as discovery/cross-check candidate** — variant/Source-URL coverage; prose perks need re-typing + re-verification.
- Bonuses-API: bonus cross-check only (Commons Clause + stale + unstructured). CFPB Agreements/TCCP: legal/APR corroboration only.

No single free feed meets RevoCred’s complete display + conservative-scoring needs.
