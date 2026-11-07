package store

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/recommendation"
	"github.com/revocred/revocred-api/internal/strategy"
)

type issuedRecommendation struct {
	StrategyCode string
	CardID       string
	IssuedAt     time.Time
}

// Issuance is backend selection, not proof of an application or screen view.
// Only canonical catalog UUIDs can enter history; names are display metadata.
func (p *Postgres) recordIssuedRecommendation(ctx context.Context, userID, code string, item *domain.RecommendationItem, at time.Time, source, runID string) error {
	if item == nil {
		return nil
	}
	if _, ok := strategy.DefinitionFor(strategy.Code(code)); !ok {
		return nil
	}
	var canonical bool
	err := p.pool.QueryRow(ctx, `
WITH canonical AS (SELECT id FROM revocred.catalog_cards WHERE id::text=$3 AND owner_user_id IS NULL AND data_kind='issuer_snapshot'),
recorded AS (
INSERT INTO revocred.issued_recommendations(user_id,strategy_code,catalog_card_id,issued_at,source,source_run_id)
SELECT $1,$2,c.id,COALESCE($4::timestamptz,now()),$5,NULLIF($6,'')::uuid
FROM canonical c
ON CONFLICT (user_id,strategy_code,catalog_card_id) DO NOTHING RETURNING 1)
SELECT EXISTS(SELECT 1 FROM canonical)`, userID, code, item.CardID, nullableIssuedTime(at), source, runID).Scan(&canonical)
	if err != nil {
		return fmt.Errorf("record issued recommendation: %w", err)
	}
	if !canonical {
		return fmt.Errorf("issued recommendation is not an exact canonical catalog product")
	}
	return nil
}

func nullableIssuedTime(at time.Time) any {
	if at.IsZero() {
		return nil
	}
	return at
}

func (p *Postgres) completedIssuedRecommendations(ctx context.Context, userID, code string, wallet []domain.WalletCard) ([]domain.WalletCard, error) {
	rows, err := p.pool.Query(ctx, `SELECT strategy_code,catalog_card_id::text,issued_at FROM revocred.issued_recommendations WHERE user_id=$1 ORDER BY issued_at,catalog_card_id`, userID)
	if err != nil {
		return nil, fmt.Errorf("load issued recommendations: %w", err)
	}
	issued := []issuedRecommendation{}
	known := map[string]bool{}
	for rows.Next() {
		var item issuedRecommendation
		if err = rows.Scan(&item.StrategyCode, &item.CardID, &item.IssuedAt); err != nil {
			rows.Close()
			return nil, err
		}
		issued = append(issued, item)
		known[item.StrategyCode+":"+item.CardID] = true
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return nil, err
	}
	// Supported old save paths selected the strategy from their immutable
	// questionnaire. The provenance explicitly identifies this recovery;
	// unsaved legacy Bootstrap suggestions cannot be reconstructed.
	rows, err = p.pool.Query(ctx, `
SELECT r.id::text,r.created_at,ri.catalog_card_id::text,q.credit_tier,q.rewards_goal,q.fee_tolerance_cents,q.travel_scope
FROM revocred.recommendation_runs r
JOIN revocred.recommendation_items ri ON ri.recommendation_run_id=r.id AND ri.rank=1
JOIN revocred.questionnaire_responses q ON q.id=r.questionnaire_response_id AND q.user_id=r.user_id
JOIN revocred.catalog_cards c ON c.id=ri.catalog_card_id AND c.owner_user_id IS NULL AND c.data_kind='issuer_snapshot'
WHERE r.user_id=$1 AND r.engine_version=$2 ORDER BY r.created_at,r.id`, userID, recommendation.EngineVersion)
	if err != nil {
		return nil, err
	}
	type legacy struct {
		runID  string
		at     time.Time
		cardID string
		input  domain.RecommendationInput
	}
	pending := []legacy{}
	for rows.Next() {
		var item legacy
		if err = rows.Scan(&item.runID, &item.at, &item.cardID, &item.input.CreditTier, &item.input.RewardsGoal, &item.input.FeeToleranceCents, &item.input.TravelScope); err != nil {
			rows.Close()
			return nil, err
		}
		pending = append(pending, item)
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return nil, err
	}
	for _, old := range pending {
		derived := onboardingStrategy(old.input)
		if derived == "" || known[derived+":"+old.cardID] {
			continue
		}
		item := domain.RecommendationItem{CardID: old.cardID}
		if err = p.recordIssuedRecommendation(ctx, userID, derived, &item, old.at, "legacy_questionnaire_rank1", old.runID); err != nil {
			return nil, err
		}
		issued = append(issued, issuedRecommendation{derived, old.cardID, old.at})
		known[derived+":"+old.cardID] = true
	}
	sort.SliceStable(issued, func(i, j int) bool {
		if issued[i].IssuedAt.Equal(issued[j].IssuedAt) {
			return issued[i].CardID < issued[j].CardID
		}
		return issued[i].IssuedAt.Before(issued[j].IssuedAt)
	})
	active := map[string]domain.WalletCard{}
	for _, held := range wallet {
		if held.Status == "active" && held.Card != nil && held.Card.ID == held.CatalogCardID {
			active[held.CatalogCardID] = held
		}
	}
	completed := []domain.WalletCard{}
	for _, item := range issued {
		if item.StrategyCode != code {
			continue
		}
		if held, ok := active[item.CardID]; ok && !held.CreatedAt.Before(item.IssuedAt) {
			completed = append(completed, held)
		}
	}
	return completed, nil
}

