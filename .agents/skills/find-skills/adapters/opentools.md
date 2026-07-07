# Adapter: OpenTools.ai

**Registry:** OpenTools.ai
**Method:** WebFetch GET with relevance filter
**Timeout:** 8 seconds

---

## Request

`https://opentools.ai/api/tools` returns 200 with valid JSON, but the results catalogue
general AI tools (image generation, deepfakes, etc.) — not Claude Code skills. A targeted
query and relevance filter is required.

---

### Step 1 — Build request URL

```
GET https://opentools.ai/api/tools?q=claude+code+skill+{url_encode(query)}&limit=20
```

No authentication required.

### Step 2 — WebFetch with timeout

Perform a WebFetch GET to the URL.

- Timeout: **8 seconds**
- On timeout: fall through to Step 4 (WebSearch fallback)
- On 4xx/5xx: fall through to Step 4

## Timeout + Retry

- Timeout: **8 seconds**
- On timeout or 4xx/5xx: fall through to Step 4 (WebSearch fallback)

## Response Parsing

If response is 200 and valid JSON with a `tools` or `results` array:

Map each item to unified schema:

| Response field | Unified schema field |
|----------------|----------------------|
| `name` or `title` | `name` |
| `description` or `tagline` (truncate to 500 chars, strip HTML/markdown tags) | `description` |
| `url` or `website` | `install_url` |
| `stars` or `upvotes` | `stars` |
| `updatedAt` or `createdAt` | `last_updated` |
| *(whole object)* | `raw_metadata` |

**Relevance filter (required):** Only include a result if its `name` or `description`
contains at least one of these terms (case-insensitive):
`claude`, `claude code`, `skill`, `agent skill`, `mcp`, `coding agent`

Discard results that don't pass this filter. If 0 results pass the filter, fall
through to Step 4.

### WebSearch fallback

If Step 2 fails or Step 3 yields 0 relevant results, run a WebSearch:

```
site:opentools.ai claude code skill {query}
```

Parse search results with URLs starting `https://opentools.ai/`:

| Search result field | Unified schema field |
|---------------------|----------------------|
| Page title | `name` |
| Snippet (truncate to 500 chars, strip HTML/markdown tags) | `description` |
| Result URL | `install_url` |
| `null` | `stars`, `last_updated`, `content_sha` |
| `"opentools"` | `source_registry` |
| `{ "search_result": {...} }` | `raw_metadata` |

## Return Value

On success (either path):

```json
{
  "registry": "opentools",
  "status": "ok",
  "reason": null,
  "results": [ /* filtered mapped array */ ],
  "latency_ms": 0
}
```

On complete failure:

```json
{
  "registry": "opentools",
  "status": "unavailable",
  "reason": "API and WebSearch both returned no relevant results",
  "results": [],
  "latency_ms": 0
}
```

## Degradation Notice

The OpenTools.ai API (`/api/tools`) returns 200 with valid JSON but catalogues general AI
tools (image generation, productivity, deepfakes) — not Claude Code skills. **The relevance
filter (Step 3) is mandatory** to prevent noise. If the API changes or the filter yields 0
results, the WebSearch fallback (Step 4) ensures the adapter remains useful. If both fail,
the adapter returns `status: "unavailable"` and does not stall the pipeline.

## Notes

- The API returns 200 with generic AI tools — the relevance filter is mandatory.
- Confirmed off-topic results on 2026-04-26: query returned deepfake/image tools.
