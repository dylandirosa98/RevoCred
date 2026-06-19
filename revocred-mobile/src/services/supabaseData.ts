import { seedCardCatalog, seedCardSearchCatalog, seedMetrics, seedPopularPicks, seedProfile, seedQuickPrompts, seedTimeline, seedWalletCards } from "../data/seed";
import { AppData, Card, CardSearchEntry, CardStatus, ChatMessage, Profile, RedemptionType, RevoAnalyticsSummary, TravelScope } from "../types/models";
import { supabase } from "./supabaseClient";

type ProfileRow = {
  user_id: string;
  name: string;
  credit_card_strategy: string;
  goal: string;
  top_spend_categories: string;
  next_application_target: string;
  points_value: number;
  projected_yearly_value: number;
};

type WalletCardRow = {
  card_id: string;
  status: string;
};

type RevoMessageRow = {
  id: string;
  role: "user" | "assistant";
  content: string;
  created_at: string;
};

type RevoUsageLogRow = {
  status: string;
  latency_ms: number | null;
  created_at: string;
};

type UserPreferenceRow = {
  redemption_type: RedemptionType;
  travel_scope: TravelScope;
};

type CardCatalogRow = {
  id: string;
  issuer: string;
  brand: string;
  name: string;
  network: string | null;
  annual_fee: string;
  point_multipliers: string[] | null;
  transferable_points: boolean;
  transfer_partners: string[] | null;
  benefits: string[] | null;
  summary: string | null;
  best_use: string;
  multiplier: string;
  redemption_type: RedemptionType | null;
  travel_scope: TravelScope | null;
  no_foreign_tx_fee: boolean | null;
  annual_fee_tier: "0" | "low" | "mid" | "high" | null;
};

const REVO_CHAT_TIMEOUT_MS = 15000;
const REMOVED_CARD_IDS = new Set(["citi-custom-cash"]);

