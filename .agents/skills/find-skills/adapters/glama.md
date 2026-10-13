# Adapter: Glama.ai

**Registry:** Glama.ai  
**Method:** WebFetch GET  
**Timeout:** 8 seconds

---

## Request

```
GET https://glama.ai/api/mcp/v1/servers?query={query}&first=20
```

- URL-encode the query string.
- No authentication required.
- Enforce 8-second timeout.

## Pagination

Response includes `pageInfo.endCursor`. If `pageInfo.hasNextPage` is true, fetch one additional page:

```
GET https://glama.ai/api/mcp/v1/servers?query={query}&first=20&after={endCursor}
```

Merge results from both pages. Do not paginate beyond 2 pages.

## Timeout + Retry

- On HTTP 429: wait 1s, retry; wait 2s, retry; wait 4s, retry. After 3 retries return `status: "unavailable"`, `reason: "rate limited by Glama.ai"`.
- On timeout or HTTP 5xx: return `status: "unavailable"`, `reason: "<error detail>"`.

## Response Parsing

Expected shape: `{ servers: [...], pageInfo: { endCursor, hasNextPage } }`.

| Response field | Unified schema field |
|----------------|----------------------|
| `name` | `name` |
| `description` (truncate to 500 chars, strip markdown/HTML tags before storing) | `description` |
| `url` (validate begins with `https://`; set `null` if not) | `install_url` |
| `attributes.githubStars` | `stars` |
| `attributes.updatedAt` | `last_updated` |
| `namespace` + `slug` | `content_sha` (use as identifier) |
| *(whole object)* | `raw_metadata` |

Set `source_registry: "glama"` on every result.

## Return Value

```json
{
  "registry": "glama",
  "status": "ok",
  "reason": null,
  "results": [ /* unified schema objects */ ],
  "latency_ms": 0
}
```
