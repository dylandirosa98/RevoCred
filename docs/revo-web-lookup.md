# REVO model-directed public research

REVO sends the user's current message, up to eight recent chat messages and the
server snapshot (profile, wallet, spending, deterministic results and catalog)
to the configured Chat Completions provider. Both OpenAI and OpenCode use the
same tool loop. The model decides whether research is useful: there is no
known-card, keyword or issuer-domain search gate. Wallet explanations and
general education can be answered without external search.

## Tools and boundaries

- `web_search(query)` posts a minimal standalone public-topic query to
  DuckDuckGo. Search snippets include source URLs and a read timestamp.
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
  has an eight-second maximum. Response bodies and excerpts are bounded.
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

The versioned sharing notice (`sharingDataUse`, `revo-sharing-v3`) describes
both the configured AI recipient and DuckDuckGo/public-page research. Its digest
changes with recipient/model/wording, forcing renewed per-message consent.
The deterministic provider performs no network research.

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
