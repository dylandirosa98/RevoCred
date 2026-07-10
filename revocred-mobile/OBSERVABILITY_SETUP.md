# Observability Setup (Analytics + Crash Monitoring)

This app now includes:

- **PostHog** for product analytics events
- **Sentry** for error/crash monitoring

Both are optional in code paths. If keys are missing, the app still runs.

## 1) Add environment variables

Create or update `.env` in `revocred-mobile`:

```bash
cp .env.example .env
```

Set:

- `EXPO_PUBLIC_POSTHOG_API_KEY`
- `EXPO_PUBLIC_POSTHOG_HOST` (default: `https://us.i.posthog.com`)
- `EXPO_PUBLIC_SENTRY_DSN`

## 2) Events instrumented

PostHog events currently tracked:

- `app_loaded`
- `screen_viewed`
- `tab_viewed`
- `auth.bootstrap.completed`
- `auth.sign_in.succeeded`, `auth.sign_in.failed`
- `auth.sign_up.succeeded`, `auth.sign_up.failed`, `auth.sign_up.pending_confirmation`
- `auth.sign_out`
- `revo.prompt.submitted`, `revo.prompt.failed`
- `wallet.card_added`, `wallet.card_add_failed`
- `app.reset_demo_data`, `app.reset_demo_data_failed`
- `analytics.refresh.succeeded`, `analytics.refresh.failed`
- `app_error`

## 3) Sentry error capture

Handled exceptions in core auth/data actions are sent to Sentry via:

- `captureError(error, context, extras)`

Unhandled runtime crashes are handled by Sentry SDK.

## 4) Verify in development

1. Launch app
2. Login/logout, send REVO prompt, add card
3. Check PostHog for event stream
4. Trigger an error case and verify Sentry event appears

## Notes

- Keep DSN/API keys in env variables only.
- Do not commit private DSN/project tokens if your policy requires redaction.
