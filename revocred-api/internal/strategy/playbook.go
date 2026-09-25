package strategy

import (
	"strings"
	"unicode"
)

type Preferences struct {
	CreditTier        string
	Goal              Goal
	FeeToleranceCents int
	Travel            Travel
}

type PlaybookStep struct {
	Name   string `json:"name"`
	Use    string `json:"use"`
	Status string `json:"status"`
	Note   string `json:"note,omitempty"`
}

type UnusedCard struct {
	Name   string `json:"name"`
	Action string `json:"action"`
	Note   string `json:"note"`
}

type Alternative struct {
	Code   Code   `json:"code"`
	Title  string `json:"title"`
	Reason string `json:"reason"`
}

type Playbook struct {
	Code         Code           `json:"code,omitempty"`
	Title        string         `json:"title,omitempty"`
	UserType     string         `json:"user_type,omitempty"`
	Goal         string         `json:"goal,omitempty"`
	FeeLevel     string         `json:"fee_level,omitempty"`
	TravelScope  string         `json:"travel_scope,omitempty"`
	Ecosystem    string         `json:"ecosystem,omitempty"`
	DebitCard    string         `json:"debit_card,omitempty"`
	NextCard     string         `json:"next_card,omitempty"`
	Steps        []PlaybookStep `json:"steps"`
	Unused       []UnusedCard   `json:"unused_cards"`
	Alternatives []Alternative  `json:"alternatives"`
}

var cardUse = map[string]string{
	"Savor for Students": "Dining and groceries while you build credit.",
	"Quicksilver":        "Everyday catch-all cash back.",
	"Freedom Rise":       "Starter card to build Chase history.",
	"Freedom Flex":       "Rotating categories and dining.",
	"Sapphire Preferred": "Travel portal and transfer partners.",
	"SavorOne":           "Dining, groceries, and entertainment.",
	"Freedom Unlimited":  "Everyday catch-all in the Chase ecosystem.",
	"Venture X":          "Premium travel catch-all and portal spend.",
	"Gold":               "Dining and groceries in the Amex ecosystem.",
	"Platinum":           "Travel credits, lounges, and premium benefits.",
	"Amex Gold":          "Dining and groceries alongside Capital One travel.",
	"Double Cash":        "Simple cash back while you enter Citi.",
	"Strata":             "Everyday Citi categories.",
	"Strata Elite":       "Domestic travel hub in Citi.",
	"Sapphire Reserve":   "Premium Chase travel hub.",
}

var titles = map[Code]string{
	S01: "Build credit with simple cash back",
	S02: "Build toward flexible travel",
	S03: "Everyday cash-back foundation",
	S04: "Flexible travel foundation",
	S05: "Premium international travel",
	S06: "Flexible international travel",
	S07: "High-value cash back",
	S08: "Domestic travel through Citi",
	S09: "Premium Chase travel",
}

func Build(code string, walletNames []string, prefs *Preferences) Playbook {
	definition, ok := DefinitionFor(Code(code))
	if !ok {
		return Playbook{Steps: []PlaybookStep{}, Unused: []UnusedCard{}, Alternatives: []Alternative{}}
	}
	owned := make([]string, 0, len(walletNames))
	owned = append(owned, walletNames...)
	playbook := Playbook{
		Code:         definition.Code,
		Title:        titles[definition.Code],
		UserType:     definition.UserType,
		Goal:         definition.Goal,
		FeeLevel:     definition.AnnualFeeLevel,
		TravelScope:  definition.TravelScope,
		Ecosystem:    definition.Ecosystem,
		DebitCard:    definition.RecommendedDebitCard,
		Steps:        make([]PlaybookStep, 0, len(definition.Cards)),
		Unused:       []UnusedCard{},
		Alternatives: alternativesFor(definition, prefs),
	}
	foundNext := false
	usedKeys := map[string]bool{}
	for _, name := range definition.Cards {
		step := PlaybookStep{Name: name, Use: cardUse[name], Status: "later"}
		if match, substitute := matchWallet(name, owned); match != "" {
			step.Status = "have"
			usedKeys[normalize(match)] = true
			if substitute {
				step.Note = "Your " + match + " covers this playbook slot."
			}
		} else if !foundNext {
			step.Status = "next"
			playbook.NextCard = name
			foundNext = true
		}
		playbook.Steps = append(playbook.Steps, step)
	}
	for _, held := range owned {
		if held == "" {
			continue
		}
		if usedKeys[normalize(held)] {
			continue
		}
		playbook.Unused = append(playbook.Unused, UnusedCard{
			Name:   held,
			Action: "avoid_for_this_strategy",
			Note:   "Keep it if you want, but do not use it as a primary card in this playbook.",
		})
	}
	return playbook
}

