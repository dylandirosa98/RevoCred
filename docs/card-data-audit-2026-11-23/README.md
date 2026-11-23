# RevoCred Card Catalog Terms Audit — 2026-11-23

**Audit date:** `2026-11-23` (live issuer fetches completed `2026-11-23T07:24:16Z`–`2026-11-23T07:24:45Z`, corroborated by HTTP `Date: Mon, 23 Nov 2026 07:24 GMT` headers).  
**Scope:** Independent verification of all **14 active recommendable `issuer_snapshot` catalog cards** (the 14 playbook cards seeded in `000004`–`000006` and linked in `000011_official_application_links.sql`), plus a transparency addendum covering the 15th `issuer_snapshot` database row (`discover-it-cash-back`, added in `000026_discover_it_cash_back.sql`).  
**Companion artifacts:**
- Structured comparison table: [card-audit.csv](card-audit.csv)
- Forward-only catalog migration: [000032_catalog_audit_2026_11_23.sql](../../revocred-api/migrations/000032_catalog_audit_2026_11_23.sql) (`dataset_version = 'conservative-2026-11-23-v1'`)

---

## Executive Summary

All 14 official issuer product pages returned HTTP `200` directly from the issuers (`americanexpress.com`, `capitalone.com`, `creditcards.chase.com`, `citi.com`) with no CAPTCHA blocks. Every annual fee across the 14 modeled products remains unchanged since `2026-09-23`, and no modeled product was retired or renamed. However, the audit identified and resolved several material data-quality and term discrepancies:

1. **Three broken/broad source URLs fixed (P0):**
   - `amex-platinum`: replaced empty 51-char category hub (`.../category/reward-points/`) with the live product page (`https://www.americanexpress.com/us/credit-cards/card/platinum/`).
   - `double-cash`: replaced generic Rewards hub (`.../rewards-credit-cards`, which did not list Double Cash terms) with `https://www.citi.com/credit-cards/citi-double-cash-credit-card`.
   - `strata`: replaced multi-tier family hub (`.../citi-strata-all-cards`) with `https://www.citi.com/credit-cards/citi-strata-credit-card`.
2. **One conservative scoring rate update verified from official Offer Details:**
   - `sapphire-preferred`: Chase's live Offer Details confirm **3x points at gas stations** (uncapped, non-portal, standing category, alongside EV charging and top-brand vacation homes). Updated conservative `reward_rates` from `{"dining": 3, "travel": 2, "other": 1}` to `{"dining": 3, "gas": 3, "travel": 2, "other": 1}`. Online-only grocery, select streaming, and 5x Chase Travel remain intentionally excluded from conservative scoring.
