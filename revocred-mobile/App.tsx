import { StatusBar } from "expo-status-bar";
import { Ionicons, MaterialCommunityIcons } from "@expo/vector-icons";
import { Component, ComponentProps, ReactNode, useEffect, useMemo, useRef, useState } from "react";
import {
  ActivityIndicator,
  Animated,
  Image,
  Keyboard,
  Modal,
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import { useAppData } from "./src/hooks/useAppData";
import { initializeObservability, trackEvent, trackScreenView } from "./src/services/observability";
import { Card, CardSearchEntry, ChatMessage, Profile, Recommendation, RedemptionType, RevoAnalyticsSummary, TabKey, TravelScope } from "./src/types/models";

const palette = {
  background: "#060B17",
  surface: "#0D152B",
  surfaceRaised: "#121D38",
  border: "#253354",
  textPrimary: "#EEF3FF",
  textSecondary: "#9BA8CC",
  accent: "#6F8BFF",
  success: "#39D7A7",
  warning: "#FFB45E",
};

const spacing = {
  xs: 8,
  sm: 16,
  md: 24,
  lg: 32,
};

const radii = {
  sm: 12,
  md: 16,
  lg: 24,
};

const typeScale = {
  xs: 12,
  sm: 14,
  base: 16,
  lg: 20,
  xl: 28,
  hero: 36,
};

function containsToken(source: string, token: string): boolean {
  return source.includes(token);
}

function RevoLogo({ size = "md" }: { size?: "md" | "lg" }) {
  const dimensions = size === "lg" ? 44 : 34;
  const borderRadius = size === "lg" ? 12 : 9;

  return (
    <Image
      source={require("./assets/icon.png")}
      style={[styles.brandLogoImage, { width: dimensions, height: dimensions, borderRadius }]}
      resizeMode="cover"
      accessibilityLabel="RevoCred"
    />
  );
}

function looksLight(colorHex: string): boolean {
  const normalized = colorHex.replace("#", "");
  const cleanHex = normalized.length === 3 ? normalized.split("").map((char) => `${char}${char}`).join("") : normalized;
  const red = Number.parseInt(cleanHex.slice(0, 2), 16);
  const green = Number.parseInt(cleanHex.slice(2, 4), 16);
  const blue = Number.parseInt(cleanHex.slice(4, 6), 16);
  if (Number.isNaN(red) || Number.isNaN(green) || Number.isNaN(blue)) {
    return false;
  }
  const luminance = (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255;
  return luminance > 0.62;
}

function topCardColor(cardId: string, brand: string, name: string): string {
  const fingerprint = `${cardId} ${brand} ${name}`.toLowerCase();

  if (containsToken(fingerprint, "amex") || containsToken(fingerprint, "american express")) {
    if (containsToken(fingerprint, "gold")) return "#C89A3D";
    if (containsToken(fingerprint, "platinum")) return "#AAB4C2";
    if (containsToken(fingerprint, "green")) return "#2E6A4C";
    if (containsToken(fingerprint, "blue cash")) return "#2F63AF";
    if (containsToken(fingerprint, "delta reserve")) return "#5A4F7B";
    if (containsToken(fingerprint, "delta")) return "#355E9C";
    if (containsToken(fingerprint, "hilton")) return "#344D86";
    if (containsToken(fingerprint, "marriott")) return "#566D8B";
    return "#3D5F8D";
  }

  if (containsToken(fingerprint, "chase")) {
    if (containsToken(fingerprint, "sapphire reserve")) return "#0F2E63";
    if (containsToken(fingerprint, "sapphire preferred")) return "#1E4E9D";
    if (containsToken(fingerprint, "freedom unlimited")) return "#2E59CA";
    if (containsToken(fingerprint, "freedom flex")) return "#6A3DB6";
    if (containsToken(fingerprint, "ink")) return "#214A87";
    if (containsToken(fingerprint, "world of hyatt")) return "#474F68";
    if (containsToken(fingerprint, "united")) return "#18508C";
    if (containsToken(fingerprint, "southwest")) return "#5C2B89";
    if (containsToken(fingerprint, "ihg")) return "#5B4676";
    return "#2257AA";
  }

  if (containsToken(fingerprint, "capital one")) {
    if (containsToken(fingerprint, "venture x")) return "#1B2E57";
    if (containsToken(fingerprint, "venture")) return "#34619C";
    if (containsToken(fingerprint, "quicksilver")) return "#7A828E";
    if (containsToken(fingerprint, "savor")) return "#A33845";
    if (containsToken(fingerprint, "spark")) return "#3E4F6C";
    return "#3A5488";
  }

  if (containsToken(fingerprint, "discover")) return "#E37D2F";

  if (containsToken(fingerprint, "citi")) {
    if (containsToken(fingerprint, "strata")) return "#1E4D8D";
    if (containsToken(fingerprint, "premier")) return "#225EA7";
    if (containsToken(fingerprint, "double cash")) return "#2A66AC";
    if (containsToken(fingerprint, "custom cash")) return "#2E71BC";
    return "#245FAE";
  }

  if (containsToken(fingerprint, "bilt")) return "#302E53";
  if (containsToken(fingerprint, "wells fargo") || containsToken(fingerprint, "autograph")) return "#A43A45";
  if (containsToken(fingerprint, "u.s. bank") || containsToken(fingerprint, "us bank") || containsToken(fingerprint, "altitude")) return "#2F5C95";
  if (containsToken(fingerprint, "apple card")) return "#D5DCE5";
  if (containsToken(fingerprint, "bank of america")) return "#C53D46";
  if (containsToken(fingerprint, "amazon")) return "#25272E";

  const fallbackPalette = ["#1A2F4F", "#27445E", "#3B3566", "#215165", "#5B3F61", "#27456B", "#364E7B", "#1F4950"];
  const hash = Array.from(fingerprint).reduce((sum, char) => sum + char.charCodeAt(0), 0);
  return fallbackPalette[hash % fallbackPalette.length];
}

function GenericCardSurface({
  cardId,
  brand,
  name,
  containerStyle,
  brandStyle,
  nameStyle,
}: {
  cardId: string;
  brand: string;
  name: string;
  containerStyle: object;
  brandStyle: object;
  nameStyle: object;
}) {
  const backgroundColor = topCardColor(cardId, brand, name);
  const lightBackground = looksLight(backgroundColor);

  return (
    <View style={[styles.genericCardSurface, { backgroundColor }, containerStyle]}>
      <Text style={[styles.cardArtBrand, brandStyle, lightBackground ? styles.cardArtBrandOnLight : undefined]}>{brand.toUpperCase()}</Text>
      <Text style={[styles.cardArtName, nameStyle, lightBackground ? styles.cardArtNameOnLight : undefined]} numberOfLines={2}>
        {name}
      </Text>
    </View>
  );
}

function CardPreview({ card }: { card: Card }) {
  return (
    <View style={styles.cardFlipContainer}>
      <GenericCardSurface
        cardId={card.id}
        brand={card.brand}
        name={card.name}
        containerStyle={styles.cardPreview}
        brandStyle={styles.cardPreviewBrand}
        nameStyle={styles.cardPreviewName}
      />
    </View>
  );
}

function WalletCard({
  card,
  expanded,
  onToggle,
  onAskRevo,
}: {
  card: Card;
  expanded: boolean;
  onToggle: () => void;
  onAskRevo: (prompt: string) => void;
}) {
  const flipProgress = useRef(new Animated.Value(expanded ? 180 : 0)).current;
  const visibleBenefits = card.benefits.slice(0, 2);
  const hiddenBenefits = card.benefits.slice(2);
  const hiddenBenefitCount = Math.max(0, card.benefits.length - visibleBenefits.length);
  const [showBenefitsModal, setShowBenefitsModal] = useState(false);

  useEffect(() => {
    Animated.spring(flipProgress, {
      toValue: expanded ? 180 : 0,
      friction: 8,
      tension: 70,
      useNativeDriver: true,
    }).start();
  }, [expanded, flipProgress]);

  const frontRotation = flipProgress.interpolate({
    inputRange: [0, 180],
    outputRange: ["0deg", "180deg"],
  });

  const backRotation = flipProgress.interpolate({
    inputRange: [0, 180],
    outputRange: ["180deg", "360deg"],
  });

  const frontOpacity = flipProgress.interpolate({
    inputRange: [0, 89, 90, 180],
    outputRange: [1, 1, 0, 0],
  });

  const backOpacity = flipProgress.interpolate({
    inputRange: [0, 89, 90, 180],
    outputRange: [0, 0, 1, 1],
  });

  return (
    <Pressable onPress={onToggle} style={styles.walletCard}>
      <View style={[styles.walletCardFlipFrame, expanded ? styles.walletCardFlipFrameExpanded : styles.walletCardFlipFrameCollapsed]}>
        <Animated.View
          style={[
            styles.walletCardFace,
            {
              opacity: frontOpacity,
              transform: [{ perspective: 1000 }, { rotateY: frontRotation }],
            },
          ]}
        >
          <View style={styles.walletCardTopRow}>
            <View style={[styles.walletCardPreviewContainer, expanded ? styles.walletCardPreviewContainerExpanded : styles.walletCardPreviewContainerCollapsed]}>
              <GenericCardSurface
                cardId={card.id}
                brand={card.brand}
                name={card.name}
                containerStyle={styles.cardPreview}
                brandStyle={styles.cardPreviewBrand}
                nameStyle={styles.cardPreviewName}
              />
            </View>
            <View style={styles.walletCardBody}>
              <View style={styles.walletCardHeader}>
                <Text style={styles.walletCardName}>{card.name}</Text>
                <View style={styles.badge}>
                  <Text style={styles.badgeText}>{card.status}</Text>
                </View>
              </View>
              <Text style={styles.walletCardSubLabel}>BEST USE</Text>
              <Text style={styles.walletCardBestUse}>{card.bestUse}</Text>
            </View>
          </View>
          <View style={styles.walletFooterRow}>
            <View style={styles.multiplierBubble}>
              <Text style={styles.multiplierText}>{card.multiplier}</Text>
            </View>
            <Text style={styles.tapHint}>Tap to flip</Text>
          </View>
        </Animated.View>

        <Animated.View
          style={[
            styles.walletCardFace,
            styles.walletCardFaceBack,
            {
              opacity: backOpacity,
              transform: [{ perspective: 1000 }, { rotateY: backRotation }],
            },
          ]}
        >
          <View style={styles.walletCardBackBody}>
            <View style={styles.walletCardBackTop}>
              <Text style={styles.expandedTitle}>Key Benefits</Text>
              <View style={styles.walletCardBackBenefits}>
                {visibleBenefits.map((benefit) => (
                  <View key={`${card.id}-${benefit}`} style={styles.benefitPill}>
                    <Text style={styles.benefitText}>{benefit}</Text>
                  </View>
                ))}
              </View>
              {hiddenBenefitCount ? (
                <Pressable
                  style={styles.walletCardMoreBenefitsButton}
                  onPress={(event) => {
                    event.stopPropagation();
                    setShowBenefitsModal(true);
                  }}
                >
                  <Text style={styles.walletCardMoreBenefits}>+{hiddenBenefitCount} more benefit(s)</Text>
                </Pressable>
              ) : null}
            </View>
            <View style={styles.walletCardBackBottom}>
              <Pressable
                style={styles.askRevoButton}
                onPress={(event) => {
                  event.stopPropagation();
                  onAskRevo(`Tell me about ${card.name} benefits and how to maximize it.`);
                }}
              >
                <Text style={styles.askRevoLabel}>ASK REVO</Text>
                <Text style={styles.askRevoText}>Ask REVO about {card.name} card</Text>
              </Pressable>
              <Text style={[styles.tapHint, styles.tapHintBack]}>Tap to return</Text>
            </View>
          </View>
        </Animated.View>
      </View>
      <Modal visible={showBenefitsModal} transparent animationType="fade" onRequestClose={() => setShowBenefitsModal(false)}>
        <Pressable style={styles.benefitsModalBackdrop} onPress={() => setShowBenefitsModal(false)}>
          <Pressable
            style={styles.benefitsModalSheet}
            onPress={(event) => {
              event.stopPropagation();
            }}
          >
            <Text style={styles.benefitsModalTitle}>More benefits for {card.name}</Text>
            <View style={styles.benefitsModalList}>
              {hiddenBenefits.map((benefit) => (
                <View key={`${card.id}-hidden-${benefit}`} style={styles.benefitPill}>
                  <Text style={styles.benefitText}>{benefit}</Text>
                </View>
              ))}
            </View>
            <Pressable style={styles.benefitsModalCloseButton} onPress={() => setShowBenefitsModal(false)}>
              <Text style={styles.benefitsModalCloseText}>Done</Text>
            </Pressable>
          </Pressable>
        </Pressable>
      </Modal>
    </Pressable>
  );
}

function AuthScreen({
  onSignIn,
  onSignUp,
  authError,
}: {
  onSignIn: (email: string, password: string) => Promise<{ ok: boolean; error?: string; message?: string }>;
  onSignUp: (email: string, password: string) => Promise<{ ok: boolean; error?: string; message?: string }>;
  authError: string | null;
}) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [localMessage, setLocalMessage] = useState<string | null>(null);

  const submitSignIn = async () => {
    setSubmitting(true);
    setLocalMessage(null);
    const result = await onSignIn(email, password);
    if (!result.ok) {
      setLocalMessage(result.error ?? "Login failed.");
    } else {
      setLocalMessage("Logged in.");
    }
    setSubmitting(false);
  };

  const submitSignUp = async () => {
    setSubmitting(true);
    setLocalMessage(null);
    const result = await onSignUp(email, password);
    if (!result.ok) {
      setLocalMessage(result.error ?? "Sign up failed.");
    } else if (result.message) {
      setLocalMessage(result.message);
    } else {
      setLocalMessage("Account created.");
    }
    setSubmitting(false);
  };

  const messageToShow = authError ?? localMessage;

  return (
    <View style={styles.authWrap}>
      <RevoLogo size="lg" />
      <Text style={styles.authTitle}>Sign in to continue</Text>
      <Text style={styles.authSubtitle}>Your wallet, strategy, and REVO chat are now synced with Supabase.</Text>
      <View style={styles.authCard}>
        <TextInput
          value={email}
          onChangeText={setEmail}
          autoCapitalize="none"
          keyboardType="email-address"
          placeholder="Email"
          placeholderTextColor="#6d7aab"
          style={styles.authInput}
        />
        <TextInput
          value={password}
          onChangeText={setPassword}
          secureTextEntry
          placeholder="Password"
          placeholderTextColor="#6d7aab"
          style={styles.authInput}
        />
        <Pressable style={[styles.authButton, submitting ? styles.disabledCard : undefined]} onPress={() => void submitSignIn()} disabled={submitting}>
          <Text style={styles.authButtonText}>Log in</Text>
        </Pressable>
        <Pressable style={[styles.authButtonSecondary, submitting ? styles.disabledCard : undefined]} onPress={() => void submitSignUp()} disabled={submitting}>
          <Text style={styles.authButtonText}>Create account</Text>
        </Pressable>
      </View>
      {messageToShow ? <Text style={styles.authMessage}>{messageToShow}</Text> : null}
    </View>
  );
}

function HomeScreen({
  cards,
  pointsValue,
  projectedValue,
  onAskRevo,
  onOpenRoadmap,
}: {
  cards: Card[];
  pointsValue: number;
  projectedValue: number;
  onAskRevo: (prompt: string) => void;
  onOpenRoadmap: () => void;
}) {
  const [expandedCardId, setExpandedCardId] = useState<string | null>(null);
  const overviewCards = cards.slice(0, 2);
  const estimatedFirstYearValue = Math.round(projectedValue + pointsValue * 7);
  const strategyScore = Math.min(97, 82 + cards.length * 2);
  const topPriorities = ["Maximize travel rewards", "Earn more on dining & groceries", "Unlock premium travel perks"];

  return (
    <ScrollView contentContainerStyle={styles.screenBody}>
      <View style={styles.screenHeader}>
        <RevoLogo />
        <Pressable style={styles.homeBellButton}>
          <Ionicons name="notifications-outline" size={20} color={palette.textPrimary} />
        </Pressable>
      </View>
      <Text style={styles.strategyReadyHeading}>Your Strategy is Ready 🎉</Text>
      <Text style={styles.panelHint}>{"Here's your personalized credit card strategy."}</Text>

      <View style={styles.strategyValueCard}>
        <Text style={styles.cardSectionLabel}>ESTIMATED FIRST-YEAR VALUE</Text>
        <Text style={styles.strategyValueAmount}>${estimatedFirstYearValue.toLocaleString()}</Text>
        <View style={styles.strategyStatsRow}>
          <View style={styles.strategyStatTile}>
            <Ionicons name="airplane" size={15} color="#72A2FF" />
            <Text style={styles.strategyStatLabel}>Travel</Text>
            <Text style={styles.strategyStatValue}>4</Text>
          </View>
          <View style={styles.strategyStatTile}>
            <Ionicons name="bed-outline" size={15} color="#8B5CF6" />
            <Text style={styles.strategyStatLabel}>Hotels</Text>
            <Text style={styles.strategyStatValue}>6</Text>
          </View>
          <View style={styles.strategyStatTile}>
            <Ionicons name="cash-outline" size={15} color="#34D399" />
            <Text style={styles.strategyStatLabel}>Cash Value</Text>
            <Text style={styles.strategyStatValue}>${projectedValue}</Text>
          </View>
        </View>
      </View>

      <View style={styles.optimizationCard}>
        <View style={styles.optimizationRing}>
          <Text style={styles.optimizationRingValue}>{strategyScore}</Text>
          <Text style={styles.optimizationRingTotal}>/100</Text>
        </View>
        <View style={styles.optimizationMeta}>
          <Text style={styles.optimizationTitle}>Optimization Score</Text>
          <Text style={styles.metricHint}>{"You're doing great. REVO keeps tuning your setup as your profile grows."}</Text>
        </View>
      </View>

      <View style={styles.panelSection}>
        <Text style={styles.cardSectionLabel}>YOUR TOP PRIORITIES</Text>
        {topPriorities.map((priority) => (
          <View key={priority} style={styles.priorityRow}>
            <Ionicons name="sparkles" size={14} color="#78A4FF" />
            <Text style={styles.priorityText}>{priority}</Text>
          </View>
        ))}
      </View>

      <GradientButton label="View Your Roadmap" trailingIcon="chevron-forward" onPress={onOpenRoadmap} />

      <View style={styles.panelSection}>
        <Text style={styles.cardSectionLabel}>WALLET SNAPSHOT</Text>
        <Text style={styles.panelHint}>Tap any card to flip and see why it matters in your strategy.</Text>
        {overviewCards.map((card) => (
          <WalletCard
            key={card.id}
            card={card}
            expanded={expandedCardId === card.id}
            onToggle={() => setExpandedCardId((current) => (current === card.id ? null : card.id))}
            onAskRevo={onAskRevo}
          />
        ))}
      </View>

      <Pressable style={styles.heroActionCard} onPress={() => onAskRevo("What card should I use right now?")}>
        <Text style={styles.cardSectionLabel}>NEXT BEST ACTION</Text>
        <Text style={styles.heroActionTitle}>Ask REVO what to use now</Text>
        <Text style={styles.metricHint}>Get an instant recommendation based on your wallet setup.</Text>
      </Pressable>
    </ScrollView>
  );
}

function CardsScreen({
  cards,
  availableCardsToAdd,
  onAddCard,
  onAskRevo,
}: {
  cards: Card[];
  availableCardsToAdd: Card[];
  onAddCard: (cardId: string) => void;
  onAskRevo: (prompt: string) => void;
}) {
  const [expandedCardId, setExpandedCardId] = useState<string | null>(null);
  const [showCardPicker, setShowCardPicker] = useState(false);
  const nextCardToAdd = availableCardsToAdd[0];

  return (
    <ScrollView contentContainerStyle={styles.screenBody}>
      <View style={styles.screenHeader}>
        <Text style={styles.cardSectionLabel}>CARDS</Text>
        <View style={styles.walletCountCard}>
          <Text style={styles.cardSectionLabel}>ACTIVE</Text>
          <Text style={styles.walletCountValue}>{cards.length} cards</Text>
        </View>
      </View>
      <Text style={styles.screenSectionTitle}>Your Card Setup</Text>
      <Text style={styles.panelHint}>Tap any card to flip it and view the key benefits behind your setup.</Text>
      {cards.map((card) => (
        <WalletCard
          key={card.id}
          card={card}
          expanded={expandedCardId === card.id}
          onToggle={() => setExpandedCardId((current) => (current === card.id ? null : card.id))}
          onAskRevo={onAskRevo}
        />
      ))}
      <Pressable
        style={[styles.addCardButton, !nextCardToAdd ? styles.disabledCard : undefined]}
        disabled={!nextCardToAdd}
        onPress={() => setShowCardPicker((current) => !current)}
      >
        <Text style={styles.addCardPlus}>{showCardPicker ? "−" : "+"}</Text>
        <Text style={styles.addCardText}>{nextCardToAdd ? "Add a card to wallet" : "All cards added"}</Text>
        {nextCardToAdd ? <Text style={styles.addCardHint}>{availableCardsToAdd.length} cards available</Text> : null}
      </Pressable>
      {showCardPicker && availableCardsToAdd.length ? (
        <View style={styles.addCardPickerPanel}>
          {availableCardsToAdd.map((card) => (
            <View key={`add-${card.id}`} style={styles.addCardOptionRow}>
              <View style={styles.addCardOptionMeta}>
                <Text style={styles.addCardOptionName}>{card.name}</Text>
                <Text style={styles.addCardOptionHint}>
                  {card.brand} • {card.bestUse} • {card.multiplier}
                </Text>
              </View>
              <Pressable
                style={styles.addCardOptionButton}
                onPress={() => {
                  onAddCard(card.id);
                  setShowCardPicker(false);
                }}
              >
                <Text style={styles.addCardOptionButtonText}>Add</Text>
              </Pressable>
            </View>
          ))}
        </View>
      ) : null}
    </ScrollView>
  );
}

function StrategyScreen({
  timeline,
  recommendedCards,
  searchCatalog,
  onAskRevo,
}: {
  timeline: Recommendation[];
  recommendedCards: Card[];
  searchCatalog: CardSearchEntry[];
  onAskRevo: (prompt: string) => void;
}) {
  const [openRecommendationIds, setOpenRecommendationIds] = useState<string[]>([]);
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedSearchCard, setSelectedSearchCard] = useState<CardSearchEntry | null>(null);

  const toggleRecommendation = (id: string) => {
    setOpenRecommendationIds((existing) =>
      existing.includes(id) ? existing.filter((entry) => entry !== id) : [...existing, id]
    );
  };

  const normalizedSearch = searchTerm.trim().toLowerCase();
  const searchTokens = normalizedSearch.split(/\s+/).filter(Boolean);
  const searchResults = useMemo(() => {
    if (!searchTokens.length) {
      return [];
    }
    return searchCatalog
      .map((card) => {
        const id = card.id.toLowerCase();
        const issuer = card.issuer.toLowerCase();
        const brand = card.brand.toLowerCase();
        const name = card.name.toLowerCase();
        const searchableFields = [id, issuer, brand, name];

        let score = 0;
        if (id === normalizedSearch) {
          score += 120;
        }
        if (name === normalizedSearch) {
          score += 100;
        }
        if (issuer === normalizedSearch) {
          score += 95;
        }
        if (brand === normalizedSearch) {
          score += 90;
        }

        for (const token of searchTokens) {
          const exactFieldMatch = searchableFields.some((field) => field === token);
          const startsWithMatch = searchableFields.some((field) => field.startsWith(token));
          const wordMatch = searchableFields.some((field) =>
            field
              .split(/[\s-]+/)
              .some((word) => word.startsWith(token))
          );

          if (exactFieldMatch) {
            score += 30;
          } else if (startsWithMatch || wordMatch) {
            score += 14;
          } else {
            return null;
          }
        }

        return { card, score };
      })
      .filter((entry): entry is { card: CardSearchEntry; score: number } => Boolean(entry))
      .sort((a, b) => (b.score === a.score ? a.card.name.localeCompare(b.card.name) : b.score - a.score))
      .map((entry) => entry.card);
  }, [normalizedSearch, searchCatalog, searchTokens]);

  const roadmapEntries = useMemo(() => {
    const accentPalette = ["#34D399", "#5B7CFA", "#8B5CF6", "#F5B740"];
    return timeline.map((entry, index) => {
      const card = recommendedCards[index % Math.max(recommendedCards.length, 1)] ?? null;
      const stageLabel = index === 0 ? "Apply Now" : `In ${index * 6} Months`;
      const estimatedValue = 220 + (index + 1) * 190 + (card?.benefits.length ?? 2) * 40;
      return {
        ...entry,
        card,
        stageLabel,
        accent: accentPalette[index % accentPalette.length],
        estimatedValue,
      };
    });
  }, [recommendedCards, timeline]);

  return (
    <>
      <ScrollView contentContainerStyle={styles.screenBody}>
        <Text style={styles.cardSectionLabel}>STRATEGY</Text>
        <Text style={styles.screenSectionTitle}>Your Roadmap</Text>
        <Text style={styles.panelHint}>The best cards to apply for and when.</Text>
        <View style={styles.roadmapSummaryCard}>
          <Text style={styles.roadmapSummaryTitle}>Built for your profile</Text>
          <Text style={styles.roadmapSummaryText}>
            Apply in a sequence that balances approval odds, welcome bonus timing, and long-term category coverage.
          </Text>
        </View>

        <View style={styles.roadmapTimeline}>
          {roadmapEntries.map((entry, index) => (
            <View key={entry.id} style={styles.roadmapStepRow}>
              <View style={styles.roadmapRailWrap}>
                <View style={[styles.roadmapDot, { backgroundColor: entry.accent }]} />
                {index < roadmapEntries.length - 1 ? <View style={styles.roadmapRail} /> : null}
              </View>

              <View style={styles.roadmapStepCard}>
                <Text style={[styles.roadmapStageLabel, { color: entry.accent }]}>{entry.stageLabel}</Text>
                <View style={styles.roadmapHeaderRow}>
                  {entry.card ? (
                    <GenericCardSurface
                      cardId={entry.card.id}
                      brand={entry.card.brand}
                      name={entry.card.name}
                      containerStyle={styles.roadmapPreviewCard}
                      brandStyle={styles.searchPhotoBrand}
                      nameStyle={styles.searchPhotoName}
                    />
                  ) : null}
                  <View style={styles.roadmapHeaderMeta}>
                    <Text style={styles.roadmapCardTitle}>{entry.card?.name ?? entry.title}</Text>
                    <Text style={styles.roadmapCardSubtitle}>{entry.note}</Text>
                  </View>
                </View>

                {entry.card ? (
                  <View style={styles.roadmapBenefits}>
                    {entry.card.benefits.slice(0, 2).map((benefit) => (
                      <View key={`${entry.id}-${benefit}`} style={styles.roadmapBenefitRow}>
                        <Ionicons name="checkmark-circle" size={14} color="#6F8BFF" />
                        <Text style={styles.roadmapBenefitText}>{benefit}</Text>
                      </View>
                    ))}
                  </View>
                ) : null}

                <View style={styles.roadmapValueRow}>
                  <Text style={styles.roadmapValueLabel}>Est. Value</Text>
                  <Text style={styles.roadmapValueAmount}>${entry.estimatedValue}</Text>
                </View>
                {entry.card ? (
                  <Pressable style={styles.askRevoButton} onPress={() => onAskRevo(`Tell me more about ${entry.card?.name} and timing`)}>
                    <Text style={styles.askRevoLabel}>ASK REVO</Text>
                    <Text style={styles.askRevoText}>Should I apply now or wait?</Text>
                  </Pressable>
                ) : null}
              </View>
            </View>
          ))}
          <Text style={styles.roadmapFootnote}>Timeline is based on good credit and approval odds.</Text>
        </View>

        <View style={styles.searchBar}>
          <TextInput
            value={searchTerm}
            onChangeText={setSearchTerm}
            placeholder="Search credit cards (e.g. Amex Gold, Venture X)"
            placeholderTextColor={palette.textSecondary}
            style={styles.searchInput}
            autoCapitalize="none"
            autoCorrect={false}
          />
        </View>

        {normalizedSearch ? (
          <View style={styles.panelSection}>
            <Text style={styles.cardSectionLabel}>SEARCH RESULTS</Text>
            <Text style={styles.panelHint}>
              {searchResults.length
                ? `${searchResults.length} card${searchResults.length > 1 ? "s" : ""} found`
                : "No matches yet. Try a different keyword."}
            </Text>
            {searchResults.length ? (
              <>
                <Text style={styles.searchResultsHint}>Tap any card image to view full details.</Text>
                <View style={styles.searchPhotoGrid}>
                  {searchResults.map((card) => (
                    <Pressable key={`${card.id}-search-result`} style={styles.searchPhotoTile} onPress={() => setSelectedSearchCard(card)}>
                      <GenericCardSurface
                        cardId={card.id}
                        brand={card.brand}
                        name={card.name}
                        containerStyle={styles.searchPhotoCard}
                        brandStyle={styles.searchPhotoBrand}
                        nameStyle={styles.searchPhotoName}
                      />
                      <Text style={styles.searchPhotoTileTitle} numberOfLines={1}>
                        {card.name}
                      </Text>
                      <Text style={styles.searchPhotoTileHint}>{card.annualFee}</Text>
                    </Pressable>
                  ))}
                </View>
              </>
            ) : null}
          </View>
        ) : null}

        <View style={styles.panelSection}>
          <Text style={styles.cardSectionLabel}>POPULAR PICKS</Text>
          {recommendedCards.map((card) => {
            const isOpen = openRecommendationIds.includes(card.id);
            return (
              <Pressable key={card.id} style={styles.recommendationCard} onPress={() => toggleRecommendation(card.id)}>
                <View style={styles.recommendationTop}>
                  <CardPreview card={card} />
                  <View style={styles.recommendationMeta}>
                    <Text style={styles.recommendationBrand}>{card.brand}</Text>
                    <Text style={styles.recommendationName}>{card.name}</Text>
                  </View>
                  <Text style={styles.chevron}>{isOpen ? "˄" : "›"}</Text>
                </View>
                {isOpen ? (
                  <View style={styles.recommendationExpanded}>
                    {card.benefits.map((benefit) => (
                      <View key={`${card.id}-pick-${benefit}`} style={styles.benefitPill}>
                        <Text style={styles.benefitText}>{benefit}</Text>
                      </View>
                    ))}
                    <Pressable style={styles.askRevoButton} onPress={() => onAskRevo(`Tell me more about ${card.name} card`)}>
                      <Text style={styles.askRevoLabel}>ASK REVO</Text>
                      <Text style={styles.askRevoText}>Ask REVO about {card.name} card</Text>
                    </Pressable>
                  </View>
                ) : null}
              </Pressable>
            );
          })}
        </View>
      </ScrollView>

      <Modal visible={Boolean(selectedSearchCard)} transparent animationType="slide" onRequestClose={() => setSelectedSearchCard(null)}>
        <View style={styles.searchModalBackdrop}>
          <View style={styles.searchModalSheet}>
            <View style={styles.searchModalHandle} />
            <View style={styles.searchModalHeader}>
              <Text style={styles.searchModalTitle}>Card details</Text>
              <Pressable style={styles.searchModalCloseButton} onPress={() => setSelectedSearchCard(null)}>
                <Text style={styles.searchModalCloseButtonText}>Close</Text>
              </Pressable>
            </View>

            {selectedSearchCard ? (
              <ScrollView contentContainerStyle={styles.searchModalBody}>
                <GenericCardSurface
                  cardId={selectedSearchCard.id}
                  brand={selectedSearchCard.brand}
                  name={selectedSearchCard.name}
                  containerStyle={styles.searchModalHeroCard}
                  brandStyle={styles.searchPhotoBrand}
                  nameStyle={styles.searchModalHeroName}
                />

                <View style={styles.searchModalInfoGrid}>
                  <View style={styles.searchModalInfoTile}>
                    <Text style={styles.searchModalInfoLabel}>ANNUAL FEE</Text>
                    <Text style={styles.searchModalInfoValue}>{selectedSearchCard.annualFee}</Text>
                  </View>
                  <View style={styles.searchModalInfoTile}>
                    <Text style={styles.searchModalInfoLabel}>TOP EARN</Text>
                    <Text style={styles.searchModalInfoValue}>{selectedSearchCard.multiplier}</Text>
                  </View>
                  <View style={styles.searchModalInfoTile}>
                    <Text style={styles.searchModalInfoLabel}>POINTS</Text>
                    <Text style={styles.searchModalInfoValue}>{selectedSearchCard.transferablePoints ? "Transferable" : "Cash Back"}</Text>
                  </View>
                </View>

                <Text style={styles.searchModalSectionTitle}>Best use</Text>
                <Text style={styles.searchModalBestUse}>{selectedSearchCard.bestUse}</Text>

                <Text style={styles.searchModalSectionTitle}>Point multipliers</Text>
                <View style={styles.searchResultBenefitsWrap}>
                  {selectedSearchCard.pointMultipliers.map((line) => (
                    <Text key={`${selectedSearchCard.id}-mult-${line}`} style={styles.searchModalListItem}>
                      • {line}
                    </Text>
                  ))}
                </View>

                <Text style={styles.searchModalSectionTitle}>Benefits</Text>
                <View style={styles.searchResultBenefitsWrap}>
                  {selectedSearchCard.benefits.map((line) => (
                    <Text key={`${selectedSearchCard.id}-benefit-${line}`} style={styles.searchModalListItem}>
                      • {line}
                    </Text>
                  ))}
                </View>
              </ScrollView>
            ) : null}
          </View>
        </View>
      </Modal>
    </>
  );
}

