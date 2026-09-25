# iOS privacy and export declarations

`Runner/PrivacyInfo.xcprivacy` is included once in the Runner resources build
phase. It declares the current app's collected data: display name, email,
account ID, credit band, entered financial information and chat/user content
(linked to the account, for functionality); anonymous offer interaction counts
(analytics); and error categories (diagnostics, unlinked).

The app uses UserDefaults through shared_preferences for its own settings and
session storage (`CA92.1`). Third-party SDK manifests still need to be checked
in Xcode's aggregate privacy report. This file does not replace App Store
Connect privacy answers or the public privacy policy.

`ITSAppUsesNonExemptEncryption=false` reflects the current app's use of standard
HTTPS/platform cryptography. Reassess if custom/non-exempt cryptography is added.

No cross-app tracking SDK, advertising identifier or individual affiliate
attribution is implemented. Anonymous redirect counts do not add an ATT prompt.
Before activating a partner integration, verify its actual data flows and
whether privacy answers, tracking domains or consent requirements change.
Third-party websites may use their own cookies after the external navigation.

Still required on macOS: archive with Xcode, inspect the bundled manifest and
SDK privacy report, validate export compliance and App Store privacy answers,
then test external application links on a device/TestFlight. Linux plist
validation is not evidence of App Store acceptance.
