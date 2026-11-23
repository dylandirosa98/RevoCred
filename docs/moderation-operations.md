# REVO Moderation Operations

Members can rate REVO replies and report answers that are inaccurate, unhelpful,
harmful, or offensive (`POST /v1/chat/messages/{id}/feedback`). Reports are
stored in `revocred.chat_feedback` and triaged strictly out of band through the
operator CLI (`revocred-api/cmd/moderation`).

There are **no** public admin endpoints, moderation routes, or privileged
database credentials in the Flutter client or the public Go API.

## Security & Database Isolation

Apply migration **32** (`000032_chat_feedback_moderation.sql`, forward-only)
with an owner/migration connection before deploying or using the CLI:

```sh
DATABASE_URL='<owner url>' make -C revocred-api migrate-up
```

Migration 32 adds operator triage columns (`status`, `reviewed_by`,
`reviewed_at`, `resolution_note`) with database-enforced invariants:

- `status` is constrained to `open`, `reviewed`, `actioned`, or `dismissed`
  (defaulting to `open`).
- Resolving a report (`reviewed`, `actioned`, or `dismissed`) requires both
  `reviewed_by` and `reviewed_at` at the database check-constraint level.
- If a member edits their rating or reason on a previously triaged message (for
  example escalating a thumbs-up to a harmful-content report), a trigger
  automatically reopens the row to `open` and clears prior review metadata.
- **Least privilege for `revocred_runtime`:** the public API login only holds
  column-level `SELECT`, `INSERT`, and `UPDATE` on user-submitted feedback
  columns (`message_id`, `user_id`, `rating`, `reason`, `created_at`,
  `updated_at`). It cannot read or mutate `status`, `reviewed_by`,
  `reviewed_at`, or `resolution_note`, and cannot directly `DELETE` feedback
  rows. Clearing chat (`DELETE /v1/chat/messages`) and account deletion
  (`DELETE /v1/account`) still remove associated feedback rows cleanly via
  foreign-key cascades.
- **Browser-role isolation:** `PUBLIC`, `anon`, and `authenticated` have zero
  privileges on `revocred.chat_feedback`.

## Triage SLA & Workflow

| Report category | Target initial triage | Typical resolution |
| --- | --- | --- |
| `Harmful or offensive` (`harmful`, `offensive`) | Within **24 hours** (immediately when webhook alerts are enabled) | Inspect full turn context; confirm whether OpenAI moderation or system guardrails missed an unsafe reply; mark `actioned` with remediation reference (prompt/guardrail fix, safety regression test, or provider escalation) or `dismissed` if false positive. |
| `Inaccurate`, `Not helpful`, `Other` | Within **7 days** (weekly review cadence) | Verify against sourced issuer terms and deterministic engine output; mark `reviewed` or `actioned` when catalog/prompt improvements are filed, or `dismissed` when accurate. |

### Status lifecycle

1. `open` — Newly submitted (or reopened because the member changed their rating
   or reason).
2. `reviewed` — Operator inspected the report; no immediate product or safety
   code change required.
3. `actioned` — Operator took corrective action (e.g., guardrail update,
   regression test, catalog term correction, or AI provider escalation) and
   recorded the reference in `--note`.
4. `dismissed` — Report reviewed and determined to be benign, off-topic, or a
   false positive.

## Operator CLI (`cmd/moderation`)

Run the CLI from `revocred-api/` with `MODERATION_DATABASE_URL` supplied via
your secret manager or shell environment (never in CLI flags, screenshots, or
version control). When connecting to Supabase with `sslmode=verify-full`, also
set `DATABASE_CA_CERT` to the Supabase CA PEM text.

```sh
export MODERATION_DATABASE_URL='postgresql://<operator-role>:<password>@<host>:5432/postgres?sslmode=verify-full'
```

### List open or filtered reports

```sh
# Open negative feedback / reports (default: -status open -rating down -limit 50)
go run ./cmd/moderation list

# Filter specifically for harmful/offensive reports since a UTC date
go run ./cmd/moderation list -status open -reason harmful -since 2026-11-01

# Inspect all statuses as JSON for scripting
go run ./cmd/moderation list -status all -json
```

Supported `list` flags:

- `-status`: `open` (default), `reviewed`, `actioned`, `dismissed`, or `all`
- `-rating`: `down` (default), `up`, or `all`
- `-reason`: case-insensitive literal substring filter (e.g. `harmful`, `offensive`, `inaccurate`)
- `-since`: inclusive UTC timestamp (`YYYY-MM-DD` or `RFC3339`)
- `-limit`: `1`–`500` (default `50`)
- `-json`: emit structured JSON array instead of a human-readable table

### Inspect a single report's full turn context

```sh
go run ./cmd/moderation show <MESSAGE_UUID>
go run ./cmd/moderation show <MESSAGE_UUID> -json
```

Displays triage metadata, the member's prompt, the reported assistant reply,
and up to two immediately preceding turns for conversational context.

### Record a triage decision

```sh
# Shorthand subcommands: reviewed, actioned, dismissed
go run ./cmd/moderation actioned <MESSAGE_UUID> --by "ops-handle" --note "Added safety regression test in PR #123"
go run ./cmd/moderation reviewed <MESSAGE_UUID> --by "ops-handle" --note "Verified against current Chase terms"
go run ./cmd/moderation dismissed <MESSAGE_UUID> --by "ops-handle" --note "False positive report"

# Equivalent explicit resolve subcommand (supports -json)
go run ./cmd/moderation resolve <MESSAGE_UUID> --status actioned --by "ops-handle" --note "..." -json
```

## Optional Alert Webhook

Alerting is **completely off by default**. To receive real-time notifications
when a member reports a REVO answer as `harmful` or `offensive`, set the
optional server environment variable (and Railway shared variable):

```sh
MODERATION_ALERT_WEBHOOK_URL=https://hooks.example.com/services/...
```

Safety and reliability guarantees:

- **Strict URL validation at startup:** requires a public `https://` hostname
  (no `http://`, raw IP addresses, loopback/private/internal hosts, embedded
  credentials, fragments, or non-443 ports).
- **SSRF defense at delivery time:** disables HTTP redirects and refuses DNS
  resolutions to loopback, RFC 1918, link-local, or CGNAT IP ranges.
- **Non-blocking & resilient:** alerts are dispatched asynchronously with
  bounded concurrency and a 5-second timeout. Webhook outages, timeouts, or
  non-2xx responses are logged as warnings and **never** fail or delay the
  member's feedback submission (`204 No Content`).
- **Secret-safe logs:** warning logs record only `report_id`, normalized
  `reason`, and destination `host` — never the full webhook URL or path token.
- **Exact privacy-minimized JSON payload:**

```json
{
  "event": "revo.moderation_report",
  "report_id": "11111111-1111-4111-8111-111111111111",
  "reason": "harmful_or_offensive",
  "submitted_at": "2026-11-23T07:30:00Z"
}
```

Use the `report_id` directly with `go run ./cmd/moderation show <report_id>`.

## Privacy Boundaries

- **No auth-table lookups:** `cmd/moderation` never queries `auth.users` and
  never prints member email addresses or raw account IDs.
- **Automatic redaction:** all displayed reasons, prompt snippets, assistant
  snippets, and turn contexts are scrubbed for email addresses, URLs with
  embedded credentials, Bearer tokens, JWTs, API keys (`sk-…`, `sb_…`, `gh*_…`,
  `AKIA…`), SSN-like numbers, and 13–19 digit card-like sequences.
- **Webhook minimization:** free-text member notes, prompts, replies, user IDs,
  and emails are never sent to `MODERATION_ALERT_WEBHOOK_URL`; only the
  normalized safety category (`harmful`, `offensive`, or
  `harmful_or_offensive`) is transmitted.
- **Account export & deletion:** `GET /v1/account/export` exports only
  user-submitted feedback fields and omits internal operator metadata
  (`status`, `reviewed_by`, `reviewed_at`, `resolution_note`). `DELETE
  /v1/chat/messages` and `DELETE /v1/account` delete the member's feedback rows.

## Verification

- `make check` runs Flutter formatting/analysis/tests, `sqlc-vet`, and Go
  unit/vet checks (including redaction, CLI flags/output, config validation,
  and webhook alerting tests).
- `make database-test` runs migrations through 32 in disposable PostgreSQL 15
  and verifies `revocred_runtime` column-level isolation, `anon`/`authenticated`
  denial, triage check constraints, reopen-on-edit behavior, account export
  filtering, cascade deletion, and backup/restore.
- `cd revocred-api && go test -race ./...` verifies race-free async webhook
  delivery and API handling.