function RevoScreen({
  quickPrompts,
  messages,
  onSubmitPrompt,
}: {
  quickPrompts: string[];
  messages: ChatMessage[];
  onSubmitPrompt: (prompt: string) => Promise<void>;
}) {
  const [question, setQuestion] = useState("");
  const [isThinking, setIsThinking] = useState(false);
  const [isComposerFocused, setIsComposerFocused] = useState(false);
  const [keyboardHeight, setKeyboardHeight] = useState(0);
  const [composerHeight, setComposerHeight] = useState(84);
  const [optimisticUserMessage, setOptimisticUserMessage] = useState<ChatMessage | null>(null);
  const chatScrollRef = useRef<ScrollView | null>(null);
  const scrollTimersRef = useRef<Array<ReturnType<typeof setTimeout>>>([]);

  const visibleMessages = optimisticUserMessage ? [...messages, optimisticUserMessage] : messages;

  const scrollToLatest = (animated: boolean) => {
    chatScrollRef.current?.scrollToEnd({ animated });
  };
  const scheduleScrollToLatest = (animated: boolean) => {
    for (const timer of scrollTimersRef.current) {
      clearTimeout(timer);
    }
    scrollTimersRef.current = [0, 90, 200, 320].map((delay) =>
      setTimeout(() => {
        scrollToLatest(animated);
      }, delay)
    );
  };

  const submitPrompt = async (prompt: string) => {
    const trimmedPrompt = prompt.trim();
    if (!trimmedPrompt) {
      return;
    }
    setQuestion("");
    setOptimisticUserMessage({
      id: `optimistic-user-${Date.now()}`,
      role: "user",
      content: trimmedPrompt,
      createdAt: new Date().toISOString(),
    });
    setIsThinking(true);
    scheduleScrollToLatest(false);
    try {
      await onSubmitPrompt(trimmedPrompt);
    } finally {
      setOptimisticUserMessage(null);
      setIsThinking(false);
      scheduleScrollToLatest(false);
    }
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      scrollToLatest(true);
    }, 40);
    return () => clearTimeout(timer);
  }, [messages, optimisticUserMessage, isThinking]);

  useEffect(() => {
    const handleKeyboardShift = (event?: { endCoordinates?: { height?: number } }) => {
      const nextKeyboardHeight = event?.endCoordinates?.height ?? 0;
      setKeyboardHeight(nextKeyboardHeight);
      scheduleScrollToLatest(false);
    };
    const handleKeyboardHide = () => {
      setKeyboardHeight(0);
      scheduleScrollToLatest(false);
    };
    const showEvent = Platform.OS === "ios" ? "keyboardWillShow" : "keyboardDidShow";
    const frameEvent = Platform.OS === "ios" ? "keyboardWillChangeFrame" : "keyboardDidShow";
    const hideEvent = Platform.OS === "ios" ? "keyboardWillHide" : "keyboardDidHide";
    const showSubscription = Keyboard.addListener(showEvent, handleKeyboardShift);
    const frameSubscription = Keyboard.addListener(frameEvent, handleKeyboardShift);
    const hideSubscription = Keyboard.addListener(hideEvent, handleKeyboardHide);
    return () => {
      showSubscription.remove();
      frameSubscription.remove();
      hideSubscription.remove();
    };
  }, []);

  useEffect(
    () => () => {
      for (const timer of scrollTimersRef.current) {
        clearTimeout(timer);
      }
    },
    []
  );

  const composerBottomOffset = keyboardHeight > 0 ? Math.max(0, keyboardHeight - 6) : 0;

  return (
    <View style={styles.revoWrap}>
      <ScrollView
        ref={chatScrollRef}
        style={styles.revoScroll}
        contentContainerStyle={[styles.revoScrollContent, { paddingBottom: composerHeight + composerBottomOffset + spacing.xs }]}
        keyboardShouldPersistTaps="handled"
        keyboardDismissMode={Platform.OS === "ios" ? "interactive" : "on-drag"}
        onContentSizeChange={() => {
          if (isComposerFocused || isThinking) {
            scheduleScrollToLatest(false);
          }
        }}
      >
        <View style={styles.revoHeader}>
          <Text style={styles.revoHeading}>Ask REVO</Text>
          <Text style={styles.revoSubheading}>Your personal credit card expert.</Text>
        </View>

        <View style={styles.promptChipWrap}>
          {quickPrompts.map((prompt) => (
            <Pressable key={prompt} style={styles.promptChip} onPress={() => void submitPrompt(prompt)}>
              <Text style={styles.promptChipText}>{prompt}</Text>
            </Pressable>
          ))}
        </View>

        <View style={styles.revoConversation}>
          {visibleMessages.length ? (
            visibleMessages.map((message, index) => (
              <View
                key={`${message.id}-${index}`}
                style={[
                  styles.revoMessageBlock,
                  message.role === "user" ? styles.revoMessageBlockUser : styles.revoMessageBlockAssistant,
                ]}
              >
                <Text style={[styles.revoMessageRole, message.role === "user" ? styles.revoMessageRoleUser : undefined]}>
                  {message.role === "user" ? "You" : "REVO"}
                </Text>
                <Text style={[styles.revoMessageText, message.role === "user" ? styles.revoMessageTextUser : styles.revoMessageTextAssistant]}>
                  {message.content}
                </Text>
              </View>
            ))
          ) : (
            <View style={styles.emptyStateCard}>
              <Text style={styles.emptyStateTitle}>Start a conversation</Text>
              <Text style={styles.emptyStateText}>Ask REVO your next move and get practical card strategy guidance.</Text>
            </View>
          )}
          {isThinking ? (
            <View style={styles.revoThinkingRow}>
              <ActivityIndicator color="#C8D7FF" size="small" />
              <Text style={styles.revoThinkingText}>REVO is thinking...</Text>
            </View>
          ) : null}
        </View>
      </ScrollView>
      <View
        style={[styles.revoComposerDock, { bottom: composerBottomOffset }]}
        onLayout={(event) => {
          const nextHeight = Math.ceil(event.nativeEvent.layout.height);
          if (nextHeight > 0 && nextHeight !== composerHeight) {
            setComposerHeight(nextHeight);
          }
        }}
      >
        <View style={styles.revoComposerRow}>
          <TextInput
            value={question}
            onChangeText={(text) => {
              setQuestion(text);
              if (isComposerFocused) {
                scheduleScrollToLatest(false);
              }
            }}
            placeholder="Ask REVO anything..."
            placeholderTextColor="#6d7aab"
            style={styles.revoComposerInput}
            multiline
            textAlignVertical="top"
            maxLength={1000}
            onFocus={() => {
              setIsComposerFocused(true);
              scheduleScrollToLatest(false);
            }}
            onBlur={() => setIsComposerFocused(false)}
          />
          <Pressable
            style={[styles.revoSendButton, isThinking || !question.trim() ? styles.disabledCard : undefined]}
            onPress={() => void submitPrompt(question)}
            disabled={isThinking || !question.trim()}
          >
            {isThinking ? (
              <ActivityIndicator color="#F2F6FF" size="small" />
            ) : (
              <Ionicons name="arrow-up" size={20} color="#F2F6FF" />
            )}
          </Pressable>
        </View>
      </View>
    </View>
  );
}

