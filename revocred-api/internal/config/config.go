package config

import (
	"crypto/x509"
	"errors"
	"fmt"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Environment      string
	Port             string
	DatabaseURL      string
	SupabaseURL      string
	SupabaseAnonKey  string
	AllowedOrigins   []string
	RequestTimeout   time.Duration
	ShutdownTimeout  time.Duration
	DatabaseMaxConns int32
	MetricsToken     string
	// AI settings for REVO explanations. Any OpenAI-compatible Chat
	// Completions provider works; empty AIAPIKey keeps the deterministic
	// explainer.
	AIAPIKey          string
	AIModel           string
	AIBaseURL         string
	AIReasoningEffort string
	// DatabaseRootCAs verifies the database server when the provider's CA is
	// not in the system bundle (Supabase). Nil means use system roots.
	DatabaseRootCAs *x509.CertPool
	// ClientIPHeader is a trusted edge-proxy header carrying the client IP.
	ClientIPHeader string
}

func Load() (Config, error) {
	cfg := Config{
		Environment:       valueOrDefault("APP_ENV", "development"),
		Port:              valueOrDefault("PORT", "8080"),
		DatabaseURL:       strings.TrimSpace(os.Getenv("DATABASE_URL")),
		SupabaseURL:       strings.TrimRight(strings.TrimSpace(os.Getenv("SUPABASE_URL")), "/"),
		SupabaseAnonKey:   strings.TrimSpace(os.Getenv("SUPABASE_ANON_KEY")),
		MetricsToken:      strings.TrimSpace(os.Getenv("METRICS_TOKEN")),
		ClientIPHeader:    strings.TrimSpace(os.Getenv("CLIENT_IP_HEADER")),
		AIAPIKey:          firstValue("AI_API_KEY", "OPENCODE_GO_API_KEY"),
		AIModel:           firstValue("AI_MODEL", "OPENCODE_GO_MODEL"),
		AIBaseURL:         strings.TrimRight(firstValue("AI_BASE_URL", "OPENCODE_GO_BASE_URL"), "/"),
		AIReasoningEffort: strings.ToLower(strings.TrimSpace(os.Getenv("AI_REASONING_EFFORT"))),
	}
	var err error
	if cfg.RequestTimeout, err = durationOrDefault("REQUEST_TIMEOUT", 30*time.Second); err != nil {
		return Config{}, err
	}
	if cfg.ShutdownTimeout, err = durationOrDefault("SHUTDOWN_TIMEOUT", 10*time.Second); err != nil {
		return Config{}, err
	}
	maxConns, err := strconv.ParseInt(valueOrDefault("DB_MAX_CONNS", "10"), 10, 32)
	if err != nil || maxConns < 1 {
		return Config{}, errors.New("DB_MAX_CONNS must be a positive integer")
	}
	cfg.DatabaseMaxConns = int32(maxConns)
	if pem := strings.TrimSpace(os.Getenv("DATABASE_CA_CERT")); pem != "" {
		cfg.DatabaseRootCAs = x509.NewCertPool()
		if !cfg.DatabaseRootCAs.AppendCertsFromPEM([]byte(pem)) {
			return Config{}, errors.New("DATABASE_CA_CERT must contain a PEM certificate")
		}
	}

	for _, origin := range strings.Split(os.Getenv("CORS_ALLOWED_ORIGINS"), ",") {
		if origin = strings.TrimSpace(origin); origin != "" {
			if origin == "*" {
				return Config{}, errors.New("CORS_ALLOWED_ORIGINS must list explicit origins; wildcard is not allowed")
			}
			cfg.AllowedOrigins = append(cfg.AllowedOrigins, strings.TrimRight(origin, "/"))
		}
	}

	// CORS_ALLOWED_ORIGINS may be empty for a mobile-only deployment: native
	// apps send no Origin, and browser requests are then rejected.
	missing := make([]string, 0, 3)
	for name, value := range map[string]string{
		"DATABASE_URL":      cfg.DatabaseURL,
		"SUPABASE_URL":      cfg.SupabaseURL,
		"SUPABASE_ANON_KEY": cfg.SupabaseAnonKey,
	} {
		if value == "" {
			missing = append(missing, name)
		}
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		return Config{}, fmt.Errorf("missing required environment variables: %s", strings.Join(missing, ", "))
	}
	if cfg.Environment == "production" {
		// Production is OpenAI-only. Never inherit a developer's legacy Go key
		// or silently route production prompts through a testing subscription.
		if cfg.AIAPIKey != "" && (!strings.HasPrefix(strings.TrimSpace(os.Getenv("AI_API_KEY")), "sk-") ||
			strings.TrimRight(strings.TrimSpace(os.Getenv("AI_BASE_URL")), "/") != "https://api.openai.com/v1" || strings.TrimSpace(os.Getenv("AI_MODEL")) == "") {
			return Config{}, errors.New("production AI requires explicit AI_API_KEY, AI_BASE_URL=https://api.openai.com/v1 and AI_MODEL; OPENCODE_GO_* is testing-only")
		}
		if len(cfg.MetricsToken) < 32 {
			return Config{}, errors.New("production requires METRICS_TOKEN of at least 32 characters")
		}
		if !strings.HasPrefix(cfg.SupabaseURL, "https://") {
			return Config{}, errors.New("production requires HTTPS Supabase")
		}
		db, err := url.Parse(cfg.DatabaseURL)
		if err != nil || db.Query().Get("sslmode") != "verify-full" {
			return Config{}, errors.New("production DATABASE_URL must use sslmode=verify-full")
		}
		if db.User == nil || db.User.Username() == "postgres" || strings.HasPrefix(db.User.Username(), "postgres.") {
			return Config{}, errors.New("production requires a dedicated database runtime role")
		}
		for _, origin := range cfg.AllowedOrigins {
			u, err := url.Parse(origin)
			if err != nil || u.Scheme != "https" || u.Host == "" || u.Path != "" || u.RawQuery != "" || u.Fragment != "" {
				return Config{}, errors.New("production CORS origins must be HTTPS origins without paths")
			}
		}
	}
	if cfg.RequestTimeout > 45*time.Second {
		return Config{}, errors.New("REQUEST_TIMEOUT must not exceed 45s")
	}
	return cfg, nil
}

func valueOrDefault(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}

// firstValue reads the preferred variable, then its older name, so existing
// OPENCODE_GO_* local setups keep working.
func firstValue(names ...string) string {
	for _, name := range names {
		if value := strings.TrimSpace(os.Getenv(name)); value != "" {
			return value
		}
	}
	return ""
}

func durationOrDefault(name string, fallback time.Duration) (time.Duration, error) {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return fallback, nil
	}
	duration, err := time.ParseDuration(value)
	if err != nil || duration <= 0 {
		return 0, fmt.Errorf("%s must be a positive duration", name)
	}
	return duration, nil
}
