import { AppData, Card, ChatMessage, Recommendation } from "../types/models";

const seedWalletCards: Card[] = [
  {
    id: "amex-gold",
    brand: "AMEX",
    name: "Amex Gold",
    bestUse: "Dining + Grocery",
    multiplier: "4x",
    status: "Active",
    benefits: ["4x dining", "4x groceries", "$10 dining credit", "Transfer partners"],
  },
  {
    id: "venture-x",
    brand: "VISA",
    name: "Venture X",
    bestUse: "Travel",
    multiplier: "2x",
    status: "Active",
    benefits: ["2x everywhere", "$300 travel credit", "Lounge access", "10k anniversary miles"],
  },
  {
    id: "freedom-unlimited",
    brand: "VISA",
    name: "Freedom Unlimited",
    bestUse: "Catch-all",
    multiplier: "1.5x",
    status: "Active",
    benefits: ["1.5x everywhere", "3x dining", "3x drugstores", "No annual fee"],
  },
  {
    id: "freedom-flex",
    brand: "MC",
    name: "Freedom Flex",
    bestUse: "Rotating Categories",
    multiplier: "5x",
    status: "Active",
    benefits: ["5x rotating categories", "3x dining", "3x drugstores", "No annual fee"],
  },
  {
    id: "savor",
    brand: "MC",
    name: "Savor",
    bestUse: "Dining + Entertainment",
    multiplier: "3x",
    status: "Active",
    benefits: ["3x dining", "3x entertainment", "3x groceries", "No annual fee"],
  },
];

const seedPopularPicks: Card[] = [
  seedWalletCards[0],
  seedWalletCards[1],
  {
    id: "bilt",
    brand: "MC",
    name: "BILT",
    bestUse: "Rent + Dining",
    multiplier: "1x-5x",
    status: "Active",
    benefits: ["1x rent", "3x dining", "2x travel", "Transfer partners"],
  },
  {
    id: "citi-strata",
    brand: "MC",
    name: "Citi Strata",
    bestUse: "Travel + Everyday",
    multiplier: "3x",
    status: "Active",
    benefits: ["3x travel", "3x grocery", "3x gas", "No foreign fees"],
  },
];

const seedTimeline: Recommendation[] = [
  {
    id: "debit",
    title: "Debit",
    monthLabel: "You're here",
    note: "Starting point before building rewards history",
  },
  {
    id: "freedom-unlimited",
    title: "Freedom Unlimited",
    monthLabel: "Apply June",
    note: "Start with a flexible beginner card",
  },
  {
    id: "sapphire-preferred",
    title: "Sapphire Preferred",
    monthLabel: "Apply October",
    note: "Add travel value after building history",
  },
];

function createInitialAssistantMessage(): ChatMessage {
  return {
    id: "seed-assistant-message-1",
    role: "assistant",
    content: "Ask me anything about your setup. I can help with card choice, timing, and points strategy.",
    createdAt: new Date().toISOString(),
  };
}

export const seedAppData: AppData = {
  profile: {
    name: "Javed Saliman",
    creditCardStrategy: "Hybrid cash back + travel",
    goal: "Maximize points without wasting perks",
    topSpendCategories: "Dining, groceries, travel",
    nextApplicationTarget: "Citi Custom Cash",
  },
  metrics: {
    pointsValue: 359,
    projectedYearlyValue: 300,
  },
  walletCards: seedWalletCards,
  strategyTimeline: seedTimeline,
  popularPicks: seedPopularPicks,
  quickPrompts: [
    "What card should I use for groceries?",
    "What should I apply for next?",
    "How do I maximize travel?",
  ],
  chatMessages: [createInitialAssistantMessage()],
  cardCatalog: [
    ...seedWalletCards,
    ...seedPopularPicks.filter((pick) => !seedWalletCards.some((walletCard) => walletCard.id === pick.id)),
    {
      id: "citi-custom-cash",
      brand: "MC",
      name: "Citi Custom Cash",
      bestUse: "Top Eligible Category",
      multiplier: "5x",
      status: "Inactive",
      benefits: ["5x top category", "No annual fee", "Flexible earning", "Great pairing card"],
    },
  ],
};