function StrategyBuildScreen({ completedCount }: { completedCount: number }) {
  const safeCompletedCount = Math.min(Math.max(completedCount, 0), STRATEGY_BUILD_STEPS.length);

  return (
    <View style={styles.strategyBuildWrap}>
      <Text style={styles.strategyBuildHeading}>Building your strategy...</Text>
      <Text style={styles.strategyBuildSubheading}>This will only take a few seconds.</Text>

      <View style={styles.strategyBuildOrbWrap}>
        <LinearGradient colors={["#4F7DFF", "#8B5CF6"]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.strategyBuildOrb}>
          <Text style={styles.strategyBuildOrbLetter}>R</Text>
        </LinearGradient>
      </View>

      <View style={styles.strategyBuildList}>
        {STRATEGY_BUILD_STEPS.map((step, index) => {
          const isComplete = index < safeCompletedCount;
          const isActive = index === safeCompletedCount && safeCompletedCount < STRATEGY_BUILD_STEPS.length;
          return (
            <View key={step} style={styles.strategyBuildStepRow}>
              <Ionicons
                name={isComplete ? "checkmark-circle" : isActive ? "ellipse" : "ellipse-outline"}
                size={16}
                color={isComplete || isActive ? "#79A1FF" : "#4A5E8E"}
              />
              <Text style={[styles.strategyBuildStepText, isComplete ? styles.strategyBuildStepTextComplete : undefined]}>{step}</Text>
            </View>
          );
        })}
      </View>
    </View>
  );
}

function QuestionnaireScreen({
  initialRedemptionType,
  initialTravelScope,
  onSaveAnswers,
  onClose,
}: {
  initialRedemptionType?: RedemptionType;
  initialTravelScope?: TravelScope;
  onSaveAnswers: (answers: { redemptionType: RedemptionType; travelScope: TravelScope }) => Promise<void>;
  onClose: () => void;
}) {
  const [redemptionType, setRedemptionType] = useState<RedemptionType>(initialRedemptionType ?? "hybrid");
  const [travelScope, setTravelScope] = useState<TravelScope>(initialTravelScope ?? "both");
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  const redemptionOptions: Array<{ value: RedemptionType; label: string; detail: string }> = [
    { value: "points", label: "Points", detail: "Maximize transferable points and partner redemptions." },
    { value: "cash_back", label: "Cash back", detail: "Prioritize simple statement-value rewards." },
    { value: "hybrid", label: "Hybrid", detail: "Balance points value and cash-back flexibility." },
  ];

  const travelScopeOptions: Array<{ value: TravelScope; label: string; detail: string }> = [
    { value: "domestic", label: "Domestic", detail: "Mostly U.S. or local travel and benefits." },
    { value: "international", label: "International", detail: "Focus on international routing and perks." },
    { value: "both", label: "Both", detail: "Mix of domestic and international usage." },
    { value: "none", label: "No travel focus", detail: "Everyday value over travel-specific perks." },
  ];

  const saveAnswers = async () => {
    setSaving(true);
    setSaveError(null);
    try {
      await onSaveAnswers({ redemptionType, travelScope });
      onClose();
    } catch (error) {
      const message = error instanceof Error ? error.message : "Could not save your answers. Please try again.";
      setSaveError(message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <ScrollView contentContainerStyle={styles.screenBody}>
      <Text style={styles.cardSectionLabel}>QUESTIONNAIRE</Text>
      <Text style={styles.screenSectionTitle}>Tell REVO your preferences</Text>
      <Text style={styles.panelHint}>Your answers tune recommendations across Strategy, Home, and chat responses.</Text>

      <View style={styles.panelSection}>
        <Text style={styles.questionnaireQuestionTitle}>1) What kind of rewards do you care about most?</Text>
        <View style={styles.questionnaireOptionsWrap}>
          {redemptionOptions.map((option) => (
            <Pressable
              key={`redemption-${option.value}`}
              style={[styles.questionnaireOptionCard, redemptionType === option.value ? styles.questionnaireOptionCardSelected : undefined]}
              onPress={() => setRedemptionType(option.value)}
            >
              <Text style={[styles.questionnaireOptionTitle, redemptionType === option.value ? styles.questionnaireOptionTitleSelected : undefined]}>
                {option.label}
              </Text>
              <Text style={styles.questionnaireOptionDetail}>{option.detail}</Text>
            </Pressable>
          ))}
        </View>
      </View>

      <View style={styles.panelSection}>
        <Text style={styles.questionnaireQuestionTitle}>2) What travel scope should REVO optimize for?</Text>
        <View style={styles.questionnaireOptionsWrap}>
          {travelScopeOptions.map((option) => (
            <Pressable
              key={`travel-${option.value}`}
              style={[styles.questionnaireOptionCard, travelScope === option.value ? styles.questionnaireOptionCardSelected : undefined]}
              onPress={() => setTravelScope(option.value)}
            >
              <Text style={[styles.questionnaireOptionTitle, travelScope === option.value ? styles.questionnaireOptionTitleSelected : undefined]}>
                {option.label}
              </Text>
              <Text style={styles.questionnaireOptionDetail}>{option.detail}</Text>
            </Pressable>
          ))}
        </View>
      </View>

      {saveError ? <Text style={styles.questionnaireErrorText}>{saveError}</Text> : null}

      <View style={styles.questionnaireActionsRow}>
        <Pressable style={styles.questionnaireSecondaryButton} onPress={onClose} disabled={saving}>
          <Text style={styles.questionnaireSecondaryButtonText}>Cancel</Text>
        </Pressable>
        <Pressable style={[styles.questionnairePrimaryButton, saving ? styles.disabledCard : undefined]} onPress={() => void saveAnswers()} disabled={saving}>
          <Text style={styles.questionnairePrimaryButtonText}>{saving ? "Saving..." : "Save answers"}</Text>
        </Pressable>
      </View>
    </ScrollView>
  );
}

