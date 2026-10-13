---
title: V-loop — SEARCH-CHANNELS.md independent verify
date: 2026-08-14
artifact: research/2026-08-14-dr-must-search-channels/SEARCH-CHANNELS.md
verdict: PASS (after cheap factual patches)
---

# V-loop: DR must-search channels

Independent check. Did not trust the research worker. Graphify query first. Live docs via `ctx_fetch_and_index` (no WebFetch, no curl HTTP). No branch switch, no commit.

## Overall: **PASS**

Two cheap factual patches applied to [SEARCH-CHANNELS.md](../SEARCH-CHANNELS.md) (see §Patches). No remaining invented numeric rate limits on cited pages that this pass could fetch.

## Checks

| # | Check | Result |
|---|---|---|
| 1 | File exists + required sections | **PASS** |
| 2 | Spot-check ≥6 live-doc claims | **PASS** (8/8 required + extras) |
| 3 | No invented numeric rate limits | **PASS** after Serper QPS clarification |
| 4 | 10-agent design = shared gateway, not 10× fan-out | **PASS** |
| 5 | Papers with Code / Hugging Face | **PASS** |

### 1. Artifact structure — PASS

File exists: [SEARCH-CHANNELS.md](../SEARCH-CHANNELS.md) (~312 lines).

| Required piece | Present |
|---|---|
| Mermaid architecture | Yes (`flowchart TB`, agents → shared gateway → FTS cache → per-host buckets → official APIs / search-cli / sample-only) |
| Per-source table (all must-search except locale) | Yes — 29 source rows covering the brief’s 16 groups (locale Qiita/V2EX/Habr/Juejin correctly omitted) |
| search-cli proposal | Yes — §3 |
| SB wiring | Yes — §4 (`search-orchestration.md`, orchestrator, catalogs, gateway, manifest) |
| MVP vs full | Yes — §5 |
| Honest gaps | Yes — §6 |

Must-search inventory vs brief (non-locale):

1. Stack Overflow / Stack Exchange
2. GitHub Discussions
3. Lobsters
4. deps.dev, ecosyste.ms, npm, PyPI, crates.io
5. Product Hunt
6. InfoQ + FOSDEM/QCon/KubeCon
7. SourceHut / Codeberg
8. Dev.to / Hashnode
9. Papers with Code
10. Per-vendor Discourse
11. Discord / Slack
12. Cursor forum, Anthropic help, OpenAI community
13. Indie Hackers
14. G2 + Gartner Peer Insights
15. TrustRadius / Capterra
16. GitHub code/issues, Reddit, Hacker News

All present. Hugging Face is not a numbered must-search item; it is the PwC replacement (correct).

### 2. Live-doc spot-checks — PASS

Fetched 2026-08-14 (this V-loop), independent of the worker.

