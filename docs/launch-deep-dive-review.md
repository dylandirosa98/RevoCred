# RevoCred Launch Deep-Dive Review

Comprehensive codebase assessment compiled from five review passes
(three parallel-scout deep dives plus two targeted re-verification rounds).
Ground truth at time of writing: HEAD `f1879f9`, worktree **28 modified +
17 untracked paths** (`git status --short | wc -l` → 45), tracked diff
**28 files, 943 insertions, 404 deletions**. All file:line references below
were re-verified against the working tree unless marked otherwise.

## Overall rating: 7.5 / 10 — launch-close, not launch-ready

The core engineering is the strongest part of this project and is genuinely
good: deterministic server-owned recommendations, real database
least-privilege, fail-closed production guards on both client and server, and
documentation that admits what is unverified instead of hiding it. Nothing in
the P0 list is a rewrite; everything is provisioning, verification, or small
gated fixes.

What holds the rating back is that the remaining work is almost entirely
*outside* the code — issuer verification, production provisioning, legal
documents, backups, observability — plus a dirty worktree and a cluster of
small but real client bugs (demo labels in real mode, a spend-key mismatch
that silently zeroes demo math, a hallucination guard with holes). The code
earns trust; the catalog and operations have not yet.

| Axis | Score | Note |
| --- | --- | --- |
| API correctness / security | 9 / 10 | Deterministic engine, anon-only auth, schema isolation, strict validation |
| REVO grounded-explainer safety | 6.5 / 10 | Numbers server-derived (good); card guard is a denylist (bad); rank rule prompt-only |
| Flutter client | 7 / 10 | Contract matches, auth/session solid; 6+ small blockers, all fixable in place |
| Data / catalog | 4 / 10 | 14 snapshots unreviewed, Chase-only identity seeds, links expire 2026-12-25 |
| Ops / deploy / observability | 5 / 10 | Runbooks and guards exist; nothing provisioned, no backups/alerts/owner |
| Docs honesty | 9 / 10 | `production-readiness.md` admits gaps; API README route table is stale |
| Test coverage | 7.5 / 10 | Strong contracts and flows; thin digest/widget/error-path tests |

## How the repeated dives went

Each pass used three parallel read-only scout slices (API / Flutter / Ops),
then line-level verification of every blocker claim before reporting. The
passes were consistent on the big picture every time — same architecture,
same P0s, same clean secret scan — which is itself a signal the findings are
stable and not hallucinations. Later passes added precision rather than
reversals:

- **Passes 1–2** established the baseline: engine determinism, auth/DB
  isolation, prod guards, the P0 trio (catalog, prod backend, legal), the
  dirty tree, the stale README, demo-label leaks, dead theme code.
- **Pass 3** went file-level on the newest uncommitted work (chat
  blocks/context/issuerlookup, migrations 000016/000017, the 440-line
  questionnaire rewrite) and found the `inventsCard` denylist weakness, the
  prompt-only rank rule, and 6 line-pinned Flutter blockers.
- **Passes 4–5** re-verified every blocker with exact lines and found two new
  P0s: the spend-key mismatch (demo branches dead, yearly value zeroed) and
  the synthetic `_cardFor` placeholder leaking into production UI.

No pass contradicted an earlier pass. Open items only ever grew more specific.

## Architecture (verified)

`revocred_flutter/ (Riverpod + go_router)` → `Supabase Auth (bearer JWT)` →
`revocred-api/ (Go stdlib net/http + pgxpool, dedicated revocred schema)` →
`PostgreSQL`. Caddy is the sole public edge (TLS, `/metrics` → 404 at
gateway, `health_uri /readyz`). `revocred-mobile/` is the untouched legacy
reference. `supabase/seed.sql` is 0 bytes — Goose migrations own all data
(000001–000014, 000016, 000017; **no 000015 file**, confirmed harmless gap).

Verified in tree: `--healthcheck` hits `/readyz`
(`revocred-api/cmd/api/main.go:29`); production compose hardens the API
container (`read_only`, `cap_drop ALL`, `no-new-privileges`, mem/pids limits);
secret grep over `lib/`, `internal/`, `cmd/` returns only guard text — no
service-role key anywhere; `.env*` ignored with only `.env.example` tracked.

## Strengths — do not break these

