# RevoCred

RevoCred is a Flutter application backed by a Go API, Supabase Auth, and
PostgreSQL. The old Expo app remains under `revocred-mobile/` only as the UI/UX
reference during the rebuild.

## Packages

- `revocred_flutter/`: primary mobile/web client. Use the Flutter SDK at
  `~/.local/share/flutter/bin/flutter` when `flutter` is not on `PATH`.
- `revocred-api/`: Go API and deterministic recommendation engine.
- `revocred-mobile/`: legacy React Native prototype. Do not add new product
  functionality here.

## Verification

Run `make check` from the repository root. It runs formatting checks, Flutter
analysis/tests, and Go tests/vetting.

Use `make flutter-web` for a local mock-data browser preview or `make docker-up`
for the self-hosted Nginx build. Neither command should contact production in
the default mock configuration.

## Architecture Rules

- Keep recommendation selection and scoring deterministic and server-owned.
- AI may explain grounded results but must not select cards.
- Never hardcode production endpoints, credentials, or Supabase keys.
- The Flutter client may hold the public Supabase key but never a service-role
  key or database credential.
- Keep real card terms sourced and versioned. Demo catalog rows must remain
  clearly labeled as unverified demo data.
