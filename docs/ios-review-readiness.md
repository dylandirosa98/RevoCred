# iOS review readiness — 2026-10-19

## 1. Executive summary

- RevoCred is a Flutter/iOS 13+ credit-card rewards planner backed by Go and
  Supabase. Core flows are questionnaire → plan, wallet management, and REVO
  explanations. Personal persistence requires an account; guest previews exist.
- **Not approved for production release yet.** A successful build is not a
  privacy, operational, physical-device, or Apple review certification.
- The first pass found missing third-party AI permission (5.1.2(i)); account-level
  consent (asked once per notice version, revocable in Profile) and server
  enforcement are now implemented locally. Native acceptance
  and the client's actual OpenAI data controls still need verification.
- Top risk: the in-app legal notice is explicitly unfinished; support ownership,
  public policy URL and deployed AI provider disclosures need operator input.
- Top risk: signed native launch, hosted auth callbacks and reviewer access are
  unverified, not demonstrated by browser or Flutter widget tests.
- Fast win: establish a repeatable release configuration/archive command.
- Fast win: provide an active reviewer account, clear steps, and live backend.
- Fast win: complete policy/support facts and align all privacy declarations.
- Baseline `make check` passed locally: formatting, analysis, 106 Flutter tests,
  sqlc vet, Go tests and Go vet. This does not execute an iOS binary.

### Local verification after release-tooling changes

- `make check`: latest pass includes 115 Flutter tests and Go tests/vetting,
  including nine new Flutter consent tests and Go consent/configuration tests.
- Python script suite: 32 tests passed (15 release-related tests).
- `make database-test`: passed migrations through 23, runtime isolation,
  lifecycle, immutable snapshots and backup restore in disposable PostgreSQL.
- `go test -race ./...`: passed.
- Initial `make security-check` found 12 reachable vulnerabilities in Go 1.26.6
  and `golang.org/x/text` 0.39.0. Updated Go module/Docker builder to 1.26.9 and
  x/text to 0.41.0, then tidied dependencies. The repeat scan reported
  **No vulnerabilities found**. Redeploy/rebuild the backend to apply these
  changes; the hosted binary was not modified or verified.
- iOS workflow YAML parsed locally; **macOS CI, signing, archive validation,
  native device tests, TestFlight upload and Apple review were not executed**.

### Sources and skill provenance

Applied `github/awesome-copilot`'s `apple-appstore-reviewer` skill after reading
its source. Discovery reported ~11.2K installs; GitHub API reported ~40.2K stars
for the community-contributed repository. Installed for OpenCode at user scope,
not as a project dependency. CLI assessments reported Gen Safe, Socket 0 alerts,
Snyk Low Risk; these are third-party signals, not a security guarantee or Apple
endorsement. No Apple-certified skill was found or claimed.

Authoritative guidance consulted on 2026-10-19:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
  — 1.5, 2.1, 2.2, 2.3, 5.1.1 and 5.1.2.
