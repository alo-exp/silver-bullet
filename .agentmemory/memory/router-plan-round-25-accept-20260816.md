# Decision — Round-25 ACCEPT: GPT Max H-1 + Opus Extra High re-verify B-1/H-1/M-1 (2026-08-16)

Locked into router_subagent_surfaces_85bf9f09 (clarify round-25). Stay on `main`. No commit. Max not re-launched.

## GPT Max H-1

WS1 owns `scripts/lib/apo_delegate_catalog.py` and `scripts/lib/apo_multi_ai_catalog.py`. Retarget `/silver:*` / `$silver:*` → `/sb:` / `$sb:`.

## Opus B-1

`docs/apo-catalog.json` is emitted by `scripts/generate-apo-catalog.py`. Stop hand-edit SOT. Parity gate required. `SKILL_TO_FLOW` / `ROUTERS` must accept post-rename `sb` tokens. `WF-SILVER-ROUTER.triggers` public trigger is `/sb`.

## Opus H-1

One `ART-AGENT-DELEGATE` (hyphen). Drop `ART-AGENT_DELEGATE`. V-loop `artifact_refs` ⇄ AF `artifacts`.

## Opus M-1

`FS-SILVER_AGENT_OPENCODE` / `FS-SILVER_AGENT_PI` `artifact_refs` = `["ART-AGENT-DELEGATE"]`.

## KEEP REJECT

Public `/sb` only. Catalog ids `WF-SILVER-*` may remain. Schema unchanged. No second AF/WF. `nested_executor` lock-only. `tests/run-all-tests.sh` is the release gate.

Plan SHA-256: `701cc66466830161476597af35606168377acb2437088fb86787eec0f6fcc884`
Prior: `1096479cc1deba1b902ca501e8d7b7b1c0c1ba5f23510f8776c098f6913002d5`
