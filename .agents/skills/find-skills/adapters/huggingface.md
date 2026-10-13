# Adapter: Hugging Face Hub

**Registry:** Hugging Face Hub (Spaces)  
**Method:** WebFetch GET  
**Timeout:** 8 seconds

---

## Request

```
GET https://huggingface.co/api/spaces?search={query}&sort=likes&limit=20&filter=mcp
```

Also run a second query without the `filter=mcp` to catch AI tools broadly:

```
GET https://huggingface.co/api/spaces?search={query}+skill+agent&sort=likes&limit=10
```

Merge and deduplicate by `id`.

## Authentication

No auth required for public Spaces. If `HF_TOKEN` is available via:

```bash
node "$CODEX_PLUGIN_ROOT/bin/topgun-tools.cjs" keychain-get hf_token
```

Include it as `Authorization: Bearer {token}` for higher rate limits. Never log the token.

## Timeout + Retry

- On HTTP 429: wait 1s, retry; wait 2s, retry; wait 4s, retry.
- On timeout or 5xx: return `status: "unavailable"`.

## Response Parsing

Expected shape: array of Space objects.

| Response field | Unified schema field |
|----------------|----------------------|
| `id` | `name` |
| `cardData.short_description` or `description` (truncate to 500 chars, strip markdown/HTML tags before storing) | `description` |
| `url` or `https://huggingface.co/spaces/{id}` | `install_url` |
| `likes` | `stars` |
| `lastModified` | `last_updated` |
| `sha` | `content_sha` |
| *(whole object)* | `raw_metadata` |

Set `source_registry: "huggingface"` on every result.

## Return Value

```json
{
  "registry": "huggingface",
  "status": "ok",
  "reason": null,
  "results": [ /* unified schema objects */ ],
  "latency_ms": 0
}
```