func alternativesFor(current Definition, prefs *Preferences) []Alternative {
	candidates := nearby(current.Code)
	if prefs != nil && prefs.Goal == GoalTravel && current.Code == S04 {
		candidates = []Code{S09, S06, S02}
	}
	out := make([]Alternative, 0, 2)
	for _, code := range candidates {
		if code == current.Code {
			continue
		}
		definition, ok := DefinitionFor(code)
		if !ok {
			continue
		}
		out = append(out, Alternative{
			Code:   code,
			Title:  titles[code],
			Reason: alternativeReason(current, definition),
		})
		if len(out) == 2 {
			break
		}
	}
	return out
}

func nearby(code Code) []Code {
	switch code {
	case S01:
		return []Code{S03, S02}
	case S02:
		return []Code{S04, S01}
	case S03:
		return []Code{S07, S01, S04}
	case S04:
		return []Code{S09, S06, S02}
	case S05:
		return []Code{S06, S09}
	case S06:
		return []Code{S05, S04}
	case S07:
		return []Code{S03, S09}
	case S08:
		return []Code{S09, S04}
	case S09:
		return []Code{S04, S05}
	default:
		return nil
	}
}

func alternativeReason(current, other Definition) string {
	if current.Goal == other.Goal && current.AnnualFeeLevel != other.AnnualFeeLevel {
		if other.AnnualFeeLevel == "High" {
			return "Same goal with a premium-fee version of the playbook."
		}
		return "Same goal with a lower-fee version of the playbook."
	}
	if current.Goal != other.Goal {
		return "A different rewards goal using a nearby playbook."
	}
	if current.TravelScope != other.TravelScope && other.TravelScope != "" {
		return "Same goal with a different travel scope."
	}
	return "A nearby playbook you can switch to later."
}

func matchWallet(target string, held []string) (string, bool) {
	want := family(target)
	for _, name := range held {
		if family(name) == want && want != "" {
			return name, normalize(name) != normalize(target)
		}
	}
	return "", false
}

func family(name string) string {
	key := normalize(name)
	switch {
	case strings.Contains(key, "savor"):
		return "savor"
	case strings.Contains(key, "quicksilver"):
		return "quicksilver"
	case strings.Contains(key, "freedomrise") || strings.Contains(key, "rise"):
		return "freedomrise"
	case strings.Contains(key, "freedomflex") || key == "flex":
		return "freedomflex"
	case strings.Contains(key, "freedomunlimited") || key == "unlimited":
		return "freedomunlimited"
	case strings.Contains(key, "sapphirepreferred") || key == "csp":
		return "sapphirepreferred"
	case strings.Contains(key, "sapphirereserve") || key == "csr":
		return "sapphirereserve"
	case strings.Contains(key, "venturex"):
		return "venturex"
	case strings.Contains(key, "platinum"):
		return "platinum"
	case strings.Contains(key, "gold"):
		return "gold"
	case strings.Contains(key, "doublecash"):
		return "doublecash"
	case strings.Contains(key, "strataelite"):
		return "strataelite"
	case strings.Contains(key, "strata"):
		return "strata"
	default:
		return key
	}
}

func normalize(value string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(value) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
		}
	}
	return strings.TrimPrefix(strings.TrimPrefix(b.String(), "amex"), "chase")
}
