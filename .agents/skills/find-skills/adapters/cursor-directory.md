# Adapter: Cursor Directory

**Registry:** Cursor Directory (awesome-cursorrules)  
**Method:** WebFetch GET (GitHub Contents API)  
**Timeout:** 8 seconds

---

## Request

```
GET https://api.github.com/repos/PatrickJS/awesome-cursorrules/contents/rules
```

This returns an array of 179+ rule directories. Filter by `name` matching the query (case-insensitive substring).

## Authentication (optional)

Retrieve GitHub token:

```bash
node "$CODEX_PLUGIN_ROOT/bin/topgun-tools.cjs" keychain-get github_token
```

If found, include `Authorization: Bearer {token}` for higher rate limits. Never log the token.

## Filtering

Client-side filter: include directory entries where `name` contains **any word** from the query string (intentionally broader than substring match — cursor rules use hyphenated slugs like `react-typescript-nextjs` so word-level matching improves recall).

For each matching directory, construct the install URL:

```
https://github.com/PatrickJS/awesome-cursorrules/tree/main/rules/{name}
```

Do NOT fetch individual rule files — directory listing is sufficient.

## Timeout + Retry

- On HTTP 429: wait 1s, retry; wait 2s, retry; wait 4s, retry.
- On timeout or 5xx: return `status: "unavailable"`.

## Response Parsing

| Response field | Unified schema field |
|----------------|----------------------|
| `name` | `name` |
| `"Cursor rules for " + name` (sanitize `name`: truncate to 500 chars, strip markdown/HTML tags before constructing) | `description` (synthesised) |
| constructed URL above | `install_url` |
| `sha` | `content_sha` |
| `null` | `stars` |
| `null` | `last_updated` |
| *(whole object)* | `raw_metadata` |

Set `source_registry: "cursor-directory"` on every result.

## Return Value

```json
{
  "registry": "cursor-directory",
  "status": "ok",
  "reason": null,
  "results": [ /* filtered unified schema objects */ ],
  "latency_ms": 0
}
```
