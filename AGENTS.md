# RevoCred

RevoCred (REVO) is a React Native + Expo mobile app (single package in `revocred-mobile/`) that acts as a personal credit-card strategy engine: wallet tracking, a searchable card catalog, a Strategy timeline, and the REVO chat assistant. Auth and data sync run on Supabase; analytics via PostHog/Sentry (all gated by `EXPO_PUBLIC_*` env vars).

## Cursor Cloud specific instructions

- Everything lives under `revocred-mobile/`. Run all commands from there (the repo root has no `package.json`).
- Standard scripts are in `revocred-mobile/package.json` (`start`, `android`, `ios`, `web`). Typecheck with `npx tsc --noEmit`. There is no lint or test script configured.
- Web preview: `expo start --web` needs `react-dom`, `react-native-web`, and `@expo/metro-runtime`, which are NOT in `package.json`. Install them ad hoc (they conflict on peer deps, so use legacy resolution and don't persist them):
  `npm install --no-save --legacy-peer-deps react-dom@19.1.0 react-native-web@^0.21.0 @expo/metro-runtime`
  then `CI=1 npx expo start --web --port 8081`. `CI=1` disables file watching/hot reload, so restart the server to pick up code changes.
- Auth gotcha: the app talks to a live Supabase project (anon URL/key are hardcoded as fallbacks in `src/services/supabaseClient.ts`). That project rejects `@example.com` emails and aggressively rate-limits signups, so you often cannot create/log into an account in the VM. To visually demo screens that live behind login (e.g. the first-login onboarding modal in `App.tsx`), temporarily force the modal `visible` and pass `seedAppData.cardSearchCatalog` as a fallback catalog, capture the artifact, then revert the temporary change before committing.
- The app renders seed data locally (`src/data/seed.ts`) immediately after a session exists, before cloud sync completes, so UI work does not require a fully working backend.