type OnboardingAgeGroup = "18-21" | "21-25" | "25-30" | "30+";
type OnboardingCardCount = "debit" | "0" | "1-2" | "2-4" | "5+";
type OnboardingFeeTolerance = "0" | "low" | "mid" | "high";
type OnboardingFlightScope = "domestic" | "international";
type OnboardingCreditScore = "under-580" | "580-650" | "650-720" | "720+";
type OnboardingPointsGoal = "travel" | "cash_back";
type OnboardingSpendCategory = "rent" | "food" | "travel" | "misc";

type OnboardingAnswers = {
  ageGroup: OnboardingAgeGroup | null;
  cardCount: OnboardingCardCount | null;
  ownedCardIds: string[];
  feeTolerance: OnboardingFeeTolerance | null;
  flightScope: OnboardingFlightScope | null;
  creditScore: OnboardingCreditScore | null;
  spendByCategory: Record<OnboardingSpendCategory, string>;
  pointsGoal: OnboardingPointsGoal | null;
};

type IoniconName = ComponentProps<typeof Ionicons>["name"];

const GRADIENT_PRIMARY = ["#5B7CFA", "#8B5CF6"] as const;
const STRATEGY_BUILD_STEPS = [
  "Analyzing your goals",
  "Reviewing your spending",
  "Comparing 200+ cards",
  "Finding the best combinations",
  "Calculating your potential value",
  "Finalizing your strategy",
] as const;
const ENABLE_ONBOARDING_MODAL = false;

function GradientButton({
  label,
  onPress,
  disabled,
  trailingIcon,
}: {
  label: string;
  onPress: () => void;
  disabled?: boolean;
  trailingIcon?: IoniconName;
}) {
  return (
    <Pressable onPress={onPress} disabled={disabled} style={[styles.gradientButtonWrap, disabled ? styles.disabledCard : undefined]}>
      <LinearGradient colors={GRADIENT_PRIMARY} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={styles.gradientButton}>
        <Text style={styles.gradientButtonText}>{label}</Text>
        {trailingIcon ? <Ionicons name={trailingIcon} size={18} color="#FFFFFF" /> : null}
      </LinearGradient>
    </Pressable>
  );
}

function SegmentedProgress({ current, total }: { current: number; total: number }) {
  return (
    <View style={styles.segmentRow}>
      {Array.from({ length: total }).map((_, index) => {
        const filled = index < current;
        return filled ? (
          <LinearGradient
            key={`segment-${index}`}
            colors={GRADIENT_PRIMARY}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 0 }}
            style={styles.segment}
          />
        ) : (
          <View key={`segment-${index}`} style={[styles.segment, styles.segmentEmpty]} />
        );
      })}
    </View>
  );
}

function OptionCard({
  title,
  subtitle,
  icon,
  iconColor,
  selected,
  onPress,
}: {
  title: string;
  subtitle?: string;
  icon: IoniconName;
  iconColor: string;
  selected: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable onPress={onPress} style={[styles.optionCard, selected ? styles.optionCardSelected : undefined]}>
      <View style={[styles.optionIconBadge, { backgroundColor: iconColor }]}>
        <Ionicons name={icon} size={18} color="#FFFFFF" />
      </View>
      <View style={styles.optionCardText}>
        <Text style={styles.optionCardTitle}>{title}</Text>
        {subtitle ? <Text style={styles.optionCardSubtitle}>{subtitle}</Text> : null}
      </View>
      {selected ? (
        <Ionicons name="checkmark-circle" size={22} color={palette.accent} />
      ) : (
        <Ionicons name="chevron-forward" size={18} color={palette.textSecondary} />
      )}
    </Pressable>
  );
}

function OnboardingChoiceList<T extends string>({
  options,
  value,
  onSelect,
}: {
  options: Array<{ value: T; label: string; detail?: string; icon: IoniconName; color: string }>;
  value: T | null;
  onSelect: (value: T) => void;
}) {
  return (
    <View style={styles.optionList}>
      {options.map((option) => (
        <OptionCard
          key={`option-${option.value}`}
          title={option.label}
          subtitle={option.detail}
          icon={option.icon}
          iconColor={option.color}
          selected={value === option.value}
          onPress={() => onSelect(option.value)}
        />
      ))}
    </View>
  );
}

function OnboardingScreen({
  searchCatalog,
  onComplete,
  onSkip,
}: {
  searchCatalog: CardSearchEntry[];
  onComplete: (answers: OnboardingAnswers) => void;
  onSkip: () => void;
}) {
  const [ageGroup, setAgeGroup] = useState<OnboardingAgeGroup | null>(null);
  const [cardCount, setCardCount] = useState<OnboardingCardCount | null>(null);
  const [ownedCardIds, setOwnedCardIds] = useState<string[]>([]);
  const [feeTolerance, setFeeTolerance] = useState<OnboardingFeeTolerance | null>(null);
  const [flightScope, setFlightScope] = useState<OnboardingFlightScope | null>(null);
  const [creditScore, setCreditScore] = useState<OnboardingCreditScore | null>(null);
  const [spendByCategory, setSpendByCategory] = useState<Record<OnboardingSpendCategory, string>>({
    rent: "",
    food: "",
    travel: "",
    misc: "",
  });
  const [pointsGoal, setPointsGoal] = useState<OnboardingPointsGoal | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [stepIndex, setStepIndex] = useState(0);

  const normalizedSearch = searchTerm.trim().toLowerCase();
  const searchTokens = normalizedSearch.split(/\s+/).filter(Boolean);
  const searchResults = useMemo(() => {
    if (!searchTokens.length) {
      return [];
    }
    return searchCatalog
      .map((card) => {
        const searchableFields = [card.id.toLowerCase(), card.issuer.toLowerCase(), card.brand.toLowerCase(), card.name.toLowerCase()];
        let score = 0;
        for (const token of searchTokens) {
          const exactFieldMatch = searchableFields.some((field) => field === token);
          const startsWithMatch = searchableFields.some((field) => field.startsWith(token));
          const wordMatch = searchableFields.some((field) => field.split(/[\s-]+/).some((word) => word.startsWith(token)));
          if (exactFieldMatch) {
            score += 30;
          } else if (startsWithMatch || wordMatch) {
            score += 14;
          } else {
            return null;
          }
        }
        return { card, score };
      })
      .filter((entry): entry is { card: CardSearchEntry; score: number } => Boolean(entry))
      .sort((a, b) => (b.score === a.score ? a.card.name.localeCompare(b.card.name) : b.score - a.score))
      .slice(0, 8)
      .map((entry) => entry.card);
  }, [searchCatalog, searchTokens]);

  const selectedCards = useMemo(
    () => ownedCardIds.map((id) => searchCatalog.find((card) => card.id === id)).filter((card): card is CardSearchEntry => Boolean(card)),
    [ownedCardIds, searchCatalog]
  );

  const toggleOwnedCard = (cardId: string) => {
    setOwnedCardIds((existing) => (existing.includes(cardId) ? existing.filter((id) => id !== cardId) : [...existing, cardId]));
  };

  const setSpendAmount = (category: OnboardingSpendCategory, amount: string) => {
    const cleaned = amount.replace(/[^0-9]/g, "");
    setSpendByCategory((existing) => ({ ...existing, [category]: cleaned }));
  };

  const spendRanking = useMemo(() => {
    const categoryLabels: Record<OnboardingSpendCategory, string> = {
      rent: "Rent",
      food: "Food",
      travel: "Travel",
      misc: "Misc",
    };
    return (Object.keys(categoryLabels) as OnboardingSpendCategory[])
      .map((category) => ({ category, label: categoryLabels[category], amount: Number.parseInt(spendByCategory[category] || "0", 10) }))
      .filter((entry) => entry.amount > 0)
      .sort((a, b) => a.amount - b.amount);
  }, [spendByCategory]);

  const finishOnboarding = () => {
    onComplete({
      ageGroup,
      cardCount,
      ownedCardIds,
      feeTolerance,
      flightScope,
      creditScore,
      spendByCategory,
      pointsGoal,
    });
  };

  const spendCategories: Array<{ value: OnboardingSpendCategory; label: string }> = [
    { value: "rent", label: "Rent" },
    { value: "food", label: "Food" },
    { value: "travel", label: "Travel" },
    { value: "misc", label: "Misc" },
  ];

  const spendCategoryMeta: Record<OnboardingSpendCategory, { icon: IoniconName; color: string }> = {
    rent: { icon: "home", color: "#5B7CFA" },
    food: { icon: "restaurant", color: "#22C55E" },
    travel: { icon: "airplane", color: "#8B5CF6" },
    misc: { icon: "grid", color: "#F5B740" },
  };

  const steps: Array<{ title: string; hint?: string; render: () => ReactNode }> = [
    {
      title: "What's your age group?",
      hint: "This helps REVO tailor recommendations to your stage.",
      render: () => (
        <OnboardingChoiceList
          value={ageGroup}
          onSelect={setAgeGroup}
          options={[
            { value: "18-21", label: "18-21", detail: "Just getting started", icon: "sparkles", color: "#5B7CFA" },
            { value: "21-25", label: "21-25", detail: "Building credit early", icon: "trending-up", color: "#22C55E" },
            { value: "25-30", label: "25-30", detail: "Establishing yourself", icon: "briefcase", color: "#8B5CF6" },
            { value: "30+", label: "30+", detail: "Optimizing your rewards", icon: "star", color: "#F5B740" },
          ]}
        />
      ),
    },
    {
      title: "How many credit cards do you have?",
      hint: "We'll build the right strategy for where you are today.",
      render: () => (
        <OnboardingChoiceList
          value={cardCount}
          onSelect={setCardCount}
          options={[
            { value: "debit", label: "Debit card only", detail: "New to credit cards", icon: "card-outline", color: "#64748B" },
            { value: "0", label: "0 cards", detail: "Starting fresh", icon: "add-circle", color: "#5B7CFA" },
            { value: "1-2", label: "1-2 cards", detail: "A couple in your wallet", icon: "card", color: "#22C55E" },
            { value: "2-4", label: "2-4 cards", detail: "Growing your setup", icon: "albums", color: "#8B5CF6" },
            { value: "5+", label: "5+ cards", detail: "Power user", icon: "trophy", color: "#F5B740" },
          ]}
        />
      ),
    },
    {
      title: "Which credit cards do you have?",
      hint: "Search our database and tap to add the cards you already own.",
      render: () => (
        <>
          {selectedCards.length ? (
            <View style={styles.onboardingChipRow}>
              {selectedCards.map((card) => (
                <Pressable key={`chip-${card.id}`} style={styles.onboardingChip} onPress={() => toggleOwnedCard(card.id)}>
                  <Text style={styles.onboardingChipText}>{card.name}</Text>
                  <Ionicons name="close" size={14} color={palette.textSecondary} />
                </Pressable>
              ))}
            </View>
          ) : null}
          <View style={styles.onboardingSearchBar}>
            <Ionicons name="search" size={18} color={palette.textSecondary} />
            <TextInput
              value={searchTerm}
              onChangeText={setSearchTerm}
              placeholder="Search cards (e.g. Amex Gold, Venture X)"
              placeholderTextColor={palette.textSecondary}
              style={styles.onboardingSearchInput}
              autoCapitalize="none"
              autoCorrect={false}
            />
          </View>
          {normalizedSearch ? (
            searchResults.length ? (
              <View style={styles.optionList}>
                {searchResults.map((card) => (
                  <OptionCard
                    key={`result-${card.id}`}
                    title={card.name}
                    subtitle={`${card.issuer} · ${card.annualFee}`}
                    icon="card"
                    iconColor="#5B7CFA"
                    selected={ownedCardIds.includes(card.id)}
                    onPress={() => toggleOwnedCard(card.id)}
                  />
                ))}
              </View>
            ) : (
              <Text style={styles.panelHint}>No matches yet. Try a different keyword.</Text>
            )
          ) : null}
        </>
      ),
    },
    {
      title: "What's your annual fee tolerance?",
      hint: "How much are you comfortable paying per year?",
      render: () => (
        <OnboardingChoiceList
          value={feeTolerance}
          onSelect={setFeeTolerance}
          options={[
            { value: "0", label: "$0", detail: "No annual fees", icon: "wallet", color: "#22C55E" },
            { value: "low", label: "Low", detail: "Around $95 a year", icon: "pricetag", color: "#5B7CFA" },
            { value: "mid", label: "Mid", detail: "$95 - $250 a year", icon: "card", color: "#8B5CF6" },
            { value: "high", label: "High", detail: "$250+ for premium perks", icon: "diamond", color: "#F5B740" },
          ]}
        />
      ),
    },
    {
      title: "Do you fly more domestic or international?",
      hint: "REVO optimizes travel perks around how you fly.",
      render: () => (
        <OnboardingChoiceList
          value={flightScope}
          onSelect={setFlightScope}
          options={[
            { value: "domestic", label: "Domestic", detail: "Mostly within the U.S.", icon: "airplane", color: "#5B7CFA" },
            { value: "international", label: "International", detail: "Frequent global trips", icon: "earth", color: "#8B5CF6" },
          ]}
        />
      ),
    },
    {
      title: "What's your credit score?",
      hint: "This helps REVO recommend cards you can actually get.",
      render: () => (
        <OnboardingChoiceList
          value={creditScore}
          onSelect={setCreditScore}
          options={[
            { value: "under-580", label: "Under 580", detail: "Building or repairing", icon: "alert-circle", color: "#F26D6D" },
            { value: "580-650", label: "580-650", detail: "Fair credit", icon: "trending-up", color: "#FB923C" },
            { value: "650-720", label: "650-720", detail: "Good credit", icon: "checkmark-circle", color: "#5B7CFA" },
            { value: "720+", label: "720+", detail: "Excellent credit", icon: "shield-checkmark", color: "#22C55E" },
          ]}
        />
      ),
    },
    {
      title: "How much do you spend each month?",
      hint: "Enter rough amounts. REVO ranks them from least to most for you.",
      render: () => (
        <>
          <View style={styles.optionList}>
            {spendCategories.map((category) => {
              const meta = spendCategoryMeta[category.value];
              return (
                <View key={`spend-${category.value}`} style={styles.onboardingSpendRow}>
                  <View style={[styles.optionIconBadge, { backgroundColor: meta.color }]}>
                    <Ionicons name={meta.icon} size={18} color="#FFFFFF" />
                  </View>
                  <Text style={styles.onboardingSpendLabel}>{category.label}</Text>
                  <View style={styles.onboardingAmountField}>
                    <Text style={styles.onboardingAmountPrefix}>$</Text>
                    <TextInput
                      value={spendByCategory[category.value]}
                      onChangeText={(amount) => setSpendAmount(category.value, amount)}
                      placeholder="0"
                      placeholderTextColor={palette.textSecondary}
                      style={styles.onboardingAmountInput}
                      keyboardType="number-pad"
                    />
                  </View>
                </View>
              );
            })}
          </View>
          {spendRanking.length ? (
            <View style={styles.onboardingRankingWrap}>
              <Text style={styles.cardSectionLabel}>LEAST → MOST</Text>
              <Text style={styles.onboardingRankingText}>
                {spendRanking.map((entry) => `${entry.label} ($${entry.amount})`).join("  →  ")}
              </Text>
            </View>
          ) : null}
        </>
      ),
    },
    {
      title: "What's your goal with points?",
      hint: "This shapes how REVO values every card for you.",
      render: () => (
        <OnboardingChoiceList
          value={pointsGoal}
          onSelect={setPointsGoal}
          options={[
            { value: "travel", label: "Unlock free travel", detail: "Maximize points for flights & hotels", icon: "airplane", color: "#5B7CFA" },
            { value: "cash_back", label: "Cash back & credits", detail: "Cash back, statement credits & gift cards", icon: "cash", color: "#22C55E" },
          ]}
        />
      ),
    },
  ];

  const totalSteps = steps.length;
  const safeStepIndex = Math.min(stepIndex, totalSteps - 1);
  const currentStep = steps[safeStepIndex];
  const isFirstStep = safeStepIndex === 0;
  const isLastStep = safeStepIndex === totalSteps - 1;

  const goNext = () => {
    if (isLastStep) {
      finishOnboarding();
      return;
    }
    setStepIndex((index) => Math.min(totalSteps - 1, index + 1));
  };

  const goBack = () => {
    setStepIndex((index) => Math.max(0, index - 1));
  };

  return (
    <View style={styles.onboardingWizard}>
      <View style={styles.onboardingTopBar}>
        <Pressable
          style={[styles.onboardingBackButton, isFirstStep ? styles.onboardingBackButtonHidden : undefined]}
          onPress={goBack}
          disabled={isFirstStep}
        >
          <Ionicons name="arrow-back" size={22} color={palette.textPrimary} />
        </Pressable>
        <View style={styles.onboardingProgressWrap}>
          <SegmentedProgress current={safeStepIndex + 1} total={totalSteps} />
        </View>
        <Text style={styles.onboardingCountLabel}>
          {safeStepIndex + 1}/{totalSteps}
        </Text>
      </View>

      <ScrollView contentContainerStyle={styles.onboardingStepBody} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
        <Text style={styles.onboardingHeading}>{currentStep.title}</Text>
        {currentStep.hint ? <Text style={styles.onboardingSubheading}>{currentStep.hint}</Text> : null}
        <View style={styles.onboardingStepContent}>{currentStep.render()}</View>
      </ScrollView>

      <View style={styles.onboardingNavBar}>
        <GradientButton label={isLastStep ? "Finish setup" : "Next"} trailingIcon="chevron-forward" onPress={goNext} />
        <Pressable style={styles.onboardingSkipButton} onPress={onSkip}>
          <Text style={styles.onboardingSkipText}>Skip for now</Text>
        </Pressable>
      </View>
    </View>
  );
}

