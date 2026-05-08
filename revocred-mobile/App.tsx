import { StatusBar } from "expo-status-bar";
import { Ionicons, MaterialCommunityIcons } from "@expo/vector-icons";
import { useEffect, useMemo, useRef, useState } from "react";
import { ActivityIndicator, Animated, Modal, Pressable, SafeAreaView, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { useAppData } from "./src/hooks/useAppData";
import { initializeObservability, trackEvent, trackScreenView } from "./src/services/observability";
import { Card, CardSearchEntry, ChatMessage, Profile, Recommendation, RevoAnalyticsSummary, TabKey } from "./src/types/models";

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

function topCardColor(cardId: string): string {
  switch (cardId) {
    case "amex-gold":
      return "#B68B3A";
    case "venture-x":
      return "#2A355A";
    case "freedom-unlimited":
      return "#3554BF";
    case "freedom-flex":
      return "#7B44C9";
    default:
      break;
  }

  const fallbackPalette = ["#2B3656", "#28417A", "#3A3565", "#2E4D5B", "#5A3D57", "#24526A"];
  const hash = Array.from(cardId).reduce((sum, char) => sum + char.charCodeAt(0), 0);
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
  return (
    <View style={[styles.genericCardSurface, { backgroundColor: topCardColor(cardId) }, containerStyle]}>
      <Text style={[styles.cardArtBrand, brandStyle]}>{brand.toUpperCase()}</Text>
      <Text style={[styles.cardArtName, nameStyle]} numberOfLines={2}>
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
  const hiddenBenefitCount = Math.max(0, card.benefits.length - visibleBenefits.length);

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
              {hiddenBenefitCount ? <Text style={styles.walletCardMoreBenefits}>+{hiddenBenefitCount} more benefit(s)</Text> : null}
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
      <Text style={styles.brandLabel}>REVOCRED</Text>
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
}: {
  cards: Card[];
  pointsValue: number;
  projectedValue: number;
  onAskRevo: (prompt: string) => void;
}) {
  const [expandedCardId, setExpandedCardId] = useState<string | null>(null);
  const overviewCards = cards.slice(0, 2);

  return (
    <ScrollView contentContainerStyle={styles.screenBody}>
      <View style={styles.screenHeader}>
        <Text style={styles.brandLabel}>REVOCRED</Text>
        <View style={styles.avatarWrap}>
          <Text style={styles.avatarText}>JS</Text>
        </View>
      </View>
      <Text style={styles.welcomeText}>Welcome back, Javed</Text>

      <View style={styles.homeHeroCard}>
        <Text style={styles.cardSectionLabel}>COMMAND CENTER</Text>
        <View style={styles.heroMetricsRow}>
          <View style={styles.heroMetricBlock}>
            <Text style={styles.heroMetricValue}>${pointsValue}</Text>
            <Text style={styles.heroMetricLabel}>Points value</Text>
          </View>
          <View style={styles.heroMetricDivider} />
          <View style={styles.heroMetricBlock}>
            <Text style={styles.heroMetricValue}>${projectedValue}</Text>
            <Text style={styles.heroMetricLabel}>Projected yearly value</Text>
          </View>
        </View>
      </View>

      <Pressable style={styles.heroActionCard} onPress={() => onAskRevo("What card should I use right now?")}>
        <Text style={styles.cardSectionLabel}>NEXT BEST ACTION</Text>
        <Text style={styles.heroActionTitle}>Ask REVO what to use now</Text>
        <Text style={styles.metricHint}>Get an instant recommendation based on your wallet setup.</Text>
      </Pressable>

      <View style={styles.panelSection}>
        <Text style={styles.cardSectionLabel}>OVERVIEW</Text>
        <Text style={styles.screenSectionTitle}>Your Card Setup</Text>
        <Text style={styles.panelHint}>Tap any card to flip it and view why it matters in your strategy.</Text>
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

  return (
    <>
      <ScrollView contentContainerStyle={styles.screenBody}>
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

        <Text style={styles.screenSectionTitle}>Your Timeline</Text>
        <Text style={styles.panelHint}>Build your setup step by step</Text>

        <View style={styles.timelineWrap}>
          {timeline.map((entry, index) => (
            <View key={entry.id} style={styles.timelineStep}>
              <View style={[styles.timelinePill, index === 0 ? styles.timelinePillStart : undefined]}>
                <Text style={styles.timelinePillText}>{entry.title}</Text>
              </View>
              <Text style={styles.timelineMonth}>{entry.monthLabel}</Text>
              <Text style={styles.timelineNote}>{entry.note}</Text>
              {index < timeline.length - 1 ? <Text style={styles.timelineArrow}>↓</Text> : null}
            </View>
          ))}
        </View>

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
                    <Pressable style={styles.askRevoButton} onPress={() => onAskRevo(`Tell me more about ${card.name}`)}>
                      <Text style={styles.askRevoLabel}>ASK REVO</Text>
                      <Text style={styles.askRevoText}>Ask REVO about {card.name}</Text>
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

  const submitPrompt = async (prompt: string) => {
    if (!prompt.trim()) {
      return;
    }
    setIsThinking(true);
    try {
      await onSubmitPrompt(prompt);
      setQuestion("");
    } finally {
      setIsThinking(false);
    }
  };

  return (
    <View style={styles.revoWrap}>
      <ScrollView contentContainerStyle={styles.screenBody}>
        <Text style={styles.revoHeading}>Ask REVO</Text>
        <Text style={styles.panelHint}>AI recommendations for every swipe, transfer, and spend moment.</Text>

        <View style={styles.promptChipWrap}>
          {quickPrompts.map((prompt) => (
            <Pressable key={prompt} style={styles.promptChip} onPress={() => void submitPrompt(prompt)}>
              <Text style={styles.promptChipText}>{prompt}</Text>
            </Pressable>
          ))}
        </View>

        {messages.length ? (
          <View style={styles.chatPanel}>
            {messages.map((message, index) => (
              <View
                key={`${message.id}-${index}`}
                style={[styles.chatBubble, message.role === "user" ? styles.chatBubbleUser : styles.chatBubbleAssistant]}
              >
                <Text style={[styles.chatBubbleText, message.role === "user" ? styles.chatBubbleTextUser : styles.chatBubbleTextAssistant]}>
                  {message.content}
                </Text>
              </View>
            ))}
            {isThinking ? (
              <View style={[styles.chatBubble, styles.chatBubbleAssistant]}>
                <Text style={[styles.chatBubbleText, styles.chatBubbleTextAssistant]}>REVO is thinking...</Text>
              </View>
            ) : null}
          </View>
        ) : (
          <View style={styles.emptyStateCard}>
            <Text style={styles.emptyStateTitle}>No conversation yet</Text>
            <Text style={styles.emptyStateText}>Tap a prompt or ask REVO your next card move.</Text>
          </View>
        )}
      </ScrollView>
      <View style={styles.inputDock}>
        <View style={styles.inputRow}>
          <TextInput
            value={question}
            onChangeText={setQuestion}
            placeholder="Ask REVO anything..."
            placeholderTextColor="#6d7aab"
            style={styles.input}
            onSubmitEditing={() => void submitPrompt(question)}
          />
          <Pressable
            style={[styles.sendButton, isThinking ? styles.disabledCard : undefined]}
            onPress={() => void submitPrompt(question)}
            disabled={isThinking}
          >
            <Text style={styles.sendButtonText}>{isThinking ? "..." : "Send"}</Text>
          </Pressable>
        </View>
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
  onSignOut,
}: {
  profile: Profile;
  walletCount: number;
  analyticsSummary: RevoAnalyticsSummary | null;
  analyticsLoading: boolean;
  onRefreshAnalytics: () => Promise<void>;
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
    { key: "Strategy", kind: "mc", icon: "chess-knight" },
    { key: "REVO", kind: "text", icon: "R" },
    { key: "Profile", kind: "ion", icon: "person-circle-outline" },
  ];

  return (
    <View style={styles.bottomNavWrap}>
      <View style={styles.bottomTabsPill}>
        {tabs.map((tab) => (
          <Pressable key={tab.key} onPress={() => onChange(tab.key)} style={[styles.navButton, activeTab === tab.key ? styles.navButtonActive : undefined]}>
            {tab.kind === "ion" ? (
              <Ionicons
                name={tab.icon as "home-outline" | "card-outline" | "person-circle-outline"}
                size={22}
                style={[styles.navIcon, activeTab === tab.key ? styles.navIconActive : undefined]}
              />
            ) : tab.kind === "mc" ? (
              <MaterialCommunityIcons name={tab.icon as "chess-knight"} size={22} style={[styles.navIcon, activeTab === tab.key ? styles.navIconActive : undefined]} />
            ) : (
              <Text style={[styles.navRevoIcon, activeTab === tab.key ? styles.navIconActive : undefined]}>{tab.icon}</Text>
            )}
          </Pressable>
        ))}
      </View>
    </View>
  );
}

export default function App() {
  const [activeTab, setActiveTab] = useState<TabKey>("Home");
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
    screenEntrance.setValue(0.94);
    Animated.timing(screenEntrance, {
      toValue: 1,
      duration: 220,
      useNativeDriver: true,
    }).start();
  }, [activeTab, screenEntrance]);

  const screenTranslateY = screenEntrance.interpolate({
    inputRange: [0.94, 1],
    outputRange: [10, 0],
  });

  const renderedScreen = useMemo(() => {
    if (!data) {
      return (
        <View style={styles.loadingWrap}>
          <ActivityIndicator color="#dfe7ff" size="large" />
          <Text style={styles.loadingText}>Loading your revocred setup...</Text>
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
    signOut,
    submitPrompt,
  ]);

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="light" />
      <View style={styles.appBackground}>
        <View style={styles.glow} />
        <View style={styles.screenContainer}>
          {loading ? (
            <View style={styles.loadingWrap}>
              <ActivityIndicator color={palette.textPrimary} size="large" />
              <Text style={styles.loadingText}>Loading your revocred setup...</Text>
            </View>
          ) : session ? (
            <Animated.View style={[styles.screenTransitionLayer, { opacity: screenEntrance, transform: [{ translateY: screenTranslateY }] }]}>
              {renderedScreen}
            </Animated.View>
          ) : (
            <AuthScreen onSignIn={signIn} onSignUp={signUp} authError={authError} />
          )}
        </View>
        {loading || !session ? null : <BottomNav activeTab={activeTab} onChange={setActiveTab} />}
      </View>
    </SafeAreaView>
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
  brandLabel: {
    color: palette.textSecondary,
    fontSize: typeScale.xs,
    letterSpacing: 3,
    fontWeight: "600",
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
  welcomeText: {
    color: palette.textPrimary,
    fontSize: typeScale.hero,
    lineHeight: 42,
    fontWeight: "700",
    marginBottom: spacing.xs,
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
    padding: spacing.xs,
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
    minHeight: 166,
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
    gap: spacing.xs,
    alignItems: "flex-start",
  },
  walletCardPreviewContainer: {
    flexShrink: 0,
  },
  walletCardPreviewContainerCollapsed: {
    width: 112,
    height: 70,
  },
  walletCardPreviewContainerExpanded: {
    width: 132,
    height: 84,
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
    fontSize: typeScale.base,
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
    fontSize: typeScale.xs,
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
    fontSize: typeScale.sm,
    lineHeight: 18,
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
  cardArtName: {
    color: "#FFFFFF",
    fontSize: typeScale.base,
    fontWeight: "700",
    zIndex: 1,
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
    color: palette.textSecondary,
    fontSize: typeScale.xs,
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
  revoWrap: {
    flex: 1,
  },
  revoHeading: {
    color: palette.textPrimary,
    fontSize: typeScale.hero,
    fontWeight: "700",
  },
  promptChipWrap: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.xs,
  },
  promptChip: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: "#344A7D",
    backgroundColor: "#162445",
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
  },
  promptChipText: {
    color: "#D7E1FF",
    fontSize: typeScale.sm,
    lineHeight: 18,
  },
  chatPanel: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surface,
    padding: spacing.sm,
    gap: spacing.xs,
  },
  chatBubble: {
    borderRadius: radii.md,
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xs,
    maxWidth: "92%",
  },
  chatBubbleUser: {
    alignSelf: "flex-end",
    backgroundColor: palette.accent,
  },
  chatBubbleAssistant: {
    alignSelf: "flex-start",
    backgroundColor: "#1A2748",
  },
  chatBubbleText: {
    fontSize: typeScale.sm,
    lineHeight: 20,
  },
  chatBubbleTextUser: {
    color: "#F4F7FF",
  },
  chatBubbleTextAssistant: {
    color: "#D7E2FF",
  },
  emptyStateCard: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surface,
    padding: spacing.sm,
    gap: spacing.xs,
    alignItems: "flex-start",
  },
  emptyStateTitle: {
    color: palette.textPrimary,
    fontSize: typeScale.lg,
    fontWeight: "600",
  },
  emptyStateText: {
    color: palette.textSecondary,
    fontSize: typeScale.sm,
  },
  inputDock: {
    borderTopWidth: 1,
    borderColor: palette.border,
    backgroundColor: "#070F21",
    paddingHorizontal: spacing.sm,
    paddingTop: spacing.xs,
    paddingBottom: spacing.sm,
  },
  inputRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.xs,
  },
  input: {
    flex: 1,
    height: 52,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: palette.surface,
    color: palette.textPrimary,
    fontSize: typeScale.base,
    paddingHorizontal: spacing.xs,
  },
  sendButton: {
    height: 52,
    minWidth: 70,
    borderRadius: radii.md,
    backgroundColor: palette.accent,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: spacing.xs,
  },
  sendButtonText: {
    color: "#F2F6FF",
    fontSize: typeScale.sm,
    fontWeight: "700",
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
    borderColor: "#293B63",
    backgroundColor: "rgba(12, 19, 38, 0.92)",
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
  navButtonActive: {
    backgroundColor: "rgba(111, 139, 255, 0.22)",
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
