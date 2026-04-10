import { StatusBar } from "expo-status-bar";
import { useMemo, useState } from "react";
import {
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

type TabKey = "Home" | "Cards" | "Strategy" | "REVO" | "Profile";

type Card = {
  id: string;
  brand: string;
  name: string;
  bestUse: string;
  multiplier: string;
  status: "Active" | "Inactive";
  benefits: string[];
};

type Recommendation = {
  id: string;
  title: string;
  monthLabel: string;
  note: string;
};

const walletCards: Card[] = [
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

const recommendedCards: Card[] = [
  walletCards[0],
  walletCards[1],
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

const timeline: Recommendation[] = [
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

const quickPrompts = [
  "What card should I use for groceries?",
  "What should I apply for next?",
  "How do I maximize travel?",
];

const profileRows = [
  { key: "Name", value: "Javed Saliman" },
  { key: "Credit Card Strategy", value: "Hybrid cash back + travel" },
  { key: "Goal", value: "Maximize points without wasting perks" },
  { key: "Setup", value: "5 active cards" },
  { key: "Top Spend Categories", value: "Dining, groceries, travel" },
  { key: "Next Application Target", value: "Citi Custom Cash" },
];

function topCardColor(cardId: string): string {
  switch (cardId) {
    case "amex-gold":
      return "#D0B163";
    case "venture-x":
      return "#2E365E";
    case "freedom-unlimited":
      return "#3F62E0";
    case "freedom-flex":
      return "#A347D7";
    default:
      return "#293657";
  }
}

function CardPreview({ card }: { card: Card }) {
  return (
    <View style={[styles.cardPreview, { backgroundColor: topCardColor(card.id) }]}>
      <Text style={styles.cardPreviewBrand}>{card.brand}</Text>
      <Text style={styles.cardPreviewName}>{card.name}</Text>
    </View>
  );
}

function WalletCard({
  card,
  expanded,
  onToggle,
}: {
  card: Card;
  expanded: boolean;
  onToggle: () => void;
}) {
  return (
    <Pressable onPress={onToggle} style={styles.walletCard}>
      <View style={styles.walletCardTopRow}>
        <CardPreview card={card} />
        <View style={styles.walletCardBody}>
          <View style={styles.walletCardHeader}>
            <Text style={styles.walletCardName}>{card.name}</Text>
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{card.status}</Text>
            </View>
          </View>
          <Text style={styles.walletCardSubLabel}>BEST USE</Text>
          <Text style={styles.walletCardBestUse}>{card.bestUse}</Text>
          <View style={styles.walletFooterRow}>
            <View style={styles.multiplierBubble}>
              <Text style={styles.multiplierText}>{card.multiplier}</Text>
            </View>
            <Text style={styles.tapHint}>{expanded ? "Tap to return" : "Tap to flip"}</Text>
          </View>
        </View>
      </View>
      {expanded ? (
        <View style={styles.expandedWrap}>
          <Text style={styles.expandedTitle}>Key Benefits</Text>
          {card.benefits.map((benefit) => (
            <View key={`${card.id}-${benefit}`} style={styles.benefitPill}>
              <Text style={styles.benefitText}>{benefit}</Text>
            </View>
          ))}
          <Pressable style={styles.askRevoButton}>
            <Text style={styles.askRevoLabel}>ASK REVO</Text>
            <Text style={styles.askRevoText}>Ask REVO about {card.name}</Text>
          </Pressable>
        </View>
      ) : null}
    </Pressable>
  );
}

function HomeScreen() {
  const [expandedCardId, setExpandedCardId] = useState<string | null>(null);

  return (
    <ScrollView contentContainerStyle={styles.screenBody}>
      <View style={styles.screenHeader}>
        <Text style={styles.brandLabel}>REVOCRED</Text>
        <View style={styles.avatarWrap}>
          <Text style={styles.avatarText}>JS</Text>
        </View>
      </View>
      <Text style={styles.welcomeText}>Welcome back, Javed</Text>

      <View style={styles.topCardRow}>
        <View style={[styles.metricCard, styles.metricCardHalf]}>
          <Text style={styles.cardSectionLabel}>POINTS VALUE</Text>
          <Text style={styles.metricValue}>$359</Text>
          <Text style={styles.metricHint}>Based on your active balances</Text>
        </View>
        <Pressable style={[styles.metricCard, styles.metricCardHalf]}>
          <Text style={styles.cardSectionLabel}>ASK REVO</Text>
          <Text style={styles.metricQuestion}>Get your next best move</Text>
          <Text style={styles.metricHint}>What card should I use right now?</Text>
        </Pressable>
      </View>

      <View style={styles.metricCard}>
        <Text style={styles.cardSectionLabel}>PROJECTED VALUE</Text>
        <Text style={styles.metricQuestion}>$300 this year</Text>
        <Text style={styles.metricHint}>Estimated using your current card setup and balances</Text>
      </View>

      <View style={styles.panelSection}>
        <Text style={styles.cardSectionLabel}>OVERVIEW</Text>
        <Text style={styles.panelTitle}>Your Card Setup</Text>
        <Text style={styles.panelHint}>Tap any card to flip it and view why it matters in your strategy.</Text>
        <WalletCard
          card={walletCards[0]}
          expanded={expandedCardId === walletCards[0].id}
          onToggle={() =>
            setExpandedCardId((current) => (current === walletCards[0].id ? null : walletCards[0].id))
          }
        />
        <WalletCard
          card={walletCards[1]}
          expanded={expandedCardId === walletCards[1].id}
          onToggle={() =>
            setExpandedCardId((current) => (current === walletCards[1].id ? null : walletCards[1].id))
          }
        />
      </View>
    </ScrollView>
  );
}

function CardsScreen() {
  const [expandedCardId, setExpandedCardId] = useState<string | null>(null);

  return (
    <ScrollView contentContainerStyle={styles.screenBody}>
      <View style={styles.screenHeader}>
        <Text style={styles.cardSectionLabel}>CARDS</Text>
        <View style={styles.walletCountCard}>
          <Text style={styles.cardSectionLabel}>WALLET</Text>
          <Text style={styles.walletCountValue}>5 active{"\n"}cards</Text>
        </View>
      </View>
      <Text style={styles.panelTitle}>Your Card Setup</Text>
      <Text style={styles.panelHint}>Tap any card to flip it and view the key benefits behind your setup.</Text>
      {walletCards.map((card) => (
        <WalletCard
          key={card.id}
          card={card}
          expanded={expandedCardId === card.id}
          onToggle={() => setExpandedCardId((current) => (current === card.id ? null : card.id))}
        />
      ))}
      <Pressable style={styles.addCardButton}>
        <Text style={styles.addCardPlus}>+</Text>
        <Text style={styles.addCardText}>Add card</Text>
      </Pressable>
    </ScrollView>
  );
}

function StrategyScreen() {
  const [openRecommendationIds, setOpenRecommendationIds] = useState<string[]>([]);

  const toggleRecommendation = (id: string) => {
    setOpenRecommendationIds((existing) =>
      existing.includes(id) ? existing.filter((entry) => entry !== id) : [...existing, id]
    );
  };

  return (
    <ScrollView contentContainerStyle={styles.screenBody}>
      <View style={styles.searchBar}>
        <Text style={styles.searchPlaceholder}>Search credit cards...</Text>
      </View>

      <Text style={styles.panelTitle}>Your Timeline</Text>
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
                  <Text style={styles.walletCardName}>{card.name}</Text>
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
                  <Pressable style={styles.askRevoButton}>
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
  );
}

function RevoScreen() {
  const [question, setQuestion] = useState("");
  const [messages, setMessages] = useState<string[]>([]);

  const submitPrompt = (prompt: string) => {
    if (!prompt.trim()) {
      return;
    }
    setMessages((existing) => [...existing, `You: ${prompt}`, "REVO: Great question. This is where your tailored answer will appear."]);
    setQuestion("");
  };

  return (
    <View style={styles.revoWrap}>
      <ScrollView contentContainerStyle={styles.screenBody}>
        <Text style={styles.revoHeading}>Let's maximize</Text>
        <Text style={styles.cardSectionLabel}>TRY ASKING</Text>
        {quickPrompts.map((prompt) => (
          <Pressable key={prompt} style={styles.promptButton} onPress={() => submitPrompt(prompt)}>
            <Text style={styles.promptText}>{prompt}</Text>
            <Text style={styles.chevron}>›</Text>
          </Pressable>
        ))}
        {messages.length ? (
          <View style={styles.chatPanel}>
            {messages.map((message, index) => (
              <Text key={`${message}-${index}`} style={styles.chatMessage}>
                {message}
              </Text>
            ))}
          </View>
        ) : null}
      </ScrollView>
      <View style={styles.inputDock}>
        <TextInput
          value={question}
          onChangeText={setQuestion}
          placeholder="Ask REVO anything..."
          placeholderTextColor="#6d7aab"
          style={styles.input}
          onSubmitEditing={() => submitPrompt(question)}
        />
      </View>
    </View>
  );
}

function ProfileScreen() {
  return (
    <ScrollView contentContainerStyle={styles.screenBody}>
      <Text style={styles.cardSectionLabel}>PROFILE</Text>
      <Text style={styles.panelTitle}>Javed Saliman</Text>
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
    </ScrollView>
  );
}

function BottomNav({ activeTab, onChange }: { activeTab: TabKey; onChange: (tab: TabKey) => void }) {
  const tabs: TabKey[] = ["Home", "Cards", "Strategy", "REVO", "Profile"];

  return (
    <View style={styles.bottomNavWrap}>
      <View style={styles.bottomDotsRow}>
        {tabs.map((tab) => (
          <View key={`${tab}-dot`} style={[styles.navDot, activeTab === tab ? styles.navDotActive : undefined]} />
        ))}
      </View>
      <View style={styles.bottomTabsRow}>
        {tabs.map((tab) => (
          <Pressable key={tab} onPress={() => onChange(tab)} style={[styles.navButton, activeTab === tab ? styles.navButtonActive : undefined]}>
            <Text style={[styles.navLabel, activeTab === tab ? styles.navLabelActive : undefined]}>{tab}</Text>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

export default function App() {
  const [activeTab, setActiveTab] = useState<TabKey>("Home");

  const renderedScreen = useMemo(() => {
    switch (activeTab) {
      case "Home":
        return <HomeScreen />;
      case "Cards":
        return <CardsScreen />;
      case "Strategy":
        return <StrategyScreen />;
      case "REVO":
        return <RevoScreen />;
      case "Profile":
        return <ProfileScreen />;
      default:
        return <HomeScreen />;
    }
  }, [activeTab]);

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="light" />
      <View style={styles.appBackground}>
        <View style={styles.glow} />
        <View style={styles.screenContainer}>{renderedScreen}</View>
        <BottomNav activeTab={activeTab} onChange={setActiveTab} />
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: "#020818",
  },
  appBackground: {
    flex: 1,
    backgroundColor: "#020818",
  },
  glow: {
    position: "absolute",
    left: "18%",
    right: "18%",
    top: 10,
    height: 190,
    borderRadius: 96,
    backgroundColor: "#1f3984",
    opacity: 0.18,
  },
  screenContainer: {
    flex: 1,
  },
  screenBody: {
    paddingHorizontal: 20,
    paddingTop: 14,
    paddingBottom: 28,
    gap: 14,
  },
  screenHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  brandLabel: {
    color: "#95a2d4",
    fontSize: 13,
    letterSpacing: 4,
    fontWeight: "500",
  },
  avatarWrap: {
    width: 48,
    height: 48,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: "#2f406f",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#10203f",
  },
  avatarText: {
    color: "#edf2ff",
    fontWeight: "700",
    fontSize: 22,
  },
  welcomeText: {
    color: "#edf2ff",
    fontSize: 40,
    lineHeight: 46,
    fontWeight: "700",
    marginBottom: 6,
  },
  topCardRow: {
    flexDirection: "row",
    gap: 12,
  },
  metricCard: {
    borderRadius: 24,
    borderColor: "#25345e",
    borderWidth: 1,
    backgroundColor: "#111d3d",
    padding: 20,
    gap: 6,
  },
  metricCardHalf: {
    flex: 1,
    minHeight: 160,
  },
  metricValue: {
    color: "#edf2ff",
    fontSize: 48,
    fontWeight: "700",
  },
  metricQuestion: {
    color: "#edf2ff",
    fontSize: 38,
    lineHeight: 40,
    fontWeight: "700",
  },
  metricHint: {
    color: "#91a0cc",
    fontSize: 22,
    lineHeight: 28,
    marginTop: 6,
  },
  cardSectionLabel: {
    color: "#8f9ecb",
    fontSize: 13,
    letterSpacing: 4,
    fontWeight: "500",
  },
  panelSection: {
    borderRadius: 24,
    borderColor: "#25345e",
    borderWidth: 1,
    backgroundColor: "#0c1532",
    padding: 16,
    gap: 10,
  },
  panelTitle: {
    color: "#edf2ff",
    fontSize: 42,
    lineHeight: 48,
    fontWeight: "700",
  },
  panelHint: {
    color: "#8f9ecb",
    fontSize: 28,
    lineHeight: 34,
    marginBottom: 4,
  },
  walletCard: {
    borderRadius: 22,
    borderWidth: 1,
    borderColor: "#2c3b67",
    backgroundColor: "#1e2948",
    padding: 14,
    gap: 12,
  },
  walletCardTopRow: {
    flexDirection: "row",
    gap: 14,
  },
  cardPreview: {
    width: 172,
    height: 108,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 12,
    justifyContent: "space-between",
  },
  cardPreviewBrand: {
    color: "#dce6ff",
    fontSize: 11,
    letterSpacing: 3,
  },
  cardPreviewName: {
    color: "#f2f6ff",
    fontSize: 26,
    fontWeight: "500",
  },
  walletCardBody: {
    flex: 1,
    gap: 4,
  },
  walletCardHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  walletCardName: {
    color: "#edf2ff",
    fontSize: 40,
    fontWeight: "700",
    flexShrink: 1,
  },
  badge: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 22,
    backgroundColor: "#42568f",
  },
  badgeText: {
    color: "#e7ecff",
    fontSize: 24,
    fontWeight: "500",
  },
  walletCardSubLabel: {
    color: "#93a3d6",
    fontSize: 12,
    letterSpacing: 4,
    marginTop: 2,
  },
  walletCardBestUse: {
    color: "#f3f5ff",
    fontSize: 42,
    lineHeight: 48,
    fontWeight: "600",
  },
  walletFooterRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginTop: 2,
  },
  multiplierBubble: {
    backgroundColor: "#1b5254",
    borderRadius: 18,
    paddingHorizontal: 12,
    paddingVertical: 4,
  },
  multiplierText: {
    color: "#8ef1d4",
    fontSize: 24,
    fontWeight: "700",
  },
  tapHint: {
    color: "#8f9ecb",
    fontSize: 22,
  },
  expandedWrap: {
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "#2b3d6f",
    backgroundColor: "#101d3d",
    padding: 12,
    gap: 9,
  },
  expandedTitle: {
    color: "#edf2ff",
    fontSize: 36,
    fontWeight: "700",
    marginBottom: 4,
  },
  benefitPill: {
    borderRadius: 12,
    backgroundColor: "#1c2748",
    paddingVertical: 8,
    paddingHorizontal: 12,
  },
  benefitText: {
    color: "#c2ceee",
    fontSize: 27,
  },
  askRevoButton: {
    borderRadius: 14,
    borderWidth: 1,
    borderColor: "#435ca1",
    backgroundColor: "#283d74",
    padding: 12,
    marginTop: 4,
  },
  askRevoLabel: {
    color: "#95a6d6",
    fontSize: 11,
    letterSpacing: 4,
    marginBottom: 4,
  },
  askRevoText: {
    color: "#edf2ff",
    fontSize: 30,
    fontWeight: "600",
  },
  walletCountCard: {
    borderRadius: 20,
    borderWidth: 1,
    borderColor: "#3e58a6",
    backgroundColor: "#1d2f62",
    paddingHorizontal: 16,
    paddingVertical: 10,
    alignItems: "flex-start",
  },
  walletCountValue: {
    color: "#edf2ff",
    fontSize: 22,
    lineHeight: 27,
    fontWeight: "700",
    marginTop: 4,
  },
  addCardButton: {
    borderRadius: 22,
    borderWidth: 1,
    borderStyle: "dashed",
    borderColor: "#2d3f73",
    backgroundColor: "#0c1430",
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 28,
    gap: 4,
  },
  addCardPlus: {
    color: "#a8b4db",
    fontSize: 34,
    fontWeight: "300",
  },
  addCardText: {
    color: "#98a8d8",
    fontSize: 28,
  },
  searchBar: {
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "#26345f",
    backgroundColor: "#0b1230",
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  searchPlaceholder: {
    color: "#7584b3",
    fontSize: 30,
  },
  timelineWrap: {
    borderRadius: 24,
    borderWidth: 1,
    borderColor: "#24335d",
    backgroundColor: "#0a1431",
    padding: 16,
    gap: 12,
  },
  timelineStep: {
    alignItems: "center",
    gap: 4,
  },
  timelinePill: {
    borderRadius: 20,
    backgroundColor: "#233a7a",
    minWidth: 230,
    paddingHorizontal: 26,
    paddingVertical: 12,
    alignItems: "center",
  },
  timelinePillStart: {
    backgroundColor: "#5a2f4f",
  },
  timelinePillText: {
    color: "#edf2ff",
    fontSize: 34,
    fontWeight: "700",
  },
  timelineMonth: {
    color: "#d8e1ff",
    fontSize: 33,
    fontWeight: "600",
    marginTop: 2,
  },
  timelineNote: {
    color: "#8e9bc4",
    fontSize: 26,
    textAlign: "center",
    paddingHorizontal: 16,
  },
  timelineArrow: {
    color: "#7586b8",
    fontSize: 44,
    marginTop: 2,
  },
  recommendationCard: {
    borderRadius: 20,
    borderWidth: 1,
    borderColor: "#273860",
    backgroundColor: "#111d3d",
    padding: 12,
    gap: 10,
  },
  recommendationTop: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
  },
  recommendationMeta: {
    flex: 1,
  },
  recommendationBrand: {
    color: "#9badde",
    fontSize: 13,
    letterSpacing: 1.5,
    marginBottom: 2,
  },
  chevron: {
    color: "#8ea0cf",
    fontSize: 28,
    paddingHorizontal: 4,
  },
  recommendationExpanded: {
    gap: 9,
  },
  revoWrap: {
    flex: 1,
  },
  revoHeading: {
    color: "#edf2ff",
    fontSize: 52,
    textAlign: "center",
    fontWeight: "700",
    marginVertical: 10,
  },
  promptButton: {
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "#22345f",
    backgroundColor: "#0a1230",
    paddingVertical: 14,
    paddingHorizontal: 16,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  promptText: {
    color: "#d3dcf8",
    fontSize: 29,
  },
  chatPanel: {
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "#2d4176",
    backgroundColor: "#101d3d",
    padding: 12,
    gap: 8,
  },
  chatMessage: {
    color: "#dbe3ff",
    fontSize: 24,
    lineHeight: 30,
  },
  inputDock: {
    borderTopWidth: 1,
    borderColor: "#1a2b55",
    backgroundColor: "#050e26",
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  input: {
    height: 54,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: "#273960",
    backgroundColor: "#0b1535",
    color: "#edf2ff",
    fontSize: 18,
    paddingHorizontal: 14,
  },
  profileRow: {
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "#1f2f58",
    backgroundColor: "#0a1230",
    paddingHorizontal: 14,
    paddingVertical: 12,
    flexDirection: "row",
    justifyContent: "space-between",
    gap: 16,
    alignItems: "center",
  },
  profileKey: {
    color: "#91a1d3",
    fontSize: 13,
    letterSpacing: 3,
    textTransform: "uppercase",
    flex: 1,
  },
  profileValue: {
    color: "#edf2ff",
    fontSize: 26,
    fontWeight: "500",
    textAlign: "right",
    flex: 1,
  },
  reportButton: {
    borderRadius: 22,
    borderWidth: 1,
    borderColor: "#435ca1",
    backgroundColor: "#283d74",
    padding: 16,
    gap: 8,
  },
  reportTitle: {
    color: "#edf2ff",
    fontSize: 42,
    lineHeight: 46,
    fontWeight: "700",
  },
  bottomNavWrap: {
    borderTopWidth: 1,
    borderColor: "#17284f",
    backgroundColor: "#030d24",
    paddingTop: 6,
    paddingBottom: 12,
    paddingHorizontal: 10,
  },
  bottomDotsRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingHorizontal: 26,
    marginBottom: 6,
  },
  navDot: {
    width: 7,
    height: 7,
    borderRadius: 4,
    backgroundColor: "#6275a8",
    opacity: 0.7,
  },
  navDotActive: {
    backgroundColor: "#f1f4ff",
    opacity: 1,
  },
  bottomTabsRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 6,
  },
  navButton: {
    borderRadius: 18,
    paddingVertical: 10,
    paddingHorizontal: 14,
    minWidth: 58,
    alignItems: "center",
  },
  navButtonActive: {
    backgroundColor: "#3b4f87",
  },
  navLabel: {
    color: "#8795bf",
    fontSize: 16,
    fontWeight: "500",
  },
  navLabelActive: {
    color: "#eef2ff",
    fontWeight: "600",
  },
});
