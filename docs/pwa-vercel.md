# RevoCred PWA on Vercel

RevoCred's web app is hosted as a static Flutter Web Progressive Web App (PWA)
on Vercel (`revocred-pwa`), backed by the Go API on Railway
(`https://api.revocred.com`) and Supabase Auth + Postgres.

- **Primary domain:** `https://app.revocred.com`
- **Vercel preview/alias domain:** `https://revocred-pwa.vercel.app`
- **Vercel project:** `revocred-pwa` (`prj_tqUy6Od1wn50pLHOO7Spsq4Kpd5H`, team `dylans-projects-62ab0a08`)
- **Hosting config:** [`revocred_flutter/vercel.json`](../revocred_flutter/vercel.json)
- **Deploy script:** [`scripts/deploy_pwa_vercel.py`](../scripts/deploy_pwa_vercel.py)
- **CI workflow:** [`.github/workflows/deploy-pwa.yml`](../.github/workflows/deploy-pwa.yml)

---

## 1. DNS setup (`app.revocred.com`)

`app.revocred.com` is attached to the `revocred-pwa` Vercel project. Add the
following DNS record at the domain registrar (Google Domains / Squarespace DNS):

| Type | Host / Name | Target / Value |
| --- | --- | --- |
| `CNAME` | `app` | `f6a8789f3617c543.vercel-dns-017.com.` |

Once DNS propagates, Vercel automatically provisions TLS for
`https://app.revocred.com`.

---

## 2. Supabase Auth redirect URLs

In **Supabase Dashboard → Authentication → URL Configuration**, add both web
origins to **Redirect URLs**:

- `https://app.revocred.com/**`
- `https://revocred-pwa.vercel.app/**`

When `app.revocred.com` is live, set **Site URL** to `https://app.revocred.com`
and build with `REVOCRED_AUTH_REDIRECT_URL=https://app.revocred.com/`.

---

## 3. Railway API CORS

The Railway `api` service (`https://api.revocred.com`) must allow both browser
origins:

```text
CORS_ALLOWED_ORIGINS=https://app.revocred.com,https://revocred-pwa.vercel.app
```

---

## 4. Environment variables & GitHub Actions configuration

All client build defines are **public** values compiled into the Flutter web
bundle. Never place service-role keys, database URLs, or AI API keys in client
defines or `.env*` files committed to Git.

| Name | Required | Default / Example | Notes |
| --- | --- | --- | --- |
| `REVOCRED_USE_MOCKS` | Yes | `false` | Must always be `false` for hosted deploys |
| `REVOCRED_PRODUCTION` | Yes | `true` (launch) / `false` (pre-launch) | `true` enforces all 7 legal defines below |
| `REVOCRED_API_URL` | Yes | `https://api.revocred.com` | Public HTTPS API origin |
| `SUPABASE_URL` | Yes | `https://jylwvumrzgihfndpurvq.supabase.co` | Public Supabase project URL |
| `SUPABASE_ANON_KEY` | Yes | `sb_publishable_...` | Public publishable or anon key only |
| `REVOCRED_AUTH_REDIRECT_URL` | Yes | `https://app.revocred.com/` | Use `https://revocred-pwa.vercel.app/` before DNS cutover |
| `REVOCRED_LEGAL_ENTITY` | When `REVOCRED_PRODUCTION=true` | Owner legal name | No placeholders (`{{...}}` / `[[...]]`) |
| `REVOCRED_LEGAL_JURISDICTION` | When `REVOCRED_PRODUCTION=true` | Governing US state | Matches `docs/legal/terms-of-use.md` |
| `REVOCRED_LEGAL_EFFECTIVE_DATE` | When `REVOCRED_PRODUCTION=true` | `YYYY-MM-DD` or full date | Matches `docs/legal/` |
| `REVOCRED_SUPPORT_EMAIL` | Optional | `support@revocred.com` | Support contact displayed in Legal screen |
| `REVOCRED_PRIVACY_URL` | Optional | `https://api.revocred.com/privacy` | Public HTTPS privacy policy |
| `REVOCRED_TERMS_URL` | Optional | `https://api.revocred.com/terms` | Public HTTPS terms of use |
| `REVOCRED_SUPPORT_URL` | Optional | `https://api.revocred.com/support` | Public HTTPS support page |

### GitHub Actions (`.github/workflows/deploy-pwa.yml`)

1. Add repository **Secret**:
   - `VERCEL_TOKEN` (Vercel personal/team deploy token)
2. Add repository **Variables**:
   - `SUPABASE_URL`, `SUPABASE_ANON_KEY` (or store `SUPABASE_ANON_KEY` as a secret)
   - `REVOCRED_AUTH_REDIRECT_URL` (`https://app.revocred.com/` once DNS is live)
   - `REVOCRED_PRODUCTION` (`true` once legal defines are ready)
   - `REVOCRED_LEGAL_ENTITY`, `REVOCRED_LEGAL_JURISDICTION`, `REVOCRED_LEGAL_EFFECTIVE_DATE`
   - Optional: set `PWA_AUTO_DEPLOY=true` to auto-deploy on pushes to `main` (manual `workflow_dispatch` is always available).

---

## 5. Local build & deploy

Ensure `vercel` CLI is logged in (`vercel whoami`) and Flutter 3.44.9 is
installed at `~/.local/share/flutter/bin/flutter`.

```sh
# Validate configuration only
python3 scripts/deploy_pwa_vercel.py --env-file .env.prod-preview \
  --auth-redirect-url https://revocred-pwa.vercel.app/ --check

# Build & deploy live to https://revocred-pwa.vercel.app (pre-launch)
python3 scripts/deploy_pwa_vercel.py --env-file .env.prod-preview \
  --auth-redirect-url https://revocred-pwa.vercel.app/

# Full production deploy once DNS + legal defines are finalized
python3 scripts/deploy_pwa_vercel.py --env-file .env.pwa --production \
  --auth-redirect-url https://app.revocred.com/
```

The script runs `dart run tool/validate_build.dart`, builds with
`flutter build web --release --no-web-resources-cdn`, copies
`revocred_flutter/vercel.json` into `revocred_flutter/build/web/`, and deploys
that static output directory directly to Vercel.

---

## 6. Cache & service worker strategy

- `revocred_flutter/web/pwa_sw.js` is a minimal **network-only** service worker.
  It clears any legacy `flutter_service_worker.js` caches on activation and
  never caches app bundles in `CacheStorage`, preventing stale Flutter releases.
- `revocred_flutter/vercel.json` sends `Cache-Control: no-cache, no-store, must-revalidate`
  for HTML routes, `index.html`, `flutter_bootstrap.js`, `flutter.js`,
  `main.dart.js`, `pwa_sw.js`, `version.json`, and `manifest.json`, mirroring
  `revocred_flutter/nginx.conf`.
- `/reset-cache.html` remains available as an emergency cache-clearing escape
  hatch (`Clear-Site-Data: "cache"`).

---

## 7. Post-deploy verification

```sh
# 1. SPA root & security/cache headers
curl -sSI https://revocred-pwa.vercel.app/

# 2. Web app manifest
curl -fsS https://revocred-pwa.vercel.app/manifest.json

# 3. SPA deep-link rewrite
curl -sSI https://revocred-pwa.vercel.app/welcome

# 4. API CORS preflight from the deployed origin
curl -sSI -X OPTIONS https://api.revocred.com/v1/public/chat-disclosure \
  -H 'Origin: https://revocred-pwa.vercel.app' \
  -H 'Access-Control-Request-Method: GET'
```
