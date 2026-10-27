# RevoCred → TestFlight

The repository can validate public iOS configuration on Linux and build a signed
IPA on a configured Mac. It does **not** upload, submit for review, prove hosted
readiness or guarantee approval. Resolve the findings in
[iOS review readiness](ios-review-readiness.md) before distributing real-user
builds. Per-message AI permission is implemented locally but still needs native
acceptance testing; final legal/support facts remain open.

## 1. Apple setup (operator, once)

- This is a client-owned app: use the **client's** membership, team, bundle ID
  and App Store Connect record. A separate paid membership for the contractor
  is not required to publish through the client's account.
- If the client is enrolled as an **organization**, ask their Account Holder
  or Admin to invite your Apple Account through App Store Connect → Users and
  Access with Developer access and the appropriate signing-resource permission.
  Use your own login with two-factor authentication, never the client's password.
- If the client is enrolled as an **individual**, an App Store Connect invitation
  does not grant Developer Program/signing membership. The client must handle
  signing/provisioning, or establish an appropriate organization/team setup.
  Confirm the enrollment type before assuming the team will appear in Xcode.
  See Apple's [user-access guidance](https://developer.apple.com/help/app-store-connect/manage-your-team/add-and-edit-users/).
- Active Apple Developer membership; accepted current agreements and an
  appropriate seller/legal entity for the app's sensitive financial information.
- Register the final bundle ID and create the matching App Store Connect app.
  Current Runner ID: `com.revocred.revocredFlutter`. Confirm it before the first
  upload. If changing it, change Debug/Profile/Release consistently in Xcode;
  the script verifies they agree. The auth URL scheme `com.revocred.app` is a
  separate identifier and need not equal the bundle ID.
- Install full Xcode **26+**, iOS **26+** SDK and compatible macOS. Complete
  Xcode's first-launch setup and select it with `xcode-select`. These are the
  upload requirements checked on 2026-10-19; recheck Apple's requirements before
  submission. The app's minimum deployment target remains iOS 13.
- Install the same Flutter revision as CI:
  `6b182d2c7585eba26d4edce0f97630effd256c33` (see `.github/workflows/check.yml`).
  Put that SDK's `bin` on PATH. Do not silently upgrade the SDK for release.
- Run `flutter pub get --enforce-lockfile` in `revocred_flutter`, open
  `revocred_flutter/ios/Runner.xcworkspace`, select Runner → Signing &
  Capabilities, choose your team and configure automatic signing. No team is
  committed yet. Confirm the final identifier and signing for Release.
- Keep certificates, private keys, profiles and passwords out of Git/chat. Use
  Xcode's account/keychain tools; do not put signing secrets in Dart defines.

## 2. Configure the installed app (public values only)

From the repository root:

```sh
cp config/ios-release.example.json .env.ios.json
```

Edit the three empty values in `.env.ios.json`: the stable HTTPS API domain,
Supabase HTTPS URL, and **public** publishable/anon key. Keep JSON values as
strings, including `"false"` and `"true"`. Never copy the server `.env`; the
validator rejects extra keys. This file is gitignored, but **everything in it
is embedded in the app and readable by users**.

The script does not read `.env`, `.env.local`, `.env.share`, Railway secrets or
production database credentials. It does not contact any services for preflight.
Configure the exact Supabase redirect allowlist entry:

```text
com.revocred.app://auth-callback/
```

Verify production SMTP, confirmation, recovery and email changes on a device.
Use a stable API domain, not a temporary tunnel or local address. Configure the
API/runtime role, apply migrations with the migration owner, confirm `/readyz`,
backup/restore and monitoring; see [Railway](railway.md) and
[operations](operations.md). Passing syntax checks does not verify any of these.

