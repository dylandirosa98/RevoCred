package store

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/revocred/revocred-api/internal/domain"
)

// SearchReferenceCards powers onboarding card selection. It is intentionally a
// separate, larger index than the vetted recommendation catalog.
func (p *Postgres) SearchReferenceCards(ctx context.Context, query string, limit int) ([]domain.ReferenceCard, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	tokens := SearchTokens(query)
	phrase := strings.Join(tokens, " ")
	// Every token must start a word somewhere in issuer, name or slug, so
	// "discover miles" and "amex gold" both work while "att" does not match
	// "Hyatt". Punctuation is ignored on both sides,
	// which is why "us bank" finds "U.S. Bank" and "att" finds "AT&T".
	rows, err := p.pool.Query(ctx, `
WITH candidates AS (
    SELECT r.*, regexp_replace(regexp_replace(lower(r.issuer || ' ' || r.name || ' ' || r.slug),
               '[.''&®™]', '', 'g'), '[^a-z0-9+]+', ' ', 'g') AS haystack,
           regexp_replace(regexp_replace(lower(r.name), '[.''&®™]', '', 'g'), '[^a-z0-9+]+', ' ', 'g') AS plain_name,
           trim(regexp_replace(regexp_replace(lower(r.issuer), '[.''&®™]', '', 'g'), '[^a-z0-9+]+', ' ', 'g')) AS plain_issuer
    FROM revocred.card_reference_index r
    WHERE r.is_active
), ranked AS (
    SELECT r.*,
           r.plain_name ~ '(aadvantage|amazon|atmos|best buy|bjs|choice privileges|costco|delta|hilton|home depot|hyatt|kohls|macys|marriott|one key|rei|southwest|spirit|t mobile|united)' AS partner_card,
           CASE
             WHEN r.plain_name ~ '(custom cash|double cash|venture x|sapphire preferred|platinum|gold)' THEN 1
             WHEN r.plain_name ~ '(strata premier|venture|sapphire reserve|blue cash preferred|active cash)' THEN 2
             WHEN r.plain_name ~ '(strata elite|savor|freedom unlimited|blue cash everyday|autograph journey)' THEN 3
             WHEN r.plain_name ~ '(quicksilver|freedom flex|green|autograph|discover it cash back)' THEN 4
             ELSE 100
           END AS core_rank
    FROM candidates r
)
SELECT r.id::text, r.slug, r.issuer, r.name, r.network, r.rewards_type, r.annual_fee_cents,
       r.reward_rates, r.terms_status, r.source_url, r.source_captured_on::text, r.disclaimer,
       COALESCE(c.id::text, '')
FROM ranked r
LEFT JOIN revocred.catalog_cards c
       ON c.owner_user_id IS NULL AND c.data_kind = 'issuer_snapshot'
      AND lower(c.name) = lower(r.name) AND lower(c.issuer) = lower(r.issuer)
WHERE NOT EXISTS (
    SELECT 1 FROM unnest($1::text[]) AS token WHERE position(' ' || token IN ' ' || r.haystack) = 0
)
ORDER BY (r.plain_name = $2) DESC,
         (r.plain_name LIKE $2 || '%') DESC,
         (r.plain_issuer = $2 AND NOT r.partner_card) DESC,
         CASE WHEN r.plain_issuer = $2 THEN r.core_rank ELSE 100 END,
         (position($2 IN r.haystack) > 0) DESC,
         (r.terms_status = 'verified') DESC,
         r.issuer, r.name
LIMIT $3`, tokens, phrase, limit)
	if err != nil {
		return nil, fmt.Errorf("search reference cards: %w", err)
	}
	defer rows.Close()
	cards := make([]domain.ReferenceCard, 0, limit)
	for rows.Next() {
		card, err := scanReferenceCard(rows)
		if err != nil {
			return nil, err
		}
		cards = append(cards, card)
	}
	return cards, rows.Err()
}

// issuerAliases maps what people type to the issuer names the index stores.
var issuerAliases = map[string]string{
	"amex":     "american express",
	"capone":   "capital one",
	"cap one":  "capital one",
	"c1":       "capital one",
	"bofa":     "bank of america",
	"boa":      "bank of america",
	"wf":       "wells fargo",
	"usbank":   "us bank",
	"usb":      "us bank",
	"citibank": "citi",
}

// SearchTokens normalises a search query the same way the SQL normalises card
// text: lowercase, dots, apostrophes and ampersands dropped, other punctuation
// treated as a space, and known issuer nicknames expanded.
func SearchTokens(query string) []string {
	normalized := strings.ToLower(query)
	normalized = strings.NewReplacer(".", "", "'", "", "’", "", "&", "", "®", "", "™", "").Replace(normalized)
	var b strings.Builder
	for _, r := range normalized {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '+' {
			b.WriteRune(r)
		} else {
			b.WriteRune(' ')
		}
	}
	normalized = " " + strings.Join(strings.Fields(b.String()), " ") + " "
	for alias, issuer := range issuerAliases {
		normalized = strings.ReplaceAll(normalized, " "+alias+" ", " "+issuer+" ")
	}
	tokens := strings.Fields(normalized)
	if tokens == nil {
		tokens = []string{}
	}
	return tokens
}

