# Affiliate offers

The application now supports approved partner application links. No live links
are seeded: a real network/publisher agreement and reviewed terms are still
needed to earn commission. Redirect counts are not applications, approvals,
unique visitors or revenue. Conversion postbacks depend on the selected network
and are not implemented yet.

## Behavior

- The recommendation engine never reads commercial tables. Unpartnered cards
  remain eligible and can outrank partnered cards.
- Apply buttons attach to the server's top-ranked **card ID**, on Home,
  Strategy and the strategy report (including its exported PDF). They are hidden
  for guests, mock data, owned cards and missing/expired offers. A partner offer
  for another card cannot replace the top recommendation.
- Every button/link has a commission disclosure. Links open in an external
  browser/new tab. PDF links use the same live redirect, so revoked links cannot
  continue redirecting from an old report.
- `GET /v1/offers` lists available offer IDs, card IDs, networks and expirations.
  It does not return destination URLs or operator review identities.
- `GET /v1/offers/{id}/apply?placement=recommendation|strategy|report` resolves only
  an operator-stored HTTPS destination and records a daily count. There is no
  user-supplied destination or user-level tracking parameter. HEAD and prefetch
  requests do not count. Existing API/edge rate limits apply.
- Availability is checked at request time: approved flag, start/end window,
  active public issuer card, and exact latest catalog version must all match.
  New catalog terms require a new review and publication. Unavailable offers
  return 404 with a refresh instruction; storage failures return an error rather
  than claiming a click was recorded.
- Counts are `(offer, UTC day, placement)` aggregates only. No user IDs, cookies,
  IPs, user agents, wallet data or chat are persisted in these analytics. Keep
  partner URL parameters limited to fixed publisher/campaign IDs. Any future
  individualized attribution needs a separate privacy assessment.

## Publish and revoke (operator only)

Run migration **10** before deploying the API. `revocred_runtime` can read offers
and increment counters, but cannot publish, change or revoke offers. Supabase
browser roles have no access. Management runs out of band using `cmd/offers`;
there is no public admin endpoint or admin credential in Flutter.

From `revocred-api/`, set `AFFILIATE_DATABASE_URL` through your secret manager or
shell environment to an operator connection. Do not put credentials in command
arguments, screenshots or version control. Reporting needs only SELECT access.

Find the current public snapshot with your operator SQL client:

```sql
SELECT c.id AS card_id, c.name, v.id AS catalog_version_id,
       v.dataset_version, s.url AS source_url, s.disclaimer
FROM revocred.catalog_cards c
JOIN LATERAL (
  SELECT * FROM revocred.card_catalog_versions
  WHERE catalog_card_id=c.id ORDER BY created_at DESC,id DESC LIMIT 1
) v ON true
JOIN revocred.catalog_sources s ON s.id=v.source_id
WHERE c.is_active AND c.owner_user_id IS NULL AND c.data_kind='issuer_snapshot';
```

Review that snapshot against current issuer terms and confirm the publisher link
is approved for this product and placement. `issuer_snapshot` alone is not an
independent review. Then publish JSON, replacing every illustrative value:

```json
{
  "card_id": "UUID-FROM-QUERY",
  "catalog_version_id": "UUID-FROM-QUERY",
  "network": "Your approved partner",
  "destination_url": "https://partner.example/apply?publisher=YOUR_ID",
  "reviewed_by": "Operator identity or review reference",
  "approved": true,
  "starts_at": "2026-10-01T00:00:00Z",
  "ends_at": "2026-11-01T00:00:00Z"
}
```

```sh
go run ./cmd/offers -publish /secure/path/offer.json
go run ./cmd/offers -revoke OFFER_UUID
```

The first command prints the newly generated offer ID. Only one approved offer
per card is allowed, including scheduled/expired offers. Revoke it before
publishing its replacement. Review identity, timestamp and old offer rows are
retained; do not edit destinations on old offers. Publisher query parameters
are preserved exactly. Test against a partner sandbox before activating a live
offer; repeated tests of a live redirect count as clicks.

## Click dashboard

Generate a standalone operator HTML dashboard; no credentials are embedded:

```sh
go run ./cmd/offers -report -since 2026-10-01 > /secure/path/affiliate-report.html
```

Open that file in your browser. It includes zero-click offers and totals by
card, offer, network and placement. It is a snapshot; rerun to refresh. Keep it
internal. Anonymous aggregates are retained until an operator prunes them under
the deployment's retention policy; they are not attributable to account exports
or deletion. The dashboard does not estimate earnings or infer approvals.

## Verification

`make check` covers redirect validation, UI eligibility/disclosures and launch
failure. `make database-test` checks runtime permissions, expiry, scheduling,
version mismatch, revocation, concurrent click counting, browser-role isolation
and identical recommendation results before/after offer publication.
