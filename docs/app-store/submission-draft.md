# App Store / TestFlight submission drafts

**Draft only — not submitted. Do not paste until the exact uploaded build,
hosted service, reviewer access and legal facts are verified.** See
[readiness and privacy answers](readiness-privacy.md) for evidence/blockers.

## Listing copy

Name: **RevoCred**  
Subtitle draft: **Plan your card rewards**

Description draft:

> Understand your card wallet and plan your next steps with RevoCred.
>
> Enter your spending preferences and goals, add the cards you already hold,
> and explore a personalized rewards strategy. Review your wallet, compare
> category choices and revisit a strategy report you can share as a PDF.
>
> REVO explains the information behind your plan. When external AI is enabled,
> you choose separately for each message whether to share with the named AI
> service, use a basic server-only reply or cancel.
>
> RevoCred is an educational planning tool. It does not connect to your bank,
> issue credit or submit applications. You do not need card numbers, security
> codes or bank passwords. Estimates are not approval or rewards guarantees;
> verify current issuer terms, conditions and eligibility. Do not borrow or
> spend more solely to earn rewards.

Owner/product sign-off: validate every advertised feature in the processed build;
do not promise complete card coverage, bonus eligibility, guaranteed savings,
credit-score improvement, issuer endorsement or exhaustive benefit accounting.
The wallet estimate and application-ranking model are separate; details belong
in the actual UI, not misleading "maximize everything" listing language.

**Required owner-only metadata:** approved support URL and privacy-policy URL;
marketing URL if used; copyright/legal seller; contact details; accurate category,
age-rating questionnaire, territories/trader status; current financial-services
seller eligibility; screenshots from this exact build with fictional accounts;
asset rights/commercial sign-off. Do not invent these from repository labels.
No IAP, bank connection or social feed is implemented in the inspected build;
confirm this remains true before answering the corresponding Connect questions.

## Reviewer instructions (conditional draft)

> RevoCred uses manually entered preferences to provide educational credit-card
> rewards planning. The Go service owns deterministic plans/ranking; REVO explains
> results and cannot alter those calculations. No card numbers, CVV, PINs, bank
> credentials or bank connection are required.
>
> **Review login:** [OWNER: confirmed dedicated reviewer email; enter password
> only into App Store Connect's protected review credentials fields, not Git].
> **Separate deletion account:** [OWNER: disposable confirmed credentials in the
> protected review fields; deleting the main review account removes future access].
>
> Launch the app. Guest users can choose Build my strategy and complete the
> questionnaire for a preview. Use the confirmed review login for saved personal
> features. A new account without a questionnaire goes to onboarding. Complete
> the questionnaire, open its strategy report, then inspect Home, Cards, Strategy
> and REVO. Profile contains account settings and strategy report access.
>
> In REVO, enter a question or use a quick prompt. Home's Ask REVO and card-detail
> Ask REVO shortcuts use the same sharing gate. When external AI is enabled, the
> dialog identifies its recipient/model and context/web sharing. Cancel posts no
> message. Use basic reply uses only RevoCred's server. Agree and send permits
> the named external service for that one message, and the next message asks
> again. No persistent AI permission is retained. Production is configured for
> OpenAI, not the developer's OpenCode/DeepSeek testing environment.
>
> Open Profile → Account settings to change email/password, export data or delete
> the account. For deletion, use the disposable account, enter its current password,
> select Delete my account and confirm Delete account. This permanently removes
> the live account and associated records. Backups follow the final published
> retention policy; this does not recall your exported copies.
>
> No in-app purchases are present. Apply links open external issuer or labeled
> partner websites and do not unlock digital features. PDF sharing uses the native
> share sheet. No camera, microphone, contacts or location permission is needed.
>
> Privacy policy: [OWNER: verified public HTTPS URL].
> Support: [OWNER: verified public HTTPS URL/contact].
> [OWNER: confirm real backend availability throughout review and exact uploaded
> version/build; do not promise this while hosting is unavailable.]

## Native acceptance instructions — all still unverified

Use supported iPhone and iPad on the exact processed build. Record device/OS,
version/build, date, outcome and redacted evidence. Do not infer results from
Flutter widget tests or Linux builds.

1. Confirm signup delivers mail, resend works, and confirmation returns to app
   both while running and terminated; confirm sign-in and logout clear private
   data. Repeat expired/invalid email links with recoverable errors.
2. Request recovery from that installed app; inspect exact
   `com.revocred.app://auth-callback/?recovery=true` allowlist behavior and PKCE
   completion on cold/warm launch. Set password and sign in again. Verify email
   change confirmation in both inboxes with actual production policy.
3. Cancel/Basic/Agree from composer, quick prompt, Home and card detail; verify
   no external requests for Cancel/Basic and per-message prompting for Agree.
   Repeat provider/disclosure failure, stale consent and logout/account change
   during the dialog and in-flight request.
4. With disposable accounts, export, delete, confirm old-token and fresh login
   denial, check cleared local session/drafts/private UI. Check cross-account
   isolation and no reappearing data after a slow pending response. Do not test
   deletion with the primary review account or any real user's account.
5. Exercise offline/slow/expired session, malformed server errors, iPad share
   sheet, accessibility and actual Apply/privacy/support URLs. Use fictional
   data. Keep exports/screenshots private and redacted.
6. Inspect signed archive's aggregate privacy report and SDK required-reason
   APIs, entitlements and encryption declaration. Source plist checks are not
   signed aggregation or App Store validation.

No App Review submission, publication, store edits, hosted test users or paid
service changes are authorized/performed by this draft.
