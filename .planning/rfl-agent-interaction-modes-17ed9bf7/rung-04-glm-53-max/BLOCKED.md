# Rung 4 BLOCKED — GLM 5.3 Max (OpenCode)

**STATUS:** blocked  
**HOST:** opencode (native `opencode run`; `scripts/agent-opencode/invoke.sh` missing)  
**MODEL:** `opencode-go/glm-5.3` `--variant max`  
**METHOD:** `/silver:agent-opencode` → native CLI (invoke.sh absent)

## What ran

1. `scripts/agent-opencode/invoke.sh` — **missing** on this sparse tree.
2. Native: `/Users/shafqat/.opencode/bin/opencode run --pure --model opencode-go/glm-5.3 --variant max --auto --dir <repo> --file <plan> --file <CHARTER> --file <rung-03 review.md>`

## Failure

OpenCode Go stream error (same on a later probe session):

```
AI_APICallError: 5-hour usage limit reached. Resets in ~2hr 19min.
providerID=opencode-go modelID=glm-5.3
```

Log: `~/.local/share/opencode/log/opencode.log` (run `357889f8` session `ses_fd01c7ef7ffe5nmAeFBjlDE0uN`; probe run `b430e04e`).

Did **not** remap to Grok/Fast. Did **not** treat the 03:45 `review.md` (pre I-32..I-40) as this rung’s review.

## Plan under review (unread by GLM)

`.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md`  
SHA256: `6e33742a3f462edc50d1eb9ed3add2c2665c007edc87e896cea32476b92907ba` (410 lines; artifacts copy synced).

Retry after the OpenCode Go 5-hour window, same slug + `--variant max`.
