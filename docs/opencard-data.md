# OpenCard DB integration

RevoCred reads OpenCard DB's free public JSON feed server-side:
`https://raw.githubusercontent.com/thedavidweng/opencard-db/main/exports/cards-all.json`.
No API key, signup, cardholder data, or paid provider is involved.

## What is connected

- Exact public catalog UUID → OpenCard product-ID bindings live in
  `revocred-api/internal/carddata/cache.go`. All fifteen main cards currently
  map. The `quicksilver` row is the base Quicksilver (excellent credit),
  re-sourced to the base issuer page in migration `000025`, and bound to
  `us-capital-one-quicksilver`. No fuzzy matching, new
  recommendation candidates, custom-card conversion, or reference-index rewrite.
- The API adds optional `community_data` to catalog/wallet card JSON. It retains
  full structured earning rules (currency, unit, merchant/portal descriptions,
  caps), flattened display rules, benefit descriptions/conditions, separate
  welcome-offer and travel-perk evidence, original sources, source verification
  date, fetch date, and snapshot SHA-256.
- Wallet and strategy card details use readable rewards, benefits and travel
  sections, with issuer links and a verification/age notice. Display-only
  formatting turns structured caps into spending limits and groups credit
  amounts/cadences, rather than printing JSON or internal field names. Cards
  do not show provider branding or duplicate modeled/source rewards blocks.
  Newer issuer benefits are not overwritten by older community descriptions;
  raw source/evidence and modeled calculation inputs remain unchanged.
  REVO receives source-labelled
  community facts as reference material, not permission to select cards.
- These descriptions are **not independently verified, complete issuer terms**.
  Missing benefit data means unknown, not no benefit. Some upstream records have
  no benefits; old records trigger a display warning after 90 days.
- Catalog annual fees, catalog scoring `reward_rates`, recommendation ordering
  and saved issuer versions remain unchanged. Owned cards added from search
  without typed terms can now be scored in the wallet with community terms; see
  [Wallet scoring terms](#wallet-scoring-terms). Wallet ongoing yearly value now has a separate
  bounded reviewed adapter for relevant recurring cash credits and anniversary
  rewards; see [ongoing-value.md](ongoing-value.md) for assumptions, exact source
  bindings, exclusions and fail-closed behavior. Unreviewed prose, conditional
  earning rates and welcome offers never become universal rates or cash value.
- No issuer card artwork is imported, downloaded, or substituted.

## Wallet scoring terms

`internal/carddata/terms.go` maps every US record in the feed to conservative
scoring terms (`MapTerms`, mapping version `opencard-terms-v2`). On the
2026-11-09 snapshot, 292 of 435 US products map; the rest are left unscored
with a stated reason.

### Where they are used

- **Only for a card the member already owns** that was added from search (or
  typed with the exact same issuer and name as a search row) **and saved
  without terms** (`terms_unknown`). Terms the member typed always win; catalog
  cards keep their issuer terms.
- The owned card is linked to its search-index row (`catalog_cards.reference_card_id`,
  migration `000031_custom_card_reference_link.sql`). The reference row stores an exact `opencard_product_id`.
  Migration 000031 links the 76 reviewed aliases in `internal/carddata/references.go`
  and inserts the remaining US identities from the 2026-11-09 snapshot (435 distinct
  products total), preserving existing issuer rows and catalog matches. Identity-only
  rows remain `partial`, with empty rates: community data never masquerades as verified
  issuer terms. The reviewed aliases still resolve for older internal callers.
  There is no fuzzy matching. Newly introduced upstream products require a versioned
  index seed before they are searchable; cached rate refreshes need no migration.
- When the product maps, the API fills the card's `reward_rates`, annual fee,
  rewards type and transferable flag in memory. It sets `terms_source:
  "community"` and attaches `community_terms`: source name, issuer URL, source
  verification date, capture date, snapshot SHA-256, mapping version, and every
  scored and unscored source rule with its reason. `dataset_version` becomes
  `opencard-terms-v2:<captured date>:<sha prefix>`. `source_disclaimer`,
  `summary`, `best_use` and `benefits` say the rates are community data and not
  issuer-verified. Nothing is written back to the database, so a refreshed
  snapshot updates the card automatically.
- The terms feed wallet metrics (score and ongoing value, including the annual
  fee), the guest preview's wallet metrics, Explore Rewards (which reads the
  server's `rewards_cents`), the purchase guide (labelled as the source), and
  REVO's grounded context (`terms_source` on the wallet card and in purchase
  rankings, with dates and the rules not counted).
- **Recommendations are unchanged.** `recommendation.Engine` drops owned cards
  with `terms_source = community` from its inputs and never ranks one as a
  candidate. `SaveOnboarding` keeps them out of `existing_card_ids`. The
  strategy playbooks (S01–S09) are untouched. Tests assert identical ranked
  items and exclusions with and without community-scored cards.
