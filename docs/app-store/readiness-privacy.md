# Auth, privacy and submission readiness

**Decision: NOT READY for App Store submission or real-user distribution.**
This is a source/local acceptance record, not a signed-native, legal or hosted
certification. No hosted user was created, no production setting changed, no
publication/submission performed, and no provider request purchased for this audit.

## Changes and verified evidence

- `AppController`: an expired/signed-out session now clears the persisted personal
  onboarding draft; previously only explicit logout cleared it. A name-update
  refresh completing after logout can no longer restore the previous account's
  private data. Both regressions were observed failing before the fixes.
- Source privacy manifest now includes **Product Personalization** alongside App
  Functionality for credit information, entered financial information and other
  user content. These inputs customize card plans/recommendations, matching
  Apple's definition. The new manifest regression failed before the change.
- Expanded consent tests exercise Cancel, Use basic reply and Agree and send for
  Home, card detail and REVO quick prompts; composer tests cover these choices,
  per-message permission, malformed/unavailable disclosure and account change.
  Source search found all UI sends funnel through `sendRevoMessage`; Home's
  dynamic purchase-guide prompt uses the same gate. This is not native testing.
- `scripts/auth_privacy_smoke.py` loads only local configuration internally,
  rejects non-loopback Auth/API destinations, creates its own disposable account
  and deletes it. It never prints account addresses, passwords or tokens.

### Execution record

| Check | Actual result |
| --- | --- |
| `make check` | PASS: formatting, analysis, **139 Flutter tests**, sqlc vet, Go tests and Go vet (concurrent product-agent tests included) |
| Targeted account privacy + chat consent tests | PASS: 18 tests |
| `python3 -m unittest discover -s scripts -p test_privacy_manifest.py` | PASS: one test including three financial/content-purpose subcases |
| `go test ./internal/httpapi ./internal/chat` | PASS; both authenticated/public consent routes covered by spy-provider tests |
| `make database-test` | PASS: disposable migrations through 25, runtime isolation, account lifecycle, immutable snapshots and restore |
| `python3 scripts/auth_privacy_smoke.py` | PASS: signup, login, local logout/relogin, delivered **local Mailpit** recovery email, password change/relogin, wallet export, deletion and denied old-token access/login |
| Signup confirmation email | NOT TESTED live: local `enable_confirmations=false`; widget test covers confirmation-required signup, not delivery |
| Native callback structure | PASS in local recovery email/HTTP redirect: `com.revocred.app://auth-callback/?recovery=true` and recovery fragment; Info.plist registers `com.revocred.app` |
| Native callback execution | UNTESTED: no signed iPhone/iPad app, cold/warm launch, native PKCE or TestFlight run |
| Browser smoke | PARTIAL/FAIL at recovery screen: sign-in (including rejected wrong password), export, logout and email request completed. Served shared-preview build sends recovery to its `trycloudflare.com` origin while script starts at localhost:8083. Mailpit inspection confirmed this origin mismatch; browser PKCE completion/deletion must be rerun with matching build/callback origin. This run is not an end-to-end pass. Disposable account cleanup ran. |

The browser attempt first needed `uv run --with playwright`, then a non-Snap
browser (`CHROMIUM_PATH=$HOME/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome`)
because Snap cannot access the Hermes hidden scratch profile. Do not restart
other workers' shared preview to hide this acceptance gap.

## Inspected data flows and dependency boundary

| Source/data | Recipient/use | Declaration |
| --- | --- | --- |
| Email/password/session; optional display name/notification choice in signup metadata (`api_app_repository.dart`) | Supabase Auth for credentials/session; RevoCred profile for display name | Email, name, user ID linked; functionality. No card numbers/bank credentials needed. Notification choice is not proof of a deployed marketing campaign. |
| Credit band, life stage, goals, entered monthly spend, wallet/custom card terms and questionnaire (`app_models.dart`, API onboarding/store) | RevoCred Go API/PostgreSQL for saved plans and deterministic recommendations | Credit info, other financial info, other user content linked; functionality and personalization. Life stage is a broad questionnaire preference, not verified birth date. |
| Guest questionnaire | API for transient plan; device draft for up to 24 hours | No account records created by guest preview. Do not claim processors never retain traffic until hosting logs are verified. |
| Chat + context (`internal/chat/context.go`, `disclosure.go`, provider) | RevoCred stores signed-in chat. Only affirmative per-message consent enables configured OpenAI production service; OpenCode/DeepSeek is developer testing, not production policy | Other user content and financial/profile context remain linked. No promise of zero retention. Context includes first name, life stage, credit band, spend, wallet terms, strategy, ranking and up to eight recent messages. |
| Optional model-directed web tools (`docs/revo-web-lookup.md`) | DuckDuckGo public-topic queries and public HTTPS sources/readable PDFs | Included in v3 sharing notice. Tool instructions minimize personal information and block clear sensitive identifiers; **not a guarantee** that generated queries cannot reveal private details. Search/source services receive request metadata. Sources cannot change deterministic scores/rankings. |
| Affiliate redirects (`internal/affiliate`, offers endpoints) | Aggregate offer/day/screen counters, then external issuer/partner site | Product interaction, unlinked analytics in inspected application. No user ID, cookie/IP/device ID in affiliate counter records. External site/hosting logs require separate verification. |
| Client errors (`operations.go`, `reportClientError`) | Authenticated request containing only flutter/platform category; aggregate metrics | Other diagnostics, unlinked in source aggregate counters; no client message/stack trace. Hosting/Auth access logs not yet verified. |
| Device storage (`onboarding_draft_store.dart`, Supabase Flutter, shared_preferences) | Auth session, appearance setting, short-lived personal draft | On-device storage is not itself off-device collection. Export/PDF/clipboard copies intentionally made by user remain outside account deletion. |

