# Official application links

Until an affiliate network is approved, every Apply button points at the
issuer's own product or application page. Migration 11 seeds one `official`
offer per active issuer-snapshot card (14 total). These earn no commission and
the UI says so ("Official issuer link. RevoCred earns no commission from this
link."). The commission disclosure appears only for `kind = 'affiliate'`.

The links were originally checked on 2026-09-25 against issuer listing pages
and expire on 2026-12-25 so a stale link cannot linger. An independent
re-audit on 2026-11-23 ([card data audit 2026-11-23](card-data-audit-2026-11-23/README.md))
verified:

- All 10 Chase, American Express, and Citi product URLs from migration 11
  continue to return HTTP 200 live product pages.
- All 4 Capital One `marketableOfferId` links (`48308`, `48321`, `47672`,
  `48137`) still return HTTP 200 (client-side SPA shell), but Capital One's
  live product pages now embed rotated offer IDs (`42214` Savor Student,
  `42700` Quicksilver, `42144` SavorOne, `42623` Venture X). Verify these in a
  browser — or switch to the stable product page URLs (`/credit-cards/...`) —
  when republishing before 2026-12-25.
- Migration `000032_catalog_audit_2026_11_23.sql` publishes new immutable
  `card_catalog_versions` (`conservative-2026-11-23-v1`) for all 14 cards. By
  design (`revocred-api/internal/store/affiliate.go`), publishing a newer
  catalog version hides superseded offers until an operator revokes the old
  offers and republishes against the new `catalog_version_id` via
  `go run ./cmd/offers -publish` with `"kind": "official"`. Issuer pages change
  product URLs without notice.

When an affiliate partner is approved, revoke the card's official offer and
publish the partner link with `"kind": "affiliate"`; the disclosure switches
automatically. See [affiliate operations](affiliate-operations.md).

Placements counted: `recommendation`, `strategy`, `report`, `card_details`.
Apply is offered on any browsed card the user does not own, but the top
recommendation keeps the primary button and a "Recommended next move" label;
other cards show an outlined button that reminds the user which card their
strategy prioritizes. Rankings never read offer data.