- **Deterministic engine** (`revocred-api/internal/recommendation/engine.go`,
  `EngineVersion v2.0.0-conservative`): pure Go, no LLM in selection, stable
  sort with `CardSlug` tiebreak, sorted spend keys, conservative policy
  explicit (1¢/pt, housing zero, fees subtracted). `postRecommendations`
  rebuilds owned IDs from the wallet (`input.ExistingCardIDs[:0]`) so clients
  cannot inject scores. The `affiliate/` package is never imported by the
  engine — compensation cannot affect ranking by construction.
- **Auth done right** (`internal/auth/supabase.go`,
  `internal/httpapi/middleware.go`): anon-key-only `/auth/v1/user` verifier,
  UUID check, 503 fail-closed without oracle, per-user buckets (120
  reads/30 writes per min) plus 600/min/IP, explicit CORS allowlist with `*`
  rejected, `/metrics` bearer-gated with 404 disguise.
- **Database isolation is real**: `revocred` schema revoked from
  PUBLIC/anon/authenticated; `revocred_runtime` NOLOGIN group role;
  `delete_account()` SECURITY DEFINER EXECUTE-only; wallet-ownership trigger
  plus cross-owner integration test; per-account caps and retention triggers.
- **Prod guards fail closed on both sides**:
  `revocred-api/internal/config/config.go:81-101` (METRICS_TOKEN ≥ 32, HTTPS
  Supabase, `sslmode=verify-full`, non-postgres runtime role, bare-HTTPS CORS)
  plus `revocred_flutter/lib/core/config/app_config.dart:33-82` (rejects
  `sb_secret_`, mocks+prod, HTTP/localhost, non-anon JWT) plus
  `scripts/check_release_config.py` plus Gradle refusing debug-key fallback.
- **Honest docs**: `docs/production-readiness.md` states snapshots dated
  2026-09-23 are unreviewed and lists 7 open external requirements.
- **Migrations 000016/000017 safe**: nullable `blocks` column (online-safe,
  old rows render as text) and identity-only multi-issuer seeds
  (`ON CONFLICT DO NOTHING`, scoped Down). Verified zero impact on offers or
  recommendations (offers join `catalog_cards data_kind='issuer_snapshot'`
  only; reference rows can never enter either path).

## P0 — launch is blocked until these are done

1. **Dirty worktree.** 28 modified + 17 untracked (45 paths), 943+/404-.
   New modules (`chat/blocks.go`, `context.go`, `issuerlookup.go`,
   `000016/000017`, `strategy_digest.dart`, `chat_blocks_view.dart`,
   `issuer_mark.dart`) are uncommitted. Commit or stash before any release cut.
2. **Stale spend keys — demo math silently wrong (verified).**
   The questionnaire emits `dining/groceries/gas/travel/streaming/other`
   (`questionnaire_screen.dart:40-47`), but
   `core/logic/demo_recommendation.dart:22,35` branches on `rent`/`food`
   (unreachable — `rent→Bilt`, `food→Savor/Amex Gold` never fire from real
   answers) and `core/logic/yearly_value.dart:18-21` reads
   `rent/food/travel/everyday` (the form sends `other`, not `everyday`), so
   `MonthlySpending` is near-zeros for real input. Existing tests use the
   stale keys, so they pass while the flow is broken. Fix: unify on the
   server `monthly_category_spend` key set; update demo logic + tests. This is
   the highest-value regression test to add.
3. **Synthetic `_cardFor` placeholder in production UI (verified).**
   `strategy_screen.dart:344-357` fabricates `annualFee:'See issuer'`, empty
   multiplier, `benefits:['Playbook card...']` when a playbook name matches no
   catalog/wallet id — a fake card face + details sheet in real mode. Fix:
   hide/disable the details CTA when unresolved, or resolve by server
   canonical id.
4. **Demo labels on real numbers (verified).**
   `strategy_screen.dart:584` (`Estimated first-year demo value`) and `:801`
   (`Grounded in your demo profile`) are unconditional; the same file gates
   `DEMO CATALOG`/`ISSUER SNAPSHOTS` correctly at `:303-304` — copy the
   pattern. Home `_DemoBadge()` is unconditional at
   `home_screen.dart:88` while score/value gate on
   `useMocks||(!auth&&!preview)` at `:34-44`.