3. **One newly verified fee/perk change:**
   - `freedom-flex`: Live Chase page explicitly advertises **"NEW: No foreign transaction fees — Earn rewards worldwide with no foreign transaction fees."** Added to sourced `benefits`. (Freedom Unlimited's product page does *not* advertise no foreign transaction fees.)
4. **Major benefit/credit display gaps resolved (P0/P1):**
   - `amex-platinum`: replaced 5 generic lines with verified itemized credits (`$600` Hotel Credit noting the upcoming **January 1, 2027** two-night minimum for Fine Hotels + Resorts, `$400` Resy, `$300` Digital Entertainment, `$300` lululemon, `$219` CLEAR+, `$200` Uber Cash, `$120` Uber One, `$200` Airline Fee, `$200` Oura Ring, `$155` Walmart+, Global Entry/TSA PreCheck, 1,550+ Global Lounge Collection). **Confirmed Equinox and Saks credits are absent** from the live `2026-11-23` product page.
   - `sapphire-reserve`: replaced outdated 6-line summary with verified refreshed terms (`$795` fee / `$195` AU, `8x` Chase Travel incl. The Edit, `4x` direct flights/hotels, `3x` dining, `$300` travel credit, `$500` The Edit credit, `$300` Exclusive Tables dining, `$300` StubHub through `12/31/2027`, `$120` Global Entry/TSA/NEXUS, Sapphire + 1,300+ Priority Pass lounges, and dated partner offers).
   - `strata-elite`: expanded vague `"Hotel and lounge benefits"` to itemized verified credits (`$300` Hotel 2-night min, `$200` Splurge choice-of-2, `$200` Blacklane semi-annual, Priority Pass 1,500+, 4 Admirals Club passes, `$120` Global Entry/TSA, `6x` Citi Nights Fri–Sat 6 PM–6 AM ET, no FTF).
   - `double-cash`, `strata`, `venture-x`, `savorone`, `savor-for-students`, `amex-gold`, `quicksilver`, `sapphire-preferred`: updated display benefits to include verified portal tiers, superstore exclusions (Walmart/Target on Savor products), Fair Credit `$39` vs `$0` Savor variant clarity, and no-FTF notes.
5. **Official application link & offer re-publication findings:**
   - All 10 Chase, Amex, and Citi product URLs in `000011_official_application_links.sql` return HTTP `200` live product pages.
   - All 4 Capital One `marketableOfferId` links in `000011` (`48308`, `48321`, `47672`, `48137`) still return HTTP `200` (client-side SPA shell), **but** Capital One's live product pages on `2026-11-23` now embed rotated offer IDs (`42214` Savor Student, `42700` Quicksilver, `42144` SavorOne, `42623` Venture X).
   - Per `revocred-api/internal/store/affiliate.go`, inserting new `card_catalog_versions` rows in migration `000032` automatically hides superseded `000011` official offers until an operator revokes and republishes them against the new `conservative-2026-11-23-v1` version IDs (also required before `2026-12-25` expiry).
6. **Ongoing-value monetized credit rules (`revocred-api/internal/valuation/benefits.json`):**
   - All 15 reviewed monetized recurring benefit rules across Amex Gold, Amex Platinum, Venture X, Sapphire Reserve, and Citi Strata Elite match the live `2026-11-23` official issuer pages. No unverified prose parsing or new monetized assumptions were introduced.

---

## Summary Comparison Table (All 14 Active Recommendable Cards)

| Slug | Issuer / Name | Prior Version | Fee (Prior → 2026-11-23) | Conservative Scoring Rates (Prior → 2026-11-23) | Source URL Changed? | Summary of Audit Result |
|---|---|---|---|---|---|---|
| `amex-gold` | American Express / Amex Gold | `benefit-display-2026-10-13-v1` | `$325` → `$325` | `dining:4, flights:3, groceries:4, other:1` (unchanged) | No | Fee, rates, and 5 credits verified; added 5x AmexTravel hotels, 2x car rentals/cruises, and no-FTF to display benefits. |
| `amex-platinum` | American Express / Platinum | `conservative-2026-09-23-v1` | `$895` → `$895` | `other:1` (unchanged) | **Yes** (`category/reward-points/` → `card/platinum/`) | **P0 fix:** replaced empty hub URL and generic 5 lines with verified credit stack (incl. Jan 1, 2027 FHR 2-night min rule; Equinox/Saks absent). |
| `quicksilver` | Capital One / Quicksilver | `benefit-display-2026-10-26-v1` | `$0` → `$0` | `other:1.5` (unchanged) | No | Base excellent-credit `$0` / `1.5%` / no-FTF verified; added 5% portal note. Apply offer ID rotated (`48321` → `42700`). |
| `savor-for-students` | Capital One / Savor for Students | `conservative-2026-09-23-v1` | `$0` → `$0` | `dining:3, entertainment:3, groceries:3, other:1` (unchanged) | No | Fee and 3%/1% rates verified; added Walmart/Target exclusion, no-FTF, no-credit-score-required, and 8%/5% portal notes. Apply offer ID rotated (`48308` → `42214`). |
| `savorone` | Capital One / SavorOne | `conservative-2026-09-23-v1` | `$39` → `$39` | `dining:3, entertainment:3, groceries:3, other:1` (unchanged) | No | Fair Credit `$39` variant verified (separate `$0` Savor Rewards exists for Excellent Credit); added Walmart/Target exclusion, no-FTF, and 5%/8% portal notes. Apply offer ID rotated (`47672` → `42144`). |
| `venture-x` | Capital One / Venture X | `conservative-2026-09-23-v1` | `$395` → `$395` | `other:2` (unchanged) | No | `$395`, `2x`, `10x/5x` portal, `$300` travel credit, and `10k` anniversary miles verified; added lounges, Global Entry/TSA, `$800` cell protection, no-FTF, and transfer partners to display benefits. Apply offer ID rotated (`48137` → `42623`). |
| `freedom-flex` | Chase / Freedom Flex | `conservative-2026-09-23-v1` | `$0` → `$0` | `dining:3, drugstores:3, other:1` (unchanged) | No | **New verified term:** Chase now advertises **no foreign transaction fees**; fee and earning tiers unchanged. |
| `freedom-rise` | Chase / Freedom Rise | `conservative-2026-09-23-v1` | `$0` → `$0` | `other:1.5` (unchanged) | No | Unchanged (`$0`, `1.5%` all purchases); noted `$250` Chase deposit approval-odds language in display benefits. |
| `freedom-unlimited` | Chase / Freedom Unlimited | `conservative-2026-09-23-v1` | `$0` → `$0` | `dining:3, drugstores:3, other:1.5` (unchanged) | No | Unchanged (`$0`, `5%` Chase Travel, `3%` dining/drugstores, `1.5%` other). Does not advertise no-FTF. |
| `sapphire-preferred` | Chase / Sapphire Preferred | `benefit-display-2026-10-13-v1` | `$95` → `$95` | `dining:3, travel:2, other:1` → **`dining:3, gas:3, travel:2, other:1`** | No | **Scoring rate added:** verified standing `3x` gas stations in live Offer Details. `$95` fee, `$100` hotel credit, and `$120` Global Entry/TSA/NEXUS credit confirmed. |
| `sapphire-reserve` | Chase / Sapphire Reserve | `conservative-2026-09-23-v1` | `$795` → `$795` | `dining:3, flights:4, hotels:4, other:1` (unchanged) | No | **P0 fix:** replaced outdated 6-line summary with verified refreshed benefits (`$500` The Edit, `$300` dining, `$300` StubHub, `$120` Global Entry/TSA/NEXUS, lounges, dated promos). |
| `double-cash` | Citi / Double Cash | `conservative-2026-09-23-v1` | `$0` → `$0`* | `other:2` (unchanged) | **Yes** (`rewards-credit-cards` → `citi-double-cash-credit-card`) | **P0 fix:** replaced broad hub URL; added 5% total Citi Travel portal tier and ThankYou Points mechanics. *Static HTML omits JS-rendered numeric fee/APR slots; no annual fee confirmed on-page & via Citi disclosures. |
| `strata` | Citi / Strata | `conservative-2026-09-23-v1` | `$0` → `$0` | `dining:2, gas:3, groceries:3, other:1` (unchanged) | **Yes** (`citi-strata-all-cards` → `citi-strata-credit-card`) | **P0 fix:** replaced multi-tier hub URL with `$0` base Strata page; added 5x cititravel.com and exact Self-Select options. |
| `strata-elite` | Citi / Strata Elite | `conservative-2026-09-23-v1` | `$595` → `$595`* | `dining:3, other:1.5` (unchanged) | No | **P0 fix:** itemized verified credits (`$300` hotel, `$200` Splurge, `$200` Blacklane, Priority Pass, 4 Admirals passes, `$120` Global Entry/TSA, `6x` Citi Nights, no FTF). *Static HTML omits JS-rendered numeric fee slot; `$595` corroborated on-page via Citigold `$595` relationship credit & Citi disclosures. |

---

## Per-Card Evidence & Provenance (`2026-11-23`)

1. **Amex Gold (`amex-gold`)**
   - Source: `https://www.americanexpress.com/us/credit-cards/card/gold-card/` (HTTP 200, `2026-11-23T07:24:16Z`, SHA-256 `e290d3ea3658...`, 18,131 text chars).
   - Verbatim evidence: `$325` Basic Card annual fee; `4X` at Restaurants Worldwide (up to `$50,000`/calendar year, then `1X`); `4X` at U.S. supermarkets (up to `$25,000`/calendar year, then `1X`); `5X` Prepaid Hotels booked through AmexTravel.com or Amex Travel App; `3X` Flights booked via Amex Travel or directly with airlines; `2X` prepaid car rentals and cruises via AmexTravel.com; `$120` Dining Credit (`$10`/mo at Grubhub/Seamless, Buffalo Wild Wings, Five Guys, The Cheesecake Factory, Wonder; enrollment required); `$120` Uber Cash (`$10`/mo); `$100` Resy Credit (`$50` Jan–Jun + `$50` Jul–Dec; enrollment required); `$84` Dunkin' Credit (`$7`/mo; enrollment required); `$100` Hotel Collection credit (2-night min); no foreign transaction fees.

2. **Amex Platinum (`amex-platinum`)**
   - Old stored source confirmed broken: `https://www.americanexpress.com/us/credit-cards/category/reward-points/` (HTTP 200, SHA-256 `480c3e354122...`, **51 text chars** — page title only, zero product terms).
   - Verified product source: `https://www.americanexpress.com/us/credit-cards/card/platinum/` (HTTP 200, `2026-11-23T07:24:16Z`, SHA-256 `da902a031ac1...`, 39,916 text chars).
   - Verbatim evidence: `$895` Basic Card annual fee (`$195` per Additional Platinum Card); `5X` Points on Flights booked directly with airlines or via Amex Travel (up to `$500,000`/calendar year); `5X` Points on Prepaid Hotels via Amex Travel; `1X` other; `$600` Hotel Credit (`$300` semi-annually on prepaid FHR or THC via Amex Travel; *"The Hotel Collection requires a minimum two-night stay. Effective January 1, 2027, Fine Hotels + Resorts bookings will require a minimum two-night stay to be eligible for the $600 Hotel Credit."*); `$400` Resy Credit (`$100`/quarter, enrollment required); `$300` Digital Entertainment (`$25`/month, enrollment required); `$300` lululemon (`$75`/quarter at U.S. stores excl. outlets & lululemon.com, enrollment required); `$219` CLEAR+ Credit; `$200` Uber Cash (`$15`/mo + `$20` Dec); `$120` Uber One Credit; `$200` Airline Fee Credit; `$200` Oura Ring Credit; `$155` Walmart+ Credit (`$12.95`/mo + taxes); Global Entry / TSA PreCheck fee credit; Global Lounge Collection (1,550+ lounges, 10 Delta Sky Club visits when flying Delta, Priority Pass with enrollment); no foreign transaction fees. Equinox and Saks credits had `0` matches on the live `2026-11-23` page.

3. **Capital One Quicksilver (`quicksilver`)**
   - Source: `https://www.capitalone.com/credit-cards/quicksilver/` (HTTP 200, `2026-11-23T07:24:17Z`, SHA-256 `ffb80fbf7ee1...`, 7,011 text chars).
   - Verbatim evidence: `Excellent credit`; `$0 annual fee`; `"Earn unlimited cash back with no annual, hidden or foreign transaction fees."`; `"Earn unlimited 1.5% cash back on every purchase, every day."`; `"Earn 5% cash back with Capital One Travel and 5% cash back with Capital One Entertainment."` Embedded apply offer ID: `marketableOfferId=42700` (vs `48321` in `000011`).

4. **Capital One Savor for Students (`savor-for-students`)**
   - Source: `https://www.capitalone.com/credit-cards/savor-student/` (HTTP 200, `2026-11-23T07:24:17Z`, SHA-256 `6cbff55d3c80...`, 9,384 text chars).
   - Verbatim evidence: `$0 annual fee`; `"Plus, there are no hidden or foreign transaction fees."`; `"No credit score is required to apply."`; `"Earn unlimited 3% cash back at grocery stores, on dining, entertainment and popular streaming services, plus 1% cash back on all other purchases."`; grocery excludes superstores like Walmart and Target; `8%` Capital One Entertainment; `5%` Capital One Travel. Embedded apply offer ID: `marketableOfferId=42214` (vs `48308` in `000011`).

5. **Capital One SavorOne (`savorone`)**
   - Source: `https://www.capitalone.com/credit-cards/savorone/` (HTTP 200, `2026-11-23T07:24:18Z`, SHA-256 `4bda8cb0e2b8...`, 8,722 text chars).
   - Companion comparison check: `https://www.capitalone.com/credit-cards/savor/` (HTTP 200, SHA-256 `1d807222c8de...`) confirms Capital One continues to offer a separate `$0` annual fee **Savor Rewards** product for `Excellent credit`.
   - Verbatim evidence (`savorone`): `Fair credit`; `$39 annual fee`; `"Plus, there are no hidden or foreign transaction fees."`; `"Earn unlimited 3% cash back at grocery stores, on dining, entertainment and popular streaming services, plus 1% cash back on all other purchases."` (excluding superstores like Walmart and Target); `"Earn 5% cash back with Capital One Travel and 8% cash back with Capital One Entertainment."` Embedded apply offer ID: `marketableOfferId=42144` (vs `47672` in `000011`).

6. **Capital One Venture X (`venture-x`)**
   - Source: `https://www.capitalone.com/credit-cards/venture-x/` (HTTP 200, `2026-11-23T07:24:18Z`, SHA-256 `a272b508f2c3...`, 11,898 text chars).
   - Verbatim evidence: `Annual Fee $395`; `Credit Level Excellent`; `10X Miles on hotels & rental cars booked through Capital One Travel`; `5X Miles on flights and vacation rentals booked through Capital One Travel`; `5X miles on Capital One Entertainment`; `2X Miles on all other purchases, every day`; embedded HTML JSON confirms `"$300 annual Capital One Travel credit"`, `"10,000 bonus miles after your anniversary each year, starting with your first anniversary"`, and `"Global Entry or TSA PreCheck"` statement credit every 4 years; Capital One Lounge and Landing + `1,300+` Priority Pass lounges (primary cardholders); up to `$800` Cell Phone Protection; no foreign transaction fees; transfer miles to `15+` travel loyalty programs. Embedded apply offer ID: `marketableOfferId=42623` (vs `48137` in `000011`).

7. **Chase Freedom Flex (`freedom-flex`)**
   - Source: `https://creditcards.chase.com/cash-back-credit-cards/freedom/flex` (HTTP 200, `2026-11-23T07:24:18Z`, SHA-256 `6f00b6151fbf...`, 36,569 text chars).
   - Verbatim evidence: `$0 annual fee`; `"Earn 5% cash back on up to $1,500 in rotating categories each quarter you activate. Plus, earn 5% back on travel purchased through Chase Travel, 3% on dining including takeout and drugstores, and 1% on all other purchases."`; **`"Now enjoy all this with no foreign transaction fee."`** / **`"NEW: No foreign transaction fees — Earn rewards worldwide with no foreign transaction fees."`**

8. **Chase Freedom Rise (`freedom-rise`)**
   - Source: `https://creditcards.chase.com/cash-back-credit-cards/freedom/rise` (HTTP 200, `2026-11-23T07:24:19Z`, SHA-256 `bd4adb11db99...`, 29,185 text chars).
   - Verbatim evidence: `$0 Annual Fee`; `"Best for: New to Credit and Students"`; `"Establish credit and earn 1.5% cash back on all purchases"`; `"Having at least $250 in Chase checking or savings accounts increases your chances of being approved."`

9. **Chase Freedom Unlimited (`freedom-unlimited`)**
   - Source: `https://creditcards.chase.com/cash-back-credit-cards/freedom/unlimited` (HTTP 200, `2026-11-23T07:24:20Z`, SHA-256 `7b49971efdd0...`, 33,437 text chars).
   - Verbatim evidence: `$0 annual fee`; `"Earn 3% on dining at restaurants, including takeout and eligible delivery services."`; `"Earn 3% on drugstore purchases."`; `"Earn 5% on travel purchased through Chase Travel."`; `"Earn 1.5% on all other purchases."` Does *not* list no foreign transaction fees in product features.

10. **Chase Sapphire Preferred (`sapphire-preferred`)**
    - Source: `https://creditcards.chase.com/rewards-credit-cards/sapphire/preferred` (HTTP 200, `2026-11-23T07:24:21Z`, SHA-256 `7658f595a866...`, 24,433 text chars).
    - Verbatim evidence: `$95 annual fee`; `5x points on Chase Travel`; `3x points on dining`; **`NEW: 3x points on gas stations, EV charging, and vacation homes at top brands`** (Offer Details: *"You'll earn 3 points for each $1 spent on purchases in the following rewards categories: vacation homes at top brands (...); gas stations; electric vehicle charging; dining at restaurants including takeout and eligible delivery services; top streaming services (...); online grocery (excluding Target, Walmart and wholesale clubs)."*); `2x points on all other travel`; `1X points on all other purchases`; `$100 Chase Travel Hotel Credit` each account anniversary year; `Global Entry or TSA PreCheck or NEXUS Application Fee credit` up to `$120` every four years; no foreign transaction fees; primary rental car & trip protections; time-bound Apple TV (activate by `12/31/2026`), DashPass (activate by `12/31/2029`), Lyft 5x (through `9/30/2027`), Peloton 5x (through `12/31/2027`).

11. **Chase Sapphire Reserve (`sapphire-reserve`)**
    - Source: `https://creditcards.chase.com/rewards-credit-cards/sapphire/reserve` (HTTP 200, `2026-11-23T07:24:31Z`, SHA-256 `28708b3bd9a9...`, 62,951 text chars).
    - Verbatim evidence: `$795 annual fee; $195 for each authorized user`; `8x points on all purchases through Chase Travel, including The Edit`; `4x points on flights booked direct`; `4x points on hotels booked direct`; `3x points on dining worldwide`; `1x points on all other purchases`; `$300 annual travel credit` (credited purchases do not earn points); `$500 credit for stays with The Edit` (`$250` per prepaid booking, 2-night minimum, credited purchases do not earn points); `$300 dining credit` (`$150` Jan–Jun + `$150` Jul–Dec at Sapphire Reserve Exclusive Tables on OpenTable); `$300 in StubHub credits` (`$150` Jan–Jun + `$150` Jul–Dec through `12/31/2027`, activation required); `$120` Global Entry/TSA PreCheck/NEXUS credit every 4 years; Chase Sapphire Lounges by The Club + `1,300+` Priority Pass lounges with up to 2 guests; time-bound Apple TV & Apple Music (`$324`/yr, activate by `6/22/2027`), Lyft (`$10`/mo + `5x` through `9/30/2027`), Peloton (`$10`/mo + `10x` through `12/31/2027`), DashPass (`$120`/yr, activate by `12/31/2029`).

12. **Citi Double Cash (`double-cash`)**
    - Old stored source confirmed broad hub: `https://www.citi.com/credit-cards/rewards-credit-cards` (HTTP 200, SHA-256 `5ec58ebc6b06...`, lists general Citi rewards cards without Double Cash product terms).
    - Verified product source: `https://www.citi.com/credit-cards/citi-double-cash-credit-card` (HTTP 200, `2026-11-23T07:24:34Z`, SHA-256 `37250c4d45a6...`, 12,300 text chars).
    - Verbatim evidence: `"Earn unlimited 1% cash back when you buy, plus an additional 1% as you pay, on every purchase."`; `"Plus, earn a total of 5% on select travel ... an additional 3% cash back on hotels, car rentals, and attractions booked through the Citi Travel portal."`; `"Cash back is earned in the form of ThankYou Points"`; `"No Authorized User fee"`; `"no annual fee"` in FAQ text (numeric fee/APR widgets load client-side; corroborated via official Citi disclosures).

13. **Citi Strata (`strata`)**
    - Old stored source confirmed multi-tier family hub: `https://www.citi.com/credit-cards/citi-strata-all-cards` (HTTP 200, SHA-256 `1755db3b9c89...`, mixes Strata, Strata Premier, and Strata Elite).
    - Verified product source: `https://www.citi.com/credit-cards/citi-strata-credit-card` (HTTP 200, `2026-11-23T07:24:40Z`, SHA-256 `dc70e6193d25...`, 11,414 text chars).
    - Verbatim evidence: `No Annual Fee` / `$0 Annual fee`; `No Authorized User Fee`; `5x` Hotels, Car Rentals, and Attractions booked on `cititravel.com`; `3x` Supermarkets; `3x` Gas & EV Charging Stations and Select Transit; `3x` eligible Self-Select Category (`Fitness Clubs, Select Streaming Services, Live Entertainment, Cosmetic Stores/Barber Shops/Hair Salons, or Pet Supply Stores`); `2x` Restaurants; `1x` All Other Purchases; transferable ThankYou Points.

14. **Citi Strata Elite (`strata-elite`)**
    - Source: `https://www.citi.com/credit-cards/citi-strata-elite-credit-card` (HTTP 200, `2026-11-23T07:24:44Z`, SHA-256 `b8258d328ee8...`, 12,124 text chars).
    - Verbatim evidence: `12x` Hotels, Car Rentals, and Attractions on `cititravel.com`; `6x` Air Travel on `cititravel.com`; `6x` Restaurants on Citi Nights (Friday and Saturday 6 PM–6 AM ET); `3x` Restaurants any other time; `1.5x` All Other Purchases; `Up to $300 Annual Hotel Benefit` (2-night min via `cititravel.com`); `Up to $200 Splurge Credit` (choice of up to 2: `1stDibs, American Airlines, Best Buy, Future Personal Training, Live Nation`); `Up to $200 Annual Blacklane Credit` (`$100` Jan–Jun + `$100` Jul–Dec); `Priority Pass Select membership` (`1,500+` lounges, valued at `$469`); `4 Admirals Club Citi Strata Elite Passes` per calendar year; `Up to $120 Global Entry or TSA PreCheck` credit every 4 years; `no foreign transaction fees`; transferable ThankYou Points; Citigold Private Client text explicitly cites `$595` first-year relationship credit (corroborating `$595` annual fee; numeric fee/APR slots render client-side).

---

## Addendum: 15th `issuer_snapshot` Database Row (`discover-it-cash-back`)

Migration `000026_discover_it_cash_back.sql` (`2026-10-28`) added a 15th active `issuer_snapshot` row (`discover-it-cash-back`, UUID `20000000-0000-4000-8000-000000000021`), which is **not** one of the 14 playbook strategy cards and has no `000011` official offer row. For completeness, its live Discover page was also checked on `2026-11-23T07:24:45Z`:
- Requested URL `https://www.discover.com/credit-cards/cash-back/it-card.html` 301-redirected to `https://www.discover.com/credit-cards/cash-back/it-card/` (HTTP 200, SHA-256 `4c05b7a7a625...`, 10,725 text chars).
- Verified terms unchanged: `No annual fee` (`$0`), `5%` rotating quarterly categories up to the quarterly maximum when activated, `1%` all other purchases, Unlimited Cashback Match first year (welcome bonus, excluded from scoring). No migration update was required.

---

## Items Requiring Manual / Operator Verification (Not Automated)

1. **Citi client-side Pricing & Terms modals (`double-cash`, `strata-elite`):** Citi's Angular frontend injects numeric annual-fee and APR values via client-side XHR rather than server-rendered HTML. While `$0` (`double-cash`) and `$595` (`strata-elite`) are corroborated by on-page prose (`"no annual fee"` and `"$595 first year banking relationship credit"`) and official `citi.com` disclosures, an operator should visually confirm the live Pricing & Information modal in a browser before public launch.
2. **Capital One `marketableOfferId` application links (`quicksilver`, `savor-for-students`, `savorone`, `venture-x`):** All four `000011` URLs return HTTP `200` as an 86 KB Angular SPA shell, so automated HTTP fetch cannot confirm whether the older `marketableOfferId` parameters (`48308`, `48321`, `47672`, `48137`) still resolve to the intended cards inside the browser app. Live product pages now embed `42214`, `42700`, `42144`, and `42623`. Before `2026-12-25`, verify in a browser and consider republishing official offers using the stable product page URLs (`/credit-cards/...`) instead of rotating offer IDs.
3. **Re-publishing `revocred.affiliate_offers` after migration `000032`:** By design (`revocred-api/internal/store/affiliate.go`), publishing new `card_catalog_versions` (`conservative-2026-11-23-v1`) hides the superseded `000011` official offers until an operator revokes them and republishes official links against the new version IDs via `go run ./cmd/offers -publish`.
4. **Guide to Benefits PDFs (all 14 cards):** Marketing product pages confirm headline travel/shopping protection availability, but exact coverage dollar caps, exclusions, and secondary-vs-primary conditions require reviewing each issuer's PDF Guide to Benefits.
5. **Upcoming Amex Platinum FHR rule change (`2027-01-01`):** Fine Hotels + Resorts bookings will require a two-night minimum stay for the `$600` Hotel Credit starting January 1, 2027 (already disclosed in the `000032` display benefits).
