# Deployment and operations

## OpenCode Go (developer testing only)

REVO never queries Postgres as an LLM and never receives a database password
or service-role key. The API loads **this authenticated user's** wallet, spend,
strategy, playbook, metrics, and server ranking. After per-message permission,
developer testing can ask DeepSeek V4.1 Flash through OpenCode Go to explain
those facts. Basic replies do not call external AI. Card selection stays
server-owned. Use synthetic data for testing.

```sh
make setup-opencode-go
make local-stop && make local-preview
```

The wizard writes `OPENCODE_GO_API_KEY` to gitignored `revocred-api/.env.local`
(mode 600). OpenCode Go is sold for coding-agent traffic; testing still needs
to comply with its terms. It is not the production provider for this app.

Development supports OpenAI-compatible settings through `AI_API_KEY`,
`AI_BASE_URL`, `AI_MODEL` and optional `AI_REASONING_EFFORT`, taking precedence
over `OPENCODE_GO_*`. Production requires explicit OpenAI settings and rejects
the testing fallbacks. Its Compose file also no longer maps legacy testing
variables into production `AI_*` variables. See
[railway.md](railway.md#revo-ai-provider).

## Local development

Use `make local-setup`, then `make local-preview` for a managed release build
and API on 8082/8083 (`make local-stop` to stop them), or `make api-run-local`
and `make flutter-web-real` for the interactive dev loop. `make verify-local`
manages a temporary API and tests real local auth/persistence. `make browser-smoke`
drives the real account/recovery journey in Chromium and reads delivered emails
from the local Mailpit UI port. The mock Nginx preview remains on 8081. After
changing `supabase/config.toml`, restart local Supabase to apply auth redirects;
do not reset the database.

## Database access

Apply migrations 6–9 with a separate owner/migration login before deploying the
new API. Migration 6 is forward-only: its provenance repair cannot safely be
reversed. Provision the runtime login through an owner connection:

```sql
CREATE ROLE revocred_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
GRANT revocred_runtime TO revocred_app;
-- In psql use \password revocred_app to set its private password interactively.
```

The runtime URL must use `sslmode=verify-full` and the provider's trusted CA
(supply a CA outside the system bundle as PEM text in `DATABASE_CA_CERT`).
Pooler usernames must follow the provider's custom-role format. Never embed an
owner login or service-role key in Flutter. Keep `revocred` out of Supabase's
exposed Data API schemas.

## Production deployment

The hosted API runs on Railway; follow [railway.md](railway.md). The Compose
steps below remain for self-hosting.

1. Complete `production-readiness.md` in staging.
2. Supply `APP_DOMAIN`, `API_DOMAIN`, `TLS_EMAIL`, `SUPABASE_URL`, public
   `SUPABASE_ANON_KEY`, private runtime `DATABASE_URL`, and random private
   `METRICS_TOKEN` (32+ characters) through your secret store/environment.
   Compose implicitly reads the repository's local `.env`, so run production
   deployments with an explicit environment file:
   `docker-compose --env-file .env.production -f compose.production.yaml up --build -d`
   (`.env.production` is gitignored). Never let the local development `.env`
   feed a production build.
3. Run `make release-check` with `REVOCRED_PRODUCTION=true`,
   `REVOCRED_USE_MOCKS=false`, `REVOCRED_API_URL=https://<API_DOMAIN>` and
   `REVOCRED_AUTH_REDIRECT_URL=https://<APP_DOMAIN>/` (store builds use
   `com.revocred.app://auth-callback/`).
4. Verify a backup; apply migrations once with the migration login.
5. Run the Compose command from step 2.
6. Verify HTTPS, readiness, authentication, recommendations, export and recovery.

Only Caddy is exposed by production Compose. It obtains TLS certificates for
your domains. Metrics are blocked at the public gateway: scrape the private API
with `Authorization: Bearer <METRICS_TOKEN>`. Never commit filled-in env files,
signing keys, dumps or tokens. Image tags are version-pinned, not digest-pinned;
record/deploy resulting immutable image digests for formal releases.

## Health and monitoring

- `/healthz`: process liveness.
- `/readyz`: database access and required catalog/schema availability.
- `/metrics`: private request, 5xx, throttling and client-error counters.
- JSON logs: request ID, method, path, status and duration.

Suggested starting alerts: readiness failure for 1 minute, sustained 5xx above
1%, auth-provider failures, p95 latency above 2 seconds, pool saturation, and
unexpected client errors/429s. Tune after load tests. Configure external log
collection/retention and incident routing; the app cannot provision them.

The in-process limiter allows 600 requests/minute per remote peer, 120 reads and
30 writes/minute per authenticated user. Memory is bounded. Forwarded IP headers
are untrusted unless `CLIENT_IP_HEADER` names a header set by a trusted edge
(Railway: `X-Real-IP`); behind Caddy its traffic shares the peer limit. Before multiple
replicas or higher traffic, add edge limits and a shared quota backend. Restarts
reset in-memory limits/counters; database quotas and retention persist.

## Backups and restore

Enable managed backups/PITR and define RPO/RTO and retention. For self-managed
PostgreSQL, schedule full logical `pg_dump --format=custom` backups using an
environment-supplied connection and dedicated backup role. Encrypt before
off-host storage. Capture required global roles separately. Do not store
plaintext dumps or passwords in this repository.

`make database-test` includes a local dump/restore drill. Production drills must
restore into an isolated database, provision the runtime role, then exercise
auth, wallets and recommendations against the restored service. Never test a
restore over the live database. Supabase-managed schemas require the provider's
restore procedure; the minimal local auth fixture is not a replacement.

## Rollback and incidents

Restore the previous compatible image digest for application failures. Do not
automatically reverse data migrations. If incompatible, deploy a forward fix
or restore a verified backup into an isolated replacement database and perform
a controlled cutover. Inspect readiness and request-ID logs first. Rotate
affected server secrets at the provider, redeploy and verify that client bundles
contain only public configuration.

## Catalog updates

Insert a new source with precise issuer URL/capture date and a new catalog
version with a unique dataset version; never update historical rows. Keep
modeled rates conservative: portal multipliers, caps and conditional credits
must not become unconditional rewards. Test independently calculated examples
and deactivate withdrawn products. Source review/publishing stays server-side.

## Android signing

Create local `revocred_flutter/android/key.properties` with `storeFile`,
`storePassword`, `keyAlias` and `keyPassword`. Signing files are ignored.
Release builds fail without signing configuration rather than use debug keys.
Test signed builds and callbacks on devices before store submission.
