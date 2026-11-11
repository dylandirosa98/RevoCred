# App Store / TestFlight submission drafts

**Draft, not submitted.** Fill every `[[...]]` placeholder and verify against the
exact uploaded build before pasting into App Store Connect. See
[readiness and privacy answers](readiness-privacy.md) for evidence and blockers,
and [docs/legal/README.md](../legal/README.md) for the legal-page placeholders.

## URLs

| App Store Connect field | Value |
| --- | --- |
| Privacy Policy URL (App Privacy) | https://api.revocred.com/privacy |
| Support URL (version information) | https://api.revocred.com/support |
| Marketing URL (optional) | https://revocred.com |
| License Agreement (App Information → custom EULA) | Paste the text of https://api.revocred.com/terms, or keep Apple's standard EULA and link the terms in the description |
| Support email (App Review contact and in-app) | support@revocred.com (mailbox being set up; unverified) |

The API serves these pages from `main` (`revocred-api/internal/legal`). Before
submission, open each URL signed out on an iPhone and confirm no `[[` remains.
The app links to the same URLs from Profile → Privacy and terms.

Availability: **United States only** (the catalog covers US issuers; avoids EU
DSA trader display). Price: free, with the optional REVO AI subscription.

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
> you can agree to sharing with the named AI service or choose a basic
> server-only answer. Account permission stays on until you turn it off in
> Profile or the sharing notice changes.
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

**Owner-only metadata still required:** seller and copyright name
(`[[COMPANY LEGAL NAME]]`, must be the Apple Organization account), category
(suggest Finance, secondary Education), screenshots from this exact build using
fictional data and no issuer card art unless rights are confirmed, and asset
rights sign-off. Keep issuer and card trademarks out of the name, subtitle and
keywords (2.3.7, 4.1(c)).

## App Privacy (nutrition label)

Matches `revocred_flutter/ios/Runner/PrivacyInfo.xcprivacy` and the privacy
policy. **Tracking: No** for every type. "Linked" means linked to the user's
identity.

| Apple data type | Collected | Linked | Purposes | Why |
| --- | --- | --- | --- | --- |
| Contact Info → Name | Yes | Yes | App Functionality | Optional display name, also sent to AI after consent |
| Contact Info → Email Address | Yes | Yes | App Functionality; Developer's Advertising or Marketing | Sign-in and account email; opt-in update emails |
| Financial Info → Credit Info | Yes | Yes | App Functionality; Product Personalization | Self-selected credit band |
| Financial Info → Other Financial Info | Yes | Yes | App Functionality; Product Personalization | Spending, wallet cards, plan |
| User Content → Other User Content | Yes | Yes | App Functionality; Product Personalization | REVO chat, custom cards, answer reports |
| Identifiers → User ID | Yes | Yes | App Functionality | Account ID (and RevenueCat app user ID once subscriptions ship) |
| Purchases → Purchase History | Yes, **once the REVO AI subscription ships** | Yes | App Functionality | Subscription status via RevenueCat |
| Usage Data → Product Interaction | Yes | No | Analytics | Aggregate Apply-link counts per offer/day/screen |
| Diagnostics → Other Diagnostic Data | Yes | No | App Functionality | Error categories only |

Not collected: Health & Fitness, Payment Info (Apple handles payment), Precise
or Coarse Location, Sensitive Info, Contacts, Emails or Text Messages, Photos or
Videos, Audio, Gameplay, Customer Support (support is by email outside the app),
Browsing History, Search History, Device ID, Advertising Data, Crash Data,
Performance Data, Other Data.

Third parties that receive this data on our behalf (Supabase, Railway, Resend,
OpenAI, Brave Search, RevenueCat) are service providers and are covered by the
answers above; none uses it for tracking.

## Age rating (18+)

Answer the questionnaire honestly, then use **Override to Higher Age Rating →
18+**. Apple requires the override because the Terms of Use set a minimum age
of 18.

| Question | Answer |
| --- | --- |
| Parental Controls | No |
| Age Assurance | No |
| Unrestricted Web Access | No (links open in Safari; no in-app browser) |
| User-Generated Content | No (REVO is private user-to-AI chat; nothing is shared with other users) |
| Messaging and Chat | No (no user-to-user messaging) |
| Advertising | [[YES IF PAID AFFILIATE OFFERS ARE LIVE IN THIS BUILD, ELSE NO]] |
| Profanity or Crude Humor | None |
| Horror/Fear Themes | None |
| Mature or Suggestive Themes | None (REVO is limited to cards, rewards, travel and money, with moderation) |
| Sexual Content or Nudity / Graphic Sexual Content | None |
| Cartoon or Fantasy Violence / Realistic Violence / Prolonged Graphic Violence | None |
| Guns or Other Weapons | None |
| Alcohol, Tobacco, or Drug Use or References | None |
| Medical or Treatment Information | None |
| Simulated Gambling / Gambling / Contests / Loot Boxes | None / No |
| Dating and Relationships (new 2026-11-16) | No |
| Shared Location (new 2026-11-16) | No |
| Age Rating Override | **18+** |

