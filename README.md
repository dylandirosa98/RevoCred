# RevoCred

RevoCred is being rebuilt as a responsive Flutter application with a Go API.
The original React Native package remains in the repository as the visual and
functional prototype.

## Packages

| Path | Purpose |
| --- | --- |
| `revocred_flutter/` | New Flutter app for iOS, Android, Linux, and web. |
| `revocred-api/` | Go API, deterministic recommendation engine, and PostgreSQL persistence. |
| `revocred-mobile/` | Original React Native prototype; retained as a reference. |

## Quick Preview

Flutter is installed locally at `~/.local/share/flutter`. Run the responsive
demo directly:

```sh
make flutter-web
```

Open `http://localhost:8081`. Demo mode is the default and does not contact a
live backend.

For a self-hosted production-style static preview:

```sh
cp .env.example .env
make docker-up
```

The Nginx-served Flutter build is then available at `http://localhost:8081`.
Stop it with `make docker-down`.

## Full Local Stack

Railway and the hosted Supabase project are not required for development. Run
local Supabase once, generate a matching pair of gitignored frontend/API env
files, and apply the database migrations:

```sh
make local-setup
```

Then use separate terminals for the Go API and Flutter web app:

```sh
make api-run-local
make flutter-web-real
```

Open `http://localhost:8083` for real-mode Flutter. Port 8081 is reserved for
the mock Nginx image (`make docker-up` / `make flutter-web`). This loop uses
local Supabase Auth, local PostgreSQL, and the local Go API; it does not
contact the hosted RevoCred project. With the API running, exercise the
complete backend journey with:

```sh
make local-e2e
```

## Verify Everything

```sh
make check
```

This checks formatting, runs Flutter static analysis and tests, and runs Go
tests and `go vet`.

## Real Backend Mode

The production direction is:

```text
Flutter -> Supabase Auth -> Go API -> Supabase-hosted PostgreSQL
```

The Go API owns recommendations and mutations. Flutter sends a Supabase access
token as a bearer token. No service-role key is used by the client.

Build the web image in real mode by setting public build configuration:

```sh
REVOCRED_USE_MOCKS=false \
REVOCRED_API_URL=https://api.example.com \
SUPABASE_URL=https://project.supabase.co \
SUPABASE_ANON_KEY=your-public-anon-key \
docker-compose build frontend
```

See `revocred_flutter/README.md` and `revocred-api/README.md` for package-level
setup. Catalog repair migrations exclude demo records from real-mode selection
and publish conservative, source-linked issuer snapshots. These still need
current issuer review before public launch.

## Production Readiness

See [the readiness checklist](docs/production-readiness.md) for implemented
hardening and external launch requirements, and [operations](docs/operations.md)
for deployment, database roles and recovery.

```sh
make database-test # disposable PostgreSQL isolation tests and restore drill
make security-check # Go dependency/runtime vulnerability scan
make verify-local # local Supabase/API journey with temporary-account cleanup
make browser-smoke # Chromium journey incl. emailed password recovery (after local-preview)
```