async function withTimeout<T>(promise: Promise<T>, timeoutMs: number, timeoutMessage: string): Promise<T> {
  let timeoutHandle: ReturnType<typeof setTimeout> | null = null;
  try {
    return await Promise.race([
      promise,
      new Promise<T>((_, reject) => {
        timeoutHandle = setTimeout(() => {
          reject(new Error(timeoutMessage));
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutHandle) {
      clearTimeout(timeoutHandle);
    }
  }
}

function isMissingTableError(error: unknown): boolean {
  if (!error || typeof error !== "object") {
    return false;
  }
  const maybeError = error as { code?: string; message?: string };
  return maybeError.code === "42P01" || maybeError.message?.toLowerCase().includes("does not exist") === true;
}

function toProfile(row: ProfileRow, preferences: UserPreferenceRow | null): Profile {
  return {
    name: row.name,
    creditCardStrategy: row.credit_card_strategy,
    goal: row.goal,
    topSpendCategories: row.top_spend_categories,
    nextApplicationTarget: row.next_application_target,
    redemptionType: preferences?.redemption_type,
    travelScope: preferences?.travel_scope,
  };
}

function toStatus(status: string): CardStatus {
  return status === "Inactive" ? "Inactive" : "Active";
}

function hydrateWallet(walletRows: WalletCardRow[]): Card[] {
  return walletRows
    .map((row) => {
      const card = seedCardCatalog.find((catalogCard) => catalogCard.id === row.card_id);
      if (!card) {
        return null;
      }
      return { ...card, status: toStatus(row.status) };
    })
    .filter((card): card is Card => Boolean(card));
}

function hydrateMessages(rows: RevoMessageRow[]): ChatMessage[] {
  return rows.map((row) => ({
    id: row.id,
    role: row.role,
    content: row.content,
    createdAt: row.created_at,
  }));
}

function mapCardCatalogRow(row: CardCatalogRow): CardSearchEntry {
  return {
    id: row.id,
    issuer: row.issuer,
    brand: row.brand,
    name: row.name,
    network: row.network ?? undefined,
    annualFee: row.annual_fee,
    pointMultipliers: row.point_multipliers ?? [],
    transferablePoints: row.transferable_points,
    transferPartners: row.transfer_partners ?? undefined,
    benefits: row.benefits ?? [],
    summary: row.summary ?? undefined,
    bestUse: row.best_use,
    multiplier: row.multiplier,
    redemptionType: row.redemption_type ?? undefined,
    travelScope: row.travel_scope ?? undefined,
    noForeignTxFee: row.no_foreign_tx_fee ?? undefined,
    annualFeeTier: row.annual_fee_tier ?? undefined,
  };
}

async function fetchUserPreferences(userId: string): Promise<UserPreferenceRow | null> {
  const { data, error } = await supabase
    .from("user_preferences")
    .select("redemption_type, travel_scope")
    .eq("user_id", userId)
    .maybeSingle<UserPreferenceRow>();

  if (error) {
    if (isMissingTableError(error)) {
      return null;
    }
    throw error;
  }
  return data ?? null;
}

async function fetchCardSearchCatalogFromDb(): Promise<CardSearchEntry[]> {
  const { data, error } = await supabase
    .from("card_catalog")
    .select(
      "id, issuer, brand, name, network, annual_fee, point_multipliers, transferable_points, transfer_partners, benefits, summary, best_use, multiplier, redemption_type, travel_scope, no_foreign_tx_fee, annual_fee_tier"
    )
    .order("issuer", { ascending: true })
    .order("name", { ascending: true })
    .returns<CardCatalogRow[]>();

  if (error) {
    if (isMissingTableError(error)) {
      return seedCardSearchCatalog.filter((card) => !REMOVED_CARD_IDS.has(card.id));
    }
    throw error;
  }
  if (!data?.length) {
    return seedCardSearchCatalog.filter((card) => !REMOVED_CARD_IDS.has(card.id));
  }
  return data.map(mapCardCatalogRow).filter((card) => !REMOVED_CARD_IDS.has(card.id));
}

function composeAppData(
  profileRow: ProfileRow,
  walletRows: WalletCardRow[],
  messageRows: RevoMessageRow[],
  preferences: UserPreferenceRow | null,
  cardSearchCatalog: CardSearchEntry[]
): AppData {
  const walletCards = hydrateWallet(walletRows);
  const activeIds = new Set(walletCards.map((card) => card.id));

  return {
    profile: toProfile(profileRow, preferences),
    metrics: {
      pointsValue: profileRow.points_value,
      projectedYearlyValue: profileRow.projected_yearly_value,
    },
    walletCards,
    strategyTimeline: seedTimeline,
    popularPicks: seedPopularPicks.map((card) => ({ ...card, status: activeIds.has(card.id) ? "Active" : "Inactive" })),
    cardSearchCatalog,
    quickPrompts: [...seedQuickPrompts],
    chatMessages: hydrateMessages(messageRows),
    cardCatalog: seedCardCatalog.map((card) => ({ ...card, status: activeIds.has(card.id) ? "Active" : "Inactive" })),
  };
}

function createAnalyticsSummary(rows: RevoUsageLogRow[]): RevoAnalyticsSummary {
  const total = rows.length;
  const successCount = rows.filter((row) => row.status === "success").length;
  const rateLimitedCount = rows.filter((row) => row.status === "rate_limited").length;
  const guardrailBlockedCount = rows.filter((row) => row.status === "guardrail_blocked").length;
  const providerErrorCount = rows.filter((row) => row.status === "provider_error").length;
  const latencyRows = rows.filter((row) => row.latency_ms !== null);
  const averageLatencyMs = latencyRows.length
    ? Math.round(latencyRows.reduce((sum, row) => sum + (row.latency_ms ?? 0), 0) / latencyRows.length)
    : 0;

  return {
    last24hRequests: total,
    successCount,
    rateLimitedCount,
    guardrailBlockedCount,
    providerErrorCount,
    successRate: total ? Math.round((successCount / total) * 100) : 0,
    averageLatencyMs,
    latestStatus: rows[0]?.status ?? "no_activity",
    generatedAt: new Date().toISOString(),
  };
}

export async function ensureUserBootstrap(userId: string): Promise<void> {
  const { data: existingProfile, error: profileReadError } = await supabase
    .from("profiles")
    .select("user_id")
    .eq("user_id", userId)
    .maybeSingle();
  if (profileReadError) {
    throw profileReadError;
  }

  if (!existingProfile) {
    const { error: profileInsertError } = await supabase.from("profiles").insert({
      user_id: userId,
      name: seedProfile.name,
      credit_card_strategy: seedProfile.creditCardStrategy,
      goal: seedProfile.goal,
      top_spend_categories: seedProfile.topSpendCategories,
      next_application_target: seedProfile.nextApplicationTarget,
      points_value: seedMetrics.pointsValue,
      projected_yearly_value: seedMetrics.projectedYearlyValue,
    });
    if (profileInsertError) {
      throw profileInsertError;
    }
  }

  const { data: existingWalletRows, error: walletReadError } = await supabase
    .from("wallet_cards")
    .select("card_id")
    .eq("user_id", userId)
    .limit(1);
  if (walletReadError) {
    throw walletReadError;
  }

  if (!existingWalletRows?.length) {
    const { error: walletInsertError } = await supabase.from("wallet_cards").insert(
      seedWalletCards.map((card) => ({
        user_id: userId,
        card_id: card.id,
        status: "Active",
      }))
    );
    if (walletInsertError) {
      throw walletInsertError;
    }
  }

  const { data: existingMessages, error: messageReadError } = await supabase
    .from("revo_messages")
    .select("id")
    .eq("user_id", userId)
    .limit(1);
  if (messageReadError) {
    throw messageReadError;
  }

  if (!existingMessages?.length) {
    const { error: messageInsertError } = await supabase.from("revo_messages").insert({
      user_id: userId,
      role: "assistant",
      content: "Ask me anything about your setup. I can help with card choice, timing, and points strategy.",
    });
    if (messageInsertError) {
      throw messageInsertError;
    }
  }

  const { data: existingPreferences, error: preferenceReadError } = await supabase
    .from("user_preferences")
    .select("user_id")
    .eq("user_id", userId)
    .maybeSingle();
  if (preferenceReadError) {
    if (isMissingTableError(preferenceReadError)) {
      return;
    }
    throw preferenceReadError;
  }

  if (!existingPreferences) {
    const { error: preferenceInsertError } = await supabase.from("user_preferences").insert({
      user_id: userId,
      redemption_type: "hybrid",
      travel_scope: "both",
    });
    if (preferenceInsertError && !isMissingTableError(preferenceInsertError)) {
      throw preferenceInsertError;
    }
  }
}

export async function fetchUserAppData(userId: string): Promise<AppData> {
  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("user_id, name, credit_card_strategy, goal, top_spend_categories, next_application_target, points_value, projected_yearly_value")
    .eq("user_id", userId)
    .maybeSingle<ProfileRow>();

  if (profileError) {
    throw profileError;
  }
  if (!profile) {
    throw new Error("Profile not found. Run bootstrap setup first.");
  }

  const [walletResult, messageResult, preferences, cardSearchCatalog] = await Promise.all([
    supabase.from("wallet_cards").select("card_id, status").eq("user_id", userId).order("created_at", { ascending: true }).returns<WalletCardRow[]>(),
    supabase.from("revo_messages").select("id, role, content, created_at").eq("user_id", userId).order("created_at", { ascending: true }).returns<RevoMessageRow[]>(),
    fetchUserPreferences(userId),
    fetchCardSearchCatalogFromDb(),
  ]);

  if (walletResult.error) {
    throw walletResult.error;
  }
  if (messageResult.error) {
    throw messageResult.error;
  }

  return composeAppData(profile, walletResult.data ?? [], messageResult.data ?? [], preferences, cardSearchCatalog);
}

export async function fetchRevoAnalyticsSummary(userId: string): Promise<RevoAnalyticsSummary> {
  const windowStart = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { data: logs, error } = await supabase
    .from("revo_usage_logs")
    .select("status, latency_ms, created_at")
    .eq("user_id", userId)
    .gte("created_at", windowStart)
    .order("created_at", { ascending: false })
    .limit(500)
    .returns<RevoUsageLogRow[]>();

  if (error) {
    throw error;
  }

  return createAnalyticsSummary(logs ?? []);
}

export async function addWalletCardForUser(userId: string, cardId: string, currentPoints: number, currentProjection: number): Promise<void> {
  const { error: insertError } = await supabase.from("wallet_cards").insert({
    user_id: userId,
    card_id: cardId,
    status: "Active",
  });
  if (insertError && !insertError.message.toLowerCase().includes("duplicate")) {
    throw insertError;
  }

  const { error: profileError } = await supabase
    .from("profiles")
    .update({
      points_value: currentPoints + 22,
      projected_yearly_value: currentProjection + 40,
    })
    .eq("user_id", userId);
  if (profileError) {
    throw profileError;
  }
}

export async function appendPromptAndReply(prompt: string): Promise<void> {
  const { data, error } = await withTimeout(
    supabase.functions.invoke("revo-chat", {
      body: { prompt },
    }),
    REVO_CHAT_TIMEOUT_MS,
    "REVO is taking too long to respond. Please try again."
  );

  if (error) {
    throw error;
  }
  if (!data?.assistantReply) {
    throw new Error("No assistant reply returned from revo-chat function.");
  }
}

export async function updateUserPreferences(
  userId: string,
  updates: {
    redemptionType?: RedemptionType;
    travelScope?: TravelScope;
  }
): Promise<void> {
  const payload: {
    user_id: string;
    redemption_type?: RedemptionType;
    travel_scope?: TravelScope;
  } = {
    user_id: userId,
  };

  if (updates.redemptionType) {
    payload.redemption_type = updates.redemptionType;
  }
  if (updates.travelScope) {
    payload.travel_scope = updates.travelScope;
  }

  const { error } = await supabase.from("user_preferences").upsert(payload, { onConflict: "user_id" });
  if (error) {
    throw error;
  }
}

export async function resetUserData(userId: string): Promise<void> {
  const { error: profileUpdateError } = await supabase
    .from("profiles")
    .update({
      name: seedProfile.name,
      credit_card_strategy: seedProfile.creditCardStrategy,
      goal: seedProfile.goal,
      top_spend_categories: seedProfile.topSpendCategories,
      next_application_target: seedProfile.nextApplicationTarget,
      points_value: seedMetrics.pointsValue,
      projected_yearly_value: seedMetrics.projectedYearlyValue,
    })
    .eq("user_id", userId);
  if (profileUpdateError) {
    throw profileUpdateError;
  }

  const { error: walletDeleteError } = await supabase.from("wallet_cards").delete().eq("user_id", userId);
  if (walletDeleteError) {
    throw walletDeleteError;
  }

  const { error: messageDeleteError } = await supabase.from("revo_messages").delete().eq("user_id", userId);
  if (messageDeleteError) {
    throw messageDeleteError;
  }

  await ensureUserBootstrap(userId);
}
