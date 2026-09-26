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
	pattern := "%" + strings.ToLower(strings.TrimSpace(query)) + "%"
	rows, err := p.pool.Query(ctx, `
SELECT r.id::text, r.slug, r.issuer, r.name, r.network, r.rewards_type, r.annual_fee_cents,
       r.reward_rates, r.terms_status, r.source_url, r.source_captured_on::text, r.disclaimer,
       COALESCE(c.id::text, '')
FROM revocred.card_reference_index r
LEFT JOIN revocred.catalog_cards c
       ON c.owner_user_id IS NULL AND c.data_kind = 'issuer_snapshot'
      AND lower(c.name) = lower(r.name) AND lower(c.issuer) = lower(r.issuer)
WHERE r.is_active
  AND ($1 = '%%' OR lower(r.name) LIKE $1 OR lower(r.issuer) LIKE $1 OR lower(r.slug) LIKE $1)
ORDER BY (lower(r.issuer) = lower($2)) DESC, r.issuer, r.name
LIMIT $3`, pattern, strings.TrimSpace(query), limit)
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

// Substitutions returns approved replacements for strategy cards, keyed by the
// card the strategy would otherwise have used.
func (p *Postgres) Substitutions(ctx context.Context) (map[string]domain.Substitution, error) {
	rows, err := p.pool.Query(ctx, `
SELECT s.strategy_card_id::text, c.id::text, c.name
FROM revocred.card_substitutions s
JOIN revocred.catalog_cards c ON c.id = s.substitute_card_id
WHERE s.approved AND c.is_active AND c.owner_user_id IS NULL AND c.data_kind='issuer_snapshot'`)
	if err != nil {
		return nil, fmt.Errorf("load substitutions: %w", err)
	}
	defer rows.Close()
	result := map[string]domain.Substitution{}
	for rows.Next() {
		var strategyID string
		var substitute domain.Substitution
		if err := rows.Scan(&strategyID, &substitute.CardID, &substitute.Name); err != nil {
			return nil, fmt.Errorf("scan substitution: %w", err)
		}
		result[strategyID] = substitute
	}
	return result, rows.Err()
}
