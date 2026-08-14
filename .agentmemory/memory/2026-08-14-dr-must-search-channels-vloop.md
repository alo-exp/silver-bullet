# Independent V-loop — DR must-search channels (2026-08-14)

- type: decision
- result: **PASS** (after cheap factual patches)
- prior_pass_trusted: false
- engine_edited: false
- commit: false
- graphify: queried then `graphify update .` after patches
- agentmemory MCP: unavailable in this session (no server in GetMcpTools); this file is the project export

Artifact: `research/2026-08-14-dr-must-search-channels/SEARCH-CHANNELS.md`
Report: `research/2026-08-14-dr-must-search-channels/vloop/VLOOP.md`

Live `ctx_fetch_and_index` confirmed: SE 30 req/s + 10k/day + once/minute; GitHub search 30/10/min + GraphQL 5k points/hour; HN Algolia JSON; Discourse search.json; Brave $5 credits + $5/1k; Serper 2,500 free queries; G2 ToS §9 scrape ban; PwC API docs redirect to Hugging Face Trending Papers.

Patches: search-cli `-p` already exists (do not invent `--providers`); Serper 300 QPS is Ultimate paid, not free trial.
