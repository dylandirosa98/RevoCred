export type TabKey = "Home" | "Cards" | "Strategy" | "REVO" | "Profile";

export type CardStatus = "Active" | "Inactive";

export type Card = {
  id: string;
  brand: string;
  name: string;
  bestUse: string;
  multiplier: string;
  status: CardStatus;
  benefits: string[];
};

export type Recommendation = {
  id: string;
  title: string;
  monthLabel: string;
  note: string;
};

export type Profile = {
  name: string;
  creditCardStrategy: string;
  goal: string;
  topSpendCategories: string;
  nextApplicationTarget: string;
};

export type ChatMessage = {
  id: string;
  role: "user" | "assistant";
  content: string;
  createdAt: string;
};

export type Metrics = {
  pointsValue: number;
  projectedYearlyValue: number;
};

export type AppData = {
  profile: Profile;
  metrics: Metrics;
  walletCards: Card[];
  strategyTimeline: Recommendation[];
  popularPicks: Card[];
  quickPrompts: string[];
  chatMessages: ChatMessage[];
  cardCatalog: Card[];
};
