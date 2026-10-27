# Home purchase-category comparison

## What changed

Home no longer uses marketing keywords, a card's highest unrelated multiplier,
wallet position fallbacks, or the global catalog to pick a purchase card. The Go
`internal/purchaseguide` package generates a deterministic comparison from the
member's active wallet. This is separate from acquisition recommendations,
wallet score, and yearly-value estimates, which are unchanged.

Authenticated `GET /v1/bootstrap` now includes `purchase_guide`.
`GET /v1/purchase-guide?travel_mode=...&caps_available=true|false` returns a fresh
comparison of that authenticated member's current wallet. It accepts no member
ID, card IDs or earning rates from the client. Invalid contexts return 400;
anonymous requests return 401.

The Flutter Home consumes the API's order. It never locally ranks production
cards. A final owned-ID filter prevents stale responses from showing a removed
or unowned card. The hero, list, earn label and “Why this card?” all use the same
purchase-specific result. Category comparisons have no Apply action. Acquisition
recommendations remain in the separately labelled next-move area.

## Rules and assumptions

- All 16 current Home categories have results or an explicit unsupported/unknown
  state. Generic catch-all rates do **not** imply that rent earns rewards or is
  payable without processing fees. Explicit user-supplied rent terms retain an
  eligibility/payment-route warning.
- Base rates and amounts come from exact mapped OpenCard records when available;
  stored source/user-supplied numeric terms are the fallback. Card names,
  benefit descriptions and generic maximum multipliers never determine rank.
- Reviewed adapters bind a source product ID and exact earning-rule label to
  supported categories and purchase contexts. Rates remain source values, not
  hardcoded rates in the adapter. New ambiguous labels are flagged as unreviewed
  and never inferred from keyword overlap. Existing fixture tests reconcile every
  category rule for the 14 mapped main products.
- Online shopping means an ordinary online purchase with no established merchant
  bonus. A restaurant multiplier, online grocery-only bonus, rotating category,
  or travel-portal rate cannot leak into this comparison.
- Travel has a booking-channel selector separating general travel, direct
  flights/hotels, and each supported portal/purchase type. A Chase Travel rate
  cannot apply to direct bookings or another issuer's portal.
- Point/mile rates are compared at **1 cent per point/mile**; cash back uses face
  value. This is a modeled return, not a guarantee of realized redemption value.
  Annual fees, credits and welcome bonuses do not inflate per-purchase ranking.
- Known capped rates assume unused eligible allowance by default. The visible
  “Spending caps still available” control can exclude them. It is an assumption,
  **not linked transaction/spending tracking**. The control is scoped to the
  selected category: exhausting a grocery cap cannot exhaust a separate dining
  or flight cap. Wallet/bootstrap changes clear stale context overrides.
- Rotating-category activation, elected self-select categories, introductory
  eligibility, Citi Nights timing and brand-specific purchase restrictions are
  not silently assumed. Unconfirmed bonuses appear under conditional rates,
  outside the default ranking. Portal alternatives are also explicitly qualified.
- Unknown terms are excluded, never treated as a low known rate. Unknown warnings
  carry aligned card IDs, so client filtering removes warnings for removed cards.
  Ties are recomputed after that filtering without changing server order. Known
  issuer product caps are enforced even if optional upstream cap metadata is
  absent, including the stored-data fallback. Unknown/unlimited supplied rates
  are not blanket-suppressed. Community source dates and limitations remain
  visible; this does not make an incomplete feed independently verified.
- If a booking-context request fails, the visible selector resets to the last
  confirmed guide; the previous rates are never labelled with an unconfirmed
  new channel. Retry resends the attempted settings. Failure and retry behavior
  has a dedicated widget regression test.

## Verified examples

The real browser/API smoke uses a disposable local account owning Amex Gold,
Sapphire Reserve and Quicksilver Good Credit:

| Purchase/context | Highest known modeled rate |
|---|---|
| Ordinary online shopping | Quicksilver, 1.5% cash back |
| Eligible groceries, cap available | Amex Gold, 4x |
| Eligible dining, cap available | Amex Gold, 4x |
| Grocery cap unavailable | Quicksilver, 1.5% cash back |
| Eligible Chase Travel purchase | Sapphire Reserve, 8x |
| Direct airline booking | Sapphire Reserve, 4x |

Adding Platinum to that QA wallet changes direct-airline selection to Platinum's
5x (subject to its eligible-flight cap); removing it changes the selection back.
A separate test confirms that disabling grocery caps does not change dining's
cap setting. None of these QA operations modify a real member's wallet.

## Verification commands

```sh
make check
cd revocred-api && go test -race ./internal/purchaseguide ./internal/httpapi
# Requires the local stack and existing share tunnels:
uv run --no-project --with playwright python scripts/purchase_guide_smoke.py
```

The smoke checks real API results for all category IDs, owned-only candidates,
cap and portal controls in a 390×844 browser, wallet add/remove recalculation,
source-specific earning labels, browser runtime errors, and QA-account deletion.
Screenshots and its machine-readable result live under
`.local/purchase-guide-smoke/`. It does not use saved user credentials or contact
production. Offline mock mode uses explicitly labelled, structured demo rates;
it never calls the real API or pretends those fixtures are current issuer terms.
