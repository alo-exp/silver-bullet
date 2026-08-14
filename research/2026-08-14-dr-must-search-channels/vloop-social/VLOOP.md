---
title: Independent V-loop — must-search social + GitLab channels
date: 2026-08-14
prior_worker_trusted: false
commit: false
branch_switch: false
result: PASS
---

# Independent V-loop (social + GitLab must-search)

Parent did **not** trust the prior worker. Graphify first, then live `ctx_fetch_and_index` (no WebFetch, no curl HTTP). Native Read before patches. No commit. No branch switch.

## Verdict

**PASS** (6/6 checks). Small catalog/prose consistency errors were patched; core API facts stand.

### Facebook one-sentence verdict — **CONFIRMED**

Skip Facebook as a must-search channel — public post search is gone, CrowdTangle is dead, Meta Content Library is academic-only, and LinkedIn/X already cover professional/dev discourse; keep optional `site:facebook.com` / Pages-you-admin sample only.

Independent re-fetch: Graph `reference/search` and `v22.0/search` **HTTP 404**; Pages search is **Pages not posts**; `www.crowdtangle.com` and `help.crowdtangle.com` **DNS ENOTFOUND**; Wikipedia `CrowdTangle` **redirects** to Meta acquisitions. Content Library title exists; body is still an empty SPA — “academic-only” is weakly evidenced from the page body this pass, but it does not change the exclude verdict.

### YouTube quota — **CONFIRMED**

Live default is **100 `search.list` calls/day at 1 unit each** (own bucket), **not** the old “100 units per search from a 10,000-unit pool” folklore. Also: 100 `videos.insert`/day and 10,000 units/day for other endpoints. Sources: [getting-started](https://developers.google.com/youtube/v3/getting-started), [determine_quota_cost](https://developers.google.com/youtube/v3/determine_quota_cost), [search.list](https://developers.google.com/youtube/v3/docs/search/list) (“Quota impact: 100 calls per day… cost of 1 unit in the Search Queries quota bucket”).

## PASS/FAIL table

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Files exist; GitLab, YouTube, LinkedIn, X/Twitter in must-search tables; Facebook explicit exclude-from-must-search with reasons | **PASS** | All four artifacts exist. [SEARCH-CHANNELS.md](../SEARCH-CHANNELS.md) §2 rows L127–131; [SOCIAL-AND-GITLAB.md](../SOCIAL-AND-GITLAB.md) §§1–5. Facebook: “Exclude from must-search” + Graph 404 / Pages≠posts / CrowdTangle DNS / Content Library SPA. |
| 2 | No invented search-cli flags (`--providers`, `--no-fanout`); must use existing `-p` | **PASS** | Artifacts warn against `--providers` / `--no-fanout`. README confirms `search search -q "…" -p brave,serper` and `-m social` / `-m people`. `--cache-dir` correctly marked proposed (not in README). V-loop tightened a proposed `--provider` example so it is not readable as shipping. |
| 3 | Live-doc spot-checks (≥5) | **PASS** | See [Live docs](#live-docs-independent-refetch) (6 independent fetches). YouTube quota **confirmed** (would FAIL if folklore). |
| 4 | JSON catalogs valid jq; gitlab.com primary; facebook not in must-search tiers; youtube/x/linkedin/gitlab descriptors present | **PASS** | `jq empty` both files **JQ_OK**. `authority_domains.code.tier=primary` includes `gitlab.com`. Facebook absent from all authority tiers; `source_channels.facebook.must_search=false`. Descriptors: `gitlab`, `youtube`, `linkedin`, `x`. |
| 5 | Gateway was not falsely claimed as implemented | **PASS** | Frontmatter `proposal only`. SOCIAL: “Do **not** implement the gateway in this pass.” SEARCH-CHANNELS: “gateway **not** implemented”; `search_gateway.py` listed as new/future. |
| 6 | Small factual errors patched | **PASS** (patched) | See [Patches](#patches-this-v-loop). |

## Live docs (independent refetch)

| Source | URL | Independent result | Worker claim |
|---|---|---|---|
| GitLab Search API | https://docs.gitlab.com/api/search/ | `GET /api/v4/search?scope=projects` (and blobs/issues/MRs/wiki_blobs). Auth required. Instance `wiki_blobs` = Premium/Ultimate + advanced search. | Official `GET /api/v4/search` + those scopes. **Match.** |
| GitLab.com limits | https://docs.gitlab.com/ee/user/gitlab_com/ | “Advanced, project, or group search API for an IP address — **10 requests each minute**.” | 10 req/min search bucket. **Match.** |
| YouTube quota | getting-started + determine_quota_cost + search.list | **100 `search.list`/day, 1 unit/call**, separate from 10k other-endpoint units. | 100 searches/day, 1 unit each. **CONFIRMED** (folklore FAIL avoided). |
| X search | https://docs.x.com/x-api/posts/search/introduction.md | `GET /2/tweets/search/recent` last **7 days**, **all developers**; `GET /2/tweets/search/all` full archive, **pay-per-use + Enterprise**. | Same. **Match.** |
| LinkedIn | Marketing hub + CM overview + Posts API | CM: manage **company pages** (create/manage posts, apply for access). Posts API is org-page write/manage, auth-walled. **No** self-serve “search all public posts” API. | No self-serve global post search; partner + `site:`. **Match.** |
| Facebook / CrowdTangle | Graph search 404; Pages search; crowdtangle.com DNS; Wikipedia redirect | Public post search docs **404**. Pages search finds **Pages**. CrowdTangle **DNS dead**. Wiki redirect to Meta acquisitions. | Exclude; same reasons. **CONFIRMED.** |

## Patches this V-loop

1. [SEARCH-CHANNELS.md](../SEARCH-CHANNELS.md) — catalog prose was present-tense “is six buckets”; now “was / this pass added”. Proposed CLI block now uses README `-p` form and labels `--provider` as invented-proposed. Mermaid no longer implies a live `--json` search flag.
2. [SOCIAL-AND-GITLAB.md](../SOCIAL-AND-GITLAB.md) — “In-repo today” catalog sentences were stale after the worker’s own JSON upgrade; rewritten as pre-this-pass. Instance `wiki_blobs` Premium/Ultimate caveat added.
3. [source_channels.json](../../../skills/silver-deep-research/reference/catalogs/source_channels.json) — `scope_notes` for instance `wiki_blobs` Premium/Ultimate + advanced search.

No YouTube quota correction. No Facebook verdict correction.

## Gateway

Proposal only. Not implemented. Not claimed as implemented.

## agentmemory

MCP `user-agentmemory` is **not wired** in this session (`~/.cursor/mcp.json` has graphify + lean-ctx only). Session note saved to [`.agentmemory/memory/2026-08-14-vloop-social-must-search.md`](../../../.agentmemory/memory/2026-08-14-vloop-social-must-search.md).
