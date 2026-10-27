package config

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"math/big"
	"testing"
	"time"
)

func TestProductionRequiresVerifiedTLSAndRuntimeRole(t *testing.T) {
	for key, value := range map[string]string{"APP_ENV": "production", "DATABASE_URL": "postgresql://app:example@db.example.test/app?sslmode=verify-full", "SUPABASE_URL": "https://auth.example.test", "SUPABASE_ANON_KEY": "public", "CORS_ALLOWED_ORIGINS": "https://app.example.test", "METRICS_TOKEN": "test-only-32-character-metrics-secret"} {
		t.Setenv(key, value)
	}
	if _, err := Load(); err != nil {
		t.Fatal(err)
	}
	for _, url := range []string{"postgresql://postgres:example@db.example.test/app?sslmode=verify-full", "postgresql://app:example@db.example.test/app?sslmode=disable"} {
		t.Setenv("DATABASE_URL", url)
		if _, err := Load(); err == nil {
			t.Fatal("accepted unsafe production database URL")
		}
	}
}

func setMobileProductionEnv(t *testing.T) {
	for key, value := range map[string]string{"APP_ENV": "production", "DATABASE_URL": "postgresql://revocred_app.ref:example@pooler.example.test:5432/postgres?sslmode=verify-full", "SUPABASE_URL": "https://auth.example.test", "SUPABASE_ANON_KEY": "public", "CORS_ALLOWED_ORIGINS": "", "METRICS_TOKEN": "test-only-32-character-metrics-secret", "CLIENT_IP_HEADER": "X-Real-IP"} {
		t.Setenv(key, value)
	}
}

func TestMobileOnlyProductionNeedsNoBrowserOrigins(t *testing.T) {
	setMobileProductionEnv(t)
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.AllowedOrigins) != 0 || cfg.ClientIPHeader != "X-Real-IP" || cfg.DatabaseRootCAs != nil {
		t.Fatalf("unexpected config: %+v", cfg)
	}
}

func TestDatabaseCACertificate(t *testing.T) {
	setMobileProductionEnv(t)
	t.Setenv("DATABASE_CA_CERT", "not a certificate")
	if _, err := Load(); err == nil {
		t.Fatal("accepted an invalid DATABASE_CA_CERT")
	}
	t.Setenv("DATABASE_CA_CERT", testCertificatePEM(t))
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.DatabaseRootCAs == nil {
		t.Fatal("DATABASE_CA_CERT was not loaded")
	}
}

func testCertificatePEM(t *testing.T) string {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	template := &x509.Certificate{SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "test root"}, NotBefore: time.Now(), NotAfter: time.Now().Add(time.Hour), IsCA: true, BasicConstraintsValid: true}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	return string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}))
}

func TestAISettingsPreferNewNamesOverOpenCodeNames(t *testing.T) {
	setMobileProductionEnv(t)
	t.Setenv("APP_ENV", "development")
	t.Setenv("OPENCODE_GO_API_KEY", "oc_local")
	t.Setenv("OPENCODE_GO_MODEL", "deepseek-v4.1-flash")
	t.Setenv("OPENCODE_GO_BASE_URL", "https://opencode.ai/zen/go/v1/")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.AIAPIKey != "oc_local" || cfg.AIModel != "deepseek-v4.1-flash" || cfg.AIBaseURL != "https://opencode.ai/zen/go/v1" {
		t.Fatalf("OpenCode fallback: %+v", cfg)
	}
	t.Setenv("AI_API_KEY", "sk-railway")
	t.Setenv("AI_MODEL", "gpt-6-luna")
	t.Setenv("AI_BASE_URL", "https://api.openai.com/v1")
	t.Setenv("AI_REASONING_EFFORT", "None")
	cfg, err = Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.AIAPIKey != "sk-railway" || cfg.AIModel != "gpt-6-luna" || cfg.AIBaseURL != "https://api.openai.com/v1" || cfg.AIReasoningEffort != "none" {
		t.Fatalf("AI_* settings: %+v", cfg)
	}
}

func TestProductionAIRejectsTestingCredentialsAndRoutes(t *testing.T) {
	setMobileProductionEnv(t)
	for _, key := range []string{"AI_API_KEY", "AI_BASE_URL", "AI_MODEL", "OPENCODE_GO_API_KEY", "OPENCODE_GO_BASE_URL", "OPENCODE_GO_MODEL"} {
		t.Setenv(key, "")
	}
	t.Setenv("OPENCODE_GO_API_KEY", "test-only-go-key")
	if _, err := Load(); err == nil {
		t.Fatal("production accepted a testing Go key")
	}
	t.Setenv("AI_API_KEY", "sk-test-only-openai-key")
	t.Setenv("AI_MODEL", "configured-production-model")
	t.Setenv("AI_BASE_URL", "https://opencode.ai/zen/go/v1")
	if _, err := Load(); err == nil {
		t.Fatal("production accepted a testing AI endpoint")
	}
	t.Setenv("AI_BASE_URL", "https://api.openai.com/v1")
	if _, err := Load(); err != nil {
		t.Fatal(err)
	}
	t.Setenv("AI_BASE_URL", "")
	t.Setenv("OPENCODE_GO_BASE_URL", "https://api.openai.com/v1")
	if _, err := Load(); err == nil {
		t.Fatal("production inherited the testing endpoint")
	}
	t.Setenv("AI_BASE_URL", "https://api.openai.com/v1")
	t.Setenv("AI_MODEL", "")
	t.Setenv("OPENCODE_GO_MODEL", "deepseek-v4.1-flash")
	if _, err := Load(); err == nil {
		t.Fatal("production inherited the testing model")
	}
}
