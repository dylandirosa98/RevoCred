# REVO AI subscription (App Store + RevenueCat)

REVO AI is a $10/month auto-renewable subscription sold through Apple In-App
Purchase, with RevenueCat in between. Subscribers get 60 AI answers a day
(`CHAT_DAILY_AI_LIMIT`); signed-in free members get 3
(`CHAT_FREE_DAILY_AI_LIMIT`); guests get built-in answers only.

**Status: built, switched off.** Nothing is sold until all of these exist:
the client's Apple Developer account with the Paid Apps agreement, the App Store
product, a RevenueCat project, the API variables below, and an iOS build with
the RevenueCat public key. Until then the webhook answers 404, the API reports
`purchases_enabled: false`, and the app shows the free limit without a purchase
button.

## How it works

| Piece | Behaviour |
| --- | --- |
| App (iOS only) | `purchases_flutter` runs only when the build has `REVENUECAT_IOS_API_KEY`, on iOS, with real sign-in. The RevenueCat app user id is the **Supabase user id**: RevenueCat is configured on sign-in, switched with `logIn` on account change and `logOut` on sign-out. Purchases are refused while no account is identified, so anonymous RevenueCat ids never buy. Web, tests and builds without the key never configure it. |
| Paywall | Opens when a free member hits `chat_daily_limit` (only where purchases work) and from Profile › REVO AI plan. The price comes from the App Store product; the title falls back to "$10" while no product has loaded, and subscribing is disabled. It has Restore Purchases, Apple's renewal terms, and Terms of Use / Privacy Policy links (`REVOCRED_TERMS_URL`, `REVOCRED_PRIVACY_URL`). Subscribers see usage, renewal date and **Manage subscription** (opens `https://apps.apple.com/account/subscriptions`). |
| Webhook | `POST /v1/webhooks/revenuecat`, authenticated by the exact `Authorization` header in `REVENUECAT_WEBHOOK_AUTH` (constant-time compare). Unset means 404. |
| Database | Migration `000030_revenuecat_entitlements.sql`. The runtime role still cannot write `revocred.ai_entitlements`; it can only call `revocred.apply_revenuecat_entitlement(...)` (SECURITY DEFINER), which writes `source='revenuecat'` rows for existing accounts, never touches `manual` rows, refuses open-ended or more-than-13-month expiries, and ignores replays (event id) and events with equal or older timestamps than the stored one. Event ids are kept 90 days and deleted with the account. |
| Plan API | `GET /v1/ai-plan` returns `plan` (`free`/`subscriber`), `source`, `used`, `limit`, `remaining`, `expires_at`, `next_reset_at`, `ai_available`, `purchases_enabled`. `POST /v1/ai-plan/refresh` re-reads the subscriber from RevenueCat first (only with `REVENUECAT_SECRET_API_KEY`); the app calls it after a purchase or restore so access unlocks without waiting for the webhook. |

Event handling (entitlement `revo_ai` must be in the event's `entitlement_ids`,
and `app_user_id` must be a UUID; anything else answers 200 and is ignored):

| Event | Effect |
| --- | --- |
| `INITIAL_PURCHASE`, `RENEWAL`, `UNCANCELLATION`, `PRODUCT_CHANGE`, `SUBSCRIPTION_EXTENDED`, `TEMPORARY_ENTITLEMENT_GRANT` | Access until the event's `expiration_at_ms` |
| `CANCELLATION` | Access kept until `expiration_at_ms` (auto-renew off). Refund revocation follows the reported expiry / EXPIRATION event |
| `EXPIRATION` | Access ends (at the reported expiry, never later than the event) |
| `TRANSFER` | Previous owners lose access at once. New owners are re-read from the RevenueCat API when `REVENUECAT_SECRET_API_KEY` is set; without that key the API returns 503 before changing either account so RevenueCat retries |
| `SANDBOX` environment | Ignored unless `REVENUECAT_ALLOW_SANDBOX=true` (default `true` outside production, `false` in production) |
| `TEST`, `BILLING_ISSUE`, `SUBSCRIPTION_PAUSED`, `NON_RENEWING_PURCHASE`, others | 200, no change |

Manual grants (`source='manual'`, inserted as `postgres` for testers) always win:
RevenueCat events never change or expire them. To move a tester onto a paid
plan, delete their manual row first, then have them Restore Purchases.

## Setup, in order

### 1. Apple: agreements and the product

1. **Paid Apps agreement.** App Store Connect › Business (Agreements, Tax, and
   Banking): the Account Holder accepts the Paid Apps agreement and completes
   bank and tax forms. Products do not load, even in sandbox, until it is
   **Active**.
2. **In-App Purchase capability.** Certificates, Identifiers & Profiles ›
   `com.revocred.app`: In-App Purchase is on by default for explicit App IDs;
   confirm it. No entitlement file change is needed.
3. **Subscription group.** App Store Connect › RevoCred › Subscriptions ›
   create group **REVO AI** (localized display name "REVO AI").
