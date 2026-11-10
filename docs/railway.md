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
    | `AI_REASONING_EFFORT` | Optional. Defaults to `low` for OpenAI to keep REVO replies fast; `none` sends temperature 0.2 |
    | `SEARCH_PROVIDER` | `searxng` for keyless private search, or `brave` (default) |
    | `SEARCH_BASE_URL` | SearXNG only: private search service URL, e.g. `http://search.railway.internal:8080/search`; see [setup](revo-web-lookup.md#keyless-search-setup) |
    | `SEARCH_API_KEY` | Only needed for Brave. SearXNG needs no key; Brave without a key disables search |
    | `CHAT_DAILY_AI_LIMIT` | External-AI REVO replies per user per rolling 24 hours (default 60). Basic answers are not capped |

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

**OpenAI is the release provider.** For `APP_ENV=production`, external AI must
be set explicitly through `AI_API_KEY`, `AI_BASE_URL` and `AI_MODEL`; inherited
`OPENCODE_GO_*` settings are never used. Two endpoints are accepted:

- `https://api.openai.com/v1` with an OpenAI `sk-…` key (release).
- `https://opencode.ai/zen/go/v1` with an OpenCode Go key and a `deepseek-…`
  model, as a deliberate testing choice before an OpenAI key exists. The
  in-app sharing notice names it "OpenCode Go and DeepSeek (testing)". Check
  OpenCode Go's terms and usage limits before real members use it, and switch
  to OpenAI before App Store submission.

If no AI key is configured at all, REVO remains deterministic.
Store the key only in server-side Railway secrets, never in Flutter/iOS
configuration.

Development still supports `OPENCODE_GO_*` as fallbacks to `AI_*`. For OpenAI
the API sends `max_completion_tokens` and `store=false`,
omits `temperature` unless `AI_REASONING_EFFORT=none` (unset means `low`), and allows more tokens
when reasoning is on. Startup fails, rather than leaking the key, if an `sk-`
key would go to OpenCode or OpenAI has no `AI_MODEL`.

Provider failures still answer the member with the plan summary ("Full answers
are unavailable right now"). Check the deploy logs for `ai provider
unavailable`; it records the HTTP status and the provider's error message,
never the member's question. After a change, send REVO a question and confirm
a full answer. The startup log line `server listening` shows `chat=openai`.

`GET /v1/public/chat-disclosure` returns the actual configured recipient, model,
search provider and versioned sharing notice without personal data. The first
time a member sends a message while external AI is configured, Flutter offers
Agree and continue, Basic answer instead, or Cancel. Agreement is saved per
account (`PUT /v1/chat/consent`) until the member turns it off in Profile;
guests agree once per app session. When the notice changes (new model, endpoint
or search provider) its version changes and every member is asked again. A
message sent with a stale explicit version returns 409 and never calls external
AI. Without saved permission, replies are deterministic basic answers.

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
- `CORS_ALLOWED_ORIGINS` comes from the shared variable of the same name. Leave
  it empty for the App Store: native apps send no `Origin`, so browser requests
  are refused. Set it to explicit HTTPS origins only while a web build (for
  example a testing preview) calls this API.
- One replica. Rate limits and counters live in process memory; more replicas
  multiply the limits. Add a shared quota backend before scaling out.
- `/metrics` is public on Railway (Caddy used to hide it) but returns 404
  without `Authorization: Bearer <METRICS_TOKEN>`.
- The Dockerfile `HEALTHCHECK` is ignored; Railway checks `/readyz` instead.
  Compose-only hardening (`read_only`, `cap_drop`, `mem_limit`) has no Railway
  equivalent; set a memory limit under service Settings → Resources.
