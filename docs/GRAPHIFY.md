# Graphify Readiness

Silver Bullet uses Graphify as the preferred local retrieval layer before planning, editing, debugging, review, and shipping.

## Opt-In Policy

Graphify is a **recommended tool**, not a hard prerequisite like `jq`. SB asks for explicit
permission at `/silver:init` and session start. Consent is stored in `.silver-bullet.json`:

```json
"recommended_tools": {
  "graphify": {
    "enabled_by_user": null,
    "enforcement_suspended": false,
    "install_status": null,
    "install_failure_reason": null,
    "required_when_enabled": true
  }
}
```

| `enabled_by_user` | Behavior |
|-----------------|----------|
| `null` | Consent pending — SB prompts at init, update, and session start; no hook enforcement |
| `true` | Mandatory — hooks block substantive edits until index + fresh query |
| `false` | Opted out — advisory/docs fallback only |

**Install failure after opt-in:** when the user opts in but CLI install or index build fails,
SB sets `enforcement_suspended: true` and `install_status: "failed"` (with `install_failure_reason`).
Init/update is not blocked. Hooks treat suspended Graphify like opted-out while preserving
`enabled_by_user: true`. Session-start notes the suspension. On the next `/silver:init` (update
mode) or `/silver:update`, SB retries install; success clears suspension and re-enables mandatory
enforcement.

The same `recommended_tools` pattern applies to future SB-suggested tooling (see `hooks/lib/recommended-tools.sh`).

## Local Setup

Graphify requires Python 3.10+. If the system `python3` is older, install it with a newer Python or a tool runtime:

```bash
uv tool install graphifyy
```

or:

```bash
python3.12 -m pip install graphifyy
```

Optional surfaces:

```bash
python3.12 -m pip install watchdog psycopg[binary] 'graphifyy[mcp]'
```

`watchdog` enables `graphify watch`. `psycopg` enables `graphify extract --postgres`. `graphifyy[mcp]` enables `graphify-mcp --transport http`.

## Refresh

For normal SB work without LLM keys:

```bash
graphify update . --no-cluster
```

This refreshes code extraction only and works in docs-heavy SB repos. Full semantic extraction over docs, Markdown, HTML, PDFs, or images requires one of Graphify's supported LLM API keys.

## Query Pattern

Prefer concrete, scoped queries:

```bash
graphify query "dev-cycle-check source edit Stage C hooks/dev-cycle-check.sh" --graph graphify-out/graph.json --budget 2000
```

Then inspect returned nodes before acting. Broad terms can match workflow/docs nodes before the intended implementation nodes. If label lookup misses a script or file that appears in `graph.json`, use the generated node id from the graph or from a prior query result.

Useful follow-ups:

```bash
graphify explain hooks_dev_cycle_check --graph graphify-out/graph.json
graphify affected "record-skill.sh" --graph graphify-out/graph.json
graphify path "completion-audit.sh" "verify-tests" --graph graphify-out/graph.json
```

## Tested Surface

Validated against Graphify `0.8.36` in `todo-app`:

- update, extract, cluster-only, label fallback
- query, DFS query, explain, path, affected, diagnose, benchmark
- tree HTML and call-flow HTML exports
- save-result, merge-graphs, merge-driver
- global add/list/remove/path
- URL add, clone
- hook install/status/uninstall
- generic install/uninstall and all platform install/uninstall commands

Observed constraints:

- `graphify extract .` fails without an LLM key when docs/Markdown/HTML inputs are present.
- `graphify watch .` needs `watchdog`.
- `graphify extract --postgres` needs `psycopg` and a reachable database.
- `graphify-mcp --transport http` needs the MCP extra (`graphifyy[mcp]`).
- `graphify label` can exit successfully with placeholder labels when no backend key is available.
