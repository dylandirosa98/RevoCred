# Railway deployment (API)

Only the Go API runs on Railway. The Flutter app ships through the App Store
and Play Store, and Supabase hosts Auth and Postgres. The service is defined in
[`.railway/railway.ts`](../.railway/railway.ts) (Railway Infrastructure as
Code); secrets live only in Railway.

Railway replaces the Caddy gateway in `compose.production.yaml`: it terminates
TLS, issues certificates and routes the custom domain to the container.

## One-time setup

1. **CLI.** IaC needs Railway CLI 5.42.1 or newer and Node 22+:
   `npm install -g @railway/cli@latest`, then `railway login`.
2. **Project.** Create an empty Railway project, install the Railway GitHub
   app on `dylandirosa98/RevoCred`, then from the repository root run
   `railway link` and pick the project and `production` environment.
3. **Supabase database login.** Provision `revocred_app` as described in
   [operations.md](operations.md#database-access). Use the **session pooler**
   (port 5432) connection string; the direct host is IPv6-only and the
   transaction pooler (6543) breaks pgx prepared statements. Pooler usernames
   take the form `revocred_app.<project-ref>`.
4. **Database CA.** Download the certificate from Supabase → Project Settings →
   Database → SSL configuration. It is the trust root for `sslmode=verify-full`.
5. **Shared variables.** In Railway → Project Settings → Shared Variables for
   `production`, add (seal the secret ones):

   | Name | Value |
   | --- | --- |
   | `DATABASE_URL` | `postgresql://revocred_app.<ref>:<password>@<pooler-host>:5432/postgres?sslmode=verify-full` |
   | `DATABASE_CA_CERT` | Full PEM text of the Supabase certificate |
   | `SUPABASE_URL` | `https://<ref>.supabase.co` |
   | `SUPABASE_ANON_KEY` | Public `sb_publishable_…` or anon key |
   | `METRICS_TOKEN` | Random, 32+ characters (`openssl rand -hex 32`) |
   | `AI_API_KEY` | OpenAI API key (`sk-…`). Optional; empty keeps REVO on the deterministic explainer |
   | `AI_BASE_URL` | `https://api.openai.com/v1` |
    | `AI_MODEL` | Explicit OpenAI model enabled for the client's project; verify with a staging request |
    | `AI_REASONING_EFFORT` | A value supported by the selected model; `none` sends temperature 0.2 |

   Never add the Supabase service-role key or the owner database login.
6. **Create the service.**
   ```sh
   cd .railway && npm ci && npm run typecheck && cd ..
   railway config plan
   railway config apply
   ```
   The plan should show one service, `api`, and no deletions.
7. **Domain.** In the `api` service → Settings → Networking, add a custom
   domain such as `api.revocred.app` and create the CNAME and TXT records it
   shows. Ship app builds against this domain, never `*.up.railway.app`: the
   API URL is compiled into every installed copy of the app.

## Every release

1. Back up (Supabase PITR or a verified dump), then apply new migrations once
   from your machine with the **owner** connection — never the runtime login:
   `DATABASE_URL='<owner url>' make -C revocred-api migrate-up`.
   The runtime image is distroless and does not run migrations.
2. Push to `main`. Railway waits for the GitHub `Verify` workflow, builds
   `revocred-api/Dockerfile` and only switches traffic once `/readyz` passes.
3. Check `https://<api-domain>/readyz` and the deploy logs (JSON, with request
   IDs).

Rollback: Railway → service → Deployments → redeploy the previous deployment.
Data migrations are forward-only; see [operations.md](operations.md#rollback-and-incidents).

## REVO AI provider

**Production uses OpenAI. OpenCode Go/DeepSeek and the developer's personal key
are testing-only.** For `APP_ENV=production`, enabling external AI requires an
explicit `AI_API_KEY` (OpenAI `sk-…`), `AI_BASE_URL=https://api.openai.com/v1`,
and `AI_MODEL`. Production refuses inherited `OPENCODE_GO_*` settings or any
other endpoint. If no AI key is configured at all, REVO remains deterministic.
Store the client's production key only in server-side Railway secrets, never
in Flutter/iOS configuration. Provision separate production/staging projects,
keys, budgets and monitoring; do not copy the developer's local `.env`.

Development still supports `OPENCODE_GO_*` as fallbacks to `AI_*`. For OpenAI
the API sends `max_completion_tokens` and `store=false`,
omits `temperature` unless `AI_REASONING_EFFORT=none`, and allows more tokens
when reasoning is on. Startup fails, rather than leaking the key, if an `sk-`
key would go to OpenCode or OpenAI has no `AI_MODEL`.

Provider failures still answer the member with the plan summary ("Full answers
are unavailable right now"). Check the deploy logs for `ai provider
unavailable`; it records the HTTP status and the provider's error message,
never the member's question. After a change, send REVO a question and confirm
a full answer. The startup log line `server listening` shows `chat=openai`.

`GET /v1/public/chat-disclosure` returns the actual configured recipient, model
and versioned sharing notice without personal data. Before every chat message,
Flutter offers Cancel, Use basic reply, or Agree and send. Only the last choice
sends `ai_consent_version` matching the current notice. Both public and signed-in
chat routes default to deterministic replies without permission; a stale version
returns 409 and never calls external AI. There is no remembered permission to
carry between messages or accounts. Older clients therefore receive basic replies.

With consent, REVO sends the member's entered personal context and recent chat
to the provider; see the in-app sharing notice for the exact fields. Name OpenAI
in the production privacy policy and App Store privacy answers. `store=false`
does **not** promise zero retention or disable every provider log; verify the
client's actual agreement and data controls. Test the full consent path on device.
OpenAI's [data controls documentation](https://developers.openai.com/api/docs/guides/your-data)
describes abuse-monitoring retention and approval requirements for ZDR; verify
the client's actual organization/project settings rather than assuming ZDR.

## How the service is configured

- `APP_ENV=production` makes the API refuse to start without
  `sslmode=verify-full`, a dedicated runtime role, HTTPS Supabase and a strong
  `METRICS_TOKEN`.
- `CLIENT_IP_HEADER=X-Real-IP` keys per-client rate limits on the IP Railway's
  edge reports. Without it every user would share the edge's limit. Only set it
  where the container is reachable solely through a proxy that overwrites the
  header.
- `CORS_ALLOWED_ORIGINS` is unset: native apps send no `Origin`, so browser
  requests are refused. Set it only if a web build is ever hosted.
- One replica. Rate limits and counters live in process memory; more replicas
  multiply the limits. Add a shared quota backend before scaling out.
- `/metrics` is public on Railway (Caddy used to hide it) but returns 404
  without `Authorization: Bearer <METRICS_TOKEN>`.
- The Dockerfile `HEALTHCHECK` is ignored; Railway checks `/readyz` instead.
  Compose-only hardening (`read_only`, `cap_drop`, `mem_limit`) has no Railway
  equivalent; set a memory limit under service Settings → Resources.