function ProfileScreen({
  profile,
  walletCount,
  analyticsSummary,
  analyticsLoading,
  onRefreshAnalytics,
  onOpenQuestionnaire,
  onSignOut,
}: {
  profile: Profile;
  walletCount: number;
  analyticsSummary: RevoAnalyticsSummary | null;
  analyticsLoading: boolean;
  onRefreshAnalytics: () => Promise<void>;
  onOpenQuestionnaire: () => void;
  onSignOut: () => Promise<void>;
}) {
  const successRate = analyticsSummary?.successRate ?? 0;
  const rateLimitedRate = analyticsSummary
    ? Math.min(100, Math.round((analyticsSummary.rateLimitedCount / Math.max(analyticsSummary.last24hRequests, 1)) * 100))
    : 0;
  const providerErrorRate = analyticsSummary
    ? Math.min(100, Math.round((analyticsSummary.providerErrorCount / Math.max(analyticsSummary.last24hRequests, 1)) * 100))
    : 0;
  const guardrailRate = analyticsSummary
    ? Math.min(100, Math.round((analyticsSummary.guardrailBlockedCount / Math.max(analyticsSummary.last24hRequests, 1)) * 100))
    : 0;

  const profileRows = [
    { key: "Name", value: profile.name },
    { key: "Credit Card Strategy", value: profile.creditCardStrategy },
    { key: "Goal", value: profile.goal },
    { key: "Setup", value: `${walletCount} active cards` },
    { key: "Top Spend Categories", value: profile.topSpendCategories },
    { key: "Next Application Target", value: profile.nextApplicationTarget },
    { key: "Rewards Preference", value: profile.redemptionType ? profile.redemptionType.replace("_", " ") : "Not set" },
    { key: "Travel Scope", value: profile.travelScope ? profile.travelScope.replace("_", " ") : "Not set" },
  ];

  return (
    <ScrollView contentContainerStyle={styles.screenBody}>
      <Text style={styles.cardSectionLabel}>PROFILE</Text>
      <Text style={styles.screenSectionTitle}>Javed Saliman</Text>
      <View style={styles.panelSection}>
        {profileRows.map((row) => (
          <View key={row.key} style={styles.profileRow}>
            <Text style={styles.profileKey}>{row.key}</Text>
            <Text style={styles.profileValue}>{row.value}</Text>
          </View>
        ))}
      </View>
      <Pressable style={styles.reportButton}>
        <Text style={styles.cardSectionLabel}>OPTIMIZATION REPORT</Text>
        <Text style={styles.reportTitle}>View your original report</Text>
        <Text style={styles.metricHint}>See where you are now compared to where you were</Text>
      </Pressable>
      <View style={styles.panelSection}>
        <View style={styles.analyticsHeaderRow}>
          <Text style={styles.cardSectionLabel}>REVO ANALYTICS (24H)</Text>
          <Pressable style={styles.analyticsRefreshButton} onPress={() => void onRefreshAnalytics()} disabled={analyticsLoading}>
            <Text style={styles.analyticsRefreshButtonText}>{analyticsLoading ? "Refreshing..." : "Refresh"}</Text>
          </Pressable>
        </View>
        {analyticsSummary ? (
          <>
            <View style={styles.analyticsSummaryRow}>
              <View style={styles.analyticsSummaryPill}>
                <Text style={styles.analyticsTileLabel}>Requests</Text>
                <Text style={styles.analyticsTileValue}>{analyticsSummary.last24hRequests}</Text>
              </View>
              <View style={styles.analyticsSummaryPill}>
                <Text style={styles.analyticsTileLabel}>Avg Latency</Text>
                <Text style={styles.analyticsTileValue}>{analyticsSummary.averageLatencyMs}ms</Text>
              </View>
            </View>
            <View style={styles.analyticsStatRow}>
              <Text style={styles.analyticsStatLabel}>Success rate</Text>
              <Text style={styles.analyticsStatValue}>{successRate}%</Text>
            </View>
            <View style={styles.analyticsProgressTrack}>
              <View style={[styles.analyticsProgressFill, { width: `${Math.max(successRate, 6)}%` }]} />
            </View>

            <View style={styles.analyticsStatRow}>
              <Text style={styles.analyticsStatLabel}>Rate limited</Text>
              <Text style={styles.analyticsStatValue}>{analyticsSummary.rateLimitedCount} ({rateLimitedRate}%)</Text>
            </View>
            <View style={styles.analyticsProgressTrack}>
              <View style={[styles.analyticsProgressFillMuted, { width: `${Math.max(rateLimitedRate, 4)}%` }]} />
            </View>

            <View style={styles.analyticsStatRow}>
              <Text style={styles.analyticsStatLabel}>Provider errors</Text>
              <Text style={styles.analyticsStatValue}>{analyticsSummary.providerErrorCount} ({providerErrorRate}%)</Text>
            </View>
            <View style={styles.analyticsProgressTrack}>
              <View style={[styles.analyticsProgressFillMuted, { width: `${Math.max(providerErrorRate, 4)}%` }]} />
            </View>

            <View style={styles.analyticsStatRow}>
              <Text style={styles.analyticsStatLabel}>Guardrail blocks</Text>
              <Text style={styles.analyticsStatValue}>{analyticsSummary.guardrailBlockedCount} ({guardrailRate}%)</Text>
            </View>
            <View style={styles.analyticsProgressTrack}>
              <View style={[styles.analyticsProgressFillMuted, { width: `${Math.max(guardrailRate, 4)}%` }]} />
            </View>
            <Text style={styles.analyticsFootnote}>Latest status: {analyticsSummary.latestStatus}</Text>
          </>
        ) : (
          <Text style={styles.panelHint}>No analytics events yet. Ask REVO to start collecting usage stats.</Text>
        )}
      </View>
      <View style={styles.panelSection}>
        <Text style={styles.cardSectionLabel}>LEGAL & SUPPORT</Text>
        <View style={styles.complianceCard}>
          <Text style={styles.complianceTitle}>Important disclaimer</Text>
          <Text style={styles.complianceText}>
            REVO provides educational insights only and is not financial, tax, or legal advice.
          </Text>
        </View>
        <View style={styles.complianceCard}>
          <Text style={styles.complianceTitle}>Support</Text>
          <Text style={styles.complianceText}>revocredapp@gmail.com</Text>
        </View>
      </View>
      <Pressable style={styles.questionnaireLaunchButton} onPress={onOpenQuestionnaire}>
        <Text style={styles.cardSectionLabel}>QUESTIONNAIRE</Text>
        <Text style={styles.questionnaireLaunchTitle}>Answer user questions</Text>
        <Text style={styles.metricHint}>Set rewards and travel preferences so REVO recommendations stay aligned.</Text>
      </Pressable>
      <Pressable style={styles.signOutButton} onPress={() => void onSignOut()}>
        <Text style={styles.resetButtonText}>Sign out</Text>
      </Pressable>
    </ScrollView>
  );
}

