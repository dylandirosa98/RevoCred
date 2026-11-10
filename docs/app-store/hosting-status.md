# Hosted release state

Current handoff updated November 8, 2026 from the evidence in
[the dated App Store review](review-2026-11-08.md). No hosting configuration,
account, DNS, plan or credentials were changed by this documentation update.

## Current evidence

- Live API health/readiness, public catalog/index, offers and Explore Rewards
  responded during that review. Supabase Auth settings also responded.
- Unauthenticated bootstrap/export/wallet/chat/consent requests returned 401;
  metrics returned 404. These are public boundary checks, not authenticated
  hosted account-lifecycle acceptance.
- Live chat disclosure named **OpenCode Go and DeepSeek (testing)** with
  `deepseek-v4.1-flash`. Final launch-provider selection, data controls and
  acceptance remain open; do not present planned OpenAI settings as deployed fact.
- The landing page loaded over HTTPS, but tested `/privacy`, `/privacy-policy`,
  `/terms` and `/support` paths returned 404. Alternate approved URLs and mailbox
  delivery remain unverified.

Earlier `.local/release-readiness/hosting.json` observations of inactive Supabase,
empty Railway and unresolved domains are historical and superseded for service
availability. They do not describe the current deployment. Exact current hosting
configuration, billing continuity and monitoring ownership still need owner
verification; live endpoint success alone does not establish those facts.

## Database and operational gate

Local database restore tests do not prove hosted recoverability. Earlier backup
flags (`backups: null`, `pitr_enabled: false`, `walg_enabled: true`) are historical,
not a current backup inventory or recovery guarantee. Before any hosted database
write, inspect current schemas/migrations/roles without logging private rows,
verify a recoverable backup and rollback plan, and use the migration owner rather
than the restricted API runtime role. Do not infer migration state from local tests.

Verify hosted SMTP, native callback allowlists, confirmation, recovery, email
changes and deletion with disposable accounts on the exact processed iOS build.
No installed hosted lifecycle pass is established by the public endpoint checks.
Confirm monitoring/alerts, support/report ownership and a hosted recovery point.

## Release configuration gate

Use the actual stable HTTPS API URL and public Supabase values in the release
configuration. Keep database credentials, service-role keys, AI credentials and
metrics secrets server-side. Finalize the launch AI recipient and align its
runtime disclosure, legal pages and Connect privacy answers with actual processor
practices. Do not substitute fixture values or developer credentials for approved
release configuration.

**Hosted services respond, but end-to-end release readiness remains unverified.**
The review found `.env.ios.json` absent and no signed, processed TestFlight build
with device acceptance. Public policy/support publication, final provider testing,
hosted native account journeys, signing and Connect metadata remain release gates.
