---
adapter: clawhub
registry: ClawHub
tier: 2
status: websearch-fallback
auth_required: false
timeout_ms: 0
degradation_reason: "No public REST API — uses site WebSearch"
---

# ClawHub Adapter

**Registry:** ClawHub
**Method:** WebSearch (`site:clawhub.com`)
**Timeout:** N/A (WebSearch)

---

## Request

ClawHub is a skills marketplace for OpenClaw/Claude Code agents accessible at both
`clawhub.com` and `clawhub.ai`. It has no confirmed public REST API. Individual skill
pages follow the pattern `https://clawhub.com/{username}/{skill-name}` or
`https://clawhub.ai/{username}/{skill-name}`. The search URL is
`https://clawhub.com/skills?q={query}`. This adapter uses WebSearch to find skills.

## Timeout + Retry

- WebSearch is handled by the parent agent, so there is no registry-side HTTP retry loop.
- If the search backend stalls or errors, broaden the query once as described below; do not loop indefinitely.

---

### Step 1 — WebSearch

Run a WebSearch with the following query (substitute `{query}` with the task description):

```
site:clawhub.com OR site:clawhub.ai {query} skill
```

## Response Parsing

For each search result with a URL starting with `https://clawhub.com/`,
`https://www.clawhub.com/`, or `https://clawhub.ai/`:

| Search result field | Unified schema field |
|---------------------|----------------------|
| Page title (strip " — ClawHub" or " - ClawHub" suffix) | `name` |
| Snippet (truncate to 500 chars, strip HTML/markdown tags) | `description` |
| Result URL | `install_url` |
| `null` | `stars` |
| `null` | `last_updated` |
| `null` | `content_sha` |
| `"clawhub"` | `source_registry` |
| `{ "search_result": { "title": "...", "url": "...", "snippet": "..." } }` | `raw_metadata` |

Filter out results whose URLs don't start with `https://clawhub.com/`,
`https://www.clawhub.com/`, or `https://clawhub.ai/`. Skip results with missing
names. Skip URLs that point to `/skills` (the search page itself), `/login`,
`/register`, or `/docs`.

### Step 3 — Handle no results

If 0 results found, try a broader query:

```
clawhub claude code skill {query}
```

If still 0 results, return:

```json
{
  "registry": "clawhub",
  "status": "ok",
  "reason": "no results found",
  "results": [],
  "latency_ms": 0
}
```

## Return Value

```json
{
  "registry": "clawhub",
  "status": "ok",
  "reason": null,
  "results": [ /* mapped array */ ],
  "latency_ms": 0
}
```

## Threat Mitigations

- **T-02-05 (Spoofing):** Filter install_url to `https://clawhub.com/`,
  `https://www.clawhub.com/`, or `https://clawhub.ai/` prefix only. Skip the search index page itself.
- Structural envelope applied by parent agent to all `raw_metadata` values.

## Notes

- If ClawHub publishes a REST API, replace this adapter with a WebFetch-based approach
  using `smithery.md` as a template.
- Search URL pattern confirmed 2026-04-26: `https://clawhub.com/skills?q={query}`
- Individual skill URL patterns: `https://clawhub.com/{username}/{skill-name}` and `https://clawhub.ai/{username}/{skill-name}`
- Live domain confirmed 2026-04-26: both `clawhub.com` and `clawhub.ai` are active