5. **Issuer catalog unverified.** 14 `issuer_snapshot` rows dated 2026-09-23
   explicitly not independently reviewed; reference index is 14 verified +
   Chase identity-only (+ 000017 multi-issuer identity rows). Fix: review
   against current issuer documents, publish corrections as NEW source/version
   rows, never edit migration history.
6. **No production backend provisioned.** No prod Supabase project (SMTP,
   confirmations, password policy, redirect allowlist, abuse controls), no PG
   roles, no domains/DNS, no `.env.production`, no secret store. Local
   `supabase/config.toml` is dev-shaped and currently dirty with a throwaway
   tunnel host (`:87,89`
   `fitting-letting-athletics-losses.trycloudflare.com`) — revert before
   commit, never ship.
7. **Legal placeholder in-app.** `legal_screen.dart:16-21` self-declares
   pre-release: no operator identity, jurisdiction, support contact,
   retention/backup SLA, DPA/subprocessors (Supabase + OpenCode/DeepSeek),
   affiliate disclosures. `support@revocred.app`
   (`profile_screen.dart:241`) is display text on an unconfirmed mailbox.

## P1 — fix or consciously accept with a written decision

- **REVO guard holes (verified).** `inventsCard` (`context.go:303-321`) is a
  ~19-substring denylist, not an allowlist — unlisted cards (`Savor Rewards`,
  `Discover it Miles`, `Altitude Go`, …) bypass it entirely, and substring
  matching over-permits (`Platinum` whitelists "platinum card"). The
  never-recommend-below-rank-1 rule is prompt-only in the AI path (the
  deterministic fallback is code-enforced via `Items[0]`). Either harden to an
  allowlist + exact-phrase match with a rank-1 post-check, or downgrade the
  "AI never selects cards" claim to prompt-directed. Chart numbers are
  server-derived by code (PASS, tested); only prose numbers rely on the prompt.
- **Hybrid goal missing (verified).** Server accepts
  `cash_back|travel|hybrid` (`validation.go:26,82,119`); client offers only
  travel + cash_back (`questionnaire_screen.dart:393-394`); `fromAnswers`
  mislabels hybrid as S04. Add the third choice or explicitly reject with a
  comment + round-trip test.
- **Fee `none` works by accident (verified).** UI sends `none`, switch in
  `app_models.dart:879-884` matches `'0'=>0` with `none` falling into `_=>0`
  (correct cents, dead arm); `production_safety_test.dart:17` constructs
  invalid `'0'`. Rename to `none`, add map test, fix fixture.
- **`other>=1` half-enforced (verified).** `card_terms_sheet.dart:190-191`
  floors correctly; `custom_card_form.dart` has no floor, and
  `yearly_value.dart` masks the bad write at read time. Shared
  `normalizeRates()` helper + test.
- **Cross-screen REVO errors invisible (verified).**
  `strategy_screen:134-137`, `cards_screen:190-193`, `home_screen:76-77`
  fire-and-forget `sendMessage`; failure sets `appController.error`, which
  `/revo` never renders (only `localError`). Await + snackbar, or surface the
  controller error on `/revo`.
- **REVO grounding label over demo data (verified).**
  `revo_screen.dart:134-136` claims personal grounding in real-mode signed-out
  over the demo wallet. Gate on `isAuthenticated||isPersonalPreview` like
  home/report.
- **Official Apply links expire 2026-12-25** (`000011:26`; ~89 days from
  review date). After expiry all Apply links correctly 404 but the product
  loses its apply path. Calendar re-review + corrective migration now.
- **README stale (verified).** `revocred-api/README.md:19` claims all `/v1`
  need Bearer — false; `api.go:68-74` shows public
  explain/cards/card-index/plan/offers by design. Liveness documented as
  `/healthz`; actual healthcheck is `/readyz`. Env table omits
  `METRICS_TOKEN`/`OPENCODE_GO_*`. Docs fix, no code change.
- **Migration ops.** Forward-only 000006/000011 abort `migrate-down/reset`
  mid-chain — never run against shared envs; 000006 destructive +
  irreversible, needs backup + staging dry-run. Missing `000015` file is a
  harmless Goose-sort gap; check `goose_db_version` on deployed DBs, don't
  renumber.
- **Scale limits.** In-memory limiters reset on restart; behind Caddy
  `RemoteAddr` is the proxy so the IP bucket is shared. Per-user buckets are
  the real protection; add edge limits before multi-replica.
