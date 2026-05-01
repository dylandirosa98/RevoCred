import { AppData, Card, CardSearchEntry, ChatMessage, Metrics, Profile, Recommendation } from "../types/models";

export const seedWalletCards: Card[] = [
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

export const seedPopularPicks: Card[] = [
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

export const seedTimeline: Recommendation[] = [
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

export const seedProfile: Profile = {
  name: "Javed Saliman",
  creditCardStrategy: "Hybrid cash back + travel",
  goal: "Maximize points without wasting perks",
  topSpendCategories: "Dining, groceries, travel",
  nextApplicationTarget: "Citi Custom Cash",
};

export const seedMetrics: Metrics = {
  pointsValue: 359,
  projectedYearlyValue: 300,
};

export const seedQuickPrompts = [
  "What card should I use for groceries?",
  "What should I apply for next?",
  "How do I maximize travel?",
];

export const seedCardCatalog: Card[] = [
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
];

export const seedCardSearchCatalog: CardSearchEntry[] = [
  {
    id: "amex-gold",
    issuer: "American Express",
    brand: "Amex",
    name: "Amex Gold",
    network: "Amex",
    annualFee: "$325",
    transferablePoints: true,
    pointMultipliers: ["4x Dining (up to annual cap)", "4x U.S. Supermarkets (up to annual cap)", "3x Flights booked direct/Amex Travel"],
    transferPartners: ["Air Canada Aeroplan", "Delta SkyMiles", "British Airways Avios", "ANA Mileage Club"],
    benefits: ["Dining credits", "Uber Cash credits", "No foreign transaction fees", "Purchase protections"],
    summary: "Strong food-focused transferable points card.",
    bestUse: "Dining + Grocery",
    multiplier: "4x",
  },
  {
    id: "venture-x",
    issuer: "Capital One",
    brand: "Visa",
    name: "Venture X",
    network: "Visa",
    annualFee: "$395",
    transferablePoints: true,
    pointMultipliers: ["10x Hotels and rental cars (Capital One Travel)", "5x Flights and vacation rentals (Capital One Travel)", "2x Everything else"],
    transferPartners: ["Air Canada Aeroplan", "British Airways Avios", "Turkish Miles&Smiles", "Air France/KLM Flying Blue"],
    benefits: ["$300 annual travel credit", "10,000 anniversary miles", "Priority Pass lounge access", "Global Entry/TSA PreCheck credit"],
    summary: "Premium travel card with strong flat-rate earnings.",
    bestUse: "Travel",
    multiplier: "2x",
  },
  {
    id: "freedom-unlimited",
    issuer: "Chase",
    brand: "Visa",
    name: "Freedom Unlimited",
    network: "Visa",
    annualFee: "$0",
    transferablePoints: true,
    pointMultipliers: ["5x Travel via Chase Travel", "3x Dining and drugstores", "1.5x Everything else"],
    transferPartners: ["Transferable when paired with Sapphire/Ink preferred cards"],
    benefits: ["No annual fee", "Purchase protection", "Extended warranty", "Useful catch-all card"],
    summary: "Easy everyday Chase points earner.",
    bestUse: "Catch-all",
    multiplier: "1.5x",
  },
  {
    id: "freedom-flex",
    issuer: "Chase",
    brand: "Mastercard",
    name: "Freedom Flex",
    network: "Mastercard",
    annualFee: "$0",
    transferablePoints: true,
    pointMultipliers: ["5x Rotating categories (activation required)", "5x Travel via Chase Travel", "3x Dining and drugstores", "1x Other purchases"],
    transferPartners: ["Transferable when paired with Sapphire/Ink preferred cards"],
    benefits: ["Cell phone protection", "No annual fee", "High earning in rotating categories", "Strong companion card"],
    summary: "Great bonus-category companion card.",
    bestUse: "Rotating Categories",
    multiplier: "5x",
  },
  {
    id: "bilt",
    issuer: "Bilt",
    brand: "Mastercard",
    name: "Bilt Mastercard",
    network: "Mastercard",
    annualFee: "$0",
    transferablePoints: true,
    pointMultipliers: ["1x Rent (up to monthly cap, terms apply)", "3x Dining", "2x Travel", "1x Other purchases"],
    transferPartners: ["Hyatt", "American Airlines AAdvantage", "Air Canada Aeroplan", "Turkish Miles&Smiles"],
    benefits: ["Earn points on rent", "No annual fee", "Cell phone protection", "Strong transfer partners"],
    summary: "Unique option for renters pursuing transferable points.",
    bestUse: "Rent + Dining",
    multiplier: "1x-3x",
  },
  {
    id: "citi-strata",
    issuer: "Citi",
    brand: "Mastercard",
    name: "Citi Strata Premier",
    network: "Mastercard",
    annualFee: "$95",
    transferablePoints: true,
    pointMultipliers: ["3x Air travel and hotels", "3x Restaurants", "3x Supermarkets", "3x Gas and EV charging"],
    transferPartners: ["Flying Blue", "Avianca LifeMiles", "Virgin Atlantic Flying Club", "Qatar Airways Privilege Club"],
    benefits: ["Annual hotel benefit on qualified bookings", "No foreign transaction fees", "Broad 3x categories", "Travel transfer partners"],
    summary: "Mid-fee transferable points card with broad 3x categories.",
    bestUse: "Travel + Everyday",
    multiplier: "3x",
  },
  {
    id: "citi-custom-cash",
    issuer: "Citi",
    brand: "Mastercard",
    name: "Citi Custom Cash",
    network: "Mastercard",
    annualFee: "$0",
    transferablePoints: false,
    pointMultipliers: ["5x Top eligible spend category each billing cycle (up to cap)", "1x Other purchases"],
    transferPartners: [],
    benefits: ["Automatic top-category optimization", "No annual fee", "Pairs well with premium Citi cards", "Simple setup"],
    summary: "Set-and-forget high earn rate on one monthly category.",
    bestUse: "Top Eligible Category",
    multiplier: "5x",
  },
];

export function initialAssistantMessage(): ChatMessage {
  return createInitialAssistantMessage();
}

export const seedAppData: AppData = {
  profile: seedProfile,
  metrics: seedMetrics,
  walletCards: seedWalletCards,
  strategyTimeline: seedTimeline,
  popularPicks: seedPopularPicks,
  cardSearchCatalog: seedCardSearchCatalog,
  quickPrompts: seedQuickPrompts,
  chatMessages: [createInitialAssistantMessage()],
  cardCatalog: seedCardCatalog,
};
