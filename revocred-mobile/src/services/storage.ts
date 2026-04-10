import AsyncStorage from "@react-native-async-storage/async-storage";
import { seedAppData } from "../data/seed";
import { AppData, Card, ChatMessage, Metrics, Profile } from "../types/models";

const STORAGE_KEY = "@revocred/app-data-v1";

function cloneSeed(): AppData {
  return JSON.parse(JSON.stringify(seedAppData)) as AppData;
}

export async function loadAppData(): Promise<AppData> {
  const raw = await AsyncStorage.getItem(STORAGE_KEY);
  if (!raw) {
    const initial = cloneSeed();
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(initial));
    return initial;
  }

  try {
    const parsed = JSON.parse(raw) as AppData;
    return parsed;
  } catch {
    const fallback = cloneSeed();
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(fallback));
    return fallback;
  }
}

export async function persistAppData(data: AppData): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(data));
}

export async function resetAppData(): Promise<AppData> {
  const fresh = cloneSeed();
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(fresh));
  return fresh;
}

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

export function createMessage(role: "user" | "assistant", content: string): ChatMessage {
  return {
    id: `${role}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    role,
    content,
    createdAt: new Date().toISOString(),
  };
}
