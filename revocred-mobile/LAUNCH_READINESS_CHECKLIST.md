# Revocred Mobile Launch Readiness Checklist

Use this checklist for every release candidate build before App Store submission.

## 1) Build Acceptance (TestFlight)

- [ ] Latest build installed on iPhone and iPad from TestFlight
- [ ] Build version + build number match expected release candidate
- [ ] App opens from cold start without crash
- [ ] Sign in / sign up / sign out flows complete successfully

## 2) Core Product Regression (All 5 Tabs)

### Home
- [ ] Wallet cards are compact in default (unflipped) state
- [ ] Full-card flip works (entire card area flips, not partial element)
- [ ] Back-side CTA shows exact copy:
  - `ASK REVO`
  - `Ask REVO about <card name> card`
- [ ] Tap on any Ask REVO CTA always routes to REVO screen

### Cards
- [ ] Same compact default wallet-card size as Home
- [ ] Expanded state remains readable and not clipped
- [ ] Multiplier pill text is fully visible (e.g., `4x`, `2x`)
- [ ] Back-side `Tap to return` hint remains readable and unobstructed

### Strategy
- [ ] Search only matches on `id`, `issuer`, `brand`, `name`
- [ ] `chase` returns Chase cards only (no Capital One leakage)
- [ ] `citi` returns expected Citi card count from catalog
- [ ] `discover` does not return unrelated cards
- [ ] Search card visuals use simplified card art (no decorative bubbles/orbs)
- [ ] Tapping a search card opens details modal correctly

### REVO
- [ ] Prompt chips submit successfully
- [ ] Sending a custom prompt works
- [ ] Thinking/loading state appears while waiting
- [ ] Failure/timeout fallback message appears when provider fails

### Profile
- [ ] No `Reset Demo Data` action present
- [ ] Legal disclaimer and support contact are visible
- [ ] Analytics refresh works without breaking layout

## 3) Reliability + UX Quality Gates

- [ ] No clipped text on primary cards/buttons
- [ ] Empty states are present and understandable
- [ ] Loading states are visible on slow network
- [ ] No dead-end screens (every empty state suggests next action)
- [ ] App remains responsive after backgrounding and reopening

## 4) Compliance + Store Readiness

- [ ] Privacy Policy URL finalized and accessible
- [ ] Terms of Service URL finalized and accessible
- [ ] In-app disclaimer aligns with App Store metadata language
- [ ] Support email confirmed and monitored
- [ ] Subscription/IAP copy (if any) is accurate and not misleading

## 5) App Store Metadata Readiness

- [ ] Final app description
- [ ] Keywords + subtitle
- [ ] Category selection
- [ ] Launch screenshots (iPhone + iPad)
- [ ] App preview video (optional)

## 6) Go/No-Go Rules

Ship only when:
- [ ] No P0 bugs open (crash, auth break, blocked navigation)
- [ ] No P1 UX blockers open (major clipping, missing CTA actions, broken search intent)
- [ ] TestFlight smoke test passes on at least one iPhone and one iPad

If any go/no-go item fails, cut a new build and re-run this checklist end-to-end.
