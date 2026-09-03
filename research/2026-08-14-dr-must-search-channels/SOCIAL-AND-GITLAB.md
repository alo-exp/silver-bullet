---
title: GitLab, YouTube, LinkedIn, X, Facebook — must-search addendum
date: 2026-08-14
status: active
fetched: 2026-08-14
parent: SEARCH-CHANNELS.md
---

# Social + GitLab.com (first-class must-search)

Parent architecture (10 agents, one gateway, one key ring, cache, per-host buckets) is in [SEARCH-CHANNELS.md](SEARCH-CHANNELS.md). This addendum is the per-platform research. Do **not** implement the gateway in this pass.

**Policy:** paid official APIs are in-scope. `site:` via search-cli `-p brave,serper` is the legal recall fallback. Unofficial scrapers are last-resort legal risk, never the primary path. Expense is not a reason to drop a platform.

---

## 1. GitLab.com — upgrade from weak secondary to first-class

**Why this was “weak” (pre-this-pass catalogs):** [authority_domains.json](../../skills/silver-deep-research/reference/catalogs/authority_domains.json) listed `gitlab.com` under `code` **tier secondary** next to GitHub. [source_channels.json](../../skills/silver-deep-research/reference/catalogs/source_channels.json) `code` filtered **github.com only**. **This pass already upgraded those files** (`code.tier=primary` includes `gitlab.com`; `code.domain_filter` is `github.com,gitlab.com`; new `gitlab` channel). TopGun’s GitLab adapter still searches `GET /api/v4/projects?search=` (project-name search), not blob/issue/MR search. Landscape script `searchGitlab()` hits `/api/v4/search?scope=projects` only.