- Search results (`GET /v1/public/card-index`) include `community_terms` for
  non-catalog rows, for information only. The terms sheet's pre-fill still
  uses the row's own `reward_rates`.

The adapter attempts every US product, but does **not** promise all 435 have
usable everyday terms. 143 remain unknown: incomplete, discontinued, conditional,
closed-loop or ambiguous records. The app must keep
these cards owned and unscored until the member supplies terms. This intentionally
limits coverage instead of fabricating everyday rates.

### Mapping rules

Card-level (the whole card stays unscored if any rule fails):

1. US, status `active` or `invite_only`. Discontinued and unknown-status
   products are not scored.
2. Annual fee in USD, present, between $0 and $10,000.
3. Valid `last_verified` date, not in the future.
4. `rate_type` is `cashback_percent` (rewards type `cash_back`) or
   `points_multiplier`/`miles_multiplier` (rewards type `travel`, the catalog's
   word for point and mile currencies). Cash values use the versioned
   per-currency assumptions below.
5. A rewards currency is present (not `none`).
6. Network is not `other`. These are closed-loop store cards that earn only at
   the merchant.
7. Hotel and other co-brand currencies retain their actual point/mile earning
   rates. Their modeled dollars and category comparisons use **0.5¢ for Hilton and IHG,
   0.7¢ for Marriott/Bonvoy/Ritz-Carlton, and 0.8¢ for Wyndham**. All other
   currencies (including cash back, bank points, airline miles and Hyatt) stay at
   1¢. `point_value_cents` is separate from nominal `reward_rates`; zero/absent
   means 1¢. These are conservative model assumptions, not guaranteed redemption
   values. `opencard-terms-v3` records this change. Values are derived on load for
   community-scored wallet cards; issuer snapshots are unchanged and no database
   migration is needed. The wallet disclaimer and REVO context state the valuation;
   do not describe this estimate
   as actual cash earned or combine currencies into a transferable point balance.
8. A non-null, finite base rate between 0 and 20. High nominal rates alone do not
   prove a store restriction; closed-loop networks and conditional descriptions
   are checked separately.
9. The base description is unconditional and unambiguous. AutoPay, "redeemed into" or deposit
   account, "if", linked accounts, tiers, membership/Prime, relationship and
   "after the first $" conditions make it conditional. Descriptions that require consulting the agreement,
   say spending must be above a threshold, or limit the quoted base to a travel
   category are rejected too. In particular, Barclays Arrival has a numeric base
   of 2 but prose saying 2x travel / 1x other: it is not scored until corrected
   upstream rather than silently treating 2x as an everyday rate. Post-first-year
   bases also remain unscored. Explicit earning gates in source notes (a required
   subscription or membership to earn, or a minimum purchase count to earn) also
   exclude the whole card. Robinhood Gold is one such example. Finite numeric
   rates are required.

The base rate becomes `other`. Engine and Flutter spending use `food`, `travel`,
`gas`, `streaming`, `shopping`, `utilities`, `rent` and `other`, with finer
`dining`, `groceries`, `flights` and `hotels` inputs also supported. `food` uses
the minimum of dining and grocery rates (base fallback for either); generic
`travel` never inherits a flights-only or hotel-only uplift. Shopping and
utilities use base because the adapter cannot prove a universal category rate.
Rent/housing always earn zero in the existing model. Each category rule is then checked in this
order, and the first failing check is recorded as the reason:

1. Label conditions (lowercased label, first match wins):
   - rotating, quarterly, activation, enrollment
   - cardholder-chosen, top-spend, monthly or "adaptive" categories
   - temporary or intro rates: "first year", "first N months", "new
     cardmember", "through <date>", "until", any date or year
   - portal, app or online-only: "booked through/on/in", "purchased through",
     "… Travel", "travel center", "portal", "via", ".com", "app", "online",
     "website", "in-store"
   - spend caps written in the label: "first $", "up to", dollar amounts,
     "then N", "thereafter", "cap", "maximum", "per year", "annually",
     "combined", "limit"
   - status, membership or timing: "status", "tier", "member", "Prime",
     "linked", "bundle", "when you", "after $", "with X+", AutoPay, "nights",
     weekdays
   - loyalty-program totals: "total", "incl. N", "card earn", "base points",
     "bonus"
2. Vocabulary. After dropping exclusion and example parentheticals
   ("(excluding …)", "(e.g. …)", "such as", "like …"), every word must be
   either a category word or a generic filler word. Category words:
   - restaurant(s), dining, takeout → `dining`
   - grocery/groceries, supermarket(s) → `groceries`
   - gas, fuel → `gas`
   - travel → `travel`
   - flight(s), airfare, airline(s), air, air travel → `flights`
   - hotel(s) → `hotels`
   - streaming → `streaming`

   Filler words include "eligible", "purchases", "stations", "EV charging",
   "including delivery", "booked directly", "U.S.", "worldwide", and non-scored
   everyday categories such as transit, drugstores and utilities. Any other
   word (merchant, brand, airline, hotel chain, program, unknown term) makes
   the label merchant-specific, so "Hilton hotels", "Gas at Costco" and
   "Eligible United flights" are not scored.
