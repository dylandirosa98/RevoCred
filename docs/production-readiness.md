# Production readiness — local implementation

This is a release checklist, not a claim that the hosted service is ready.
The working tree includes the pre-existing strategy/playbook rebuild plus this
hardening work. No production credentials or production deployment were used.

## Implemented locally

- Wallet ownership enforced in repository SQL and a database trigger.
  Inactive/demo cards cannot be added. Custom names are account-scoped and
  removing a custom wallet entry removes its private catalog record.
- Forward migrations 6–9 retire demo rows, separate per-card issuer sources,
  create conservative catalog versions, forbid updates to versions/sources,
  and retain exact catalog snapshots with new recommendation runs.
- Real-mode Flutter never substitutes demo recommendations or playbooks.
- The server supplies separate, explicit wallet and incremental recommendation
  value models. Home includes reviewed conditional recurring benefits; application
  rankings remain conservative rewards-minus-fees. Wallet changes recalculate the
  next action. Student cards require an explicit student selection.
- Password reset, confirmation resend, email/password updates, session events,
  JSON export and password-reauthenticated account deletion are wired into Flutter
  and the API. Web auth query strings are preserved; native callback schemes are
  registered. Production delivery and device callbacks need external verification.
- Request limits, card quotas, bounded history, database readiness, private
  Prometheus counters and privacy-minimized client error reports.
- The runtime database role cannot directly mutate auth tables. Deletion uses a
  narrowly scoped backend-only function.
- Production configuration rejects mocks, insecure endpoints, privileged client
  keys and privileged/non-TLS database settings. Android release signing no
  longer falls back to a debug key.
- Pinned Flutter/Go builds (the frontend image clones and verifies the exact
  Flutter SDK tag), automated CI checks, dependency update configuration,
  production Compose/Caddy configuration, and disposable database restore tests.
- Browser-verified fix: the app-level loader now overlays in-progress screens
  instead of unmounting them, so sign-in and other flows are not dropped while
  server data refreshes.

## Model contract and limitations

The server calculates rewards in integer cents, rounds per spending category,
and values every point at **one cent**. Housing earns zero. Combined food uses
the lower dining/grocery rate. Catalog modeled rates omit known portal-only and
capped-category uplift. Home ongoing value adds reviewed relevant credits at a
disclosed conditional 70% usage assumption and eligible anniversary rewards,
then subtracts active annual fees; welcome bonuses remain excluded. See
[ongoing value](ongoing-value.md) for exact evidence/eligibility limits.
Application candidate value excludes these conditional benefits and is improvement
over the current wallet after the candidate's fee; non-positive improvements
are excluded. Custom card terms are user-supplied assumptions.

This intentionally underestimates some products rather than assuming use of
every benefit. It is not a complete simulator of caps, redemption options, APR,
merchant eligibility, application rules or offers. Never present those facts as
guaranteed value or approval. The wallet score is a product heuristic, **not a
credit score**.

Inherited issuer snapshots are dated 2026-09-23 and have **not been independently
reviewed by this implementation**. Verify fees, variants and terms against
current issuer documents before launch. Insert new source/version rows for
changes; never edit migration history. Earlier migrations updated rows in place,
so pre-repair historical terms cannot be reconstructed honestly.

Bootstrap's `latest_recommendations` is a fresh evaluation of the current wallet
and latest questionnaire. Historical runs and snapshots are available in account
exports. Switching a thematic strategy does not override fee/eligibility/value
constraints or invent a card selection.

## Data limits

- 100 wallet entries and 100 custom cards per account.
- Latest 1,000 chat messages and 100 recommendation runs/questionnaires.
  Older records are deleted as new records arrive.
- Account deletion removes the auth user and associated live application data.
  Backup copies expire under the operator's published retention policy.
- Exports contain application records, custom terms and recommendation snapshots;
  never password hashes or authentication tokens.
- Client reports contain only `flutter`/`platform` error categories. Server logs
  record request IDs, method, path, status and timing. Set log retention externally.

## Reproducible checks

```sh
make check
make database-test
make security-check
make verify-local  # requires local Supabase and .env.local
make browser-smoke # real browser journey; requires make local-preview and scripts/requirements-browser.txt
```

`database-test` creates/removes its own PostgreSQL container, uses a minimal
`auth.users` fixture, applies migrations, exercises the restricted runtime role,
and restores a dump into another database. It never reads production env files.
`verify-local` applies forward migrations to **loopback local Supabase**, starts
a temporary API, exercises a temporary real-auth account, and deletes it. It
does not reset the local database. `browser-smoke` drives the release web build
in Chromium through real sign-in, account export, sign-out, emailed PKCE
password recovery, session persistence across reload, account deletion and the
mobile-legal viewport, and fails on any browser runtime error.

## External launch requirements — still open

Onboarding card search (migrations 12-14) is implemented over a search-only index:
14 verified rows plus 25 identity-only rows, with cardholder-supplied terms and an
explicit skip path. Coverage is far from a full US database; see
[card reference index](card-reference-index.md). Affiliate infrastructure (migration 10, reviewed offers, Apply buttons, anonymous
click counts and an operator dashboard) is implemented. See
[affiliate operations](affiliate-operations.md). Earning revenue still requires
approved partner links; network application/approval/revenue reporting is not
connected. The iOS manifest and encryption declaration are included; see
[iOS privacy](ios-privacy.md) for the remaining Xcode/App Store validation.

1. **Issuer review:** verify launch catalog entries and publish corrections.
   Approve point valuations and customer-facing model claims.
2. **Legal/business:** replace the explicit pre-release notice with approved
   privacy/terms, operator identity, jurisdiction, support contact, backup/log
   retention and commercial/affiliate disclosures if applicable.
3. **Hosting:** choose staging/production services; provision database/API roles,
   private secrets, DNS, domains, TLS and capacity.
4. **Supabase:** configure production SMTP, email confirmation, password policy,
   exact web/native redirect allowlists, secure email changes and abuse controls.
   Verify confirmation, recovery and email changes with real delivered emails.
5. **Operations:** configure managed backups/PITR, encrypted off-host storage,
   scheduled restore drills, metrics scraping, alerts and an incident owner.
   Local tests do not prove hosted backup coverage.
6. **Mobile:** Android SDK, release keys, final store IDs and physical-device
   testing. iOS requires macOS/Xcode, provisioning and TestFlight/device testing.
   Linux desktop requires clang/GTK tooling. Keep signing assets out of Git.
7. **Release acceptance:** staging browser/device flows, accessibility, session
   expiry/recovery and realistic load tests. Add edge/shared rate limiting before
   scaling to multiple API replicas.

CI is ready to run when pushed. Branch protection, hosted CI secrets and remote
workflow success still require repository/provider configuration.