4. **Product.** In that group create an auto-renewable subscription:
   - Reference name: `REVO AI Monthly`
   - Product ID: **`com.revocred.app.revo_ai_monthly`** (permanent, cannot be reused)
   - Duration: 1 month; price: **$10.00 (USD)**, let Apple derive other storefronts
   - Localization: display name "REVO AI", description
     "60 AI answers a day about your cards and money."
   - Family Sharing: off
   - Review information: a screenshot of the paywall sheet and the review note below
5. **In-App Purchase key** (for RevenueCat, StoreKit 2): Users and Access ›
   Integrations › In-App Purchase › generate a key; keep the `.p8`, key ID and
   issuer ID for RevenueCat. Do not commit it.
6. The first subscription must be submitted **with an app version**: on the
   version page, add it under "In-App Purchases and Subscriptions".

### 2. RevenueCat

1. Create project **RevoCred**; add an **App Store** app with bundle ID
   `com.revocred.app`; upload the In-App Purchase key (`.p8`, key ID, issuer ID).
   Optionally add the App Store Connect API key so RevenueCat can import products.
2. Optionally point App Store Server Notifications (V2) for production and
   sandbox at the URL RevenueCat shows under the app's settings, for faster
   renewals and refunds.
3. **Product:** add `com.revocred.app.revo_ai_monthly`.
4. **Entitlement:** identifier **`revo_ai`**; attach the product.
5. **Offering:** identifier `default`, mark it **Current**; one package
   **Monthly** (`$rc_monthly`) with the product. The app buys the current
   offering's monthly package.
6. **Webhook:** Integrations › Webhooks › add
   - URL: `https://api.revocred.com/v1/webhooks/revenuecat`
   - Authorization header value: `Bearer <openssl rand -hex 32>`; the same exact
     string goes into `REVENUECAT_WEBHOOK_AUTH`
   - Environment: production and sandbox (the API filters sandbox itself);
     all event types
7. **Keys:** Project settings › API keys:
   - the App Store **public** key (`appl_…`) goes into the iOS build as
     `REVENUECAT_IOS_API_KEY`. It is public by design.
   - create a **secret** key, API version **V1** (`sk_…`), for
     `REVENUECAT_SECRET_API_KEY`. Server only; never in the app.
8. **Restore behaviour:** keep the default "Transfer to new App User ID". With
   the secret key set, a restore on a different RevoCred account moves access
   immediately (TRANSFER revokes the old account, the API re-reads the new one).

### 3. API (Railway)

