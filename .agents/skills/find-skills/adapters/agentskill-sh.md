# Adapter: agentskill.sh

**Registry:** agentskill.sh  
**Method:** WebFetch GET (primary) / Bash CLI `ags` (fallback)  
**Timeout:** 8 seconds

---

## Request

```
GET https://agentskill.sh/api/skills?q={query}&limit=20
```

- URL-encode the query string.
- No authentication required.
- Enforce 8-second timeout.

## Timeout + Retry

- On HTTP 429: wait 1s, retry; wait 2s, retry; wait 4s, retry. After 3 retries return `status: "unavailable"`, `reason: "rate limited by agentskill.sh"`.
- On timeout or HTTP 5xx: fall through to Step 2 (CLI fallback).

## Response Parsing

Expected shape: `{ data: [...], total, page, totalPages }`.

| Response field | Unified schema field |
|----------------|----------------------|
| `name` | `name` |
| `description` or `seoSummary` (truncate to 500 chars, strip markdown/HTML tags before storing) | `description` |
| `repositoryUrl` | `install_url` |
| `contentSha` or `githubSha` | `content_sha` |
| `githubStars` | `stars` |
| `updatedAt` | `last_updated` |
| `installCount` | `install_count` |
| *(whole object)* | `raw_metadata` |

Set `source_registry: "agentskill-sh"` on every result.

---

## Step 2 — CLI Fallback

Only attempt if Step 1 fails (timeout, 5xx, or network error). Skip if Step 1 returned 4xx (not a transient failure).

```bash
which ags 2>/dev/null
```

If `ags` not found, return immediately:

```json
{
  "registry": "agentskill-sh",
  "status": "unavailable",
  "reason": "WebFetch failed and ags CLI not found",
  "results": [],
  "latency_ms": 0
}
```

If `ags` found:

```bash
ags search "{query}" --json
```

Shell-quote the query string. Enforce 8-second timeout. Parse the JSON array output using the same field mapping as Step 1.

If `ags` output is not valid JSON or is empty, return:

```json
{
  "registry": "agentskill-sh",
  "status": "failed",
  "reason": "ags CLI returned non-JSON output",
  "results": [],
  "latency_ms": 0
}
```

---

## Return Value

```json
{
  "registry": "agentskill-sh",
  "status": "ok",
  "reason": null,
  "results": [ /* unified schema objects */ ],
  "latency_ms": 0
}
```

On failure:

```json
{
  "registry": "agentskill-sh",
  "status": "unavailable",
  "reason": "<reason string>",
  "results": [],
  "latency_ms": 0
}
```