- **No prod backup/PITR/RPO/RTO, no scraping/alerts/incident owner/log
  retention.** Only a local `pg_dump` drill. Single DB incident = data loss.
- **Password-rule split.** Client signup/recovery/change 12 chars vs signin 6;
  server policy may disagree → raw error. Delete-reauth is password-only and
  strands OAuth/MFA users if those exist.
- **Spend-tie nondeterminism.** `spendChart`/`spendBars` sort value-desc with
  no label tiebreak — one-line `sort.SliceStable` fix + test.
- **Release gate unenforced.** `make release-check` exists and is sound but is
  not in `make check` or CI; `docs/operations.md:58-60` invocation omits
  `SUPABASE_URL`/`SUPABASE_ANON_KEY`. Dead test block
  `scripts/test_share_tunnel.py:18-33` (duplicated class, first copy broken).
  One-line comment bug `share_tunnel.py:232-233`.

## P2 — polish, defer without guilt

Percent chart hardcodes "cash back" for all percent units; chart bars lack
semantics labels; roadmap order differs by screen (digest reversed vs timeline
forward — pick canonical); `strategyDigest` `currentCards/order/annualValue`
have no consumer; `onAskAbout` prop unwired; double thinking indicator;
`strategyCode()` duplicated in `httpapi/api.go` + `store/onboarding.go`;
`putStrategy` builds a playbook with nil prefs then discards it; `sqlc`
covers only `health.sql` beside handwritten pgx (adopt or remove); images
version-pinned not digest-pinned; 6 of 8 `AppThemeVariant` dead code;
`DELETE /v1/wallet` JSON body stripped by some proxies (add `?wallet_card_id=`
fallback); thin digest/widget/error-path tests; no offline banner (per-screen
errors acceptable for launch if REVO surfacing is fixed).

## Things to add (post-launch roadmap)

1. Conversion postbacks / earnings pipeline (explicitly unimplemented;
   dashboard is a manual HTML snapshot).
2. Link-expiry watcher + alert on active-official count.
3. `?wallet_card_id=` DELETE fallback; edge/shared rate limiting; Supabase JWT
   verify/cache (not for launch — latency/availability tradeoff).
4. Mid-wizard draft persistence + questionnaire Skip (legacy had it).
5. `/account`, offers-failure, and offline widget tests; fee/hybrid/`other`
   round-trip tests; stale-spend-key regression test.
6. Broaden reference coverage beyond Chase identity rows, or narrow the
   product claim to supported cards. No partner links seeded by design —
   affiliate revenue needs network approval first.

## Launch sequence (in order)

1. Commit the tree; revert `supabase/config.toml` tunnel host; cut a release
   branch.
2. Fix P0 client bugs: spend-key unification, `_cardFor` path, demo gates
   (`:584`, `:801`, home badge).
3. Fix `other>=1`, fee `none`, hybrid goal, REVO error surfacing + label.
4. Harden `inventsCard` (allowlist + exact-phrase + rank-1 post-check) or
   downgrade the claim; spend-tie tiebreak.
5. Issuer review → NEW source/version rows → republish official links (before
   2026-12-25).
6. Provision prod Supabase (SMTP, confirmations ON, strong passwords, exact
   allowlist, abuse controls) + PG roles + domains/DNS + secret store.
7. Approved privacy/terms replace `LegalScreen`; confirm support mailbox.
8. `make release-check` with the full five-var env → owner-login migrate once
   → `docker-compose --env-file .env.production -f compose.production.yaml
   up --build -d` → verify HTTPS/readyz/auth/recommendations/export/recovery
   with real delivered email.
9. Managed backups/PITR + encrypted off-host storage + isolated restore drill;
   metrics scraping + alerts (readiness 1m, 5xx>1%, auth failures, p95>2s,
   pool, 429s) + incident owner.
10. Staging acceptance: browser/device flows, session expiry/recovery,
    accessibility pass, 2× load test; branch protection + hosted CI secrets;
    record image digests; rewrite README routes/env tables; delete dead test
    block; fix `operations.md` release-check line.

## Bottom line

Ship the provisioning and verification, fix the listed client bugs (all
small, all line-pinned above), commit the tree — then launch. The foundation
is better than most pre-launch codebases; the remaining risk is launching
unverified financial recommendations without legal and operational cover.
