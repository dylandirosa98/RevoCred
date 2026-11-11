# Existing credit-card data options

Yes—there are existing options. We do not need to build the entire dataset from scratch.

| Resource | What it gives us | Main limitation |
|---|---|---|
| **OpenCard DB** | Free JSON downloads and a working REST API; fees, earning rates, benefits, issuer links, and verification dates.[1][3] | Community-maintained; completeness and freshness vary. |
| **Miles public API** | Free, no key; card identities, fees, benefit/protection names.[4] | Excludes reward multipliers and detailed benefit amounts, so insufficient on its own.[4] |
| **CardAPI** | Free tier: 100 calls/day and 3,000/month; basic info and top three reward rates.[5] | Benefits, credits, and full rates require its $29/month Starter plan.[5] |

**My recommendation is OpenCard DB as the free starting point.** I called its Sapphire Reserve endpoint successfully. It already includes The Edit credit, dining credit, lounge access, and travel protections missing from our record.[3] Its data license explicitly permits commercial use with attribution; card artwork is excluded.[2]

The caveat: that Reserve record says **last verified July 23, 2026**, so it is not a guarantee of complete current terms.[3] We can use the existing feed and review changes or gaps rather than researching every card from zero. No third-party data has been imported into RevoCred yet.

## Sources

[1] https://github.com/thedavidweng/opencard-db — OpenCard DB
[2] https://raw.githubusercontent.com/thedavidweng/opencard-db/main/LICENSE-DATA — OpenCard data license
[3] https://opencard-db.davidweng.workers.dev/v1/cards/us-chase-sapphire-reserve — Live Sapphire Reserve API response
[4] https://askmiles.ai/developers — Miles developer documentation
[5] https://cardapi.dev/pricing — CardAPI pricing