func (p *Postgres) referenceCardsByID(ctx context.Context, ids []string) (map[string]domain.ReferenceCard, error) {
	if len(ids) == 0 {
		return map[string]domain.ReferenceCard{}, nil
	}
	rows, err := p.pool.Query(ctx, `
SELECT r.id::text, r.slug, r.issuer, r.name, r.network, r.rewards_type, r.annual_fee_cents,
       r.reward_rates, r.terms_status, r.source_url, r.source_captured_on::text, r.disclaimer,
       COALESCE(c.id::text, '')
FROM revocred.card_reference_index r
LEFT JOIN revocred.catalog_cards c
       ON c.owner_user_id IS NULL AND c.data_kind = 'issuer_snapshot'
      AND lower(c.name) = lower(r.name) AND lower(c.issuer) = lower(r.issuer)
WHERE r.is_active AND r.id = ANY($1::uuid[])`, ids)
	if err != nil {
		return nil, fmt.Errorf("load reference cards: %w", err)
	}
	defer rows.Close()
	found := map[string]domain.ReferenceCard{}
	for rows.Next() {
		card, err := scanReferenceCard(rows)
		if err != nil {
			return nil, err
		}
		found[card.ID] = card
	}
	return found, rows.Err()
}

func scanReferenceCard(row rowScanner) (domain.ReferenceCard, error) {
	var card domain.ReferenceCard
	var rates []byte
	if err := row.Scan(&card.ID, &card.Slug, &card.Issuer, &card.Name, &card.Network,
		&card.RewardsType, &card.AnnualFeeCents, &rates, &card.TermsStatus, &card.SourceURL,
		&card.SourceCapturedOn, &card.Disclaimer, &card.CatalogCardID); err != nil {
		return domain.ReferenceCard{}, fmt.Errorf("scan reference card: %w", err)
	}
	if err := json.Unmarshal(rates, &card.RewardRates); err != nil {
		return domain.ReferenceCard{}, fmt.Errorf("decode reference rates: %w", err)
	}
	return card, nil
}

// resolveOnboardingCards turns index picks into wallet cards. A product that is
// already vetted keeps its sourced terms. Otherwise an owned user_supplied card
// is created: with the user's own terms when supplied, or without any terms when
// they skipped, which keeps it out of scoring.
func (p *Postgres) resolveOnboardingCards(ctx context.Context, userID string, picks []domain.OnboardingCard, existing []string) ([]string, error) {
	ids := make([]string, 0, len(picks)+len(existing))
	ids = append(ids, existing...)
	byID := map[string]bool{}
	for _, id := range ids {
		byID[id] = true
	}
	if len(picks) == 0 {
		return ids, nil
	}
	wanted := make([]string, 0, len(picks))
	for _, pick := range picks {
		wanted = append(wanted, pick.ReferenceID)
	}
	references, err := p.referenceCardsByID(ctx, wanted)
	if err != nil {
		return nil, err
	}
	seen := map[string]bool{}
	for _, pick := range picks {
		reference, ok := references[pick.ReferenceID]
		if !ok {
			return nil, ErrNotFound
		}
		// Never create a second copy of a product the vetted catalog already
		// models: its sourced terms are better than anything a user types.
		if reference.CatalogCardID != "" {
			if !byID[reference.CatalogCardID] {
				ids = append(ids, reference.CatalogCardID)
				byID[reference.CatalogCardID] = true
			}
			continue
		}
		key := strings.ToLower(reference.Issuer + "|" + reference.Name)
		if seen[key] {
			continue
		}
		seen[key] = true
		draft := domain.CreateCustomCard{
			Name:              reference.Name,
			Issuer:            reference.Issuer,
			Network:           reference.Network,
			RewardRates:       map[string]float64{},
			TravelScope:       "none",
			RewardsType:       reference.RewardsType,
			MinimumCreditTier: "good",
			TermsUnknown:      true,
		}
		if pick.IncludeTerms {
			// The user's own terms win, because that is the card they hold.
			draft.TermsUnknown = false
			draft.AnnualFeeCents = pick.AnnualFeeCents
			draft.RewardRates = pick.RewardRates
			draft.TransferablePoints = pick.Transferable
			draft.BestUse = pick.BestUse
			draft.MinimumCreditTier = pick.MinimumTier
			draft.Benefits = []string{"Terms supplied by the cardholder"}
		} else {
			draft.Benefits = []string{"Terms not supplied; excluded from wallet score and value"}
		}
		if draft.RewardsType == "unknown" {
			draft.RewardsType = "cash_back"
		}
		created, err := p.CreateCustomCard(ctx, userID, draft)
		if err != nil {
			if errors.Is(err, ErrConflict) {
				continue
			}
			return nil, err
		}
		ids = append(ids, created.CatalogCardID)
		byID[created.CatalogCardID] = true
	}
	return ids, nil
}

// Substitutions returns approved replacements keyed by the strategy card's
// display name. They are candidates only; Bootstrap uses one exclusively when
// that replacement is already present in the member's wallet.
func (p *Postgres) Substitutions(ctx context.Context) (map[string][]domain.Substitution, error) {
	rows, err := p.pool.Query(ctx, `
SELECT target.name, replacement.id::text, replacement.name
FROM revocred.card_substitutions s
JOIN revocred.catalog_cards target ON target.id = s.strategy_card_id
JOIN revocred.catalog_cards replacement ON replacement.id = s.substitute_card_id
WHERE s.approved
  AND target.is_active AND target.owner_user_id IS NULL AND target.data_kind='issuer_snapshot'
  AND replacement.is_active AND replacement.owner_user_id IS NULL AND replacement.data_kind='issuer_snapshot'
ORDER BY target.name, replacement.name`)
	if err != nil {
		return nil, fmt.Errorf("load substitutions: %w", err)
	}
	defer rows.Close()
	result := map[string][]domain.Substitution{}
	for rows.Next() {
		var strategyName string
		var substitute domain.Substitution
		if err := rows.Scan(&strategyName, &substitute.CardID, &substitute.Name); err != nil {
			return nil, fmt.Errorf("scan substitution: %w", err)
		}
		result[strategyName] = append(result[strategyName], substitute)
	}
	return result, rows.Err()
}
