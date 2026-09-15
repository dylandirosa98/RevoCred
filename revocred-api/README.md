# RevoCred API

Production-oriented Go HTTP foundation for RevoCred. Supabase owns authentication and hosts PostgreSQL; this service verifies Supabase access tokens and owns application logic, recommendations, and portable SQL persistence through `pgxpool`.

## Architecture

- `cmd/api`: process startup, dependency wiring, HTTP timeouts, and graceful shutdown.
- `internal/httpapi`: routes, strict JSON decoding, validation, CORS, auth middleware, request IDs, and structured errors/logs.
- `internal/auth`: testable Supabase `/auth/v1/user` token verifier using only the public anon key.
- `internal/recommendation`: deterministic pure-Go v1 scoring and transparent estimates. No LLM participates in selection.
- `internal/chat`: provider interface with a grounded deterministic demo provider. No external AI call is made.
- `internal/store`: repository contract and PostgreSQL implementation.
- `internal/database`: generated sqlc package; do not edit these files manually.
- `queries`: source SQL used to generate the database package.
- `migrations`: Goose-managed schema and explicitly non-current demo catalog.

Application tables live in the dedicated `revocred` PostgreSQL schema rather than Supabase's Data API-exposed `public` schema.

All `/v1` routes require `Authorization: Bearer <supabase-access-token>`. `GET /healthz` is public. A service-role key is neither accepted nor required by this API or its clients.

## Environment

Copy values from `.env.example` into your environment. The process intentionally does not load `.env` files or provide credential defaults.

Required variables:

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | Standard PostgreSQL connection URL; use Supabase's direct or pooled URL in hosted environments. |
| `SUPABASE_URL` | Supabase project HTTPS URL. |
| `SUPABASE_ANON_KEY` | Public anon/publishable key sent only to Supabase Auth. |
| `CORS_ALLOWED_ORIGINS` | Comma-separated explicit origins. Wildcards are rejected. |

Optional variables are `APP_ENV`, `PORT`, `REQUEST_TIMEOUT`, `SHUTDOWN_TIMEOUT`, and `DB_MAX_CONNS`.

## Local Run

Go 1.24+ and a PostgreSQL database are expected.

Install the pinned project-local Goose and sqlc binaries:

```sh
make tools
```

```sh
export DATABASE_URL='postgresql://postgres:postgres@localhost:5432/revocred?sslmode=disable'
export SUPABASE_URL='https://your-project.supabase.co'
export SUPABASE_ANON_KEY='your-public-anon-key'
export CORS_ALLOWED_ORIGINS='http://localhost:8081'
make migrate-up
make run
```

The API does not auto-run migrations, which keeps schema changes explicit and safe in multi-instance deployments.

## Database Development

Create and apply Goose migrations with:

```sh
make migration NAME=create_strategies
make migrate-up
make migrate-status
```

`make migrate-down` rolls back one migration. `make migrate-reset` rolls back all migrations, so use it only against a disposable development database.

Add annotated queries under `queries/`, then regenerate the typed `pgx/v5` package:

```sh
make generate
make sqlc-vet
```

The tool versions are pinned in `Makefile` and installed under the ignored `bin/` directory. Existing repository queries remain handwritten for now; they can be migrated to sqlc incrementally instead of changing all persistence behavior at once.

## Routes

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/healthz` | Public liveness response. |
| `GET` | `/v1/bootstrap` | Profile, wallet, catalog, latest recommendation, and prompts. |
| `GET` | `/v1/cards` | Latest version of each active catalog card, including source disclaimer. |
| `GET`, `PUT` | `/v1/profile` | Read or upsert the authenticated user's profile. |
| `GET`, `POST`, `DELETE` | `/v1/wallet` | `DELETE` accepts `{"wallet_card_id":"<uuid>"}`. |
| `POST` | `/v1/recommendations` | Runs and persists deterministic scoring plus questionnaire input. |
| `GET`, `POST` | `/v1/chat/messages` | Lists history or stores a grounded deterministic exchange. |

Money inputs and outputs are integer cents. A recommendation request looks like:

```json
{
  "monthly_category_spend": {"dining": 45000, "groceries": 60000, "other": 30000},
  "fee_tolerance_cents": 10000,
  "travel_scope": "both",
  "rewards_goal": "travel",
  "credit_tier": "good",
  "existing_card_ids": []
}
```

Success responses use `{"data": ...}`. Errors use:

```json
{
  "error": {
    "code": "validation_error",
    "message": "request validation failed",
    "request_id": "...",
    "details": {"field": "reason"}
  }
}
```

## Verification

```sh
make test
make vet
make check
```

Tests use fakes and `httptest`; they do not require live Supabase or PostgreSQL services.

## Container

```sh
docker build -t revocred-api .
docker run --rm -p 8080:8080 --env-file .env revocred-api
```

Run migrations as a separate deployment step before starting a new API release.
