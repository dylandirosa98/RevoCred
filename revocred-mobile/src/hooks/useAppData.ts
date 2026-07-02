import { Session } from "@supabase/supabase-js";
import { useEffect, useMemo, useState } from "react";
import {
  addWalletCardForUser,
  appendPromptAndReply,
  ensureUserBootstrap,
  fetchRevoAnalyticsSummary,
  fetchUserAppData,
  resetUserData,
  updateUserPreferences,
} from "../services/supabaseData";
import { seedAppData } from "../data/seed";
import { captureError, identifyUser, resetUserIdentity, trackEvent } from "../services/observability";
import { supabase } from "../services/supabaseClient";
import { AppData, Card, ChatMessage, RedemptionType, RevoAnalyticsSummary, TravelScope } from "../types/models";

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
  saveQuestionnaireAnswers: (answers: { redemptionType: RedemptionType; travelScope: TravelScope }) => Promise<void>;
};

function toErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return "Something went wrong. Please try again.";
}

function requiresBootstrap(error: unknown): boolean {
  if (error instanceof Error) {
    return error.message.toLowerCase().includes("profile not found");
  }
  return false;
}

function cloneSeedAppData(): AppData {
  return JSON.parse(JSON.stringify(seedAppData)) as AppData;
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
        trackEvent("auth.bootstrap.completed", {
          hasActiveSession: Boolean(currentSession),
        });
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
      setAnalyticsLoading(true);
      setAuthError(null);

      // Render a local-first shell instantly while cloud sync catches up.
      if (alive) {
        setData((current) => current ?? cloneSeedAppData());
        setLoadingData(false);
      }

      try {
        // Fast path: fetch existing user payload directly (most logins).
        const loaded = await fetchUserAppData(userId);
        if (alive) {
          setData(loaded);
        }
      } catch (error) {
        if (requiresBootstrap(error)) {
          try {
            await ensureUserBootstrap(userId);
            const loaded = await fetchUserAppData(userId);
            if (alive) {
              setData(loaded);
            }
          } catch (bootstrapError) {
            if (alive) {
              setAuthError(toErrorMessage(bootstrapError));
            }
          }
        } else if (alive) {
          captureError(error, "loadForCurrentUser.fetchUserAppData", {
            userId,
          });
          setAuthError(toErrorMessage(error));
        }
      }

      try {
        const analytics = await fetchRevoAnalyticsSummary(userId);
        if (alive) {
          setAnalyticsSummary(analytics);
        }
      } catch (error) {
        if (alive) {
          captureError(error, "loadForCurrentUser.fetchRevoAnalyticsSummary", {
            userId,
          });
          setAuthError(toErrorMessage(error));
        }
      } finally {
        if (alive) {
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
      trackEvent("auth.sign_in.failed", {
        reason: message,
      });
      setAuthError(message);
      return { ok: false, error: message };
    }
    trackEvent("auth.sign_in.succeeded");
    identifyUser(email.trim(), email.trim());
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
      trackEvent("auth.sign_up.failed", {
        reason: message,
      });
      setAuthError(message);
      return { ok: false, error: message };
    }

    if (!signUpData.session) {
      trackEvent("auth.sign_up.pending_confirmation");
      return { ok: true, message: "Check your email to confirm your account, then log in." };
    }

    trackEvent("auth.sign_up.succeeded");
    identifyUser(email.trim(), email.trim());
    return { ok: true };
  };

  const signOut = async () => {
    await supabase.auth.signOut();
    trackEvent("auth.sign_out");
    resetUserIdentity();
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
      trackEvent("analytics.refresh.succeeded");
    } catch (error) {
      captureError(error, "refreshAnalytics.fetchRevoAnalyticsSummary");
      trackEvent("analytics.refresh.failed");
      setAuthError(toErrorMessage(error));
    } finally {
      setAnalyticsLoading(false);
    }
  };

  const saveQuestionnaireAnswers = async (answers: { redemptionType: RedemptionType; travelScope: TravelScope }) => {
    if (!session) {
      return;
    }
    try {
      await updateUserPreferences(session.user.id, {
        redemptionType: answers.redemptionType,
        travelScope: answers.travelScope,
      });
      const refreshed = await fetchUserAppData(session.user.id);
      setData(refreshed);
      trackEvent("questionnaire.answers_saved", answers);
    } catch (error) {
      captureError(error, "saveQuestionnaireAnswers");
      trackEvent("questionnaire.answers_save_failed");
      setAuthError(toErrorMessage(error));
      throw error;
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
      trackEvent("revo.prompt.submitted", {
        promptChars: trimmed.length,
      });
    } catch (error) {
      captureError(error, "submitPrompt");
      trackEvent("revo.prompt.failed");
      const message = toErrorMessage(error);
      setAuthError(message);
      if (message.toLowerCase().includes("timed out")) {
        const fallbackMessage: ChatMessage = {
          id: `local-timeout-${Date.now()}`,
          role: "assistant",
          content: "REVO timed out. Please try again in a few seconds.",
          createdAt: new Date().toISOString(),
        };
        setData((current) =>
          current
            ? {
                ...current,
                chatMessages: [...current.chatMessages, fallbackMessage],
              }
            : current
        );
      }
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
      trackEvent("wallet.card_added", {
        cardId,
      });
    } catch (error) {
      captureError(error, "addCardToWallet", {
        cardId,
      });
      trackEvent("wallet.card_add_failed", {
        cardId,
      });
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
      trackEvent("app.reset_demo_data");
    } catch (error) {
      captureError(error, "resetToSeed");
      trackEvent("app.reset_demo_data_failed");
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
    saveQuestionnaireAnswers,
  };
}
