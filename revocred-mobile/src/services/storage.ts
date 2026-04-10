import { Card, Metrics, Profile } from "../types/models";

export function buildRevoReply(prompt: string, profile: Profile, cards: Card[], metrics: Metrics): string {
  const normalized = prompt.toLowerCase();
  const topCard = cards[0];

  if (normalized.includes("grocer")) {
    const groceryCard = cards.find((card) =>
      card.bestUse.toLowerCase().includes("grocery") || card.benefits.some((benefit) => benefit.toLowerCase().includes("grocery"))
    );
    if (groceryCard) {
      return `Use ${groceryCard.name} for groceries. It's currently one of your best options and aligns with your ${profile.creditCardStrategy.toLowerCase()} strategy.`;
    }
  }

  if (normalized.includes("apply")) {
    return `Next target: ${profile.nextApplicationTarget}. Keep your utilization steady and use ${topCard?.name ?? "your strongest card"} consistently before applying.`;
  }

  if (normalized.includes("travel")) {
    const travelCard = cards.find((card) => card.bestUse.toLowerCase().includes("travel"));
    if (travelCard) {
      return `For travel, prioritize ${travelCard.name}. You can also stack it with transfer-friendly cards to improve redemption value.`;
    }
  }

  return `You're tracking about $${metrics.projectedYearlyValue} in yearly value now. I can help you optimize by spend category or next-card timing.`;
}