**Focus:** gitlab.com. Self-hosted / Dedicated expose the same Search API, but rate limits are admin-configured ([Projects API rate-limit page](https://docs.gitlab.com/ee/administration/settings/rate_limit_on_projects_api.html) is Self-Managed/Dedicated, not gitlab.com). Do not assume a customer’s GitLab instance is in the DR fleet.

### Best method

Official REST Search API, **authenticated**:

```text
GET https://gitlab.com/api/v4/search?scope=<scope>&search=<q>
```

Instance-level scopes (docs): `projects`, `issues`, `work_items`, `merge_requests`, `milestones`, `snippet_titles`, `users`, plus advanced/exact-code: `wiki_blobs`, `commits`, `blobs`, `notes`. **Instance `wiki_blobs` is Premium/Ultimate and needs advanced search enabled** (gitlab.com has advanced search; Free self-hosted may not). Project-level search: `GET /projects/:id/search`. Group-level also exists.

Gateway should fan **four DR-useful scopes** per query (cached): `projects`, `blobs`, `issues`, `merge_requests` (add `wiki_blobs` when the brief is docs-heavy). One PAT, `PRIVATE-TOKEN` header.

### Fallback

search-cli `-p brave,serper` with `site:gitlab.com <topic>`. Weaker than blob search (no code-line hits) but catches README/issue pages the SERP indexed. Unauthenticated `GET /api/v4/projects?search=` is a **name-only** weak path (TopGun); do not treat it as must-search coverage.

### Free / paid limits (cited 2026-08-14)

| Limit | Value | Source |
|---|---|---|
| Auth | **Every Search API call requires authentication.** Unauthenticated search is not a documented option. | [docs.gitlab.com/api/search](https://docs.gitlab.com/api/search/) |
| gitlab.com search API | **Advanced, project, or group search API: 10 requests each minute per IP** | [GitLab.com settings](https://docs.gitlab.com/ee/user/gitlab_com/) |
| gitlab.com authenticated API | **2,000 requests each minute per user** | same |
| gitlab.com unauthenticated traffic | **500 requests each minute per IP** (does not unlock Search API) | same |
| gitlab.com all traffic / IP | **2,000 requests each minute** | same |
| PAT cost | Free GitLab.com account + PAT. Numeric PAT creation cap: **unknown** this pass. | Search API is Free/Premium/Ultimate |

Honor `429`. The **10 req/min search cap** is the fleet bottleneck, not the 2,000 authenticated API cap.

### 10-agent strategy

One GitLab PAT on the gateway. Bucket **≤10 search req/min** (serialize scopes: projects → blobs → issues → MRs, or cache-collapse to one fingerprint). Do not give 10 agents their own tokens (still one IP). Cache `(scope, q, search_type)`.

### ToS

Official REST API is the intended integration. Do not scrape gitlab.com HTML/git raw for search. PAT scopes: `read_api` is enough for public search; never log the token.

### Where the adapter lives

**SB gateway** (same class as GitHub REST search), not a search-cli provider first. search-cli `-p` + `site:gitlab.com` is fallback only. Upstream search-cli GitLab provider is optional later, after the SB adapter is stable — same recommendation as SE/HN/Discourse in the parent doc.

### Evidence

- https://docs.gitlab.com/api/search/
- https://docs.gitlab.com/ee/api/search.html (same body)
- https://docs.gitlab.com/ee/user/gitlab_com/
- https://docs.gitlab.com/user/search/

---

## 2. YouTube — tech talks + product demos

### Best method

YouTube Data API v3 `search.list` with an API key (public video metadata; no user OAuth for search):

- `part=snippet`, `type=video`, `q=<topic>`, `order=relevance` (or `date` for recency), `maxResults=25`
- Optional: `videoCaption=closedCaption` when you need talks that advertise captions; `channelId=` for CNCF / vendor channels
- Then `videos.list` (`part=contentDetails,statistics`) for duration — **other-endpoint quota**, not the search bucket

This is the right tool for **conference talks, product demos, “X vs Y” videos**. `site:youtube.com` is weak (stale titles, no duration/channel filter, poor recency).

### Fallback

search-cli `-p brave,serper` `site:youtube.com <topic>` or `site:youtube.com/c/CNCF`. Use when the YouTube quota bucket is exhausted.

### Transcripts

| Path | Legal / practical |
|---|---|
| **Official** `captions.list` / `captions.download` | Requires OAuth with `youtube.force-ssl` or `youtubepartner`. These methods are for **the video owner / CMS partner**, not arbitrary public videos. **Not** a fleet transcript harvester. |
| **youtube-transcript** (npm) / InnerTube `get_transcript` | Unofficial timedtext. Convenient, **ToS-risk** vs YouTube API Services Developer Policies. Do **not** make it the default SB adapter. |
| ** pragmatic DR** | Cite the watch URL + snippet title/description from `search.list`. If a transcript is essential, human/sample or owner-uploaded captions only. |

### Free / paid limits (cited 2026-08-14) — **quota model changed vs folklore**

Folklore was “search.list = 100 units, default 10,000 units/day ⇒ 100 searches.” **Live docs disagree:**

| Fact | Live text |
|---|---|
| Default allocation | **100 `search.list` calls/day**, **100 `videos.insert` calls/day**, and **10,000 units/day for all other endpoints** (separate buckets). |
| `search.list` cost | **1 unit per call** (getting-started examples; quota calculator: search bucket cost is 1 per call). Extra pages of `search.list` each cost another call. |
| Reset | Midnight Pacific Time. |
| Increase | [Quota extension request form](https://support.google.com/youtube/contact/yt_api_form). Paid/extended quota is the “whatever it takes” path — **do not skip YouTube because 100/day is tight.** |

Sources: [getting-started](https://developers.google.com/youtube/v3/getting-started), [determine_quota_cost](https://developers.google.com/youtube/v3/determine_quota_cost), [search.list](https://developers.google.com/youtube/v3/docs/search/list).

**10 agents × uncached search = lockout in minutes.** Gateway cache is mandatory. 100 searches/day is enough for DR if queries are normalized.

### 10-agent strategy

One Google Cloud project / API key on the gateway. Bucket **search.list ≤ ~4/hour sustained** (leave headroom) or simply **cache-first, ≤100/day**. Never 10 keys. `videos.list` uses the 10k “other” bucket (cheap).

### ToS

YouTube API Services Developer Policies apply. Do not scrape watch pages. Unofficial InnerTube transcript clients are a policy risk — last resort, never default.

### Where the adapter lives

**SB gateway** (official JSON, like GitHub). Not a search-cli provider first. search-cli `site:youtube.com` is fallback. search-cli has no YouTube Data API provider today.

### Evidence

- https://developers.google.com/youtube/v3/docs/search/list
- https://developers.google.com/youtube/v3/getting-started
- https://developers.google.com/youtube/v3/determine_quota_cost
- https://developers.google.com/youtube/v3/docs/captions/list (OAuth required)
- https://developers.google.com/youtube/v3/docs/captions/download
- https://developers.google.com/youtube/terms/developer-policies
- https://www.npmjs.com/package/youtube-transcript (unofficial)

---

## 3. LinkedIn — partner APIs + `site:` (no public post search)

### What exists (official)

| Surface | What it actually searches | Who can use it |
|---|---|---|
| **Marketing API / Community Management** | **Your** org pages, shares, mentions, follower stats — not the global feed | Marketing API partners. Docs often sit behind Microsoft Learn auth (Posts API page required sign-in this pass). |
| **Consumer “Share on LinkedIn”** | **Write** a share as the member — **not search** | Self-serve consumer program |
| **Talent / Jobs APIs** | Jobs / ATS — partner application | Talent Solutions partners |
| **Sales Navigator Application Platform** | SNAP is a **partner CRM integration**, not a DR search API we can buy off the shelf. Sales Nav **UI** is not an API. | Sales Navigator partners |
| **Member profile “people” search** | No self-serve global people-search API for third-party DR | Restricted / partner |

There is **no** documented self-serve “search all public LinkedIn posts” API. Community Management “search” is brand-mention / page-admin scoped.

### Best method (legal “whatever it takes”)

1. **Paid partner (if budget + time):** apply to [LinkedIn Marketing API](https://learn.microsoft.com/en-us/linkedin/marketing/) / Community Management for **named company pages you have admin on**, and Talent if the brief is jobs. This is expensive and slow. Still **not** a firehose of all public posts.
2. **Aggregator recall (fleet default until partner lands):** search-cli `-p brave,serper`  
   `site:linkedin.com/posts <topic>`, `site:linkedin.com/company <vendor>`, `site:linkedin.com/pulse <topic>`. Recall is **partial** (Google/Brave index a slice of public posts; login-walled content will miss).
3. **search-cli `-m people`** already routes person lookups to **Exa** (search-cli README). Legal-ish aggregator, not LinkedIn-official. Optional, not fleet default (`-p brave,serper` remains the 10-agent web path).
4. **Human Sales Nav** for a named account list — sample only, not API.

### Fallback

Same `site:` queries. Do **not** use RapidAPI “LinkedIn search/scrape” products or headless login crawlers as the primary path — **ToS risk**. Last-resort legal option is still **partner application + paid Exa/Serper**, not a scraper.

### Free / paid limits

| Item | Status 2026-08-14 |
|---|---|
| Marketing / Community Management numeric rate limits | **Unknown** — docs behind auth |
| Partner fees | **Unknown** this pass (application, not a public SKU) |
| `site:linkedin.com` | Brave/Serper aggregator caps (parent doc) |
| SNAP | Not a DR API |

### Posts vs company pages vs jobs

| Need | Method |
|---|---|
| Public thought-leadership posts | `site:linkedin.com/posts` + `/pulse` |
| Vendor company page | `site:linkedin.com/company/<slug>` ; official Posts API only if we **admin** that Page via CM partner |
| Jobs | Talent partner APIs **or** `site:linkedin.com/jobs` |
| People / titles | `-m people` (Exa) or `site:linkedin.com/in` — never scrape profiles |

### 10-agent strategy

No LinkedIn token in MVP. One Brave+Serper key, `site:` templates, cache. If a Marketing API token is later approved, it lives on the gateway like GitHub PAT — never copied to 10 agents.

### ToS

[LinkedIn API Terms](https://www.linkedin.com/legal/l/api-terms-of-use) + [User Agreement](https://www.linkedin.com/legal/user-agreement) (effective 2025-11-03). Developer program is for approved products; scraping/crawling member content is the classic Don’t. RapidAPI unofficial LinkedIn APIs = assume **ToS-violating** unless LinkedIn is the publisher.

### Where the adapter lives

**Not** a native search-cli provider. Fleet: `-p brave,serper` + `site:`. Official CM/Marketing client belongs in **SB gateway** only after partner approval (full / paid).

### Evidence

- https://learn.microsoft.com/en-us/linkedin/marketing/
- https://learn.microsoft.com/en-us/linkedin/marketing/community-management/community-management-overview?view=li-lms-2026-07
- https://learn.microsoft.com/en-us/linkedin/marketing/community-management/shares/posts-api (auth-walled this pass)
- https://learn.microsoft.com/en-us/linkedin/sales/ (SNAP docs auth-walled)
- https://developer.linkedin.com/
- https://developer.linkedin.com/product-catalog
- https://www.linkedin.com/legal/l/api-terms-of-use
- https://www.linkedin.com/legal/user-agreement

---

## 4. Twitter / X — paid official API is the real answer

### Best method

X API v2 Search Posts (Bearer token), via the **pay-per-usage** Developer Console — **not** the old Basic/Pro/Enterprise monthly SKUs as a current price list.

| Endpoint | Window | Access (live docs) |
|---|---|---|
| `GET /2/tweets/search/recent` | Last **7 days** | **All developers** |
| `GET /2/tweets/search/all` | Full archive | **Pay-per-use + Enterprise** |

Docs: [Search Posts intro](https://docs.x.com/x-api/posts/search/introduction.md), [recent search](https://docs.x.com/x-api/posts/search-recent-posts.md), [full-archive quickstart](https://docs.x.com/x-api/posts/search/quickstart/full-archive-search.md).

**Expense is acceptable.** If DR needs X discourse (CVE chatter, launch threads, eng Twitter), **buy credits**. Do not drop the channel because it is not free.

### Fallback

search-cli `-p brave,serper` with `site:x.com OR site:twitter.com <topic>`. Recall is incomplete (deleted tweets, login walls, JavaScript SERP). Better than nothing when credits are empty.

search-cli **already has** `-m social` → **xAI (Grok)** for “what’s being said on X/Twitter” (README). That is an aggregator, bills xAI, **not** the official X Search API. Optional breadth; **not** the 10-agent default (fleet stays `-p brave,serper`).

### Free / paid limits (cited 2026-08-14)

Live pricing page: **pay-per-usage, no subscriptions.** Buy credits, spending caps, up to 20% back as xAI credits. [pricing.md](https://docs.x.com/x-api/getting-started/pricing.md)

| Item | Live figure | Notes |
|---|---|---|
| Owned Reads (your own posts/followers/likes/…) | **$0.001 per resource** (1,000 / $1) | Not public search |
| Public Post **search** unit cost | **Unknown** this pass — pricing tables listed writes/actions and Owned Reads; search/recent per-hit USD was **not extracted** from the MD table | Treat as **paid; look up console.x.com before budgeting** |
| Pay-per-usage cap | **3 million Post reads / monthly billing cycle**; more → Enterprise interest form | |
| Legacy Basic $100 / Pro $5,000 / month | **Not on the live pricing page.** Do not cite those SKUs as current. | Replaced by credits |
| `max_results` examples | 100 in official curl samples | |

Developer Agreement fetched (updated 2026-04-27): paid services / acceptable use. Scraping is not the licensed path.

### Nitter / syndication / scrapers

| Option | Verdict |
|---|---|
| **Nitter** ([zedeus/nitter](https://github.com/zedeus/nitter)) | Still in tree, but **“Running a Nitter instance now requires real accounts, since Twitter removed the previous methods”** (guest tokens gone). Unofficial API. **Do not** put Nitter in the SB gateway. Treat public instances as **likely dead / ToS-hostile**. |
| RSS / syndication | **Unknown** as a first-class X product this pass. |
| ToS-violating scrapers | Not the primary path. Paid X API is the honest answer. |

### 10-agent strategy

One X developer app + credit balance on the gateway. Cache by query + `start_time`. Prefer `search/recent` for DR freshness; `search/all` only when the brief needs history (costs more). Never 10 Bearer tokens.

### Where the adapter lives

**SB gateway** when credits are budgeted (full / paid). Until then, search-cli `-p brave,serper` + `site:x.com OR site:twitter.com`. Do **not** add an unofficial Nitter provider to search-cli.

### Evidence

- https://docs.x.com/x-api/getting-started/pricing.md
- https://docs.x.com/x-api/posts/search/introduction.md
- https://docs.x.com/x-api/posts/search-recent-posts.md
- https://docs.x.com/x-api/posts/search/quickstart/recent-search.md
- https://docs.x.com/x-api/posts/search/quickstart/full-archive-search.md
- https://developer.x.com/en/developer-terms/agreement
- https://github.com/zedeus/nitter

---

## 5. Facebook — dedicated verdict

### **Exclude from must-search** for tech/dev DR.

One-sentence verdict: **Skip Facebook as a must-search channel** — public post search is gone, CrowdTangle is dead, Meta Content Library is academic-only, and LinkedIn/X already cover professional/dev discourse; keep optional `site:facebook.com` / Pages-you-admin sample only.

### What we fetched

| Claim | Evidence 2026-08-14 |
|---|---|
| Graph API **public post search** | `https://developers.facebook.com/docs/graph-api/reference/search` **HTTP 404**. Legacy v3.2 search URL also 404. Treat the product as **removed**, not temporarily undocumented. Historical “~2018–2019 Cambridge Analytica” removal is widely reported; **that changelog URL was not fetchable this pass** — do not pretend we re-read the 2018 note. |
| **Pages search** (not posts) | Live: `GET https://graph.facebook.com/pages/search?q=` with a user access token. Finds **Pages** (name/location), not the public feed. [Pages API searching](https://developers.facebook.com/docs/pages/searching) |
| Pages **you admin** | Graph API Pages/feed for pages the token can manage — sample / first-party only, not “search Facebook.” |
| **CrowdTangle** | `www.crowdtangle.com` **DNS ENOTFOUND**. Wikipedia `CrowdTangle` **redirects** to Meta acquisitions (product absorbed). Reuters/Verge shutdown URLs 401/404 this pass. **Do not build a CrowdTangle client.** |
| **Meta Content Library** | [transparency.meta.com/researchtools/meta-content-library](https://transparency.meta.com/researchtools/meta-content-library) exists (title indexed; body SPA **empty** this pass). Academic / qualified-researcher access, **not** an SB DR API. |
| Scraping | [Platform Terms](https://developers.facebook.com/terms/) exist (long). Automated collection ToS page returned empty. Assume **no scrape**. |

### Best / fallback / paid

| Path | Role |
|---|---|
| Official public post search | **Does not exist** |
| Paid Meta / Content Library | Academic program — **out of band** for product DR; do not budget as MVP |
| Pages API (admin) | Only if SB or the user admins a Page |
| `site:facebook.com` via Brave/Serper | Optional **recall sample** when a brief names a Page; **not** must-search |
| Unofficial scrapers | ToS-violating — not a path |

### Is Facebook worth it vs LinkedIn / X for tech DR?

**No.** Dev/tooling conversation lives on X, GitHub, HN, SO, and professional posts on LinkedIn. Facebook Groups still host some communities, but there is **no legal search API** and aggregator recall is poor. Opportunity cost of a Meta partnership is better spent on **X credits + YouTube quota + GitLab PAT**.

### 10-agent strategy

**None.** Do not add a Facebook bucket. If a brief names a Page, one `site:facebook.com/<page>` query through the existing Brave/Serper path is enough.

### ToS

Platform Terms + no automated scraping. Content Library has its own research terms (not extracted; SPA).

---

## 6. search-cli vs SB gateway (this pass)

| Channel | search-cli | SB gateway adapter |
|---|---|---|
| GitLab.com Search API | **No** — use `-p brave,serper` + `site:gitlab.com` until adapter exists | **Yes (MVP-adjacent)** — same class as GitHub REST |
| YouTube `search.list` | **No** native provider | **Yes (MVP-adjacent)** |
| LinkedIn | `-p` + `site:linkedin.com…`; optional `-m people` (Exa) | Official CM/Marketing **only after partner** (full/paid) |
| X | `-p` + `site:x.com OR site:twitter.com`; optional `-m social` (xAI) | Official v2 search **when credits budgeted** (full/paid) |
| Facebook | Optional `site:facebook.com` only | **Do not build** |

**Do not invent flags.** Confirmed: `-p brave,serper` exists. `--providers` / `--no-fanout` were V-loop false inventions. Remaining real gaps: **`--cache-dir`** + native SE / HN / Discourse providers (parent doc). GitLab/YouTube native providers belong in **SB first**, then optional upstream PR.

search-cli `-m social` / `-m people` are **existing modes** (xAI / Exa). They are **not** the 10-agent default (fan-out / extra bills). Document them as legal aggregator extras, not official platform APIs.

---

## 7. MVP vs full (social + GitLab slice)

**MVP-adjacent (APIs exist, keys cheap):** GitLab PAT Search API + YouTube Data API key. Plus existing `site:` fallback.

**Full / paid:** X API credits (`search/recent` then `search/all`); LinkedIn Marketing/Community Management partner if a named Page program matters.

**Exclude from must-search:** Facebook (sample/`site:` only).

---

## 8. Sources fetched 2026-08-14 (addendum)

Success: GitLab Search API + gitlab.com settings; YouTube search.list / quota / captions / policies; X pricing.md + search intro + recent/all quickstarts + Developer Agreement; LinkedIn Marketing hub + CM overview + API ToS + User Agreement + product catalog; Facebook Platform Terms + Pages search; Nitter README; Meta Content Library title; youtube-transcript npm.

Failed / thin (do not invent from them): X `/products` 404; several guessed CrowdTangle news URLs 404/401; Graph API `/search` 404; CrowdTangle DNS fail; LinkedIn Posts API / SNAP / getting-access **auth-walled**; Meta Content Library body empty SPA; Facebook Terms of Service body empty; automated scraping ToS empty; X public-search **dollar-per-hit unknown**.
