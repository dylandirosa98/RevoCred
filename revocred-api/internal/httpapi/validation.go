package httpapi

import (
	"strings"
	"unicode/utf8"

	"github.com/revocred/revocred-api/internal/domain"
)

func validateProfile(profile domain.Profile) map[string]string {
	errors := make(map[string]string)
	validateOptionalLength(errors, "display_name", profile.DisplayName, 100)
	validateOptionalLength(errors, "credit_card_strategy", profile.CreditCardStrategy, 500)
	validateOptionalLength(errors, "goal", profile.Goal, 500)
	validateOptionalLength(errors, "next_application_target", profile.NextApplicationTarget, 200)
	if len(profile.TopSpendCategories) > 20 {
		errors["top_spend_categories"] = "must contain at most 20 categories"
	}
	for _, category := range profile.TopSpendCategories {
		if strings.TrimSpace(category) == "" || utf8.RuneCountInString(category) > 50 {
			errors["top_spend_categories"] = "each category must contain 1 to 50 characters"
			break
		}
	}
	if !oneOf(profile.RewardsGoal, "", "cash_back", "travel", "hybrid") {
		errors["rewards_goal"] = "must be cash_back, travel, or hybrid"
	}
	if !oneOf(profile.TravelScope, "", "none", "domestic", "international", "both") {
		errors["travel_scope"] = "must be none, domestic, international, or both"
	}
	return errors
}

func validateWalletCard(input domain.CreateWalletCard) map[string]string {
	errors := make(map[string]string)
	if !validUUID(input.CatalogCardID) {
		errors["catalog_card_id"] = "must be a UUID from GET /v1/cards"
	}
	validateOptionalLength(errors, "nickname", input.Nickname, 100)
	if !oneOf(input.Status, "active", "inactive") {
		errors["status"] = "must be active or inactive"
	}
	return errors
}

func validateCustomCard(input domain.CreateCustomCard) map[string]string {
	errors := make(map[string]string)
	if strings.TrimSpace(input.Name) == "" || utf8.RuneCountInString(input.Name) > 100 {
		errors["name"] = "must contain 1 to 100 characters"
	}
	if strings.TrimSpace(input.Issuer) == "" || utf8.RuneCountInString(input.Issuer) > 80 {
		errors["issuer"] = "must contain 1 to 80 characters"
	}
	if !oneOf(input.Network, "Visa", "Mastercard", "Amex", "Discover", "Other") {
		errors["network"] = "must be Visa, Mastercard, Amex, Discover, or Other"
	}
	if input.AnnualFeeCents < 0 || input.AnnualFeeCents > 1_000_000 {
		errors["annual_fee_cents"] = "must be between 0 and 1000000"
	}
	if len(input.RewardRates) == 0 {
		errors["reward_rates"] = "must include at least one category"
	}
	for category, rate := range input.RewardRates {
		if !oneOf(category, "other", "dining", "groceries", "gas", "travel", "flights", "hotels", "rent", "entertainment") {
			errors["reward_rates"] = "contains an unsupported category"
			break
		}
		if rate < 0 || rate > 20 {
			errors["reward_rates"] = "rates must be between 0 and 20"
			break
		}
	}
	validateOptionalLength(errors, "best_use", input.BestUse, 120)
	validateOptionalLength(errors, "nickname", input.Nickname, 100)
	if len(input.Benefits) > 20 {
		errors["benefits"] = "must contain at most 20 items"
	}
	if !oneOf(input.TravelScope, "none", "domestic", "international", "both") {
		errors["travel_scope"] = "must be none, domestic, international, or both"
	}
	if !oneOf(input.RewardsType, "cash_back", "travel", "hybrid") {
		errors["rewards_type"] = "must be cash_back, travel, or hybrid"
	}
	if !oneOf(input.MinimumCreditTier, "building", "fair", "good", "excellent") {
		errors["minimum_credit_tier"] = "must be building, fair, good, or excellent"
	}
	return errors
}

