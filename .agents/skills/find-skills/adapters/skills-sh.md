# Adapter: skills.sh

**Registry:** skills.sh
**Method:** WebSearch (API endpoint confirmed 404 on 2026-04-26)
**Timeout:** N/A (WebSearch)

---

## Request

The REST API endpoint `https://skills.sh/api/skills` returns 404. The domain exists but
has no public search API. This adapter uses WebSearch to find skills listed on skills.sh.

## Timeout + Retry

- WebSearch is handled by the parent agent, so there is no registry-side HTTP retry loop.
- If the search backend stalls or errors, broaden the query once as described below; do not loop indefinitely.

---

### Step 1 — WebSearch

Run a WebSearch with the following query (substitute `{query}` with the task description):

```
site:skills.sh {query} skill
```

## Response Parsing

For each search result returned:

| Search result field | Unified schema field |
|---------------------|----------------------|
| Page title (strip site name suffix) | `name` |
| Snippet / description (truncate to 500 chars, strip HTML/markdown tags) | `description` |
| Result URL (only if starts with `https://skills.sh/`) | `install_url` |
| `null` | `stars` |
| `null` | `last_updated` |
| `null` | `content_sha` |
| `"skills-sh"` | `source_registry` |
| `{ "search_result": { "title": "...", "url": "...", "snippet": "..." } }` | `raw_metadata` |

Filter out any result whose URL does not start with `https://skills.sh/`. Skip results
with empty or missing names.

### Step 3 — Handle no results

If WebSearch returns 0 results for the site-scoped query, try a broader query:

```
skills.sh claude code skill {query}
```

If still 0 results, return:

```json
{
  "registry": "skills-sh",
  "status": "ok",
  "reason": "no results found",
  "results": [],
  "latency_ms": 0
}
```

## Return Value

```json
{
  "registry": "skills-sh",
  "status": "ok",
  "reason": null,
  "results": [ /* mapped array */ ],
  "latency_ms": 0
}
```

## Threat Mitigations

- **T-02-05 (Spoofing):** Filter install_url to `https://skills.sh/` prefix only.
- Structural envelope applied by parent agent to all `raw_metadata` values.

## Notes

- If skills.sh publishes a REST API in future, replace this adapter with a WebFetch-based approach
  using `smithery.md` as a template.
- Confirmed 404 on 2026-04-26: `GET https://skills.sh/api/skills?q=test` → 404 Not Found.
