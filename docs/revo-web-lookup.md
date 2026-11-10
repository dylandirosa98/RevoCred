# REVO model-directed public research

REVO sends the user's current message, up to eight recent chat messages and the
server snapshot (profile, wallet, spending, deterministic results and catalog)
to the configured Chat Completions provider. Both OpenAI and OpenCode use the
same tool loop. The model decides whether research is useful: there is no
known-card, keyword or issuer-domain search gate. Wallet explanations and
general education can be answered without external search.

REVO answers general knowledge, budgeting, credit education, travel, points,
benefits and unfamiliar products. The default is 40–100 words, usually one to
three sentences for a simple follow-up; explicit requests for detail can be
longer. Search is for changing or uncertain facts, not every conversational turn.

## Tools and boundaries

- `web_search(query)` sends a minimal standalone public-topic query to the
  configured search service. Keyless mode uses private SearXNG, which queries
  its configured upstream engines. Brave Search remains optional with a key.
  Search snippets include source URLs and a read timestamp.
- `read_public_page(url, topic)` reads a public HTTPS page and returns relevant
  text windows, source URL and timestamp. Prefer official issuer terms through
  the prompt, not a domain allowlist. Non-issuer references are allowed.
- PDF text extraction is optional: `pdftotext` must be installed on the server.
  Scans, oversized files, bot challenges and unsupported media may be unreadable;
  tools report errors instead of pretending to have read them.
- The model receives tool errors and must honestly state any evidence gap.
  Web content is untrusted reference material, never an instruction source.
- Up to four tool-bearing model rounds, six tool invocations and one final
  response. Model requests share the original overall deadline; each web call
  has an eight-second maximum. A failed model connection is retried once only
  when the deadline permits; HTTP/provider errors still fall back normally.
  Response bodies and excerpts are bounded.
- Public-page fetching rejects non-HTTPS, nonstandard ports, credentials,
  query strings and fragments. Every redirect is revalidated (three-hop limit).
  DNS resolution rejects non-public addresses and the socket connects to the
  validated IP, preventing rebinding; no environment proxy or AI auth is used.

## Privacy and consent

The AI is instructed to resolve follow-ups privately and send only public
product/topic words to tools, never profile/history dumps, personal situations,
spending, credit bands, names or identifiers. Server checks reject clear sensitive
identifiers (emails, long account/card/phone numbers, SSNs, UUIDs, credentials,
dollar amounts and the member's first name). This is defense in depth, not a
claim that arbitrary natural-language PII can be detected perfectly. Do not
include sensitive information in chat. Source URLs cannot carry query parameters.

The versioned sharing notice (`sharingDataUse`, `revo-sharing-v4`) describes
the configured AI recipient and search service/public-page research. Its digest
changes with recipient/model/wording or search-service URL, requiring renewed
agreement. Account permission persists until revoked or changed; guest permission
lasts for the app session. Opening Privacy & Terms does not grant permission.
The deterministic provider performs no network research.

## Keyless search setup

Run the private local service (binds only to loopback):

```sh
make search-up
```

Configure the **API server**, never Flutter, then restart it:

```dotenv
SEARCH_PROVIDER=searxng
SEARCH_BASE_URL=http://127.0.0.1:8096/search
SEARCH_API_KEY=
```

No third-party search key is required. The pinned image generates its own
internal cookie-signing secret at startup. Upstream engines can still rate-limit,
challenge or fail; partial results remain usable, and empty/unavailable results
produce a tool error instead of fabricated current facts.

For Railway, deploy `deploy/search` as a private service named `search` using its
Dockerfile, container port 8080, then set shared `SEARCH_PROVIDER=searxng` and
`SEARCH_BASE_URL=http://search.railway.internal:8080/search`. Do not expose a public
search domain. Deploy the updated API to consume these settings. Hosting still
uses resources; keyless does not mean the hosted container has no cost. Existing
production remains unchanged until deployment. For Docker API/search on a shared
network use `http://search:8080/search`. Arbitrary public plain-HTTP search URLs,
credentials, query strings and fragments are rejected in provider configuration.

The [SearXNG API](https://docs.searxng.org/dev/search_api.html) requires JSON output
to be enabled; this repository's private configuration enables it. Public shared
instances often disable JSON and are not used as an automatic fallback.

## App decisions remain read-only

Chat can explain or compare unfamiliar alternatives without changing the app's
official recommendation. Scores, ranking, purchase guide, strategy and chart
values remain server-owned deterministic calculations. No write tool is exposed.
Current source terms must not be confused with modeled estimates.

## Verification

`make check` runs all existing app checks plus chat tests for the actual
multi-request tool exchange, follow-up context, unfamiliar cards, no-search
wallet explanations, search outages, identifier rejection and public URL/IP
restrictions. `python3 scripts/revo_venturex_test.py` uses a disposable local
account, persists the real verbatim responses in `.local/revo-venturex-reply.json`,
and deletes and verifies deletion of the account. No production accounts are used.

### November 8 keyless research verification

The private packaged SearXNG service returned 25 results, including issuer pages,
despite one upstream CAPTCHA. A disposable local QA account exercised real
OpenCode/DeepSeek responses for credit education, conversational follow-ups,
current card terms, unfamiliar-card comparisons and unrelated general knowledge.
Simple answers were 42–49 words; the comparison was 145 words. One researched
turn hit a provider TLS error and used the labeled basic fallback. After adding
bounded connection retry, a separate current-terms question returned a sourced
74-word answer through the running local API/search service. These are observed
sample results, not guarantees for every question or the final launch model.

QA replies are saved privately in `.local/app-store-review/revo-quality.json` and
`revo-research-check.json`; the disposable account was deleted and temporary API
stopped. Keyless search remains running via `make search-up`; local API env now
selects it. Full `make check` passed (267 Flutter tests and Go checks), Go race
tests passed, Railway TypeScript and search Compose configuration validated.
No commit, push or production deployment was performed. The live API still needs
the private hosted search service and this source deployed before search is live.