## App Review notes

Paste into App Review Information → Notes. Enter credentials only in the
protected sign-in fields, never in Git.

> RevoCred is an educational credit-card rewards planner for adults in the
> United States. Users enter their own preferences and cards by hand. It does
> not connect to banks, pull credit, issue credit, submit applications or move
> money, and it never asks for card numbers. Card recommendations are
> calculated by our server with fixed rules; AI never selects or scores cards.
>
> **Sign-in:** use the demo account in the Sign-in Information fields
> ([[REVIEW ACCOUNT EMAIL]]). It is pre-confirmed, has a completed
> questionnaire and wallet, and has the REVO AI allowance enabled, so Home,
> Cards, Strategy and REVO show data immediately. To test account deletion,
> please use the second account [[DELETION TEST ACCOUNT EMAIL]] (password
> [[DELETION TEST ACCOUNT PASSWORD]]) so the main review account stays
> available.
>
> **REVO (AI assistant):** tap the **REVO** tab (labeled "Ask REVO" on larger
> screens), or **Ask REVO** on Home or a card's details. Before the first AI
> answer, a sheet names the AI service (OpenAI) and lists exactly what is
> shared (question, first name, life stage, credit band, spending, wallet,
> strategy, ranking and up to eight recent messages). **Agree and continue**
> enables AI answers for the account; **Basic answer instead** uses only our
> server;
> **Cancel** sends nothing. Permission can be turned off in Profile → AI
> answers (REVO). Guests (not signed in) always get basic answers. REVO only
> discusses cards, rewards, travel and money; messages and answers pass
> through OpenAI's moderation check. Each REVO answer has a **Report** option.
>
> **Account deletion:** Profile → Account settings → Delete my account, enter
> the password and confirm. Data export is on the same screen.
>
> **Purchases:** No in-app purchases in this build. [[IF THE REVO AI
> SUBSCRIPTION IS IN THE BUILD, REPLACE THE PREVIOUS SENTENCE WITH: "REVO AI
> is an optional auto-renewing monthly subscription (product ID: fill in) that
> raises the daily AI answer limit. It is offered in REVO once the free daily
> allowance is used. Basic answers and all planning features stay free."]]
> Apply links open the issuer's or a labeled
> partner's website in Safari and unlock nothing in the app.
>
> No camera, microphone, contacts, location or tracking permission is used.
> Privacy policy: https://api.revocred.com/privacy. Support:
> https://api.revocred.com/support, support@revocred.com.

Before submitting:

- Create both review accounts in production, confirm their emails, and give the
  main account an active `ai_entitlements` row (free accounts get 3 AI answers
  a day, which a reviewer can exhaust).
- Production must use OpenAI (the sharing notice names the provider in use; an
  OpenCode "(testing)" recipient in the review build reads as test content).
- Custom SMTP (Resend) must be live so sign-up and password reset emails
  arrive.

## Native acceptance instructions — all still unverified

Use a supported iPhone (the app is iPhone-only) on the exact processed build. Record device/OS,
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
   no external requests for Cancel/Basic; Agree persists for the account across
   subsequent messages. Turn off Profile → AI answers (REVO), confirm basic
   answers and renewed prompting on the next send, then verify notice changes
   require fresh agreement. Check guest session scope and account isolation.
   Repeat provider/disclosure failure, stale consent and logout/account change
   during the dialog and in-flight request.
4. With disposable accounts, export, delete, confirm old-token and fresh login
   denial, check cleared local session/drafts/private UI. Check cross-account
   isolation and no reappearing data after a slow pending response. Do not test
   deletion with the primary review account or any real user's account.
5. Exercise offline/slow/expired session, malformed server errors, share
   sheet, accessibility and actual Apply/privacy/support URLs. Use fictional
   data. Keep exports/screenshots private and redacted.
6. Inspect signed archive's aggregate privacy report and SDK required-reason
   APIs, entitlements and encryption declaration. Source plist checks are not
   signed aggregation or App Store validation.

No App Review submission, publication, store edits, hosted test users or paid
service changes are authorized/performed by this draft.
