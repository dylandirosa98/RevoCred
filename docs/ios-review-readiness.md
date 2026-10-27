# iOS review readiness — 2026-10-19

## 1. Executive summary

- RevoCred is a Flutter/iOS 13+ credit-card rewards planner backed by Go and
  Supabase. Core flows are questionnaire → plan, wallet management, and REVO
  explanations. Personal persistence requires an account; guest previews exist.
- **Not approved for production release yet.** A successful build is not a
  privacy, operational, physical-device, or Apple review certification.
- The first pass found missing third-party AI permission (5.1.2(i)); per-message
  consent and server enforcement are now implemented locally. Native acceptance
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

Consent now uses the actual backend recipient/model, not a hardcoded build-time
label. Each message requires a new affirmative action for external AI. Basic
reply uses the deterministic server explainer; cancel sends nothing. There is
no persistent permission to revoke or accidentally reuse across accounts.
The backend matches a disclosure version covering endpoint/model/text before
calling an external provider; missing permission never invokes that provider.

OpenCode's [Go documentation](https://opencode.ai/v2/docs/console/go), checked
2026-10-19, describes coding-agent traffic and a monthly DeepSeek ZDR agreement
currently valid through 2026-10-31. Those testing-service terms do **not** define
OpenAI production retention. Do not promise zero retention for either route
without confirming its actual current agreement. Testing should use synthetic
data and must still comply with its provider's terms.

| Priority | Area | Finding | Why review might reject | Evidence | Recommendation | Effort | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P1 high | Privacy | Consent implemented locally; native acceptance and actual OpenAI controls unverified | 5.1.2(i) requires permission before third-party AI sharing | `send_revo_message.dart`, server `chat_consent.go`, chat consent tests | Verify production recipient, decline/cancel, every entry point and session changes on device | M | High |
| P0 blocker | Privacy / UX | Legal notice still contains operator placeholders | 2.1 completeness; 5.1.1 privacy disclosure | `lib/features/profile/presentation/legal_screen.dart`; `docs/railway.md` | Operator-approved policy, retention, legal identity, public privacy URL and working support | M | High |
| P1 high | Technical | Signed archive/device behavior unverified | 2.1 stability and reviewer access | Xcode project has no development team; Linux environment | Sign/archive on Mac; validate in Organizer; execute device acceptance matrix | M | High |
| P1 high | Account | Hosted email/auth callbacks and deletion unverified | Reviewer cannot enter or manage account | `Info.plist` URL scheme; `account_screen.dart`; `ApiAppRepository.deleteAccount` | Deliver real emails; verify cold/warm callback, recovery, deletion on device | M | High |
| P1 high | UX | Reviewer account, store metadata and hosted backend availability unverified | 2.1 requires full access and working service | External App Store Connect/Railway/Supabase state not inspected | Provide active account and accurate notes; keep backend live | S | High |
| P1 high | Privacy | SDK aggregate manifest and App Store answers unverified | Privacy declarations must match actual collection | `Runner/PrivacyInfo.xcprivacy`, `pubspec.lock`, `docs/ios-privacy.md` | Inspect archived SDK report; complete accurate Connect answers | M | High |
| P1 high | Content | Financial positioning, catalog accuracy and asset rights need sign-off | Misleading claims / sensitive information / IP risks | `legal_screen.dart` educational disclaimer; catalog migrations; card artwork | Verify current issuer facts, artwork rights and seller/legal-entity suitability under 5.1.1(ix) | M | Medium |

Paths under `lib/` above are relative to `revocred_flutter/`.

## 3. Detailed findings

### Privacy & data handling

**AI consent remediation:** `sendRevoMessage` gates the composer, quick prompts
and Home/Cards shortcuts. It fetches the current named recipient, model and
data-use notice without sending private content. Cancel does not send, Basic
reply sends no external-AI permission, and Agree and send authorizes only that
message. The dialog names the personal context and recent history to be shared.
No permission is persisted. An account change during the dialog blocks sending.
`chat_consent.go` selects the deterministic provider for absent permission and
rejects stale permission before either public or authenticated provider calls.
Unknown recipient disclosures fail closed. Flutter regression tests cover all
entry points, cancel/basic/agree, per-message prompting, malformed/failed notices
and account changes; Go spy-provider tests cover both routes and changed versions.
Repeat these checks on the archived app and real production backend. Do not
mistake a request-level permission assertion for a cryptographic proof of user
interaction or a durable consent audit log.

**Legal facts:** `LegalScreen` still asks the operator to supply legal identity,
jurisdiction and retention facts. Its provider wording now distinguishes OpenAI
production from OpenCode/DeepSeek testing and describes per-message choices.
Do not invent remaining facts to remove placeholders.
Obtain actual operator/retention choices, publish accessible policy
and support pages, update the in-app notice, and align the manifest and Connect
answers. Verify URLs without sign-in and from the archived app.

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
