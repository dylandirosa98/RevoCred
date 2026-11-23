// moderation is an operator-only triage tool for reported REVO replies.
// Database credentials are read strictly from MODERATION_DATABASE_URL (and
// optional DATABASE_CA_CERT), never from command-line arguments or the client.
package main

import (
	"context"
	"crypto/x509"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"text/tabwriter"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/revocred/revocred-api/internal/moderation"
	"github.com/revocred/revocred-api/internal/store"
)

const usageText = `Usage:
  moderation list [-status open|reviewed|actioned|dismissed|all] [-rating down|up|all] [-reason TEXT] [-since YYYY-MM-DD|RFC3339] [-limit N] [-json]
  moderation show [-json] <message-id>
  moderation resolve -status reviewed|actioned|dismissed --by OPERATOR [--note TEXT] [-json] <message-id>
  moderation reviewed|actioned|dismissed --by OPERATOR [--note TEXT] [-json] <message-id>

Environment:
  MODERATION_DATABASE_URL  Required operator Postgres connection URL (never passed as a flag).
  DATABASE_CA_CERT         Optional PEM CA certificate for sslmode=verify-full connections.
`

type moderationStore interface {
	ListModerationReports(ctx context.Context, filter moderation.ListFilter) ([]moderation.ReportSummary, error)
	GetModerationReport(ctx context.Context, messageID string) (moderation.ReportDetail, error)
	ResolveModerationReport(ctx context.Context, res moderation.Resolution) (moderation.ReportSummary, error)
}

type storeConnector func(ctx context.Context, databaseURL, caCertPEM string) (moderationStore, func(), error)

