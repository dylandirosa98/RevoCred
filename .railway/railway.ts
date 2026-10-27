// Railway Infrastructure as Code for the RevoCred API. See docs/railway.md.
//
// Only the Go API runs on Railway. The Flutter app ships through the App Store
// and Play Store, and Supabase hosts Auth and Postgres.
//
// Secrets are never written here. They are Railway shared variables on each
// environment and reach the service as ${{shared.NAME}} references.
import { defineRailway, github, project, service } from "railway/iac";

export default defineRailway((ctx) => {
  const api = service("api", {
    source: github("dylandirosa98/RevoCred", {
      branch: "main",
      rootDirectory: "revocred-api",
      // Deploy only after the GitHub "Verify" workflow passes.
      checkSuites: true,
    }),
    build: {
      builder: "DOCKERFILE",
      dockerfilePath: "Dockerfile",
      watchPatterns: ["/revocred-api/**"],
    },
    deploy: {
      healthcheckPath: "/readyz",
      healthcheckTimeout: 60,
      restartPolicyType: "ON_FAILURE",
      restartPolicyMaxRetries: 5,
      // Rate limits live in process memory; more replicas multiply them.
      numReplicas: 1,
      // Covers SHUTDOWN_TIMEOUT (10s) so in-flight requests finish.
      drainingSeconds: 15,
    },
    env: {
      APP_ENV: "production",
      // Railway's edge sets X-Real-IP; the container is only reachable through it.
      CLIENT_IP_HEADER: "X-Real-IP",
      DB_MAX_CONNS: "10",
      DATABASE_URL: ctx.shared.DATABASE_URL,
      DATABASE_CA_CERT: ctx.shared.DATABASE_CA_CERT,
      SUPABASE_URL: ctx.shared.SUPABASE_URL,
      SUPABASE_ANON_KEY: ctx.shared.SUPABASE_ANON_KEY,
      METRICS_TOKEN: ctx.shared.METRICS_TOKEN,
      // Production is OpenAI-only. The developer's OPENCODE_GO_* settings are
      // testing-only; see docs/railway.md. No key keeps deterministic replies.
      AI_API_KEY: ctx.shared.AI_API_KEY,
      AI_BASE_URL: ctx.shared.AI_BASE_URL,
      AI_MODEL: ctx.shared.AI_MODEL,
      AI_REASONING_EFFORT: ctx.shared.AI_REASONING_EFFORT,
    },
  });

  return project("RevoCred", { resources: [api] });
});
