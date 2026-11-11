# Data verification policy — lightweight, proposed (not enforced)

Status: **proposed** in this work directory only. No app, DB, migration, service, or model changes authorized. Stale-review, immutability, and pre-publish review below are **proposed, not claimed enforced** — the existing DB triggers (`immutable_catalog_version`, `check_wallet_owner` in `000006_catalog_integrity.sql`) are read-only context, not modified here.

## Principles

- One canonical structured record per exact product variant (issuer + product + network + variant qualifier, e.g., “Quicksilver Rewards for Good Credit” vs standard/One/Secured/Student; “SavorOne $39 (Fair)” vs “Savor $0”; “Citi Strata ($0 base)” vs Premier/Elite). Never reuse a row across variants.
- Display terms and scoring model stay separate. Scoring keeps the conservative subset (1 cpp, no bonuses/statement-credit uplift, portal/capped uplift excluded) per disclaimer. Conditional credits and welcome bonuses are display-only, never auto-added to projected value.
- Missing evidence never implies “no benefit.” Omit, flag `not_verified`, and schedule re-check — do not write “no fee/credit/protection.”
- Every field cites issuer evidence (URL + verbatim quote + `fetched_at` + `verified_at` + `sha256`). Community data is a candidate, never authoritative. Public GitHub without clear license is not commercial reuse permission. No card artwork ingestion.
- Immutable versioning: new evidence = new `card_catalog_versions` row + new `catalog_sources` row (never UPDATE). Demo rows stay demo; user-supplied custom stays user-supplied.

## Canonical record (proposed fields)

- `identity`: `slug, name, issuer, network, variant_qualifier, product_url (exact), terms_unknown (bool)`
- `fee`: `annual_fee_cents, authorized_user_fee_cents, foreign_txn_note` + evidence per field
- `rewards[]`: typed `{category, points_per_dollar_or_pct, cap_amount, cap_period, activation_required, scope_exclusions, portal_required}` + evidence per row (e.g., “5x prepaid hotels via AmexTravel; up to $500k/yr” with cap/portal typed, not prose)
- `credits[]`: `{title, amount_cents, cadence (annual/semi-annual/quarterly/monthly/per-4yr), activation (enrollment/add-to-Uber/etc), eligibility (channel/min-stay/etc), expiry_or_window, display_only:true}` + evidence per credit
- `protections[]`: `{title, coverage_summary, limit_amount, guide_pdf_url, guide_quote}` — marketing page alone insufficient; Guide to Benefits PDF required for limits
- `perks[]`: `{title, detail}` (lounge, status, entertainment) + evidence
- `welcome_bonus (separate)`: `{amount, spend, window, as_of}` — never merged into recurring value
- `sources[]`: `{source_id, name, url, disclaimer, published_at}` + `dataset_version, summary, best_use, transferable_points, rewards_type`
- `field_evidence{field: {url, quote, fetched_at, verified_at, sha256}}`, `review: {status: draft|in_review|approved|stale, reviewer, reviewed_at, next_review_due}`, `scoring_note: conservative subset description`

## Workflow (lightweight)

1. **Capture:** fetch exact product URL (+ Pricing Details + Guide PDF link) with stdlib/urllib or curl into `evidence/` + meta (`final_url, status, sha256, fetched_at`). 200 ≠ verification; empty/broad pages rejected. One alternative fetch for key failures; document errors.
2. **Type:** fill canonical record with per-field quotes/hashes; mark unknown as `not_verified`, not zero.
3. **Review:** second human reviews variant identity, caps/enrollment/expiry, tier separation (never copy Elite→base), promo-vs-recurring, and reuse license; sets `approved` + `next_review_due` (proposed: 90 days for premium travel, 180 days others; stale = past due, not auto-enforced).
4. **Publish (future, out of scope here):** insert new immutable version + source rows; never update history; keep conservative scoring disclaimer. No publish performed in this audit.

## Sample schema + example (proposed, not imported)

```json
{
  "slug": "sapphire-preferred",
  "variant_qualifier": "consumer Sapphire Preferred $95",
  "annual_fee_cents": 9500,
  "rewards": [
    {"category": "chase_travel", "points_per_dollar": 5, "cap": null, "activation_required": false, "portal_required": true}
  ],
  "credits": [
    {"title": "Chase Travel hotel credit", "amount_cents": 10000, "cadence": "per_account_anniversary_year", "activation": "none; purchase via Chase Travel", "eligibility": "hotel stays via Chase Travel; first $100 earns no points", "display_only": true}
  ],
  "field_evidence": {
    "credits[0]": {"url": "https://creditcards.chase.com/rewards-credit-cards/sapphire/preferred", "quote": "$100 Chase Travel Hotel Credit Earn up to $100 ... each account anniversary year for hotel stays purchased through Chase Travel", "fetched_at": "2026-10-25T23:46:02Z", "verified_at": "2026-10-25T23:55:00Z", "sha256": "9aac6a59..."}
  },
  "review": {"status": "approved", "reviewer": "human", "reviewed_at": "2026-10-25", "next_review_due": "2026-10-25+90d (proposed)"}
}
```

Example quotes are from `evidence/issuer-pages/sapphire-preferred.txt` to illustrate shape only; this file proposes the schema, it does not import data into the app.

## Reuse + safety checklist

- License verified from raw LICENSE (MIT vs MIT+Commons Clause vs CC BY 4.0 vs unverified federal). No scrape of artwork; no paid APIs; no secrets.
- Stale policy is proposed: premium 90d, others 180d; overdue = `stale`, needs re-fetch before display use.