1. Back up, then apply the migration once with the **owner** connection, as in
   [railway.md](../railway.md#every-release). Production migrations are applied
   with `supabase db query` as `postgres`: run the Up section of
   `revocred-api/migrations/000030_revenuecat_entitlements.sql` and record
   version 30 in `goose_db_version`, as for earlier migrations.
2. Railway › Shared Variables (production), seal the secrets:

   | Name | Value |
   | --- | --- |
   | `REVENUECAT_WEBHOOK_AUTH` | Exact header value from step 2.6 (32+ characters) |
   | `REVENUECAT_SECRET_API_KEY` | RevenueCat V1 secret key `sk_…` (required for transfers) |
   | `REVENUECAT_ENTITLEMENT_ID` | `revo_ai` (default; may stay unset) |
   | `REVENUECAT_ALLOW_SANDBOX` | `true` through TestFlight **and App Review** (reviewers buy in sandbox); see below |

3. Redeploy and check: `curl -i -X POST https://api.revocred.com/v1/webhooks/revenuecat`
   returns **401** (not 404). Then RevenueCat › Webhooks › **Send test event**
   should show 200 with `"status":"ignored"`.

Rollback: unset `REVENUECAT_WEBHOOK_AUTH` and redeploy. The webhook returns 404
and the app hides the purchase button (`purchases_enabled: false`); existing
subscribers keep access until their stored `expires_at`.

### 4. iOS build

Add the public key to the gitignored release config (`.env.ios.json`, see
[build.md](build.md)): `"REVENUECAT_IOS_API_KEY": "appl_…"`. The key is
optional; `scripts/ios_release.py` accepts only `appl_` values and rejects
secret keys. Build with `make ios-release IOS_BUILD_NUMBER=<n>`.

### 5. Legal and App Store metadata

- **Terms of Use** must cover the subscription: price and period, automatic
  renewal, cancellation in Apple ID settings, refunds handled by Apple, and what
  REVO AI includes (60 AI answers a day, card and money questions only). Link the
  Terms of Use in the App Store description or the custom EULA field (3.1.2
  requires it in metadata as well as in the app).
- **Privacy Policy** must name RevenueCat as a processor (account id, purchase
  history, device and store transaction data).
- **App Privacy** answers: add Purchases › Purchase History, linked to the
  user, used for App Functionality.
- Update the "no in-app purchases" statements in
  [submission-draft.md](submission-draft.md) and
  [../ios-review-readiness.md](../ios-review-readiness.md) when this ships.

## App Review (Guideline 3.1.2)

What the paywall already shows, as 3.1.2(a) and the Schedule 2 disclosure
require: subscription name (REVO AI) and length (monthly); price from the
store, per month; what the member gets; that payment is charged to the Apple
ID, renews automatically unless cancelled at least 24 hours before the period
ends, and how to manage/cancel in Settings; **Restore Purchases**; functional
**Terms of Use** and **Privacy Policy** links. The subscription gives ongoing
value (a daily allowance), and free members keep basic answers and 3 AI answers
a day, so nothing previously free is taken away.

Keep `REVENUECAT_ALLOW_SANDBOX=true` while the build is in review: reviewers
purchase with sandbox accounts against the production API, and a purchase that
does not unlock gets rejected under 2.1. Sandbox purchases can only come from
TestFlight/Xcode/review builds, never from the App Store build.

Suggested review note:

> REVO AI is an optional auto-renewable subscription
> (com.revocred.app.revo_ai_monthly, 1 month). Free members get 3 AI answers a
> day; REVO AI raises this to 60. Sign in with the demo account below, then
> open Profile › REVO AI plan to see the subscription screen, or send four
> questions in the REVO tab to reach the free daily limit, which opens it. The
> screen includes the price, renewal terms, Restore Purchases, Terms of Use and
> Privacy Policy. Manage subscription opens Apple's subscription settings.
> Demo account: <email> / <password>.

## Testing in sandbox and TestFlight

1. App Store Connect › Users and Access › Sandbox › create a tester. On the
   iPhone: Settings › App Store › Sandbox Account › sign in. The renewal rate
   can be set per tester there; by default a sandbox month lasts minutes.
2. Use a staging or production API with `REVENUECAT_ALLOW_SANDBOX=true` and the
   migration applied. TestFlight builds also buy in sandbox.
3. Checklist:
   - Profile shows "REVO AI plan · Free · n of 3"; the price on the paywall
     matches App Store Connect.
   - Buy: the sheet says "REVO AI is active" within seconds; Profile shows
     "REVO AI · n of 60" and Manage subscription. In the database:
     `SELECT source, expires_at, revenuecat_event_at FROM revocred.ai_entitlements WHERE user_id='<id>';`
     shows `revenuecat` and a near expiry.
   - Wait for renewals: `expires_at` moves forward with each RENEWAL.
   - Cancel in Settings › Apple ID › Subscriptions (sandbox): access stays until
     expiry, then EXPIRATION returns the account to Free.
   - Sign out, sign in as a second RevoCred account on the same Apple ID, tap
     Restore Purchases: the second account gets access and the first loses it
     (TRANSFER; needs the secret key).
   - A manual tester row is never changed by any of the above.
   - Replays: RevenueCat › Customer › event › Resend; the API logs `duplicate`.
4. Local smoke without RevenueCat (any machine):

   ```sh
   curl -i -X POST http://127.0.0.1:8082/v1/webhooks/revenuecat \
     -H "Authorization: $REVENUECAT_WEBHOOK_AUTH" -H 'Content-Type: application/json' \
     -d '{"api_version":"1.0","event":{"id":"local-1","type":"INITIAL_PURCHASE",
          "app_user_id":"<supabase user id>","event_timestamp_ms":<now ms>,
          "expiration_at_ms":<now ms + 3600000>,"entitlement_ids":["revo_ai"],
          "product_id":"com.revocred.app.revo_ai_monthly","environment":"SANDBOX"}}'
   ```

## Known limits

- Billing grace periods are not extended from `BILLING_ISSUE`; access ends at
  the paid period's expiry until RevenueCat sends RENEWAL.
- The benefit copy says "60 a day vs 3"; change it if the limit variables change.
- The web build now ships RevenueCat's ~1 MB web bundle as a same-origin asset
  (the plugin registers on web); it is never configured there and makes no
  RevenueCat requests.

Refreshes use the request start time as their ordering watermark; TRANSFER
refreshes use the original event time and an account-specific idempotency key.
Equal or older timestamps cannot replace stored state. Disallowed sandbox
lookups leave stored production access unchanged.

References: [RevenueCat webhooks](https://www.revenuecat.com/docs/integrations/webhooks),
[event fields](https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields),
[Flutter SDK](https://www.revenuecat.com/docs/getting-started/installation/flutter),
and [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/#subscriptions).

## Verification before activation

Local checks cover API event mapping, authentication, sandbox filtering, plan
reads, ordering and replay guards, manual-grant preservation, runtime database
permissions, paywall states and release configuration. The mock web build
compiles with purchases disabled. These checks do not verify an Apple or
RevenueCat account: native iOS compilation/signing, product availability and
localized pricing, actual purchase/renewal/cancellation/refund/restore/transfer
delivery, TestFlight and App Review must still be exercised once those accounts
exist, following the checklist above.