3. At least one category word is present.
4. The rate is between 0 and 20.
5. The source `cap` is null. Any structured cap means the rate is not scored
   (for example, Blue Cash Everyday's 3% categories capped at $6,000 a year),
   so the category falls back to the base or another uncapped rate.
6. The rate is above the base rate.

A label naming several categories ("Gas, groceries and dining") scores each
category at that rate; the highest scored rate per category wins.

Transferable points: only for issuer-flexible currencies (Membership Rewards,
Ultimate Rewards, ThankYou, Wells Fargo Rewards, Bilt, and Capital One miles),
and only when the source's redemption notes say points transfer to partners.
Co-brand airline and hotel currencies are never transferable.

Tests: `internal/carddata/terms_test.go` checks real rows copied verbatim from
the 2026-11-09 snapshot (`testdata/terms_fixture.json`). They cover flat,
capped, rotating, chosen, top-category, portal, merchant-specific, hotel,
store, conditional-base, discontinued and transferable cases, and check that
every source rule is accounted for. Set `OPENCARD_SNAPSHOT=<cards-all.json>` to
check that every binding names a real US product in a full export. `make
card-data-status` reports `wallet_terms` counts.

## Refresh and fallback

Migration `000024_opencard_cache.sql` creates `community_card_snapshots`. Raw
public JSON snapshots persist separately from issuer catalog versions. Content
hashes identify snapshots; identical checks update only `last_checked_at`.
Runtime permissions allow reading/inserting snapshots and updating that check
column, not rewriting raw payloads.

At API startup, load the last successful DB cache. A background worker checks
at most once every 24 hours; failed requests retry after an hour and preserve the
last good snapshot. A fresh installation still serves the core catalog if the
feed is unavailable. Requests never wait for the external provider. Network
requests have timeouts and a 16 MiB body limit; invalid JSON, duplicate IDs,
missing mapped products, unexpected reward units or malformed dates are rejected
before publication. All mapped products must validate before the cache switches.

Disable fetch and enrichment with `OPENCARD_ENABLED=false` on the API process.
No cron job or external daemon is required.

Local-only operator commands (load the existing local database configuration):

```sh
make card-data-refresh  # explicitly fetch and persist
make card-data-status  # read back the persisted snapshot; no network fetch
```

An explicit CLI refresh becomes visible to a running API after its next refresh
or restart; the CLI does not mutate in-process memory. The local preview rebuild
restarts the API and hydrates the refreshed snapshot immediately.

## Attribution and reuse

Data: [OpenCard DB](https://github.com/thedavidweng/opencard-db),
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/),
[upstream data license](https://github.com/thedavidweng/opencard-db/blob/main/LICENSE-DATA).
RevoCred adapts field formatting for display. Attribution, the original source
link, license link and adaptation disclosure are in Profile → Privacy and terms
→ Data credits. Cards retain issuer links and source verification dates without
provider branding or technical retrieval metadata; fetch dates remain in the API.
This license does
not grant rights to card artwork or issuer trademarks. Re-check the upstream
license if changing provider or importing a different artifact.

## Verification

- `go test -race ./internal/carddata ./internal/store ./internal/chat`
- `make database-test`: disposable PostgreSQL, actual runtime-role persistence,
  restart/cache reload, 15 exact mappings, wallet enrichment, unchanged scoring
  inputs and recommendation results. It also checks wallet community terms:
  the reference link is written on creation and cannot be rewritten by the
  runtime role, a skipped pick is scored and labelled, a hotel-currency card
  retains its nominal earning rate, typed terms win, wallet metrics rise, and search
  `community_terms` and the guest preview work with recommendations unchanged.
- `make check`: formatter/analyzer, complete Flutter and Go suites, SQL vet.
- `test/community_card_data_test.dart`: model isolation, copy preservation, and
  mobile-width readable card details with currency, earning rules, benefits,
  dates and issuer links; attribution appears separately in Legal.
- `test/card_detail_text_test.dart`: spending-cap and travel-field formatting,
  preservation of missing/zero/conditional terms, no raw code across all fifteen
  catalog products, and unchanged source evidence.
- `uv run --no-project --with playwright python scripts/opencard_smoke.py`:
  real shared-browser test at 390×844 with a disposable local QA account,
  Discover/Gold spending limits, Reserve credits and travel conditions, clean
  Cards presentation, dates and issuer links, separate Legal attribution, unchanged
  financial inputs/evidence and no runtime errors. Deletes its own account and
  verifies deletion. Uses installed native
  Playwright Chromium when available; `CHROMIUM_PATH` can override it. Snap
  Chromium cannot access Hermes scratch profiles under confinement.
