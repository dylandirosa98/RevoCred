package config

import "testing"

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
