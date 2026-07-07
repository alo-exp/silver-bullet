---
adapter: lobehub
registry: LobeHub
tier: 2
status: websearch-fallback
auth_required: false
timeout_ms: 8000
degradation_reason: "API endpoint returns 403 Forbidden — bot/API-key protection active"
---

# LobeHub Adapter

**Registry:** LobeHub
**Method:** WebSearch (API returns 403 as of 2026-04-26)
**Timeout:** N/A (WebSearch)

---

## Request

`https://chat-agents.lobehub.com/api/agents` returns 403 Forbidden. This adapter uses
WebSearch to find LobeHub agents relevant to the query.

Note: LobeHub agents are primarily designed for LobeChat, not Claude Code. Results may
be tangentially relevant (agent prompts/tools that could be adapted).

## Timeout + Retry

- WebSearch is handled by the parent agent, so there is no registry-side HTTP retry loop.
- If the search backend stalls or errors, broaden the query once as described below; do not loop indefinitely.

---

### Step 1 — WebSearch

Run a WebSearch with the following query:

```
lobehub agent {query}
```

## Response Parsing

For each search result with a URL starting with `https://lobehub.com/` or
`https://chat-agents.lobehub.com/`:

| Search result field | Unified schema field |
|---------------------|----------------------|
| Page title (strip " - LobeHub" suffix) | `name` |
| Snippet (truncate to 500 chars, strip HTML/markdown tags) | `description` |
| Result URL | `install_url` |
| `null` | `stars` |
| `null` | `last_updated` |
| `null` | `content_sha` |
| `"lobehub"` | `source_registry` |
| `{ "search_result": { "title": "...", "url": "...", "snippet": "..." } }` | `raw_metadata` |

Filter out results whose URLs don't start with `https://lobehub.com/` or
`https://chat-agents.lobehub.com/`. Skip results with missing names.

### Step 3 — Handle no results

If 0 results found, return:

```json
{
  "registry": "lobehub",
  "status": "ok",
  "reason": "no results found",
  "results": [],
  "latency_ms": 0
}
```

## Return Value

```json
{
  "registry": "lobehub",
  "status": "ok",
  "reason": null,
  "results": [ /* mapped array */ ],
  "latency_ms": 0
}
```

## Notes

- If LobeHub publishes a public API, replace this adapter with a WebFetch approach.
- Confirmed 403 on 2026-04-26: `GET https://chat-agents.lobehub.com/api/agents?q=test`.
