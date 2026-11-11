# Public legal pages

`privacy-policy.md`, `terms-of-use.md` and `support.md` are the source of the
public pages Apple requires (Privacy Policy URL, Support URL, and the terms /
EULA link). They are drafts to be completed by the owner and reviewed by
counsel before App Review.

## Where they are served

The Go API serves them, so they work without anyone editing the marketing site:

| Page | URL |
| --- | --- |
| Privacy Policy | https://api.revocred.com/privacy |
| Terms of Use | https://api.revocred.com/terms |
| Support | https://api.revocred.com/support |
| Index | https://api.revocred.com/legal |

`/privacy-policy`, `/terms-of-use` and trailing-slash forms redirect (308) to
the canonical paths. The pages are plain HTML with one inline stylesheet, no
scripts, fonts, images or external requests. They need no sign-in, skip the
API's CORS origin check, and send `Cache-Control: public, max-age=300`, an
ETag, and strict security headers (CSP `default-src 'none'`, `nosniff`,
`X-Frame-Options: DENY`). Code: `revocred-api/internal/legal`.

They go live when `main` deploys to Railway. The Flutter app links to these
URLs by default (`REVOCRED_PRIVACY_URL`, `REVOCRED_TERMS_URL`,
`REVOCRED_SUPPORT_URL` override them).

## Editing

1. Edit the Markdown here. Supported: `#`–`###` headings, paragraphs, `- `
   bullets, pipe tables, `**bold**` and `[text](https://… | mailto:… | /path)`
   links. Everything else is shown as escaped text.
2. Run `make legal-sync` to copy the files into
   `revocred-api/internal/legal/content/` (Railway builds only from
   `revocred-api/`, so the API embeds its own copy). `make check` fails if the
   copies differ.
3. Commit and deploy the API.

## Owner placeholders to fill before submission

Search for `[[` to find each one. The API logs a warning at startup while any
remain, and the static export refuses to run.

| Placeholder | Used in | What to enter |
| --- | --- | --- |
| `[[COMPANY LEGAL NAME]]` | privacy, terms, support | The legal entity that is the App Store seller (must match the Apple Organization account) |
| `[[MAILING ADDRESS]]` | privacy, terms, support | A postal address for legal and privacy notices |
| `[[EFFECTIVE DATE]]` | privacy, terms | The date the final text takes effect, e.g. November 20, 2026 |
| `[[GOVERNING LAW STATE]]` | terms | The US state whose law governs the terms |
| `[[BACKUP RETENTION PERIOD]]` | privacy | How long Supabase database backups are kept on the current plan (for example "7 days"; check the Supabase project's backup settings, including point-in-time recovery) |
| `[[SUPPORT RESPONSE TIME]]` | support | A reply time you can keep, e.g. "two business days" |

Also set the matching app build defines: `REVOCRED_LEGAL_ENTITY`,
`REVOCRED_LEGAL_JURISDICTION`, `REVOCRED_LEGAL_EFFECTIVE_DATE`.

## Facts to confirm (written as true in the drafts)

- **`support@revocred.com` is unverified.** The owner is setting up this
  mailbox. Send a test message and reply from it before submission. It is the
  only contact address in the app and on all three pages.
- **Processors.** The privacy policy names: Supabase (Auth and Postgres),
  Railway (API hosting), Resend (Supabase Auth SMTP), OpenAI (AI answers and
  moderation), OpenCode (testing only), Brave Search (web search, not yet
  enabled), Apple and RevenueCat (subscriptions, not yet built), and "our email
  provider" for support mail (`revocred.com` MX points to Google). Code
  inspection found no other recipient of user data: OpenCard DB and issuer pages
  are only downloaded, Apply links open in the user's browser, and error reports
  carry categories only. If self-hosted SearXNG replaces Brave
  (`SEARCH_PROVIDER=searxng`), name it and its upstream engines in the policy.
- **OpenAI terms.** The policy states OpenAI's default API terms (no training on
  API data, up to 30 days abuse-monitoring retention). Re-check if the account
  has zero-data-retention or other terms.
- **REVO AI subscription.** The terms describe an Apple auto-renewing monthly
  subscription. Before launch, make sure the in-app paywall also shows the
  title, length, price and links to these terms and the privacy policy
  (Guideline 3.1.2).
- **Update emails.** The policy promises an unsubscribe link in any update
  email. No update emails are sent yet; keep that promise when they are.
- **US-only, 18+.** Set App Store availability to the United States and the
  age rating override to 18+ to match.

## Optional: host on revocred.com later

Export the same pages as a static site and copy them to the marketing host:

```sh
cd revocred-api && go run ./cmd/legalpages -out ../.local/public-pages
```

It is offline, refuses to run while placeholders remain (`-allow-placeholders`
exports a review copy), and writes `index.html`, `privacy/index.html`,
`terms/index.html` and `support/index.html`. `deploy/public-pages.nginx.conf`
serves that layout. After moving, set the new URLs in App Store Connect and the
app build defines; keep the API routes so older app builds keep working.
