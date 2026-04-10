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

...with row-level security so each user can only access their own data.

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

## Notes

- Never expose the `service_role` key in mobile code.
- The app only uses the public anon key.
- REVO replies are generated server-side by `supabase/functions/revo-chat`.