- [Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
  — uploads require Xcode 26+/iOS 26 SDK since April 28, 2026; deployment target
  iOS 13+ since September 9, 2026. Recheck before each submission.
- [Skill source](https://github.com/github/awesome-copilot/tree/main/skills/apple-appstore-reviewer).

## 2. Risk register

### Confirmed production/testing split

The operator clarified that **production uses OpenAI**. OpenCode Go/DeepSeek is
the developer's personal testing setup, not the production provider. Production
configuration now requires explicit OpenAI credentials, model and exact endpoint
and refuses legacy testing fallbacks. The installed app receives no provider key.
No hosted settings were changed and no live AI requests or key inspection were
used for this patch. The actual enabled OpenAI model and project data controls
remain deployment acceptance items.

Consent uses the actual backend recipient, model and search provider, not a
hardcoded build-time label. A signed-in member is asked once; the server stores
the agreed notice version per account (`chat_ai_consents`) and the member can
turn AI answers off in Profile. Any change to the endpoint, model, search
provider or notice wording changes the version, so stale permission falls back
to basic answers and the app asks again. Guests agree once per app session and
send the version with each message. "Basic answer instead" saves nothing;
cancel sends nothing. Permission never crosses accounts: the client reloads it
when the signed-in account changes, and an account change while the sheet is
open blocks sending. When the app sends an explicit version the backend refuses
a stale one (409 `ai_consent_changed`) rather than downgrading silently.
Every saved reply records whether it used AI (`mode`), and external-AI replies
are capped per user per day (`CHAT_DAILY_AI_LIMIT`). Members can rate or report
any saved answer and clear their conversation. Flutter regression tests cover
all entry points, ask-once, re-prompting on a changed notice, Profile revoke,
basic/cancel, failed notices and account changes; Go tests cover stored
consent, stale versions, the cap, streaming and disconnects.
Repeat these checks on the archived app and real production backend. Do not
mistake a request-level permission assertion for a cryptographic proof of user
interaction or a durable consent audit log.

**Legal remediation addressed in source:** Privacy & Terms now uses required production legal defines, public HTTPS policy/terms links and a support mailto. Policy and terms drafts are in `docs/legal/`; affiliate language is consistent and email marketing is declared. Owner completion, legal review, hosting and signed-build verification remain release gates.

### Permissions & entitlements

`Runner/Info.plist` registers the auth scheme, declares standard encryption and
does not declare broad camera/location/tracking/background permissions. No need
to add prompts for features that do not exist. The app privacy manifest includes
UserDefaults reason CA92.1. Aggregate SDK manifests, signed entitlements and
encryption answers remain **unverified** until archive inspection. Verify the
exported bundle and Xcode privacy report, not only source plist syntax.

### Monetization (IAP/subscriptions)

No purchase dependency is present in `pubspec.yaml`. Existing Apply actions
link to issuer/affiliate credit-card pages, not a purchase of digital app
features. A restore-purchases button is not warranted by the inspected feature
set. Verify the actual live destinations and disclosures; reassess IAP rules
if paid digital features are introduced. Do not claim partner approval/revenue
integration that is not deployed.

### Account & authentication

The repository uses email/password authentication; no social sign-in was found,
so this inspection does not establish a Sign in with Apple requirement.
In-app account deletion exists with password reauthentication. Verify it removes
the hosted auth user and live application data, clears local private data and
does not allow the deleted user to sign back in. Test emailed confirmation,
password recovery and email changes with the exact native callback in the
Supabase allowlist, with the app both running and terminated. Provide a separate
confirmed review account; don't put its credentials in Git.

### Content / UGC / external links

REVO is private AI chat, not an observed public user-to-user feed; do not invent
social blocking/reporting features or apply every social moderation rule blindly.
Apple's current 1.2 text includes AI content creation apps: evaluate REVO safety,
offensive-output reporting and handling with the actual deployed model. This
is not established by a deterministic recommendation engine. Inspect real outputs
and escalation/support paths before submission. Verify issuer data, claims,
affiliate destinations and artwork usage rights. Keep the educational estimate
disclaimer; it does not itself certify regulatory compliance. Have the operator
confirm seller/legal-entity suitability for sensitive financial information
under 5.1.1(ix); account enrollment details are unverified.

### Technical stability & performance

Local checks pass, but signing, iOS plugin linking, PDF share sheets, native
deep links, IPv6-only connectivity, offline handling and iPad behavior are not
proven. Use Xcode 26+ and iOS 26+ SDK, then validate the signed archive and test
on actual supported devices. Record device/OS/build/date/results. The unsigned
macOS CI job is a compile gate, not a TestFlight or device acceptance result.

### UX & reviewability

Guest preview, questionnaire, saved wallet and REVO provide inspectable value.
App Store Connect listing/screenshots/age-rating answers are not available in
this repo and remain unverified. Use fictional data in screenshots, avoid
approval/reward guarantees, and give reviewers an active account and the exact
path to settings/deletion. Don't ship a mock-only build as the live product.

## 4. Reviewer experience checklist

- [ ] Install and launch signed release on iPhone and iPad — unverified.
- [x] First-run/core flows covered by local Flutter tests — native unverified.
- [x] Permission/decline/cancel covered by local tests — native unverified.
- [ ] Real hosted questionnaire → plan → wallet → REVO — unverified on device.
- [x] Purchase/restore — not applicable to inspected build; recheck monetization.
- [ ] Working support/public privacy/legal pages — incomplete operator facts.
- [ ] Offline/slow API/session expiry/empty wallet — device acceptance required.
- [ ] PDF sharing/external Apply links — device acceptance required.
- [ ] Auth email callbacks and account deletion — hosted device test required.

## 5. Suggested reviewer notes (draft — do not paste until verified)

RevoCred provides educational credit-card rewards estimates using manually
entered preferences and spending. It does not connect to a bank, issue credit,
process applications, or require card numbers/CVV/bank passwords. Recommendations
are computed by our Go service; REVO explains the results.

Review account: `<confirmed review email>` / `<password supplied only in Connect>`.
From Home, complete the questionnaire and open the strategy report. Open Cards
to manage the wallet, Strategy to inspect the plan, and REVO for explanations.
Account settings are accessible from Profile, including export and account
deletion. Use a separate disposable account to test deletion.

No in-app purchases are present in this build. Apply links open external issuer
or disclosed partner websites; they do not unlock digital app functionality.
No camera, microphone, contacts or location access is needed. Sharing a PDF uses
the native share sheet. Guest previews are limited; use the review account to
exercise saved personal features. Backend services will remain available.

Production REVO uses OpenAI when enabled. Sending a chat message first shows a
sharing notice identifying the actual service, model and shared data. Choose
Agree and send for an external AI explanation, Use basic reply for a server-only
explanation, or Cancel. Permission is not remembered for later messages.
Before submission, verify this in the uploaded build and append actual
support/privacy URLs. Do not describe a consent feature until shipped.

## 6. Next pass

Release tooling can be prepared without inventing business facts. The next
product/compliance patch needs public policy and support URLs, legal
identity/retention decisions and enrollment details. Production OpenAI is now
confirmed and consent implemented locally. Finalize legal facts, configure the
client's production project/model and repeat this review against the signed
artifact and live services.

## App Store Connect privacy answers

Tracking: No. Data collection: Yes. Enter the following categories and purposes; only the indicated categories are linked to identity. No category is used for tracking. Confirm against the final archived SDK privacy report.

| Data type | Linked to identity | Purposes |
| --- | --- | --- |
| Name | Yes | AppFunctionality |
| CreditInfo | Yes | AppFunctionality, ProductPersonalization |
| ProductInteraction | No | Analytics |
| EmailAddress | Yes | AppFunctionality, DeveloperAdvertising |
| UserID | Yes | AppFunctionality |
| OtherFinancialInfo | Yes | AppFunctionality, ProductPersonalization |
| OtherUserContent | Yes | AppFunctionality, ProductPersonalization |
| OtherDiagnosticData | No | AppFunctionality |

Legal source changes and marketing purpose declaration are addressed. Public hosting, real operator facts and App Store Connect entry remain owner actions.
