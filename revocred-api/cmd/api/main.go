package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/revocred/revocred-api/internal/auth"
	"github.com/revocred/revocred-api/internal/carddata"
	"github.com/revocred/revocred-api/internal/chat"
	"github.com/revocred/revocred-api/internal/config"
	"github.com/revocred/revocred-api/internal/httpapi"
	"github.com/revocred/revocred-api/internal/recommendation"
	"github.com/revocred/revocred-api/internal/store"
)

func main() {
	if len(os.Args) == 2 && os.Args[1] == "--healthcheck" {
		port := os.Getenv("PORT")
		if port == "" {
			port = "8080"
		}
		client := &http.Client{Timeout: 3 * time.Second}
		response, err := client.Get("http://127.0.0.1:" + port + "/readyz")
		if err != nil {
			os.Exit(1)
		}
		defer response.Body.Close()
		if response.StatusCode != http.StatusOK {
			os.Exit(1)
		}
		return
	}
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if err := run(logger); err != nil {
		logger.Error("server stopped", "error", err)
		os.Exit(1)
	}
}

func run(logger *slog.Logger) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	poolConfig, err := pgxpool.ParseConfig(cfg.DatabaseURL)
	if err != nil {
		return errors.New("DATABASE_URL is invalid")
	}
	poolConfig.MaxConns = cfg.DatabaseMaxConns
	if cfg.DatabaseRootCAs != nil {
		// sslmode=verify-full still checks the host name; only the trusted
		// roots change.
		if poolConfig.ConnConfig.TLSConfig == nil {
			return errors.New("DATABASE_CA_CERT requires a TLS sslmode in DATABASE_URL")
		}
		poolConfig.ConnConfig.TLSConfig.RootCAs = cfg.DatabaseRootCAs
		for _, fallback := range poolConfig.ConnConfig.Fallbacks {
			if fallback.TLSConfig != nil {
				fallback.TLSConfig.RootCAs = cfg.DatabaseRootCAs
			}
		}
	}
	startupCtx, cancelStartup := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancelStartup()
	pool, err := pgxpool.NewWithConfig(startupCtx, poolConfig)
	if err != nil {
		return err
	}
	defer pool.Close()
	if err := pool.Ping(startupCtx); err != nil {
		return err
	}

	authClient := &http.Client{Timeout: 5 * time.Second}
	authenticator, err := auth.NewSupabaseAuthenticator(cfg.SupabaseURL, cfg.SupabaseAnonKey, authClient)
	if err != nil {
		return err
	}
	repository := store.NewPostgres(pool)
	// This public feed receives no member data. Load the durable snapshot first;
	// background network failures never block serving the core catalog.
	dataCtx, stopData := context.WithCancel(context.Background())
	defer stopData()
	if os.Getenv("OPENCARD_ENABLED") != "false" {
		cache := carddata.New(&http.Client{Timeout: 20 * time.Second}, repository, carddata.SourceURL)
		if err := cache.Load(startupCtx); err != nil {
			logger.Warn("OpenCard cache load failed", "error", err)
		}
		repository.UseCardData(cache)
		go cache.Run(dataCtx, func(err error) { logger.Warn("OpenCard refresh failed; retaining cached data", "error", err) })
	}
	chatProvider, err := chat.New(chat.Options{
		APIKey:          cfg.AIAPIKey,
		Model:           cfg.AIModel,
		BaseURL:         cfg.AIBaseURL,
		ReasoningEffort: cfg.AIReasoningEffort,
		Logger:          logger,
	})
	if err != nil {
		return err
	}
	handler := httpapi.New(
		repository,
		authenticator,
		recommendation.New(),
		chatProvider,
		logger,
		cfg.AllowedOrigins,
		cfg.RequestTimeout,
		httpapi.Options{MetricsToken: cfg.MetricsToken, ClientIPHeader: cfg.ClientIPHeader},
	)

	server := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       20 * time.Second,
		WriteTimeout:      50 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	shutdownSignal, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	serverErrors := make(chan error, 1)
	go func() {
		logger.Info("server listening", "address", server.Addr, "environment", cfg.Environment, "chat", chatProvider.Mode())
		serverErrors <- server.ListenAndServe()
	}()

	select {
	case err := <-serverErrors:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-shutdownSignal.Done():
		logger.Info("shutdown requested")
		ctx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
		defer cancel()
		if err := server.Shutdown(ctx); err != nil {
			return err
		}
		if err := <-serverErrors; err != nil && !errors.Is(err, http.ErrServerClosed) {
			return err
		}
		return nil
	}
}