func validateRecommendation(input domain.RecommendationInput) map[string]string {
	errors := make(map[string]string)
	if !oneOf(input.LifeStage, "", "student", "adult", "adult-learning", "adult-building", "adult-established", "adult-optimizing") {
		errors["life_stage"] = "unsupported life stage"
	}
	if len(input.MonthlyCategorySpend) == 0 || len(input.MonthlyCategorySpend) > 20 {
		errors["monthly_category_spend"] = "must contain between 1 and 20 categories"
	}
	for category, amount := range input.MonthlyCategorySpend {
		if strings.TrimSpace(category) == "" || utf8.RuneCountInString(category) > 50 {
			errors["monthly_category_spend"] = "category names must contain 1 to 50 characters"
			break
		}
		if !oneOf(category, "rent", "housing", "food", "dining", "groceries", "travel", "everyday", "other", "gas", "flights", "hotels", "streaming", "entertainment", "transit", "drugstores") {
			errors["monthly_category_spend"] = "contains an unsupported category"
			break
		}
		if amount < 0 || amount > 100_000_000 {
			errors["monthly_category_spend"] = "amounts must be between 0 and 100000000 cents"
			break
		}
	}
	if input.FeeToleranceCents < 0 || input.FeeToleranceCents > 1_000_000 {
		errors["fee_tolerance_cents"] = "must be between 0 and 1000000"
	}
	if !oneOf(input.TravelScope, "none", "domestic", "international", "both") {
		errors["travel_scope"] = "must be none, domestic, international, or both"
	}
	if !oneOf(input.RewardsGoal, "cash_back", "travel", "hybrid") {
		errors["rewards_goal"] = "must be cash_back, travel, or hybrid"
	}
	if !oneOf(input.CreditTier, "building", "fair", "good", "excellent") {
		errors["credit_tier"] = "must be building, fair, good, or excellent"
	}
	validateAddedCards(input.AddedCards, errors)
	if len(input.ExistingCardIDs) > 50 {
		errors["existing_card_ids"] = "must contain at most 50 IDs"
	}
	for _, id := range input.ExistingCardIDs {
		if strings.TrimSpace(id) == "" || utf8.RuneCountInString(id) > 100 {
			errors["existing_card_ids"] = "each ID must contain 1 to 100 characters"
			break
		}
	}
	return errors
}

func validateOptionalLength(errors map[string]string, field, value string, max int) {
	if utf8.RuneCountInString(value) > max {
		errors[field] = "must contain at most " + intString(max) + " characters"
	}
}

func oneOf(value string, choices ...string) bool {
	for _, choice := range choices {
		if value == choice {
			return true
		}
	}
	return false
}

func validUUID(value string) bool {
	if len(value) != 36 {
		return false
	}
	for i, character := range value {
		if i == 8 || i == 13 || i == 18 || i == 23 {
			if character != '-' {
				return false
			}
			continue
		}
		if !((character >= '0' && character <= '9') || (character >= 'a' && character <= 'f') || (character >= 'A' && character <= 'F')) {
			return false
		}
	}
	return true
}

func intString(value int) string {
	const digits = "0123456789"
	if value == 0 {
		return "0"
	}
	var buffer [20]byte
	position := len(buffer)
	for value > 0 {
		position--
		buffer[position] = digits[value%10]
		value /= 10
	}
	return string(buffer[position:])
}

// validateAddedCards keeps a search-index pick from smuggling invented terms
// into a scored wallet. Rates must be real numbers on known categories.
func validateAddedCards(cards []domain.OnboardingCard, out map[string]string) {
	if len(cards) > 40 {
		out["added_cards"] = "must contain at most 40 cards"
		return
	}
	seen := map[string]bool{}
	for _, card := range cards {
		key := "added_cards"
		if !validUUID(card.ReferenceID) {
			out[key] = "each reference_id must be a UUID"
			return
		}
		if seen[card.ReferenceID] {
			out[key] = "must not repeat a card"
			return
		}
		seen[card.ReferenceID] = true
		if !card.IncludeTerms {
			continue
		}
		if card.AnnualFeeCents < 0 || card.AnnualFeeCents > 1_000_000 {
			out[key] = "annual_fee_cents must be between 0 and 1000000"
			return
		}
		if len(card.RewardRates) == 0 || len(card.RewardRates) > 20 {
			out[key] = "reward_rates must contain between 1 and 20 categories"
			return
		}
		for category, rate := range card.RewardRates {
			if !oneOf(category, "other", "dining", "groceries", "gas", "travel", "flights", "hotels", "streaming", "drugstores", "transit", "entertainment") {
				out[key] = "reward_rates contains an unsupported category"
				return
			}
			if rate <= 0 || rate > 100 {
				out[key] = "reward_rates must be greater than 0 and at most 100"
				return
			}
		}
		if card.RewardRates["other"] < 1 {
			out[key] = "reward_rates must include an other rate of at least 1"
			return
		}
		if card.MinimumTier != "" && !oneOf(card.MinimumTier, "building", "fair", "good", "excellent") {
			out[key] = "minimum_credit_tier must be building, fair, good, or excellent"
			return
		}
	}
}
