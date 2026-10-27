# Hosted release state

Verified through authenticated Supabase/Railway CLIs during this readiness pass.
No hosted data, service, plan, DNS, or credentials were changed.

## Intended resources found

- Supabase organization: **RevoCred**; existing **RevoCred** project in
  **us-east-2**. The CLI reports **INACTIVE**. Its API hostname did not resolve
  from the build workstation.
- Railway workspace: **RevoCred's Projects**; existing **loving-generosity**
  project, **production** environment. Authenticated inspection found **zero
  services**. This is not a deployed Go backend.
- `api.revocred.app` and `revocred.app` are examples in older documentation, not
  verified configured domains: DNS did not resolve in this pass.
- GitHub `dylandirosa98/RevoCred`: public; current operator has ADMIN permission;
  Actions enabled. Standard public-repository macOS runners need no paid runner
  purchase. Repository secret/variable inventories were empty when inspected.

Exact project/environment identifiers and CLI evidence are retained locally in
`.local/release-readiness/hosting.json`; do not confuse other client projects
with these resources.

## Database safety gate

Supabase backup inspection returned `backups: null`, `pitr_enabled: false` and
`walg_enabled: true`. The last flag alone does **not** prove that a usable backup
can be restored. No hosted migration history was obtained while the project was
inactive. Do not run migrations or assume that local tables are deployed.

Before a hosted database write:

1. Recover/activate the intended existing project through its authorized owner;
   verify recovery options and any cost first. Do not create a replacement or
   upgrade a plan without authorization.
2. Inspect existing schemas, migration history, roles and real-user data without
   exporting private rows into build logs.
3. Obtain and verify a recovery point or encrypted backup; establish how rollback
   would work before applying forward migrations.
4. Apply the reviewed missing migrations with the migration owner, never the API
   runtime role. Provision the restricted runtime role described in operations.
5. Configure and verify native auth redirect, email confirmation/recovery, SMTP,
   password policy and deletion against disposable accounts only.

## Backend/release configuration gate

The empty Railway project still needs a Go API service and server-side production
configuration. Provisioning/starting hosting can consume billable resources;
this pass did not create services or enable spending without a confirmed budget.
The server needs its dedicated database connection/CA, Supabase URL/public key,
metrics secret and the client's production OpenAI settings when AI is enabled.
Never copy a developer's OpenCode credentials into production.

Use a stable HTTPS API URL in installed builds. Verify `/readyz`, actual AI
recipient disclosure, cold/warm native callbacks and account lifecycle before
building the distributable artifact. Do not replace missing production settings
with localhost, a quick tunnel, a demo backend or compile-test fixture values.

## Result

**Hosted end-to-end release readiness is blocked.** Local and CI fixture builds
can validate code, native linking and app launch; they do not establish usable
production services or a distributable TestFlight release.
