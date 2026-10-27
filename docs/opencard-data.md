# OpenCard DB integration

RevoCred reads OpenCard DB's free public JSON feed server-side:
`https://raw.githubusercontent.com/thedavidweng/opencard-db/main/exports/cards-all.json`.
No API key, signup, cardholder data, or paid provider is involved.

## What is connected

- Exact public catalog UUID → OpenCard product-ID bindings live in
  `revocred-api/internal/carddata/cache.go`. All fourteen main cards currently
  map. The `quicksilver` row is the base Quicksilver (excellent credit),
  re-sourced to the base issuer page in migration `000025`, and bound to
  `us-capital-one-quicksilver`. No fuzzy matching, new
  recommendation candidates, custom-card conversion, or reference-index rewrite.
- The API adds optional `community_data` to catalog/wallet card JSON. It retains
  full structured earning rules (currency, unit, merchant/portal descriptions,
  caps), flattened display rules, benefit descriptions/conditions, separate
  welcome-offer and travel-perk evidence, original sources, source verification
  date, fetch date, and snapshot SHA-256.
- Wallet and strategy card details display this in an attributed supplemental
  section, alongside existing issuer snapshots. Newer issuer benefits are not
  overwritten by older community descriptions. REVO receives source-labelled
  community facts as reference material, not permission to select cards.
- These descriptions are **not independently verified, complete issuer terms**.
  Missing benefit data means unknown, not no benefit. Some upstream records have
  no benefits; old records trigger a display warning after 90 days.
- Annual fees, scoring `reward_rates`, recommendation ordering and saved issuer
  versions remain unchanged. Wallet ongoing yearly value now has a separate
  bounded reviewed adapter for relevant recurring cash credits and anniversary
  rewards; see [ongoing-value.md](ongoing-value.md) for assumptions, exact source
  bindings, exclusions and fail-closed behavior. Unreviewed prose, conditional
  earning rates and welcome offers never become universal rates or cash value.
- No issuer card artwork is imported, downloaded, or substituted.

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
RevoCred adapts field formatting for display and shows attribution, license link,
issuer link, verification date and retrieval date in the UI. This license does
not grant rights to card artwork or issuer trademarks. Re-check the upstream
license if changing provider or importing a different artifact.

## Verification

- `go test -race ./internal/carddata ./internal/store ./internal/chat`
- `make database-test`: disposable PostgreSQL, actual runtime-role persistence,
  restart/cache reload, 14 exact mappings, wallet enrichment, unchanged scoring
  inputs and recommendation results.
- `make check`: formatter/analyzer, complete Flutter and Go suites, SQL vet.
- `test/community_card_data_test.dart`: model isolation, copy preservation, and
  mobile-width rendering with currency, earning rules, benefit text, dates,
  source attribution and external links.
- `uv run --no-project --with playwright python scripts/opencard_smoke.py`:
  real shared-browser test at 390×844 with a disposable local QA account,
  expanded Reserve credits, earning rates, dates/attribution, and no runtime
  errors. Deletes its own account and verifies deletion. Uses installed native
  Playwright Chromium when available; `CHROMIUM_PATH` can override it. Snap
  Chromium cannot access Hermes scratch profiles under confinement.