function BottomNav({ activeTab, onChange }: { activeTab: TabKey; onChange: (tab: TabKey) => void }) {
  const tabs: Array<{ key: TabKey; kind: "ion" | "mc" | "text"; icon: string }> = [
    { key: "Home", kind: "ion", icon: "home-outline" },
    { key: "Cards", kind: "ion", icon: "card-outline" },
    { key: "REVO", kind: "text", icon: "R" },
    { key: "Strategy", kind: "mc", icon: "chess-knight" },
    { key: "Profile", kind: "ion", icon: "person-circle-outline" },
  ];

  return (
    <View style={styles.bottomNavWrap}>
      <View style={styles.bottomTabsPill}>
        {tabs.map((tab) => (
          <Pressable key={tab.key} onPress={() => onChange(tab.key)} style={[styles.navButton, activeTab === tab.key ? styles.navButtonActive : undefined]}>
            <View style={styles.navIconStack}>
              {tab.kind === "ion" ? (
                <Ionicons
                  name={tab.icon as "home-outline" | "card-outline" | "person-circle-outline"}
                  size={20}
                  style={[styles.navIcon, activeTab === tab.key ? styles.navIconActive : undefined]}
                />
              ) : tab.kind === "mc" ? (
                <MaterialCommunityIcons name={tab.icon as "chess-knight"} size={20} style={[styles.navIcon, activeTab === tab.key ? styles.navIconActive : undefined]} />
              ) : (
                <Text style={[styles.navRevoIcon, activeTab === tab.key ? styles.navIconActive : undefined]}>{tab.icon}</Text>
              )}
              <Text style={[styles.navLabel, activeTab === tab.key ? styles.navIconActive : undefined]}>
                {tab.key === "REVO" ? "Ask REVO" : tab.key}
              </Text>
            </View>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

function AppContent() {
  const [activeTab, setActiveTab] = useState<TabKey>("Home");
  const [showQuestionnaire, setShowQuestionnaire] = useState(false);
  const [showOnboarding, setShowOnboarding] = useState(false);
  const [showStrategyBuild, setShowStrategyBuild] = useState(false);
  const [strategyBuildCompletedCount, setStrategyBuildCompletedCount] = useState(0);
  const [keyboardVisible, setKeyboardVisible] = useState(false);
  const onboardingShownForSession = useRef<string | null>(null);
  const screenEntrance = useRef(new Animated.Value(1)).current;
  const {
    data,
    loading,
    authError,
    session,
    signIn,
    signUp,
    signOut,
    submitPrompt,
    addCardToWallet,
    availableCardsToAdd,
    analyticsSummary,
    analyticsLoading,
    refreshAnalytics,
    saveQuestionnaireAnswers,
  } = useAppData();

  const handleAskRevo = (prompt: string) => {
    setActiveTab("REVO");
    void submitPrompt(prompt);
  };

  useEffect(() => {
    initializeObservability();
    trackEvent("app_loaded", {
      source: "mobile",
    });
  }, []);

  useEffect(() => {
    trackScreenView(activeTab);
    trackEvent("tab_viewed", {
      tab: activeTab,
    });
  }, [activeTab]);

  useEffect(() => {
    const showEvent = Platform.OS === "ios" ? "keyboardWillShow" : "keyboardDidShow";
    const hideEvent = Platform.OS === "ios" ? "keyboardWillHide" : "keyboardDidHide";
    const showSubscription = Keyboard.addListener(showEvent, () => setKeyboardVisible(true));
    const hideSubscription = Keyboard.addListener(hideEvent, () => setKeyboardVisible(false));
    return () => {
      showSubscription.remove();
      hideSubscription.remove();
    };
  }, []);

  useEffect(() => {
    if (!ENABLE_ONBOARDING_MODAL) {
      return;
    }
    if (!session) {
      onboardingShownForSession.current = null;
      return;
    }
    if (data && onboardingShownForSession.current !== session.user.id) {
      onboardingShownForSession.current = session.user.id;
      setShowOnboarding(true);
    }
  }, [session, data]);

  useEffect(() => {
    screenEntrance.setValue(0.94);
    Animated.timing(screenEntrance, {
      toValue: 1,
      duration: 220,
      useNativeDriver: true,
    }).start();
  }, [activeTab, screenEntrance]);

  useEffect(() => {
    if (!showStrategyBuild) {
      return;
    }

    if (strategyBuildCompletedCount >= STRATEGY_BUILD_STEPS.length) {
      const completeTimer = setTimeout(() => {
        setShowStrategyBuild(false);
      }, 480);
      return () => clearTimeout(completeTimer);
    }

    const tickTimer = setTimeout(() => {
      setStrategyBuildCompletedCount((current) => current + 1);
    }, 620);
    return () => clearTimeout(tickTimer);
  }, [showStrategyBuild, strategyBuildCompletedCount]);

  const screenTranslateY = screenEntrance.interpolate({
    inputRange: [0.94, 1],
    outputRange: [10, 0],
  });

  const renderedScreen = useMemo(() => {
    if (!data) {
      return (
        <View style={styles.loadingWrap}>
          <ActivityIndicator color="#dfe7ff" size="large" />
          <Text style={styles.loadingText}>Loading your setup...</Text>
        </View>
      );
    }

    switch (activeTab) {
      case "Home":
        return (
          <HomeScreen
            cards={data.walletCards}
            pointsValue={data.metrics.pointsValue}
            projectedValue={data.metrics.projectedYearlyValue}
            onAskRevo={handleAskRevo}
            onOpenRoadmap={() => setActiveTab("Strategy")}
          />
        );
      case "Cards":
        return (
          <CardsScreen
            cards={data.walletCards}
            availableCardsToAdd={availableCardsToAdd}
            onAddCard={(cardId) => void addCardToWallet(cardId)}
            onAskRevo={handleAskRevo}
          />
        );
      case "Strategy":
        return (
          <StrategyScreen
            timeline={data.strategyTimeline}
            recommendedCards={data.popularPicks}
            searchCatalog={data.cardSearchCatalog}
            onAskRevo={handleAskRevo}
          />
        );
      case "REVO":
        return <RevoScreen quickPrompts={data.quickPrompts} messages={data.chatMessages} onSubmitPrompt={submitPrompt} />;
      case "Profile":
        return (
          <ProfileScreen
            profile={data.profile}
            walletCount={data.walletCards.length}
            analyticsSummary={analyticsSummary}
            analyticsLoading={analyticsLoading}
            onRefreshAnalytics={refreshAnalytics}
            onOpenQuestionnaire={() => setShowQuestionnaire(true)}
            onSignOut={signOut}
          />
        );
      default:
        return (
          <HomeScreen
            cards={data.walletCards}
            pointsValue={data.metrics.pointsValue}
            projectedValue={data.metrics.projectedYearlyValue}
            onAskRevo={handleAskRevo}
            onOpenRoadmap={() => setActiveTab("Strategy")}
          />
        );
    }
  }, [
    activeTab,
    addCardToWallet,
    analyticsLoading,
    analyticsSummary,
    availableCardsToAdd,
    data,
    refreshAnalytics,
    saveQuestionnaireAnswers,
    signOut,
    submitPrompt,
  ]);

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="light" />
      <View style={styles.appBackground}>
        <View style={styles.glow} />
        <View style={styles.glowSecondary} />
        <View style={styles.screenContainer}>
          {loading ? (
            <View style={styles.loadingWrap}>
              <ActivityIndicator color={palette.textPrimary} size="large" />
              <Text style={styles.loadingText}>Loading your setup...</Text>
            </View>
          ) : session ? (
            <Animated.View style={[styles.screenTransitionLayer, { opacity: screenEntrance, transform: [{ translateY: screenTranslateY }] }]}>
              {renderedScreen}
            </Animated.View>
          ) : (
            <AuthScreen onSignIn={signIn} onSignUp={signUp} authError={authError} />
          )}
        </View>
        {loading || !session || (activeTab === "REVO" && keyboardVisible) ? null : <BottomNav activeTab={activeTab} onChange={setActiveTab} />}
        <Modal visible={showQuestionnaire} animationType="slide" onRequestClose={() => setShowQuestionnaire(false)}>
          <SafeAreaView style={styles.safeArea}>
            <View style={styles.appBackground}>
              <View style={styles.glow} />
              <View style={styles.glowSecondary} />
              <QuestionnaireScreen
                initialRedemptionType={data?.profile.redemptionType}
                initialTravelScope={data?.profile.travelScope}
                onSaveAnswers={saveQuestionnaireAnswers}
                onClose={() => setShowQuestionnaire(false)}
              />
            </View>
          </SafeAreaView>
        </Modal>
        <Modal
          visible={ENABLE_ONBOARDING_MODAL && showOnboarding && Boolean(session)}
          animationType="slide"
          onRequestClose={() => setShowOnboarding(false)}
        >
          <SafeAreaView style={styles.safeArea}>
            <View style={styles.appBackground}>
              <View style={styles.glow} />
              <View style={styles.glowSecondary} />
              <OnboardingScreen
                searchCatalog={data?.cardSearchCatalog ?? []}
                onComplete={() => {
                  setShowOnboarding(false);
                  setStrategyBuildCompletedCount(0);
                  setShowStrategyBuild(true);
                  setActiveTab("Home");
                }}
                onSkip={() => setShowOnboarding(false)}
              />
            </View>
          </SafeAreaView>
        </Modal>
        <Modal visible={showStrategyBuild && Boolean(session)} animationType="fade" transparent onRequestClose={() => setShowStrategyBuild(false)}>
          <View style={styles.strategyBuildModalBackdrop}>
            <SafeAreaView style={styles.strategyBuildModalSafeArea}>
              <View style={styles.appBackground}>
                <View style={styles.glow} />
                <View style={styles.glowSecondary} />
                <StrategyBuildScreen completedCount={strategyBuildCompletedCount} />
              </View>
            </SafeAreaView>
          </View>
        </Modal>
      </View>
    </SafeAreaView>
  );
}

type AppErrorBoundaryState = {
  errorMessage: string | null;
};

class AppErrorBoundary extends Component<{ children: ReactNode }, AppErrorBoundaryState> {
  constructor(props: { children: ReactNode }) {
    super(props);
    this.state = { errorMessage: null };
  }

  static getDerivedStateFromError(error: Error): AppErrorBoundaryState {
    return { errorMessage: error.message || "Unknown runtime error" };
  }

  componentDidCatch(error: Error) {
    // Keep this log for production diagnostics when JS crashes.
    console.error("RevoCred runtime crash:", error);
  }

  render() {
    if (this.state.errorMessage) {
      return (
        <SafeAreaView style={styles.safeArea}>
          <View style={styles.appBackground}>
            <View style={styles.crashFallbackWrap}>
              <Text style={styles.crashFallbackTitle}>We hit a startup error</Text>
              <Text style={styles.crashFallbackText}>
                {this.state.errorMessage}
              </Text>
              <Text style={styles.crashFallbackText}>
                Close and reopen the app. If it keeps happening, reinstall this TestFlight build.
              </Text>
            </View>
          </View>
        </SafeAreaView>
      );
    }

    return this.props.children;
  }
}

export default function App() {
  return (
    <AppErrorBoundary>
      <AppContent />
    </AppErrorBoundary>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: palette.background,
  },
  appBackground: {
    flex: 1,
    backgroundColor: palette.background,
  },
  glow: {
    position: "absolute",
    left: "10%",
    right: "10%",
    top: -24,
    height: 190,
    borderRadius: 96,
    backgroundColor: palette.accent,
    opacity: 0.12,
  },
  glowSecondary: {
    position: "absolute",
    width: 220,
    height: 220,
    borderRadius: 999,
    right: -52,
    bottom: 80,
    backgroundColor: "#8B5CF6",
    opacity: 0.1,
  },
  screenContainer: {
    flex: 1,
  },
  screenTransitionLayer: {
    flex: 1,
  },
  screenBody: {
    paddingHorizontal: spacing.sm,
    paddingTop: spacing.sm,
    paddingBottom: spacing.lg + spacing.sm,
    gap: spacing.sm,
  },
  screenHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  brandLogoImage: {
    overflow: "hidden",
  },
  avatarWrap: {
    width: 40,
    height: 40,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.surfaceRaised,
  },
  avatarText: {
    color: palette.textPrimary,
    fontWeight: "700",
    fontSize: typeScale.sm,
  },
  homeBellButton: {
    width: 40,
    height: 40,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: "#31456F",
    backgroundColor: "#121E3D",
    alignItems: "center",
    justifyContent: "center",
  },
  welcomeText: {
    color: palette.textPrimary,
    fontSize: typeScale.hero,
    lineHeight: 42,
    fontWeight: "700",
    marginBottom: spacing.xs,
  },
  strategyReadyHeading: {
    color: palette.textPrimary,
    fontSize: 32,
    lineHeight: 38,
    fontWeight: "800",
  },
  strategyValueCard: {
    borderRadius: 22,
    borderWidth: 1,
    borderColor: "#314B7E",
    backgroundColor: "#0F1D3E",
    padding: spacing.sm,
    gap: spacing.xs,
    shadowColor: "#3D5DC7",
    shadowOpacity: 0.28,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 10 },
    elevation: 8,
  },
  strategyValueAmount: {
    color: "#45D89A",
    fontSize: 44,
    lineHeight: 50,
    fontWeight: "800",
  },
  strategyStatsRow: {
    flexDirection: "row",
    gap: spacing.xs,
    marginTop: 2,
  },
  strategyStatTile: {
    flex: 1,
    borderRadius: radii.sm,
    borderWidth: 1,
    borderColor: "#2E436D",
    backgroundColor: "#12264B",
    paddingVertical: 8,
    paddingHorizontal: 10,
    gap: 3,
  },
  strategyStatLabel: {
    color: "#9BA8CC",
    fontSize: 11,
    fontWeight: "600",
  },
  strategyStatValue: {
    color: "#E9F1FF",
    fontSize: typeScale.base,
    fontWeight: "700",
  },
  optimizationCard: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: "#2E426A",
    backgroundColor: "#0E1A35",
    padding: spacing.sm,
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
  },
  optimizationRing: {
    width: 84,
    height: 84,
    borderRadius: 999,
    borderWidth: 6,
    borderColor: "#3ACF9E",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(13, 47, 48, 0.35)",
  },
  optimizationRingValue: {
    color: palette.textPrimary,
    fontSize: typeScale.lg,
    fontWeight: "800",
    lineHeight: 22,
  },
  optimizationRingTotal: {
    color: palette.textSecondary,
    fontSize: 11,
    fontWeight: "600",
  },
  optimizationMeta: {
    flex: 1,
    gap: 4,
  },
  optimizationTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "700",
  },
  priorityRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  priorityText: {
    color: "#D9E3FF",
    fontSize: typeScale.sm,
    lineHeight: 20,
    flex: 1,
  },
  homeHeroCard: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surfaceRaised,
    padding: spacing.sm,
    gap: spacing.sm,
  },
  heroMetricsRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
  },
  heroMetricBlock: {
    flex: 1,
    gap: 2,
  },
  heroMetricValue: {
    color: palette.textPrimary,
    fontSize: typeScale.xl,
    fontWeight: "700",
  },
  heroMetricLabel: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
  },
  heroMetricDivider: {
    width: 1,
    alignSelf: "stretch",
    backgroundColor: palette.border,
  },
  heroActionCard: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: "#5169BF",
    backgroundColor: "#1A2752",
    padding: spacing.sm,
    gap: spacing.xs,
    shadowColor: palette.accent,
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.22,
    shadowRadius: 18,
    elevation: 7,
  },
  heroActionTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.lg,
    fontWeight: "700",
  },
  metricHint: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    lineHeight: 20,
  },
  cardSectionLabel: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    letterSpacing: 2.4,
    fontWeight: "600",
    textTransform: "uppercase",
  },
  panelSection: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surface,
    padding: spacing.sm,
    gap: spacing.sm,
  },
  screenSectionTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.xl,
    fontWeight: "700",
    lineHeight: 34,
  },
  panelHint: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    lineHeight: 20,
  },
  walletCard: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: "#33456C",
    backgroundColor: "#162341",
    padding: 6,
    shadowColor: "#000000",
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.25,
    shadowRadius: 12,
    elevation: 6,
  },
  walletCardFlipFrame: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#304366",
    backgroundColor: "#101A33",
    position: "relative",
    overflow: "hidden",
  },
  walletCardFlipFrameCollapsed: {
    minHeight: 142,
  },
  walletCardFlipFrameExpanded: {
    minHeight: 250,
  },
  walletCardFace: {
    position: "absolute",
    top: spacing.xs,
    right: spacing.xs,
    bottom: spacing.xs,
    left: spacing.xs,
    backfaceVisibility: "hidden",
  },
  walletCardFaceBack: {
    justifyContent: "space-between",
  },
  walletCardTopRow: {
    flexDirection: "row",
    gap: 6,
    alignItems: "flex-start",
  },
  walletCardPreviewContainer: {
    flexShrink: 0,
  },
  walletCardPreviewContainerCollapsed: {
    width: 127,
    height: 78,
  },
  walletCardPreviewContainerExpanded: {
    width: 167,
    height: 105,
  },
  walletCardBody: {
    flex: 1,
    gap: spacing.xs,
  },
  walletCardHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    gap: spacing.xs,
  },
  walletCardName: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "700",
    flexShrink: 1,
  },
  badge: {
    paddingHorizontal: spacing.xs,
    paddingVertical: 4,
    borderRadius: radii.sm,
    backgroundColor: "#2A3B63",
  },
  badgeText: {
    color: palette.textPrimary,
    fontSize: 11,
    fontWeight: "600",
  },
  walletCardSubLabel: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    letterSpacing: 2,
    textTransform: "uppercase",
  },
  walletCardBestUse: {
    color: palette.textPrimary,
    fontSize: typeScale.xs,
    lineHeight: 16,
    fontWeight: "600",
  },
  walletFooterRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  tapHint: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
  },
  tapHintBack: {
    textAlign: "right",
  },
  multiplierBubble: {
    backgroundColor: "#183D3B",
    borderRadius: radii.sm,
    paddingHorizontal: spacing.xs,
    paddingVertical: 4,
  },
  multiplierText: {
    color: palette.success,
    fontSize: typeScale.sm,
    fontWeight: "700",
  },
  genericCardSurface: {
    width: "100%",
    height: "100%",
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "rgba(147, 167, 213, 0.35)",
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
    justifyContent: "space-between",
    overflow: "hidden",
  },
  cardArtBrand: {
    color: "#F4F7FF",
    fontSize: typeScale.xs,
    letterSpacing: 2,
    fontWeight: "700",
    zIndex: 1,
  },
  cardArtBrandOnLight: {
    color: "#24324F",
  },
  cardArtName: {
    color: "#FFFFFF",
    fontSize: typeScale.base,
    fontWeight: "700",
    zIndex: 1,
  },
  cardArtNameOnLight: {
    color: "#17243D",
  },
  cardPreview: {
    width: "100%",
    height: "100%",
  },
  cardFlipContainer: {
    width: 124,
    height: 78,
  },
  cardPreviewBrand: {
    color: "#F4F7FF",
    fontSize: typeScale.xs,
    letterSpacing: 1.8,
    fontWeight: "700",
  },
  cardPreviewName: {
    color: "#FFFFFF",
    fontSize: typeScale.base,
    fontWeight: "700",
  },
  walletCardBackBody: {
    flex: 1,
    gap: spacing.xs,
  },
  walletCardBackTop: {
    gap: 6,
  },
  walletCardBackBottom: {
    gap: 6,
    marginTop: "auto",
    paddingTop: 4,
  },
  expandedTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.lg,
    fontWeight: "700",
  },
  walletCardBackBenefits: {
    gap: 6,
  },
  benefitPill: {
    borderRadius: radii.sm,
    backgroundColor: "#202F52",
    paddingVertical: spacing.xs,
    paddingHorizontal: spacing.xs,
  },
  benefitText: {
    color: "#C9D4F2",
    fontSize: typeScale.xs,
  },
  walletCardMoreBenefits: {
    color: "#B3C4F3",
    fontSize: typeScale.xs,
    textDecorationLine: "underline",
  },
  walletCardMoreBenefitsButton: {
    alignSelf: "flex-start",
    borderRadius: radii.sm,
    paddingVertical: 2,
  },
  benefitsModalBackdrop: {
    flex: 1,
    backgroundColor: "rgba(6, 11, 23, 0.82)",
    justifyContent: "center",
    paddingHorizontal: spacing.sm,
  },
  benefitsModalSheet: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: "#334A79",
    backgroundColor: "#0F1B38",
    padding: spacing.sm,
    gap: spacing.xs,
  },
  benefitsModalTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.lg,
    fontWeight: "700",
  },
  benefitsModalList: {
    gap: 6,
  },
  benefitsModalCloseButton: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#4B66B8",
    backgroundColor: "#22366B",
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: spacing.xs,
    marginTop: spacing.xs,
  },
  benefitsModalCloseText: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "700",
  },
  askRevoButton: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#4B66B8",
    backgroundColor: "#22366B",
    padding: 10,
    gap: 2,
  },
  askRevoLabel: {
    color: "#A9BAE8",
    fontSize: typeScale.xs,
    letterSpacing: 1.8,
    fontWeight: "600",
  },
  askRevoText: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "600",
  },
  walletCountCard: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#3E56A0",
    backgroundColor: "#1A2A57",
    paddingHorizontal: spacing.xs,
    paddingVertical: 6,
  },
  walletCountValue: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "700",
    marginTop: 2,
  },
  addCardButton: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderStyle: "dashed",
    borderColor: palette.border,
    backgroundColor: palette.surface,
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: spacing.md,
    gap: 2,
  },
  addCardPlus: {
    color: palette.textSecondary,
    fontSize: typeScale.hero,
    fontWeight: "300",
  },
  addCardText: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
  },
  addCardHint: {
    color: "#7E91BF",
    fontSize: typeScale.xs,
    marginTop: 2,
  },
  addCardPickerPanel: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surface,
    padding: spacing.xs,
    gap: spacing.xs,
  },
  addCardOptionRow: {
    borderRadius: radii.sm,
    borderWidth: 1,
    borderColor: "#2E416D",
    backgroundColor: "#131F3D",
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: spacing.xs,
  },
  addCardOptionMeta: {
    flex: 1,
    gap: 2,
  },
  addCardOptionName: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "600",
  },
  addCardOptionHint: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
  },
  addCardOptionButton: {
    borderRadius: radii.sm,
    borderWidth: 1,
    borderColor: "#4865B6",
    backgroundColor: "#22376C",
    paddingHorizontal: spacing.xs,
    paddingVertical: 6,
    minWidth: 60,
    alignItems: "center",
  },
  addCardOptionButtonText: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "600",
  },
  searchBar: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surface,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.sm,
    minHeight: 64,
    justifyContent: "center",
  },
  searchPlaceholder: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
  },
  searchInput: {
    color: palette.textPrimary,
    fontSize: typeScale.lg,
    paddingVertical: 0,
  },
  searchResultsHint: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    marginBottom: spacing.xs,
  },
  searchPhotoGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.xs,
  },
  searchPhotoTile: {
    width: "48%",
    gap: 6,
  },
  searchPhotoCard: {
    height: 116,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#4A629D",
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
    justifyContent: "space-between",
    overflow: "hidden",
  },
  searchPhotoBrand: {
    color: "#F2F6FF",
    fontSize: typeScale.xs,
    letterSpacing: 1.5,
    fontWeight: "700",
  },
  searchPhotoName: {
    color: "#FFFFFF",
    fontSize: typeScale.base,
    fontWeight: "700",
  },
  searchPhotoTileTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "600",
  },
  searchPhotoTileHint: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
  },
  searchModalBackdrop: {
    flex: 1,
    backgroundColor: "rgba(4, 8, 18, 0.78)",
    justifyContent: "flex-end",
  },
  searchModalSheet: {
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    borderWidth: 1,
    borderColor: "#2D416E",
    backgroundColor: "#0A142E",
    maxHeight: "82%",
    paddingTop: spacing.xs,
  },
  searchModalHandle: {
    alignSelf: "center",
    width: 42,
    height: 4,
    borderRadius: 99,
    backgroundColor: "#4A5F95",
    marginBottom: spacing.xs,
  },
  searchModalHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: spacing.sm,
    marginBottom: spacing.xs,
  },
  searchModalTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.lg,
    fontWeight: "700",
  },
  searchModalCloseButton: {
    borderRadius: radii.sm,
    borderWidth: 1,
    borderColor: "#3E56A0",
    backgroundColor: "#182A55",
    paddingHorizontal: spacing.xs,
    paddingVertical: 6,
  },
  searchModalCloseButtonText: {
    color: palette.textPrimary,
    fontSize: typeScale.xs,
    fontWeight: "600",
  },
  searchModalBody: {
    paddingHorizontal: spacing.sm,
    paddingBottom: spacing.lg,
    gap: spacing.sm,
  },
  searchModalHeroCard: {
    height: 170,
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: "#4A629D",
    padding: spacing.sm,
    justifyContent: "space-between",
    overflow: "hidden",
  },
  searchModalHeroName: {
    color: "#FFFFFF",
    fontSize: typeScale.xl,
    fontWeight: "700",
  },
  searchModalInfoGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.xs,
  },
  searchModalInfoTile: {
    width: "48%",
    borderRadius: radii.sm,
    borderWidth: 1,
    borderColor: "#324A75",
    backgroundColor: "#131F3D",
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
    gap: 4,
  },
  searchModalInfoLabel: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    letterSpacing: 1.3,
  },
  searchModalInfoValue: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "700",
  },
  searchModalBestUse: {
    color: "#D8E2FF",
    fontSize: typeScale.base,
    lineHeight: 22,
  },
  searchModalSectionTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "700",
    letterSpacing: 1.2,
  },
  searchModalListItem: {
    color: "#CFDAF6",
    fontSize: typeScale.sm,
    lineHeight: 21,
  },
  searchResultCard: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#314A79",
    backgroundColor: "#111D38",
    padding: spacing.sm,
    gap: spacing.xs,
  },
  searchResultTopRow: {
    flexDirection: "row",
    alignItems: "flex-start",
    justifyContent: "space-between",
    gap: spacing.xs,
  },
  searchResultTitleWrap: {
    flex: 1,
    gap: 2,
  },
  searchResultCardName: {
    color: palette.textPrimary,
    fontSize: typeScale.lg,
    fontWeight: "700",
  },
  searchResultCardBrand: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
  },
  searchResultFeeBadge: {
    borderRadius: 999,
    borderWidth: 1,
    borderColor: "#48619D",
    backgroundColor: "#1E2E55",
    paddingHorizontal: spacing.xs,
    paddingVertical: 5,
  },
  searchResultFeeText: {
    color: "#DDE6FF",
    fontSize: typeScale.xs,
    fontWeight: "600",
  },
  searchResultMetaRow: {
    flexDirection: "row",
    gap: spacing.xs,
  },
  searchResultMetaPill: {
    flex: 1,
    borderRadius: radii.sm,
    borderWidth: 1,
    borderColor: "#324972",
    backgroundColor: "#162649",
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
    gap: 2,
  },
  searchResultMetaLabel: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    letterSpacing: 1.4,
  },
  searchResultMetaValue: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "700",
  },
  searchResultBestUse: {
    color: "#D8E2FF",
    fontSize: typeScale.sm,
  },
  searchResultBenefitsWrap: {
    gap: spacing.xs,
  },
  timelineWrap: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surface,
    padding: spacing.sm,
    gap: spacing.sm,
  },
  timelineStep: {
    alignItems: "center",
    gap: 4,
  },
  timelinePill: {
    borderRadius: radii.md,
    backgroundColor: "#243C75",
    minWidth: 220,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    alignItems: "center",
  },
  timelinePillStart: {
    backgroundColor: "#523455",
  },
  timelinePillText: {
    color: palette.textPrimary,
    fontSize: typeScale.lg,
    fontWeight: "700",
  },
  timelineMonth: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "600",
  },
  timelineNote: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    textAlign: "center",
    paddingHorizontal: spacing.xs,
  },
  timelineArrow: {
    color: palette.textSecondary,
    fontSize: typeScale.xl,
  },
  recommendationCard: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surfaceRaised,
    padding: spacing.xs,
    gap: spacing.xs,
  },
  recommendationTop: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.xs,
  },
  recommendationMeta: {
    flex: 1,
  },
  recommendationBrand: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    letterSpacing: 1.4,
    marginBottom: 2,
  },
  recommendationName: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "700",
    lineHeight: 20,
  },
  chevron: {
    color: palette.textSecondary,
    fontSize: typeScale.xl,
    paddingHorizontal: 4,
  },
  recommendationExpanded: {
    gap: spacing.xs,
  },
  roadmapSummaryCard: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: "#304879",
    backgroundColor: "#112041",
    padding: spacing.sm,
    gap: 6,
  },
  roadmapSummaryTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "700",
  },
  roadmapSummaryText: {
    color: "#C5D3F5",
    fontSize: typeScale.sm,
    lineHeight: 20,
  },
  roadmapTimeline: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: "#304778",
    backgroundColor: "#0C1836",
    padding: spacing.sm,
    gap: spacing.sm,
    shadowColor: "#274A9A",
    shadowOpacity: 0.2,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 10 },
    elevation: 6,
  },
  roadmapStepRow: {
    flexDirection: "row",
    alignItems: "stretch",
    gap: spacing.xs,
  },
  roadmapRailWrap: {
    width: 18,
    alignItems: "center",
  },
  roadmapDot: {
    width: 10,
    height: 10,
    borderRadius: 999,
    marginTop: 6,
  },
  roadmapRail: {
    width: 2,
    flex: 1,
    marginTop: 6,
    backgroundColor: "#2D406A",
  },
  roadmapStepCard: {
    flex: 1,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#365189",
    backgroundColor: "#132651",
    padding: spacing.xs,
    gap: 8,
  },
  roadmapStageLabel: {
    fontSize: typeScale.sm,
    fontWeight: "700",
  },
  roadmapHeaderRow: {
    flexDirection: "row",
    gap: spacing.xs,
    alignItems: "center",
  },
  roadmapPreviewCard: {
    width: 108,
    height: 68,
    borderRadius: radii.sm,
    borderWidth: 1,
    borderColor: "#5A76B5",
    paddingHorizontal: 8,
    paddingVertical: 8,
  },
  roadmapHeaderMeta: {
    flex: 1,
    gap: 4,
  },
  roadmapCardTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "700",
  },
  roadmapCardSubtitle: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    lineHeight: 16,
  },
  roadmapBenefits: {
    gap: 4,
  },
  roadmapBenefitRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
  roadmapBenefitText: {
    color: "#D4DEFB",
    fontSize: typeScale.xs,
    lineHeight: 16,
    flex: 1,
  },
  roadmapValueRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  roadmapValueLabel: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    letterSpacing: 1.2,
    textTransform: "uppercase",
  },
  roadmapValueAmount: {
    color: "#68E0AE",
    fontSize: typeScale.base,
    fontWeight: "700",
  },
  roadmapFootnote: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    textAlign: "center",
    marginTop: 2,
  },
  revoWrap: {
    flex: 1,
  },
  revoScroll: {
    flex: 1,
  },
  revoScrollContent: {
    paddingHorizontal: spacing.sm,
    paddingTop: spacing.sm,
    paddingBottom: spacing.sm,
    gap: spacing.sm,
  },
  revoHeader: {
    gap: 4,
  },
  revoHeading: {
    color: palette.textPrimary,
    fontSize: typeScale.hero,
    fontWeight: "800",
  },
  revoSubheading: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    lineHeight: 20,
  },
  promptChipWrap: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.xs,
  },
  promptChip: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#3B4F82",
    backgroundColor: "#132146",
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
  },
  promptChipText: {
    color: "#D3DFFF",
    fontSize: typeScale.sm,
    lineHeight: 18,
  },
  revoConversation: {
    gap: spacing.sm,
    paddingTop: 4,
    paddingBottom: 12,
  },
  revoMessageBlock: {
    maxWidth: "94%",
    gap: 6,
  },
  revoMessageBlockUser: {
    alignSelf: "flex-end",
    alignItems: "flex-end",
  },
  revoMessageBlockAssistant: {
    alignSelf: "flex-start",
  },
  revoMessageRole: {
    color: "#9EB2E3",
    fontSize: typeScale.xs,
    fontWeight: "700",
    letterSpacing: 0.6,
    textTransform: "uppercase",
  },
  revoMessageRoleUser: {
    color: "#AEC2FF",
  },
  revoMessageText: {
    fontSize: typeScale.sm,
    lineHeight: 24,
  },
  revoMessageTextUser: {
    color: "#DCE6FF",
    textAlign: "right",
  },
  revoMessageTextAssistant: {
    color: "#EDF3FF",
  },
  revoThinkingRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingTop: 4,
  },
  revoThinkingText: {
    color: "#C7D6FB",
    fontSize: typeScale.xs,
    letterSpacing: 0.3,
  },
  emptyStateCard: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#293A63",
    backgroundColor: "#0F1831",
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.sm,
    gap: spacing.xs,
  },
  emptyStateTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "600",
  },
  emptyStateText: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    lineHeight: 20,
  },
  revoComposerDock: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    zIndex: 20,
    borderTopWidth: 1,
    borderColor: "#1C2A48",
    backgroundColor: "#060E1F",
    paddingHorizontal: spacing.sm,
    paddingTop: spacing.xs,
    paddingBottom: spacing.xs,
  },
  revoComposerRow: {
    flexDirection: "row",
    alignItems: "flex-end",
    gap: spacing.xs,
  },
  revoComposerInput: {
    flex: 1,
    minHeight: 52,
    maxHeight: 140,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: "#2C3E67",
    backgroundColor: "#0E1A35",
    color: palette.textPrimary,
    fontSize: typeScale.base,
    lineHeight: 22,
    paddingHorizontal: 16,
    paddingTop: 13,
    paddingBottom: 13,
  },
  revoSendButton: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: palette.accent,
    alignItems: "center",
    justifyContent: "center",
  },
  profileRow: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: "#111B35",
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
    flexDirection: "row",
    justifyContent: "space-between",
    gap: spacing.xs,
    alignItems: "center",
  },
  profileKey: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    letterSpacing: 1.6,
    textTransform: "uppercase",
    flex: 1,
  },
  profileValue: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "500",
    textAlign: "right",
    flex: 1,
  },
  reportButton: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: "#5067B3",
    backgroundColor: "#1D2F5F",
    padding: spacing.sm,
    gap: spacing.xs,
  },
  reportTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.xl,
    lineHeight: 32,
    fontWeight: "700",
  },
  questionnaireLaunchButton: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: "#4B66B8",
    backgroundColor: "#172957",
    padding: spacing.sm,
    gap: spacing.xs,
  },
  questionnaireLaunchTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.lg,
    fontWeight: "700",
  },
  questionnaireQuestionTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "700",
    lineHeight: 22,
  },
  questionnaireOptionsWrap: {
    gap: spacing.xs,
  },
  questionnaireOptionCard: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: "#101B36",
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
    gap: 4,
  },
  questionnaireOptionCardSelected: {
    borderColor: "#6F8BFF",
    backgroundColor: "#1A2D5B",
  },
  questionnaireOptionTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "700",
  },
  questionnaireOptionTitleSelected: {
    color: "#DDE6FF",
  },
  questionnaireOptionDetail: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    lineHeight: 18,
  },
  questionnaireErrorText: {
    color: "#FF8E8E",
    fontSize: typeScale.sm,
    fontWeight: "600",
  },
  questionnaireActionsRow: {
    flexDirection: "row",
    gap: spacing.xs,
    marginTop: spacing.xs,
  },
  questionnairePrimaryButton: {
    flex: 1,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#4B66B8",
    backgroundColor: "#223A72",
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: spacing.xs,
  },
  questionnairePrimaryButtonText: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "700",
  },
  questionnaireSecondaryButton: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surface,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
  },
  questionnaireSecondaryButtonText: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    fontWeight: "600",
  },
  onboardingPillRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.xs,
  },
  onboardingPill: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: "#101B36",
    paddingHorizontal: spacing.sm,
    paddingVertical: 10,
  },
  onboardingPillSelected: {
    borderColor: "#6F8BFF",
    backgroundColor: "#1A2D5B",
  },
  onboardingPillText: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "700",
  },
  onboardingPillTextSelected: {
    color: "#DDE6FF",
  },
  onboardingChipRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.xs,
  },
  onboardingChip: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#4B66B8",
    backgroundColor: "#1A2D5B",
    paddingHorizontal: spacing.xs,
    paddingVertical: 6,
  },
  onboardingChipText: {
    color: "#DDE6FF",
    fontSize: typeScale.xs,
    fontWeight: "700",
  },
  onboardingChipRemove: {
    color: palette.textSecondary,
    fontSize: typeScale.base,
    fontWeight: "700",
    lineHeight: 18,
  },
  onboardingResultsWrap: {
    gap: spacing.xs,
  },
  onboardingResultRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: "#101B36",
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
  },
  onboardingResultRowSelected: {
    borderColor: "#6F8BFF",
    backgroundColor: "#1A2D5B",
  },
  onboardingResultMeta: {
    flex: 1,
    gap: 2,
  },
  onboardingResultName: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "700",
  },
  onboardingResultIssuer: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
  },
  onboardingResultCheck: {
    color: palette.textSecondary,
    fontSize: typeScale.lg,
    fontWeight: "700",
    marginLeft: spacing.xs,
  },
  onboardingResultCheckSelected: {
    color: palette.success,
  },
  onboardingSpendRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.xs,
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surfaceRaised,
    paddingVertical: 10,
    paddingHorizontal: spacing.xs,
  },
  onboardingSpendLabel: {
    flex: 1,
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "700",
  },
  onboardingAmountField: {
    flexDirection: "row",
    alignItems: "center",
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: "#101B36",
    paddingHorizontal: spacing.xs,
    minWidth: 120,
  },
  onboardingAmountPrefix: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    fontWeight: "700",
  },
  onboardingAmountInput: {
    flex: 1,
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "600",
    paddingVertical: 10,
    paddingHorizontal: 6,
  },
  onboardingRankingWrap: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: "#0F1A34",
    padding: spacing.xs,
    gap: 4,
    marginTop: 4,
  },
  onboardingRankingText: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "600",
  },
  onboardingWizard: {
    flex: 1,
  },
  onboardingTopBar: {
    paddingHorizontal: spacing.sm,
    paddingTop: spacing.sm,
    paddingBottom: spacing.xs,
    gap: spacing.xs,
  },
  onboardingTopBarRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  onboardingProgressLabel: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    fontWeight: "700",
    letterSpacing: 0.5,
  },
  onboardingProgressTrack: {
    flexDirection: "row",
    height: 8,
    borderRadius: 999,
    backgroundColor: "#101B36",
    borderWidth: 1,
    borderColor: palette.border,
    overflow: "hidden",
  },
  onboardingProgressFill: {
    backgroundColor: palette.accent,
    borderRadius: 999,
  },
  onboardingStepBody: {
    paddingHorizontal: spacing.sm,
    paddingTop: spacing.xs,
    paddingBottom: spacing.md,
    gap: spacing.sm,
  },
  onboardingNavBar: {
    gap: spacing.xs,
    paddingHorizontal: spacing.sm,
    paddingTop: spacing.sm,
    paddingBottom: spacing.sm,
    backgroundColor: palette.background,
  },
  gradientButtonWrap: {
    borderRadius: radii.lg,
    overflow: "hidden",
    shadowColor: "#5B7CFA",
    shadowOpacity: 0.35,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
  },
  gradientButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    paddingVertical: 16,
    borderRadius: radii.lg,
  },
  gradientButtonText: {
    color: "#FFFFFF",
    fontSize: typeScale.base,
    fontWeight: "700",
  },
  onboardingBackButton: {
    width: 40,
    height: 40,
    borderRadius: 999,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.surfaceRaised,
    borderWidth: 1,
    borderColor: palette.border,
  },
  onboardingBackButtonHidden: {
    opacity: 0,
  },
  onboardingProgressWrap: {
    flex: 1,
    marginHorizontal: spacing.sm,
  },
  onboardingCountLabel: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    fontWeight: "700",
    minWidth: 34,
    textAlign: "right",
  },
  segmentRow: {
    flexDirection: "row",
    gap: 6,
    alignItems: "center",
  },
  segment: {
    flex: 1,
    height: 6,
    borderRadius: 999,
  },
  segmentEmpty: {
    backgroundColor: "#1C2846",
  },
  onboardingHeading: {
    color: palette.textPrimary,
    fontSize: typeScale.xl,
    fontWeight: "800",
    lineHeight: 34,
  },
  onboardingSubheading: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    lineHeight: 20,
    marginTop: 4,
  },
  onboardingStepContent: {
    marginTop: spacing.sm,
    gap: spacing.sm,
  },
  onboardingSkipButton: {
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: spacing.xs,
  },
  onboardingSkipText: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    fontWeight: "600",
  },
  optionList: {
    gap: spacing.xs,
  },
  optionCard: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.xs,
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surfaceRaised,
    paddingVertical: 14,
    paddingHorizontal: spacing.xs,
  },
  optionCardSelected: {
    borderColor: palette.accent,
    backgroundColor: "#1A2952",
  },
  optionIconBadge: {
    width: 40,
    height: 40,
    borderRadius: 999,
    alignItems: "center",
    justifyContent: "center",
  },
  optionCardText: {
    flex: 1,
    gap: 2,
  },
  optionCardTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "700",
  },
  optionCardSubtitle: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    lineHeight: 16,
  },
  onboardingSearchBar: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.xs,
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surfaceRaised,
    paddingHorizontal: spacing.sm,
    paddingVertical: 12,
  },
  onboardingSearchInput: {
    flex: 1,
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "500",
    padding: 0,
  },
  strategyBuildModalBackdrop: {
    flex: 1,
    backgroundColor: "rgba(4, 8, 20, 0.78)",
  },
  strategyBuildModalSafeArea: {
    flex: 1,
  },
  strategyBuildWrap: {
    flex: 1,
    paddingHorizontal: spacing.md,
    paddingTop: spacing.lg,
    paddingBottom: spacing.lg,
    alignItems: "center",
    gap: spacing.sm,
  },
  strategyBuildHeading: {
    color: palette.textPrimary,
    fontSize: 32,
    lineHeight: 38,
    fontWeight: "800",
    textAlign: "center",
  },
  strategyBuildSubheading: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    lineHeight: 20,
    textAlign: "center",
  },
  strategyBuildOrbWrap: {
    width: 214,
    height: 214,
    borderRadius: 999,
    borderWidth: 2,
    borderColor: "#2E4475",
    alignItems: "center",
    justifyContent: "center",
    marginVertical: spacing.xs,
    shadowColor: "#456EF8",
    shadowOpacity: 0.35,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 12 },
    elevation: 10,
  },
  strategyBuildOrb: {
    width: 138,
    height: 138,
    borderRadius: 999,
    alignItems: "center",
    justifyContent: "center",
  },
  strategyBuildOrbLetter: {
    color: "#EEF3FF",
    fontSize: 54,
    fontWeight: "800",
    lineHeight: 60,
  },
  strategyBuildList: {
    width: "100%",
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: "#304878",
    backgroundColor: "#0E1938",
    padding: spacing.sm,
    gap: spacing.xs,
  },
  strategyBuildStepRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  strategyBuildStepText: {
    color: "#8FA3D5",
    fontSize: typeScale.sm,
    lineHeight: 20,
  },
  strategyBuildStepTextComplete: {
    color: "#D9E4FF",
    fontWeight: "600",
  },
  analyticsHeaderRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  analyticsRefreshButton: {
    borderRadius: radii.sm,
    borderWidth: 1,
    borderColor: "#3D5396",
    backgroundColor: "#15264E",
    paddingHorizontal: spacing.xs,
    paddingVertical: 6,
  },
  analyticsRefreshButtonText: {
    color: "#DCE5FF",
    fontSize: typeScale.xs,
    fontWeight: "600",
  },
  analyticsSummaryRow: {
    flexDirection: "row",
    gap: spacing.xs,
  },
  analyticsSummaryPill: {
    flex: 1,
    borderRadius: radii.sm,
    backgroundColor: "#162746",
    borderWidth: 1,
    borderColor: "#2F466F",
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
    gap: 2,
  },
  analyticsTileLabel: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
  },
  analyticsTileValue: {
    color: palette.textPrimary,
    fontSize: typeScale.base,
    fontWeight: "700",
  },
  analyticsStatRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginTop: spacing.xs,
  },
  analyticsStatLabel: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
  },
  analyticsStatValue: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "600",
  },
  analyticsProgressTrack: {
    height: 8,
    borderRadius: 999,
    backgroundColor: "#1A2644",
    overflow: "hidden",
  },
  analyticsProgressFill: {
    height: "100%",
    borderRadius: 999,
    backgroundColor: palette.success,
  },
  analyticsProgressFillMuted: {
    height: "100%",
    borderRadius: 999,
    backgroundColor: palette.warning,
  },
  analyticsFootnote: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    marginTop: spacing.xs,
  },
  complianceCard: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: "#111B35",
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
    gap: 4,
  },
  complianceTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "700",
  },
  complianceText: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    lineHeight: 20,
  },
  resetButton: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surface,
    paddingVertical: spacing.xs,
    alignItems: "center",
  },
  signOutButton: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#4661AA",
    backgroundColor: "#223A72",
    paddingVertical: spacing.xs,
    alignItems: "center",
  },
  resetButtonText: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "600",
  },
  bottomNavWrap: {
    paddingHorizontal: spacing.sm,
    paddingBottom: spacing.sm,
    paddingTop: spacing.xs,
    backgroundColor: "transparent",
  },
  bottomTabsPill: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: "#324878",
    backgroundColor: "rgba(10, 17, 36, 0.95)",
    paddingHorizontal: spacing.xs,
    paddingVertical: 6,
    flexDirection: "row",
    alignItems: "stretch",
    justifyContent: "space-between",
    gap: 6,
  },
  navButton: {
    flex: 1,
    borderRadius: radii.md,
    paddingVertical: spacing.sm,
    paddingHorizontal: 6,
    alignItems: "center",
    justifyContent: "center",
  },
  navIconStack: {
    alignItems: "center",
    justifyContent: "center",
    gap: 2,
  },
  navButtonActive: {
    backgroundColor: "rgba(111, 139, 255, 0.2)",
  },
  navIcon: {
    color: palette.textSecondary,
    fontWeight: "700",
  },
  navRevoIcon: {
    color: palette.textSecondary,
    fontSize: typeScale.lg,
    fontWeight: "700",
    marginTop: -1,
  },
  navLabel: {
    color: palette.textSecondary,
    fontSize: 11,
    fontWeight: "600",
  },
  navIconActive: {
    color: palette.accent,
  },
  loadingWrap: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    gap: spacing.xs,
  },
  loadingText: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
  },
  crashFallbackWrap: {
    flex: 1,
    justifyContent: "center",
    paddingHorizontal: spacing.md,
    gap: spacing.sm,
  },
  crashFallbackTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.xl,
    fontWeight: "800",
  },
  crashFallbackText: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    lineHeight: 20,
  },
  disabledCard: {
    opacity: 0.55,
  },
  authWrap: {
    flex: 1,
    paddingHorizontal: spacing.md,
    justifyContent: "center",
    gap: spacing.sm,
  },
  authTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.xl,
    fontWeight: "700",
  },
  authSubtitle: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    lineHeight: 20,
  },
  authCard: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surfaceRaised,
    padding: spacing.sm,
    gap: spacing.xs,
  },
  authInput: {
    height: 48,
    borderRadius: radii.sm,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surface,
    color: palette.textPrimary,
    fontSize: typeScale.base,
    paddingHorizontal: spacing.xs,
  },
  authButton: {
    borderRadius: radii.sm,
    backgroundColor: palette.accent,
    alignItems: "center",
    paddingVertical: spacing.xs,
  },
  authButtonSecondary: {
    borderRadius: radii.sm,
    borderWidth: 1,
    borderColor: palette.accent,
    backgroundColor: "#16254B",
    alignItems: "center",
    paddingVertical: spacing.xs,
  },
  authButtonText: {
    color: palette.textPrimary,
    fontSize: typeScale.sm,
    fontWeight: "700",
  },
  authMessage: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
    lineHeight: 20,
  },
});
