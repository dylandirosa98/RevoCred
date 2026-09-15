# RevoCred Flutter

Responsive Flutter frontend for RevoCred card strategy, wallet management,
roadmap planning, and REVO chat.

The app includes two complete product themes: Clear, a Wise-inspired
light-first direction using RevoCred colors, and Focus, a Linear-inspired dark
direction. Clear is the default. Open Profile and choose **Compare themes and
components** to see both against identical content. See
`DESIGN_DIRECTIONS.md` for the reference rationale and public sources.

## Run

Demo mode is the default and uses only local fixture data:

```sh
flutter run -d chrome --dart-define=REVOCRED_USE_MOCKS=true
```

Real mode requires a Go API and Supabase project configuration. Supabase is
initialized only when real mode is selected and both Supabase values exist.

```sh
flutter run -d chrome \
  --dart-define=REVOCRED_USE_MOCKS=false \
  --dart-define=REVOCRED_API_URL=https://api.example.com \
  --dart-define=SUPABASE_URL=https://project.example.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-publishable-or-anon-key
```

The API repository sends the current Supabase access token as a bearer token.
No production URL, project identifier, or key is included in the source.

## Verify

```sh
dart format lib test
flutter analyze
flutter test
```

## Self-hosted Web Build

From the repository root:

```sh
docker-compose up --build -d frontend
```

This creates a release Flutter web build and serves it through Nginx at
`http://localhost:8081`. The default Docker build uses mock data and needs no
credentials. Configure the public build arguments documented in the root
README to build real mode.
