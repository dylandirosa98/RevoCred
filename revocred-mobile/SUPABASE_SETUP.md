# Supabase Setup

Follow these steps once to connect the app to your Supabase project.

## 1) Configure environment variables

Create a `.env` file in `revocred-mobile` using `.env.example`:

```bash
cp .env.example .env
```

Then set:

- `EXPO_PUBLIC_SUPABASE_URL`
- `EXPO_PUBLIC_SUPABASE_ANON_KEY`

## 2) Create tables and policies

In Supabase dashboard:

1. Open **SQL Editor**
2. Paste the full contents of `supabase/schema.sql`
3. Run the script

This creates:

- `profiles`
- `wallet_cards`
- `revo_messages`
- `revo_usage_logs`
- `user_preferences`
- `card_catalog`

...with row-level security so each user can only access their own data.

If you've already run an older schema, re-run the latest `supabase/schema.sql` so newer
tables/policies (including `revo_usage_logs`, `user_preferences`, `card_catalog`) are added.

## 3) Run app

```bash
npm install
npm run start
```

On first launch:

- Create account or log in from the in-app auth screen
- Seed profile/cards/messages are bootstrapped automatically for that user

## 4) Deploy REVO AI function

From `revocred-mobile`:

```bash
supabase functions deploy revo-chat --project-ref jylwvumrzgihfndpurvq
```

Set secrets (required):

```bash
supabase secrets set OPENAI_API_KEY=your-openai-key --project-ref jylwvumrzgihfndpurvq
```

Optional (if CLI is not already authenticated):

```bash
supabase login
```

Optional function tuning secrets:

```bash
supabase secrets set REVO_RATE_LIMIT_WINDOW_MIN=60 --project-ref jylwvumrzgihfndpurvq
supabase secrets set REVO_RATE_LIMIT_MAX_REQUESTS=20 --project-ref jylwvumrzgihfndpurvq
supabase secrets set REVO_MAX_PROMPT_CHARS=500 --project-ref jylwvumrzgihfndpurvq
supabase secrets set OPENAI_MODEL=gpt-4o-mini --project-ref jylwvumrzgihfndpurvq
```

## Notes

- Never expose the `service_role` key in mobile code.
- The app only uses the public anon key.
- REVO replies are generated server-side by `supabase/functions/revo-chat`.
- REVO now includes rate limiting, prompt guardrails, and usage logs for monitoring.
- Strategy card search will read from `card_catalog` when populated, and safely falls back to local seed data if this table is empty.

## Observability setup (analytics + crash monitoring)

The app now supports PostHog analytics and Sentry crash monitoring.

Add these to your local `.env` (optional in dev, recommended for launch):

- `EXPO_PUBLIC_POSTHOG_API_KEY`
- `EXPO_PUBLIC_POSTHOG_HOST` (defaults to `https://us.i.posthog.com`)
- `EXPO_PUBLIC_SENTRY_DSN`

If keys are not provided, the app keeps running with no-op tracking.
- Profile screen now includes a live analytics panel (24h summary) sourced from `revo_usage_logs`.