Direct client dependencies inspected: Supabase Flutter, http, shared_preferences,
printing/pdf, url_launcher, Riverpod/go_router and web; no analytics/ad tracking,
IAP, bank-link or social-login SDK in the app's pubspec. Locked plugin sources
include app_links 7.2.1, shared_preferences_foundation 2.5.6 and url_launcher_ios
6.4.1. Their source manifests exist; shared_preferences declares wrapper reason
`1C8F.1`. Runner declares own UserDefaults reason `CA92.1`, tracking false and no
tracking domains. Printing has no source manifest found in this bounded check;
that is **not proof of noncompliance or proof of no required API use**. Xcode must
inspect the actual linked archive, Flutter engine/frameworks and every SDK.
`ITSAppUsesNonExemptEncryption=false` is source-only standard-HTTPS declaration.

Account deletion reauthenticates with current password; API requires a recent
sign-in (five minutes); backend-only `revocred.delete_account` removes the Auth
user and cascading live application records. Local smoke confirmed user/API
access denied afterwards and password login rejected; database integration tests
cover cascades. App logout/session events clear private in-memory state and drafts.
Session clearing in Flutter tests is not native Keychain/backup inspection.

## Privacy answers (draft, not submitted)

**Data collected: Yes. Tracking: No for inspected source, pending actual hosted
processor/partner confirmation.** Do not select "Data Not Collected."

| App Store Connect data type | Linked? | Purposes supported by source |
| --- | --- | --- |
| Contact Info / Name | Yes | App Functionality |
| Contact Info / Email Address | Yes | App Functionality |
| Identifiers / User ID | Yes | App Functionality |
| Financial Info / Credit Info (self-entered band, not credit bureau report) | Yes | App Functionality, Product Personalization |
| Financial Info / Other Financial Info (entered budgets/card terms) | Yes | App Functionality, Product Personalization |
| User Content / Other User Content (questionnaire/preferences/chat) | Yes | App Functionality, Product Personalization |
| Usage Data / Product Interaction (aggregate redirects) | No in application records | Analytics |
| Diagnostics / Other Diagnostic Data (aggregate categories) | No in application counters | App Functionality |

Do not claim payment card numbers, precise location, contacts, microphone, photos,
health, IDFA, purchases or social features from this feature set. Revisit answers
for actual hosting/Auth/IP/security logs, SMTP/support providers, third-party AI
retention/training/data use and commercial agreements. Optional AI is primary
functionality, not an exemption from privacy disclosure. Apple's definition of
collection includes third-party retention beyond real-time request servicing.

## Owner-only blockers and exact evidence needed

1. **Legal identity/jurisdiction/seller:** owner-approved operator entity/name,
   service address/jurisdiction, seller/enrollment eligibility for sensitive
   financial information, controller/contact and territory/trader details. A
   GitHub username or workspace label is not legal identity.
2. **Support/policy publication:** owner selects working contact mailbox and
   stable public HTTPS policy/support URLs, approves drafts below, publishes and
   verifies anonymously; then link them inside app and Connect. None known live.
3. **Retention/rights:** owner supplies actual database lifespan, backup/PITR
   expiration and deletion/recovery handling, Auth and SMTP logs, API/CDN logs,
   support ticket retention, geography/transfers and applicable rights handling.
   Source record caps are not a time-based retention policy.
4. **Hosted backend unavailable:** parent discovery reports Supabase project
   `jylwvumrzgihfndpurvq` INACTIVE, backup list null/PITR disabled (WALG flag is
   not recovery proof), linked Railway production has no services, and
   `revocred.app`, `api.revocred.app` and Supabase host DNS unresolved. No hosted
   availability, live privacy policy, working reviewer access or recovery proof.
   Do not resume/recreate/purchase hosting as part of this audit.
5. **Auth/email:** verify deployed SMTP/secure-email-change/password policies,
   email confirmation and resend, update-email double confirmation, recovery,
   expiry and deletion with disposable accounts on native cold/warm launch.
   Register both the base callback and recovery query variant with exact intended
   Supabase allowlist behavior; do not rely on local broad glob as hosted proof.
6. **AI controls/safety:** owner verifies actual OpenAI project/model/endpoint,
   retention/training controls, subprocessors, web-tool availability and safe
   outputs/support escalation. Native Cancel/Basic/Agree for all entry points
   must match source tests. Do not enable developer testing service in production.
7. **Signed artifact:** native acceptance, aggregate SDK manifest/privacy report,
   encryption, entitlement verification and accessibility/device tests still
   required. Linux/static tests cannot complete this.
8. **Review materials:** confirmed dedicated review account, separate disposable
   deletion account, approved financial/catalog/artwork/commercial facts and
   screenshots of the actual build. Parent/product agents own product claims;
   existing educational legal copy must align with current conditional credits.

## Draft submission materials and authoritative references

- [Privacy policy and support draft](policy-support-draft.md)
- [Store description and reviewer instructions draft](submission-draft.md)
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
  — current retrieved definition of collection, linked data, purposes and required
  public privacy URL informed this record.
- [Apple User Privacy and Data Use](https://developer.apple.com/app-store/user-privacy-and-data-use/)
  — SDK aggregation and tracking definition.
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
  and [account deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
  — owner must recheck exact current submission requirements before release.
