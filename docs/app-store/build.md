# iOS build evidence and release boundary

## Automatic native verification (not a release)

`.github/workflows/ios.yml` runs on pushes to `release/**` and `main`, selected
pull requests, and manual dispatch. The release-branch push trigger deliberately
has **no path filter**: a new workflow can execute from the release branch
without merging it into the default branch. Manual dispatch discovery may still
require a default-branch workflow; use the push trigger for this first run.

The job uses the standard public-repository `macos-15` hosted runner, a 55-minute
job limit, read-only repository permission, and one cancelable run per ref.
There are no paid/larger runner labels and no Apple secrets are read. Artifacts
expire after seven days. No signing, TestFlight upload, review submission, or
production API switch is performed.

Toolchain:

- Flutter **3.44.9**, Dart **3.12.2**, exact framework revision
  `6b182d2c7585eba26d4edce0f97630effd256c33` (verified locally with
  `flutter --version --machine`). Dependencies use `--enforce-lockfile`.
- Explicit selection of the newest installed **Xcode 26+**, followed by an
  **iOS 26+ SDK** check. Missing Xcode/SDK fails instead of silently using an
  old selected Xcode. No workstation upgrade or software purchase occurs.
- App deployment minimum remains **iOS 13.0**, matching the pinned Flutter
  SDK's `ios_deployment_target_migration.dart` minimum. The build SDK requirement
  is **not** a reason to raise the app deployment target to iOS 26.
- Debug/Profile/Release Runner bundle ID remains
  `com.revocred.revocredFlutter`. `Info.plist` inherits it. The independent native
  auth scheme remains `com.revocred.app`. Neither identifier has been renamed.

`python3 scripts/ios_ci.py` creates a temporary public compile fixture with
production code-path flags (`REVOCRED_PRODUCTION=true`, mocks disabled), but
**non-routable `.test` endpoints and an intentionally fake public key**. It
never substitutes local mocks or reads an existing `.env.ios.json`. The fixture
file is removed on completion and is excluded from artifact upload. The compiled
binaries intentionally contain the same non-secret fixture values.

The runner performs:

1. Static public-config/native metadata gates and release-tooling unit tests.
2. Unsigned device release compilation. The built app must retain the expected
   bundle ID, encryption declaration, and bundled non-tracking privacy manifest.
3. Debug simulator compilation with the same fixture, not live credentials.
4. Cold installation/launch on an available iOS 26+ **iPhone and iPad** simulator.
   Each app process must remain alive after 15 seconds; each produces a launch
   screenshot and fixture-only Runner runtime log. Missing either family fails
   rather than silently marking smoke passed.

This is **launch-process smoke**, not an automated UI journey or proof of the
first Flutter frame. Inspect both screenshots for blank/error screens. Real
native auth callbacks, account deletion/export, consent, network recovery,
sharing, accessibility, hosted services, and TestFlight acceptance remain
separate device/release gates in [the TestFlight checklist](../testflight.md).
No fixture artifact is production-ready, installable on real devices without
signing, or TestFlight-ready.

## Evidence

Only these allowlisted files are uploaded from `.local/release-readiness/`:

- `build-result.json`: exact CI commit and Flutter revision; explicit fixture,
  signing, distribution, compile, and simulator smoke status. Native stages
  start as `unverified`; errors never produce a success status.
- `unsigned-device-compile-fixture.zip`: unsigned release `Runner.app`.
- `simulator-compile-fixture.zip`: debug simulator `Runner.app`.
- `iphone-launch.png`, `ipad-launch.png`, and named fixture-only `*.log` files.

App bundles are zipped with `ditto` to retain framework symlinks. Whole
workspaces, keychains, provisioning profiles, `.env*`, and signing material are
not uploaded. Hidden-file inclusion is necessary for the `.local` directory and
is constrained by this explicit allowlist.

Linux/static verification:

```sh
python3 -m unittest discover -s scripts -p 'test_*release*.py'
python3 -m unittest discover -s scripts -p 'test_ios_ci.py'
python3 scripts/ios_ci.py --preflight-only
# Optional free local linter:
actionlint .github/workflows/ios.yml
```

A static-only result is `static-passed-native-unverified`, never a native pass.
The first actual native compile must be verified from the release branch's
GitHub Actions run and its artifacts; local Linux cannot run Xcode.

## Real signed release remains an explicit operator gate

Name-only repository checks returned **no repository Actions secret names and
no repository variable names** for `dylandirosa98/RevoCred`; no repository
environments were listed. This does not inspect Apple accounts, a local Mac
keychain, or prove the absence of all possible external credentials. No secret
values were retrieved and no secrets/variables were created.

Signed CI/archive/upload automation is intentionally **not enabled**. Manual
dispatch performs the same unsigned fixture checks. With credentials absent,
there is no attempted signing or upload, and no misleading release-ready job.
Use the existing local signing/export instructions in [TestFlight](../testflight.md)
after the account owner authorizes and configures the Apple team and real public
service configuration. Any future signed CI job must require explicit boolean
`workflow_dispatch` opt-in plus authorized signing secrets/environment approval;
it must preflight missing credentials cleanly, never run from a PR/push, and
must keep upload separate from archive creation.

`scripts/ios_release.py` now rejects reserved/local/numeric/tunnel API or
Supabase hosts and placeholder public keys for real preflight/archive builds.
Only the CI tooling calls the explicit fixture-validation bypass, and that
bypass is never exposed on the signed-build CLI. Syntax validation still does
not establish domain ownership, key validity, hosted readiness, or device/privacy
acceptance. App Store submission must additionally inspect aggregated
third-party privacy manifests and signing/entitlements in Xcode Organizer.

## Parent handoff / file manifest

No commits, pushes, checkout, ref changes, or workflow runs are performed by
this tooling-preparation task. For the parent-managed release branch push,
include these task files:

- `.github/workflows/ios.yml`
- `scripts/ios_ci.py`, `scripts/test_ios_ci.py`
- `scripts/ios_release.py`, `scripts/test_ios_release.py`
- `docs/app-store/build.md`

The baseline release files are currently untracked and are dependencies of the
workflow: include `config/ios-release.example.json`,
`config/ios-export-options.example.plist`, `scripts/check_release_config.py`,
`scripts/test_release_config.py`, and the intended native iOS project/product
changes in the parent's selected release snapshot. Do not accidentally commit
`.local/`, generated Flutter SDK/cache files, or private configurations. The
parent owns final snapshot selection and the subsequent remote run; this file
is not evidence that a remote run succeeded.
