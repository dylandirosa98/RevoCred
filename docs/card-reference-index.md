# Card reference index

Onboarding can search a much larger card list than the 14 cards RevoCred models
for recommendations. The index exists for one purpose: helping a person say
"yes, I own that card". It is search-only.

## Rules

- **Never recommendable.** An index pick becomes an owned `user_supplied`
  catalog card. Only public `issuer_snapshot` cards can be recommended, so an
  index card can never come back as a suggestion or earn an Apply link. There is
  a browser test asserting no Apply link appears for an owned card.
- **No invented terms.** An index row either carries terms copied from a dated
  issuer source (`terms_status = 'verified'`) or carries identity only
  (`terms_status = 'partial'`). Network is `Unknown` unless a source stated it.
- **The user's terms win.** When someone adds a card we ask for the terms and
  pre-fill the published rates where we have them. Their terms are stored, not
  ours, because theirs is the card they actually hold.
- **Skipping is allowed and explained.** A skipped card is saved and shown as
  owned with `terms_unknown`, and is excluded from the wallet score, valuation
  and ranking inputs. The UI says, in two places, that the score may be less
  accurate as a result. The flag is deliberately inverted (`terms_unknown`) so
  an unset value can never silently drop a card from the math.
- **A modelled product wins.** If a pick matches a card the catalog already
  models, the real catalog card is used and no user copy is created, so sourced
  terms are never replaced by typed ones.
- **Preview matches saved.** A guest preview synthesizes index picks in memory
  and feeds the engine the same cards and terms the saved plan will use, so the
  numbers do not change after sign-up.

## Adding more cards

Current coverage: 14 verified rows (the modeled catalog, terms copied from the
catalog) plus 25 identity-only rows captured from Chase's public card list on
2026-09-26. That is **not** a large database yet.

To add an issuer, capture its public card list and insert identity rows with the
issuer's product URL and the capture date. Requirements:

1. Name without the issuer prefix; the issuer is its own column, and a prefixed
   name produces a duplicate of the catalog-backed row.
2. Strip `®`, `™`, `℠` and standalone `SM` **before** collapsing whitespace, or
   names end up with double spaces.
3. Omit any product the vetted catalog already models.
4. Do not guess `network`, fees or rates. Leave them empty or copy them from a
   dated issuer page and set `terms_status` accordingly.

The endpoint is `GET /v1/public/card-index?q=`, unauthenticated and rate limited
per IP, and is the only consumer. Migrations 13 and 14 hold the seed rows; both
are forward-only, so a corrected dataset is a new migration rather than an edit
to a shipped one.

## Verification

- `make database-test` covers: search finds rows, verified rows resolve to the
  catalog, identity rows are sourced, a skipped-term card is saved with
  `terms_unknown` and leaves the score at the no-rewards floor, supplying terms
  raises the score and value, unknown reference IDs are rejected, and one
  account cannot pick up another's card.
- `make check` covers the terms sheet (pre-fill, both paths, the accuracy
  warning) and the anonymous search call.
- `python3 scripts/card_index_smoke.py` drives a real browser: search, add with
  terms, add while skipping, confirm both reach the wallet, confirm the report
  states the exclusion, and confirm no Apply link appears.