func main() {
	if err := run(os.Args[1:], os.Getenv, connectPostgres, os.Stdout, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(args []string, getenv func(string) string, connect storeConnector, stdout, stderr io.Writer) error {
	if len(args) == 0 || args[0] == "-h" || args[0] == "--help" || args[0] == "help" {
		_, _ = io.WriteString(stderr, usageText)
		if len(args) == 0 {
			return errors.New("subcommand required: list, show, resolve, reviewed, actioned, or dismissed")
		}
		return nil
	}

	subcmd := strings.ToLower(strings.TrimSpace(args[0]))
	subArgs := args[1:]

	switch subcmd {
	case "list":
		return runList(subArgs, getenv, connect, stdout)
	case "show":
		return runShow(subArgs, getenv, connect, stdout)
	case "resolve":
		return runResolve("", subArgs, getenv, connect, stdout)
	case moderation.StatusReviewed, moderation.StatusActioned, moderation.StatusDismissed:
		return runResolve(subcmd, subArgs, getenv, connect, stdout)
	default:
		_, _ = io.WriteString(stderr, usageText)
		return fmt.Errorf("unknown subcommand %q", args[0])
	}
}

func runList(args []string, getenv func(string) string, connect storeConnector, stdout io.Writer) error {
	fs := flag.NewFlagSet("list", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	status := fs.String("status", moderation.StatusOpen, "filter by status: open, reviewed, actioned, dismissed, or all")
	rating := fs.String("rating", "down", "filter by rating: down, up, or all")
	reason := fs.String("reason", "", "case-insensitive substring match against report reason")
	sinceRaw := fs.String("since", "", "include reports created at or after YYYY-MM-DD or RFC3339 (UTC)")
	limit := fs.Int("limit", moderation.DefaultListLimit, "maximum reports to return (1-500)")
	asJSON := fs.Bool("json", false, "output JSON")
	if err := fs.Parse(args); err != nil {
		return fmt.Errorf("invalid list flags: %w", err)
	}
	if fs.NArg() != 0 {
		return errors.New("list takes no positional arguments")
	}
	var since *time.Time
	if strings.TrimSpace(*sinceRaw) != "" {
		parsed, err := parseSince(*sinceRaw)
		if err != nil {
			return err
		}
		since = &parsed
	}
	filter, err := (moderation.ListFilter{
		Status: *status,
		Rating: *rating,
		Reason: *reason,
		Since:  since,
		Limit:  *limit,
	}).Normalize()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	repo, closeFn, err := openStore(ctx, getenv, connect)
	if err != nil {
		return err
	}
	defer closeFn()

	reports, err := repo.ListModerationReports(ctx, filter)
	if err != nil {
		return errors.New("failed to list moderation reports: verify operator database access and migration 32")
	}
	if *asJSON {
		return writeIndentedJSON(stdout, reports)
	}
	return writeReportTable(stdout, reports)
}

func runShow(args []string, getenv func(string) string, connect storeConnector, stdout io.Writer) error {
	fs := flag.NewFlagSet("show", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	idFlag := fs.String("id", "", "reported message UUID")
	asJSON := fs.Bool("json", false, "output JSON")
	normalizedArgs, positional := splitFlagsAndPositional(args, map[string]bool{"id": true})
	if err := fs.Parse(normalizedArgs); err != nil {
		return fmt.Errorf("invalid show flags: %w", err)
	}
	messageID, err := pickSingleID(*idFlag, positional)
	if err != nil {
		return err
	}
	if !moderation.ValidUUID(messageID) {
		return errors.New("message ID must be a valid UUID")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	repo, closeFn, err := openStore(ctx, getenv, connect)
	if err != nil {
		return err
	}
	defer closeFn()

	detail, err := repo.GetModerationReport(ctx, messageID)
	if errors.Is(err, store.ErrNotFound) {
		return errors.New("moderation report not found")
	}
	if err != nil {
		return errors.New("failed to load moderation report: verify operator database access and migration 32")
	}
	if *asJSON {
		return writeIndentedJSON(stdout, detail)
	}
	return writeReportDetail(stdout, detail)
}

func runResolve(fixedStatus string, args []string, getenv func(string) string, connect storeConnector, stdout io.Writer) error {
	name := fixedStatus
	if name == "" {
		name = "resolve"
	}
	fs := flag.NewFlagSet(name, flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	idFlag := fs.String("id", "", "reported message UUID")
	statusFlag := fs.String("status", fixedStatus, "resolution status: reviewed, actioned, or dismissed")
	by := fs.String("by", "", "operator identity recording the triage decision")
	note := fs.String("note", "", "optional operator resolution note")
	asJSON := fs.Bool("json", false, "output JSON")

	valueFlags := map[string]bool{"id": true, "by": true, "note": true}
	if fixedStatus == "" {
		valueFlags["status"] = true
	}
	normalizedArgs, positional := splitFlagsAndPositional(args, valueFlags)
	if err := fs.Parse(normalizedArgs); err != nil {
		return fmt.Errorf("invalid %s flags: %w", name, err)
	}
	messageID, err := pickSingleID(*idFlag, positional)
	if err != nil {
		return err
	}
	chosenStatus := fixedStatus
	if chosenStatus == "" {
		chosenStatus = *statusFlag
	}
	res, err := (moderation.Resolution{
		MessageID:  messageID,
		Status:     chosenStatus,
		ReviewedBy: *by,
		Note:       *note,
	}).Normalize()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	repo, closeFn, err := openStore(ctx, getenv, connect)
	if err != nil {
		return err
	}
	defer closeFn()

	updated, err := repo.ResolveModerationReport(ctx, res)
	if errors.Is(err, store.ErrNotFound) {
		return errors.New("moderation report not found")
	}
	if err != nil {
		return errors.New("failed to update moderation report: verify operator database access and migration 32")
	}
	if *asJSON {
		return writeIndentedJSON(stdout, updated)
	}
	reviewedAt := ""
	if updated.ReviewedAt != nil {
		reviewedAt = updated.ReviewedAt.UTC().Format(time.RFC3339)
	}
	_, err = fmt.Fprintf(stdout, "Updated %s -> status=%s by=%s at=%s\n", updated.MessageID, updated.Status, updated.ReviewedBy, reviewedAt)
	return err
}

func openStore(ctx context.Context, getenv func(string) string, connect storeConnector) (moderationStore, func(), error) {
	databaseURL := strings.TrimSpace(getenv("MODERATION_DATABASE_URL"))
	if databaseURL == "" {
		return nil, nil, errors.New("set MODERATION_DATABASE_URL to an operator database connection")
	}
	return connect(ctx, databaseURL, strings.TrimSpace(getenv("DATABASE_CA_CERT")))
}

func connectPostgres(ctx context.Context, databaseURL, caCertPEM string) (moderationStore, func(), error) {
	poolConfig, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, nil, errors.New("invalid MODERATION_DATABASE_URL")
	}
	if caCertPEM != "" {
		roots := x509.NewCertPool()
		if !roots.AppendCertsFromPEM([]byte(caCertPEM)) {
			return nil, nil, errors.New("DATABASE_CA_CERT must contain a valid PEM certificate")
		}
		if poolConfig.ConnConfig.TLSConfig == nil {
			return nil, nil, errors.New("DATABASE_CA_CERT requires a TLS sslmode in MODERATION_DATABASE_URL")
		}
		poolConfig.ConnConfig.TLSConfig.RootCAs = roots
		for _, fallback := range poolConfig.ConnConfig.Fallbacks {
			if fallback.TLSConfig != nil {
				fallback.TLSConfig.RootCAs = roots
			}
		}
	}
	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, nil, errors.New("cannot connect with MODERATION_DATABASE_URL")
	}
	return store.NewPostgres(pool), pool.Close, nil
}

func parseSince(raw string) (time.Time, error) {
	trimmed := strings.TrimSpace(raw)
	if t, err := time.Parse(time.RFC3339, trimmed); err == nil {
		return t.UTC(), nil
	}
	if t, err := time.Parse("2006-01-02", trimmed); err == nil {
		return t.UTC(), nil
	}
	return time.Time{}, errors.New("invalid -since timestamp: use YYYY-MM-DD or RFC3339")
}

// splitFlagsAndPositional lets operators place the message UUID either before
// or after flags (for example: `moderation show <id> -json`).
func splitFlagsAndPositional(args []string, valueFlags map[string]bool) (flagArgs, positional []string) {
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if arg == "--" {
			positional = append(positional, args[i+1:]...)
			break
		}
		if !strings.HasPrefix(arg, "-") || arg == "-" {
			positional = append(positional, arg)
			continue
		}
		flagArgs = append(flagArgs, arg)
		trimmed := strings.TrimLeft(arg, "-")
		if strings.Contains(trimmed, "=") {
			continue
		}
		if valueFlags[trimmed] && i+1 < len(args) {
			i++
			flagArgs = append(flagArgs, args[i])
		}
	}
	return flagArgs, positional
}

func pickSingleID(flagID string, positional []string) (string, error) {
	flagID = strings.TrimSpace(flagID)
	if flagID != "" && len(positional) > 0 {
		return "", errors.New("specify message ID either positionally or with -id, not both")
	}
	if flagID != "" {
		return flagID, nil
	}
	if len(positional) != 1 {
		return "", errors.New("expected exactly one message UUID")
	}
	return strings.TrimSpace(positional[0]), nil
}

func writeIndentedJSON(w io.Writer, value any) error {
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	return encoder.Encode(value)
}

func writeReportTable(w io.Writer, reports []moderation.ReportSummary) error {
	if len(reports) == 0 {
		_, err := fmt.Fprintln(w, "No moderation reports matched.")
		return err
	}
	tw := tabwriter.NewWriter(w, 0, 2, 2, ' ', 0)
	_, _ = fmt.Fprintln(tw, "MESSAGE_ID\tSTATUS\tCREATED_AT\tREASON\tPROMPT_SNIPPET\tASSISTANT_SNIPPET")
	for _, r := range reports {
		_, _ = fmt.Fprintf(
			tw,
			"%s\t%s\t%s\t%s\t%s\t%s\n",
			r.MessageID,
			r.Status,
			r.CreatedAt.UTC().Format(time.RFC3339),
			moderation.Snippet(r.Reason, 60),
			moderation.Snippet(r.PromptSnippet, 60),
			moderation.Snippet(r.AssistantSnippet, 60),
		)
	}
	return tw.Flush()
}

func writeReportDetail(w io.Writer, d moderation.ReportDetail) error {
	_, _ = fmt.Fprintf(w, "Message ID:   %s\n", d.MessageID)
	_, _ = fmt.Fprintf(w, "Status:       %s\n", d.Status)
	_, _ = fmt.Fprintf(w, "Rating:       %s\n", d.Rating)
	if d.Mode != "" {
		_, _ = fmt.Fprintf(w, "Mode:         %s\n", d.Mode)
	}
	_, _ = fmt.Fprintf(w, "Reason:       %s\n", d.Reason)
	_, _ = fmt.Fprintf(w, "Reported At:  %s\n", d.CreatedAt.UTC().Format(time.RFC3339))
	_, _ = fmt.Fprintf(w, "Updated At:   %s\n", d.UpdatedAt.UTC().Format(time.RFC3339))
	if d.ReviewedBy != "" {
		reviewedAt := ""
		if d.ReviewedAt != nil {
			reviewedAt = d.ReviewedAt.UTC().Format(time.RFC3339)
		}
		_, _ = fmt.Fprintf(w, "Reviewed By:  %s (%s)\n", d.ReviewedBy, reviewedAt)
	}
	if d.ResolutionNote != "" {
		_, _ = fmt.Fprintf(w, "Note:         %s\n", d.ResolutionNote)
	}
	_, _ = fmt.Fprintln(w, "\n--- Turn Context (Redacted) ---")
	if len(d.ContextTurns) > 0 {
		for _, turn := range d.ContextTurns {
			marker := ""
			if turn.Reported {
				marker = " [REPORTED]"
			}
			mode := ""
			if turn.Mode != "" {
				mode = " (" + turn.Mode + ")"
			}
			_, _ = fmt.Fprintf(w, "\n[%s] %s%s%s:\n%s\n", turn.CreatedAt.UTC().Format(time.RFC3339), strings.ToUpper(turn.Role), mode, marker, turn.Content)
		}
		return nil
	}
	_, _ = fmt.Fprintf(w, "\nUSER:\n%s\n\nASSISTANT [REPORTED]:\n%s\n", d.UserPrompt, d.AssistantReply)
	return nil
}