// Preserve genuine completed recommendations as their own personalized steps.
// Do not claim an outside-template card fills a different matrix role.
func restoreCompletedRecommendations(playbook *strategy.Playbook, completed, wallet []domain.WalletCard) {
	ordered := append([]domain.WalletCard{}, completed...)
	sort.SliceStable(ordered, func(i, j int) bool {
		if ordered[i].CreatedAt.Equal(ordered[j].CreatedAt) {
			return ordered[i].CatalogCardID < ordered[j].CatalogCardID
		}
		return ordered[i].CreatedAt.Before(ordered[j].CreatedAt)
	})
	for order, held := range ordered {
		if held.Status != "active" || held.Card == nil || held.CatalogCardID != held.Card.ID {
			continue
		}
		found := false
		for i := range playbook.Steps {
			step := &playbook.Steps[i]
			// Only the exact issued product can complete. Family coverage of a
			// different template role would slide later cards into earlier slots.
			match := step.Name == held.Card.Name && (step.CardID == "" || step.CardID == held.CatalogCardID)
			if match {
				step.CardID = held.CatalogCardID
				step.Status = "have"
				step.CoveredBy = held.Card.Name
				step.CompletedRecommendation = true
				step.CompletedOrder = order + 1
				found = true
				break
			}
		}
		if found {
			continue
		}
		playbook.Steps = append(playbook.Steps, strategy.PlaybookStep{
			CardID: held.CatalogCardID, Name: held.Card.Name, Status: "have", CoveredBy: held.Card.Name,
			CompletedRecommendation: true, Use: "Previously recommended by RevoCred; now in your wallet.",
			CompletedOrder: order + 1,
			Note:           "Completed recommendation. No new application needed. This does not replace a different template role.",
		})
	}
}

func detachIssuedFamilyCoverage(playbook *strategy.Playbook, completed []domain.WalletCard) {
	issuedName := map[string]string{}
	for _, held := range completed {
		if held.Card != nil {
			issuedName[held.CatalogCardID] = held.Card.Name
		}
	}
	for i := range playbook.Steps {
		step := &playbook.Steps[i]
		name, issuedID := issuedName[step.CardID]
		coveredByIssued := false
		for _, issued := range issuedName {
			if step.CoveredBy == issued && step.Name != issued {
				coveredByIssued = true
				break
			}
		}
		if (issuedID && name != step.Name) || coveredByIssued {
			step.Status = "later"
			step.CoveredBy = ""
			step.Note = ""
			step.CompletedRecommendation = false
			step.CompletedOrder = 0
			if issuedID && name != step.Name {
				step.CardID = ""
			}
		}
	}
}

// absorbFamilyRoles removes a redundant template role when an issued next or
// completed card fills the same product family. The issued step absorbs the
// role instead of duplicating it, so the roadmap keeps one role per family.
func absorbFamilyRoles(playbook *strategy.Playbook) {
	families := map[string]string{}
	for i := range playbook.Steps {
		step := &playbook.Steps[i]
		if step.CardID == "" {
			continue
		}
		if step.CompletedRecommendation || step.Status == "next" {
			if fam := strategy.Family(step.Name); fam != "" {
				families[fam] = step.Name
			}
		}
	}
	if len(families) == 0 {
		return
	}
	kept := playbook.Steps[:0]
	for _, step := range playbook.Steps {
		if step.CompletedRecommendation || step.Status == "next" || step.CardID == "" {
			kept = append(kept, step)
			continue
		}
		if filling, ok := families[strategy.Family(step.Name)]; ok && filling != step.Name {
			for i := range playbook.Steps {
				absorbed := &playbook.Steps[i]
				if absorbed.Name == filling && (absorbed.CompletedRecommendation || absorbed.Status == "next") {
					note := "Fills the " + step.Name + " role in this strategy."
					if absorbed.Note == "" {
						absorbed.Note = note
					} else if !strings.Contains(absorbed.Note, step.Name+" role") {
						absorbed.Note += " " + note
					}
				}
			}
			continue
		}
		kept = append(kept, step)
	}
	playbook.Steps = kept
}
