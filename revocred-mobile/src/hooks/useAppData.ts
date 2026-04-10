import { useEffect, useMemo, useState } from "react";
import { AppData, Card, ChatMessage } from "../types/models";
import { buildRevoReply, createMessage, loadAppData, persistAppData, resetAppData } from "../services/storage";

type UseAppDataResult = {
  data: AppData | null;
  loading: boolean;
  submitPrompt: (prompt: string) => Promise<void>;
  addCardToWallet: (cardId: string) => Promise<void>;
  resetToSeed: () => Promise<void>;
  availableCardsToAdd: Card[];
};

export function useAppData(): UseAppDataResult {
  const [data, setData] = useState<AppData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    async function bootstrap() {
      setLoading(true);
      const loaded = await loadAppData();
      if (alive) {
        setData(loaded);
        setLoading(false);
      }
    }
    bootstrap();
    return () => {
      alive = false;
    };
  }, []);

  const updateData = async (nextData: AppData) => {
    setData(nextData);
    await persistAppData(nextData);
  };

  const submitPrompt = async (prompt: string) => {
    const trimmed = prompt.trim();
    if (!trimmed || !data) {
      return;
    }

    const userMessage = createMessage("user", trimmed);
    const assistantReply = createMessage("assistant", buildRevoReply(trimmed, data.profile, data.walletCards, data.metrics));

    const nextMessages: ChatMessage[] = [...data.chatMessages, userMessage, assistantReply];
    await updateData({ ...data, chatMessages: nextMessages });
  };

  const addCardToWallet = async (cardId: string) => {
    if (!data) {
      return;
    }

    const alreadyInWallet = data.walletCards.some((card) => card.id === cardId);
    if (alreadyInWallet) {
      return;
    }

    const cardToAdd = data.cardCatalog.find((card) => card.id === cardId);
    if (!cardToAdd) {
      return;
    }

    const activatedCard: Card = { ...cardToAdd, status: "Active" };
    const nextWallet = [...data.walletCards, activatedCard];
    const nextPoints = data.metrics.pointsValue + 22;
    const nextProjection = data.metrics.projectedYearlyValue + 40;

    await updateData({
      ...data,
      walletCards: nextWallet,
      metrics: { pointsValue: nextPoints, projectedYearlyValue: nextProjection },
    });
  };

  const resetToSeed = async () => {
    const fresh = await resetAppData();
    setData(fresh);
  };

  const availableCardsToAdd = useMemo(() => {
    if (!data) {
      return [];
    }
    return data.cardCatalog.filter((catalogCard) => !data.walletCards.some((walletCard) => walletCard.id === catalogCard.id));
  }, [data]);

  return {
    data,
    loading,
    submitPrompt,
    addCardToWallet,
    resetToSeed,
    availableCardsToAdd,
  };
}
