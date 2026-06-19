import { AppData, Card, CardSearchEntry, ChatMessage, Metrics, Profile, Recommendation } from "../types/models";

export const seedWalletCards: Card[] = [
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

export const seedPopularPicks: Card[] = [
  seedWalletCards[0],
  seedWalletCards[1],
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

export const seedTimeline: Recommendation[] = [
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

function createInitialAssistantMessage(): ChatMessage {
  return {
    id: "seed-assistant-message-1",
    role: "assistant",
    content: "Ask me anything about your setup. I can help with card choice, timing, and points strategy.",
    createdAt: new Date().toISOString(),
  };
}

export const seedProfile: Profile = {
  name: "Javed Saliman",
  creditCardStrategy: "Hybrid cash back + travel",
  goal: "Maximize points without wasting perks",
  topSpendCategories: "Dining, groceries, travel",
  nextApplicationTarget: "Citi Custom Cash",
};

export const seedMetrics: Metrics = {
  pointsValue: 359,
  projectedYearlyValue: 300,
};

export const seedQuickPrompts = [
  "What card should I use for groceries?",
  "What should I apply for next?",
  "How do I maximize travel?",
];

export const seedCardCatalog: Card[] = [
  ...seedWalletCards,
  ...seedPopularPicks.filter((pick) => !seedWalletCards.some((walletCard) => walletCard.id === pick.id)),
  {
    id: "citi-custom-cash",
    brand: "MC",
    name: "Citi Custom Cash",
    bestUse: "Top Eligible Category",
    multiplier: "5x",
    status: "Inactive",
    benefits: ["5x top category", "No annual fee", "Flexible earning", "Great pairing card"],
  },
];

function parseCsvLine(line: string): string[] {
  const values: string[] = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i += 1) {
    const char = line[i];
    const nextChar = line[i + 1];

    if (char === "\"" && inQuotes && nextChar === "\"") {
      current += "\"";
      i += 1;
      continue;
    }

    if (char === "\"") {
      inQuotes = !inQuotes;
      continue;
    }

    if (char === "," && !inQuotes) {
      values.push(current.trim());
      current = "";
      continue;
    }

    current += char;
  }

  values.push(current.trim());
  return values;
}

function deriveTopMultiplier(pointMultiplierText: string): string {
  const normalized = pointMultiplierText.toLowerCase();
  const match = normalized.match(/(\d+(?:\.\d+)?x|\d+(?:\.\d+)?%)/);
  if (match?.[1]) {
    return match[1];
  }
  if (normalized.includes("no rewards")) {
    return "none";
  }
  if (normalized.includes("manual review")) {
    return "manual";
  }
  return "n/a";
}

const rawCardSearchCsv = `id,issuer,brand,name,annual fee,point multipliers,best use,transferable point,benefits
venture-x,Capital One,Visa,Venture X,$395.00,10x hotels and rental cars through Capital One Travel | 5x flights and vacation rentals through Capital One Travel | 2x everywhere,Premium Travel,true_direct,"$300 Capital One Travel credit annually | 10,000 anniversary miles annually | up to $120 Global Entry/TSA PreCheck credit every 4 years | Capital One Lounge access | Priority Pass lounge access | cell phone protection"
venture-one,Capital One,Visa,VentureOne,$0.00,5x hotels and rental cars through Capital One Travel | 1.25x everywhere,No-Fee Travel,true_direct,no annual fee | miles transfer partners | travel accident insurance | extended warranty | purchase protection
venture,Capital One,Visa,Venture,$95.00,5x hotels and rental cars through Capital One Travel | 2x everywhere,Simple Travel,true_direct,up to $120 Global Entry/TSA PreCheck credit every 4 years | miles transfer partners | travel accident insurance | extended warranty | purchase protection
quicksilver,Capital One,Visa,Quicksilver,$0.00,5% hotels and rental cars through Capital One Travel | 1.5% cash back everywhere,Flat Cash Back,FALSE,no annual fee | simple cash back | extended warranty | purchase protection
quicksilverone,Capital One,Mastercard,QuicksilverOne,$39.00,5% hotels and rental cars through Capital One Travel | 1.5% cash back everywhere,Credit Building Cash Back,FALSE,unlimited cash back | automatic credit line reviews | credit-building option
savor,Capital One,Mastercard,Savor,$0.00,8% Capital One Entertainment | 5% hotels and rental cars through Capital One Travel | 3% dining | 3% entertainment | 3% grocery stores | 3% streaming | 1% everywhere,Dining and Entertainment,true_pairing,no annual fee | Capital One Entertainment access | dining rewards | entertainment rewards
savorone,Capital One,Mastercard,SavorOne,$0.00,8% Capital One Entertainment | 5% hotels and rental cars through Capital One Travel | 3% dining | 3% entertainment | 3% grocery stores | 3% streaming | 1% everywhere,Dining and Entertainment,true_pairing,no annual fee | Capital One Entertainment access | dining rewards | entertainment rewards
sapphire-reserve,Chase,Visa,Sapphire Reserve,$795.00,8x Chase Travel | 5x direct flights and select travel | 4x dining | 3x select streaming | 1x everywhere,Premium Travel,true_direct,up to $300 travel credit annually | up to $120 Global Entry/TSA PreCheck/NEXUS credit every 4 years | Priority Pass lounge access | Chase Sapphire Lounge access | $500 hotel credit through The Edit annually | $300 dining credit through Sapphire Reserve Exclusive Tables annually
sapphire-preferred,Chase,Visa,Sapphire Preferred,$95.00,"5x Chase Travel | 3x dining | 3x online groceries | 3x top streaming services | 2x travel | 1x everywhere | 3x on gas and EV charging | 3x on vacation homes like Airbnb, Vrbo, and more",Travel Starter,true_direct,"up to $100 Chase Travel hotel credit annually | TSA Recheck, Nexus, or Global entry credit | trip cancellation/interruption insurance | primary rental car coverage | Complimentary DashPass membership for 12 months ($120 value)"
freedom-unlimited,Chase,Visa,Freedom Unlimited,$0.00,5x Chase Travel | 3x dining | 3x drugstores | 1.5x everywhere,Everyday Cash Back,true_pairing,no annual fee | purchase protection | extended warranty | trip cancellation/interruption insurance
freedom-flex,Chase,Mastercard,Freedom Flex,$0.00,5x rotating quarterly categories up to activation cap | 5x Chase Travel | 3x dining | 3x drugstores | 1x everywhere,Rotating Cash Back,true_pairing,no annual fee | cell phone protection up to $800 per claim | purchase protection | extended warranty
freedom-rise,Chase,Visa,Freedom Rise,$0.00,1.5% cash back everywhere,Credit Building,true_pairing,no annual fee | automatic credit line review | credit journey access
slate-edge,Chase,Visa,Slate Edge,$0.00,no rewards,Balance Transfer,FALSE,no annual fee | intro APR offers | automatic APR review | credit line review
slate,Chase,Visa,Slate,$0.00,no rewards,Balance Transfer,FALSE,no annual fee | intro APR offers | credit journey access
united-explorer,Chase,Visa,United Explorer,$0 intro first year then $150,2x United purchases | 2x dining | 2x hotels booked directly | 1x everywhere,United Travel,FALSE,first checked bag free | 2 United Club one-time passes annually | up to $120 Global Entry/TSA PreCheck/NEXUS credit every 4 years | priority boarding | 25% back on United inflight purchases
united-quest,Chase,Visa,United Quest,$350.00,3x United purchases | 2x dining | 2x select streaming | 2x other travel | 1x everywhere,United Frequent Flyer,FALSE,$200 United travel credit annually | first and second checked bags free | up to $120 Global Entry/TSA PreCheck/NEXUS credit every 4 years | priority boarding | 25% back on United inflight purchases
united-gateway,Chase,Visa,United Gateway,$0.00,2x United purchases | 2x gas | 2x local transit | 1x everywhere,No-Fee United,FALSE,no annual fee | 25% back on United inflight purchases | expanded award availability
united-club,Chase,Visa,United Club Infinite,$695.00,4x United purchases | 2x dining | 2x other travel | 1x everywhere,United Lounge,FALSE,United Club membership | first and second checked bags free | up to $120 Global Entry/TSA PreCheck/NEXUS credit every 4 years | priority check-in | priority boarding | Premier Access travel services
southwest-plus,Chase,Visa,Southwest Rapid Rewards Plus,$69.00,2x Southwest purchases | 2x Rapid Rewards hotel and car partners | 2x local transit | 2x internet cable phone and select streaming | 1x everywhere,Southwest Starter,FALSE,"3,000 anniversary points annually | 2 EarlyBird Check-In credits annually | 25% back on inflight purchases"
southwest-priority,Chase,Visa,Southwest Rapid Rewards Priority,$229.00,4x Southwest purchases | 2x Rapid Rewards hotel and car partners | 2x local transit | 2x internet cable phone and select streaming | 1x everywhere,Southwest Frequent Flyer,FALSE,"7,500 anniversary points annually | $75 Southwest travel credit annually | 4 upgraded boardings annually when available | 25% back on inflight purchases"
southwest-premier,Chase,Visa,Southwest Rapid Rewards Premier,$149.00,3x Southwest purchases | 2x Rapid Rewards hotel and car partners | 2x local transit | 2x internet cable phone and select streaming | 1x everywhere,Southwest Travel,FALSE,"6,000 anniversary points annually | 2 EarlyBird Check-In credits annually | 25% back on inflight purchases"
marriott-bonvoy-boundless,Chase,Visa,Marriott Bonvoy Boundless,$95.00,"6x Marriott Bonvoy hotels | 3x first $6,000 combined gas grocery dining annually | 2x everywhere",Marriott Travel,FALSE,"1 free night award annually up to 35,000 points | 15 elite night credits annually | automatic Silver Elite status | path to Gold Elite with spend"
marriott-bonvoy-bountiful,Chase,Visa,Marriott Bonvoy Bountiful,$250.00,"6x Marriott Bonvoy hotels | 4x first $15,000 combined grocery and dining annually | 2x everywhere",Marriott Travel,FALSE,"1 free night award after $15,000 annual spend up to 50,000 points | 15 elite night credits annually | automatic Gold Elite status"
marriott-bonvoy-bold,Chase,Visa,Marriott Bonvoy Bold,$0.00,3x Marriott Bonvoy hotels | 2x grocery rideshare select food delivery select streaming and internet cable phone | 1x everywhere,No-Fee Marriott,FALSE,no annual fee | 5 elite night credits annually | automatic Silver Elite status
ihg-premier,Chase,Mastercard,IHG One Rewards Premier,$99.00,10x IHG hotels | 5x travel dining and gas | 3x everywhere,IHG Travel,FALSE,"anniversary free night annually up to 40,000 points | fourth reward night free | up to $120 Global Entry/TSA PreCheck/NEXUS credit every 4 years | automatic Platinum Elite status"
ihg-traveler,Chase,Mastercard,IHG One Rewards Traveler,$0.00,5x IHG hotels | 3x monthly bills gas and dining | 2x everywhere,No-Fee IHG,FALSE,no annual fee | fourth reward night free | automatic Silver Elite status
world-of-hyatt,Chase,Visa,World of Hyatt,$95.00,4x Hyatt hotels | 2x dining airline tickets local transit fitness clubs | 1x everywhere,Hyatt Travel,FALSE,"1 free night annually Category 1-4 | 5 elite night credits annually | 2 additional elite nights per $5,000 spend | automatic Discoverist status"
prime,Chase,Visa,Prime Visa,$0 with eligible Prime membership,5% Amazon and Whole Foods with eligible Prime | 2% gas restaurants local transit and rideshare | 1% everywhere,Amazon Shopping,FALSE,no annual fee | 5% back with eligible Prime membership | travel and purchase protections
platinum-card,American Express,Amex,Platinum Card,$895.00,5x flights booked directly or through Amex Travel up to annual cap | 5x prepaid hotels through Amex Travel | 1x everywhere,Premium Travel,true_direct,up to $600 Fine Hotels + Resorts or The Hotel Collection credit annually | up to $400 Resy credit annually | up to $300 digital entertainment credit annually | up to $200 Uber Cash annually | up to $200 airline fee credit annually | up to $300 lululemon credit annually | up to $209 CLEAR Plus credit annually | up to $120 Global Entry/TSA PreCheck credit every 4 years | Centurion Lounge access | Priority Pass lounge access
gold-card,American Express,Amex,Gold Card,$325.00,4x restaurants worldwide up to annual cap | 4x U.S. supermarkets up to annual cap | 3x flights booked directly or through Amex Travel | 2x prepaid hotels through Amex Travel | 1x everywhere,Dining and Groceries,true_direct,up to $120 dining credit annually | up to $120 Uber Cash annually | up to $100 Resy credit annually | up to $84 Dunkin credit annually
green-card,American Express,Amex,Green Card,$150.00,3x travel | 3x transit | 3x restaurants | 1x everywhere,Travel and Transit,true_direct,up to $209 CLEAR Plus credit annually | up to $100 LoungeBuddy credit annually
blue-cash-everyday,American Express,Amex,Blue Cash Everyday,$0.00,3% U.S. supermarkets up to annual cap | 3% U.S. online retail purchases up to annual cap | 3% U.S. gas stations up to annual cap | 1% everywhere,Everyday Cash Back,FALSE,no annual fee | up to $84 Disney Bundle credit annually | up to $180 Home Chef credit annually
blue-cash-preferred,American Express,Amex,Blue Cash Preferred,$0 intro first year then $95,6% U.S. supermarkets up to annual cap | 6% select U.S. streaming | 3% transit | 3% U.S. gas stations | 1% everywhere,Groceries and Streaming,FALSE,up to $84 Disney Bundle credit annually | return protection | purchase protection
marriott-bonvoy-bevy,American Express,Amex,Marriott Bonvoy Bevy,$250.00,6x Marriott Bonvoy hotels | 4x restaurants worldwide | 4x U.S. supermarkets up to annual cap | 2x everywhere,Marriott Travel,FALSE,"1 free night award after $15,000 annual spend up to 50,000 points | 15 elite night credits annually | automatic Gold Elite status"
marriott-bonvoy-brilliant,American Express,Amex,Marriott Bonvoy Brilliant,$650.00,6x Marriott Bonvoy hotels | 3x restaurants worldwide | 3x flights booked directly | 2x everywhere,Premium Marriott,FALSE,"up to $300 dining credit annually | 1 free night award annually up to 85,000 points | 25 elite night credits annually | automatic Platinum Elite status | Priority Pass lounge access | up to $120 Global Entry/TSA PreCheck credit every 4 years"
hilton-honors,American Express,Amex,Hilton Honors,$0.00,7x Hilton hotels | 5x U.S. restaurants U.S. supermarkets and U.S. gas stations | 3x everywhere,No-Fee Hilton,FALSE,no annual fee | automatic Hilton Silver status
hilton-honors-surpass,American Express,Amex,Hilton Honors Surpass,$150.00,12x Hilton hotels | 6x U.S. restaurants U.S. supermarkets and U.S. gas stations | 4x U.S. online retail | 3x everywhere,Hilton Travel,FALSE,up to $200 Hilton credit annually paid quarterly | automatic Hilton Gold status | National Car Rental Emerald Club Executive status
delta-skymiles-blue,American Express,Amex,Delta SkyMiles Blue,$0.00,2x Delta purchases | 2x restaurants worldwide | 1x everywhere,No-Fee Delta,FALSE,no annual fee | 20% back on Delta inflight purchases
delta-skymiles-gold,American Express,Amex,Delta SkyMiles Gold,$0 intro first year then $150,2x Delta purchases | 2x U.S. supermarkets | 2x restaurants worldwide | 1x everywhere,Delta Starter,FALSE,"first checked bag free | priority boarding | up to $200 Delta flight credit after $10,000 annual spend | $100 Delta Stays credit annually | 20% back on Delta inflight purchases"
delta-skymiles-platinum,American Express,Amex,Delta SkyMiles Platinum,$350.00,3x Delta purchases | 3x hotels booked directly | 2x U.S. supermarkets | 2x restaurants worldwide | 1x everywhere,Delta Frequent Flyer,FALSE,annual companion certificate Main Cabin | first checked bag free | priority boarding | up to $120 Global Entry/TSA PreCheck credit every 4 years | $150 Delta Stays credit annually | up to $120 rideshare credit annually | up to $120 Resy credit annually
delta-skymiles-reserve,American Express,Amex,Delta SkyMiles Reserve,$650.00,3x Delta purchases | 1x everywhere,Premium Delta,FALSE,Delta Sky Club access when flying Delta with visit limits | Centurion Lounge access when flying Delta | annual companion certificate First Class Comfort Plus or Main Cabin | first checked bag free | priority boarding | up to $120 Global Entry/TSA PreCheck credit every 4 years | $200 Delta Stays credit annually | up to $120 rideshare credit annually | up to $240 Resy credit annually
citi-custom-cash,Citi,Mastercard,Custom Cash,$0.00,5x top eligible spend category each billing cycle up to monthly cap | 1x everywhere,Flexible Cash Back,true_pairing,no annual fee | automatic top-category rewards
citi-double-cash,Citi,Mastercard,Double Cash,$0.00,2% total cash back everywhere with 1% when buying and 1% when paying,Flat Cash Back,true_pairing,no annual fee | simple cash back | ThankYou points option
citi-strata,Citi,Mastercard,Strata,$0.00,3x select transit | 3x EV charging | 3x gas | 3x supermarkets | 3x restaurants | 1x everywhere,Everyday Rewards,true_pairing,no annual fee | Citi Entertainment access
citi-strata-premier,Citi,Mastercard,Strata Premier,$95.00,10x hotels car rentals and attractions through Citi Travel | 3x air travel and hotels | 3x restaurants | 3x supermarkets | 3x gas and EV charging | 1x everywhere,Travel Rewards,true_direct,$100 hotel savings benefit annually on eligible Citi Travel hotel stay of $500+ | transfer partners
citi-strata-elite,Citi,Mastercard,Strata Elite,$595.00,12x hotels car rentals and attractions through Citi Travel | 6x air travel through Citi Travel | 6x restaurants Friday and Saturday nights | 3x restaurants other nights | 1.5x everywhere,Premium Citi Travel,true_direct,up to $300 annual hotel benefit through Citi Travel | up to $200 Splurge credit annually | up to $120 Global Entry/TSA PreCheck credit every 4 years | Priority Pass lounge access | four American Airlines Admirals Club passes annually
citi-diamond-preferred,Citi,Mastercard,Diamond Preferred,$0.00,no rewards,Balance Transfer,FALSE,no annual fee | intro APR offers | Citi Entertainment access
citi-simplicity,Citi,Mastercard,Simplicity,$0.00,no rewards,Balance Transfer,FALSE,no annual fee | no late fees | no penalty APR | intro APR offers
costco-anywhere,Citi,Visa,Costco Anywhere,$0 with paid Costco membership,4% eligible gas and EV charging up to annual cap | 3% restaurants and eligible travel | 2% Costco and Costco.com | 1% everywhere,Costco and Gas,FALSE,no annual fee with paid Costco membership | annual Costco reward certificate
aadvantage-mileup,Citi,Mastercard,AAdvantage MileUp,$0.00,2x grocery stores | 2x American Airlines purchases | 1x everywhere,No-Fee American Airlines,FALSE,no annual fee | 25% savings on American Airlines inflight food and beverage
aadvantage-platinum-select,Citi,Mastercard,AAdvantage Platinum Select,$0 intro first year then $99,2x American Airlines purchases | 2x restaurants | 2x gas | 1x everywhere,American Airlines Travel,FALSE,"first checked bag free | preferred boarding | $125 American Airlines flight discount after $20,000 annual spend | 25% savings on American Airlines inflight food and beverage"
aadvantage-globe,Citi,Mastercard,AAdvantage Globe,$350.00,6x eligible American Airlines purchases | 3x hotels | 3x car rentals | 1x everywhere,American Airlines Premium,FALSE,up to $100 Global Entry/TSA PreCheck credit every 4 years | first checked bag free | preferred boarding | American Airlines travel credits and statement credits
aadvantage-executive,Citi,Mastercard,AAdvantage Executive,$595.00,10x eligible car rentals and hotels through AA portal | 4x American Airlines purchases | 1x everywhere,American Airlines Lounge,FALSE,Admirals Club membership | first checked bag free | priority check-in | priority screening where available | priority boarding | up to $120 Global Entry/TSA PreCheck credit every 4 years | 25% savings on inflight food and beverage
bilt-blue-card,Bilt,Mastercard,Blue Card,$0.00,1x rent payments through Bilt | 1x everywhere,Rent Rewards,true_direct,no annual fee | rent payment rewards | Bilt transfer partners
bilt-obsidian-card,Bilt,Mastercard,Obsidian Card,manual review,manual review,Rent Rewards,true_direct,manual review | not a standard public Bilt consumer card
bilt-palladium-card,Bilt,Mastercard,Palladium Card,manual review,manual review,Rent Rewards,true_direct,manual review | not a standard public Bilt consumer card
active-cash,Wells Fargo,Visa,Active Cash,$0.00,2% cash rewards everywhere,Flat Cash Back,true_pairing,no annual fee | cell phone protection up to $600 per claim | Visa Signature benefits
autograph,Wells Fargo,Visa,Autograph,$0.00,3x restaurants | 3x travel | 3x gas | 3x transit | 3x popular streaming | 3x phone plans | 1x everywhere,Everyday Travel,true_direct,no annual fee | cell phone protection up to $600 per claim | auto rental collision damage waiver
autograph-journey,Wells Fargo,Visa,Autograph Journey,$95.00,5x hotels | 4x airlines | 3x other travel and restaurants | 1x everywhere,Travel Rewards,true_direct,$50 annual airline statement credit | cell phone protection up to $600 per claim | auto rental collision damage waiver
reflect,Wells Fargo,Visa,Reflect,$0.00,no rewards,Balance Transfer,FALSE,no annual fee | intro APR offers | cell phone protection up to $600 per claim
attune,Wells Fargo,Mastercard,Attune,$0.00,4% select self-care planet-friendly and entertainment purchases | 1% everywhere,Lifestyle Cash Back,true_pairing,no annual fee | cell phone protection up to $600 per claim | unique lifestyle category rewards
discover-it-cash-back,Discover,Discover,Discover it Cash Back,$0.00,5% rotating quarterly categories when activated up to quarterly cap | 1% everywhere,Rotating Cash Back,FALSE,no annual fee | Cashback Match first year | free FICO score
discover-it-miles,Discover,Discover,Discover it Miles,$0.00,1.5x miles everywhere,No-Fee Travel,FALSE,no annual fee | unlimited mile-for-mile match first year | no foreign transaction fees
discover-it-chrome,Discover,Discover,Discover it Chrome,$0.00,2% gas and restaurants up to quarterly cap | 1% everywhere,Gas and Dining,FALSE,no annual fee | Cashback Match first year | free FICO score
discover-it-student-cash-back,Discover,Discover,Discover it Student Cash Back,$0.00,5% rotating quarterly categories when activated up to quarterly cap | 1% everywhere,Student Cash Back,FALSE,no annual fee | Cashback Match first year | free FICO score
apple-card,Apple,Mastercard,Apple Card,$0.00,3% Apple and select merchants with Apple Pay | 2% Apple Pay | 1% physical card,Apple Pay Cash Back,FALSE,no annual fee | Daily Cash | no foreign transaction fees | Apple Wallet integration
venmo,Venmo,Visa,Venmo Credit Card,$0.00,3% top eligible category | 2% second eligible category | 1% everywhere,Flexible Cash Back,FALSE,no annual fee | automatic category rewards | cash back to Venmo | QR code card payments
amazon-store-card,Amazon,Store Card,Amazon Store Card,$0 with optional Prime membership,5% Amazon.com with eligible Prime | promotional financing offers | 0% rewards without eligible Prime,Amazon Financing,FALSE,no annual fee | 5% back with eligible Prime membership | promotional financing
paypal-cashback,PayPal,Mastercard,PayPal Cashback Mastercard,$0.00,3% PayPal checkout | 1.5% everywhere,PayPal Cash Back,FALSE,no annual fee | cash back to PayPal | Mastercard benefits`;

export const seedCardSearchCatalog: CardSearchEntry[] = rawCardSearchCsv
  .trim()
  .split("\n")
  .slice(1)
  .map((line) => parseCsvLine(line))
  .filter((values) => values.length >= 9)
  .map((values) => {
    const [id, issuer, brand, name, annualFee, pointMultiplierText, bestUse, transferablePointText, benefitsText] = values;
    const pointMultipliers = pointMultiplierText
      .split("|")
      .map((value) => value.trim())
      .filter(Boolean);
    const benefits = benefitsText
      .split("|")
      .map((value) => value.trim())
      .filter(Boolean);

    return {
      id,
      issuer,
      brand,
      name,
      annualFee,
      pointMultipliers,
      transferablePoints: transferablePointText.toLowerCase().startsWith("true"),
      benefits,
      bestUse,
      multiplier: deriveTopMultiplier(pointMultiplierText),
    };
  });

export function initialAssistantMessage(): ChatMessage {
  return createInitialAssistantMessage();
}

export const seedAppData: AppData = {
  profile: seedProfile,
  metrics: seedMetrics,
  walletCards: seedWalletCards,
  strategyTimeline: seedTimeline,
  popularPicks: seedPopularPicks,
  cardSearchCatalog: seedCardSearchCatalog,
  quickPrompts: seedQuickPrompts,
  chatMessages: [createInitialAssistantMessage()],
  cardCatalog: seedCardCatalog,
};
