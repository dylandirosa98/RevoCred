# Official application links

Until an affiliate network is approved, every Apply button points at the
issuer's own product or application page. Migration 11 seeds one `official`
offer per active issuer-snapshot card (14 total). These earn no commission and
the UI says so ("Official issuer link. RevoCred earns no commission from this
link."). The commission disclosure appears only for `kind = 'affiliate'`.

The links were checked on 2026-09-25 against issuer listing pages. That check
confirms navigation only; it is not a re-review of the modeled card terms.
They expire on 2026-12-25 so a stale link cannot linger: re-check each URL and
republish (revoke, then `go run ./cmd/offers -publish` with `"kind":
"official"`) before then. Issuer pages change product URLs without notice.

When an affiliate partner is approved, revoke the card's official offer and
publish the partner link with `"kind": "affiliate"`; the disclosure switches
automatically. See [affiliate operations](affiliate-operations.md).

Placements counted: `recommendation`, `strategy`, `report`, `card_details`.
Apply is offered on any browsed card the user does not own, but the top
recommendation keeps the primary button and a "Recommended next move" label;
other cards show an outlined button that reminds the user which card their
strategy prioritizes. Rankings never read offer data.