| Claim | Live page | Verdict |
|---|---|---|
| Stack Exchange: **30 req/s per IP**; daily quota **default 10,000** with `key`; honor `backoff`; identical requests **once/minute** | [api.stackexchange.com/docs/throttle](https://api.stackexchange.com/docs/throttle) — “more than 30 requests a second”; “default is 10,000”; “semantically identical requests more than once a minute” | **PASS** |
| GitHub REST search: **30/min auth** (except code), **10/min unauth**, code **10/min** auth required; GraphQL primary **5,000 points/hour/user**; secondary **≤100 concurrent**, **2,000 GraphQL points/min**; REST primary **60/hour** unauth, **5,000/hour** auth | [REST search rate limit](https://docs.github.com/en/rest/search/search#rate-limit), [GraphQL rate limits](https://docs.github.com/en/graphql/overview/rate-limits-and-node-limits-for-the-graphql-api), [REST rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) | **PASS** |
| GitHub Discussions: web syntax `is:discussion` documented; REST search has no discussions endpoint | [Searching discussions](https://docs.github.com/en/search-github/searching-on-github/searching-discussions). GraphQL `SearchType` enum page is still SPA-empty this pass (same gap the worker disclosed). `search(type: DISCUSSION)` not independently rendered; not an invented number. | **PASS** (web syntax); GraphQL type name remains unverified SPA |
| HN Algolia: public JSON works unauthenticated; HTML docs have no numeric cap | Live `GET https://hn.algolia.com/api/v1/search?query=rate%20limit&hitsPerPage=1` returned JSON hits. `https://hn.algolia.com/api` nearly empty. | **PASS** |
| Discourse `/search.json` | [meta.discourse.org/search.json](https://meta.discourse.org/search.json?q=search.json%20api) and [forum.cursor.com/search.json](https://forum.cursor.com/search.json?q=api) both return `posts` JSON. `docs.discourse.org` SPA-empty. | **PASS** |
| Brave free tier: **$5 free credits / month**; Search **$5 per 1,000 requests** | [brave.com/search/api](https://brave.com/search/api/) “$5 in free credits every month”; [plans dashboard](https://api-dashboard.search.brave.com/app/plans) “$5.00 per 1,000 requests” under Search | **PASS** |
| Serper free trial **2,500 queries** | [serper.dev](https://serper.dev/) “Get 2,500 free queries” / “Try 2,500 queries for free” | **PASS** |
| G2 scrape ToS §9 | [legal.g2.com/terms-of-use](https://legal.g2.com/terms-of-use) last updated **July 9, 2026**; **§9 Prohibited Automated Access, Scraping, and Data Extraction** | **PASS** |
| search-cli providers vs in-repo/docs | Upstream README: “13 providers” — Brave, Serper, Exa, Linkup, Jina, Firecrawl, Tavily, SerpApi, Perplexity, Parallel, xAI, and more. In-repo [docs/SEARCH-CLI.md](../../../docs/SEARCH-CLI.md) lists a smaller subset (Brave, Serper, Exa, Jina, Firecrawl). Document correctly treats search-cli as **external OSS**. **`-p` already exists** (`search search -q "…" -p brave,serper`). | **PASS** after patch (was FAIL: invented `--providers` / `--no-fanout` as missing flags) |

Extra numbers also backed (not in the required six): Slack `search.messages` **Tier 2: 20+ per minute**; Reddit **100 QPM per OAuth client id** (10-min average); npm search `size` max **250**; PyPI **no edge rate limit**; Tavily **1,000 free credits/month**; Exa `/search` **10 QPS**, Search **$7/1k** up to 10 results; Gartner marketing **880,000+** ratings; Jina **500 RPM** cited as search-cli README only.

Operational bucket starts (≤15 req/s SE, 5 req/s deps.dev, 2 req/s Codeberg, 1 req/2s Discourse, ≤1 req/s HN) sit in the **10-agent strategy** column, not as fetched official limits. Allowed.

### 3. Invented numeric limits — PASS after patch

Pre-patch issue: Serper row said “Ultimate default **300 QPS**” next to the free trial. Live page: **300 QPS is the Ultimate paid plan** ($3750 / 12.5M credits); $1250 plan is **200 QPS**; free-trial QPS **not stated**. Patched to say that. 300 was not invented — it was mis-scoped.

No other fetched number failed its cited page.

### 4. 10-agent design — PASS

Executive rec + mermaid: **one shared search gateway** owns keys, token buckets, and query-normalized cache. Agents do not hold provider keys. Explicitly **not** 10 independent search-cli `general` fan-outs. Coherent with per-host buckets and “pick 1–2 aggregators, not 5”.

### 5. Papers with Code / Hugging Face — PASS

`https://paperswithcode.com/api/v1/docs/` **redirects to Hugging Face Trending Papers** (title “Trending Papers - Hugging Face”). `https://huggingface.co/papers` is Daily Papers. Document’s “sunset/redirect; do not build a PwC client; use academic mode + HF Papers + arXiv” matches live fetch.

## Patches applied to SEARCH-CHANNELS.md

1. **search-cli `-p` already exists** (README: `search search -q "…" -p brave,serper`). Removed invented “add `--providers` / `--no-fanout`” as missing primitives. Remaining real gap: `--cache-dir` + native SE/HN/Discourse providers. Updated mermaid, §3, §4, MVP #2.
2. **Serper 300 QPS** scoped to Ultimate paid plan; free-trial QPS unknown.
3. Removed session-local “agentmemory MCP unavailable” row from search-channel gaps (not a source-channel fact).

## Not patched (not FAILs)

- GraphQL `search(type: DISCUSSION)` still SPA-undocumented this pass; already in §6.
- Exact `general`-mode provider set is `search agent-info`; README diagram shows Brave+Serper+Exa. Lockout warning still holds.
- You.com is optional breadth, not a search-cli provider (README has no You.com). Honest.

## Tooling notes

- Graphify CLI query used (MCP `user-graphify` was in error state).
- agentmemory MCP: no server in this session’s `GetMcpTools` catalog; capture attempted via project export after this file.
- `graphify update .` after patches.
