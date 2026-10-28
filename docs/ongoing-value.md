# Ongoing yearly wallet value

Implemented wallet-only model `ongoing-v1`, reviewed 2026-10-26. Welcome bonuses
are **excluded**; automatic first-year bonus eligibility is **not implemented**.

## Formula and boundaries

`spending rewards + estimated usable credits + recurring anniversary rewards - annual fees`

Amounts are deterministic integer cents. `wallet_metrics.ongoing_value` carries
all four components, total, assumptions and per-benefit evidence. The existing
whole-dollar `yearly_value` is the rounded ongoing total. Only active,
known-terms wallet cards participate. Unknown/custom cards never acquire benefits
by name or marketing text; supplied base rates and fees still work. Duplicate
catalog products are counted once. No DB migration was needed.

`valuation.Net` is unchanged: rewards minus fees. Application rankings, scores,
purchase-guide rules, eligibility and strategy selection are unchanged. Ranking
explanations explicitly distinguish their conservative model from Home's ongoing
wallet model. Chat receives the actual breakdown, not an obsolete global claim
that wallet credits are excluded.

Credits use **70% only for reviewed relevant cash credits**. Category budget and
travel scope screen relevance, not actual merchant use. The estimate is explicitly
conditional on using each merchant/portal/service, enrollment, eligible purchase
requirements, monthly/half-year caps and expiry. A travel-incompatible profile
excludes travel credits. Category-linked credits share 70% of annual category
spending across the wallet, allocated in stable product/rule order, so the same
budget cannot support unlimited overlapping credits. This cap is conservative,
not an attempt to predict merchant purchases. No new questionnaire was added.

Anniversary miles use 1 cent per mile and assume renewal/continued eligibility,
starting at the first eligible anniversary. No welcome or temporary bonuses,
lounge/insurance value, per-stay property perks or undisclosed annualization of
multi-year application-fee reimbursements is included.

**Limitation:** spending rewards are modeled separately on entered spending.
Some credited purchases do not earn points; real rewards may therefore be lower.
This is disclosed in the breakdown, not a guaranteed savings calculation.

## Source audit and reviewed adapters

The existing local OpenCard cache was examined first, through the local API with
a disposable account. The public-only captured catalog is the regression fixture
`revocred-api/internal/valuation/testdata/catalog.json`; the audit copy is
`.local/ongoing-catalog.json`. The feed has exact product IDs, `last_verified`,
issuer URLs, structured earning rules, and benefit descriptions flattened to
strings. Benefit amounts/frequencies are not consistently machine-structured;
there is no safe universal dollar parser.

The simplest fail-closed adapter is the reviewed allowlist
`revocred-api/internal/valuation/benefits.json`: 75 evidence/exclusion records,
covering all 15 catalog products, with 15 monetized recurring benefit rules.
Amounts were explicitly reviewed, **not extracted automatically from prose**.
Valued rules require exact catalog UUID + exact OpenCard product ID + exact
reviewed benefit text. Changed/removed text or missing community data yields
zero with `source_missing_or_changed`; the model does not fuzzy-match or use AI
web output. Additional feed perks do not silently become money. Exclusions remain
visible so missing data is not represented as an absence of benefits.

Each row retains source URL, reviewed date, original source-verification date,
frequency, conditions, and adapter version. API rows additionally expose the
current cached snapshot SHA-256 and issuer catalog version. Reviewed date means
adapter review, **not** a claim that every upstream issuer term was freshly
verified. Cached source dates can be old; these are estimates from reviewed
snapshots, not live issuer guarantees. Future term changes need a reviewed
adapter update. Raw issuer/AI text never writes modeled financial amounts.

