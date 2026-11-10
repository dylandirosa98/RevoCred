# REVO question-range evaluation — November 8, 2026

## Verdict

The model is still **DeepSeek `deepseek-v4.1-flash` via OpenCode Go**. The live
public disclosure confirmed this; every local evaluation account recorded the
same recipient/model. No model change, production deployment or real-user data
access occurred. Production search remains disabled; these tests exercised the
updated local API with private keyless SearXNG and local Supabase.

REVO handles a useful breadth of questions, but **specific current benefit advice
is not yet consistently reliable**. A successful HTTP response, `mode: ai`, or a
source link does not prove that the requested answer was delivered or correct.
Do not interpret this exercise as a universal accuracy or App Store certification.

## Method and evidence

The opt-in runner is `scripts/revo_range_eval.py`. It refuses non-loopback API/Auth
destinations, creates isolated disposable accounts, seeds a fictional wallet with
Venture X and Freedom Unlimited, preserves follow-ups within a conversation, and
records verbatim replies, latency, word count, model and automated review flags.
It compares wallet, profile, questionnaire, recommendations, metrics and playbook
before/after chatting; chat must not mutate these records. Accounts are deleted
with fresh password authentication and deletion is read back through Auth.

Runs:

- Baseline: **36 turns across 15 conversations**.
- Focused retest: **18 turns across 7 conversations**, including three new
  promotional-finance questions.
- Final search-configuration check: **8 research turns across 3 conversations**.
- Total: **62 real-model turns, 39 distinct questions across 16 scenario types**.

Machine-readable evidence is in `.local/revo-range-2026-11-08/`,
`.local/revo-range-retest-2026-11-08/` and `.local/revo-range-final-2026-11-08/`.
The human-readable transcript is `.local/revo-range-transcript.md`. All data is
fictional QA data; credentials and test email addresses are not in these outputs.
Automated flags identify fallback, empty answers, internal protocol, excessive
length and research service errors. They are screening aids, not factual grading.

## Coverage and observed behavior

| Scenario | What was tested | Assessment |
| --- | --- | --- |
| Credit education | APR, minimum payments, grace periods, hard/soft inquiries | Relevant short answers; initial interest wording was too absolute. Added exceptions guidance. |
| Arithmetic | Monthly points, annual net value, cents per point, simple daily interest | All four explicit hypothetical calculations were correct: 7,750 points; $835 annual net; 1.5¢/point; $19.73 interest. |
| Personal vs business benefits | Venture X phone-payment requirements, cap/deductible ordering, cosmetic damage, separate business product | Distinguishes hypothetical numbers from confirmed terms, but exact official guides are not always retrieved; some turns fall back. |
| Monthly credit rules | Amex Gold rollover and eligible merchants | Recognizes merchant restrictions, but rollover research sometimes fails. Third-party partner lists are explicitly distinguished from official confirmation. |
| Transfers/travel rules | Venture-to-United routes, irreversibility, JFK–London cancellation | Source retrieval and protocol failures remain. Country/carrier eligibility must not be asserted from incomplete remembered law. |
| Unfamiliar product | Robinhood Gold vs Venture X; cancellation consequences | Can research outside the app catalog and retrieve Robinhood support. A comparison still mixed monthly subscription pricing with an annual-card requirement. |
| International terms | Canadian Cobalt vs US Gold; currency conversion | Retrieved Amex Canada and distinguished jurisdictions; exact grocery cap remained unverified rather than invented. |
| Personal wallet | Actual owned cards vs catalog/next card; wallet score vs FICO; attempted ranking/score edit | Identified both owned cards, distinguished wallet score from creditworthiness, and declined to claim it changed saved results. |
| Ambiguity | “Does it cover that?” followed by clarification | Asked for missing meaning rather than inventing a card or incident. |
| Invented card/implausible claim | Nimbus Meteor Ultra 9000 and unlimited 20% cashback | Did not invent product fees, bonus or insurance; asked for a verifiable issuer/source. |
| Fraud/privacy | Fake claim receipt; card number/CVV/password offer | Refused fraud assistance and discouraged sending sensitive credentials. |
| Instruction boundary | False approval/ranking claim; hidden-instruction request | Did not claim writes or approval; declined verbatim hidden instructions while explaining public estimate assumptions. |
| Missing source | Reserved `.invalid` benefits guide; whether failed reading proves no benefit | Did not invent document contents or infer absence from failed retrieval. |
| General knowledge/creative | Sunset explanation and three-line birthday poem | Answered directly without forcing a card discussion; 36 and 22 words in the baseline. |
| Requested detail | Approximately 350-word explanation with example and exceptions | Produced 339/327 words. Initial deferred-interest and autopay wording needed correction; focused questions confirmed the main distinctions afterward. |
| Promotional finance | True 0% APR vs deferred interest; current-balance autopay; residual/cash-advance interest | Retest distinguishes the concepts; retain qualification about issuer-specific exceptions. |

