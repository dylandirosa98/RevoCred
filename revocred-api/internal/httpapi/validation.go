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

func validateRecommendation(input domain.RecommendationInput) map[string]string {
	errors := make(map[string]string)
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
