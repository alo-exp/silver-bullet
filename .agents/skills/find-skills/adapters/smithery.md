# Adapter: Smithery

**Registry:** Smithery  
**Method:** WebFetch GET  
**Timeout:** 8 seconds

---

## Authentication

Retrieve the Bearer token from the keychain before making the request:

```bash
node "$CODEX_PLUGIN_ROOT/bin/topgun-tools.cjs" keychain-get smithery_token
```

- If the command returns a non-empty string, use it as a Bearer token in the
  `Authorization` header: `Authorization: Bearer {token}`.
- If the command returns empty output or exits with an error, proceed **without**
  the Authorization header. The API allows unauthenticated requests at a lower
  rate limit.
- **Never log or write the token to any file.**

---

## Request

```
GET https://registry.smithery.ai/servers?q={query}
```

- URL-encode the query string before inserting it.
- Include `Authorization: Bearer {token}` header only if a token was retrieved.

---

## Timeout + Retry

- Set fetch timeout to 8 seconds.
- On HTTP 429: wait 1s, retry; wait 2s, retry; wait 4s, retry. After 3 retries
  return `status: "unavailable"`, `reason: "rate limited by Smithery"`.
- On timeout or HTTP 5xx: return `status: "unavailable"`, `reason: "<error detail>"`.

---

## Response Parsing

Parse the JSON response body. Expected shape is an object with a `servers` array
(or a top-level array). Extract the following fields from each server entry
(use `null` if absent):

| Response field | Unified schema field |
|----------------|----------------------|
| `name` or `displayName` | `name` |
| `description` or `summary` (truncate to 500 chars, strip markdown/HTML tags before storing) | `description` |
| `url` or `homepage` | `install_url` |
| `stars` or `starCount` | `stars` |
| `updatedAt` or `lastUpdated` | `last_updated` |
| *(whole object)* | `raw_metadata` |

Set `source_registry: "smithery"` on every result.  
Set `content_sha: null` (not available from this registry).

---

## Return Value

```json
{
  "registry": "smithery",
  "status": "ok",
  "reason": null,
  "results": [ /* unified schema objects */ ],
  "latency_ms": 0
}
```

On failure:

```json
{
  "registry": "smithery",
  "status": "unavailable",
  "reason": "<reason string>",
  "results": [],
  "latency_ms": 0
}
```
