import { Session } from "@supabase/supabase-js";
import { useEffect, useMemo, useState } from "react";
import {
  addWalletCardForUser,
  appendPromptAndReply,
  ensureUserBootstrap,
  fetchRevoAnalyticsSummary,
  fetchUserAppData,
  resetUserData,
} from "../services/supabaseData";
import { supabase } from "../services/supabaseClient";
import { AppData, Card, RevoAnalyticsSummary } from "../types/models";

type AuthResult = {
  ok: boolean;
  error?: string;
  message?: string;
};

type UseAppDataResult = {
  data: AppData | null;
  loading: boolean;
  authError: string | null;
  session: Session | null;
  signIn: (email: string, password: string) => Promise<AuthResult>;
  signUp: (email: string, password: string) => Promise<AuthResult>;
  signOut: () => Promise<void>;
  submitPrompt: (prompt: string) => Promise<void>;
  addCardToWallet: (cardId: string) => Promise<void>;
  resetToSeed: () => Promise<void>;
  availableCardsToAdd: Card[];
  analyticsSummary: RevoAnalyticsSummary | null;
  analyticsLoading: boolean;
  refreshAnalytics: () => Promise<void>;
};

function toErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return "Something went wrong. Please try again.";
}

export function useAppData(): UseAppDataResult {
  const [session, setSession] = useState<Session | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [data, setData] = useState<AppData | null>(null);
  const [loadingData, setLoadingData] = useState(false);
  const [authError, setAuthError] = useState<string | null>(null);
  const [analyticsSummary, setAnalyticsSummary] = useState<RevoAnalyticsSummary | null>(null);
  const [analyticsLoading, setAnalyticsLoading] = useState(false);

  useEffect(() => {
    let alive = true;

    async function bootstrapAuth() {
      const {
        data: { session: currentSession },
      } = await supabase.auth.getSession();
      if (alive) {
        setSession(currentSession);
        setAuthReady(true);
      }
    }

    bootstrapAuth();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      if (alive) {
        setSession(nextSession);
      }
    });

    return () => {
      alive = false;
      subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    let alive = true;
    if (!authReady) {
      return () => {
        alive = false;
      };
    }

    if (!session) {
      setData(null);
      setAnalyticsSummary(null);
      setLoadingData(false);
      return () => {
        alive = false;
      };
    }

    async function loadForCurrentUser(userId: string) {
      setLoadingData(true);
      setAnalyticsLoading(true);
      setAuthError(null);
      try {
        await ensureUserBootstrap(userId);
        // Prioritize core app payload first so users see screens faster after login.
        const loaded = await fetchUserAppData(userId);
        if (alive) {
          setData(loaded);
          setLoadingData(false);
        }

        const analytics = await fetchRevoAnalyticsSummary(userId);
        if (alive) {
          setAnalyticsSummary(analytics);
        }
      } catch (error) {
        if (alive) {
          setAuthError(toErrorMessage(error));
        }
      } finally {
        if (alive) {
          setLoadingData(false);
          setAnalyticsLoading(false);
        }
      }
    }

    loadForCurrentUser(session.user.id);
    return () => {
      alive = false;
    };
  }, [authReady, session]);

  const signIn = async (email: string, password: string): Promise<AuthResult> => {
    setAuthError(null);
    const { error } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });
    if (error) {
      const message = error.message;
      setAuthError(message);
      return { ok: false, error: message };
    }
    return { ok: true };
  };

  const signUp = async (email: string, password: string): Promise<AuthResult> => {
    setAuthError(null);
    const { data: signUpData, error } = await supabase.auth.signUp({
      email: email.trim(),
      password,
    });
    if (error) {
      const message = error.message;
      setAuthError(message);
      return { ok: false, error: message };
    }

    if (!signUpData.session) {
      return { ok: true, message: "Check your email to confirm your account, then log in." };
    }

    return { ok: true };
  };

  const signOut = async () => {
    await supabase.auth.signOut();
    setData(null);
    setAnalyticsSummary(null);
  };

  const refreshAnalytics = async () => {
    if (!session) {
      return;
    }
    setAnalyticsLoading(true);
    try {
      const analytics = await fetchRevoAnalyticsSummary(session.user.id);
      setAnalyticsSummary(analytics);
    } catch (error) {
      setAuthError(toErrorMessage(error));
    } finally {
      setAnalyticsLoading(false);
    }
  };

  const submitPrompt = async (prompt: string) => {
    const trimmed = prompt.trim();
    if (!trimmed || !data || !session) {
      return;
    }

    try {
      await appendPromptAndReply(trimmed);
      const [refreshed, analytics] = await Promise.all([
        fetchUserAppData(session.user.id),
        fetchRevoAnalyticsSummary(session.user.id),
      ]);
      setData(refreshed);
      setAnalyticsSummary(analytics);
    } catch (error) {
      setAuthError(toErrorMessage(error));
    }
  };

  const addCardToWallet = async (cardId: string) => {
    if (!data || !session) {
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

    try {
      await addWalletCardForUser(session.user.id, cardId, data.metrics.pointsValue, data.metrics.projectedYearlyValue);
      const [refreshed, analytics] = await Promise.all([
        fetchUserAppData(session.user.id),
        fetchRevoAnalyticsSummary(session.user.id),
      ]);
      setData(refreshed);
      setAnalyticsSummary(analytics);
    } catch (error) {
      setAuthError(toErrorMessage(error));
    }
  };

  const resetToSeed = async () => {
    if (!session) {
      return;
    }
    try {
      await resetUserData(session.user.id);
      const [refreshed, analytics] = await Promise.all([
        fetchUserAppData(session.user.id),
        fetchRevoAnalyticsSummary(session.user.id),
      ]);
      setData(refreshed);
      setAnalyticsSummary(analytics);
    } catch (error) {
      setAuthError(toErrorMessage(error));
    }
  };

  const availableCardsToAdd = useMemo(() => {
    if (!data) {
      return [];
    }
    return data.cardCatalog.filter((catalogCard) => !data.walletCards.some((walletCard) => walletCard.id === catalogCard.id));
  }, [data]);

  return {
    data,
    loading: !authReady || loadingData,
    authError,
    session,
    signIn,
    signUp,
    signOut,
    submitPrompt,
    addCardToWallet,
    resetToSeed,
    availableCardsToAdd,
    analyticsSummary,
    analyticsLoading,
    refreshAnalytics,
  };
}