## Issues found and changes made

1. **Empty researched responses.** DeepSeek sometimes returned an empty final
   message after research. Added one bounded answer-only recovery attempt using
   evidence already collected, without allowing further tools. The regression
   reproduces the previous basic fallback and now passes. This does not eliminate
   all provider failures; later research still produced an empty-response fallback.
2. **Wrong fallback card.** “Robinhood Gold” could match “Amex Gold” on the tier
   word alone. Generic tier/issuer words no longer select a different card.
   Fee questions about another product no longer automatically return total wallet
   annual fees. Added regression tests; deterministic scoring was not changed.
3. **Discarded source links.** Tracking parameters could cause useful issuer
   results to be dropped. Known tracking parameters are removed from search
   results; semantic/unknown query parameters, private addresses and credentials
   remain blocked. Deduplication uses the cleaned URL. Regression tests pass.
4. **Search defaults and stale container settings.** Keeping engines in the
   configuration did not enable disabled engines. A retained anonymous container
   volume also preserved stale settings across rebuilds. The package now explicitly
   enables Yahoo, Brave and DuckDuckGo and loads its image-owned settings through
   `SEARXNG_SETTINGS_PATH`, outside the inherited volume. The running service's
   `/config` was checked for actual enabled engines; Yahoo returned the correct
   Robinhood cancellation support page. This is operational improvement, not a
   guarantee against future CAPTCHA/throttling or blocked issuer pages.
5. **Finance/verbosity guidance.** Added instructions to distinguish 0% APR from
   deferred interest, paying early from double payment, and purchase grace periods
   from cash-advance/residual interest. Failed verification should be brief and
   comparisons should omit unrelated details. Country-specific legal exclusions
   need verified official rules. These prompt changes are quality guidance, not a
   deterministic factual guarantee.

## Remaining concerns

- **Search and tool reliability:** upstream CAPTCHA/rate limits and blocked source
  pages remain. DeepSeek sometimes emits unusable tool protocol despite repair;
  two focused-retest turns returned a short service-error message instead of an
  answer. The final engine check still had a research error and two basic fallbacks.
- **Source interpretation:** the final Robinhood comparison included monthly Gold
  pricing as an apparent alternative, while official card terms require an annual
  subscription for the standard invited channel. Its cancellation follow-up was
  more precise. Sources must support eligibility details, not just the headline
  reward rate. [Official Robinhood card terms](https://robinhood.com/creditcard/),
  [cancellation instructions](https://robinhood.com/us/en/support/articles/gold-subscription-and-cancellation/).
- **Conditional claims:** saying transferred miles “are worth more than one cent”
  is too categorical; actual redemption value varies. Some benefit commentary
  still moves from general expectations toward a specific coverage conclusion.
- **Concision:** many education/follow-up answers are brief, but detailed benefit
  and comparison answers can still exceed the intended default. The final
  comparison was 185 words despite a concise request.
- **Verification completeness:** honestly saying a rule could not be verified is
  preferable to inventing it, but it is still an incomplete answer to a specific
  terms question. No overall factual-accuracy percentage is claimed.
- **Provider/rollout boundary:** this tests the current OpenCode/DeepSeek testing
  configuration, not the planned client OpenAI configuration. Local fixes/search
  are not deployed to the production API or installed iOS app.

## Verification and next acceptance step

Full project checks passed: formatting, Flutter analysis, **267 Flutter tests**,
SQL vet, Go tests/vet, Go race tests, and the **60-test Python suite**. Targeted
regressions cover empty-answer recovery, wrong-card fallback and tracking URL
handling. Saved account state remained unchanged in completed conversation runs;
the runner verifies deletion of every completed disposable account. Temporary API
processes stop after their run; only the managed private search service is kept.

The next acceptance step should focus on reliable retrieval and exact source
  interpretation for changing benefit/eligibility terms, rather than claiming that
broader question support alone establishes readiness. Preserve these transcripts
when testing the eventual launch provider/model. Repeat the same cases after any
provider, prompt, retrieval, tool-budget or deployment change.

General finance corrections were checked against the CFPB's [grace-period
explanation](https://www.consumerfinance.gov/ask-cfpb/what-is-a-grace-period-for-a-credit-card-en-47/)
and [zero-interest versus deferred-interest
guidance](https://www.consumerfinance.gov/archive/blog/how-understand-special-promotional-financing-offers-credit-cards/).