| Exact product | Included annual face amounts before 70%/budget screen | Exclusions / gaps |
|---|---|---|
| Amex Gold | $120 Uber Cash; $120 dining; $100 Resy; $84 Dunkin | Generic bundle itself excluded (no duplicate); insurance/per-stay Hotel Collection value excluded |
| Amex Platinum | $200 Uber Cash; $120 Uber One; $200 airline incidentals | Lounge access, Global Entry multi-year reimbursement, protections excluded; feed is not a complete inventory of current issuer credits |
| Venture X | $300 Capital One Travel; 10,000 anniversary miles at 1 cent = $100 | Lounge access, multi-year Global Entry/TSA and protections excluded |
| Sapphire Reserve | $300 travel; $500 The Edit annual capped statement credits; $300 Exclusive Tables dining | Two-night/qualifying-booking and half-year conditions retained; lounge access, relationship offer, temporary/unclear offers excluded |
| Citi Strata Elite | $300 hotel; $200 selected-brand Splurge; $200 Blacklane | Two-night Citi Travel, brand selection and half-year Blacklane caps retained; lounges/multi-year reimbursements/relationship bonuses excluded |
| Sapphire Preferred | None pending complete versioned review | Feed omits hotel/anniversary terms; issuer now advertises $100 hotel credit, not historical $50; anniversary spend cannot be assigned from best-wallet spending without allocation evidence |
| Quicksilver | None | Protections, assistance and travel-per-stay perks have no assigned annual cash value |
| Savor Student | None | Benefit evidence missing in feed, not proof of no benefit |
| SavorOne | None | Benefit evidence missing in feed, not proof of no benefit |
| Freedom Flex | None | Protections, per-stay perks, temporary memberships/credits and fixed-term offers excluded |
| Freedom Rise | None | Benefit evidence missing in feed |
| Freedom Unlimited | None | Protections, per-stay perks, temporary memberships/credits and fixed-term offers excluded |
| Citi Double Cash | None | Benefit evidence missing in feed |
| Citi Strata | None | Benefit evidence missing in feed |

Gold's feed has an amount-free dining-credit bundle, so only that gap was
supplemented by issuer verification. Explicit child rules share the exact feed
bundle anchor but distinct issuer-backed IDs and amounts; the parent bundle
stays at zero. Issuer sources checked:

- https://www.americanexpress.com/en-us/credit-cards/offers/resy
- https://www.americanexpress.com/en-us/account/get-started/gold/explore-benefits
- https://www.americanexpress.com/en-us/credit-cards/apply/terms/personal/gold-card/91101-10-0
- Preferred discrepancy: https://creditcards.chase.com/rewards-credit-cards/sapphire/preferred
  and https://media.chase.com/news/Meet-the-New-Chase-Sapphire-Preferred

The remaining benefit rows use the already cached feed evidence with issuer URLs
preserved, not a newly researched replacement catalog. Full source evidence,
verification dates and snapshots remain available in the public fixture.

## Flutter and mock parity

Home labels the number **Estimated ongoing yearly value**. A collapsed
"How this is estimated" expansion shows rewards, conditional credits at 70%,
anniversary rewards, fees, total, assumptions and each included/excluded benefit's
conditions, cap, frequency, status and source/review link. All Home treatments
have the expansion. The production number comes from the API; no first-year
recommendation fallback remains.

The mock-only estimator mirrors integer-cent rules and fail-closed behavior.
`scripts/sync_ongoing_evidence.py` generates its reviewed JSON mirror; `--check`
and Flutter tests enforce parity with the authoritative Go evidence. Demo/custom
products without exact evidence receive zero inferred credits, not invented
source-backed benefits.

## Verification and evidence

TDD: initial Go ongoing test failed with undefined `Ongoing`, then passed after
implementation. The breakdown/widget and mock tests likewise failed for missing
implementations before passing. Regression tests cover no-fee value, Venture X,
incompatible/no travel budget, missing/changed evidence, anniversary reward,
custom/unknown/inactive cards, duplicate/overlapping budget, all 15 source
bindings, ignored marketing perks, unchanged application rankings and chat facts.

Real commands/results (logs under `.local/`):

- `make check`: Flutter formatter/analyzer, full Flutter suite, SQL vet, all Go
  tests and Go vet passed. `.local/ongoing-check.log`.
- `make database-test`: disposable DB migrations to version 25, runtime-role
  isolation, lifecycle and backup/restore passed. `.local/ongoing-database-test.log`.
- `python3 scripts/sync_ongoing_evidence.py --check`: reviewed mirror matches.
- `make share-preview`: real API + shared Flutter preview rebuilt successfully.
  `.local/ongoing-share-preview.log`.
- `uv run --no-project --with playwright python scripts/ongoing_value_smoke.py`:
  disposable **local-only** Auth/API user; real bootstrap returned $288 rewards,
  $210 conditional travel credit, $100 anniversary reward, $395 fee, **$203 ongoing**.
  Incompatible travel profile returned zero credit. Public API readback matched.
  Browser at 390×844 expanded actual Home, checked numbers/conditions/sources,
  and recorded no runtime errors. Account deletion and subsequent Auth rejection
  verified in `finally`, including on an initial locator-ambiguity retry.

Sanitized actual response and QA flags: `.local/ongoing-value/qa.json`.
Screenshots (visually inspected):

- `.local/ongoing-value/home-mobile.png`
- `.local/ongoing-value/breakdown-mobile.png`
- `.local/ongoing-value/conditions-source-mobile.png`

No secrets were printed, no hosted database was modified, and no commit was made.
Unrelated pre-existing dirty work was preserved.
