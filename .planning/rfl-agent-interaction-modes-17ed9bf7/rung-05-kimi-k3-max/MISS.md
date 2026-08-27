# Rung 5 miss — Kimi K3 Max / OpenCode

User mapping: `/silver:agent-opencode`, Kimi K3, Max.

## Evidence

1. Catalog (earlier this session) listed `opencode-go/kimi-k3`.
2. Retry:

```
opencode run -m opencode-go/kimi-k3 --variant max
Error: Model not found: opencode-go/kimi-k3. Did you mean: kimi-k3?
```

3. Suggested slug:

```
opencode run -m kimi-k3 --variant max
UnknownError Unexpected server error. ref err_8d1e0d83
```

**Did not remap** to Kimi K2.7 or Grok. Ladder continues.