**AI environment separation:** production uses the client's OpenAI project/key
in server-side Railway secrets, never in this iOS JSON. The production API
requires explicit `AI_API_KEY`, `AI_BASE_URL=https://api.openai.com/v1` and
`AI_MODEL` when external AI is enabled. The developer's OpenCode Go/DeepSeek
key is testing-only and is not inherited in production. See
[the provider configuration and consent contract](railway.md#revo-ai-provider).

Validate offline (works on Linux):

```sh
make ios-release-check
python3 -m unittest discover -s scripts -p 'test_*release*.py'
```

## 3. Create the signed archive and IPA (Mac)

```sh
mkdir -p .local/ios
cp config/ios-export-options.example.plist .local/ios/ExportOptions.plist
```

Set `teamID` to the same Apple team selected in Xcode. The example uses
`method=app-store-connect`, `destination=export`, automatic signing and symbol
upload. The script refuses an implicit upload destination. Teams using manual
signing should export matching options from Xcode and supply that local plist.

After committing the intended release changes and ensuring hosted readiness:

```sh
make ios-release FLUTTER=flutter DART=dart IOS_BUILD_NUMBER=1
```

Choose a fresh positive build number for **every** upload; `1` is only an example
for the first upload. The marketing version currently comes from
`revocred_flutter/pubspec.yaml` (`1.0.0`). `make ios-release` runs `make check`,
validates the public config/native project/export options/toolchain, enforces
the pinned Flutter revision and dependency lockfile, then invokes:

```sh
flutter build ipa --release --build-number=1 \
  --dart-define-from-file=../.env.ios.json \
  --export-options-plist=../.local/ios/ExportOptions.plist
```

The script uses absolute file paths internally. Outputs are under
`revocred_flutter/build/ios/archive/` and `revocred_flutter/build/ios/ipa/`.
Retain the exact archive and dSYMs for crash symbolication, along with commit,
Flutter/Xcode versions, marketing/build number and deployment version. Do not
commit build/signing artifacts. The repository does not yet enforce clean-tree
release provenance; record the exact release commit and avoid uncommitted cuts.

## 4. Native acceptance gate

Record device/OS, build number, date, result and evidence for each row. All rows
start **unverified**, not passed. Use iPhone and iPad (both are supported by the
current target), a small screen, increased text size and VoiceOver.

| Journey | Required evidence |
| --- | --- |
| Install/cold launch/resume | No crash, stuck loader or layout overflow |
| Guest questionnaire → report | Real API result, honest assumptions, no mock fallback |
| Sign up/confirm/resend/sign in/sign out | Delivered email and correct cold/warm native callback |
| Password recovery/email change/session expiry | Return to correct screen; stale token gives recoverable error |
| Wallet add/edit/remove and plan refresh | Account-isolated saved values; consistent deterministic results |
| AI consent/decline/revoke/account switch | No external AI calls without permission; planning still usable |
| REVO slow/failing/offline | Recoverable error; no duplicate sends or private cross-account data |
| Strategy PDF export/share | Native share sheet works on iPhone and iPad |
| Apply links/privacy/support | Correct destinations, actual disclosure, no dead links |
| Account export/delete | Export readable; deletion removes hosted auth/live data and local private state |
| Airplane mode/poor network/IPv6-only | No crash; clear retry/errors and no endless loader |
| Accessibility | Usable focus order, labels, contrast, text scaling and keyboard behavior |

In Xcode Organizer inspect and validate the archive: identifiers, signing,
entitlements, app icon, minimum OS, encryption declaration and aggregate privacy
report including third-party SDK manifests. The static checker is intentionally
not a substitute for Xcode validation or App Store Connect processing.

## 5. Upload and beta distribution (operator)

1. Open the exact `.xcarchive` in Xcode Organizer and validate it. Upload that
   archive through Organizer, or upload the exported IPA with Apple's
   Transporter. The build script never uploads or publishes.
2. Wait for App Store Connect processing; resolve warnings/errors rather than
   treating an upload as acceptance. Confirm version/build/bundle ID match.
3. Complete encryption/export compliance and the applicable beta information,
   feedback email, contact information and tester groups.
4. Start with internal testers who are eligible App Store Connect users. This
   normally does not require Beta App Review; still verify device behavior and
   privacy before using real accounts. Test the **processed TestFlight build**.
5. External testers require Beta App Review as applicable. Supply a working,
   confirmed review account, accurate beta description, test instructions,
   support/policy URLs and contact information. Keep services available.
   Draft review notes are in [the review report](ios-review-readiness.md).
6. A public App Store release is a separate submission. Complete listing,
   screenshots using fictional data, category, age-rating questions, privacy
   answers, territory/trader/legal details and current review requirements.
   Don't describe unshipped consent or unsupported financial claims.

## CI scope

`.github/workflows/ios.yml` compiles the native release code on macOS using
production flags but **non-routable fixture endpoints**, without signing. It
uses no Apple secrets and cannot produce a distributable TestFlight build. Its
first remote run remains unverified until pushed and executed. It complements
the existing Linux checks, not device tests, privacy acceptance or Beta Review.
