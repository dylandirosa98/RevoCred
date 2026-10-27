# Privacy policy and support — owner approval drafts

**NOT PUBLISHED / NOT APPROVED / DO NOT SUBMIT AS FINAL.** Bracketed fields below
are exact owner-only unknowns, not facts to infer from project labels. Before
publication, verify every statement against the deployed build and vendors. This
is technical drafting, not legal advice. The app's pre-release notice is not a
replacement for an approved public policy or terms.

## Privacy policy draft

**RevoCred Privacy Policy**  
Effective date: **[OWNER: approved effective date]**  
Operator/controller: **[OWNER: full legal entity/person and jurisdiction/address]**  
Privacy contact: **[OWNER: monitored privacy contact and request method]**

RevoCred helps you plan credit-card rewards using information you enter. You do
not need to provide a card number, security code, PIN or bank password. Do not put
these or other sensitive credentials into chat or custom card fields.

### What we process and why

- **Account:** email, password/authentication information and sessions handled
  through Supabase Auth; optional display name and notification preference.
  RevoCred uses an account ID to associate your saved application records.
- **Plans and wallet:** life-stage preference, entered credit band, spending
  categories/budgets, reward goals, fee/travel preferences, wallet card names and
  terms, questionnaires and resulting plans/recommendations. These provide and
  personalize the service. We do not obtain a credit report or connect to your
  bank through this app's inspected feature set.
- **Chat:** your questions and replies, including personal details you choose to
  enter. Signed-in chat is stored in your account. Guest previews send answers
  to our API for calculation without creating saved account records.
- **Reliability and links:** the app reports only error categories (not message
  text or stack traces) to application counters and counts offer redirects by
  offer/day/screen without account/device identifiers in those counters.
  **[OWNER: describe actual hosting/Auth/CDN security and access logs, IP metadata,
  vendors and retention after deployment inspection; do not promise no logs.]**

### External AI and public web sources

Production REVO is configured for OpenAI when external AI is enabled. Before
each message the app identifies the configured service/model and describes the
sharing. **Agree and send** permits external AI for that message only. **Use basic
reply** uses RevoCred's deterministic server explainer without external AI.
**Cancel** sends no chat message. Permission is not saved for future messages.

If you agree, the request includes your question and, when signed in, your first
name, life stage, credit band, entered spend, wallet terms, strategy,
recommendation ranking and up to eight recent chat messages. Guest chat uses
demo context but the text you enter is still shared if you agree. Public-topic
web searches may be sent to DuckDuckGo and public HTTPS pages/readable PDFs may
be fetched. Tools are instructed to exclude personal details and block clear
sensitive identifiers; these safeguards are not a promise of perfect removal.
Search/source services may receive request metadata. Web results are evidence
for explanations, not inputs that can change deterministic rankings/scores.

**[OWNER: confirm actual OpenAI project/model, contractual retention, training
controls, geography/transfers, service-provider terms and web-tool providers. Do
not promise zero retention or no model training without evidence.]** OpenCode Go /
DeepSeek is developer testing only and must not silently substitute for the
production disclosure; its terms are not OpenAI production terms.

### Device storage, export and deletion

The device stores your session, appearance preferences and a short-lived
questionnaire draft. Drafts expire after 24 hours when accessed and can be
cleared from the guest preview. Logout/session sign-out clears private app state
and the draft. This is not a guarantee of forensic erasure from device backups.

In the app, open **Profile → Account settings** to export your application data
as JSON or request permanent account deletion after confirming your current
password. Deletion removes your Auth user and associated live profile, wallet,
questionnaire, recommendation and chat records. Your own exported files, PDF
copies and clipboard contents are not recalled by deleting your account.
**[OWNER: provide alternative verified deletion/privacy request contact for people
who cannot access their account, plus actual handling commitments.]**

The live application caps history at 1,000 chat messages and 100 recommendation
runs/questionnaires per account; older records are removed as new records arrive.
These caps do not establish a time-based retention period.
**[OWNER: actual account inactivity/closure retention; backup/PITR expiry and
restoration/deletion safeguards; logs, Auth/SMTP/support and AI vendor retention;
legal retention exceptions and rights/complaint procedures by served territory.]**

### External sites and commercial links

Apply links open an issuer or disclosed partner website. RevoCred does not send
your spending, wallet or chat with those links. The destination may process its
own cookies/traffic under its own policy. Partner links, if enabled, are labeled
and may earn a commission; recommendations do not require a partner offer.
**[OWNER: confirm actual commercial arrangements and destinations before launch.]**

No cross-app tracking/ad identifier collection is implemented in the inspected
app. **[OWNER: confirm actual processors/partners before adopting this sentence as
a public no-tracking commitment.]**

### Contact, rights and changes

For support, privacy requests or inaccurate/unsafe REVO output, contact
**[OWNER: monitored support/privacy channel]**. Do not send passwords, tokens,
card numbers or full financial exports. **[OWNER: applicable rights, regional
terms, children's/audience policy, identity verification without unnecessary
sensitive data, appeal/complaint routes, policy change notice and commitments.]**

## Support-page draft

**RevoCred Support**  
Contact: **[OWNER: monitored support email or working form]**  
Operator: **[OWNER: approved legal identity]**

- **Sign-in/confirmation:** check the email you entered and spam folder. From the
  welcome screen choose **Forgot password / confirm email**, then **Resend
  account confirmation** if needed. Never share the email's sign-in/reset link.
- **Password reset:** choose **Send password reset** in account recovery and open
  the email on the device/browser where you initiated recovery. Complete the new
  password screen. If an expired link fails, request a new one.
- **Privacy/data:** **Profile → Account settings → Export my data** creates a
  private JSON export. **Delete my account** asks for your current password and
  confirmation before deleting the live account/data. Backup handling follows
  the final privacy policy, not an instant-erasure guarantee.
- **REVO:** Cancel sends nothing; Use basic reply avoids external AI; Agree and
  send permits external AI for this message only. If sending fails, your plan and
  wallet remain available. Do not send private financial credentials in chat.
- **Incorrect or unsafe information:** report the screen/feature, app version,
  approximate time and a redacted description through the contact above. Do not
  attach account exports, credentials or unredacted financial screenshots.
- **Estimates:** RevoCred does not issue credit, submit applications, guarantee
  approval/rewards, or provide personalized professional financial advice.
  Verify issuer terms. Wallet estimates and application rankings have different
  documented assumptions; use the current build's explanation.

**[OWNER: response availability/commitments, escalation owner, public privacy
policy URL, verified deletion assistance and final support URL.]** No support SLA,
working public mailbox or published page has been verified. Publish only after
replacing these fields and testing the contact channel and HTTPS pages without
sign-in. Do not create a new login, purchase a domain or post publicly without
owner authorization.
